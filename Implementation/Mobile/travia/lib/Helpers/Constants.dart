import 'package:flutter/material.dart';

import 'AppColors.dart';

BoxDecoration backGroundColor() {
  return BoxDecoration(color: Colors.white);
}

final List<Map<String, String>> countries = [
  // Arabic countries
  {'code': 'EG', 'name': 'Egypt', 'emoji': '🇪🇬'},
  {'code': 'SA', 'name': 'Saudi Arabia', 'emoji': '🇸🇦'},
  {'code': 'LY', 'name': 'Libya', 'emoji': '🇱🇾'},
  {'code': 'AE', 'name': 'UAE', 'emoji': '🇦🇪'},
  {'code': 'JO', 'name': 'Jordan', 'emoji': '🇯🇴'},
  {'code': 'YE', 'name': 'Yemen', 'emoji': '🇾🇪'},
  {'code': 'OM', 'name': 'Oman', 'emoji': '🇴🇲'},
  {'code': 'QA', 'name': 'Qatar', 'emoji': '🇶🇦'},
  {'code': 'KW', 'name': 'Kuwait', 'emoji': '🇰🇼'},
  {'code': 'BH', 'name': 'Bahrain', 'emoji': '🇧🇭'},
  {'code': 'SY', 'name': 'Syria', 'emoji': '🇸🇾'},
  {'code': 'LB', 'name': 'Lebanon', 'emoji': '🇱🇧'},
  {'code': 'IQ', 'name': 'Iraq', 'emoji': '🇮🇶'},
  {'code': 'SD', 'name': 'Sudan', 'emoji': '🇸🇩'},
  {'code': 'DZ', 'name': 'Algeria', 'emoji': '🇩🇿'},
  {'code': 'MA', 'name': 'Morocco', 'emoji': '🇲🇦'},
  {'code': 'TN', 'name': 'Tunisia', 'emoji': '🇹🇳'},
  {'code': 'PS', 'name': 'Palestine', 'emoji': '🇵🇸'},
  {'code': 'MR', 'name': 'Mauritania', 'emoji': '🇲🇷'},
  {'code': 'US', 'name': 'United States', 'emoji': '🇺🇸'},
  {'code': 'GB', 'name': 'United Kingdom', 'emoji': '🇬🇧'},
  {'code': 'FR', 'name': 'France', 'emoji': '🇫🇷'},
  {'code': 'DE', 'name': 'Germany', 'emoji': '🇩🇪'},
  {'code': 'IT', 'name': 'Italy', 'emoji': '🇮🇹'},
  {'code': 'ES', 'name': 'Spain', 'emoji': '🇪🇸'},
  {'code': 'JP', 'name': 'Japan', 'emoji': '🇯🇵'},
  {'code': 'CN', 'name': 'China', 'emoji': '🇨🇳'},
  {'code': 'IN', 'name': 'India', 'emoji': '🇮🇳'},
  {'code': 'BR', 'name': 'Brazil', 'emoji': '🇧🇷'},
  {'code': 'MX', 'name': 'Mexico', 'emoji': '🇲🇽'},
  {'code': 'CA', 'name': 'Canada', 'emoji': '🇨🇦'},
  {'code': 'AU', 'name': 'Australia', 'emoji': '🇦🇺'},
  {'code': 'RU', 'name': 'Russia', 'emoji': '🇷🇺'},
  {'code': 'KR', 'name': 'South Korea', 'emoji': '🇰🇷'},
  {'code': 'ZA', 'name': 'South Africa', 'emoji': '🇿🇦'},
  {'code': 'AR', 'name': 'Argentina', 'emoji': '🇦🇷'},
  {'code': 'TR', 'name': 'Turkey', 'emoji': '🇹🇷'},
  {'code': 'GR', 'name': 'Greece', 'emoji': '🇬🇷'},
  {'code': 'TH', 'name': 'Thailand', 'emoji': '🇹🇭'},
  {'code': 'SE', 'name': 'Sweden', 'emoji': '🇸🇪'},
  {'code': 'NO', 'name': 'Norway', 'emoji': '🇳🇴'},
  {'code': 'CH', 'name': 'Switzerland', 'emoji': '🇨🇭'},
  {'code': 'NL', 'name': 'Netherlands', 'emoji': '🇳🇱'},
  {'code': 'BE', 'name': 'Belgium', 'emoji': '🇧🇪'},
  {'code': 'PT', 'name': 'Portugal', 'emoji': '🇵🇹'},
  {'code': 'NZ', 'name': 'New Zealand', 'emoji': '🇳🇿'},
  {'code': 'AT', 'name': 'Austria', 'emoji': '🇦🇹'},
  {'code': 'IE', 'name': 'Ireland', 'emoji': '🇮🇪'},
  {'code': 'DK', 'name': 'Denmark', 'emoji': '🇩🇰'},
  {'code': 'FI', 'name': 'Finland', 'emoji': '🇫🇮'},
  {'code': 'PL', 'name': 'Poland', 'emoji': '🇵🇱'},
  {'code': 'CZ', 'name': 'Czech Republic', 'emoji': '🇨🇿'},
  {'code': 'HU', 'name': 'Hungary', 'emoji': '🇭🇺'},
  {'code': 'PE', 'name': 'Peru', 'emoji': '🇵🇪'},
  {'code': 'CL', 'name': 'Chile', 'emoji': '🇨🇱'},
  {'code': 'CO', 'name': 'Colombia', 'emoji': '🇨🇴'},
  {'code': 'VE', 'name': 'Venezuela', 'emoji': '🇻🇪'},
  {'code': 'VN', 'name': 'Vietnam', 'emoji': '🇻🇳'},
  {'code': 'PH', 'name': 'Philippines', 'emoji': '🇵🇭'},
  {'code': 'MY', 'name': 'Malaysia', 'emoji': '🇲🇾'},
  {'code': 'SG', 'name': 'Singapore', 'emoji': '🇸🇬'},
  {'code': 'ID', 'name': 'Indonesia', 'emoji': '🇮🇩'},
  {'code': 'PK', 'name': 'Pakistan', 'emoji': '🇵🇰'},
  {'code': 'BD', 'name': 'Bangladesh', 'emoji': '🇧🇩'},
  {'code': 'IR', 'name': 'Iran', 'emoji': '🇮🇷'},
  {'code': 'UA', 'name': 'Ukraine', 'emoji': '🇺🇦'},
  {'code': 'RO', 'name': 'Romania', 'emoji': '🇷🇴'},
  {'code': 'IS', 'name': 'Iceland', 'emoji': '🇮🇸'},
  {'code': 'CY', 'name': 'Cyprus', 'emoji': '🇨🇾'},
];

class BadgeStyle {
  final List<Color> gradient;
  final IconData icon;

  const BadgeStyle({required this.gradient, required this.icon});
}

final Map<String, BadgeStyle> badgeStyles = {
  'Founder': BadgeStyle(
    gradient: [Colors.orange, Colors.deepOrange],
    icon: Icons.verified,
  ),
  'isYounisBaby': BadgeStyle(
    gradient: [Colors.red, Colors.purple],
    icon: Icons.monetization_on,
  ),
  'Poster': BadgeStyle(
    gradient: [Colors.blue, Colors.indigo],
    icon: Icons.post_add,
  ),
  'Story Teller': BadgeStyle(
    gradient: [Colors.purple, Colors.deepPurple],
    icon: Icons.history_edu,
  ),
  'Adventurer': BadgeStyle(
    gradient: [Colors.green, Colors.teal],
    icon: Icons.explore,
  ),
  'Social': BadgeStyle(
    gradient: [Colors.pink, Colors.redAccent],
    icon: Icons.forum,
  ),
  'Trendy': BadgeStyle(
    gradient: [Colors.amber, Colors.deepOrangeAccent],
    icon: Icons.trending_up,
  ),
  'Ramy': BadgeStyle(
    gradient: [Colors.cyan, Colors.lightBlueAccent],
    icon: Icons.local_cafe,
  ),
  'International': BadgeStyle(
    gradient: [Colors.teal, Colors.lightBlue],
    icon: Icons.public,
  ),
  'Popular': BadgeStyle(
    gradient: [Colors.deepPurple, Colors.pink],
    icon: Icons.people_alt,
  ),
  'Clean': BadgeStyle(
    gradient: [Colors.grey, Colors.green],
    icon: Icons.flag,
  ),
  'New User': BadgeStyle(
    gradient: [kDeepPink, Colors.black],
    icon: Icons.fiber_new,
  ),
};

final defaultBadgeStyle = BadgeStyle(
  gradient: [kDeepPink, Colors.black],
  icon: Icons.star_border,
);
