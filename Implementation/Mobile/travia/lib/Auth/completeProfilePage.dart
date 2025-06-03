import 'package:bottom_picker/bottom_picker.dart';
import 'package:bottom_picker/resources/arrays.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:modular_ui/modular_ui.dart';
import 'package:travia/Helpers/GoogleTexts.dart';

import '../Helpers/AppColors.dart';
import '../Helpers/Constants.dart';
import '../Helpers/DefaultFormField.dart';
import '../Helpers/DropDown.dart';
import '../Helpers/Loading.dart';
import '../Helpers/PopUp.dart';
import '../Providers/LoadingProvider.dart';
import '../database/DatabaseMethods.dart';
import '../main.dart';
import 'AuthMethods.dart';

final countrySearchQueryProvider = StateProvider<String>((ref) => '');
final filteredCountriesProvider = Provider<List<Map<String, String>>>((ref) {
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

class CompleteProfilePage extends ConsumerStatefulWidget {
  const CompleteProfilePage({super.key});

  @override
  ConsumerState<CompleteProfilePage> createState() => _CompleteProfilePageState();
}

class _CompleteProfilePageState extends ConsumerState<CompleteProfilePage> {
  var _formKey;
  DateTime? selectedDate;
  List<String> selectedCountries = [];

  @override
  void initState() {
    super.initState();
    _formKey = GlobalKey<FormState>();
    // Initialize with a default date (18 years ago)
    selectedDate = DateTime(2003, 8, 6);
  }

  final TextEditingController _displayNameController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();

  final relationshipOptions = ['Single', 'Married', 'Complicated'];
  String? selectedRelationship;
  String? selectedGender;

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
        setState(() {
          selectedDate = date;
        });
      },
      buttonSingleColor: kDeepPink,
      initialDateTime: selectedDate,
      maxDateTime: DateTime.now().subtract(Duration(days: 365 * 16)), // Must be at least 16 years old
      minDateTime: DateTime.now().subtract(Duration(days: 365 * 100)), // Max 100 years old
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
          return StatefulBuilder(
            builder: (context, setDialogState) {
              return Consumer(
                builder: (context, ref, _) {
                  final filteredCountries = ref.watch(filteredCountriesProvider);

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
                          if (selectedCountries.isNotEmpty)
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
                                    '${selectedCountries.length} countries selected',
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
                                          final isSelected = selectedCountries.contains(country['emoji']);

                                          return GestureDetector(
                                            onTap: () {
                                              setDialogState(() {
                                                if (isSelected) {
                                                  selectedCountries.remove(country['emoji']);
                                                } else {
                                                  selectedCountries.add(country['emoji']!);
                                                }
                                              });
                                              setState(() {});
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
                                                    country['code']!,
                                                    style: GoogleFonts.lexendDeca(
                                                      fontSize: 12,
                                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                                      color: isSelected ? kDeepPink : Colors.black87,
                                                    ),
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
                                      setDialogState(() {
                                        selectedCountries.clear();
                                      });
                                      setState(() {});
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
          );
        });
  }

  @override
  Widget build(BuildContext context) {
    double height = MediaQuery.sizeOf(context).height;
    double width = MediaQuery.sizeOf(context).width;

    final double paddingFactor = 0.05;
    final EdgeInsets padding = EdgeInsets.fromLTRB(
      width * paddingFactor,
      0,
      width * paddingFactor,
      0,
    );

    final isLoading = ref.watch(loadingProvider);

    return Container(
      color: backgroundColor,
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        body: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Image.asset(
                "assets/TraviaLogo.png",
                height: 130,
                width: 130,
              ),
              SizedBox(height: height * 0.02),
              // User name field
              RedHatText(
                text: "Complete Your Profile",
                color: Colors.black,
                isBold: true,
                size: 28,
                center: true,
              ),
              SizedBox(height: height * 0.04),
              Form(
                key: _formKey,
                child: Padding(
                  padding: padding,
                  child: Column(
                    children: [
                      // Username Field
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withOpacity(0.1),
                              spreadRadius: 1,
                              blurRadius: 3,
                            ),
                          ],
                        ),
                        child: DefaultTextFormField(
                          type: TextInputType.text,
                          controller: _usernameController,
                          label: "Username",
                          icon: const Icon(Icons.alternate_email, size: 20, color: Colors.grey),
                          validatorFun: (val) {
                            final username = val?.trim() ?? '';
                            if (username.length < 4) return "Username must be at least 3 characters";
                            if (username.length > 14) return "Username must be be less than 14 characters";
                            final validUsernameRegExp = RegExp(r'^[a-zA-Z0-9._]+$');
                            if (!validUsernameRegExp.hasMatch(username)) {
                              return "Only letters, numbers, . and _ allowed";
                            }
                            if (filter.hasProfanity(username)) return "Bad words detected";
                            return null;
                          },
                        ),
                      ),
                      SizedBox(height: height * 0.02),
                      // Display Name Field
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withValues(alpha: 0.1),
                              spreadRadius: 1,
                              blurRadius: 3,
                            ),
                          ],
                        ),
                        child: DefaultTextFormField(
                          type: TextInputType.text,
                          controller: _displayNameController,
                          label: "Display Name",
                          icon: const Icon(Icons.person, size: 20, color: Colors.grey),
                          validatorFun: (val) {
                            final name = val?.trim() ?? '';
                            if (name.isEmpty) return "Name cannot be empty";
                            final specialCharRegExp = RegExp(r'[^a-zA-Z0-9._ ]');
                            if (specialCharRegExp.hasMatch(name)) return "Only ., _, and spaces are allowed as special characters";
                            final letterRegExp = RegExp(r'[a-zA-Z]');
                            if (!letterRegExp.hasMatch(name)) return "Name must contain at least one letter";
                            if (name.length < 4) return "At least 4 letters";
                            if (name.length > 25) return "At most 25 letters";
                            if (filter.hasProfanity(name)) return "Bad words detected";
                            return null;
                          },
                        ),
                      ),
                      SizedBox(height: height * 0.02),

                      // Date of Birth Field
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(left: 4.0, bottom: 8.0),
                            child: Text(
                              'Date of Birth',
                              style: TextStyle(
                                fontWeight: FontWeight.w500,
                                fontSize: 14,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                          InkWell(
                            onTap: () => showDatePicker(context),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.grey.withValues(alpha: 0.1),
                                    spreadRadius: 1,
                                    blurRadius: 3,
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.calendar_today, size: 20, color: Colors.grey),
                                      SizedBox(width: 12),
                                      Text(
                                        selectedDate != null ? DateFormat('dd/MM/yyyy').format(selectedDate!) : 'Select your date of birth',
                                        style: TextStyle(
                                          fontSize: 16,
                                          color: selectedDate != null ? Colors.black87 : Colors.grey.shade600,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Icon(Icons.arrow_drop_down, color: Colors.grey),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),

                      SizedBox(height: height * 0.02),

                      AppCustomDropdown<String>(
                        label: "Gender",
                        hintText: "Select your gender",
                        value: selectedGender,
                        prefixIcon: Icon(Icons.people, size: 22, color: Colors.grey.shade600),
                        items: ['Male', 'Female'],
                        onChanged: (value) {
                          setState(() {
                            selectedGender = value;
                          });
                        },
                        validator: (value) => value == null ? "Please select your gender" : null,
                      ),

                      SizedBox(height: height * 0.02),

                      AppCustomDropdown<String>(
                        label: "Relationship Status",
                        hintText: "Select your relationship status",
                        value: selectedRelationship,
                        prefixIcon: Icon(Icons.favorite, size: 22, color: Colors.redAccent),
                        items: relationshipOptions,
                        onChanged: (value) {
                          setState(() {
                            selectedRelationship = value;
                          });
                        },
                        validator: (value) => value == null ? "Please select your relationship status" : null,
                      ),

                      SizedBox(height: height * 0.04),

                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline, size: 18, color: kDeepPink),
                            SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                "We request your relationship status and gender to help our AI recommend family-friendly places. Sorry for the inconvenience.",
                                style: TextStyle(
                                  fontSize: 13,
                                  color: kDeepPink,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      SizedBox(height: height * 0.04),

                      // Previously Visited Countries
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(left: 4.0, bottom: 8.0),
                            child: Text(
                              'Previously Visited Countries',
                              style: TextStyle(
                                fontWeight: FontWeight.w500,
                                fontSize: 14,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                          InkWell(
                            onTap: () => showCountrySelectionDialog(context),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.grey.withValues(alpha: 0.1),
                                    spreadRadius: 1,
                                    blurRadius: 3,
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.flight_takeoff, size: 20, color: Colors.grey),
                                      SizedBox(width: 12),
                                      selectedCountries.isEmpty
                                          ? Text(
                                              'Select countries you\'ve visited',
                                              style: TextStyle(
                                                fontSize: 16,
                                                color: Colors.grey.shade600,
                                              ),
                                            )
                                          : Container(
                                              constraints: BoxConstraints(maxWidth: width * 0.5),
                                              child: Text(
                                                selectedCountries.join(' '),
                                                style: TextStyle(
                                                  fontSize: 16,
                                                  color: Colors.black87,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                    ],
                                  ),
                                  Icon(Icons.arrow_drop_down, color: Colors.grey),
                                ],
                              ),
                            ),
                          ),
                          if (selectedCountries.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 4.0, left: 4.0),
                              child: Text(
                                '${selectedCountries.length} countries selected',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: kDeepPink,
                                ),
                              ),
                            ),
                        ],
                      ),
                      SizedBox(height: height * 0.04),
                      // Submit Button
                      if (isLoading)
                        LoadingWidget()
                      else
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.purpleAccent.withValues(alpha: 0.3),
                                spreadRadius: 1,
                                blurRadius: 8,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: MUIGradientBlockButton(
                            widthFactor: 0.45,
                            widthFactorPressed: 0.45,
                            text: "Complete Profile",
                            onPressed: () async {
                              try {
                                ref.read(loadingProvider.notifier).setLoadingToTrue();
                                if (!_formKey.currentState!.validate()) {
                                  print("Form is not valid");
                                  ref.read(loadingProvider.notifier).setLoadingToFalse();
                                  return;
                                }

                                // Validate date of birth
                                if (selectedDate == null) {
                                  Popup.showWarning(text: "Please select your date of birth", context: context);
                                  ref.read(loadingProvider.notifier).setLoadingToFalse();
                                  return;
                                }

                                // Calculate age and validate
                                final today = DateTime.now();
                                final age = today.year - selectedDate!.year - ((today.month < selectedDate!.month || (today.month == selectedDate!.month && today.day < selectedDate!.day)) ? 1 : 0);

                                if (age < 16) {
                                  Popup.showWarning(text: "You must be at least 16 years old", context: context);
                                  ref.read(loadingProvider.notifier).setLoadingToFalse();
                                  return;
                                }

                                if (age > 100) {
                                  Popup.showWarning(text: "Please enter a valid date of birth", context: context);
                                  ref.read(loadingProvider.notifier).setLoadingToFalse();
                                  return;
                                }

                                if (FirebaseAuth.instance.currentUser == null) {
                                  context.go("/signin");
                                  return;
                                }

                                String username = _usernameController.text.trim().toLowerCase();
                                bool userNameExists = await checkIfUsernameExists(username);
                                if (userNameExists) {
                                  Popup.showWarning(text: "Username already exists", context: context);
                                  ref.read(loadingProvider.notifier).setLoadingToFalse();
                                  return;
                                }

                                final user = FirebaseAuth.instance.currentUser!;
                                await user.updateDisplayName(_displayNameController.text);
                                await insertUser(
                                  userId: user.uid,
                                  email: user.email ?? "",
                                  username: username.toLowerCase(),
                                  displayName: _displayNameController.text,
                                  age: selectedDate!.toIso8601String(),
                                  gender: selectedGender ?? "Male",
                                  relationshipStatus: selectedRelationship ?? "Single",
                                  visitedCountries: selectedCountries,
                                );
                                await user.updateDisplayName(_displayNameController.text);
                                ref.read(loadingProvider.notifier).setLoadingToFalse();
                                context.go("/home");
                              } catch (e) {
                                Popup.showError(text: "Error while updating profile", context: context);
                                print(e);
                              } finally {
                                ref.read(loadingProvider.notifier).setLoadingToFalse();
                              }
                            },
                            bgGradient: LinearGradient(colors: [kDeepPinkLight, kDeepPink]),
                            animationDuration: 5,
                          ),
                        ),
                      SizedBox(height: height * 0.04),
                    ],
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
