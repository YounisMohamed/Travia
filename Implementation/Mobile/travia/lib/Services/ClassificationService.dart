import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:travia/Helpers/Constants.dart';

// Models for request and response
class ImageClassificationRequest {
  final String imageUrl;
  final String caption;

  ImageClassificationRequest({
    required this.imageUrl,
    required this.caption,
  });

  Map<String, dynamic> toJson() => {
        'image_url': imageUrl,
        'caption': caption,
      };
}

class ImageClassificationResponse {
  final Map<String, bool> attributes;
  final Map<String, double> confidenceScores;
  final String blipDescription;
  final String yoloDescription;
  final String caption;

  ImageClassificationResponse({
    required this.attributes,
    required this.confidenceScores,
    required this.blipDescription,
    required this.yoloDescription,
    required this.caption,
  });

  factory ImageClassificationResponse.fromJson(Map<String, dynamic> json) {
    return ImageClassificationResponse(
      attributes: Map<String, bool>.from(json['attributes']),
      confidenceScores: Map<String, double>.from(json['confidence_scores'].map((key, value) => MapEntry(key, value.toDouble()))),
      blipDescription: json['blip_description'],
      yoloDescription: json['yolo_description'],
      caption: json['caption'],
    );
  }

  // Convenience getters for common attributes
  bool get isCasual => attributes['casual'] ?? false;
  bool get isRomantic => attributes['romantic'] ?? false;
  bool get isClassy => attributes['classy'] ?? false;
  bool get isGoodForKids => attributes['good_for_kids'] ?? false;

  double get casualConfidence => confidenceScores['casual'] ?? 0.0;
  double get romanticConfidence => confidenceScores['romantic'] ?? 0.0;
  double get classyConfidence => confidenceScores['classy'] ?? 0.0;
  double get goodForKidsConfidence => confidenceScores['good_for_kids'] ?? 0.0;

  @override
  String toString() {
    return 'ImageClassificationResponse(attributes: $attributes, confidenceScores: $confidenceScores)';
  }
}

// Custom exceptions for better error handling
class ClassificationException implements Exception {
  final String message;
  final int? statusCode;
  final String? details;

  ClassificationException(this.message, {this.statusCode, this.details});

  @override
  String toString() => 'ClassificationException: $message${statusCode != null ? ' (Status: $statusCode)' : ''}';
}

class NetworkException extends ClassificationException {
  NetworkException(String message) : super('Network error: $message');
}

class ServerException extends ClassificationException {
  ServerException(String message, int statusCode) : super(message, statusCode: statusCode);
}

class TimeoutException extends ClassificationException {
  TimeoutException() : super('Request timed out');
}

// Health check response model
class HealthResponse {
  final String status;
  final bool modelsLoaded;
  final bool? gpuAvailable;
  final int? gpuMemory;

  HealthResponse({
    required this.status,
    required this.modelsLoaded,
    this.gpuAvailable,
    this.gpuMemory,
  });

  factory HealthResponse.fromJson(Map<String, dynamic> json) {
    return HealthResponse(
      status: json['status'],
      modelsLoaded: json['models_loaded'],
      gpuAvailable: json['gpu_available'],
      gpuMemory: json['gpu_memory'],
    );
  }

  bool get isHealthy => status == 'healthy' && modelsLoaded;
}

class ImageClassificationService {
  static const Duration _defaultTimeout = Duration(seconds: 90); // Longer timeout for image processing
  static const Duration _healthCheckTimeout = Duration(seconds: 10);

  final String baseUrl;
  final Duration timeout;
  final http.Client _client;

  // Singleton pattern for easy access
  static ImageClassificationService? _instance;

  factory ImageClassificationService({
    String? baseUrl,
    Duration? timeout,
    http.Client? client,
  }) {
    _instance ??= ImageClassificationService._internal(
      baseUrl: baseUrlForClassification,
      timeout: timeout ?? _defaultTimeout,
      client: client ?? http.Client(),
    );
    return _instance!;
  }

  ImageClassificationService._internal({
    required this.baseUrl,
    required this.timeout,
    required http.Client client,
  }) : _client = client;

  // Dispose method for cleanup
  void dispose() {
    _client.close();
    _instance = null;
  }

  /// Check if the classification service is healthy and ready
  Future<HealthResponse> checkHealth() async {
    try {
      final response = await _client
          .get(
            Uri.parse('$baseUrl/health'),
            headers: _getHeaders(),
          )
          .timeout(_healthCheckTimeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return HealthResponse.fromJson(data);
      } else {
        throw ServerException(
          'Health check failed: ${response.reasonPhrase}',
          response.statusCode,
        );
      }
    } on SocketException catch (e) {
      throw NetworkException('Unable to connect to classification service: ${e.message}');
    } on http.ClientException catch (e) {
      throw NetworkException('Client error: ${e.message}');
    } on TimeoutException {
      throw TimeoutException();
    } catch (e) {
      throw ClassificationException('Unexpected error during health check: $e');
    }
  }

  /// Classify an image from URL with caption
  Future<ImageClassificationResponse> classifyImage({
    required String imageUrl,
    required String caption,
  }) async {
    // Validate inputs
    if (imageUrl.trim().isEmpty) {
      throw ClassificationException('Image URL cannot be empty');
    }
    if (caption.trim().isEmpty) {
      throw ClassificationException('Caption cannot be empty');
    }

    final request = ImageClassificationRequest(
      imageUrl: imageUrl.trim(),
      caption: caption.trim(),
    );

    try {
      if (kDebugMode) {
        print('🔄 Sending classification request for: $imageUrl');
      }

      final response = await _client
          .post(
            Uri.parse('$baseUrl/classify'),
            headers: _getHeaders(),
            body: json.encode(request.toJson()),
          )
          .timeout(timeout);

      return _handleResponse(response);
    } on SocketException catch (e) {
      throw NetworkException('Unable to connect to classification service: ${e.message}');
    } on http.ClientException catch (e) {
      throw NetworkException('Client error: ${e.message}');
    } on TimeoutException {
      throw TimeoutException();
    } catch (e) {
      if (e is ClassificationException) rethrow;
      throw ClassificationException('Unexpected error during classification: $e');
    }
  }

  /// Classify multiple images concurrently with rate limiting
  Future<List<ImageClassificationResponse>> classifyImages({
    required List<ImageClassificationRequest> requests,
    int concurrency = 3, // Limit concurrent requests to avoid overwhelming the server
  }) async {
    if (requests.isEmpty) {
      return [];
    }

    final results = <ImageClassificationResponse>[];
    final errors = <String>[];

    // Process requests in batches
    for (int i = 0; i < requests.length; i += concurrency) {
      final batch = requests.skip(i).take(concurrency);
      final futures = batch.map((request) async {
        try {
          return await classifyImage(
            imageUrl: request.imageUrl,
            caption: request.caption,
          );
        } catch (e) {
          errors.add('Failed to classify ${request.imageUrl}: $e');
          return null;
        }
      });

      final batchResults = await Future.wait(futures);
      results.addAll(batchResults.whereType<ImageClassificationResponse>());

      // Add a small delay between batches to be respectful to the server
      if (i + concurrency < requests.length) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
    }

    if (errors.isNotEmpty && kDebugMode) {
      print('⚠️ Some classifications failed: ${errors.join(', ')}');
    }

    return results;
  }

  /// Get service info
  Future<Map<String, dynamic>> getServiceInfo() async {
    try {
      final response = await _client
          .get(
            Uri.parse('$baseUrl/'),
            headers: _getHeaders(),
          )
          .timeout(_healthCheckTimeout);

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw ServerException(
          'Failed to get service info: ${response.reasonPhrase}',
          response.statusCode,
        );
      }
    } catch (e) {
      if (e is ClassificationException) rethrow;
      throw ClassificationException('Failed to get service info: $e');
    }
  }

  /// Handle HTTP response and convert to ImageClassificationResponse
  ImageClassificationResponse _handleResponse(http.Response response) {
    if (kDebugMode) {
      print('📨 Response status: ${response.statusCode}');
    }

    switch (response.statusCode) {
      case 200:
        try {
          final data = json.decode(response.body);
          final result = ImageClassificationResponse.fromJson(data);

          if (kDebugMode) {
            print('✅ Classification successful: ${result.attributes}');
          }

          return result;
        } catch (e) {
          throw ClassificationException('Failed to parse response: $e');
        }

      case 400:
        final errorData = _parseErrorResponse(response.body);
        throw ClassificationException(
          'Invalid request: ${errorData['detail'] ?? 'Bad request'}',
          statusCode: 400,
        );

      case 404:
        throw ClassificationException(
          'Classification endpoint not found',
          statusCode: 404,
        );

      case 500:
        final errorData = _parseErrorResponse(response.body);
        throw ServerException(
          'Server error: ${errorData['detail'] ?? 'Internal server error'}',
          500,
        );

      case 503:
        throw ClassificationException(
          'Service temporarily unavailable',
          statusCode: 503,
        );

      default:
        throw ClassificationException(
          'Unexpected response: ${response.statusCode} ${response.reasonPhrase}',
          statusCode: response.statusCode,
        );
    }
  }

  /// Parse error response safely
  Map<String, dynamic> _parseErrorResponse(String body) {
    try {
      return json.decode(body);
    } catch (e) {
      return {'detail': 'Unknown error'};
    }
  }

  /// Get standard headers for requests
  Map<String, String> _getHeaders() {
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'User-Agent': 'Flutter-ImageClassification-Client/1.0',
    };
  }
}

// Extension methods for easier usage
extension ImageClassificationExtension on ImageClassificationResponse {
  /// Get the attribute with highest confidence
  String get topAttribute {
    var maxScore = 0.0;
    var topAttr = 'casual';

    confidenceScores.forEach((attr, score) {
      if (score > maxScore) {
        maxScore = score;
        topAttr = attr;
      }
    });

    return topAttr;
  }

  /// Get all attributes that are true
  List<String> get trueAttributes {
    return attributes.entries.where((entry) => entry.value).map((entry) => entry.key).toList();
  }

  /// Get formatted description combining BLIP and YOLO
  String get fullDescription {
    final parts = <String>[];
    if (blipDescription.isNotEmpty) parts.add(blipDescription);
    if (yoloDescription.isNotEmpty) parts.add(yoloDescription);
    return parts.join(' - ');
  }
}
