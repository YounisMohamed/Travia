import 'package:html/parser.dart' as parser;
import 'package:http/http.dart' as http;

class Event {
  final String? imageUrl;
  final String? title;
  final String? time;
  final String? location;
  final String? eventLink;

  Event({
    this.imageUrl,
    this.title,
    this.time,
    this.location,
    this.eventLink,
  });

  Map<String, dynamic> toJson() {
    return {
      'imageUrl': imageUrl,
      'title': title,
      'time': time,
      'location': location,
      'eventLink': eventLink,
    };
  }
}

class EventbriteService {
  static const Map<String, String> _cityUrlMapping = {
    'New York': 'https://www.eventbrite.com/d/ny--new-york/all-events/',
    'Mexico City': 'https://www.eventbrite.com/d/mexico--mexico-city/all-events/',
    'Barcelona': 'https://www.eventbrite.com/d/spain--barcelona/all-events/',
    'Moscow': 'https://www.eventbrite.com/d/russia--moscow/all-events/',
    'Berlin': 'https://www.eventbrite.com/d/germany--berlin/all-events/',
    'Paris': 'https://www.eventbrite.com/d/france--paris/all-events/',
    'Dubai': 'https://www.eventbrite.com/d/united-arab-emirates--dby/all-events/',
    'Rome': 'https://www.eventbrite.com/d/italy--rome/all-events/',
    'Toronto': 'https://www.eventbrite.com/d/canada--toronto/all-events/',
    'Los Angeles': 'https://www.eventbrite.com/d/ca--los-angeles/all-events/',
    'Rio de Janeiro': 'https://www.eventbrite.com/d/brazil--rio-de-janeiro/all-events/',
    'Shanghai': 'https://www.eventbrite.com/d/china--shanghai/all-events/',
  };

  Future<List<Event>> getEventsByCity(String cityName) async {
    final url = _cityUrlMapping[cityName];
    if (url == null) {
      throw ArgumentError('Invalid city name. Please use one of: ${_cityUrlMapping.keys.join(', ')}');
    }

    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
        },
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to load events. Status code: ${response.statusCode}');
      }

      final document = parser.parse(response.body);
      final events = <Event>[];

      // Find all event list items
      var eventElements = document.querySelectorAll('li').where((element) {
        return element.querySelector('h3') != null && element.querySelector('img') != null;
      }).toList();

      for (int i = 0; i < eventElements.length; i++) {
        try {
          final eventElement = eventElements[i];

          // Extract image URL
          final imageElement = eventElement.querySelector('img');
          final imageUrl = imageElement?.attributes['src'];

          // Extract title
          final titleElement = eventElement.querySelector('h3');
          final title = titleElement?.text.trim();

          // More robust time and location extraction
          String? time;
          String? location;
          String? price;

          // Get all text elements, filtering out urgency signals
          final allParagraphs = eventElement.querySelectorAll('p').where((p) {
            final classes = p.classes.join(' ');
            final text = p.text.trim().toLowerCase();

            // Filter out urgency signal paragraphs
            return !classes.contains('EventCardUrgencySignal') && !text.contains('sales end soon') && !text.contains('almost full') && !text.contains('selling fast') && text.isNotEmpty;
          }).toList();

          // Look for time patterns (common formats: dates, times with AM/PM)
          for (var p in allParagraphs) {
            final text = p.text.trim();

            // Check if this looks like a date/time
            if (_isTimeFormat(text)) {
              time ??= text;
            }
            // Check if this looks like a location (contains common location indicators)
            else if (_isLocationFormat(text) && time != null) {
              location ??= text;
            }
          }

          // Alternative method: Look for specific EventBrite class patterns
          if (time == null || location == null) {
            // Try to find elements by common EventBrite class patterns
            final timeElements = eventElement.querySelectorAll('[class*="event-card__date"]');
            if (timeElements.isNotEmpty && time == null) {
              time = timeElements.first.text.trim();
            }

            final locationElements = eventElement.querySelectorAll('[class*="event-card__location"], [class*="event-card__venue"]');
            if (locationElements.isNotEmpty && location == null) {
              location = locationElements.first.text.trim();
            }
          }

          // If still no time/location, fall back to paragraph order (skipping urgency signals)
          if (time == null && allParagraphs.isNotEmpty) {
            time = allParagraphs[0].text.trim();
          }
          if (location == null && allParagraphs.length > 1) {
            location = allParagraphs[1].text.trim();
          }

          // Extract event link
          final linkElements = eventElement.querySelectorAll('a');
          String? eventLink;
          for (var link in linkElements) {
            final href = link.attributes['href'];
            if (href != null && href.contains('/e/')) {
              eventLink = href.startsWith('http') ? href : 'https://www.eventbrite.com$href';
              break;
            }
          }

          // Extract price information
          final priceWrapper = eventElement.querySelector('[class*="priceWrapper"]');
          if (priceWrapper != null) {
            // Try to get actual price text
            final priceText = priceWrapper.text.trim();
            if (priceText.isNotEmpty && !priceText.toLowerCase().contains('free')) {
              price = priceText;
            }
          }

          // Check data attributes for paid status
          if (price == null) {
            final eventLinkWithData = eventElement.querySelector('a[data-event-paid-status]');
            final isPaid = eventLinkWithData?.attributes['data-event-paid-status'] == 'paid';

            if (isPaid) {
              // Try to find actual price in text
              final pricePattern = RegExp(r'\$\d+\.?\d*|\d+\.?\d*\s*(USD|EUR|GBP|EGP)');
              for (var element in eventElement.querySelectorAll('*')) {
                final match = pricePattern.firstMatch(element.text);
                if (match != null) {
                  price = match.group(0);
                  break;
                }
              }
              price ??= 'Paid Event';
            } else {
              price = 'Free';
            }
          }

          if (title != null && title.isNotEmpty) {
            events.add(Event(
              imageUrl: imageUrl,
              title: title,
              time: time,
              location: location,
              eventLink: eventLink,
            ));
          }
        } catch (e) {
          // Skip this event if parsing fails
          print('Error parsing event $i: $e');
          continue;
        }
      }

      return events;
    } catch (e) {
      throw Exception('Error fetching events: $e');
    }
  }

// Helper function to check if text looks like a time/date format
  bool _isTimeFormat(String text) {
    // Common date/time patterns
    final patterns = [
      // Day names
      RegExp(r'\b(Monday|Tuesday|Wednesday|Thursday|Friday|Saturday|Sunday|Mon|Tue|Wed|Thu|Fri|Sat|Sun)\b', caseSensitive: false),
      // Month names
      RegExp(r'\b(January|February|March|April|May|June|July|August|September|October|November|December|Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)\b', caseSensitive: false),
      // Time patterns
      RegExp(r'\b\d{1,2}:\d{2}\s*(AM|PM|am|pm)?\b'),
      // Date patterns
      RegExp(r'\b\d{1,2}[/-]\d{1,2}[/-]\d{2,4}\b'),
      RegExp(r'\b\d{4}[/-]\d{1,2}[/-]\d{1,2}\b'),
      // Common time indicators
      RegExp(r'\b(Today|Tomorrow|Tonight)\b', caseSensitive: false),
    ];

    return patterns.any((pattern) => pattern.hasMatch(text));
  }

// Helper function to check if text looks like a location
  bool _isLocationFormat(String text) {
    // Common location indicators
    final patterns = [
      // Street addresses
      RegExp(r'\b\d+\s+[A-Za-z\s]+\s+(Street|St|Avenue|Ave|Road|Rd|Boulevard|Blvd|Drive|Dr|Lane|Ln|Way|Place|Pl)\b', caseSensitive: false),
      // City, State patterns
      RegExp(r'[A-Za-z\s]+,\s*[A-Z]{2}\b'),
      // Common venue indicators
      RegExp(r'\b(Center|Centre|Hall|Theatre|Theater|Arena|Stadium|Park|Museum|Gallery|Club|Lounge|Bar|Restaurant|Hotel|University|College|School|Church|Library)\b', caseSensitive: false),
      // "at" or "in" followed by a place name
      RegExp(r'^(at|in)\s+[A-Z]', caseSensitive: false),
      // Contains city names (you can expand this list based on your cities)
      RegExp(r'\b(Cairo|Alexandria|Giza|London|New York|Paris|Berlin|Tokyo)\b', caseSensitive: false),
    ];

    // Exclude if it's too short (likely not a location)
    if (text.length < 5) return false;

    // Check if it matches location patterns
    return patterns.any((pattern) => pattern.hasMatch(text));
  }
}
