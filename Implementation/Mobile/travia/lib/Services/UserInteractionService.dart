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

class UserInteraction {
  final int id;
  final int businessId;
  final String businessName;
  final String locality;
  final String region;
  final InteractionType interactionType;
  final DateTime createdAt;

  UserInteraction({
    required this.id,
    required this.businessId,
    required this.businessName,
    required this.locality,
    required this.region,
    required this.interactionType,
    required this.createdAt,
  });

  factory UserInteraction.fromJson(Map<String, dynamic> json) {
    return UserInteraction(
      id: json['id'],
      businessId: json['business_id'],
      businessName: json['business_name'],
      locality: json['locality'],
      region: json['region'],
      interactionType: json['interaction_type'] == 'like' ? InteractionType.like : InteractionType.dislike,
      createdAt: DateTime.parse(json['created_at']),
    );
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
  String? _currentUserId;
  DateTime? _lastLoadTime;

  // Timeout configurations
  static const Duration _requestTimeout = Duration(seconds: 30);
  static const int _maxRetries = 3;
  static const Duration _retryDelay = Duration(seconds: 2);
  static const Duration _cacheExpiry = Duration(minutes: 5); // Cache expires after 5 minutes

  bool get isInitialized => _currentUserId != null && _lastLoadTime != null;

  UserInteractionState? getInteractionState(int businessId) {
    return _interactions[businessId];
  }

  bool isLiked(int businessId) {
    final result = _interactions[businessId]?.currentInteraction == InteractionType.like;
    if (kDebugMode) {
      print('UserInteractionService: isLiked($businessId) = $result, state: ${_interactions[businessId]?.currentInteraction}');
    }
    return result;
  }

  bool isDisliked(int businessId) {
    final result = _interactions[businessId]?.currentInteraction == InteractionType.dislike;
    if (kDebugMode) {
      print('UserInteractionService: isDisliked($businessId) = $result, state: ${_interactions[businessId]?.currentInteraction}');
    }
    return result;
  }

  bool isLoading(int businessId) {
    return _interactions[businessId]?.isLoading ?? false;
  }

  String? getError(int businessId) {
    return _interactions[businessId]?.error;
  }

  /// Check if cache is expired
  bool get _isCacheExpired {
    if (_lastLoadTime == null) return true;
    return DateTime.now().difference(_lastLoadTime!) > _cacheExpiry;
  }

  /// Load user interactions from database - always refresh from API
  Future<void> loadUserInteractions(String userId, {bool forceRefresh = false}) async {
    try {
      // Always reload if it's a different user or cache is expired or forced refresh
      final shouldReload = _currentUserId != userId || _isCacheExpired || forceRefresh;

      if (!shouldReload && isInitialized) {
        if (kDebugMode) {
          print('UserInteractionService: Using cached interactions for user $userId');
        }
        return;
      }

      if (kDebugMode) {
        print('UserInteractionService: Loading interactions for user $userId (${shouldReload ? "refresh" : "initial"})');
      }

      final interactions = await _fetchUserInteractions(userId);

      // Clear existing interactions if user changed
      if (_currentUserId != userId) {
        _interactions.clear();
      }

      // Clear all interactions and reload from database
      _interactions.clear();

      // Initialize interactions from database
      for (final interaction in interactions) {
        _interactions[interaction.businessId] = UserInteractionState(
          businessId: interaction.businessId,
          currentInteraction: interaction.interactionType,
        );
      }

      _currentUserId = userId;
      _lastLoadTime = DateTime.now();
      notifyListeners();

      if (kDebugMode) {
        print('UserInteractionService: Loaded ${interactions.length} interactions for user $userId');
      }
    } catch (e) {
      if (kDebugMode) {
        print('UserInteractionService: Error loading interactions: $e');
      }
      // Clear interactions on error
      _interactions.clear();
      _currentUserId = userId;
      _lastLoadTime = DateTime.now();
      notifyListeners();
    }
  }

  /// Fetch user interactions from API
  Future<List<UserInteraction>> _fetchUserInteractions(String userId) async {
    final url = Uri.parse('$baseUrl/users/$userId/interactions');

    if (kDebugMode) {
      print('UserInteractionService: Fetching interactions from $url');
    }

    final response = await http.get(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ).timeout(_requestTimeout);

    if (kDebugMode) {
      print('UserInteractionService: API response status: ${response.statusCode}');
      print('UserInteractionService: API response body: ${response.body}');
    }

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => UserInteraction.fromJson(json)).toList();
    } else if (response.statusCode == 404) {
      // User not found or no interactions - return empty list
      if (kDebugMode) {
        print('UserInteractionService: No interactions found for user $userId');
      }
      return [];
    } else {
      throw HttpException('Failed to fetch interactions: ${response.statusCode}');
    }
  }

  /// Submit feedback - only update UI after successful API response
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

    // Set loading state without changing interaction
    _updateInteractionState(
      businessId: businessId,
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

      // Success - update state only after successful API response
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
      // Failure - show error and stop loading
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

    // Stop loading and show error - preserve current interaction state
    _updateInteractionState(
      businessId: businessId,
      isLoading: false,
      error: errorMessage,
      // Don't change interaction state on error
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
    bool? clearInteraction, // Add explicit flag to clear interaction
    bool isLoading = false,
    String? error,
  }) {
    final currentState = _interactions[businessId];

    // Determine the final interaction state
    InteractionType? finalInteraction;
    if (clearInteraction == true) {
      // Explicitly clear the interaction
      finalInteraction = null;
    } else if (newInteraction != null) {
      // Set new interaction
      finalInteraction = newInteraction;
    } else {
      // Preserve current interaction if not explicitly changing it
      finalInteraction = currentState?.currentInteraction;
    }

    _interactions[businessId] = UserInteractionState(
      businessId: businessId,
      currentInteraction: finalInteraction,
      isLoading: isLoading,
      error: error,
    );

    if (kDebugMode) {
      print('UserInteractionService: Updated state for business $businessId - '
          'interaction: $finalInteraction, loading: $isLoading, error: $error');
    }

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

  /// Toggle like/dislike - only updates after successful API response
  /// Toggle like/dislike - only updates after successful API response
  Future<void> toggleLike(String userId, int businessId) async {
    final currentState = _interactions[businessId];
    final isCurrentlyLiked = currentState?.currentInteraction == InteractionType.like;

    if (kDebugMode) {
      print('UserInteractionService: toggleLike for business $businessId - currently liked: $isCurrentlyLiked');
      print('UserInteractionService: Current state: ${currentState?.currentInteraction}');
    }

    if (isCurrentlyLiked) {
      // Remove like
      if (kDebugMode) {
        print('UserInteractionService: Removing like for business $businessId');
      }
      await _removeInteraction(userId, businessId);
    } else {
      // Submit like
      if (kDebugMode) {
        print('UserInteractionService: Adding like for business $businessId');
      }
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

    if (kDebugMode) {
      print('UserInteractionService: toggleDislike for business $businessId - currently disliked: $isCurrentlyDisliked');
      print('UserInteractionService: Current state: ${currentState?.currentInteraction}');
    }

    if (isCurrentlyDisliked) {
      // Remove dislike
      if (kDebugMode) {
        print('UserInteractionService: Removing dislike for business $businessId');
      }
      await _removeInteraction(userId, businessId);
    } else {
      // Submit dislike
      if (kDebugMode) {
        print('UserInteractionService: Adding dislike for business $businessId');
      }
      await submitFeedback(
        userId: userId,
        businessId: businessId,
        interactionType: InteractionType.dislike,
      );
    }
  }

  /// Remove interaction from database
  Future<void> _removeInteraction(String userId, int businessId) async {
    // Set loading state while preserving current interaction
    final currentState = _interactions[businessId];
    _updateInteractionState(
      businessId: businessId,
      isLoading: true,
      error: null,
      // Don't change the interaction state during loading
    );

    try {
      await _removeInteractionWithRetry(userId: userId, businessId: businessId);

      // Success - explicitly clear the interaction
      _updateInteractionState(
        businessId: businessId,
        clearInteraction: true, // Explicitly clear
        isLoading: false,
        error: null,
      );

      if (kDebugMode) {
        print('UserInteractionService: Successfully removed interaction for business $businessId');
      }
    } catch (e) {
      // Failure - show error and stop loading, keep current interaction
      _handleSubmissionError(businessId, e);
    }
  }

  /// Remove interaction with retry logic
  Future<void> _removeInteractionWithRetry({
    required String userId,
    required int businessId,
  }) async {
    int attempts = 0;
    Exception? lastException;

    while (attempts < _maxRetries) {
      attempts++;

      try {
        await _makeRemoveApiRequest(userId: userId, businessId: businessId);
        return; // Success
      } on SocketException catch (e) {
        lastException = e;
        if (kDebugMode) {
          print('UserInteractionService: Network error removing interaction (attempt $attempts/$_maxRetries): ${e.message}');
        }
      } on TimeoutException catch (e) {
        lastException = e;
        if (kDebugMode) {
          print('UserInteractionService: Timeout error removing interaction (attempt $attempts/$_maxRetries): ${e.message}');
        }
      } on HttpException catch (e) {
        lastException = e;
        if (kDebugMode) {
          print('UserInteractionService: HTTP error removing interaction (attempt $attempts/$_maxRetries): ${e.message}');
        }

        // Don't retry on client errors (4xx)
        if (e.message.contains('4')) {
          throw e;
        }
      } catch (e) {
        lastException = Exception(e.toString());
        if (kDebugMode) {
          print('UserInteractionService: Unexpected error removing interaction (attempt $attempts/$_maxRetries): $e');
        }
      }

      // Wait before retry (except on last attempt)
      if (attempts < _maxRetries) {
        await Future.delayed(_retryDelay * attempts); // Exponential backoff
      }
    }

    // All retries failed
    throw lastException ?? Exception('Failed to remove interaction after $_maxRetries attempts');
  }

  /// Make the actual API request to remove interaction
  Future<void> _makeRemoveApiRequest({
    required String userId,
    required int businessId,
  }) async {
    final url = Uri.parse('$baseUrl/users/$userId/interactions/$businessId');

    if (kDebugMode) {
      print('UserInteractionService: Removing interaction at $url');
    }

    final response = await http.delete(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ).timeout(_requestTimeout);

    if (kDebugMode) {
      print('UserInteractionService: Remove API response status: ${response.statusCode}');
      print('UserInteractionService: Remove API response body: ${response.body}');
    }

    if (response.statusCode == 200) {
      // Success
      return;
    } else if (response.statusCode == 404) {
      // No interaction found - treat as success since the goal is achieved
      if (kDebugMode) {
        print('UserInteractionService: No interaction found to remove (already removed)');
      }
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

  /// Initialize business state (useful for lists)
  void initializeBusinessState(int businessId, {InteractionType? initialInteraction}) {
    if (!_interactions.containsKey(businessId)) {
      _interactions[businessId] = UserInteractionState(
        businessId: businessId,
        currentInteraction: initialInteraction,
      );
    }
  }

  /// Clear all interactions (useful for logout)
  void clearAllInteractions() {
    _interactions.clear();
    _pendingRequests.clear();
    _currentUserId = null;
    _lastLoadTime = null;
    notifyListeners();
  }

  /// Force refresh interactions from database
  Future<void> refreshInteractions(String userId) async {
    await loadUserInteractions(userId, forceRefresh: true);
  }
}
