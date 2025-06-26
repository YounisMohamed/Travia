class Business {
  final int id;
  final String name;
  final String locality;
  final String region;
  final String? country;
  final String? city;
  final double stars;
  final int priceRange;
  final String? businessId;
  final List<String> cuisines;
  final bool hasWifi;
  final bool goodForKids;
  final String? address;
  final double? latitude;
  final double? longitude;
  final List<String>? categories;
  final String? primaryCategory;
  final int? reviewCount;
  final String? phone;
  final String? website;
  final List<String>? photos;
  final bool? acceptsCreditCards;
  final bool? goodForBreakfast;
  final bool? goodForLunch;
  final bool? goodForDinner;
  final bool? goodForDessert;
  final bool? servesBeer;
  final bool? hasDelivery;
  final bool? ambienceRomantic;
  final bool? ambienceTrendy;
  final bool? ambienceTouristy;
  final bool? ambienceCasual;
  final bool? ambienceClassy;
  final bool? isBar;
  final bool? isNightlife;
  final bool? isBeautyHealth;
  final bool? isCafe;
  final bool? isGym;
  final bool? isRestaurant;
  final bool? isShop;
  final Map<String, String>? hours;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Business({
    required this.id,
    required this.name,
    required this.locality,
    required this.region,
    this.country,
    this.city,
    required this.stars,
    required this.priceRange,
    this.businessId,
    required this.cuisines,
    required this.hasWifi,
    required this.goodForKids,
    this.address,
    this.latitude,
    this.longitude,
    this.categories,
    this.primaryCategory,
    this.reviewCount,
    this.phone,
    this.website,
    this.photos,
    this.acceptsCreditCards,
    this.goodForBreakfast,
    this.goodForLunch,
    this.goodForDinner,
    this.goodForDessert,
    this.servesBeer,
    this.hasDelivery,
    this.ambienceRomantic,
    this.ambienceTrendy,
    this.ambienceTouristy,
    this.ambienceCasual,
    this.ambienceClassy,
    this.isBar,
    this.isNightlife,
    this.isBeautyHealth,
    this.isCafe,
    this.isGym,
    this.isRestaurant,
    this.isShop,
    this.hours,
    this.createdAt,
    this.updatedAt,
  });

  factory Business.fromJson(Map<String, dynamic> json) {
    Map<String, String>? hours;
    if (json['hours_monday'] != null) {
      hours = {
        'monday': json['hours_monday'] ?? '',
        'tuesday': json['hours_tuesday'] ?? '',
        'wednesday': json['hours_wednesday'] ?? '',
        'thursday': json['hours_thursday'] ?? '',
        'friday': json['hours_friday'] ?? '',
        'saturday': json['hours_saturday'] ?? '',
        'sunday': json['hours_sunday'] ?? '',
      };
    }

    return Business(
      id: json['id'],
      name: json['name'],
      locality: json['locality'],
      region: json['region'],
      country: json['country'],
      city: json['city'],
      stars: (json['stars'] ?? 0).toDouble(),
      priceRange: json['price_range'] ?? 2,
      businessId: json['business_id'],
      cuisines: List<String>.from(json['cuisines'] ?? []),
      hasWifi: json['has_wifi'] ?? false,
      goodForKids: json['good_for_kids'] ?? false,
      address: json['address'],
      latitude: json['latitude']?.toDouble(),
      longitude: json['longitude']?.toDouble(),
      categories: json['categories'] != null ? List<String>.from(json['categories']) : null,
      primaryCategory: json['primary_category'],
      reviewCount: json['review_count'],
      phone: json['phone'],
      website: json['website'],
      photos: json['photos'] != null ? List<String>.from(json['photos']) : null,
      acceptsCreditCards: json['accepts_credit_cards'],
      goodForBreakfast: json['good_for_breakfast'],
      goodForLunch: json['good_for_lunch'],
      goodForDinner: json['good_for_dinner'],
      goodForDessert: json['good_for_dessert'],
      servesBeer: json['serves_beer'],
      hasDelivery: json['has_delivery'],
      ambienceRomantic: json['ambience_romantic'],
      ambienceTrendy: json['ambience_trendy'],
      ambienceTouristy: json['ambience_touristy'],
      ambienceCasual: json['ambience_casual'],
      ambienceClassy: json['ambience_classy'],
      isBar: json['is_bar'],
      isNightlife: json['is_nightlife'],
      isBeautyHealth: json['is_beauty_health'],
      isCafe: json['is_cafe'],
      isGym: json['is_gym'],
      isRestaurant: json['is_restaurant'],
      isShop: json['is_shop'],
      hours: hours,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : null,
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at']) : null,
    );
  }

  /// Get price range as dollar signs
  String get priceRangeSymbol => '\$' * priceRange.clamp(1, 4);

  /// Get ambience tags
  List<String> get ambienceTags {
    final tags = <String>[];
    if (ambienceRomantic == true) tags.add('Romantic');
    if (ambienceTrendy == true) tags.add('Trendy');
    if (ambienceTouristy == true) tags.add('Touristy');
    if (ambienceCasual == true) tags.add('Casual');
    if (ambienceClassy == true) tags.add('Classy');
    return tags;
  }

  /// Get business type
  String get businessType {
    if (isRestaurant == true) return 'Restaurant';
    if (isCafe == true) return 'Cafe';
    if (isBar == true) return 'Bar';
    if (isGym == true) return 'Gym';
    if (isBeautyHealth == true) return 'Beauty & Health';
    if (isShop == true) return 'Shop';
    if (isNightlife == true) return 'Nightlife';
    return 'Business';
  }

  @override
  String toString() {
    return 'Business{id: $id, name: $name, locality: $locality, region: $region, country: $country, city: $city, stars: $stars, priceRange: $priceRange, businessId: $businessId, cuisines: $cuisines, hasWifi: $hasWifi, goodForKids: $goodForKids, address: $address, latitude: $latitude, longitude: $longitude, categories: $categories, primaryCategory: $primaryCategory, reviewCount: $reviewCount, phone: $phone, website: $website, photos: $photos, acceptsCreditCards: $acceptsCreditCards, goodForBreakfast: $goodForBreakfast, goodForLunch: $goodForLunch, goodForDinner: $goodForDinner, goodForDessert: $goodForDessert, servesBeer: $servesBeer, hasDelivery: $hasDelivery, ambienceRomantic: $ambienceRomantic, ambienceTrendy: $ambienceTrendy, ambienceTouristy: $ambienceTouristy, ambienceCasual: $ambienceCasual, ambienceClassy: $ambienceClassy, isBar: $isBar, isNightlife: $isNightlife, isBeautyHealth: $isBeautyHealth, isCafe: $isCafe, isGym: $isGym, isRestaurant: $isRestaurant, isShop: $isShop, hours: $hours, createdAt: $createdAt, updatedAt: $updatedAt}';
  }
}
