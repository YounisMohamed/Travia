import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

import '../Classes/Businesses.dart';
import '../Classes/DayItinerary.dart';
import '../Classes/UserPreferences.dart';
import '../Helpers/Constants.dart';
import '../main.dart';

/// Itinerary response model
class ItineraryResponse {
  final List<DayItinerary> itinerary;
  final int totalBusinesses;
  final UserPreferences? userPreferences;
  final String trip_name;

  ItineraryResponse({
    required this.itinerary,
    required this.totalBusinesses,
    required this.trip_name,
    this.userPreferences,
  });

  factory ItineraryResponse.fromJson(Map<String, dynamic> json) {
    return ItineraryResponse(
      itinerary: (json['itinerary'] as List).map((day) => DayItinerary.fromJson(day)).toList(),
      totalBusinesses: json['total_businesses'] ?? 0,
      userPreferences: json['user_preferences'] != null ? UserPreferences.fromJson(json['user_preferences']) : null,
      trip_name: json['trip_name'] ?? "No name",
    );
  }

  String get city {
    if (userPreferences != null && userPreferences?.location != null) {
      return userPreferences!.location as String;
    }
    // Fallback to business city if preferences not available
    if (allUniqueBusinesses.isNotEmpty) {
      return allUniqueBusinesses.first.city ?? 'Your destination';
    }
    return 'Your destination';
  }

  /// Get total number of days
  int get totalDays => itinerary.length;

  /// Get all unique businesses
  List<Business> get allUniqueBusinesses {
    final businessMap = <int, Business>{};
    for (final day in itinerary) {
      for (final business in day.allBusinesses) {
        businessMap[business.id] = business;
      }
    }
    return businessMap.values.toList();
  }

  @override
  String toString() {
    return 'ItineraryResponse{itinerary: ${itinerary.toString()}, totalBusinesses: $totalBusinesses, userPreferences: ${userPreferences.toString()}';
  }
}

/// Travel planner exception
class TravelPlannerException implements Exception {
  final String message;
  final int? statusCode;
  final dynamic originalError;

  TravelPlannerException({
    required this.message,
    this.statusCode,
    this.originalError,
  });

  @override
  String toString() => 'TravelPlannerException: $message';
}

class TravelPlannerService {
  static const Duration _defaultTimeout = Duration(seconds: 60);

  final Duration timeout;
  final http.Client _client;
  final String baseUrl;

  // Singleton pattern
  static TravelPlannerService? _instance;

  factory TravelPlannerService({
    Duration? timeout,
    http.Client? client,
  }) {
    _instance ??= TravelPlannerService._internal(
      baseUrl: baseUrlForPlanner,
      timeout: timeout ?? _defaultTimeout,
      client: client ?? http.Client(),
    );
    return _instance!;
  }

  TravelPlannerService._internal({
    required this.baseUrl,
    required this.timeout,
    required http.Client client,
  }) : _client = client;

  /// Get singleton instance
  static TravelPlannerService get instance => _instance ?? TravelPlannerService();

  /// Save user preferences
  Future<void> savePreferences({
    required String userId,
    required UserPreferences preferences,
  }) async {
    try {
      debugPrint('[TravelPlanner] Saving preferences for user: $userId');
      debugPrint('[TravelPlanner] Preferences: ${json.encode(preferences.toJson())}');

      final response = await _makeRequest(
        'POST',
        '/users/$userId/preferences',
        body: preferences.toJson(),
      );

      debugPrint('[TravelPlanner] Preferences saved successfully');
    } catch (e) {
      debugPrint('[TravelPlanner] Error saving preferences: $e');
      if (e is TravelPlannerException) rethrow;

      throw TravelPlannerException(
        message: 'Failed to save preferences: ${e.toString()}',
        originalError: e,
      );
    }
  }

  /// Generate itinerary for a user
  Future<ItineraryResponse> generateItinerary({
    required String userId,
    required String city,
  }) async {
    try {
      debugPrint('[TravelPlanner] Generating itinerary for user: $userId');
      debugPrint('[TravelPlanner] Location: $city');

      final response = await _makeRequest(
        'POST',
        '/users/$userId/itinerary?city=${Uri.encodeComponent(city)}',
      );

      debugPrint('[TravelPlanner] Itinerary generated successfully');
      debugPrint('[TravelPlanner] Total days: ${response['itinerary']?.length ?? 0}');

      return ItineraryResponse.fromJson(response);
    } catch (e) {
      debugPrint('[TravelPlanner] Error generating itinerary: $e');
      if (e is TravelPlannerException) rethrow;

      throw TravelPlannerException(
        message: 'Failed to generate itinerary: ${e.toString()}',
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

      debugPrint('[TravelPlanner] $method $uri');

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
          throw TravelPlannerException(message: 'Unsupported HTTP method: $method');
      }

      debugPrint('[TravelPlanner] Response status: ${response.statusCode}');

      // Handle response
      if (response.statusCode >= 200 && response.statusCode < 300) {
        if (response.body.isEmpty) {
          return {};
        }
        return json.decode(response.body);
      } else if (response.statusCode == 404) {
        throw TravelPlannerException(
          message: 'Not found',
          statusCode: response.statusCode,
        );
      } else if (response.statusCode == 422) {
        // Validation error
        final error = json.decode(response.body);
        throw TravelPlannerException(
          message: error['detail']?.toString() ?? 'Validation error',
          statusCode: response.statusCode,
        );
      } else {
        throw TravelPlannerException(
          message: 'Request failed: ${response.reasonPhrase}',
          statusCode: response.statusCode,
        );
      }
    } on TimeoutException {
      throw TravelPlannerException(
        message: 'Request timed out. Please try again.',
      );
    } on SocketException {
      throw TravelPlannerException(
        message: 'Cannot connect to server. Make sure the API is running on $baseUrl',
      );
    } catch (e) {
      if (e is TravelPlannerException) rethrow;

      throw TravelPlannerException(
        message: 'Network error: ${e.toString()}',
        originalError: e,
      );
    }
  }

  Future<String> saveItinerary({
    required String userId,
    required ItineraryResponse itinerary,
    required DateTime tripDate,
  }) async {
    try {
      final tripId = const Uuid().v4();
      final List<Map<String, dynamic>> itineraryRecords = [];

      for (final dayItinerary in itinerary.itinerary) {
        final List<int> businessIds = [];
        final Map<String, List<int>> businessesByCategory = {
          'breakfast': [],
          'lunch': [],
          'dinner': [],
          'activities': [],
          'dessert': [],
        };

        // Add businesses to categories and collect IDs
        void processCategory(List<Business> businesses, String category) {
          for (final business in businesses) {
            businessIds.add(business.id);
            businessesByCategory[category]!.add(business.id);
          }
        }

        processCategory(dayItinerary.breakfast, 'breakfast');
        processCategory(dayItinerary.lunch, 'lunch');
        processCategory(dayItinerary.dinner, 'dinner');
        processCategory(dayItinerary.activities, 'activities');
        processCategory(dayItinerary.dessert, 'dessert');

        itineraryRecords.add({
          'trip_id': tripId,
          'user_id': userId,
          'day_number': dayItinerary.day,
          'business_ids': businessIds,
          'businesses_by_category': businessesByCategory,
          'preferences_snapshot': itinerary.userPreferences?.toJson(),
          'created_at': tripDate.toIso8601String(),
        });
      }
      print("ITINERARY RECORDS: ${itineraryRecords}");

      await supabase.from('itineraries').insert(itineraryRecords);
      return tripId;
    } catch (e) {
      print('Failed to save itinerary: $e');
      throw TravelPlannerException(message: 'Failed to save itinerary: $e');
    }
  }

  Future<List<SavedItinerary>> getSavedItineraries({required String userId}) async {
    try {
      final response = await supabase.from('itineraries').select().eq('user_id', userId).order('created_at', ascending: false);

      // Group by trip ID
      final Map<String, List<dynamic>> groupedByTrip = {};
      for (final record in response as List) {
        final tripId = record['trip_id'] as String;
        groupedByTrip.putIfAbsent(tripId, () => []).add(record);
      }

      final savedItineraries = <SavedItinerary>[];

      for (final entry in groupedByTrip.entries) {
        final days = entry.value;
        days.sort((a, b) => a['day_number'].compareTo(b['day_number']));

        // Collect all unique business IDs
        final Set<int> allBusinessIds = {};
        for (final day in days) {
          allBusinessIds.addAll(List<int>.from(day['business_ids'] as List));
        }

        // Fetch businesses using IN query instead of filtering all businesses
        final Map<int, Business> businessMap = {};
        if (allBusinessIds.isNotEmpty) {
          print('Fetching businesses with IDs: $allBusinessIds'); // Debug log

          final businessesResponse = await supabase.from('businesses').select().inFilter('id', allBusinessIds.toList());

          print('Found ${businessesResponse.length} businesses'); // Debug log

          for (final businessData in businessesResponse as List) {
            final business = Business.fromJson(businessData);
            businessMap[business.id] = business;
            print('Loaded business: ${business.id} - ${business.name}'); // Debug log
          }
        }

        // Reconstruct day itineraries
        final dayItineraries = <DayItinerary>[];
        for (final day in days) {
          final businessesByCategory = day['businesses_by_category'] as Map<String, dynamic>;

          dayItineraries.add(DayItinerary(
            day: day['day_number'],
            breakfast: _getBusinesses(businessesByCategory, 'breakfast', businessMap),
            lunch: _getBusinesses(businessesByCategory, 'lunch', businessMap),
            dinner: _getBusinesses(businessesByCategory, 'dinner', businessMap),
            activities: _getBusinesses(businessesByCategory, 'activities', businessMap),
            dessert: _getBusinesses(businessesByCategory, 'dessert', businessMap),
          ));
        }

        // Get city from preferences snapshot first, fallback to business city
        String city = 'Unknown';
        final preferencesSnapshot = days.first['preferences_snapshot'];
        if (preferencesSnapshot != null && preferencesSnapshot['location'] != null) {
          city = preferencesSnapshot['location'] as String;
        } else if (businessMap.isNotEmpty) {
          city = businessMap.values.first.city ?? 'Unknown';
        }

        savedItineraries.add(SavedItinerary(
          id: entry.key,
          userId: userId,
          createdAt: DateTime.parse(days.first['created_at']),
          totalDays: days.length,
          city: city,
          dayItineraries: dayItineraries,
          tripName: days.first['trip_name'],
        ));
      }

      return savedItineraries;
    } catch (e) {
      print('Error in getSavedItineraries: $e'); // Debug log
      throw TravelPlannerException(message: 'Failed to retrieve saved itineraries: $e');
    }
  }

  List<Business> _getBusinesses(Map<String, dynamic> categories, String category, Map<int, Business> businessMap) {
    return (categories[category] as List? ?? []).map((id) => businessMap[id as int]).whereType<Business>().toList();
  }

  /// Dispose of resources
  void dispose() {
    _client.close();
    _instance = null;
  }
}
