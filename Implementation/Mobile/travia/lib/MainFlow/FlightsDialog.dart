import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:travia/Helpers/PopUp.dart';
import 'package:url_launcher/url_launcher.dart';

import '../Helpers/AppColors.dart';
import '../Helpers/HelperMethods.dart';
import 'CitySelector.dart';

class FlightBookingDialog extends ConsumerStatefulWidget {
  final String toCity;
  final DateTime startDate;
  final DateTime endDate;

  const FlightBookingDialog({
    super.key,
    required this.toCity,
    required this.startDate,
    required this.endDate,
  });

  @override
  ConsumerState<FlightBookingDialog> createState() => _FlightBookingDialogState();
}

// Add this provider outside your class
final showFlightSitesProvider = StateProvider<bool>((ref) => false);

class _FlightBookingDialogState extends ConsumerState<FlightBookingDialog> with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutBack,
    ));

    _animationController.forward();

    // Auto-detect location on init
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.refresh(autoDetectCityProvider);
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final showFlightSites = ref.watch(showFlightSitesProvider);

    ref.listen(autoDetectCityProvider, (previous, next) {
      if (next.hasValue && next.value != null) {
        ref.read(selectedFromCityProvider.notifier).state = next.value;
      }
    });

    ref.listen(selectedFromCityProvider, (previous, next) {
      if (next == null) {
        ref.read(showFlightSitesProvider.notifier).state = false;
      }
    });

    return Dialog(
      backgroundColor: Colors.transparent,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height,
              maxWidth: MediaQuery.of(context).size.width * 0.9,
            ),
            decoration: BoxDecoration(
              color: kBackground,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: kDeepPink.withOpacity(0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildHeader(),
                if (!showFlightSites) ...[
                  _buildCitySelection(),
                  _buildContinueButton(),
                ] else ...[
                  _buildFlightInfo(),
                  Flexible(
                    child: _buildFlightSitesList(),
                  ),
                  _buildFooter(),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContinueButton() {
    final selectedCity = ref.watch(selectedFromCityProvider);
    final isEnabled = selectedCity != null;

    return Container(
      padding: const EdgeInsets.all(24),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: isEnabled
              ? () {
                  ref.read(showFlightSitesProvider.notifier).state = true;
                }
              : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: isEnabled ? kDeepPink : Colors.grey.shade300,
            foregroundColor: kWhite,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: isEnabled ? 2 : 0,
          ),
          child: Text(
            'Continue to Flight Search',
            style: GoogleFonts.lexendDeca(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final showFlightSites = ref.watch(showFlightSitesProvider);
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [kDeepPink, kDeepPinkLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: kWhite.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.flight_takeoff,
              color: kWhite,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              showFlightSites ? 'Choose Your Flight' : 'Flight Search',
              style: const TextStyle(
                color: kWhite,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close, color: kWhite),
          ),
        ],
      ),
    );
  }

  Widget _buildCitySelection() {
    final selectedCity = ref.watch(selectedFromCityProvider);
    final locationState = ref.watch(locationDetectionStateProvider);

    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Where are you flying from?',
            style: GoogleFonts.ibmPlexSans(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 20),

          // City selector
          GestureDetector(
            onTap: () async {
              final city = await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => CitySelector()),
              );
              if (city != null) {
                ref.read(selectedFromCityProvider.notifier).state = city;
              }
            },
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: selectedCity != null ? kDeepPink : Colors.grey.shade300,
                  width: 1.5,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.location_on,
                    color: selectedCity != null ? kDeepPink : Colors.grey,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      selectedCity ?? 'Select departure city',
                      style: GoogleFonts.lexendDeca(
                        fontSize: 16,
                        color: selectedCity != null ? Colors.black87 : Colors.grey,
                      ),
                    ),
                  ),
                  const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Location detection status
          if (locationState == LocationDetectionState.detecting)
            _buildLocationStatus(
              icon: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(kDeepPinkLight),
                ),
              ),
              text: 'Detecting your location...',
              color: kDeepPinkLight,
            ),

          if (locationState == LocationDetectionState.failed || locationState == LocationDetectionState.permissionDenied)
            _buildLocationStatus(
              icon: Icon(Icons.error_outline, size: 16, color: kDeepPinkLight),
              text: locationState == LocationDetectionState.permissionDenied ? 'Location permission denied' : 'Could not detect location\nYour city might not be supported.',
              color: kDeepPinkLight,
              showRetry: true,
            ),

          if (locationState == LocationDetectionState.success)
            _buildLocationStatus(
              icon: Icon(Icons.check, size: 16, color: kDeepPink),
              text: 'Location auto-detected',
              color: kDeepPink,
            ),
        ],
      ),
    );
  }

  Widget _buildLocationStatus({
    required Widget icon,
    required String text,
    required Color color,
    bool showRetry = false,
  }) {
    return Row(
      children: [
        icon,
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.lexendDeca(fontSize: 10, color: color),
          ),
        ),
        if (showRetry) ...[
          const SizedBox(width: 8),
          TextButton(
            onPressed: () => ref.refresh(autoDetectCityProvider),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              '(Retry)',
              style: GoogleFonts.lexendDeca(fontSize: 12, color: kDeepPink),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildFlightInfo() {
    final selectedFromCity = ref.watch(selectedFromCityProvider);

    return Container(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Expanded(
            child: _buildCityCard(CityAirportMapping.getAirportCode(selectedFromCity!), 'From', Icons.flight_takeoff),
          ),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 12),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: kDeepPink.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.compare_arrows,
              color: kDeepPink,
              size: 24,
            ),
          ),
          Expanded(
            child: _buildCityCard(widget.toCity, 'To', Icons.flight_land),
          ),
        ],
      ),
    );
  }

  Widget _buildCityCard(String city, String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kDeepPink.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(
            color: kDeepPink.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: kDeepPink, size: 20),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            city.toUpperCase(),
            style: const TextStyle(
              color: Colors.black87,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFlightSitesList() {
    final flightSites = FlightSitesData.getAllSites();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Flexible(
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: flightSites.length,
          itemBuilder: (context, index) {
            final site = flightSites[index];
            return _buildFlightSiteCard(site, index);
          },
        ),
      ),
    );
  }

  Widget _buildFlightSiteCard(FlightSite site, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _openFlightSite(site),
          borderRadius: BorderRadius.circular(16),
          child: AnimatedContainer(
            duration: Duration(milliseconds: 200 + (index * 50)),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: kWhite,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: kDeepPink.withOpacity(0.1)),
              boxShadow: [
                BoxShadow(
                  color: kDeepPink.withOpacity(0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [site.primaryColor, site.secondaryColor],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    site.icon,
                    color: kWhite,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        site.name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        site.description,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: kDeepPink.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.arrow_forward_ios,
                    color: kDeepPink,
                    size: 16,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Icon(
            Icons.info_outline,
            color: Colors.grey[600],
            size: 16,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Dates: ${DateFormat('MMM dd').format(widget.startDate)} - ${DateFormat('MMM dd, yyyy').format(widget.endDate)}',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openFlightSite(FlightSite site) async {
    final selectedFromCity = ref.read(selectedFromCityProvider);
    if (selectedFromCity == null) return;

    try {
      final fromCode = CityAirportMapping.getAirportCode(selectedFromCity);
      final toCode = CityAirportMapping.getAirportCode(widget.toCity);

      final url = site.buildUrl(
        fromCode,
        toCode,
        widget.startDate,
        widget.endDate,
      );

      if (await canLaunchUrl(Uri.parse(url))) {
        await launchUrl(
          Uri.parse(url),
          mode: LaunchMode.externalApplication,
        );
        Navigator.of(context).pop();
      } else {
        Popup.showError(text: "Could not open site", context: context);
      }
    } catch (e) {
      print(e);
      Popup.showError(text: "Error opening", context: context);
    }
  }
}

// Flight site data model
class FlightSite {
  final String name;
  final String description;
  final IconData icon;
  final Color primaryColor;
  final Color secondaryColor;
  final String urlTemplate;

  const FlightSite({
    required this.name,
    required this.description,
    required this.icon,
    required this.primaryColor,
    required this.secondaryColor,
    required this.urlTemplate,
  });

  String buildUrl(String from, String to, DateTime startDate, DateTime endDate) {
    final String formattedStart = DateFormat('yyyy-MM-dd').format(startDate);
    final String formattedEnd = DateFormat('yyyy-MM-dd').format(endDate);

    String url = urlTemplate.replaceAll('{FROM}', from.toUpperCase()).replaceAll('{TO}', to.toUpperCase()).replaceAll('{DEPARTURE_DATE}', formattedStart).replaceAll('{RETURN_DATE}', formattedEnd);

    return url;
  }
}

// Flight sites data
class FlightSitesData {
  static List<FlightSite> getAllSites() {
    return [
      const FlightSite(
        name: 'Google Flights',
        description: 'Comprehensive search with price tracking',
        icon: Icons.travel_explore,
        primaryColor: Color(0xFF4285F4),
        secondaryColor: Color(0xFF34A853),
        urlTemplate: 'https://www.google.com/travel/flights?q=Flights%20from%20{FROM}%20to%20{TO}%20on%20{DEPARTURE_DATE}%20through%20{RETURN_DATE}&curr=USD&hl=en',
      ),
      const FlightSite(
        name: 'Kayak',
        description: 'Compare flights from hundreds of sites',
        icon: Icons.search,
        primaryColor: Color(0xFFFF690F),
        secondaryColor: Color(0xFFFF8A3D),
        urlTemplate: 'https://www.kayak.com/flights/{FROM}-{TO}/{DEPARTURE_DATE}/{RETURN_DATE}?sort=price_a',
      ),
      const FlightSite(
        name: 'Expedia',
        description: 'Bundle flights with hotels for savings',
        icon: Icons.flight_takeoff,
        primaryColor: Color(0xFF003B95),
        secondaryColor: Color(0xFF0066CC),
        urlTemplate:
            'https://www.expedia.com/Flights-Search?flight-type=on&mode=search&trip=roundtrip&leg1=from%3A{FROM}%2Cto%3A{TO}%2Cdeparture%3A{DEPARTURE_DATE}TANYT&leg2=from%3A{TO}%2Cto%3A{FROM}%2Cdeparture%3A{RETURN_DATE}TANYT&options=cabinclass%3Aeconomy&passengers=adults%3A1%2Cinfantinlap%3AN',
      ),
      const FlightSite(
        name: 'Momondo',
        description: 'Find the cheapest flights worldwide',
        icon: Icons.public,
        primaryColor: Color(0xFF7D1F7C),
        secondaryColor: Color(0xFFA02FA0),
        urlTemplate: 'https://www.momondo.com/flight-search/{FROM}-{TO}/{DEPARTURE_DATE}/{RETURN_DATE}?sort=price_a',
      ),
      const FlightSite(
        name: 'Skyscanner',
        description: 'Flexible date search and everywhere option',
        icon: Icons.flight,
        primaryColor: Color(0xFF00A9FF),
        secondaryColor: Color(0xFF0770E3),
        urlTemplate:
            'https://www.skyscanner.com/transport/flights/{FROM}/{TO}/{DEPARTURE_DATE}/{RETURN_DATE}/?adultsv2=1&cabinclass=economy&ref=home&rtn=1&preferdirects=false&outboundaltsenabled=false&inboundaltsenabled=false',
      ),
    ];
  }
}

// Usage function to show the dialog
void showFlightBookingDialog({
  required BuildContext context,
  required String toCity,
  required DateTime startDate,
  required DateTime endDate,
}) {
  showDialog(
    context: context,
    barrierDismissible: true,
    builder: (context) => FlightBookingDialog(
      toCity: toCity,
      startDate: startDate,
      endDate: endDate,
    ),
  );
}

class FlightBookingHelper {
  static void openFlightBooking({
    required BuildContext context,
    required String toCity,
    required DateTime departureDate,
    required int tripDays,
  }) {
    final String toCode = CityAirportMapping.getAirportCode(toCity)!;
    final returnDate = departureDate.add(Duration(days: tripDays));
    showFlightBookingDialog(
      context: context,
      toCity: toCode,
      startDate: departureDate,
      endDate: returnDate,
    );
  }
}

final selectedFromCityProvider = StateProvider<String?>((ref) => null);
final locationDetectionStateProvider = StateProvider<LocationDetectionState>((ref) => LocationDetectionState.initial);

enum LocationDetectionState {
  initial,
  detecting,
  success,
  failed,
  permissionDenied,
}

// Auto-detect location provider for cities
// Auto-detect location provider for cities
final autoDetectCityProvider = FutureProvider<String?>((ref) async {
  try {
    print('[Location] Starting location detection...');

    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    print('[Location] Service enabled: $serviceEnabled');
    if (!serviceEnabled) {
      ref.read(locationDetectionStateProvider.notifier).state = LocationDetectionState.failed;
      return null;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    print('[Location] Permission status: $permission');
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      print('[Location] After request: $permission');
      if (permission == LocationPermission.denied) {
        ref.read(locationDetectionStateProvider.notifier).state = LocationDetectionState.permissionDenied;
        return null;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      ref.read(locationDetectionStateProvider.notifier).state = LocationDetectionState.permissionDenied;
      return null;
    }

    ref.read(locationDetectionStateProvider.notifier).state = LocationDetectionState.detecting;
    print('[Location] Getting position...');

    Position position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
      timeLimit: const Duration(seconds: 10),
    );
    print('[Location] Position: ${position.latitude}, ${position.longitude}');

    List<Placemark> placemarks = await placemarkFromCoordinates(
      position.latitude,
      position.longitude,
    );
    print('[Location] Placemarks count: ${placemarks.length}');

    if (placemarks.isNotEmpty) {
      final placemark = placemarks.first;
      print('[Location] City: ${placemark.locality}');
      print('[Location] Admin area: ${placemark.administrativeArea}');
      print('[Location] Country: ${placemark.country}');
      print('[Location] Country code: ${placemark.isoCountryCode}');

      String? cityName = placemark.locality ?? placemark.administrativeArea;
      print('[Location] Detected city name: $cityName');

      if (cityName != null && CityAirportMapping.isCitySupported(cityName)) {
        print('[Location] City supported directly');
        ref.read(locationDetectionStateProvider.notifier).state = LocationDetectionState.success;
        return cityName;
      }

      // Fallback to major cities if exact city not found
      String? countryCode = placemark.isoCountryCode;
      print('[Location] Falling back to country code: $countryCode');
      if (countryCode != null) {
        final majorCity = _getMajorCityForCountry(countryCode);
        print('[Location] Major city for country: $majorCity');
        if (majorCity != null) {
          ref.read(locationDetectionStateProvider.notifier).state = LocationDetectionState.success;
          return majorCity;
        }
      }
    }

    print('[Location] No valid location found');
    ref.read(locationDetectionStateProvider.notifier).state = LocationDetectionState.failed;
    return null;
  } catch (e, stackTrace) {
    print('[Location] Exception: $e');
    print('[Location] Stack trace: $stackTrace');
    ref.read(locationDetectionStateProvider.notifier).state = LocationDetectionState.failed;
    return null;
  }
});

// Helper function to get major city for country
String? _getMajorCityForCountry(String countryCode) {
  final Map<String, List<String>> countryToMajorCities = {
    'US': ['New York', 'Los Angeles', 'Chicago', 'Houston', 'Phoenix'],
    'CN': ['Shanghai', 'Beijing', 'Guangzhou', 'Shenzhen', 'Chengdu'],
    'IN': ['Mumbai', 'Delhi', 'Bangalore', 'Hyderabad', 'Chennai'],
    'JP': ['Tokyo', 'Osaka', 'Yokohama', 'Nagoya', 'Sapporo'],
    'DE': ['Berlin', 'Hamburg', 'Munich', 'Cologne', 'Frankfurt'],
    'EG': ['Cairo', 'Alexandria', 'Giza', 'Shubra El Kheima', 'Port Said'],
    'BR': ['São Paulo', 'Rio de Janeiro', 'Brasília', 'Salvador', 'Fortaleza'],
    'GB': ['London', 'Birmingham', 'Manchester', 'Liverpool', 'Leeds'],
    'FR': ['Paris', 'Marseille', 'Lyon', 'Toulouse', 'Nice'],
    'IT': ['Rome', 'Milan', 'Naples', 'Turin', 'Palermo'],
    'CA': ['Toronto', 'Montreal', 'Vancouver', 'Calgary', 'Ottawa'],
    'RU': ['Moscow', 'Saint Petersburg', 'Novosibirsk', 'Yekaterinburg', 'Nizhny Novgorod'],
    'KR': ['Seoul', 'Busan', 'Incheon', 'Daegu', 'Daejeon'],
    'ES': ['Madrid', 'Barcelona', 'Valencia', 'Seville', 'Zaragoza'],
    'AU': ['Sydney', 'Melbourne', 'Brisbane', 'Perth', 'Adelaide'],
    'MX': ['Mexico City', 'Guadalajara', 'Monterrey', 'Puebla', 'Tijuana'],
    'ID': ['Jakarta', 'Surabaya', 'Bandung', 'Bekasi', 'Medan'],
    'NL': ['Amsterdam', 'Rotterdam', 'The Hague', 'Utrecht', 'Eindhoven'],
    'SA': ['Riyadh', 'Jeddah', 'Mecca', 'Medina', 'Dammam'],
    'TR': ['Istanbul', 'Ankara', 'Izmir', 'Bursa', 'Adana'],
    'CH': ['Zurich', 'Geneva', 'Basel', 'Bern', 'Lausanne'],
    'BE': ['Brussels', 'Antwerp', 'Ghent', 'Charleroi', 'Liège'],
    'IR': ['Tehran', 'Mashhad', 'Isfahan', 'Karaj', 'Shiraz'],
    'TH': ['Bangkok', 'Chiang Mai', 'Pattaya', 'Phuket', 'Hat Yai'],
    'ZA': ['Johannesburg', 'Cape Town', 'Durban', 'Pretoria', 'Port Elizabeth'],
    'AR': ['Buenos Aires', 'Córdoba', 'Rosario', 'Mendoza', 'La Plata'],
    'PL': ['Warsaw', 'Krakow', 'Łódź', 'Wrocław', 'Poznań'],
    'UA': ['Kyiv', 'Kharkiv', 'Odesa', 'Dnipro', 'Donetsk'],
    'MY': ['Kuala Lumpur', 'George Town', 'Ipoh', 'Johor Bahru', 'Malacca'],
    'UZ': ['Tashkent', 'Samarkand', 'Namangan', 'Andijan', 'Nukus'],
    'VN': ['Ho Chi Minh City', 'Hanoi', 'Da Nang', 'Hai Phong', 'Can Tho'],
    'PE': ['Lima', 'Arequipa', 'Trujillo', 'Chiclayo', 'Piura'],
    'VE': ['Caracas', 'Maracaibo', 'Valencia', 'Barquisimeto', 'Maracay'],
    'NP': ['Kathmandu', 'Pokhara', 'Lalitpur', 'Bharatpur', 'Biratnagar'],
    'AF': ['Kabul', 'Kandahar', 'Herat', 'Mazar-i-Sharif', 'Jalalabad'],
    'AO': ['Luanda', 'Huambo', 'Lobito', 'Benguela', 'Kuito'],
    'GH': ['Accra', 'Kumasi', 'Tamale', 'Takoradi', 'Cape Coast'],
    'YE': ['Sanaa', 'Aden', 'Taiz', 'Al Hudaydah', 'Ibb'],
    'MG': ['Antananarivo', 'Toamasina', 'Antsirabe', 'Fianarantsoa', 'Mahajanga'],
    'CM': ['Douala', 'Yaoundé', 'Bamenda', 'Bafoussam', 'Garoua'],
    'CI': ['Abidjan', 'Bouaké', 'Daloa', 'San-Pédro', 'Yamoussoukro'],
    'NE': ['Niamey', 'Zinder', 'Maradi', 'Agadez', 'Tahoua'],
    'LK': ['Colombo', 'Kandy', 'Galle', 'Jaffna', 'Negombo'],
    'BF': ['Ouagadougou', 'Bobo-Dioulasso', 'Koudougou', 'Banfora', 'Ouahigouya'],
    'ML': ['Bamako', 'Sikasso', 'Mopti', 'Koutiala', 'Kayes'],
    'MW': ['Lilongwe', 'Blantyre', 'Mzuzu', 'Zomba', 'Kasungu'],
    'ZM': ['Lusaka', 'Kitwe', 'Ndola', 'Kabwe', 'Chingola'],
    'SN': ['Dakar', 'Touba', 'Thiès', 'Kaolack', 'Saint-Louis'],
    'SO': ['Mogadishu', 'Hargeisa', 'Bosaso', 'Kismayo', 'Merca'],
    'CL': ['Santiago', 'Valparaíso', 'Concepción', 'La Serena', 'Antofagasta'],
    'ZW': ['Harare', 'Bulawayo', 'Chitungwiza', 'Mutare', 'Gweru'],
    'GT': ['Guatemala City', 'Villa Nueva', 'Quetzaltenango', 'Villa Canales', 'Escuintla'],
    'SY': ['Damascus', 'Aleppo', 'Homs', 'Latakia', 'Hama'],
    'KH': ['Phnom Penh', 'Siem Reap', 'Battambang', 'Sihanoukville', 'Poipet'],
    'TD': ['N\'Djamena', 'Moundou', 'Sarh', 'Abéché', 'Kelo'],
    'TN': ['Tunis', 'Sfax', 'Sousse', 'Kairouan', 'Bizerte'],
    'BI': ['Gitega', 'Bujumbura', 'Muyinga', 'Ruyigi', 'Ngozi'],
    'BJ': ['Porto-Novo', 'Cotonou', 'Parakou', 'Djougou', 'Bohicon'],
    'JO': ['Amman', 'Zarqa', 'Irbid', 'Russeifa', 'Wadi as-Sir'],
    'AZ': ['Baku', 'Ganja', 'Sumqayit', 'Lankaran', 'Mingachevir'],
    'AT': ['Vienna', 'Graz', 'Linz', 'Salzburg', 'Innsbruck'],
    'HN': ['Tegucigalpa', 'San Pedro Sula', 'Choloma', 'La Ceiba', 'El Progreso'],
    'TJ': ['Dushanbe', 'Khujand', 'Kulob', 'Qurghonteppa', 'Istaravshan'],
    'AE': ['Dubai', 'Abu Dhabi', 'Sharjah', 'Al Ain', 'Ajman'],
    'IL': ['Jerusalem', 'Tel Aviv', 'Haifa', 'Rishon LeZion', 'Petah Tikva'],
    'TG': ['Lomé', 'Sokodé', 'Kara', 'Palimé', 'Atakpamé'],
    'RS': ['Belgrade', 'Novi Sad', 'Niš', 'Kragujevac', 'Subotica'],
    'PG': ['Port Moresby', 'Lae', 'Mount Hagen', 'Popondetta', 'Madang'],
    'LA': ['Vientiane', 'Savannakhet', 'Pakse', 'Luang Prabang', 'Xam Neua'],
    'SL': ['Freetown', 'Bo', 'Kenema', 'Koidu', 'Makeni'],
    'LR': ['Monrovia', 'Gbarnga', 'Kakata', 'Bensonville', 'Harper'],
    'NI': ['Managua', 'León', 'Masaya', 'Matagalpa', 'Chinandega'],
    'CR': ['San José', 'Cartago', 'Puntarenas', 'Limón', 'Alajuela'],
    'IE': ['Dublin', 'Cork', 'Limerick', 'Galway', 'Waterford'],
    'GE': ['Tbilisi', 'Kutaisi', 'Batumi', 'Rustavi', 'Zugdidi'],
    'OM': ['Muscat', 'Salalah', 'Seeb', 'Sohar', 'Nizwa'],
    'PA': ['Panama City', 'San Miguelito', 'Tocumen', 'David', 'Arraiján'],
    'HR': ['Zagreb', 'Split', 'Rijeka', 'Osijek', 'Zadar'],
    'ER': ['Asmara', 'Keren', 'Massawa', 'Assab', 'Mendefera'],
    'BA': ['Sarajevo', 'Banja Luka', 'Tuzla', 'Zenica', 'Mostar'],
    'MN': ['Ulaanbaatar', 'Erdenet', 'Darkhan', 'Choibalsan', 'Murun'],
    'AM': ['Yerevan', 'Gyumri', 'Vanadzor', 'Vagharshapat', 'Hrazdan'],
    'JM': ['Kingston', 'Spanish Town', 'Portmore', 'Montego Bay', 'May Pen'],
    'QA': ['Doha', 'Al Rayyan', 'Umm Salal', 'Al Khor', 'Al Wakrah'],
    'AL': ['Tirana', 'Durrës', 'Vlorë', 'Elbasan', 'Shkodër'],
    'LT': ['Vilnius', 'Kaunas', 'Klaipėda', 'Šiauliai', 'Panevėžys'],
    'NA': ['Windhoek', 'Rundu', 'Walvis Bay', 'Swakopmund', 'Oshakati'],
    'GM': ['Banjul', 'Serekunda', 'Brikama', 'Bakau', 'Farafenni'],
    'BW': ['Gaborone', 'Francistown', 'Molepolole', 'Maun', 'Serowe'],
    'GA': ['Libreville', 'Port-Gentil', 'Franceville', 'Oyem', 'Moanda'],
    'LS': ['Maseru', 'Teyateyaneng', 'Mafeteng', 'Hlotse', 'Mohale\'s Hoek'],
    'GW': ['Bissau', 'Bafatá', 'Gabú', 'Bissorã', 'Bolama'],
    'GQ': ['Malabo', 'Bata', 'Ebebiyin', 'Aconibe', 'Añisoc'],
    'EE': ['Tallinn', 'Tartu', 'Narva', 'Pärnu', 'Kohtla-Järve'],
    'MU': ['Port Louis', 'Beau Bassin-Rose Hill', 'Vacoas-Phoenix', 'Curepipe', 'Quatre Bornes'],
    'SZ': ['Mbabane', 'Manzini', 'Big Bend', 'Malkerns', 'Nhlangano'],
    'DJ': ['Djibouti', 'Ali Sabieh', 'Dikhil', 'Tadjourah', 'Obock'],
    'FJ': ['Suva', 'Lautoka', 'Nadi', 'Labasa', 'Ba'],
    'CY': ['Nicosia', 'Limassol', 'Larnaca', 'Famagusta', 'Paphos'],
    'BH': ['Manama', 'Riffa', 'Muharraq', 'Hamad Town', 'A\'ali'],
    'KM': ['Moroni', 'Mutsamudu', 'Fomboni', 'Domoni', 'Tsémbéhou'],
    'BT': ['Thimphu', 'Phuntsholing', 'Punakha', 'Wangdue', 'Samdrup Jongkhar'],
    'SB': ['Honiara', 'Gizo', 'Auki', 'Kirakira', 'Buala'],
    'LU': ['Luxembourg', 'Esch-sur-Alzette', 'Differdange', 'Dudelange', 'Ettelbruck'],
    'MT': ['Valletta', 'Birkirkara', 'Mosta', 'Qormi', 'Zabbar'],
    'BN': ['Bandar Seri Begawan', 'Kuala Belait', 'Seria', 'Tutong', 'Bangar'],
    'IS': ['Reykjavik', 'Kópavogur', 'Hafnarfjörður', 'Akureyri', 'Garðabær'],
    'MV': ['Malé', 'Addu City', 'Fuvahmulah', 'Kulhudhuffushi', 'Thinadhoo'],
    'BB': ['Bridgetown', 'Speightstown', 'Oistins', 'Bathsheba', 'Holetown'],
    'VU': ['Port Vila', 'Luganville', 'Isangel', 'Sola', 'Lenakel'],
    'WS': ['Apia', 'Vaitele', 'Faleula', 'Siusega', 'Malie'],
    'ST': ['São Tomé', 'Santo António', 'Neves', 'Santana', 'Guadalupe'],
    'LC': ['Castries', 'Bisée', 'Vieux Fort', 'Micoud', 'Soufrière'],
    'KI': ['South Tarawa', 'Betio', 'Bikenibeu', 'Teaoraereke', 'Bairiki'],
    'AD': ['Andorra la Vella', 'Escaldes-Engordany', 'Sant Julià de Lòria', 'Encamp', 'La Massana'],
    'PW': ['Ngerulmud', 'Koror', 'Airai', 'Melekeok', 'Peleliu'],
    'SC': ['Victoria', 'Anse Boileau', 'Beau Vallon', 'Takamaka', 'Glacis'],
    'AG': ['St. John\'s', 'All Saints', 'Liberta', 'Potter\'s Village', 'Bolans'],
    'TO': ['Nuku\'alofa', 'Neiafu', 'Haveluloto', 'Vaini', 'Pangai'],
    'DM': ['Roseau', 'Portsmouth', 'Marigot', 'Berekua', 'Saint Joseph'],
    'FM': ['Palikir', 'Weno', 'Tofol', 'Colonia', 'Lelu'],
    'MH': ['Majuro', 'Ebeye', 'Arno', 'Jaluit', 'Wotje'],
    'KN': ['Basseterre', 'Charlestown', 'Newcastle', 'Gingerland', 'Cayon'],
    'LI': ['Vaduz', 'Schaan', 'Balzers', 'Triesen', 'Eschen'],
    'SM': ['City of San Marino', 'Serravalle', 'Borgo Maggiore', 'Domagnano', 'Fiorentino'],
    'TV': ['Funafuti', 'Savave', 'Tanrake', 'Toga', 'Asau'],
    'NR': ['Yaren', 'Aiwo', 'Anabar', 'Anetan', 'Anibare'],
    'MC': ['Monaco', 'Monte Carlo', 'La Condamine', 'Fontvieille', 'Larvotto'],
    'VA': ['Vatican City'],
  };

  // Get the list of cities for the country
  final List<String>? cities = countryToMajorCities[countryCode];

  if (cities == null || cities.isEmpty) {
    print('[Location] No cities found for country code: $countryCode');
    return null;
  }
  final primaryCity = cities.first;
  print('[Location] Using primary city: $primaryCity for country: $countryCode');
  return primaryCity;
}
