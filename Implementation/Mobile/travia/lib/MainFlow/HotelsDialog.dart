import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:travia/Helpers/PopUp.dart';
import 'package:url_launcher/url_launcher.dart';

import '../Helpers/AppColors.dart';

class HotelBookingDialog extends ConsumerStatefulWidget {
  final String toCity;
  final DateTime startDate;
  final DateTime endDate;

  const HotelBookingDialog({
    super.key,
    required this.toCity,
    required this.startDate,
    required this.endDate,
  });

  @override
  ConsumerState<HotelBookingDialog> createState() => _HotelBookingDialogState();
}

// Add this provider outside your class
final showHotelsSitesProvider = StateProvider<bool>((ref) => false);

class _HotelBookingDialogState extends ConsumerState<HotelBookingDialog> with TickerProviderStateMixin {
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
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final showBookSites = ref.watch(showHotelsSitesProvider);

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
                ...[
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

  Widget _buildHeader() {
    final showHotelSites = ref.watch(showHotelsSitesProvider);
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
              showHotelSites ? 'Choose Your Hotel Site' : 'Hotel Search',
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

  Widget _buildFlightSitesList() {
    final flightSites = HotelSitesData.getAllSites();
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

  Widget _buildFlightSiteCard(HotelSite site, int index) {
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

  Future<void> _openFlightSite(HotelSite site) async {
    try {
      final url = site.buildUrl(
        widget.toCity,
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
class HotelSite {
  final String name;
  final String description;
  final IconData icon;
  final Color primaryColor;
  final Color secondaryColor;
  final String urlTemplate;

  const HotelSite({
    required this.name,
    required this.description,
    required this.icon,
    required this.primaryColor,
    required this.secondaryColor,
    required this.urlTemplate,
  });

  String buildUrl(String to, DateTime startDate, DateTime endDate) {
    // Format dates as required by most booking sites
    final String checkIn = '${startDate.year}-${startDate.month.toString().padLeft(2, '0')}-${startDate.day.toString().padLeft(2, '0')}';
    final String checkOut = '${endDate.year}-${endDate.month.toString().padLeft(2, '0')}-${endDate.day.toString().padLeft(2, '0')}';

    // Replace placeholders in URL template
    String url = urlTemplate
        .replaceAll('{DESTINATION}', Uri.encodeComponent(to))
        .replaceAll('{CHECKIN}', checkIn)
        .replaceAll('{CHECKOUT}', checkOut)
        .replaceAll('{CHECKIN_MONTHDAY}', '${startDate.month.toString().padLeft(2, '0')}/${startDate.day.toString().padLeft(2, '0')}/${startDate.year}')
        .replaceAll('{CHECKOUT_MONTHDAY}', '${endDate.month.toString().padLeft(2, '0')}/${endDate.day.toString().padLeft(2, '0')}/${endDate.year}');

    return url;
  }
}

// Flight sites data
class HotelSitesData {
  static List<HotelSite> getAllSites() {
    return [
      const HotelSite(
        name: 'Booking.com',
        description: 'Millions of properties worldwide',
        icon: Icons.hotel,
        primaryColor: Color(0xFF003580),
        secondaryColor: Color(0xFF0057B8),
        urlTemplate: 'https://www.booking.com/searchresults.html?ss={DESTINATION}&checkin={CHECKIN}&checkout={CHECKOUT}',
      ),
      const HotelSite(
        name: 'Expedia',
        description: 'Bundle flights and hotels for savings',
        icon: Icons.flight_land,
        primaryColor: Color(0xFF003B95),
        secondaryColor: Color(0xFF0066CC),
        urlTemplate: 'https://www.expedia.com/Hotel-Search?destination={DESTINATION}&startDate={CHECKIN}&endDate={CHECKOUT}',
      ),
      const HotelSite(
        name: 'Airbnb',
        description: 'Unique stays and experiences',
        icon: Icons.home,
        primaryColor: Color(0xFFFF5A5F),
        secondaryColor: Color(0xFFFC642D),
        urlTemplate: 'https://www.airbnb.com/s/{DESTINATION}/homes?checkin={CHECKIN}&checkout={CHECKOUT}',
      ),
      const HotelSite(
        name: 'Kayak',
        description: 'Search hundreds of travel sites at once',
        icon: Icons.search,
        primaryColor: Color(0xFFFF690F),
        secondaryColor: Color(0xFFFF8A3D),
        urlTemplate: 'https://www.kayak.com/hotels/{DESTINATION}/{CHECKIN}/{CHECKOUT}?sort=price_a',
      ),
    ];
  }
}

// Usage function to show the dialog
void showHotelBookingDialog({
  required BuildContext context,
  required String toCity,
  required DateTime startDate,
  required DateTime endDate,
}) {
  showDialog(
    context: context,
    barrierDismissible: true,
    builder: (context) => HotelBookingDialog(
      toCity: toCity,
      startDate: startDate,
      endDate: endDate,
    ),
  );
}

class HotelBookingHelper {
  static void openHotelBooking({
    required BuildContext context,
    required String toCity,
    required DateTime departureDate,
    required int tripDays,
  }) {
    final returnDate = departureDate.add(Duration(days: tripDays));
    showHotelBookingDialog(
      context: context,
      toCity: toCity,
      startDate: departureDate,
      endDate: returnDate,
    );
  }
}
