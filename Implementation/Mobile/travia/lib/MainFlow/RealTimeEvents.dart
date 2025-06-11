import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:travia/Helpers/AppColors.dart';
import 'package:travia/Helpers/Loading.dart';
import 'package:travia/Helpers/PopUp.dart';
import 'package:url_launcher/url_launcher.dart';

import '../Services/EventBrightService.dart';

// Providers
final eventsProvider = StateNotifierProvider.family<EventsNotifier, AsyncValue<List<Event>>, String>(
  (ref, city) => EventsNotifier(city),
);

class EventsNotifier extends StateNotifier<AsyncValue<List<Event>>> {
  final String city;
  final EventbriteService _eventbriteService = EventbriteService();

  EventsNotifier(this.city) : super(const AsyncValue.loading()) {
    loadEvents();
  }

  Future<void> loadEvents() async {
    state = const AsyncValue.loading();
    try {
      final events = await _eventbriteService.getEventsByCity(city);
      state = AsyncValue.data(events);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }
}

class EventListPage extends ConsumerWidget {
  final String cityName;

  const EventListPage({Key? key, required this.cityName}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventsAsync = ref.watch(eventsProvider(cityName));

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
              'Events',
              style: GoogleFonts.lexendDeca(
                color: Colors.black87,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              'in $cityName',
              style: GoogleFonts.lexendDeca(
                color: Colors.grey[600],
                fontSize: 14,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
        centerTitle: true,
      ),
      body: eventsAsync.when(
        loading: () => Center(
          child: LoadingWidget(
            size: 24,
          ),
        ),
        error: (error, _) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Popup.showError(
              text: 'Error loading events: ${error.toString()}',
              context: context,
            );
          });
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 60, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'Failed to load events',
                  style: GoogleFonts.lexendDeca(
                    fontSize: 18,
                    color: Colors.grey[700],
                  ),
                ),
                SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => ref.refresh(eventsProvider(cityName)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kDeepPink,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: Text(
                    'Retry',
                    style: GoogleFonts.lexendDeca(color: Colors.white),
                  ),
                ),
              ],
            ),
          );
        },
        data: (events) {
          if (events.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.event_busy, size: 60, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'No events found',
                    style: GoogleFonts.lexendDeca(
                      fontSize: 18,
                      color: Colors.grey[700],
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: EdgeInsets.all(16),
            itemCount: events.length + 1,
            itemBuilder: (context, index) {
              if (index == events.length) {
                return Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Center(
                    child: TextButton(
                      onPressed: () async {
                        final url = 'https://www.eventbrite.com';
                        if (await canLaunch(url)) {
                          await launch(url);
                        }
                      },
                      child: Text(
                        'Powered by Eventbrite',
                        style: GoogleFonts.lexendDeca(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                );
              }

              final event = events[index];
              return _buildEventCard(context, event);
            },
          );
        },
      ),
    );
  }

  Widget _buildEventCard(BuildContext context, Event event) {
    return Container(
      margin: EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image
          if (event.imageUrl != null)
            ClipRRect(
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Image.network(
                  event.imageUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: Colors.grey[200],
                      child: Center(
                        child: Icon(
                          Icons.event,
                          size: 50,
                          color: Colors.grey[400],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),

          // Content
          Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title
                Text(
                  event.title ?? 'Untitled Event',
                  style: GoogleFonts.lexendDeca(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 12),

                // Time
                if (event.time != null)
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: kDeepPink.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.access_time,
                          size: 18,
                          color: kDeepPink,
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          event.time!,
                          style: GoogleFonts.lexendDeca(
                            fontSize: 14,
                            color: Colors.grey[700],
                          ),
                        ),
                      ),
                    ],
                  ),

                // Location
                if (event.location != null) ...[
                  SizedBox(height: 10),
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: kDeepPink.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.location_on,
                          size: 18,
                          color: kDeepPink,
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          event.location!,
                          style: GoogleFonts.lexendDeca(
                            fontSize: 14,
                            color: Colors.grey[700],
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],

                SizedBox(height: 16),

                // Price and Link
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Spacer(),
                    if (event.eventLink != null)
                      GestureDetector(
                        onTap: () async {
                          if (await canLaunch(event.eventLink!)) {
                            await launch(event.eventLink!);
                          } else {
                            Popup.showError(
                              text: 'Could not open link',
                              context: context,
                            );
                          }
                        },
                        child: Container(
                          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            border: Border.all(color: kDeepPink, width: 1.5),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'View Event',
                                style: GoogleFonts.lexendDeca(
                                  color: kDeepPink,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              SizedBox(width: 4),
                              Icon(
                                Icons.arrow_forward_ios,
                                size: 14,
                                color: kDeepPink,
                              ),
                            ],
                          ),
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
}
