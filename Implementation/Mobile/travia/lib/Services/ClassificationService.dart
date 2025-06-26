import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../Helpers/Constants.dart';

/// Request model for venue classification
class ClassificationRequest {
  final String imageUrl;
  final String caption;
  final double confidenceThreshold;

  ClassificationRequest({
    required this.imageUrl,
    required this.caption,
    this.confidenceThreshold = 0.5,
  });

  Map<String, dynamic> toJson() => {
        'image_url': imageUrl,
        'caption': caption,
        'confidence_threshold': confidenceThreshold,
      };
}

/// Response model for classification results
class ClassificationResponse {
  final bool success;
  final VenueAttributes attributes;
  final ClassificationMetadata metadata;
  final String? error;

  ClassificationResponse({
    required this.success,
    required this.attributes,
    required this.metadata,
    this.error,
  });

  factory ClassificationResponse.fromJson(Map<String, dynamic> json) {
    return ClassificationResponse(
      success: json['success'] ?? false,
      attributes: VenueAttributes.fromJson(json['attributes'] ?? {}),
      metadata: ClassificationMetadata.fromJson(json['metadata'] ?? {}),
      error: json['error'],
    );
  }
}

/// Venue attributes model
class VenueAttributes {
  final bool goodForKids;
  final bool ambienceRomantic;
  final bool ambienceTrendy;
  final bool ambienceCasual;
  final bool ambienceClassy;
  final bool barsNight;
  final bool cafes;
  final bool restaurantsCuisines;

  VenueAttributes({
    required this.goodForKids,
    required this.ambienceRomantic,
    required this.ambienceTrendy,
    required this.ambienceCasual,
    required this.ambienceClassy,
    required this.barsNight,
    required this.cafes,
    required this.restaurantsCuisines,
  });

  factory VenueAttributes.fromJson(Map<String, dynamic> json) {
    return VenueAttributes(
      goodForKids: (json['attributes_GoodForKids'] ?? 0) == 1,
      ambienceRomantic: (json['attributes_Ambience_romantic'] ?? 0) == 1,
      ambienceTrendy: (json['attributes_Ambience_trendy'] ?? 0) == 1,
      ambienceCasual: (json['attributes_Ambience_casual'] ?? 0) == 1,
      ambienceClassy: (json['attributes_Ambience_classy'] ?? 0) == 1,
      barsNight: (json['Bars_Night'] ?? 0) == 1,
      cafes: (json['Cafes'] ?? 0) == 1,
      restaurantsCuisines: (json['Restaurants_Cuisines'] ?? 0) == 1,
    );
  }

  /// Get list of active attributes for display
  List<String> getActiveAttributes() {
    final List<String> active = [];
    if (goodForKids) active.add('Good for Kids');
    if (ambienceRomantic) active.add('Romantic');
    if (ambienceTrendy) active.add('Trendy');
    if (ambienceCasual) active.add('Casual');
    if (ambienceClassy) active.add('Classy');
    if (barsNight) active.add('Bar/Nightlife');
    if (cafes) active.add('Cafe');
    if (restaurantsCuisines) active.add('Restaurant');
    return active;
  }

  /// Get venue type (primary category)
  String getVenueType() {
    if (restaurantsCuisines) return 'Restaurant';
    if (cafes) return 'Cafe';
    if (barsNight) return 'Bar';
    return 'Venue';
  }
}

/// Classification metadata model
class ClassificationMetadata {
  final String blipDescription;
  final String simpleDescription;
  final String combinedText;
  final double confidenceThreshold;

  ClassificationMetadata({
    required this.blipDescription,
    required this.simpleDescription,
    required this.combinedText,
    required this.confidenceThreshold,
  });

  factory ClassificationMetadata.fromJson(Map<String, dynamic> json) {
    return ClassificationMetadata(
      blipDescription: json['blip_description'] ?? '',
      simpleDescription: json['simple_description'] ?? '',
      combinedText: json['combined_text'] ?? '',
      confidenceThreshold: (json['confidence_threshold'] ?? 0.5).toDouble(),
    );
  }
}

/// Custom exception for classifier errors
class ClassifierException implements Exception {
  final String message;
  final int? statusCode;
  final dynamic originalError;

  ClassifierException({
    required this.message,
    this.statusCode,
    this.originalError,
  });

  @override
  String toString() => 'ClassifierException: $message';
}

class TravelClassifierService {
  static final String _defaultBaseUrl = baseUrlForClassification;
  static const Duration _defaultTimeout = Duration(seconds: 60); // Longer timeout for model loading

  final String baseUrl;
  final Duration timeout;
  final http.Client _client;

  // Singleton pattern for easy access
  static TravelClassifierService? _instance;

  factory TravelClassifierService({
    Duration? timeout,
    http.Client? client,
  }) {
    _instance ??= TravelClassifierService._internal(
      baseUrl: _defaultBaseUrl,
      timeout: timeout ?? _defaultTimeout,
      client: client ?? http.Client(),
    );
    return _instance!;
  }

  TravelClassifierService._internal({
    required this.baseUrl,
    required this.timeout,
    required http.Client client,
  }) : _client = client;

  /// Get singleton instance
  static TravelClassifierService get instance => _instance ?? TravelClassifierService();
  Future<ClassificationResponse> classifyFromUrl({
    required String imageUrl,
    required String caption,
    double confidenceThreshold = 0.5,
  }) async {
    try {
      final request = ClassificationRequest(
        imageUrl: imageUrl,
        caption: caption,
        confidenceThreshold: confidenceThreshold,
      );

      final response = await _makeRequest(
        'POST',
        '/classify/url',
        body: request.toJson(),
      );
      return ClassificationResponse.fromJson(response);
    } catch (e) {
      if (e is ClassifierException) rethrow;
      throw ClassifierException(
        message: 'Classification failed: ${e.toString()}',
        originalError: e,
      );
    }
  }

  Future<Map<String, dynamic>> getFeatures() async {
    try {
      final response = await _makeRequest(
        'GET',
        '/features',
      );

      return response;
    } catch (e) {
      throw ClassifierException(
        message: 'Failed to get features: ${e.toString()}',
        originalError: e,
      );
    }
  }

  /// Make HTTP request with error handling
  Future<Map<String, dynamic>> _makeRequest(
    String method,
    String endpoint, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl$endpoint');
      final requestHeaders = {
        'Content-Type': 'application/json',
        ...?headers,
      };

      http.Response response;

      switch (method) {
        case 'GET':
          response = await _client.get(uri, headers: requestHeaders).timeout(timeout);
          break;
        case 'POST':
          response = await _client
              .post(
                uri,
                headers: requestHeaders,
                body: body != null ? json.encode(body) : null,
              )
              .timeout(timeout);
          break;
        default:
          throw ClassifierException(message: 'Unsupported HTTP method: $method');
      }

      // Handle response
      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else if (response.statusCode == 422) {
        // Validation error
        final error = json.decode(response.body);
        throw ClassifierException(
          message: error['detail']?.toString() ?? 'Validation error',
          statusCode: response.statusCode,
        );
      } else {
        throw ClassifierException(
          message: 'Request failed: ${response.reasonPhrase}',
          statusCode: response.statusCode,
        );
      }
    } on TimeoutException {
      throw ClassifierException(
        message: 'Request timed out. The server might be loading models or processing.',
      );
    } on SocketException {
      throw ClassifierException(
        message: 'Cannot connect to server. Make sure the API is running on $baseUrl',
      );
    } catch (e) {
      if (e is ClassifierException) rethrow;

      throw ClassifierException(
        message: 'Network error: ${e.toString()}',
        originalError: e,
      );
    }
  }

  /// Dispose of resources
  void dispose() {
    _client.close();
    _instance = null;
  }
}
