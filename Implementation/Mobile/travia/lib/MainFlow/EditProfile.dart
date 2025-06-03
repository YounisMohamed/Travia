import 'package:bottom_picker/bottom_picker.dart';
import 'package:bottom_picker/resources/arrays.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:travia/Classes/UserSupabase.dart';
import 'package:travia/Helpers/HelperMethods.dart';
import 'package:travia/main.dart';

import '../Auth/AuthMethods.dart';
import '../Helpers/AppColors.dart';
import '../Helpers/Constants.dart';
import '../Helpers/DropDown.dart';
import '../Helpers/PopUp.dart';

final profileDisplayNameProvider = StateProvider.family<String, UserModel>((ref, user) => user.displayName ?? "");
final profileUsernameProvider = StateProvider.family<String, UserModel>((ref, user) => user.username ?? "");
final profileBioProvider = StateProvider.family<String, UserModel>((ref, user) => user.bio ?? "");
final profileDateOfBirthProvider = StateProvider.family<DateTime, UserModel>((ref, user) => user.age);
final showLikedPostsProvider = StateProvider.family<bool, UserModel>((ref, user) => user.showLikedPosts);
final profileGenderProvider = StateProvider.family<String?, UserModel>((ref, user) => user.gender);
final profileRelationshipStatusProvider = StateProvider.family<String?, UserModel>((ref, user) => user.relationshipStatus);
final profileVisitedCountriesProvider = StateProvider.family<List<String>, UserModel>(
  (ref, user) => user.visitedCountries,
);

final countrySearchQueryProvider = StateProvider<String>((ref) => '');
final filteredCountriesProvider = Provider.family<List<Map<String, String>>, UserModel>((ref, user) {
  final searchQuery = ref.watch(countrySearchQueryProvider).toLowerCase();

  if (searchQuery.isEmpty) {
    return countries;
  }

  return countries.where((country) {
    final countryName = country['name']!.toLowerCase();
    final countryCode = country['code']!.toLowerCase();
    return countryName.contains(searchQuery) || countryCode.contains(searchQuery);
  }).toList();
});

class EditProfilePage extends ConsumerStatefulWidget {
  final UserModel user;
  EditProfilePage({super.key, required this.user});

  @override
  ConsumerState<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends ConsumerState<EditProfilePage> {
  // Text controllers
  late TextEditingController displayNameController;
  late TextEditingController usernameController;
  late TextEditingController bioController;

  // Dropdown options
  final List<String> genderOptions = ['Male', 'Female'];
  final List<String> relationshipOptions = ['Single', 'Married', 'Complicated'];

  @override
  void initState() {
    super.initState();
    // Initialize controllers with user data
    displayNameController = TextEditingController(text: widget.user.displayName);
    usernameController = TextEditingController(text: widget.user.username);
    bioController = TextEditingController(text: widget.user.bio ?? "");
  }

  @override
  void dispose() {
    disposeControllers();
    super.dispose();
  }

  void disposeControllers() {
    displayNameController.dispose();
    usernameController.dispose();
    bioController.dispose();
  }

  // Date picker function
  void showDatePicker(BuildContext context) {
    BottomPicker.date(
      pickerTitle: Text(
        'Select Date of Birth',
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
        ref.read(profileDateOfBirthProvider(widget.user).notifier).state = date;
      },
      buttonSingleColor: kDeepPink,
      initialDateTime: ref.watch(profileDateOfBirthProvider(widget.user)),
      maxDateTime: DateTime.now(),
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

  void showCountrySelectionDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Consumer(
          builder: (context, ref, _) {
            final visitedCountries = ref.watch(profileVisitedCountriesProvider(widget.user));
            final filteredCountries = ref.watch(filteredCountriesProvider(widget.user));

            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 40),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: kDeepPink.withOpacity(0.2),
                      blurRadius: 20,
                      spreadRadius: 2,
                      offset: Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header
                    Container(
                      padding: EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [kDeepPinkLight, kDeepPink],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.flight_takeoff_rounded,
                            color: Colors.white,
                            size: 28,
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Travel History',
                                  style: GoogleFonts.lexendDeca(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                Text(
                                  'Select countries you\'ve visited',
                                  style: GoogleFonts.lexendDeca(
                                    fontSize: 13,
                                    color: Colors.white.withOpacity(0.9),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              shape: BoxShape.circle,
                            ),
                            child: IconButton(
                              icon: Icon(Icons.close, color: Colors.white),
                              onPressed: () {
                                ref.read(countrySearchQueryProvider.notifier).state = '';
                                Navigator.pop(context);
                              },
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Search Bar
                    Container(
                      margin: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: kDeepPink.withOpacity(0.1),
                          width: 1,
                        ),
                      ),
                      child: TextField(
                        onChanged: (value) {
                          ref.read(countrySearchQueryProvider.notifier).state = value;
                        },
                        decoration: InputDecoration(
                          hintText: 'Search countries...',
                          hintStyle: GoogleFonts.lexendDeca(
                            color: Colors.grey.shade500,
                            fontSize: 14,
                          ),
                          prefixIcon: Icon(
                            Icons.search_rounded,
                            color: kDeepPink,
                          ),
                          suffixIcon: ref.watch(countrySearchQueryProvider).isNotEmpty
                              ? IconButton(
                                  icon: Icon(Icons.clear, color: Colors.grey),
                                  onPressed: () {
                                    ref.read(countrySearchQueryProvider.notifier).state = '';
                                  },
                                )
                              : null,
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        ),
                        style: GoogleFonts.lexendDeca(fontSize: 14),
                      ),
                    ),

                    // Selected Count Badge
                    if (visitedCountries.isNotEmpty)
                      Container(
                        margin: EdgeInsets.symmetric(horizontal: 16),
                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [kDeepPink.withOpacity(0.1), kDeepPinkLight.withOpacity(0.1)],
                          ),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.check_circle_rounded,
                              size: 16,
                              color: kDeepPink,
                            ),
                            SizedBox(width: 8),
                            Text(
                              '${visitedCountries.length} countries selected',
                              style: GoogleFonts.lexendDeca(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: kDeepPink,
                              ),
                            ),
                          ],
                        ),
                      ),
                    SizedBox(
                      height: 16,
                    ),
                    // Countries Grid
                    Expanded(
                      child: Container(
                        constraints: BoxConstraints(
                          maxHeight: MediaQuery.of(context).size.height * 0.5,
                        ),
                        child: filteredCountries.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.search_off_rounded,
                                      size: 64,
                                      color: Colors.grey.shade300,
                                    ),
                                    SizedBox(height: 16),
                                    Text(
                                      'No countries found',
                                      style: GoogleFonts.lexendDeca(
                                        fontSize: 16,
                                        color: Colors.grey.shade500,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : Padding(
                                padding: EdgeInsets.symmetric(horizontal: 16),
                                child: GridView.builder(
                                  shrinkWrap: true,
                                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 3,
                                    crossAxisSpacing: 12,
                                    mainAxisSpacing: 12,
                                    childAspectRatio: 0.85,
                                  ),
                                  itemCount: filteredCountries.length,
                                  itemBuilder: (context, index) {
                                    final country = filteredCountries[index];
                                    final isSelected = visitedCountries.contains(country['emoji']);

                                    return GestureDetector(
                                      onTap: () {
                                        final currentList = List<String>.from(visitedCountries);
                                        if (isSelected) {
                                          currentList.remove(country['emoji']);
                                        } else {
                                          currentList.add(country['emoji']!);
                                        }
                                        ref.read(profileVisitedCountriesProvider(widget.user).notifier).state = currentList;
                                      },
                                      child: AnimatedContainer(
                                        duration: Duration(milliseconds: 200),
                                        decoration: BoxDecoration(
                                          color: isSelected ? kDeepPink.withOpacity(0.1) : Colors.white,
                                          borderRadius: BorderRadius.circular(16),
                                          border: Border.all(
                                            color: isSelected ? kDeepPink : Colors.grey.shade200,
                                            width: isSelected ? 2 : 1,
                                          ),
                                          boxShadow: isSelected
                                              ? [
                                                  BoxShadow(
                                                    color: kDeepPink.withOpacity(0.2),
                                                    blurRadius: 8,
                                                    offset: Offset(0, 4),
                                                  ),
                                                ]
                                              : [
                                                  BoxShadow(
                                                    color: Colors.black.withOpacity(0.05),
                                                    blurRadius: 4,
                                                    offset: Offset(0, 2),
                                                  ),
                                                ],
                                        ),
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Container(
                                              width: 56,
                                              height: 42,
                                              decoration: BoxDecoration(
                                                borderRadius: BorderRadius.circular(8),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: Colors.black.withOpacity(0.1),
                                                    blurRadius: 4,
                                                    offset: Offset(0, 2),
                                                  ),
                                                ],
                                              ),
                                              child: ClipRRect(
                                                borderRadius: BorderRadius.circular(8),
                                                child: CachedNetworkImage(
                                                  imageUrl: 'https://flagsapi.com/${country['code']}/flat/64.png',
                                                  fit: BoxFit.cover,
                                                  placeholder: (context, url) => Container(
                                                    color: Colors.grey.shade200,
                                                    child: Center(
                                                      child: Text(
                                                        country['emoji']!,
                                                        style: TextStyle(fontSize: 24),
                                                      ),
                                                    ),
                                                  ),
                                                  errorWidget: (context, url, error) => Container(
                                                    color: Colors.grey.shade200,
                                                    child: Center(
                                                      child: Text(
                                                        country['emoji']!,
                                                        style: TextStyle(fontSize: 24),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                            SizedBox(height: 8),
                                            Text(
                                              country['name']!.length > 10 ? country['code']! : country['name']!,
                                              style: GoogleFonts.lexendDeca(
                                                fontSize: 11,
                                                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                                color: isSelected ? kDeepPink : Colors.black87,
                                              ),
                                              textAlign: TextAlign.center,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            if (isSelected)
                                              Container(
                                                margin: EdgeInsets.only(top: 4),
                                                padding: EdgeInsets.all(2),
                                                decoration: BoxDecoration(
                                                  color: kDeepPink,
                                                  shape: BoxShape.circle,
                                                ),
                                                child: Icon(
                                                  Icons.check,
                                                  size: 10,
                                                  color: Colors.white,
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                      ),
                    ),

                    // Action Buttons
                    Container(
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextButton(
                              onPressed: () {
                                ref.read(profileVisitedCountriesProvider(widget.user).notifier).state = [];
                              },
                              child: Text(
                                'Clear All',
                                style: GoogleFonts.lexendDeca(
                                  color: Colors.grey.shade600,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                gradient: LinearGradient(
                                  colors: [kDeepPinkLight, kDeepPink],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: kDeepPink.withOpacity(0.3),
                                    blurRadius: 8,
                                    offset: Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(16),
                                  onTap: () {
                                    ref.read(countrySearchQueryProvider.notifier).state = '';
                                    Navigator.pop(context);
                                  },
                                  child: Container(
                                    padding: EdgeInsets.symmetric(vertical: 14),
                                    child: Center(
                                      child: Text(
                                        'Done',
                                        style: GoogleFonts.lexendDeca(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    ).then((_) {
      // Clear search when dialog is closed
      ref.read(countrySearchQueryProvider.notifier).state = '';
    });
  }

  bool _isBadgeSectionExpanded = false;

  @override
  Widget build(BuildContext context) {
    final isShowLikedPosts = ref.watch(showLikedPostsProvider(widget.user));
    final selectedGender = ref.watch(profileGenderProvider(widget.user));
    final selectedRelationship = ref.watch(profileRelationshipStatusProvider(widget.user));
    final visitedCountries = ref.watch(profileVisitedCountriesProvider(widget.user));
    // Consistent text field decoration
    InputDecoration getTextFieldDecoration(String label) {
      return InputDecoration(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        filled: true,
        fillColor: Colors.grey[200],
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Colors.black),
        ),
        labelStyle: const TextStyle(color: Colors.black),
        focusColor: Colors.black,
      );
    }

    return Scaffold(
      appBar: AppBar(
        forceMaterialTransparency: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Edit Profile',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Profile picture
              Center(
                child: Stack(
                  children: [
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
                        image: DecorationImage(
                          image: CachedNetworkImageProvider(widget.user.photoUrl),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        decoration: BoxDecoration(
                          color: kDeepPink,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Display Name
              const Text(
                'Display Name',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: displayNameController,
                cursorColor: Colors.black,
                decoration: getTextFieldDecoration('Display Name'),
                onChanged: (value) {
                  ref.read(profileDisplayNameProvider(widget.user).notifier).state = value;
                },
              ),
              const SizedBox(height: 16),

              // Username
              const Text(
                'User name',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: usernameController,
                cursorColor: Colors.black,
                decoration: getTextFieldDecoration('User name'),
                onChanged: (value) {
                  ref.read(profileUsernameProvider(widget.user).notifier).state = value;
                },
              ),
              const SizedBox(height: 16),

              // Bio
              const Text(
                'Bio',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: bioController,
                cursorColor: Colors.black,
                maxLines: 3,
                decoration: getTextFieldDecoration('Bio'),
                onChanged: (value) {
                  ref.read(profileBioProvider(widget.user).notifier).state = value;
                },
              ),
              const SizedBox(height: 16),

              // Date of Birth
              const Text(
                'Date of Birth',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              InkWell(
                onTap: () => showDatePicker(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        DateFormat('dd/MM/yyyy').format(ref.watch(profileDateOfBirthProvider(widget.user))),
                        style: const TextStyle(fontSize: 16),
                      ),
                      const Icon(Icons.calendar_today, color: Colors.black),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Gender Dropdown
              const Text(
                'Gender',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              AppCustomDropdown<String>(
                hintText: "Select your gender",
                value: selectedGender,
                prefixIcon: Icon(Icons.people, size: 22, color: Colors.grey.shade600),
                items: genderOptions,
                onChanged: (value) {
                  ref.read(profileGenderProvider(widget.user).notifier).state = value;
                },
                validator: (value) => value == null ? "Please select your gender" : null,
              ),
              const SizedBox(height: 16),

              // Relationship Status Dropdown
              const Text(
                'Relationship Status',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              AppCustomDropdown<String>(
                hintText: "Select your relationship status",
                value: selectedRelationship,
                prefixIcon: Icon(Icons.favorite, size: 22, color: Colors.redAccent),
                items: relationshipOptions,
                onChanged: (value) {
                  ref.read(profileRelationshipStatusProvider(widget.user).notifier).state = value;
                },
                validator: (value) => value == null ? "Please select your relationship status" : null,
              ),
              const SizedBox(height: 28),

              // Previously Visited Countries
              const Text(
                'Previously Visited Countries',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              InkWell(
                onTap: () => showCountrySelectionDialog(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: visitedCountries.isEmpty
                            ? Text(
                                'Select countries you\'ve visited',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey.shade600,
                                ),
                              )
                            : Text(
                                visitedCountries.join(' '),
                                style: const TextStyle(
                                  fontSize: 16,
                                  color: Colors.black87,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                      ),
                      const Icon(Icons.flight_takeoff, color: Colors.black),
                    ],
                  ),
                ),
              ),
              if (visitedCountries.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4.0),
                  child: Text(
                    '${visitedCountries.length} countries selected',
                    style: TextStyle(
                      fontSize: 12,
                      color: kDeepPink,
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Show liked posts',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Switch(
                    value: isShowLikedPosts,
                    onChanged: (value) {
                      ref.read(showLikedPostsProvider(widget.user).notifier).state = value;
                    },
                    activeColor: kDeepPink,
                  ),
                ],
              ),
              const SizedBox(height: 24),
              StatefulBuilder(
                builder: (context, setState) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '🎖 Badges',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: () => setState(() => _isBadgeSectionExpanded = !_isBadgeSectionExpanded),
                        child: Row(
                          children: [
                            Icon(
                              _isBadgeSectionExpanded ? Icons.expand_less : Icons.expand_more,
                              color: kDeepPink,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _isBadgeSectionExpanded ? 'Hide badge tutorial' : 'How to earn badges',
                              style: TextStyle(
                                color: kDeepPink,
                                fontWeight: FontWeight.w500,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                      AnimatedCrossFade(
                        duration: const Duration(milliseconds: 200),
                        crossFadeState: _isBadgeSectionExpanded ? CrossFadeState.showFirst : CrossFadeState.showSecond,
                        firstChild: Column(
                          children: [
                            const SizedBox(height: 12),
                            ...badgeStyles.entries.map((entry) {
                              final name = entry.key;
                              final style = entry.value;
                              final description = badgeDescriptions[name] ?? 'Earn this badge by engaging with the app.';

                              return Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(colors: style.gradient),
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: style.gradient.first.withOpacity(0.25),
                                      blurRadius: 6,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  children: [
                                    Icon(style.icon, color: Colors.white, size: 20),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            name,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            description,
                                            style: const TextStyle(
                                              color: Colors.white70,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                            const SizedBox(height: 12),
                          ],
                        ),
                        secondChild: const SizedBox.shrink(),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    try {
                      final username = ref.read(profileUsernameProvider(widget.user)).toLowerCase().trim();
                      bool userNameExists = await checkIfUsernameExists(username);
                      if (userNameExists && username != widget.user.username) {
                        Popup.showWarning(text: "Username already exists", context: context);
                        return;
                      }

                      if (username.length < 4) {
                        Popup.showWarning(text: "Username at least 3 characters", context: context);
                        return;
                      }
                      if (username.length > 14) {
                        Popup.showWarning(text: "Username at most 14 characters", context: context);
                        return;
                      }

                      if (filter.hasProfanity(username)) {
                        Popup.showWarning(text: "Bad words detected", context: context);
                        return;
                      }

                      final validUsernameRegExp = RegExp(r'^[a-zA-Z0-9._]+$');
                      if (!validUsernameRegExp.hasMatch(username) && username != "yoño") {
                        Popup.showWarning(
                          text: "Only letters, numbers, . and _ allowed in username",
                          context: context,
                        );
                        return;
                      }

                      final displayName = ref.read(profileDisplayNameProvider(widget.user));
                      final displayNameTrimmed = displayName.trim();

                      if (displayNameTrimmed.isEmpty) {
                        Popup.showWarning(text: "Display name cannot be empty", context: context);
                        return;
                      }
                      if (displayNameTrimmed.length < 3) {
                        Popup.showWarning(text: "Display name must be at least 3 characters long", context: context);
                        return;
                      }
                      if (displayNameTrimmed.length > 25) {
                        Popup.showWarning(text: "Display name cannot exceed 25 characters", context: context);
                        return;
                      }
                      if (filter.hasProfanity(displayNameTrimmed)) {
                        Popup.showWarning(text: "Bad words detected", context: context);
                        return;
                      }
                      final validDisplayNameRegex = RegExp(r'^[a-zA-Z0-9._ ]+$');
                      if (!validDisplayNameRegex.hasMatch(displayNameTrimmed)) {
                        Popup.showWarning(
                          text: "Only letters, numbers, '.', '_', and spaces are allowed in display name",
                          context: context,
                        );
                        return;
                      }

                      final age = ref.read(profileDateOfBirthProvider(widget.user));
                      final today = DateTime.now();
                      final ageInYears = today.year - age.year - ((today.month < age.month || (today.month == age.month && today.day < age.day)) ? 1 : 0);
                      bool ageValid = ageInYears >= 16 && ageInYears <= 100;
                      if (!ageValid) {
                        Popup.showWarning(text: "Birthdate not valid", context: context);
                        return;
                      }

                      final bio = ref.read(profileBioProvider(widget.user));
                      if (bio.length > 150) {
                        Popup.showWarning(text: "Bio too long, at most 150 characters", context: context);
                        return;
                      }
                      if (filter.hasProfanity(bio) || hasArabicProfanity(bio)) {
                        Popup.showWarning(text: "Bad words detected", context: context);
                        return;
                      }
                      final visited_countries = ref.read(profileVisitedCountriesProvider(widget.user));
                      if (visited_countries.length > 50) {
                        Popup.showWarning(text: "You have been to way too many countries man.", context: context);
                        return;
                      }
                      await supabase.from("users").update({
                        'display_name': displayNameTrimmed,
                        'username': ref.read(profileUsernameProvider(widget.user)).toLowerCase(),
                        'bio': bio,
                        'age': age.toIso8601String(),
                        'gender': ref.read(profileGenderProvider(widget.user)),
                        'relationship_status': ref.read(profileRelationshipStatusProvider(widget.user)),
                        'visited_countries': visited_countries,
                        'showLikedPosts': ref.read(showLikedPostsProvider(widget.user)),
                        'updated_at': DateTime.now().toIso8601String(),
                      }).eq('id', widget.user.id);

                      FirebaseAuth.instance.currentUser!.updateDisplayName(displayNameTrimmed);

                      Navigator.pop(context);
                    } catch (e) {
                      Popup.showError(text: "Error happened while updating", context: context);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kDeepPink,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'Save changes',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
