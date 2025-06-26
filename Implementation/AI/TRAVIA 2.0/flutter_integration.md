# TRAVIA Flutter Integration Guide

This guide provides the necessary information to integrate the TRAVIA FastAPI backend with a Flutter mobile application.

## API Base URL
```
https://your-domain.com/api/v1
```

## Authentication
Currently, the API uses user IDs for session management. For production, implement proper JWT authentication.

## API Endpoints

### 1. Health Check
- **GET** `/health`
- **Response**: `{"status": "healthy", "database": "connected"}`

### 2. User Management

#### Create User
- **POST** `/users`
- **Body**:
```json
{
  "email": "user@example.com",
  "display_name": "John Doe"
}
```
- **Response**:
```json
{
  "id": "uuid-string",
  "email": "user@example.com", 
  "display_name": "John Doe",
  "created_at": "2024-01-01T00:00:00"
}
```

#### Get All Users
- **GET** `/users`
- **Response**: Array of user objects

#### Get User by ID
- **GET** `/users/{user_id}`
- **Response**: User object

### 3. User Preferences

#### Save Preferences
- **POST** `/users/{user_id}/preferences`
- **Body**:
```json
{
  "budget": 2,
  "travel_days": 5,
  "travel_style": "tourist",
  "noise_preference": "quiet", 
  "family_friendly": false,
  "accommodation_type": "hotel",
  "preferred_cuisine": ["Italian", "Chinese"],
  "ambience_preference": "casual",
  "good_for_kids": false,
  "include_gym": true,
  "include_bar": false,
  "include_nightlife": false,
  "include_beauty_health": true,
  "include_shop": true,
  "location": "Las Vegas, Nevada"
}
```

#### Get User Preferences
- **GET** `/users/{user_id}/preferences`
- **Response**: Preferences object

### 4. Locations

#### Get Available Locations
- **GET** `/locations`
- **Response**:
```json
[
  {
    "locality": "Las Vegas",
    "region": "Nevada", 
    "country": "US",
    "business_count": 5420
  }
]
```

### 5. Itinerary Generation

#### Generate Itinerary
- **POST** `/users/{user_id}/itinerary?locality=Las Vegas&region=Nevada`
- **Response**:
```json
{
  "itinerary": [
    {
      "day": 1,
      "breakfast": [
        {
          "id": 123,
          "name": "Best Breakfast Cafe",
          "locality": "Las Vegas",
          "region": "Nevada",
          "stars": 4.5,
          "price_range": 2,
          "cuisines": ["American", "Coffee"],
          "has_wifi": true,
          "good_for_kids": true
        }
      ],
      "lunch": [...],
      "dinner": [...],
      "activities": [...],
      "dessert": [...]
    }
  ],
  "total_businesses": 150,
  "user_preferences": {...}
}
```

### 6. User Feedback

#### Submit Feedback
- **POST** `/users/{user_id}/feedback`
- **Body**:
```json
{
  "business_id": 123,
  "interaction_type": "like"
}
```

#### Get User Interactions
- **GET** `/users/{user_id}/interactions`
- **Response**: Array of interaction objects

## Flutter HTTP Client Setup

### Dependencies (pubspec.yaml)
```yaml
dependencies:
  flutter:
    sdk: flutter
  http: ^1.1.0
  shared_preferences: ^2.2.2
  json_annotation: ^4.8.1

dev_dependencies:
  flutter_test:
    sdk: flutter
  build_runner: ^2.4.7
  json_serializable: ^6.7.1
```

### API Service Class
```dart
import 'dart:convert';
import 'package:http/http.dart' as http;

class TraviaApiService {
  static const String baseUrl = 'https://your-domain.com/api/v1';
  
  // Headers for all requests
  Map<String, String> get headers => {
    'Content-Type': 'application/json',
  };

  // Create user
  Future<User> createUser(String email, String displayName) async {
    final response = await http.post(
      Uri.parse('$baseUrl/users'),
      headers: headers,
      body: jsonEncode({
        'email': email,
        'display_name': displayName,
      }),
    );

    if (response.statusCode == 200) {
      return User.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to create user');
    }
  }

  // Get locations
  Future<List<Location>> getLocations() async {
    final response = await http.get(
      Uri.parse('$baseUrl/locations'),
      headers: headers,
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => Location.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load locations');
    }
  }

  // Save preferences
  Future<void> savePreferences(String userId, UserPreferences preferences) async {
    final response = await http.post(
      Uri.parse('$baseUrl/users/$userId/preferences'),
      headers: headers,
      body: jsonEncode(preferences.toJson()),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to save preferences');
    }
  }

  // Generate itinerary
  Future<Itinerary> generateItinerary(String userId, String locality, String region) async {
    final response = await http.post(
      Uri.parse('$baseUrl/users/$userId/itinerary?locality=$locality&region=$region'),
      headers: headers,
    );

    if (response.statusCode == 200) {
      return Itinerary.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to generate itinerary');
    }
  }

  // Submit feedback
  Future<void> submitFeedback(String userId, int businessId, String interactionType) async {
    final response = await http.post(
      Uri.parse('$baseUrl/users/$userId/feedback'),
      headers: headers,
      body: jsonEncode({
        'business_id': businessId,
        'interaction_type': interactionType,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to submit feedback');
    }
  }
}
```

### Data Models

#### User Model
```dart
import 'package:json_annotation/json_annotation.dart';

part 'user.g.dart';

@JsonSerializable()
class User {
  final String id;
  final String? email;
  @JsonKey(name: 'display_name')
  final String displayName;
  @JsonKey(name: 'created_at')
  final DateTime createdAt;

  User({
    required this.id,
    this.email,
    required this.displayName,
    required this.createdAt,
  });

  factory User.fromJson(Map<String, dynamic> json) => _$UserFromJson(json);
  Map<String, dynamic> toJson() => _$UserToJson(this);
}
```

#### Location Model
```dart
@JsonSerializable()
class Location {
  final String locality;
  final String region;
  final String country;
  @JsonKey(name: 'business_count')
  final int businessCount;

  Location({
    required this.locality,
    required this.region,
    required this.country,
    required this.businessCount,
  });

  factory Location.fromJson(Map<String, dynamic> json) => _$LocationFromJson(json);
  Map<String, dynamic> toJson() => _$LocationToJson(this);
  
  String get displayName => '$locality, $region';
}
```

#### Business Model
```dart
@JsonSerializable()
class Business {
  final int id;
  final String name;
  final String? locality;
  final String? region;
  final String? country;
  final double? stars;
  @JsonKey(name: 'review_count')
  final int? reviewCount;
  @JsonKey(name: 'price_range')
  final int? priceRange;
  @JsonKey(name: 'primary_category')
  final String? primaryCategory;
  final List<String>? categories;
  final List<String>? cuisines;
  final String? phone;
  final String? website;
  final List<String>? photos;
  @JsonKey(name: 'has_wifi')
  final bool? hasWifi;
  @JsonKey(name: 'has_delivery')
  final bool? hasDelivery;
  @JsonKey(name: 'good_for_kids')
  final bool? goodForKids;

  Business({
    required this.id,
    required this.name,
    this.locality,
    this.region,
    this.country,
    this.stars,
    this.reviewCount,
    this.priceRange,
    this.primaryCategory,
    this.categories,
    this.cuisines,
    this.phone,
    this.website,
    this.photos,
    this.hasWifi,
    this.hasDelivery,
    this.goodForKids,
  });

  factory Business.fromJson(Map<String, dynamic> json) => _$BusinessFromJson(json);
  Map<String, dynamic> toJson() => _$BusinessToJson(this);
}
```

## State Management with Provider

### User Provider
```dart
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UserProvider with ChangeNotifier {
  User? _currentUser;
  UserPreferences? _preferences;

  User? get currentUser => _currentUser;
  UserPreferences? get preferences => _preferences;

  // Set current user and save to storage
  Future<void> setUser(User user) async {
    _currentUser = user;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_id', user.id);
    notifyListeners();
  }

  // Load saved user
  Future<void> loadSavedUser() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('user_id');
    if (userId != null) {
      // Load user from API
      // _currentUser = await apiService.getUser(userId);
      notifyListeners();
    }
  }

  // Update preferences
  void updatePreferences(UserPreferences preferences) {
    _preferences = preferences;
    notifyListeners();
  }
}
```

## Example Flutter Screens

### Location Selection Screen
```dart
class LocationSelectionScreen extends StatefulWidget {
  @override
  _LocationSelectionScreenState createState() => _LocationSelectionScreenState();
}

class _LocationSelectionScreenState extends State<LocationSelectionScreen> {
  List<Location> locations = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    loadLocations();
  }

  Future<void> loadLocations() async {
    try {
      final apiService = TraviaApiService();
      final loadedLocations = await apiService.getLocations();
      setState(() {
        locations = loadedLocations;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      // Handle error
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text('Select Destination')),
      body: ListView.builder(
        itemCount: locations.length,
        itemBuilder: (context, index) {
          final location = locations[index];
          return ListTile(
            title: Text(location.displayName),
            subtitle: Text('${location.businessCount} businesses'),
            onTap: () {
              // Navigate to preferences or itinerary
              Navigator.pushNamed(
                context, 
                '/preferences',
                arguments: location,
              );
            },
          );
        },
      ),
    );
  }
}
```

This setup provides a complete foundation for Flutter integration with the TRAVIA FastAPI backend. The API is designed to be mobile-friendly with proper error handling, data validation, and efficient endpoints for mobile usage patterns. 