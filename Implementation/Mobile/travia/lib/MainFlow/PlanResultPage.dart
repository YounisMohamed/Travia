import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:travia/Helpers/AppColors.dart';
import 'package:travia/MainFlow/HotelsDialog.dart';

import 'FlightsDialog.dart';
import 'RealTimeEvents.dart';

// Providers
final selectedDayProvider = StateProvider<int>((ref) => 1);
final savedPlansProvider = StateProvider<bool>((ref) => false);

// Dummy data for places
final dummyPlaces = {
  1: [
    {
      'name': 'Eiffel Tower',
      'category': 'Landmark',
      'rating': 4.8,
      'reviews': 2341,
      'description': 'Iconic iron lattice tower on the Champ de Mars, offering panoramic views of Paris.',
      'address': 'Champ de Mars, 5 Avenue Anatole France',
      'price': '\$\$\$',
      'image': 'https://picsum.photos/id/63/200/200',
      'isFavorite': false,
    },
    {
      'name': 'Louvre Museum',
      'category': 'Museum',
      'rating': 4.7,
      'reviews': 1892,
      'description': "World's largest art museum and cultural monument, housing the Mona Lisa and Venus de Milo.",
      'address': 'Rue de Rivoli, 75001 Paris',
      'price': '\$\$\$',
      'image': 'https://images.unsplash.com/photo-1499856871958-5b9627545d1a?w=800',
      'isFavorite': false,
    },
  ],
  2: [
    {
      'name': 'Arc de Triomphe',
      'category': 'Monument',
      'rating': 4.6,
      'reviews': 1654,
      'description': 'Iconic triumphal arch honoring those who fought for France.',
      'address': 'Place Charles de Gaulle',
      'price': '\$\$',
      'image': 'https://images.unsplash.com/photo-1550340499-a6c60fc8287c?w=800',
      'isFavorite': false,
    },
    {
      'name': 'Notre-Dame Cathedral',
      'category': 'Church',
      'rating': 4.9,
      'reviews': 3421,
      'description': 'Medieval Catholic cathedral, a masterpiece of French Gothic architecture.',
      'address': '6 Parvis Notre-Dame',
      'price': 'Free',
      'image': 'https://images.unsplash.com/photo-1528728329032-2972f65dfb3f?w=800',
      'isFavorite': true,
    },
  ],
  3: [
    {
      'name': 'Notre-Dame Cathedral',
      'category': 'Church',
      'rating': 4.9,
      'reviews': 3421,
      'description': 'Medieval Catholic cathedral, a masterpiece of French Gothic architecture.',
      'address': '6 Parvis Notre-Dame',
      'price': 'Free',
      'image': 'https://images.unsplash.com/photo-1528728329032-2972f65dfb3f?w=800',
      'isFavorite': true,
    },
  ],
};

class PlanResultPage extends ConsumerStatefulWidget {
  final String destination;
  final int days;
  final DateTime date;

  const PlanResultPage({
    Key? key,
    required this.destination,
    required this.days,
    required this.date,
  }) : super(key: key);

  @override
  ConsumerState<PlanResultPage> createState() => _PlanResultPageState();
}

class _PlanResultPageState extends ConsumerState<PlanResultPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: widget.days, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackground,
      appBar: AppBar(
        forceMaterialTransparency: true,
        backgroundColor: kBackground,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          children: [
            Text(
              'Your Travel Plan',
              style: GoogleFonts.lexendDeca(
                color: Colors.black87,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              '${widget.days} Days in ${widget.destination}',
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
            color: Colors.white,
            child: TabBar(
              controller: _tabController,
              labelColor: kDeepPink,
              unselectedLabelColor: Colors.grey[500],
              labelStyle: GoogleFonts.lexendDeca(fontWeight: FontWeight.w600),
              unselectedLabelStyle: GoogleFonts.lexendDeca(fontWeight: FontWeight.w400),
              indicatorColor: kDeepPink,
              indicatorWeight: 2,
              tabs: List.generate(widget.days, (index) => Tab(text: 'Day ${index + 1}')),
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: List.generate(widget.days, (index) {
          final dayNumber = index + 1;
          final places = dummyPlaces[dayNumber] ?? [];
          final isLastDay = dayNumber == widget.days;

          return ListView(
            padding: EdgeInsets.all(16),
            children: [
              ...places.map((place) => _buildPlaceCard(place)),
              SizedBox(height: 20),

              // Only show options on the last day
              if (isLastDay) ...[
                // Additional options
                _buildOptionCard(
                  icon: Icons.hotel_outlined,
                  title: 'Find Best Hotels',
                  subtitle: 'Find the cheapest hotel deals',
                  onTap: () {
                    HotelBookingHelper.openHotelBooking(
                      context: context,
                      toCity: widget.destination,
                      departureDate: widget.date,
                      tripDays: widget.days,
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
                        toCity: widget.destination,
                        departureDate: widget.date,
                        tripDays: widget.days,
                      );
                    }),
                SizedBox(height: 12),
                _buildOptionCard(
                    icon: Icons.event,
                    title: 'Real Time Events',
                    subtitle: 'Check the events happening right now on ${widget.destination}',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => EventListPage(cityName: widget.destination),
                        ),
                      );
                    }),
                SizedBox(height: 30),
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: ElevatedButton(
                    onPressed: () {
                      ref.read(savedPlansProvider.notifier).state = true;
                      // TODO: Save plan logic
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kDeepPink,
                      padding: EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      'Save Plan',
                      style: GoogleFonts.lexendDeca(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 20),
              ],
            ],
          );
        }),
      ),
    );
  }

  Widget _buildPlaceCard(Map<String, dynamic> place) {
    return Container(
      margin: EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image
          Container(
            height: 180,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              image: DecorationImage(
                image: NetworkImage(place['image']),
                fit: BoxFit.cover,
              ),
            ),
          ),

          // Content
          Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            place['name'],
                            style: GoogleFonts.lexendDeca(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            place['category'],
                            style: GoogleFonts.lexendDeca(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Row(
                      children: [
                        IconButton(
                          onPressed: () {
                            // TODO: Toggle favorite
                          },
                          icon: Icon(
                            place['isFavorite'] ? Icons.favorite : Icons.favorite_border,
                            color: place['isFavorite'] ? Colors.red : Colors.grey[400],
                            size: 24,
                          ),
                          padding: EdgeInsets.zero,
                          constraints: BoxConstraints(),
                        ),
                        SizedBox(width: 12),
                        IconButton(
                          onPressed: () {
                            // TODO: Dislike
                          },
                          icon: Icon(
                            CupertinoIcons.hand_thumbsdown,
                            color: Colors.grey[400],
                            size: 24,
                          ),
                          padding: EdgeInsets.zero,
                          constraints: BoxConstraints(),
                        ),
                      ],
                    ),
                  ],
                ),
                SizedBox(height: 12),

                // Rating
                Row(
                  children: [
                    Icon(Icons.star, color: Colors.amber, size: 18),
                    SizedBox(width: 4),
                    Text(
                      place['rating'].toString(),
                      style: GoogleFonts.lexendDeca(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      ' (${place['reviews'].toString()} reviews)',
                      style: GoogleFonts.lexendDeca(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8),

                // Description
                Text(
                  place['description'],
                  style: GoogleFonts.lexendDeca(
                    fontSize: 14,
                    color: Colors.grey[700],
                    height: 1.4,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 8),

                // Address
                Row(
                  children: [
                    Icon(Icons.location_on_outlined, size: 16, color: Colors.grey[600]),
                    SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        place['address'],
                        style: GoogleFonts.lexendDeca(
                          fontSize: 13,
                          color: Colors.grey[600],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12),

                // Price and View on Map
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      place['price'],
                      style: GoogleFonts.lexendDeca(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[700],
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        // TODO: Open map
                      },
                      child: Row(
                        children: [
                          Text(
                            'View on Map',
                            style: GoogleFonts.lexendDeca(
                              color: Colors.blue,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Icon(
                            Icons.arrow_forward_ios,
                            size: 12,
                            color: Colors.blue,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOptionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                size: 24,
                color: Colors.grey[700],
              ),
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
                  Text(
                    subtitle,
                    style: GoogleFonts.lexendDeca(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: Colors.grey[400],
            ),
          ],
        ),
      ),
    );
  }
}
