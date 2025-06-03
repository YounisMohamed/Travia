import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../Helpers/AppColors.dart';
import '../Helpers/Constants.dart';
import '../Helpers/DropDown.dart';
import '../Helpers/Loading.dart';
import '../Providers/GeoLocationProvider.dart';

class LocationPicker extends ConsumerWidget {
  final void Function()? onRetryTap;

  const LocationPicker({super.key, this.onRetryTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedCountry = ref.watch(selectedCountryProvider);
    final locationDetectionState = ref.watch(locationDetectionStateProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppCustomDropdownWithIcon<Map<String, String>>(
          hintText: "Select country",
          value: selectedCountry,
          prefixIcon: Icon(Icons.location_on, size: 22, color: kDeepPink),
          items: countries,
          withSearch: true,
          searchHintText: "Search country...",
          displayText: (country) => country['name'] ?? '',
          itemIcon: (country) => Text(
            country['emoji'] ?? '',
            style: TextStyle(fontSize: 20),
          ),
          onChanged: (value) {
            ref.read(selectedCountryProvider.notifier).state = value;
          },
          validator: (value) => value == null ? "Please select a country" : null,
        ),
        if (locationDetectionState == LocationDetectionState.detecting)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Row(
              children: [
                SizedBox(width: 16, height: 16, child: LoadingWidget()),
                SizedBox(width: 15),
                Text(
                  'Detecting your location...',
                  style: TextStyle(fontSize: 12, color: kDeepPinkLight),
                ),
              ],
            ),
          ),
        if (locationDetectionState == LocationDetectionState.failed || locationDetectionState == LocationDetectionState.permissionDenied)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Row(
              children: [
                Icon(Icons.error_outline, size: 16, color: kDeepPinkLight),
                SizedBox(width: 8),
                Text(
                  locationDetectionState == LocationDetectionState.permissionDenied ? 'Location permission denied' : 'Could not detect location, Open location',
                  style: GoogleFonts.lexendDeca(fontSize: 12, color: kDeepPinkLight),
                ),
                SizedBox(width: 8),
                TextButton(
                  onPressed: onRetryTap,
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    '(Retry)',
                    style: GoogleFonts.lexendDeca(fontSize: 12, color: kDeepPink),
                  ),
                ),
              ],
            ),
          ),
        if (locationDetectionState == LocationDetectionState.success)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Row(
              children: [
                SizedBox(width: 8),
                Text(
                  "Location auto detected",
                  style: GoogleFonts.lexendDeca(fontSize: 12, color: kDeepPink),
                ),
                SizedBox(width: 8),
                Icon(Icons.check, color: kDeepPink),
              ],
            ),
          ),
      ],
    );
  }
}
