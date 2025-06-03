import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

import '../Helpers/Constants.dart';

// Provider for selected country
final selectedCountryProvider = StateProvider<Map<String, String>?>((ref) => null);

// Provider for location detection state
final locationDetectionStateProvider = StateProvider<LocationDetectionState>((ref) => LocationDetectionState.initial);

enum LocationDetectionState {
  initial,
  detecting,
  success,
  failed,
  permissionDenied,
}

// Provider for auto-detecting location
final autoDetectLocationProvider = FutureProvider<Map<String, String>?>((ref) async {
  debugPrint('[Location] Starting auto-detect');

  try {
    // Check if location services are enabled
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    debugPrint('[Location] Service enabled: $serviceEnabled');

    if (!serviceEnabled) {
      ref.read(locationDetectionStateProvider.notifier).state = LocationDetectionState.failed;
      debugPrint('[Location] Location services are disabled');
      return null;
    }

    // Check location permissions
    LocationPermission permission = await Geolocator.checkPermission();
    debugPrint('[Location] Initial permission status: $permission');

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      debugPrint('[Location] Requested permission, new status: $permission');

      if (permission == LocationPermission.denied) {
        ref.read(locationDetectionStateProvider.notifier).state = LocationDetectionState.permissionDenied;
        debugPrint('[Location] Permission denied by user');
        return null;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      ref.read(locationDetectionStateProvider.notifier).state = LocationDetectionState.permissionDenied;
      debugPrint('[Location] Permission denied forever');
      return null;
    }

    ref.read(locationDetectionStateProvider.notifier).state = LocationDetectionState.detecting;
    debugPrint('[Location] Permission granted, detecting location...');

    // Get current position
    Position position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
      timeLimit: const Duration(seconds: 10),
    );

    debugPrint('[Location] Position acquired: lat=${position.latitude}, long=${position.longitude}');

    // Get address from coordinates
    List<Placemark> placemarks = await placemarkFromCoordinates(
      position.latitude,
      position.longitude,
    );

    debugPrint('[Location] Placemarks found: ${placemarks.length}');

    if (placemarks.isNotEmpty) {
      String? countryCode = placemarks.first.isoCountryCode;
      String? countryName = placemarks.first.country;
      debugPrint('[Location] Country code: $countryCode, Country name: $countryName');

      if (countryCode != null) {
        final country = countries.firstWhere(
          (c) => c['code'] == countryCode.toUpperCase(),
          orElse: () {
            debugPrint('[Location] No match found for country code, using fallback');
            return countries.first;
          },
        );

        ref.read(locationDetectionStateProvider.notifier).state = LocationDetectionState.success;
        debugPrint('[Location] Matched country: ${country['name']}');
        return country;
      }
    }

    ref.read(locationDetectionStateProvider.notifier).state = LocationDetectionState.failed;
    debugPrint('[Location] No valid placemark or country code found');
    return null;
  } catch (e, stack) {
    ref.read(locationDetectionStateProvider.notifier).state = LocationDetectionState.failed;
    debugPrint('[Location] Exception occurred: $e');
    debugPrint('[Location] Stack trace:\n$stack');
    return null;
  }
});
