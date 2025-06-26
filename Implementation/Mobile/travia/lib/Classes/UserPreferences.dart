class UserPreferences {
  final int budget;
  final int travelDays;
  final String travelStyle;
  final String noisePreference;
  final bool familyFriendly;
  final String accommodationType;
  final List<String> preferredCuisine;
  final String ambiencePreference;
  final bool goodForKids;
  final bool includeGym;
  final bool includeBar;
  final bool includeNightlife;
  final bool includeBeautyHealth;
  final bool includeShop;
  final String location;
  final bool? includeTrendyPlaces;
  final bool? includeRomanticPlaces;
  final bool? includeTouristyPlaces;

  UserPreferences({
    required this.budget,
    required this.travelDays,
    required this.travelStyle,
    required this.noisePreference,
    required this.familyFriendly,
    required this.accommodationType,
    required this.preferredCuisine,
    required this.ambiencePreference,
    required this.goodForKids,
    required this.includeGym,
    required this.includeBar,
    required this.includeNightlife,
    required this.includeBeautyHealth,
    required this.includeShop,
    required this.location,
    this.includeTrendyPlaces = false,
    this.includeRomanticPlaces = false,
    this.includeTouristyPlaces = false,
  });

  Map<String, dynamic> toJson() => {
        'budget': budget,
        'travel_days': travelDays,
        'travel_style': travelStyle,
        'noise_preference': noisePreference,
        'family_friendly': familyFriendly,
        'accommodation_type': accommodationType,
        'preferred_cuisine': preferredCuisine,
        'ambience_preference': ambiencePreference,
        'good_for_kids': goodForKids,
        'include_gym': includeGym,
        'include_bar': includeBar,
        'include_nightlife': includeNightlife,
        'include_beauty_health': includeBeautyHealth,
        'include_shop': includeShop,
        'location': location,
        'include_trendy_places': includeTrendyPlaces,
        'include_romantic_places': includeRomanticPlaces,
        'include_touristy_places': includeTouristyPlaces,
      };

  factory UserPreferences.fromJson(Map<String, dynamic> json) {
    return UserPreferences(
      budget: json['budget'] ?? 2,
      travelDays: json['travel_days'] ?? 3,
      travelStyle: json['travel_style'] ?? 'tourist',
      noisePreference: json['noise_preference'] ?? 'quiet',
      familyFriendly: json['family_friendly'] ?? false,
      accommodationType: json['accommodation_type'] ?? 'hotel',
      preferredCuisine: List<String>.from(json['preferred_cuisine'] ?? []),
      ambiencePreference: json['ambience_preference'] ?? 'casual',
      goodForKids: json['good_for_kids'] ?? false,
      includeGym: json['include_gym'] ?? false,
      includeBar: json['include_bar'] ?? false,
      includeNightlife: json['include_nightlife'] ?? false,
      includeBeautyHealth: json['include_beauty_health'] ?? false,
      includeShop: json['include_shop'] ?? false,
      location: json['location'] ?? '',
      includeTrendyPlaces: json['include_trendy_places'] ?? false,
      includeRomanticPlaces: json['include_romantic_places'] ?? false,
      includeTouristyPlaces: json['include_touristy_places'] ?? false,
    );
  }

  @override
  String toString() {
    return 'UserPreferences{budget: $budget, travelDays: $travelDays, travelStyle: $travelStyle, noisePreference: $noisePreference, familyFriendly: $familyFriendly, accommodationType: $accommodationType, preferredCuisine: $preferredCuisine, ambiencePreference: $ambiencePreference, goodForKids: $goodForKids, includeGym: $includeGym, includeBar: $includeBar, includeNightlife: $includeNightlife, includeBeautyHealth: $includeBeautyHealth, includeShop: $includeShop, location: $location, includeTrendyPlaces: $includeTrendyPlaces, includeRomanticPlaces: $includeRomanticPlaces, includeTouristyPlaces: $includeTouristyPlaces}';
  }
}
