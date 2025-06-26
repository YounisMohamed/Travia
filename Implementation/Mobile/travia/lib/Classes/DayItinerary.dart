import '../Services/PlannerService.dart';
import '../Services/UserInteractionService.dart';
import '../main.dart';
import 'Businesses.dart';

/// Day itinerary model
class DayItinerary {
  final int day;
  final List<Business> breakfast;
  final List<Business> lunch;
  final List<Business> dinner;
  final List<Business> activities;
  final List<Business> dessert;

  DayItinerary({
    required this.day,
    required this.breakfast,
    required this.lunch,
    required this.dinner,
    required this.activities,
    required this.dessert,
  });

  factory DayItinerary.fromJson(Map<String, dynamic> json) {
    return DayItinerary(
      day: json['day'],
      breakfast: (json['breakfast'] as List?)?.map((b) => Business.fromJson(b)).toList() ?? [],
      lunch: (json['lunch'] as List?)?.map((b) => Business.fromJson(b)).toList() ?? [],
      dinner: (json['dinner'] as List?)?.map((b) => Business.fromJson(b)).toList() ?? [],
      activities: (json['activities'] as List?)?.map((b) => Business.fromJson(b)).toList() ?? [],
      dessert: (json['dessert'] as List?)?.map((b) => Business.fromJson(b)).toList() ?? [],
    );
  }

  /// Get all businesses for the day
  List<Business> get allBusinesses {
    return [...breakfast, ...lunch, ...dinner, ...activities, ...dessert];
  }

  /// Check if day has any activities
  bool get hasActivities => allBusinesses.isNotEmpty;

  @override
  String toString() {
    return 'DayItinerary{day: $day, breakfast: $breakfast, lunch: $lunch, dinner: $dinner, activities: $activities, dessert: $dessert}';
  }
}

class SavedItinerary {
  final String id;
  final String userId;
  final DateTime createdAt;
  final int totalDays;
  final String city;
  final List<DayItinerary> dayItineraries;
  final Map<int, String> userInteractions;
  final String tripName;

  SavedItinerary({
    required this.id,
    required this.userId,
    required this.createdAt,
    required this.totalDays,
    required this.city,
    required this.dayItineraries,
    this.tripName = "",
    this.userInteractions = const {},
  });

  // Helper to get interaction for a specific business
  InteractionType? getInteractionForBusiness(int businessId) {
    final interactionString = userInteractions[businessId];
    if (interactionString == null) return null;

    return InteractionType.values.firstWhere(
      (e) => e.name == interactionString,
      // orElse: () => InteractionType.none,
    );
  }

  @override
  String toString() {
    return 'SavedItinerary{id: $id, userId: $userId, createdAt: $createdAt, totalDays: $totalDays, city: $city, dayItineraries: $dayItineraries, userInteractions: $userInteractions, tripName: $tripName}';
  }
}

// Delete saved itinerary
Future<void> deleteSavedItinerary({
  required String userId,
  required String tripId,
}) async {
  try {
    await supabase.from('itineraries').delete().eq('user_id', userId).eq('trip_id', tripId);
  } catch (e) {
    throw TravelPlannerException(message: 'Failed to delete itinerary: ${e.toString()}');
  }
}
