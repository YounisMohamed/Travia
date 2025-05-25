import 'package:bottom_picker/bottom_picker.dart';
import 'package:bottom_picker/resources/arrays.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:travia/Classes/UserSupabase.dart';
import 'package:travia/main.dart';

import '../Helpers/AppColors.dart';

final profileDisplayNameProvider = StateProvider.family<String, UserModel>((ref, user) => user.displayName ?? "");
final profileUsernameProvider = StateProvider.family<String, UserModel>((ref, user) => user.username ?? "");
final profileBioProvider = StateProvider.family<String, UserModel>((ref, user) => user.bio ?? "");
final profileDateOfBirthProvider = StateProvider.family<DateTime, UserModel>((ref, user) => user.age);
final profileGenderProvider = StateProvider.family<String, UserModel>((ref, user) => user.gender ?? "");
final profileRelationshipStatusProvider = StateProvider.family<String, UserModel>((ref, user) => user.relationshipStatus ?? "");
final profileIsPublicProvider = StateProvider.family<bool, UserModel>((ref, user) => user.public);
final showLikedPostsProvider = StateProvider.family<bool, UserModel>((ref, user) => user.showLikedPosts);

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

  String? getValidGenderValue(String value) {
    const validGenders = ["Male", "Female", "Other"];
    if (value.isEmpty) return null;

    // Try to find exact match first
    if (validGenders.contains(value)) return value;

    // Try case-insensitive match
    String? match = validGenders.firstWhere(
      (item) => item.toLowerCase() == value.toLowerCase(),
      orElse: () => "",
    );

    return match.isEmpty ? null : match;
  }

  String? getValidRelationshipValue(String value) {
    const validStatuses = ["taken", "single", "it's complicated"];
    if (value.isEmpty) return null;

    // Try to find exact match first
    if (validStatuses.contains(value)) return value;

    // Try case-insensitive match
    String? match = validStatuses.firstWhere(
      (item) => item.toLowerCase() == value.toLowerCase(),
      orElse: () => "",
    );

    return match.isEmpty ? null : match;
  }

  @override
  void initState() {
    super.initState();
    // Initialize controllers with user data
    displayNameController = TextEditingController(text: widget.user.displayName ?? "");
    usernameController = TextEditingController(text: widget.user.username ?? "");
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

  @override
  Widget build(BuildContext context) {
    // Access providers with user parameter
    final displayName = ref.watch(profileDisplayNameProvider(widget.user));
    final username = ref.watch(profileUsernameProvider(widget.user));
    final bio = ref.watch(profileBioProvider(widget.user));
    final dateOfBirth = ref.watch(profileDateOfBirthProvider(widget.user));
    final gender = ref.watch(profileGenderProvider(widget.user));
    final relationshipStatus = ref.watch(profileRelationshipStatusProvider(widget.user));
    final isPublic = ref.watch(profileIsPublicProvider(widget.user));
    final isShowLikedPosts = ref.watch(showLikedPostsProvider(widget.user));

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
        initialDateTime: dateOfBirth,
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
                        image: const DecorationImage(
                          image: NetworkImage("https://lh3.googleusercontent.com/a/ACg8ocKstmlfI0S9ZjDG-7UCvToQOhYVIz7YX9bUJpsSNdT7XoKVsgc=s96-c"),
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
                  ref.read(profileDisplayNameProvider(widget.user).notifier).state = value; // Fixed: added widget.user
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
                  ref.read(profileUsernameProvider(widget.user).notifier).state = value; // Fixed: added widget.user
                },
              ),
              const SizedBox(height: 16),

              // Bio - New field
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
                  ref.read(profileBioProvider(widget.user).notifier).state = value; // Fixed: added widget.user
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
                        DateFormat('dd/MM/yyyy').format(dateOfBirth),
                        style: const TextStyle(fontSize: 16),
                      ),
                      const Icon(Icons.calendar_today, color: Colors.black),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Gender
              const Text(
                'Gender',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: getValidGenderValue(gender),
                    isExpanded: true,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    icon: const Icon(Icons.keyboard_arrow_down),
                    items: <String>["Male", "Female", "Other"].map((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(value),
                      );
                    }).toList(),
                    onChanged: (String? newValue) {
                      if (newValue != null) {
                        ref.read(profileGenderProvider(widget.user).notifier).state = newValue;
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Relationship status
              const Text(
                'Relationship status',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: getValidRelationshipValue(relationshipStatus),
                    isExpanded: true,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    icon: const Icon(Icons.keyboard_arrow_down),
                    items: <String>["taken", "single", "it's complicated"].map((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(value),
                      );
                    }).toList(),
                    onChanged: (String? newValue) {
                      if (newValue != null) {
                        ref.read(profileRelationshipStatusProvider(widget.user).notifier).state = newValue;
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(height: 40),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Make account public',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Switch(
                    value: isPublic, // Fixed: use the watched value
                    onChanged: (value) {
                      ref.read(profileIsPublicProvider(widget.user).notifier).state = value; // Fixed: added widget.user
                    },
                    activeColor: kDeepPink,
                  ),
                ],
              ),
              const SizedBox(height: 24),
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

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    try {
                      await supabase.from("users").update({
                        'display_name': ref.read(profileDisplayNameProvider(widget.user)),
                        'username': ref.read(profileUsernameProvider(widget.user)),
                        'bio': ref.read(profileBioProvider(widget.user)),
                        'age': ref.read(profileDateOfBirthProvider(widget.user)).toIso8601String(),
                        'gender': ref.read(profileGenderProvider(widget.user)),
                        'relationship_status': ref.read(profileRelationshipStatusProvider(widget.user)),
                        'public': ref.read(profileIsPublicProvider(widget.user)),
                        'showLikedPosts': ref.read(showLikedPostsProvider(widget.user)),
                        'updated_at': DateTime.now().toIso8601String(),
                      }).eq('id', widget.user.id);

                      Navigator.pop(context);
                    } catch (e) {
                      // Handle error - show snackbar or dialog
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error updating profile: $e')),
                      );
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
