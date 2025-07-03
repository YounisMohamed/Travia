import 'package:bottom_picker/bottom_picker.dart';
import 'package:bottom_picker/resources/arrays.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:lottie/lottie.dart';
import 'package:travia/Helpers/AppColors.dart';
import 'package:travia/Helpers/HelperMethods.dart';
import 'package:travia/Helpers/PopUp.dart';
import 'package:travia/MainFlow/YourPlansPage.dart';

import '../Classes/UserPreferences.dart';
import '../Helpers/Constants.dart';
import '../Helpers/GoogleTexts.dart';
import '../Services/PlannerService.dart';
import 'CitySelector.dart';

// Providers for state management
final plannerTypeProvider = StateProvider<String?>((ref) => null); // 'basic' or 'advanced'
final daysProvider = StateProvider<int>((ref) => 1);
final budgetRangeProvider = StateProvider<String>((ref) => '\$\$');
final selectedActivitiesProvider = StateProvider<Set<String>>((ref) => {});
final cuisineTypeProvider = StateProvider<Set<String>>((ref) => {'All'});
final additionalPreferencesProvider = StateProvider<Set<String>>((ref) => {});
final selectedCityProvider = StateProvider<String?>((ref) => null);
final timeOfTravel = StateProvider<DateTime>((ref) => DateTime.now().add(Duration(days: 1)));
final isActivitiesCollapsedProvider = StateProvider<bool>((ref) => true);
final isCuisineCollapsedProvider = StateProvider<bool>((ref) => true);

final isCreatingPlanProvider = StateProvider<bool>((ref) => false);

// Budget mapping
Map<String, int> budgetToApiValue = {
  '\$': 1,
  '\$\$': 2,
  '\$\$\$': 3,
  '\$\$\$\$': 4,
};

// Activity mapping
Map<String, String> activityToApiField = {
  'Bars': 'is_bar',
  'Nightlife': 'is_nightlife',
  'Gyms': 'is_gym',
  'Beauty & Health': 'is_beauty_health',
  'Shopping': 'is_shop',
};

// Budget options
final budgetOptions = ['\$', '\$\$', '\$\$\$', '\$\$\$\$'];

// Activity options
final activityOptions = ['Gyms', 'Bars', 'Nightlife', 'Beauty & Health', 'Shopping'];

// Cuisine options
final cuisineOptions = [
  'Italian',
  'Mexican',
  'Tapas',
  'French',
  'Fast Food',
  'Seafood',
  'Burgers',
  'Brazilian',
  'Sushi',
  'American',
];

// Additional preferences
final additionalPreferences = ['Family Friendly Places', 'Good for Kids', 'Noisy Places', 'Classy Places'];

class PlanPage extends ConsumerStatefulWidget {
  @override
  ConsumerState<PlanPage> createState() => _PlanPageState();
}

class _PlanPageState extends ConsumerState<PlanPage> with SingleTickerProviderStateMixin {
  Widget _buildCreateItineraryButton() {
    return Consumer(
      builder: (context, ref, child) {
        final isCreating = ref.watch(isCreatingPlanProvider);

        return SizedBox(
          width: double.infinity,
          height: 55,
          child: ElevatedButton(
            onPressed: isCreating
                ? null
                : () async {
                    // Get all provider values
                    final days = ref.read(daysProvider);
                    final city = ref.read(selectedCityProvider);
                    final date = ref.read(timeOfTravel);
                    final budgetString = ref.read(budgetRangeProvider);
                    final selectedActivities = ref.read(selectedActivitiesProvider);
                    final cuisineTypes = ref.read(cuisineTypeProvider);
                    final additionalPreferences = ref.read(additionalPreferencesProvider);
                    final plannerType = ref.read(plannerTypeProvider);

                    // Validate city selection
                    if (city == null) {
                      Popup.showError(text: "Please select a city", context: context);
                      return;
                    }

                    showTravelPlanLoadingDialog(context, city, days);

                    // Set loading state
                    ref.read(isCreatingPlanProvider.notifier).state = true;

                    try {
                      // Convert budget string to API value
                      final budget = budgetToApiValue[budgetString] ?? 2;

                      // Convert cuisine types (remove 'All' if present)
                      final preferredCuisine = cuisineTypes.where((c) => c != 'All').toList();

                      // Parse additional preferences
                      final familyFriendly = additionalPreferences.contains('Family Friendly');
                      final goodForKids = additionalPreferences.contains('Good for Kids');
                      final noise_preference = additionalPreferences.contains('Noisy Places') ? 'noisy' : 'quiet';
                      final ambience = additionalPreferences.contains('Classy Places') ? 'classy' : 'casual';

                      // Map activities to include flags
                      final includeGym = selectedActivities.contains('Gyms');
                      final includeBar = selectedActivities.contains('Bars');
                      final includeNightlife = selectedActivities.contains('Nightlife');
                      final includeBeautyHealth = selectedActivities.contains('Beauty & Health');
                      final includeShop = selectedActivities.contains('Shopping');

                      // Determine travel style based on planner type
                      final travelStyle = plannerType == 'advanced' ? 'local' : 'tourist';
                      // TOURIST IF BASIC

                      // Create user preferences
                      final preferences = UserPreferences(
                        budget: budget,
                        travelDays: days,
                        travelStyle: travelStyle,
                        noisePreference: noise_preference,
                        familyFriendly: familyFriendly,
                        accommodationType: 'hotel',
                        preferredCuisine: preferredCuisine,
                        ambiencePreference: ambience,
                        goodForKids: goodForKids,
                        includeGym: includeGym,
                        includeBar: includeBar,
                        includeNightlife: includeNightlife,
                        includeBeautyHealth: includeBeautyHealth,
                        includeShop: includeShop,
                        location: city,
                      );

                      // Get travel planner service
                      final planner = TravelPlannerService.instance;
                      final userId = FirebaseAuth.instance.currentUser!.uid;

                      // Save preferences
                      await planner.savePreferences(
                        userId: userId,
                        preferences: preferences,
                      );

                      // Generate itinerary
                      final itinerary = await planner.generateItinerary(
                        userId: userId,
                        city: city,
                      );

                      // Save the itinerary to database
                      final String tripId = await planner.saveItinerary(
                        userId: userId,
                        itinerary: itinerary,
                        tripDate: date,
                      );
                      //Future.delayed(Duration(seconds: 10));

                      print("GENERATED ITINERARY: ${itinerary.toString()}");

                      // Close the loading dialog
                      if (context.mounted) {
                        Navigator.of(context).pop(); // Close loading dialog
                        context.push('/plan-result/$tripId');
                      }
                    } catch (e) {
                      // Close the loading dialog
                      if (context.mounted) {
                        Navigator.of(context).pop(); // Close loading dialog

                        Popup.showError(
                          text: e is TravelPlannerException ? e.message : "Failed to create travel plan. Please try again.",
                          context: context,
                        );
                      }
                    } finally {
                      // Reset loading state
                      ref.read(isCreatingPlanProvider.notifier).state = false;
                    }
                  },
            style: ElevatedButton.styleFrom(
              backgroundColor: kDeepPink,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
              elevation: 0,
            ),
            child: Text(
              'Create My Plan',
              style: GoogleFonts.ibmPlexSans(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        );
      },
    );
  }

  late TabController _tabController;
  final ScrollController _scrollController = ScrollController();
  final PageController _pageController = PageController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _scrollController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void showTravelPlanLoadingDialog(BuildContext context, String city, int days) {
    final controller = AnimationController(
      vsync: Navigator.of(context), // requires TickerProvider
      duration: const Duration(seconds: 1), // duration doesn't matter here
    );

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          insetPadding: const EdgeInsets.all(24),
          backgroundColor: Colors.white,
          child: StatefulBuilder(
            builder: (context, setState) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 🧵 Speed-controlled animation
                    SizedBox(
                      height: 120,
                      child: Lottie.asset(
                        'assets/tailor.json',
                        repeat: true,
                        fit: BoxFit.contain,
                        controller: controller,
                        onLoaded: (composition) {
                          controller
                            ..duration = composition.duration
                            ..repeat(
                              min: 0,
                              max: 1,
                              period: composition.duration! ~/ 3, // 3x speed
                            );
                        },
                      ),
                    ),

                    const SizedBox(height: 16),

                    Text(
                      'Tailoring your trip...',
                      style: GoogleFonts.ibmPlexSans(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: kDeepPink,
                      ),
                    ),

                    const SizedBox(height: 8),

                    Text(
                      'We’re stitching together the perfect ${days}-day adventure in $city ✨',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.ibmPlexSans(
                        fontSize: 16,
                        color: Colors.grey[700],
                      ),
                    ),

                    const SizedBox(height: 24),

                    LinearProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(kDeepPink),
                      backgroundColor: kDeepPink.withOpacity(0.2),
                    ),

                    const SizedBox(height: 12),

                    Text(
                      'Finding hidden gems, perfect bites, and just the right vibes...',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.ibmPlexSans(
                        fontSize: 14,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  void showDatePicker(BuildContext context) {
    final minDate = DateTime.now().add(Duration(days: 1));
    final selected = ref.watch(timeOfTravel);
    final initial = selected.isBefore(minDate) ? minDate : selected;

    BottomPicker.date(
      pickerTitle: Text(
        'Select Departure Date',
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 16,
          color: Colors.black,
        ),
      ),
      backgroundColor: Colors.white,
      pickerTextStyle: const TextStyle(
        color: Colors.black,
        fontSize: 16,
      ),
      onSubmit: (date) {
        ref.read(timeOfTravel.notifier).state = date;
      },
      buttonSingleColor: kDeepPink,
      initialDateTime: initial,
      minDateTime: minDate,
      maxDateTime: DateTime.now().add(Duration(days: 100)),
      closeIconColor: Colors.black,
      bottomPickerTheme: BottomPickerTheme.plumPlate,
      buttonAlignment: MainAxisAlignment.center,
      titleAlignment: Alignment.center,
      buttonContent: Center(
        child: Text(
          'Confirm',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    ).show(context);
  }

  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async {
        refresh(context);
      },
      displacement: 32,
      color: kDeepPink,
      backgroundColor: Colors.white,
      child: Scaffold(
        backgroundColor: kBackground,
        appBar: AppBar(
          backgroundColor: kBackground,
          elevation: 0,
          title: TypewriterAnimatedText(
            text: 'Plan your perfect trip',
            style: GoogleFonts.ibmPlexSans(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 20),
          ),
          centerTitle: true,
          bottom: PreferredSize(
            preferredSize: Size.fromHeight(60),
            child: TabBar(
              controller: _tabController,
              labelColor: kDeepPink,
              unselectedLabelColor: Colors.black,
              labelStyle: GoogleFonts.lexendDeca(fontWeight: FontWeight.bold),
              indicatorColor: kDeepPink,
              tabs: [
                Tab(text: 'Plan'),
                Tab(text: 'Your plans'),
              ],
            ),
          ),
        ),
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildPlanTab(),
            YourPlansPage(),
          ],
        ),
      ),
    );
  }

  Widget _buildPlanTab() {
    final plannerType = ref.watch(plannerTypeProvider);

    if (plannerType == null) {
      return _buildPlannerTypeSelection();
    } else {
      return _buildMainPlanner();
    }
  }

  Widget _buildPlannerTypeSelection() {
    return Container(
      decoration: BoxDecoration(
        color: kBackground,
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: [
              SizedBox(height: 20),
              Text(
                'Choose Your Planning Style',
                textAlign: TextAlign.center,
                style: GoogleFonts.lexendDeca(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              SizedBox(height: 12),
              Text(
                'Tailor your trip to match your travel personality',
                style: GoogleFonts.lexendDeca(
                  fontSize: 16,
                  color: Colors.black54,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 40),
              // Basic Planner Card
              _buildPlannerCard(
                type: 'basic',
                title: 'Basic Planner',
                subtitle: 'Perfect If you want to quickly plan with no extra preferences or options',
                icon: Icons.explore_outlined,
                features: [
                  'Choose trip duration',
                  'Set your budget range',
                  'Pick favorite activities',
                  'Get instant recommendations',
                ],
                gradient: [Colors.black, kDeepPink],
              ),
              SizedBox(height: 30),
              // Advanced Planner Card
              _buildPlannerCard(
                type: 'advanced',
                title: 'Advanced Planner',
                subtitle: 'More accurate and detailed',
                icon: Icons.star_outline,
                features: [
                  'Everything in Basic',
                  'Cuisine preferences',
                  'Family-friendly options',
                  'Local vs Tourist experiences',
                ],
                gradient: [Colors.black, kDeepPinkLight],
              ),
              SizedBox(height: 40),
              Text(
                'You can always switch between modes',
                style: GoogleFonts.lexendDeca(
                  fontSize: 14,
                  color: Colors.black38,
                  fontStyle: FontStyle.italic,
                ),
              ),
              SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlannerCard({
    required String type,
    required String title,
    required String subtitle,
    required IconData icon,
    required List<String> features,
    required List<Color> gradient,
  }) {
    return GestureDetector(
      onTap: () {
        ref.read(plannerTypeProvider.notifier).state = type;
      },
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: gradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: kDeepPink.withOpacity(0.25),
              blurRadius: 20,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(
                  icon,
                  color: Colors.white,
                  size: 36,
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    type == 'basic' ? 'QUICK' : 'DETAILED',
                    style: GoogleFonts.lexendDeca(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 20),
            Text(
              title,
              style: GoogleFonts.lexendDeca(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            SizedBox(height: 8),
            Text(
              subtitle,
              style: GoogleFonts.lexendDeca(
                fontSize: 16,
                color: Colors.white.withOpacity(0.9),
              ),
            ),
            SizedBox(height: 20),
            ...features
                .map((feature) => Padding(
                      padding: EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Icon(
                            Icons.check_circle,
                            color: Colors.white.withOpacity(0.9),
                            size: 18,
                          ),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              feature,
                              style: GoogleFonts.lexendDeca(
                                fontSize: 14,
                                color: Colors.white.withOpacity(0.9),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ))
                .toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildMainPlanner() {
    final plannerType = ref.watch(plannerTypeProvider);

    return SingleChildScrollView(
      controller: _scrollController,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Planner type indicator with switch button
            Container(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: kDeepPink.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        plannerType == 'basic' ? Icons.explore_outlined : Icons.star_outline,
                        color: kDeepPink,
                        size: 20,
                      ),
                      SizedBox(width: 8),
                      Text(
                        plannerType == 'basic' ? 'Basic Mode' : 'Advanced Mode',
                        style: GoogleFonts.lexendDeca(
                          color: kDeepPink,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  TextButton(
                    onPressed: () {
                      ref.read(plannerTypeProvider.notifier).state = null;
                    },
                    child: Text(
                      'Switch',
                      style: GoogleFonts.lexendDeca(
                        color: kDeepPink,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 30),
            _buildCitySelector(),
            SizedBox(height: 30),

            // Days selector
            _buildDaysSelector(),
            SizedBox(height: 40),

            _buildDatePicker(),
            SizedBox(height: 10),
            WarningBox(warning: "We optionally need the departure date of your trip to get the best hotel and flight deals."),
            SizedBox(height: 30),
            // Budget Range selector
            _buildBudgetRangeSelector(),
            SizedBox(height: 40),

            // Activities selector
            _buildActivitiesSelector(),
            SizedBox(height: 40),

            // Advanced options (only for advanced planner)
            if (plannerType == 'advanced') ...[
              _buildCuisineSelector(),
              SizedBox(height: 40),
              _buildAdditionalPreferences(),
              SizedBox(height: 40),
            ],

            // Create Itinerary button
            _buildCreateItineraryButton(),
            SizedBox(height: 20),

            // Bottom text
            Center(
              child: Text(
                'Your perfect trip is just a few taps away',
                textAlign: TextAlign.center,
                style: GoogleFonts.lexendDeca(
                  color: Colors.black54,
                  fontSize: 14,
                ),
              ),
            ),
            SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildCitySelector() {
    final selectedCity = ref.watch(selectedCityProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Where to?',
          style: GoogleFonts.ibmPlexSans(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        SizedBox(height: 20),
        GestureDetector(
          onTap: () async {
            final city = await Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => CitySelector()),
            );
            if (city != null) {
              ref.read(selectedCityProvider.notifier).state = city;
            }
          },
          child: Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selectedCity != null ? kDeepPink : Colors.grey.shade300,
                width: 1.5,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.location_on,
                  color: selectedCity != null ? kDeepPink : Colors.grey,
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    selectedCity ?? 'Select destination',
                    style: GoogleFonts.lexendDeca(
                      fontSize: 16,
                      color: selectedCity != null ? Colors.black87 : Colors.grey,
                    ),
                  ),
                ),
                Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDaysSelector() {
    return Consumer(
      builder: (context, ref, child) {
        final days = ref.watch(daysProvider);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'How many days?',
              style: GoogleFonts.ibmPlexSans(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Decrease button
                InkWell(
                  focusColor: Colors.transparent,
                  hoverColor: Colors.transparent,
                  highlightColor: Colors.transparent,
                  splashColor: Colors.transparent,
                  onTap: () {
                    if (days > 1) {
                      ref.read(daysProvider.notifier).state = days - 1;
                    }
                  },
                  child: Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: kDeepPink, width: 2),
                    ),
                    child: Center(
                      child: Icon(
                        Icons.remove,
                        color: kDeepPink,
                        size: 25,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 40),

                // Days number
                Text(
                  days.toString(),
                  style: GoogleFonts.lexendDeca(
                    fontSize: 32,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                  ),
                ),
                SizedBox(width: 40),

                // Increase button
                InkWell(
                  focusColor: Colors.transparent,
                  hoverColor: Colors.transparent,
                  highlightColor: Colors.transparent,
                  splashColor: Colors.transparent,
                  onTap: () {
                    if (days < 3) {
                      ref.read(daysProvider.notifier).state = days + 1;
                    } else {
                      Popup.showInfo(text: "Min is 1 and Max is 3", context: context);
                    }
                  },
                  child: Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: kDeepPink, width: 2),
                    ),
                    child: Center(
                      child: Icon(
                        Icons.add,
                        color: kDeepPink,
                        size: 25,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildDatePicker() {
    return InkWell(
      onTap: () => showDatePicker(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey, width: 1)),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              DateFormat('dd/MM/yyyy').format(ref.watch(timeOfTravel)),
              style: GoogleFonts.lexendDeca(fontSize: 16),
            ),
            const Icon(Icons.calendar_today, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _buildCuisineSelector() {
    return Consumer(
      builder: (context, ref, child) {
        final selectedCuisines = ref.watch(cuisineTypeProvider);
        final isCollapsed = ref.watch(isCuisineCollapsedProvider);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                ref.read(isCuisineCollapsedProvider.notifier).state = !isCollapsed;
              },
              child: Row(
                children: [
                  Icon(Icons.restaurant_menu, color: kDeepPink, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Cuisine Preferences',
                    style: GoogleFonts.lexendDeca(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  SizedBox(width: 8),
                  Icon(
                    isCollapsed ? Icons.format_line_spacing_sharp : Icons.list,
                    size: 24,
                    color: kDeepPink,
                  ),
                ],
              ),
            ),
            if (!isCollapsed) ...[
              SizedBox(height: 20),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: cuisineOptions.map((cuisine) {
                  final isSelected = selectedCuisines.contains(cuisine);
                  return InkWell(
                    focusColor: Colors.transparent,
                    hoverColor: Colors.transparent,
                    highlightColor: Colors.transparent,
                    splashColor: Colors.transparent,
                    onTap: () {
                      final updatedCuisines = Set<String>.from(selectedCuisines);

                      if (cuisine == 'All') {
                        updatedCuisines.clear();
                        updatedCuisines.add('All');
                      } else {
                        if (isSelected) {
                          updatedCuisines.remove(cuisine);
                          if (updatedCuisines.isEmpty) {
                            updatedCuisines.add('All');
                          }
                        } else {
                          updatedCuisines.remove('All');
                          updatedCuisines.add(cuisine);
                        }
                      }

                      ref.read(cuisineTypeProvider.notifier).state = updatedCuisines;
                    },
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                      decoration: BoxDecoration(
                        color: isSelected ? kDeepPink : Colors.transparent,
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(
                          color: kDeepPink,
                          width: 1.5,
                        ),
                      ),
                      child: Text(
                        cuisine,
                        style: GoogleFonts.lexendDeca(
                          color: isSelected ? Colors.white : kDeepPink,
                          fontSize: 15,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildAdditionalPreferences() {
    return Consumer(
      builder: (context, ref, child) {
        final selectedPreferences = ref.watch(additionalPreferencesProvider);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.tune, color: kDeepPink, size: 20),
                SizedBox(width: 8),
                Text(
                  'Additional Preferences',
                  style: GoogleFonts.lexendDeca(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
            SizedBox(height: 20),
            ...additionalPreferences.map((preference) {
              final isSelected = selectedPreferences.contains(preference);
              return Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: InkWell(
                  focusColor: Colors.transparent,
                  hoverColor: Colors.transparent,
                  highlightColor: Colors.transparent,
                  splashColor: Colors.transparent,
                  onTap: () {
                    final updatedPreferences = Set<String>.from(selectedPreferences);
                    if (isSelected) {
                      updatedPreferences.remove(preference);
                    } else {
                      updatedPreferences.add(preference);
                    }
                    ref.read(additionalPreferencesProvider.notifier).state = updatedPreferences;
                  },
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    decoration: BoxDecoration(
                      color: isSelected ? kDeepPink.withOpacity(0.1) : Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(
                        color: isSelected ? kDeepPink : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isSelected ? kDeepPink : Colors.white,
                            border: Border.all(
                              color: isSelected ? kDeepPink : Colors.grey.shade400,
                              width: 2,
                            ),
                          ),
                          child: isSelected ? Icon(Icons.check, color: Colors.white, size: 16) : SizedBox(),
                        ),
                        SizedBox(width: 16),
                        Text(
                          preference,
                          style: GoogleFonts.lexendDeca(
                            color: Colors.black87,
                            fontSize: 16,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ],
        );
      },
    );
  }

  Widget _buildBudgetRangeSelector() {
    return Consumer(
      builder: (context, ref, child) {
        final selectedBudget = ref.watch(budgetRangeProvider);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Budget Range',
              style: GoogleFonts.ibmPlexSans(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            SizedBox(height: 20),
            Row(
              children: budgetOptions.map((budget) {
                final isSelected = selectedBudget == budget;
                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6),
                    child: InkWell(
                      focusColor: Colors.transparent,
                      hoverColor: Colors.transparent,
                      highlightColor: Colors.transparent,
                      splashColor: Colors.transparent,
                      onTap: () {
                        ref.read(budgetRangeProvider.notifier).state = budget;
                      },
                      child: Container(
                        height: 56,
                        decoration: BoxDecoration(
                          color: isSelected ? kDeepPink : Colors.transparent,
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(
                            color: kDeepPink,
                            width: 2,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            budget,
                            style: GoogleFonts.lexendDeca(
                              color: isSelected ? Colors.white : kDeepPink,
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        );
      },
    );
  }

  Widget _buildActivitiesSelector() {
    return Consumer(
      builder: (context, ref, child) {
        final selectedActivities = ref.watch(selectedActivitiesProvider);
        final isCollapsed = ref.watch(isActivitiesCollapsedProvider);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                ref.read(isActivitiesCollapsedProvider.notifier).state = !isCollapsed;
              },
              child: Row(
                children: [
                  Text(
                    'Include Activities',
                    style: GoogleFonts.ibmPlexSans(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  SizedBox(width: 8),
                  Icon(
                    isCollapsed ? Icons.format_line_spacing_sharp : Icons.list,
                    size: 24,
                    color: kDeepPink,
                  ),
                ],
              ),
            ),
            if (!isCollapsed) ...[
              SizedBox(height: 20),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: activityOptions.map((activity) {
                  final isSelected = selectedActivities.contains(activity);
                  return InkWell(
                    focusColor: Colors.transparent,
                    hoverColor: Colors.transparent,
                    highlightColor: Colors.transparent,
                    splashColor: Colors.transparent,
                    onTap: () {
                      final updatedActivities = Set<String>.from(selectedActivities);
                      if (isSelected) {
                        updatedActivities.remove(activity);
                      } else {
                        updatedActivities.add(activity);
                      }
                      ref.read(selectedActivitiesProvider.notifier).state = updatedActivities;
                    },
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                      decoration: BoxDecoration(
                        color: isSelected ? kDeepPink : Colors.transparent,
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(
                          color: kDeepPink,
                          width: 1.5,
                        ),
                      ),
                      child: Text(
                        activity,
                        style: GoogleFonts.lexendDeca(
                          color: isSelected ? Colors.white : kDeepPink,
                          fontSize: 15,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ],
        );
      },
    );
  }
}
