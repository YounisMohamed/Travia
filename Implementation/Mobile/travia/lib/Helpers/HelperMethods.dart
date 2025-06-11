import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path/path.dart' as p;
import 'package:travia/Classes/message_class.dart';

import '../Helpers/Constants.dart';
import '../main.dart';
import 'AppColors.dart';

String timeAgo(DateTime utcDateTime) {
  // Force the input to UTC (Every body's time is different so its a time mw7d)
  final utcTime = utcDateTime.isUtc
      ? utcDateTime
      : DateTime.utc(
          utcDateTime.year,
          utcDateTime.month,
          utcDateTime.day,
          utcDateTime.hour,
          utcDateTime.minute,
          utcDateTime.second,
          utcDateTime.millisecond,
          utcDateTime.microsecond,
        );

  final now = DateTime.now().toUtc();

  final difference = now.difference(utcTime);
  if (difference.inSeconds < 60) {
    return 'Just Now';
  } else if (difference.inMinutes < 60) {
    return '${difference.inMinutes} minute${difference.inMinutes == 1 ? '' : 's'} ago';
  } else if (difference.inHours < 24) {
    return '${difference.inHours} hour${difference.inHours == 1 ? '' : 's'} ago';
  } else if (difference.inDays < 7) {
    return '${difference.inDays} day${difference.inDays == 1 ? '' : 's'} ago';
  } else if (difference.inDays < 30) {
    final weeks = (difference.inDays / 7).floor();
    return '$weeks week${weeks == 1 ? '' : 's'} ago';
  } else if (difference.inDays < 365) {
    final months = (difference.inDays / 30).floor();
    return '$months month${months == 1 ? '' : 's'} ago';
  } else {
    final years = (difference.inDays / 365).floor();
    return '$years year${years == 1 ? '' : 's'} ago';
  }
}

String formatTimeLabel(DateTime timeStamp) {
  // Force to UTC
  final utcTime = timeStamp.isUtc
      ? timeStamp
      : DateTime.utc(
          timeStamp.year,
          timeStamp.month,
          timeStamp.day,
          timeStamp.hour,
          timeStamp.minute,
          timeStamp.second,
          timeStamp.millisecond,
          timeStamp.microsecond,
        );

  // format time to something like 11:03 PM
  final hour = utcTime.hour % 12 == 0 ? 12 : utcTime.hour % 12;
  final minute = utcTime.minute.toString().padLeft(2, '0');
  final period = utcTime.hour >= 12 ? 'PM' : 'AM';

  return '$hour:$minute $period';
}

String formatCount(int count) {
  if (count < 1000) {
    return count.toString();
  } else if (count < 1000000) {
    return '${(count / 1000).toStringAsFixed(1)}K';
  } else if (count >= 1000000 && count < 1000000000000) {
    return '${(count / 1000000).toStringAsFixed(1)}M';
  } else {
    if (count > 1000000000000) {
      return "Too many views 😯";
    } else {
      return '${(count / 1000000000000).toStringAsFixed(1)}B';
    }
  }
}

dynamic isMostlyRtl(String text) {
  // Lw el kalam mostly arabic, rtl, else ltr
  final rtlChars = RegExp(r'[\u0600-\u06FF]');
  final rtlCount = rtlChars.allMatches(text).length;
  final totalCount = text.length;
  return (rtlCount / totalCount > 0.5) ? TextDirection.rtl : TextDirection.ltr;
}

Future<bool> createStory({
  required String mediaUrl,
  required String mediaType,
  String? caption,
}) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return false;

  try {
    final storyResponse = await supabase
        .from('stories')
        .insert({
          'user_id': user.uid,
        })
        .select()
        .single();

    // Create story item
    await supabase.from('story_items').insert({
      'story_id': storyResponse['story_id'],
      'media_url': mediaUrl,
      'media_type': mediaType,
      'caption': caption,
    });
    return true;
  } catch (e) {
    print('Error creating story: $e');
    return false;
  }
}

// New function to only create a story and return its ID
Future<String?> createNewStory() async {
  try {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      print("createNewStory failed: No user logged in");
      return null;
    }

    // Create a new story
    final storyData = {
      'user_id': user.uid,
      // The trigger will populate username and user_photo_url
    };

    // Insert story into database
    final response = await supabase.from('stories').insert(storyData).select('story_id').single();

    final storyId = response['story_id'] as String;
    print("Created new story with ID: $storyId");

    return storyId;
  } catch (e) {
    print("Error creating story: $e");
    return null;
  }
}

Future<bool> addStoryItem({
  required String storyId,
  required String mediaUrl,
  required String mediaType,
  String? caption,
}) async {
  try {
    // Create story item
    final itemData = {
      'story_id': storyId,
      'media_url': mediaUrl,
      'media_type': mediaType,
      'caption': caption,
    };

    // Insert story item
    await supabase.from('story_items').insert(itemData);
    print("Added story item to story $storyId: $mediaUrl ($mediaType)");

    return true;
  } catch (e) {
    print("Error adding story item: $e");
    return false;
  }
}

final Map<String, DateTime> _notificationCooldowns = {};

bool canSendNotification(String postId, String reactionType, String userId) {
  final key = '${postId}_$reactionType\_$userId';
  final now = DateTime.now();
  final lastSent = _notificationCooldowns[key];

  if (lastSent == null || now.difference(lastSent) > const Duration(seconds: 15)) {
    _notificationCooldowns[key] = now;
    return true;
  }
  return false;
}

String? normalizeCountry(String? inputCountry) {
  if (inputCountry == null) return null;
  for (var c in countries) {
    if (inputCountry.toLowerCase().contains(c['name']!.toLowerCase())) {
      return c['name'];
    }
  }
  return null;
}

bool hasArabicProfanity(String input) {
  // THIS IS TO PREVENT BAD WORDS IN COMMENTS, SORRY IF THESE WORDS OFFENDED YOU :)
  // THE OFFICIAL LIST OF PROFANITY IN GITHUB ONLY SUPPORTS 30 WORDS
  // SO I HAD TO TAKE MATTERS INTO MY OWN HANDS
  final List<String> profaneWords = [
    'كسمك',
    'بنت الشرموطة',
    'الزاني',
    'الزانية',
    'خول',
    'عرص',
    'متناك',
    'مومس',
    'كس امك',
    'كسمك',
    'كسختك',
    'كسمين',
    'كسمين امك',
    'كس اختك',
    'كسمينك',
    'يلعن امك',
    'يلعن',
    'العن',
    'شاذ',
    'نيك',
    'منيوك',
    'متناك',
    'زانية',
    'بتتناك',
    'شرموطة',
    'شرموط',
    'قحبة',
    'قحاب',
    'عاهرة',
    'عاهر',
    'وسخ',
    'وسخة',
    'غبي',
    'احا',
    'خرا',
    'زبي',
    'زب',
    'طيز',
    'طيزك',
    'بضان',
    'شرمط',
    'معرص',
    'ابن الشرموطة',
    'ابن القحبة',
    'يابن الشرموطة',
    'يابن القحبة',
    'لعنة الله',
    'لعنة',
    'ملعون',
    'كس اخت',
    'كس ام',
    'نيكني',
    'انيكك',
    'انيك',
    'تتناك',
    'يتناك',
    'منايك',
    'مناييك',
    'فاجرة',
    'فاجر',
    'ديوث',
    'قواد',
    'جحش',
    'بهيمة',
    'حقير',
    'نجس',
    'قذر',
    'احة',
    'احا',
    'يلعن دينك',
    'يخرب بيتك',
    'عبيط',
    'اهبل',
    'خولات',
    'وسخين',
    'ابن الوسخة',
    'بنت الوسخة',
    'متبعبص',
    'بعبوص',
    'زق',
    'خنيث',
    'فاسق',
    'منحرف',
    'عرصة',
    'كس اخوك',
    'ايري',
    'اير',
    'بدي انيكك',
    'زامل',
    'قواد',
    'دين',
    'دينك',
    'ديانة',
    'سياسة',
    'نعال',
    'يلعن والديك',
    'kosomak',
    'kos omak',
    'kos om',
    'ks omk',
    'ksomk',
    'ksmk',
    'kosomk',
    'kos',
    'neek',
    'nik',
    'n1k',
    'ne1k',
    'metnak',
    'met2nak',
    'metnayak',
    'metn2k',
    'sharmota',
    'sharmoota',
    '4armota',
    '4armoota',
    'shar2ota',
    'a7a',
    'a7aa',
    'a77a',
    'aha',
    'ahaa',
    '3ars',
    '3rs',
    'ars',
    'khwal',
    '5ol',
    '5wal',
    'khawal',
    'khawl',
    'teez',
    'tiz',
    't1z',
    'teezak',
    'tizak',
    'zeb',
    'zeby',
    'zby',
    'zebi',
    'zibi',
    'zb',
    'zbby',
    'ayr',
    'ayri',
    'eyr',
    'eyri',
    '3ayr',
    '3ayri',
    'gazma',
    'gizma',
    '8azma',
    'wes5',
    'weskh',
    'wesk5',
    'ws5',
    'wskh',
    'ibn el sharmota',
    'ibn sharmota',
    'ebn sharmota',
    'ibn el sharmoota',
    'ebn el sharmota',
    'bent el sharmota',
    'bnt el sharmota',
    'yel3an',
    'yel3n',
    'yl3n',
    'yl3an',
    'la3an',
    'l3an',
    'la3nat',
    'l3nat',
    'manyok',
    'mnyok',
    'manyook',
    'mnouk',
    'mnayek',
    'mnayik',
    '7ayawan',
    '7ywan',
    '5anzeer',
    '5anzir',
    'khanzeer',
    'khanzir',
    '5nzeer',
    '5nzir',
    'khnzeer',
    'khnzir',
    'ka7ba',
    'k7ba',
    'kahba',
    'qahba',
    'qa7ba',
    '2a7ba',
    '2ahba',
    'ahira',
    '3ahira',
    '3ahra',
    '3ahr',
    'dayooth',
    'dywth',
    'dioth',
    'd1oth',
    'labwa',
    'lbwa',
    'lab2a',
    'momis',
    'momes',
    'mums',
    'sharmoota',
    'shrmota',
    '4rmoota',
    'ya kalb',
    'yakalb',
    'yklb',
    'ya ibn el sharmota',
    'yabn el sharmota',
    'ybn el 4armota',
    'kos o5tak',
    'kos okhtak',
    'ks o5tk',
    'ks okhtak',
    'f*ck',
    'sh*t',
    'b*tch',
    '2rs',
    '3rs',
    '5ol',
    '5wal',
    '7ywan',
    '7mar',
    '5nzir',
    '2hba',
    '3hr',
    '4rmota',
    'kossomak',
    'kosommak',
    'kossommak',
    'neik',
    'neeek',
    'n33k',
    'sharmouta',
    'sharmooota',
    'khawal',
    'khaawal',
    'khwaal',
    '5waal',
    '5awaal',
  ];

  // Additional Franco patterns with spaces
  final List<String> francoPhrases = [
    'kos om',
    'ks om',
    'kos omm',
    'ibn el',
    'ebn el',
    'bent el',
    'bnt el',
    'ya ibn',
    'ya ebn',
    'ya bent el',
    'ya bnt el',
    'ya bent l',
    'ya bnt l',
  ];

  final normalizedInput = input.trim().toLowerCase();

  // Remove common character substitutions to catch variations
  final cleanedInput = normalizedInput
      .replaceAll('0', 'o')
      .replaceAll('1', 'i')
      .replaceAll('3', 'e')
      .replaceAll('4', 'a')
      .replaceAll('5', 's')
      .replaceAll('7', 'h')
      .replaceAll('8', 'g')
      .replaceAll('@', 'a')
      .replaceAll('!', 'i')
      .replaceAll('\$', 's');

  // Check exact words
  for (final word in profaneWords) {
    if (normalizedInput.contains(word) || cleanedInput.contains(word)) {
      return true;
    }
  }

  // Check phrases (for multi-word profanities)
  for (final phrase in francoPhrases) {
    if (normalizedInput.contains(phrase) || cleanedInput.contains(phrase)) {
      // Check if it's followed by a profane context
      for (final word in profaneWords) {
        if (normalizedInput.contains('$phrase$word') || normalizedInput.contains('$phrase $word') || cleanedInput.contains('$phrase$word') || cleanedInput.contains('$phrase $word')) {
          return true;
        }
      }
    }
  }

  // Check for word boundaries to avoid false positives
  final words = normalizedInput.split(RegExp(r'\s+'));
  final cleanedWords = cleanedInput.split(RegExp(r'\s+'));

  for (final word in words + cleanedWords) {
    if (profaneWords.contains(word)) {
      return true;
    }
  }

  return false;
}

bool isEmojiOnly(String content) {
  final emojiRegex = RegExp(r'^[\u{1F300}-\u{1FAFF}\u{1F1E6}-\u{1F1FF}\u{2600}-\u{26FF}\u{2700}-\u{27BF}\u200d\s]+$', unicode: true);
  return emojiRegex.hasMatch(content.trim());
}

IconData getReplyIcon(String contentType) {
  switch (contentType) {
    case 'text':
      return Icons.chat_bubble_outline;
    case 'record':
      return Icons.mic;
    case 'image':
      return Icons.image;
    case 'video':
      return Icons.videocam;
    default:
      return Icons.attach_file;
  }
}

String getReplyPreviewText(MessageClass message) {
  switch (message.contentType) {
    case 'text':
      return message.content.length > 60 ? '${message.content.substring(0, 60)}...' : message.content;
    case 'record':
      return '🎵 Voice message';
    case 'image':
      return '📷 Photo';
    case 'video':
      return '🎥 Video';
    default:
      return '📎 Attachment';
  }
}

TextDirection getTextDirectionForText(String text) {
  if (text.isEmpty) return TextDirection.ltr;

  final firstChar = text[0];
  final isRtl = RegExp(r'[\u0600-\u06FF\u0750-\u077F\u08A0-\u08FF\uFB50-\uFDFF\uFE70-\uFEFF]').hasMatch(firstChar);
  return isRtl ? TextDirection.rtl : TextDirection.ltr;
}

bool isPathVideo(String path) {
  final extension = p.extension(path).toLowerCase();
  final isVideo = ['.mp4', '.mov', '.avi', '.mkv', '.flv', '.wmv'].contains(extension);
  return isVideo;
}

class WarningBox extends StatelessWidget {
  final String warning;
  const WarningBox({super.key, required this.warning});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: kDeepPink.withOpacity(0.05),
        border: Border.all(color: kDeepPink),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 20, color: kDeepPink),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              warning,
              style: GoogleFonts.lexendDeca(
                fontSize: 13,
                color: kDeepPink,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class CityAirportMapping {
  static const Map<String, String> _cityToAirportCode = {
    'New York': 'JFK',
    'Mexico City': 'MEX',
    'Barcelona': 'BCN',
    'Moscow': 'SVO',
    'Berlin': 'BER',
    'Paris': 'CDG',
    'Dubai': 'DXB',
    'Rome': 'FCO',
    'Toronto': 'YYZ',
    'Los Angeles': 'LAX',
    'Rio de Janeiro': 'GIG',
    'Shanghai': 'PVG',
  };

  /// Get airport code for a city name
  /// Returns the airport code if found, otherwise returns the original city name
  static String getAirportCode(String cityName) {
    final code = _cityToAirportCode[cityName];
    if (code != null) {
      return code;
    }

    // Try case-insensitive search
    final lowerCityName = cityName.toLowerCase();
    for (final entry in _cityToAirportCode.entries) {
      if (entry.key.toLowerCase() == lowerCityName) {
        return entry.value;
      }
    }

    // If not found, return the original city name as fallback
    print('Warning: Airport code not found for city: $cityName');
    return cityName;
  }

  /// Get all supported cities
  static List<String> getSupportedCities() {
    return _cityToAirportCode.keys.toList()..sort();
  }

  /// Check if a city is supported
  static bool isCitySupported(String cityName) {
    return _cityToAirportCode.containsKey(cityName) || _cityToAirportCode.keys.any((city) => city.toLowerCase() == cityName.toLowerCase());
  }

  /// Get city name from airport code
  static String? getCityFromAirportCode(String airportCode) {
    for (final entry in _cityToAirportCode.entries) {
      if (entry.value == airportCode.toUpperCase()) {
        return entry.key;
      }
    }
    return null;
  }
}
