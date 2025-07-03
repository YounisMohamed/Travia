import 'dart:math';
import 'dart:ui';

import 'package:carousel_slider/carousel_slider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:travia/Helpers/AppColors.dart';
import 'package:travia/MainFlow/HotelsDialog.dart';
import 'package:url_launcher/url_launcher.dart';

import '../Classes/Businesses.dart';
import '../Classes/DayItinerary.dart';
import '../Classes/UserPreferences.dart';
import '../Services/PlannerService.dart';
import '../Services/UserInteractionService.dart';
import '../main.dart';
import 'FlightsDialog.dart';
import 'RealTimeEvents.dart';

// Providers

final fullItineraryProvider = FutureProvider.family<ItineraryResponse, String>((ref, tripId) async {
  final itineraryDataList = await supabase.from('itineraries').select().eq('trip_id', tripId).order('day_number', ascending: true);
  if (itineraryDataList.isEmpty) {
    throw Exception('No itinerary found for trip $tripId');
  }
  final Set<int> allBusinessIds = {};
  for (final dayData in itineraryDataList) {
    allBusinessIds.addAll(List<int>.from(dayData['business_ids'] ?? []));
  }
  List<dynamic> businessesData = [];
  Map<int, Business> businessMap = {};
  if (allBusinessIds.isNotEmpty) {
    businessesData = await supabase.from('businesses').select().inFilter('id', allBusinessIds.toList());
    for (final businessData in businessesData) {
      final business = Business.fromJson(businessData);
      businessMap[business.id] = business;
    }
  }
  final allBusinesses = businessesData.map((json) => Business.fromJson(json)).toList();
  UserPreferences? userPreferences;
  if (itineraryDataList.isNotEmpty) {
    final preferencesSnapshot = itineraryDataList.first['preferences_snapshot'] as Map<String, dynamic>?;
    if (preferencesSnapshot != null) {
      userPreferences = UserPreferences.fromJson(preferencesSnapshot);
    }
  }
  final dayItineraries = itineraryDataList.map((dayData) {
    final businessesByCategory = dayData['businesses_by_category'] as Map<String, dynamic>;
    return DayItinerary(
      day: dayData['day_number'] as int,
      breakfast: _getBusinessesForCategory(businessesByCategory, 'breakfast', businessMap),
      lunch: _getBusinessesForCategory(businessesByCategory, 'lunch', businessMap),
      dinner: _getBusinessesForCategory(businessesByCategory, 'dinner', businessMap),
      dessert: _getBusinessesForCategory(businessesByCategory, 'dessert', businessMap),
      activities: _getBusinessesForCategory(businessesByCategory, 'activities', businessMap),
    );
  }).toList();
  final String trip_name = itineraryDataList.first["trip_name"];
  return ItineraryResponse(itinerary: dayItineraries, totalBusinesses: allBusinesses.length, userPreferences: userPreferences, trip_name: trip_name);
});
List<Business> _getBusinessesForCategory(Map<String, dynamic> categories, String category, Map<int, Business> businessMap) {
  return (categories[category] as List? ?? []).map((id) => businessMap[id as int]).whereType<Business>().toList();
}

final selectedDayProvider = StateProvider<int>((ref) => 0);
final expandedBusinessProvider = StateProvider<String?>((ref) => null);

final userInteractionsProvider = FutureProvider.family<void, String>((ref, userId) async {
  final service = UserInteractionService();
  // Always force refresh to get latest data from database
  await service.loadUserInteractions(userId, forceRefresh: true);
});

// Create a combined provider that loads both itinerary and interactions
final planWithInteractionsProvider = FutureProvider.family<ItineraryResponse, String>((ref, tripId) async {
  final userId = FirebaseAuth.instance.currentUser!.uid;
  final futures = await Future.wait([
    ref.watch(fullItineraryProvider(tripId).future),
    ref.watch(userInteractionsProvider(userId).future),
  ]);
  return futures[0] as ItineraryResponse;
});

class PlanResultPage extends ConsumerWidget {
  final String tripId;

  const PlanResultPage({
    Key? key,
    required this.tripId,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Use the combined provider instead of just the itinerary provider
    final planAsync = ref.watch(planWithInteractionsProvider(tripId));

    return planAsync.when(
      loading: () => Scaffold(
        backgroundColor: kBackground,
        appBar: AppBar(forceMaterialTransparency: true),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: kDeepPink),
              const SizedBox(height: 16),
              Text(
                'Loading your travel plan...',
                style: GoogleFonts.lexendDeca(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ),
      error: (err, stack) => Scaffold(
        backgroundColor: kBackground,
        appBar: AppBar(
          forceMaterialTransparency: true,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_ios_new, color: Colors.black87),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: Colors.red[300],
              ),
              const SizedBox(height: 16),
              Text(
                'Failed to load plan',
                style: GoogleFonts.lexendDeca(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[800],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                err.toString(),
                style: GoogleFonts.lexendDeca(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
      data: (itinerary) {
        final city = itinerary.city;
        final tripStartDate = itinerary.allUniqueBusinesses.isNotEmpty && itinerary.allUniqueBusinesses.first.createdAt != null ? itinerary.allUniqueBusinesses.first.createdAt! : DateTime.now();

        return DefaultTabController(
          length: itinerary.totalDays,
          child: Scaffold(
            backgroundColor: kBackground,
            appBar: AppBar(
              forceMaterialTransparency: true,
              backgroundColor: kBackground,
              elevation: 0,
              leading: IconButton(
                icon: Icon(Icons.arrow_back_ios_new, color: Colors.black87),
                onPressed: () => Navigator.pop(context),
              ),
              title: Column(
                children: [
                  Text(
                    itinerary.trip_name,
                    style: GoogleFonts.lexendDeca(
                      color: Colors.black87,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    '${itinerary.totalDays} Days in $city',
                    style: GoogleFonts.lexendDeca(
                      color: Colors.grey[600],
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
              centerTitle: true,
              bottom: PreferredSize(
                preferredSize: Size.fromHeight(48),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.1),
                        spreadRadius: 1,
                        blurRadius: 3,
                        offset: Offset(0, 1),
                      ),
                    ],
                  ),
                  child: TabBar(
                    labelColor: kDeepPink,
                    unselectedLabelColor: Colors.grey[500],
                    labelStyle: GoogleFonts.lexendDeca(fontWeight: FontWeight.w600, fontSize: 15),
                    unselectedLabelStyle: GoogleFonts.lexendDeca(fontWeight: FontWeight.w400),
                    indicatorColor: kDeepPink,
                    indicatorWeight: 3,
                    tabs: List.generate(itinerary.totalDays, (index) => Tab(text: 'Day ${index + 1}')),
                  ),
                ),
              ),
            ),
            body: TabBarView(
              children: List.generate(itinerary.totalDays, (index) {
                final dayItinerary = itinerary.itinerary[index];
                return _buildDayView(
                  dayItinerary,
                  ref,
                  tripStartDate: tripStartDate,
                  city: city,
                  totalDays: itinerary.totalDays,
                  context: context,
                );
              }),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDayView(DayItinerary dayItinerary, WidgetRef ref, {required DateTime tripStartDate, required String city, required int totalDays, required BuildContext context}) {
    final optimizedBreakfast = _optimizeRoute(dayItinerary.breakfast);
    final optimizedActivities = _optimizeRoute(dayItinerary.activities);
    final optimizedLunch = _optimizeRoute(dayItinerary.lunch);
    final optimizedDinner = _optimizeRoute(dayItinerary.dinner);
    final optimizedDessert = _optimizeRoute(dayItinerary.dessert);

    return ListView(
      padding: EdgeInsets.all(16),
      children: [
        _buildDateHeader(dayItinerary.day, tripStartDate),
        _buildDayStats(dayItinerary),
        if (optimizedBreakfast.isNotEmpty) ...[
          _buildSectionHeader('Breakfast', Icons.free_breakfast),
          for (int i = 0; i < optimizedBreakfast.length; i++)
            _buildBusinessCard(
              optimizedBreakfast[i],
              'breakfast',
              ref,
              previousBusiness: i > 0 ? optimizedBreakfast[i - 1] : null,
            ),
        ],
        if (optimizedLunch.isNotEmpty) ...[
          _buildSectionHeader('Lunch', Icons.lunch_dining),
          for (int i = 0; i < optimizedLunch.length; i++)
            _buildBusinessCard(
              optimizedLunch[i],
              'lunch',
              ref,
              previousBusiness: i > 0
                  ? optimizedLunch[i - 1]
                  : (optimizedActivities.isNotEmpty
                      ? optimizedActivities.last
                      : optimizedBreakfast.isNotEmpty
                          ? optimizedBreakfast.last
                          : null),
            ),
        ],
        if (optimizedDinner.isNotEmpty) ...[
          _buildSectionHeader('Dinner', Icons.dinner_dining),
          for (int i = 0; i < optimizedDinner.length; i++)
            _buildBusinessCard(
              optimizedDinner[i],
              'dinner',
              ref,
              previousBusiness: i > 0
                  ? optimizedDinner[i - 1]
                  : (optimizedLunch.isNotEmpty
                      ? optimizedLunch.last
                      : optimizedActivities.isNotEmpty
                          ? optimizedActivities.last
                          : optimizedBreakfast.isNotEmpty
                              ? optimizedBreakfast.last
                              : null),
            ),
        ],
        if (optimizedDessert.isNotEmpty) ...[
          _buildSectionHeader('Dessert', Icons.cake),
          for (int i = 0; i < optimizedDessert.length; i++)
            _buildBusinessCard(
              optimizedDessert[i],
              'dessert',
              ref,
              previousBusiness: i > 0
                  ? optimizedDessert[i - 1]
                  : (optimizedDinner.isNotEmpty
                      ? optimizedDinner.last
                      : optimizedLunch.isNotEmpty
                          ? optimizedLunch.last
                          : optimizedActivities.isNotEmpty
                              ? optimizedActivities.last
                              : optimizedBreakfast.isNotEmpty
                                  ? optimizedBreakfast.last
                                  : null),
            ),
        ],
        if (optimizedActivities.isNotEmpty) ...[
          _buildSectionHeader('Activities', Icons.explore),
          for (int i = 0; i < optimizedActivities.length; i++)
            _buildBusinessCard(
              optimizedActivities[i],
              'activity',
              ref,
              previousBusiness: i > 0 ? optimizedActivities[i - 1] : (optimizedBreakfast.isNotEmpty ? optimizedBreakfast.last : null),
            ),
        ],
        SizedBox(height: 20),
        _buildAdditionalOptions(tripStartDate, city, totalDays, context),
      ],
    );
  }

  Widget _buildAdditionalOptions(DateTime tripStartDate, String city, int totalDays, BuildContext context) {
    return Column(
      children: [
        _buildOptionCard(
          icon: Icons.hotel_outlined,
          title: 'Find Best Hotels',
          subtitle: 'Find the cheapest hotel deals',
          onTap: () {
            HotelBookingHelper.openHotelBooking(
              context: context,
              toCity: city,
              departureDate: tripStartDate,
              tripDays: totalDays,
            );
          },
        ),
        SizedBox(height: 12),
        _buildOptionCard(
          icon: Icons.flight_outlined,
          title: 'Search Flights',
          subtitle: 'Best deals on flight reservations',
          onTap: () {
            FlightBookingHelper.openFlightBooking(
              context: context,
              toCity: city,
              departureDate: tripStartDate,
              tripDays: totalDays,
            );
          },
        ),
        SizedBox(height: 12),
        _buildOptionCard(
          icon: Icons.event,
          title: 'Real Time Events',
          subtitle: 'Check events happening in $city',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => EventListPage(cityName: city),
              ),
            );
          },
        ),
        SizedBox(height: 20),
      ],
    );
  }

  Widget _buildBusinessCard(Business business, String type, WidgetRef ref, {Business? previousBusiness}) {
    final expandedId = ref.watch(expandedBusinessProvider);
    final isExpanded = expandedId == business.businessId;

    return Column(
      children: [
        if (previousBusiness != null && previousBusiness.latitude != null && previousBusiness.longitude != null && business.latitude != null && business.longitude != null)
          _buildDistanceConnector(previousBusiness, business),
        Container(
          margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                spreadRadius: 0,
                blurRadius: 20,
                offset: Offset(0, 4),
              ),
              BoxShadow(
                color: Colors.grey.withOpacity(0.05),
                spreadRadius: 0,
                blurRadius: 10,
                offset: Offset(0, 1),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (business.photos != null && business.photos!.isNotEmpty)
                    Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                          child: CarouselSlider(
                            options: CarouselOptions(
                              height: 220,
                              viewportFraction: 1.0,
                              enableInfiniteScroll: business.photos!.length > 1,
                              autoPlay: business.photos!.length > 1,
                              autoPlayInterval: Duration(seconds: 5),
                            ),
                            items: business.photos!.map((photo) {
                              return Container(
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  image: DecorationImage(
                                    image: NetworkImage(photo),
                                    fit: BoxFit.cover,
                                  ),
                                ),
                                child: Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Colors.transparent,
                                        Colors.black.withOpacity(0.2),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                        Positioned(
                          top: 12,
                          right: 12,
                          child: LikeDislikeButtons(
                            businessId: business.id,
                            userId: FirebaseAuth.instance.currentUser!.uid,
                          ),
                        ),
                      ],
                    ),
                  Padding(
                    padding: EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (business.photos == null || business.photos!.isEmpty) ...[
                              Container(
                                width: 64,
                                height: 64,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      _getTypeColor(type).withOpacity(0.1),
                                      _getTypeColor(type).withOpacity(0.2),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Icon(
                                  _getTypeIcon(type),
                                  color: _getTypeColor(type),
                                  size: 30,
                                ),
                              ),
                              SizedBox(width: 16),
                            ],
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    business.name,
                                    style: GoogleFonts.lexendDeca(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.black87,
                                      height: 1.2,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  SizedBox(height: 8),
                                  Row(
                                    children: [
                                      _buildRating(business.stars),
                                      if (business.reviewCount != null) ...[
                                        SizedBox(width: 8),
                                        Text(
                                          '(${business.reviewCount})',
                                          style: TextStyle(
                                            color: Colors.grey[600],
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  SizedBox(height: 8),
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Icon(Icons.location_on, size: 16, color: Colors.grey[600]),
                                      SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          business.address ?? '${business.locality}, ${business.region}',
                                          style: TextStyle(
                                            color: Colors.grey[600],
                                            fontSize: 14,
                                            height: 1.3,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              children: [
                                if (business.photos == null || business.photos!.isEmpty) ...[
                                  LikeDislikeButtons(
                                    businessId: business.id,
                                    userId: FirebaseAuth.instance.currentUser!.uid,
                                  ),
                                  SizedBox(height: 8),
                                ],
                                Container(
                                  decoration: BoxDecoration(
                                    color: kDeepPinkLight.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(32),
                                  ),
                                  child: IconButton(
                                    onPressed: () {
                                      ref.read(expandedBusinessProvider.notifier).state = isExpanded ? null : business.businessId;
                                    },
                                    icon: AnimatedRotation(
                                      turns: isExpanded ? 0.5 : 0,
                                      duration: Duration(milliseconds: 200),
                                      child: Icon(Icons.expand_more),
                                    ),
                                    color: kDeepPink,
                                    iconSize: 22,
                                    constraints: BoxConstraints(
                                      minWidth: 44,
                                      minHeight: 44,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        SizedBox(height: 16),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              _buildPriceTag(business.priceRange),
                              SizedBox(width: 8),
                              ...business.cuisines.take(3).map((c) => Padding(
                                    padding: EdgeInsets.only(right: 8),
                                    child: _buildTag(c),
                                  )),
                              if (business.hasWifi)
                                Padding(
                                  padding: EdgeInsets.only(right: 8),
                                  child: _buildTag('WiFi', icon: Icons.wifi),
                                ),
                              if (business.goodForKids)
                                Padding(
                                  padding: EdgeInsets.only(right: 8),
                                  child: _buildTag('Family', icon: Icons.family_restroom),
                                ),
                              if (business.acceptsCreditCards == true) _buildTag('Cards', icon: Icons.credit_card),
                            ],
                          ),
                        ),
                        AnimatedCrossFade(
                          firstChild: SizedBox.shrink(),
                          secondChild: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(height: 20),
                              Container(
                                height: 1,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.transparent,
                                      Colors.grey[300]!,
                                      Colors.transparent,
                                    ],
                                  ),
                                ),
                              ),
                              SizedBox(height: 20),
                              if (business.categories != null && business.categories!.isNotEmpty) ...[
                                Text(
                                  'Categories',
                                  style: GoogleFonts.lexendDeca(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black87,
                                  ),
                                ),
                                SizedBox(height: 12),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: business.categories!
                                      .take(5)
                                      .map((cat) => _buildTag(
                                            cat,
                                            backgroundColor: kDeepPinkLight.withOpacity(0.1),
                                            textColor: kDeepPink,
                                          ))
                                      .toList(),
                                ),
                                SizedBox(height: 20),
                              ],
                              Container(
                                padding: EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.grey[50],
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                  children: [
                                    if (business.phone != null)
                                      _buildActionButton(
                                        icon: Icons.phone,
                                        label: 'Call',
                                        onTap: () => _launchUrl('tel:${business.phone}'),
                                      ),
                                    if (business.website != null)
                                      _buildActionButton(
                                        icon: Icons.language,
                                        label: 'Website',
                                        onTap: () => _launchUrl(business.website!),
                                      ),
                                    if (business.latitude != null && business.longitude != null)
                                      _buildActionButton(
                                        icon: Icons.directions,
                                        label: 'Directions',
                                        onTap: () => _launchUrl('https://www.google.com/maps/search/?api=1&query=${business.latitude},${business.longitude}'),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          crossFadeState: isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                          duration: Duration(milliseconds: 300),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatItem({required IconData icon, required String value, required String label}) {
    return Column(
      children: [
        Icon(icon, color: kDeepPink, size: 24),
        SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.lexendDeca(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Colors.black87,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildDayStats(DayItinerary dayItinerary) {
    // Calculate total distance for the day
    double totalDistance = 0;
    List<Business> allBusinesses = [
      ..._optimizeRoute(dayItinerary.breakfast),
      ..._optimizeRoute(dayItinerary.activities),
      ..._optimizeRoute(dayItinerary.lunch),
      ..._optimizeRoute(dayItinerary.dinner),
      ..._optimizeRoute(dayItinerary.dessert),
    ];

    for (int i = 1; i < allBusinesses.length; i++) {
      if (allBusinesses[i - 1].latitude != null && allBusinesses[i - 1].longitude != null && allBusinesses[i].latitude != null && allBusinesses[i].longitude != null) {
        totalDistance += _calculateDistance(
          allBusinesses[i - 1].latitude!,
          allBusinesses[i - 1].longitude!,
          allBusinesses[i].latitude!,
          allBusinesses[i].longitude!,
        );
      }
    }

    final totalWalkingMinutes = (totalDistance * 12).round();
    final hours = totalWalkingMinutes ~/ 60;
    final minutes = totalWalkingMinutes % 60;

    return Container(
      margin: EdgeInsets.only(bottom: 16),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [kDeepPink.withOpacity(0.05), kDeepPinkLight.withOpacity(0.05)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kDeepPinkLight.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem(
            icon: Icons.place,
            value: '${allBusinesses.length}',
            label: 'Places',
          ),
          Container(width: 1, height: 40, color: Colors.grey[300]),
          _buildStatItem(
            icon: Icons.route,
            value: '${totalDistance.toStringAsFixed(1)} km',
            label: 'Total Distance',
          ),
          Container(width: 1, height: 40, color: Colors.grey[300]),
          _buildStatItem(
            icon: Icons.timer,
            value: hours > 0 ? '${hours}h ${minutes}m' : '${minutes}m',
            label: 'Walking Time',
          ),
        ],
      ),
    );
  }

  Widget _buildDateHeader(int dayNumber, DateTime tripStartDate) {
    final tripDate = tripStartDate.add(Duration(days: dayNumber - 1));
    return Container(
      margin: EdgeInsets.only(bottom: 20),
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [kDeepPinkLight.withOpacity(0.1), kDeepPink.withOpacity(0.1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.calendar_today, color: kDeepPink, size: 20),
          SizedBox(width: 12),
          Text(
            DateFormat('EEEE, MMMM d').format(tripDate),
            style: GoogleFonts.lexendDeca(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: kDeepPinkLight.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: kDeepPink, size: 20),
          ),
          SizedBox(width: 12),
          Text(
            title,
            style: GoogleFonts.lexendDeca(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371; // km
    double dLat = (lat2 - lat1) * pi / 180;
    double dLon = (lon2 - lon1) * pi / 180;

    double a = sin(dLat / 2) * sin(dLat / 2) + cos(lat1 * pi / 180) * cos(lat2 * pi / 180) * sin(dLon / 2) * sin(dLon / 2);

    double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c;
  }

// Add this function to build the distance connector
  Widget _buildDistanceConnector(Business from, Business to) {
    final distance = _calculateDistance(from.latitude!, from.longitude!, to.latitude!, to.longitude!);

    // Estimate walking time (average walking speed: 5 km/h)
    final walkingMinutes = (distance * 12).round(); // 12 minutes per km

    return Container(
      margin: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 1,
              color: Colors.grey[300],
            ),
          ),
          Container(
            margin: EdgeInsets.symmetric(horizontal: 12),
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.directions_walk, size: 16, color: Colors.grey[700]),
                SizedBox(width: 6),
                Text(
                  '${distance.toStringAsFixed(1)} km • ~$walkingMinutes min',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[700],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Container(
              height: 1,
              color: Colors.grey[300],
            ),
          ),
        ],
      ),
    );
  }

// Add this function to optimize route by minimizing walking distance
  List<Business> _optimizeRoute(List<Business> businesses) {
    if (businesses.length <= 1) return businesses;

    // Filter businesses with valid coordinates
    final validBusinesses = businesses.where((b) => b.latitude != null && b.longitude != null).toList();
    final invalidBusinesses = businesses.where((b) => b.latitude == null || b.longitude == null).toList();

    if (validBusinesses.isEmpty) return businesses;
    if (validBusinesses.length == 1) return [...validBusinesses, ...invalidBusinesses];

    // Simple nearest neighbor algorithm
    List<Business> optimized = [];
    List<Business> remaining = List.from(validBusinesses);

    // Start with the first business
    optimized.add(remaining.removeAt(0));

    while (remaining.isNotEmpty) {
      Business current = optimized.last;
      Business? nearest;
      double minDistance = double.infinity;

      for (Business business in remaining) {
        double dist = _calculateDistance(current.latitude!, current.longitude!, business.latitude!, business.longitude!);

        if (dist < minDistance) {
          minDistance = dist;
          nearest = business;
        }
      }

      if (nearest != null) {
        optimized.add(nearest);
        remaining.remove(nearest);
      }
    }

    // Add businesses without coordinates at the end
    optimized.addAll(invalidBusinesses);

    return optimized;
  } // rest of code

// Enhanced tag builder with better styling
  Widget _buildTag(String text, {IconData? icon, Color? backgroundColor, Color? textColor}) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor ?? Colors.grey[100],
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: (backgroundColor ?? Colors.grey[100]!).withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              size: 14,
              color: textColor ?? Colors.grey[700],
            ),
            SizedBox(width: 4),
          ],
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: textColor ?? Colors.grey[700],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRating(double stars) {
    return Row(
      children: List.generate(5, (index) {
        if (index < stars.floor()) {
          return Icon(Icons.star, color: Colors.amber, size: 16);
        } else if (index < stars) {
          return Icon(Icons.star_half, color: Colors.amber, size: 16);
        } else {
          return Icon(Icons.star_border, color: Colors.amber, size: 16);
        }
      }),
    );
  }

  Widget _buildPriceTag(int priceRange) {
    final priceSymbol = '\$' * priceRange.clamp(1, 4);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        priceSymbol,
        style: TextStyle(
          color: Colors.green[700],
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          children: [
            Icon(icon, color: kDeepPink, size: 24),
            SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: kDeepPink,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      elevation: 2,
      shadowColor: Colors.grey.withOpacity(0.1),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: kDeepPinkLight.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: kDeepPink, size: 28),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.lexendDeca(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios, color: Colors.grey[400], size: 16),
            ],
          ),
        ),
      ),
    );
  }

  Color _getTypeColor(String type) {
    switch (type) {
      case 'breakfast':
        return Colors.orange;
      case 'lunch':
        return Colors.blue;
      case 'dinner':
        return Colors.purple;
      case 'dessert':
        return kDeepPink;
      case 'activity':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  IconData _getTypeIcon(String type) {
    switch (type) {
      case 'breakfast':
        return Icons.free_breakfast;
      case 'lunch':
        return Icons.lunch_dining;
      case 'dinner':
        return Icons.dinner_dining;
      case 'dessert':
        return Icons.cake;
      case 'activity':
        return Icons.explore;
      default:
        return Icons.place;
    }
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

class LikeDislikeButtons extends StatefulWidget {
  final int businessId;
  final String userId;

  const LikeDislikeButtons({
    Key? key,
    required this.businessId,
    required this.userId,
  }) : super(key: key);

  @override
  State<LikeDislikeButtons> createState() => _LikeDislikeButtonsState();
}

class _LikeDislikeButtonsState extends State<LikeDislikeButtons> {
  late final UserInteractionService _interactionService;

  @override
  void initState() {
    super.initState();
    _interactionService = UserInteractionService();

    // Initialize business state if not already present
    // Since interactions are loaded at the page level, this is just a fallback
    _interactionService.initializeBusinessState(widget.businessId);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _interactionService,
      builder: (context, child) {
        final isLiked = _interactionService.isLiked(widget.businessId);
        final isDisliked = _interactionService.isDisliked(widget.businessId);
        final isLoading = _interactionService.isLoading(widget.businessId);
        final error = _interactionService.getError(widget.businessId);

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildLikeDislikeButton(
                  icon: Icons.favorite_border,
                  onPressed: isLoading ? null : _handleLikePressed,
                  isLiked: isLiked,
                  isDislike: false,
                  isLoading: isLoading && !isDisliked,
                ),
                const SizedBox(width: 12),
                _buildLikeDislikeButton(
                  icon: Icons.thumb_down_outlined,
                  onPressed: isLoading ? null : _handleDislikePressed,
                  isDisliked: isDisliked,
                  isDislike: true,
                  isLoading: isLoading && !isLiked,
                ),
              ],
            ),
            if (error != null) ...[
              const SizedBox(height: 4),
              _buildErrorIndicator(error),
            ],
          ],
        );
      },
    );
  }

  Widget _buildLikeDislikeButton({
    required IconData icon,
    required VoidCallback? onPressed,
    bool isLiked = false,
    bool isDisliked = false,
    bool isDislike = false,
    double size = 40,
    bool isLoading = false,
  }) {
    final isActive = isLiked || isDisliked;
    final activeColor = isDislike ? (Colors.red) : (kDeepPink);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.4),
        borderRadius: BorderRadius.circular(size / 2),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(size / 2),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              color: isActive ? activeColor.withOpacity(0.2) : Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(size / 2),
              border: Border.all(
                color: Colors.white.withOpacity(0.2),
                width: 1,
              ),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(size / 2),
                onTap: onPressed,
                splashColor: (isActive ? activeColor : Colors.white).withOpacity(0.3),
                highlightColor: (isActive ? activeColor : Colors.white).withOpacity(0.1),
                child: AnimatedScale(
                  scale: isActive ? 1.1 : 1.0,
                  duration: const Duration(milliseconds: 200),
                  child: Center(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      transitionBuilder: (child, animation) {
                        return ScaleTransition(
                          scale: animation,
                          child: child,
                        );
                      },
                      child: isLoading
                          ? SizedBox(
                              key: const ValueKey('loading'),
                              width: size * 0.35,
                              height: size * 0.35,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  isActive ? activeColor : Colors.white.withOpacity(0.9),
                                ),
                              ),
                            )
                          : Icon(
                              isActive ? (isDislike ? Icons.thumb_down : Icons.favorite) : icon,
                              key: ValueKey(isActive ? 'active' : 'inactive'),
                              size: size * 0.45,
                              color: isActive ? activeColor : Colors.white.withOpacity(0.9),
                            ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorIndicator(String error) {
    return Tooltip(
      message: error,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.8),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(
          Icons.error_outline,
          size: 16,
          color: Colors.white,
        ),
      ),
    );
  }

  void _handleLikePressed() {
    _interactionService.toggleLike(widget.userId, widget.businessId);
  }

  void _handleDislikePressed() {
    _interactionService.toggleDislike(widget.userId, widget.businessId);
  }
}
