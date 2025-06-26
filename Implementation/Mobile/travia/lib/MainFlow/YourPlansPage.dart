import 'dart:math';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:travia/Helpers/Loading.dart';
import 'package:travia/Helpers/PopUp.dart';

import '../Classes/DayItinerary.dart';
import '../Helpers/AppColors.dart';
import '../Services/PlannerService.dart';
import '../main.dart';
import 'SharePlanDialog.dart';

// Provider for saved itineraries
final savedItinerariesProvider = FutureProvider<List<SavedItinerary>>((ref) async {
  final userId = FirebaseAuth.instance.currentUser!.uid;
  final planner = TravelPlannerService.instance;
  return planner.getSavedItineraries(userId: userId);
});

// Group itineraries by city
final itinerariesByCityProvider = Provider<Map<String, List<SavedItinerary>>>((ref) {
  final itinerariesAsync = ref.watch(savedItinerariesProvider);

  return itinerariesAsync.when(
    data: (itineraries) {
      final Map<String, List<SavedItinerary>> grouped = {};
      for (final itinerary in itineraries) {
        grouped.putIfAbsent(itinerary.city, () => []).add(itinerary);
      }
      return grouped;
    },
    loading: () => {},
    error: (_, __) => {},
  );
});

class YourPlansPage extends ConsumerStatefulWidget {
  const YourPlansPage({Key? key}) : super(key: key);

  @override
  ConsumerState<YourPlansPage> createState() => _YourPlansPageState();
}

class _YourPlansPageState extends ConsumerState<YourPlansPage> {
  final Map<String, TextEditingController> _nameControllers = {};
  final Map<String, bool> _isEditingName = {};
  String currentUserId = FirebaseAuth.instance.currentUser!.uid;

  @override
  void dispose() {
    for (final controller in _nameControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _refreshPlans() async {
    try {
      // Refresh the itineraries provider
      ref.invalidate(savedItinerariesProvider);

      // Optional: Show success feedback
      if (mounted) {
        Popup.showSuccess(text: 'Plans refreshed successfully', context: context);
      }
    } catch (e) {
      // Handle refresh error
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to refresh plans',
              style: GoogleFonts.lexendDeca(
                fontSize: 14,
                color: Colors.white,
              ),
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final itinerariesByCity = ref.watch(itinerariesByCityProvider);
    final itinerariesAsync = ref.watch(savedItinerariesProvider);

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: itinerariesAsync.when(
        loading: () => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              LoadingWidget(
                size: 24,
              ),
              const SizedBox(height: 16),
              Text(
                'Loading your plans...',
                style: GoogleFonts.lexendDeca(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
        error: (error, stack) => RefreshIndicator(
          onRefresh: _refreshPlans,
          color: kDeepPink,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: SizedBox(
              height: MediaQuery.of(context).size.height - 100,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.error_outline,
                        size: 48,
                        color: Colors.red.shade400,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Oops! Something went wrong',
                      style: GoogleFonts.lexendDeca(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[800],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Failed to load your travel plans',
                      style: GoogleFonts.lexendDeca(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Pull down to refresh or tap the button below',
                      style: GoogleFonts.lexendDeca(
                        fontSize: 12,
                        color: Colors.grey[500],
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: _refreshPlans,
                      icon: const Icon(Icons.refresh, size: 20),
                      label: const Text('Try Again'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kDeepPink,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        data: (itineraries) {
          if (itineraries.isEmpty) {
            return RefreshIndicator(
              onRefresh: _refreshPlans,
              displacement: 32,
              color: Colors.black,
              backgroundColor: Colors.white,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: SizedBox(
                  height: MediaQuery.of(context).size.height - 100,
                  child: _buildEmptyState(),
                ),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: _refreshPlans,
            color: kDeepPink,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                // Stats Header
                SliverToBoxAdapter(
                  child: _buildModernStatsHeader(itineraries),
                ),

                // Cities and Plans
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final entry = itinerariesByCity.entries.elementAt(index);
                      return _buildModernCitySection(
                        city: entry.key,
                        plans: entry.value,
                      );
                    },
                    childCount: itinerariesByCity.entries.length,
                  ),
                ),

                // Bottom padding
                const SliverToBoxAdapter(
                  child: SizedBox(height: 100),
                ),
              ],
            ),
          );
        },
      ),
      floatingActionButton: _buildFloatingActionButton(), // Add this line
    );
  }

  Widget? _buildFloatingActionButton() {
    return FloatingActionButton(
      mini: true,
      backgroundColor: kDeepPink,
      foregroundColor: Colors.white,
      onPressed: _refreshPlans,
      child: const Icon(Icons.refresh),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    kDeepPinkLight.withOpacity(0.2),
                    kDeepPink.withOpacity(0.1),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.travel_explore,
                size: 70,
                color: kDeepPink,
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'No Travel Plans Yet',
              style: GoogleFonts.lexendDeca(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: Colors.grey[900],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Start planning your dream vacation\nand create unforgettable memories',
              textAlign: TextAlign.center,
              style: GoogleFonts.lexendDeca(
                fontSize: 15,
                color: Colors.grey[600],
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModernStatsHeader(List<SavedItinerary> itineraries) {
    final totalPlans = itineraries.length;
    final totalCities = itineraries.map((i) => i.city).toSet().length;

    return Container(
      margin: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Plans Statistics',
            style: GoogleFonts.lexendDeca(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Colors.grey[900],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildModernStatCard(
                  icon: Icons.map_outlined,
                  value: totalPlans.toString(),
                  label: 'Plans',
                  color: kDeepPink,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildModernStatCard(
                  icon: Icons.location_city_rounded,
                  value: totalCities.toString(),
                  label: 'Cities',
                  color: Colors.orange,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildModernStatCard({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: GoogleFonts.lexendDeca(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: Colors.grey[900],
            ),
          ),
          Text(
            label,
            style: GoogleFonts.lexendDeca(
              fontSize: 13,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernCitySection({
    required String city,
    required List<SavedItinerary> plans,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: kDeepPink.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.location_on,
                  color: kDeepPink,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  city,
                  style: GoogleFonts.lexendDeca(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey[900],
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${plans.length} ${plans.length == 1 ? 'plan' : 'plans'}',
                  style: GoogleFonts.lexendDeca(
                    fontSize: 13,
                    color: Colors.grey[700],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 300,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: plans.length,
            itemBuilder: (context, index) {
              return _buildModernPlanCard(plans[index], index + 1);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildModernPlanCard(SavedItinerary itinerary, int index) {
    if (!_nameControllers.containsKey(itinerary.id)) {
      _nameControllers[itinerary.id] = TextEditingController(
        text: itinerary.tripName == "" ? 'Plan $index' : itinerary.tripName,
      );
      _isEditingName[itinerary.id] = false;
    }

    return SizedBox(
      height: 300,
      width: 300,
      child: Container(
        margin: const EdgeInsets.only(right: 16, bottom: 8),
        child: Card(
          elevation: 0,
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(
              color: Colors.grey.shade200,
              width: 1,
            ),
          ),
          child: InkWell(
            onTap: () {
              context.push('/plan-result/${itinerary.id}');
            },
            borderRadius: BorderRadius.circular(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: 150,
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                    child: BusinessCarousel(
                      itinerary: itinerary,
                      onSaveName: _saveTripName,
                    ),
                  ),
                ), // Details section
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Info pills
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _buildInfoPill(
                              icon: Icons.calendar_today,
                              text: '${itinerary.totalDays} ${itinerary.totalDays == 1 ? 'day' : 'days'}',
                              color: kDeepPink,
                            ),
                            _buildInfoPill(
                              icon: Icons.place,
                              text: '${itinerary.totalPlaces} places',
                              color: Colors.blue,
                            ),
                          ],
                        ),
                        // Bottom row
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              DateFormat('MMM d, yyyy').format(itinerary.createdAt),
                              style: GoogleFonts.lexendDeca(
                                fontSize: 12,
                                color: Colors.grey[500],
                              ),
                            ),
                            Row(
                              children: [
                                IconButton(
                                  onPressed: () {
                                    showSharePlanDialog(
                                      context,
                                      itinerary.id,
                                      _nameControllers[itinerary.id]!.text,
                                      itinerary.city,
                                    );
                                  },
                                  icon: Icon(
                                    Icons.share_outlined,
                                    size: 20,
                                    color: Colors.grey[600],
                                  ),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                                const SizedBox(width: 12),
                                IconButton(
                                  onPressed: () {
                                    deleteSavedItinerary(userId: currentUserId, tripId: itinerary.id);
                                  },
                                  icon: Icon(
                                    Icons.delete_outline,
                                    size: 20,
                                    color: Colors.red[400],
                                  ),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoPill({
    required IconData icon,
    required String text,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            text,
            style: GoogleFonts.lexendDeca(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _saveTripName(String tripId, String name) async {
    try {
      final planner = TravelPlannerService.instance;
      await planner.updateTripName(tripId: tripId, name: name);
      Popup.showSuccess(text: 'Plan name updated', context: context);
    } catch (e) {
      // Handle error
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to update name',
            style: GoogleFonts.lexendDeca(),
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }
}

// Extension to get total places count
extension SavedItineraryExtension on SavedItinerary {
  int get totalPlaces {
    return dayItineraries.fold(0, (sum, day) => sum + day.allBusinesses.length);
  }
}

// Add this method to TravelPlannerService
extension TravelPlannerServiceExtension on TravelPlannerService {
  Future<void> updateTripName({
    required String tripId,
    required String name,
  }) async {
    try {
      await supabase.from('itineraries').update({'trip_name': name}).eq('trip_id', tripId);
    } catch (e) {
      throw TravelPlannerException(message: 'Failed to update trip name: ${e.toString()}');
    }
  }
}

class BusinessCarousel extends StatefulWidget {
  final SavedItinerary itinerary;
  final Future<void> Function(String tripId, String name) onSaveName;

  const BusinessCarousel({
    super.key,
    required this.itinerary,
    required this.onSaveName,
  });

  @override
  State<BusinessCarousel> createState() => _BusinessCarouselState();
}

class _BusinessCarouselState extends State<BusinessCarousel> {
  late TextEditingController _controller;
  bool _isEditing = false;
  final random = Random();
  List<String> imageUrls = [];

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.itinerary.tripName);
    _generateImageUrls();
  }

  void _generateImageUrls() {
    for (final day in widget.itinerary.dayItineraries) {
      for (final business in day.allBusinesses) {
        if (business.photos != null && business.photos!.isNotEmpty) {
          final photo = business.photos![random.nextInt(business.photos!.length)];
          imageUrls.add(photo);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (imageUrls.isEmpty) {
      return const Center(child: Text('No images available'));
    }

    return Stack(
      children: [
        CarouselSlider(
          options: CarouselOptions(
            height: double.infinity,
            autoPlay: true,
            viewportFraction: 1.0,
            disableCenter: true,
            scrollPhysics: const NeverScrollableScrollPhysics(),
            autoPlayInterval: const Duration(seconds: 6),
            autoPlayAnimationDuration: const Duration(milliseconds: 800),
          ),
          items: imageUrls.map((url) {
            return CachedNetworkImage(
              imageUrl: url,
              fit: BoxFit.cover,
              width: double.infinity,
              placeholder: (context, url) => Container(
                color: Colors.grey[300],
                child: const Center(child: LoadingWidget()),
              ),
              errorWidget: (context, url, error) => Container(
                color: Colors.grey[300],
                child: const Icon(Icons.broken_image, size: 40, color: Colors.grey),
              ),
            );
          }).toList(),
        ),
        // Top-right edit icon
        Positioned(
          top: 12,
          right: 12,
          child: GestureDetector(
            onTap: () async {
              if (_isEditing) {
                await widget.onSaveName(widget.itinerary.id, _controller.text);
              }
              setState(() => _isEditing = !_isEditing);
            },
            child: Icon(
              _isEditing ? Icons.check : Icons.edit,
              color: Colors.white,
              size: 28,
            ),
          ),
        ),
        // Bottom plan name
        Positioned(
          left: 16,
          right: 16,
          bottom: 12,
          child: _isEditing
              ? TextField(
                  controller: _controller,
                  style: GoogleFonts.lexendDeca(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                  cursorColor: Colors.white,
                  decoration: const InputDecoration(
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    filled: true,
                    fillColor: Colors.black45,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(12)),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onSubmitted: (value) async {
                    await widget.onSaveName(widget.itinerary.id, value);
                    setState(() => _isEditing = false);
                  },
                )
              : Text(
                  _controller.text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.lexendDeca(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
        ),
      ],
    );
  }
}
