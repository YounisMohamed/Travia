import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:travia/Helpers/Constants.dart';

enum InteractionType { like, dislike }

class FeedbackRequest {
  final int businessId;
  final String interactionType;

  FeedbackRequest({
    required this.businessId,
    required this.interactionType,
  });

  Map<String, dynamic> toJson() {
    return {
      'business_id': businessId,
      'interaction_type': interactionType,
    };
  }
}

class UserInteractionState {
  final int businessId;
  final InteractionType? currentInteraction;
  final bool isLoading;
  final String? error;

  UserInteractionState({
    required this.businessId,
    this.currentInteraction,
    this.isLoading = false,
    this.error,
  });

  UserInteractionState copyWith({
    InteractionType? currentInteraction,
    bool? isLoading,
    String? error,
  }) {
    return UserInteractionState(
      businessId: businessId,
      currentInteraction: currentInteraction,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class UserInteractionService extends ChangeNotifier {
  static final UserInteractionService _instance = UserInteractionService._internal();
  factory UserInteractionService() => _instance;
  UserInteractionService._internal();

  final String baseUrl = baseUrlForPlanner;
  final Map<int, UserInteractionState> _interactions = {};
  final Set<String> _pendingRequests = {};

  // Timeout configurations
  static const Duration _requestTimeout = Duration(seconds: 30);
  static const int _maxRetries = 3;
  static const Duration _retryDelay = Duration(seconds: 2);

  UserInteractionState? getInteractionState(int businessId) {
    return _interactions[businessId];
  }

  bool isLiked(int businessId) {
    return _interactions[businessId]?.currentInteraction == InteractionType.like;
  }

  bool isDisliked(int businessId) {
    return _interactions[businessId]?.currentInteraction == InteractionType.dislike;
  }

  bool isLoading(int businessId) {
    return _interactions[businessId]?.isLoading ?? false;
  }

  String? getError(int businessId) {
    return _interactions[businessId]?.error;
  }

  /// Submit feedback with optimistic UI updates
  Future<void> submitFeedback({
    required String userId,
    required int businessId,
    required InteractionType interactionType,
  }) async {
    // Prevent duplicate requests
    final requestKey = '${businessId}_${interactionType.name}';
    if (_pendingRequests.contains(requestKey)) {
      if (kDebugMode) {
        print('UserInteractionService: Request already pending for $requestKey');
      }
      return;
    }

    // Optimistic update - immediately show the interaction
    _updateInteractionState(
      businessId: businessId,
      newInteraction: interactionType,
      isLoading: true,
      error: null,
    );

    _pendingRequests.add(requestKey);

    try {
      await _submitFeedbackWithRetry(
        userId: userId,
        businessId: businessId,
        interactionType: interactionType,
      );

      // Success - keep the optimistic state and remove loading
      _updateInteractionState(
        businessId: businessId,
        newInteraction: interactionType,
        isLoading: false,
        error: null,
      );

      if (kDebugMode) {
        print('UserInteractionService: Successfully submitted ${interactionType.name} for business $businessId');
      }
    } catch (e) {
      // Failure - revert optimistic update and show error
      _handleSubmissionError(businessId, e);
    } finally {
      _pendingRequests.remove(requestKey);
    }
  }

  /// Submit feedback with retry logic
  Future<void> _submitFeedbackWithRetry({
    required String userId,
    required int businessId,
    required InteractionType interactionType,
  }) async {
    int attempts = 0;
    Exception? lastException;

    while (attempts < _maxRetries) {
      attempts++;

      try {
        await _makeApiRequest(
          userId: userId,
          businessId: businessId,
          interactionType: interactionType,
        );
        return; // Success
      } on SocketException catch (e) {
        lastException = e;
        if (kDebugMode) {
          print('UserInteractionService: Network error (attempt $attempts/$_maxRetries): ${e.message}');
        }
      } on TimeoutException catch (e) {
        lastException = e;
        if (kDebugMode) {
          print('UserInteractionService: Timeout error (attempt $attempts/$_maxRetries): ${e.message}');
        }
      } on HttpException catch (e) {
        lastException = e;
        if (kDebugMode) {
          print('UserInteractionService: HTTP error (attempt $attempts/$_maxRetries): ${e.message}');
        }

        // Don't retry on client errors (4xx)
        if (e.message.contains('4')) {
          throw e;
        }
      } catch (e) {
        lastException = Exception(e.toString());
        if (kDebugMode) {
          print('UserInteractionService: Unexpected error (attempt $attempts/$_maxRetries): $e');
        }
      }

      // Wait before retry (except on last attempt)
      if (attempts < _maxRetries) {
        await Future.delayed(_retryDelay * attempts); // Exponential backoff
      }
    }

    // All retries failed
    throw lastException ?? Exception('Failed to submit feedback after $_maxRetries attempts');
  }

  /// Make the actual API request
  Future<void> _makeApiRequest({
    required String userId,
    required int businessId,
    required InteractionType interactionType,
  }) async {
    final url = Uri.parse('$baseUrl/users/$userId/feedback');

    final feedbackRequest = FeedbackRequest(
      businessId: businessId,
      interactionType: interactionType.name,
    );

    final response = await http
        .post(
          url,
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          body: jsonEncode(feedbackRequest.toJson()),
        )
        .timeout(_requestTimeout);

    if (response.statusCode == 200 || response.statusCode == 201) {
      // Success
      return;
    } else if (response.statusCode >= 400 && response.statusCode < 500) {
      // Client error
      String errorMessage = 'Client error: ${response.statusCode}';
      try {
        final errorData = jsonDecode(response.body);
        errorMessage = errorData['detail'] ?? errorMessage;
      } catch (e) {
        // Ignore JSON parsing errors
      }
      throw HttpException(errorMessage);
    } else {
      // Server error
      String errorMessage = 'Server error: ${response.statusCode}';
      try {
        final errorData = jsonDecode(response.body);
        errorMessage = errorData['detail'] ?? errorMessage;
      } catch (e) {
        // Ignore JSON parsing errors
      }
      throw HttpException(errorMessage);
    }
  }

  /// Handle submission errors
  void _handleSubmissionError(int businessId, dynamic error) {
    String errorMessage = 'Failed to submit feedback';

    if (error is SocketException) {
      errorMessage = 'No internet connection';
    } else if (error is TimeoutException) {
      errorMessage = 'Request timed out';
    } else if (error is HttpException) {
      errorMessage = error.message;
    } else {
      errorMessage = error.toString();
    }

    // Revert to previous state (no interaction) and show error
    _updateInteractionState(
      businessId: businessId,
      newInteraction: null,
      isLoading: false,
      error: errorMessage,
    );

    if (kDebugMode) {
      print('UserInteractionService: Error submitting feedback for $businessId: $errorMessage');
    }

    // Clear error after some time
    Timer(const Duration(seconds: 5), () {
      _clearError(businessId);
    });
  }

  /// Update interaction state and notify listeners
  void _updateInteractionState({
    required int businessId,
    InteractionType? newInteraction,
    bool isLoading = false,
    String? error,
  }) {
    final currentState = _interactions[businessId];

    _interactions[businessId] = UserInteractionState(
      businessId: businessId,
      currentInteraction: newInteraction,
      isLoading: isLoading,
      error: error,
    );

    notifyListeners();
  }

  /// Clear error for a specific business
  void _clearError(int businessId) {
    final currentState = _interactions[businessId];
    if (currentState != null && currentState.error != null) {
      _interactions[businessId] = currentState.copyWith(error: null);
      notifyListeners();
    }
  }

  /// Toggle like/dislike - handles switching between states
  Future<void> toggleLike(String userId, int businessId) async {
    final currentState = _interactions[businessId];
    final isCurrentlyLiked = currentState?.currentInteraction == InteractionType.like;

    if (isCurrentlyLiked) {
      _clearInteraction(businessId);
    } else {
      // Submit like
      await submitFeedback(
        userId: userId,
        businessId: businessId,
        interactionType: InteractionType.like,
      );
    }
  }

  Future<void> toggleDislike(String userId, int businessId) async {
    final currentState = _interactions[businessId];
    final isCurrentlyDisliked = currentState?.currentInteraction == InteractionType.dislike;

    if (isCurrentlyDisliked) {
      // If already disliked, remove the dislike
      _clearInteraction(businessId);
    } else {
      // Submit dislike
      await submitFeedback(
        userId: userId,
        businessId: businessId,
        interactionType: InteractionType.dislike,
      );
    }
  }

  /// Clear interaction for a business
  void _clearInteraction(int businessId) {
    _updateInteractionState(
      businessId: businessId,
      newInteraction: null,
      isLoading: false,
      error: null,
    );
  }

  /// Clear all interactions (useful for logout)
  void clearAllInteractions() {
    _interactions.clear();
    _pendingRequests.clear();
    notifyListeners();
  }

  /// Preload interaction state for a business (useful for lists)
  void initializeBusinessState(int businessId, {InteractionType? initialInteraction}) {
    if (!_interactions.containsKey(businessId)) {
      _interactions[businessId] = UserInteractionState(
        businessId: businessId,
        currentInteraction: initialInteraction,
      );
    }
  }
}
