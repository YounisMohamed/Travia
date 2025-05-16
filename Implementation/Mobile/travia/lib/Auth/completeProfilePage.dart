import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:modular_ui/modular_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:travia/Helpers/GoogleTexts.dart';

import '../Helpers/AppColors.dart';
import '../Helpers/DefaultFormField.dart';
import '../Helpers/Loading.dart';
import '../Helpers/PopUp.dart';
import '../Providers/LoadingProvider.dart';
import '../database/DatabaseMethods.dart';
import '../main.dart';

class CompleteProfilePage extends ConsumerStatefulWidget {
  const CompleteProfilePage({super.key});

  @override
  ConsumerState<CompleteProfilePage> createState() => _CompleteProfilePageState();
}

class _CompleteProfilePageState extends ConsumerState<CompleteProfilePage> {
  var _formKey;

  @override
  void initState() {
    super.initState();
    _formKey = GlobalKey<FormState>();
  }

  final TextEditingController _displayNameController = TextEditingController();
  final TextEditingController _ageController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();

  final relationshipOptions = ['Single', 'Married'];
  String? selectedRelationship;
  String? selectedGender;

  @override
  Widget build(BuildContext context) {
    double height = MediaQuery.sizeOf(context).height;
    double width = MediaQuery.sizeOf(context).width;

    final double paddingFactor = kIsWeb ? 0.3 : 0.05;
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
        body: Padding(
          padding: EdgeInsets.symmetric(vertical: 30),
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Image.asset("assets/TraviaLogo.png"),
                SizedBox(height: height * 0.02),
                // User name field
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withValues(alpha: 0.3),
                        spreadRadius: 2,
                        blurRadius: 5,
                      ),
                    ],
                  ),
                  child: RedHatText(
                    text: "Complete Your Profile",
                    color: Colors.black,
                    isBold: true,
                    size: 20,
                    center: true,
                  ),
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
                              if (username.length > 15) return "Username must be be less than 15 characters";
                              final validUsernameRegExp = RegExp(r'^[a-zA-Z0-9._]+');
                              if (!validUsernameRegExp.hasMatch(username)) {
                                return "Only letters, numbers, . and _ allowed";
                              }
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
                              if (name.contains(' ')) return "No spaces allowed";
                              final specialCharRegExp = RegExp(r'[^a-zA-Z0-9._]');
                              if (specialCharRegExp.hasMatch(name)) return "Only . and _ are allowed as special characters";
                              final letterRegExp = RegExp(r'[a-zA-Z]');
                              if (!letterRegExp.hasMatch(name)) return "Name must contain at least one letter";
                              if (name.length < 4) return "At least 4 letters";
                              if (name.length > 15) return "At most 15 letters";
                              return null;
                            },
                          ),
                        ),
                        SizedBox(height: height * 0.02),

                        // Age Field
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
                            type: TextInputType.number,
                            controller: _ageController,
                            label: "Age",
                            icon: const Icon(Icons.cake, size: 20, color: Colors.grey),
                            validatorFun: (val) {
                              if (val == null || val.isEmpty) return "Age is required";
                              final age = int.tryParse(val);
                              if (age == null) return "Please enter a valid age";
                              if (age < 10) return "You are too young to enter";
                              if (age > 120) return "You are too old to enter";
                              return null;
                            },
                          ),
                        ),
                        SizedBox(height: height * 0.02),

                        Container(
                          width: width * 0.7, // Controls width for a balanced UI
                          padding: EdgeInsets.symmetric(horizontal: 10),
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
                          child: DropdownButtonFormField<String>(
                            decoration: InputDecoration(
                              labelText: "Gender",
                              prefixIcon: Icon(Icons.people, size: 22, color: Colors.grey.shade600),
                              border: InputBorder.none, // Removes default border
                              contentPadding: EdgeInsets.symmetric(vertical: 14, horizontal: 10),
                            ),
                            value: selectedGender,
                            items: ['Male ♂️', 'Female ♀️']
                                .map((gender) => DropdownMenuItem(
                                      value: gender,
                                      child: Text(gender, style: TextStyle(fontSize: 16)),
                                    ))
                                .toList(),
                            onChanged: (value) {
                              selectedGender = value;
                            },
                            validator: (value) => value == null ? "Please select your gender" : null,
                          ),
                        ),
                        SizedBox(height: height * 0.02),
                        Container(
                          width: width * 0.7, // Matches gender dropdown width
                          padding: EdgeInsets.symmetric(horizontal: 10),
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
                          child: DropdownButtonFormField<String>(
                            decoration: InputDecoration(
                              labelText: "Relationship Status",
                              prefixIcon: Icon(Icons.favorite, size: 22, color: Colors.redAccent),
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(vertical: 14, horizontal: 10),
                            ),
                            value: selectedRelationship,
                            items: relationshipOptions
                                .map((status) => DropdownMenuItem(
                                      value: status,
                                      child: Text(status, style: TextStyle(fontSize: 16)),
                                    ))
                                .toList(),
                            onChanged: (value) {
                              selectedRelationship = value;
                            },
                            validator: (value) => value == null ? "Please select your relationship status" : null,
                          ),
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
                                  if (FirebaseAuth.instance.currentUser == null) {
                                    context.go("/signin");
                                    return;
                                  }
                                  String username = _usernameController.text.trim().toLowerCase();
                                  bool userNameExists = await checkIfUsernameExists(username);
                                  if (userNameExists) {
                                    Popup.showPopUp(text: "Username already exists", context: context);
                                    ref.read(loadingProvider.notifier).setLoadingToFalse();
                                    return;
                                  }
                                  final user = FirebaseAuth.instance.currentUser!;
                                  await user.updateDisplayName(_displayNameController.text);
                                  await insertUser(
                                    userId: user.uid,
                                    email: user.email ?? "",
                                    username: username,
                                    displayName: _displayNameController.text,
                                    age: toInt(_ageController.text) ?? 25,
                                    gender: selectedGender?.split(" ").first ?? "Male",
                                    relationshipStatus: selectedRelationship ?? "Single",
                                  );
                                  await user.updateDisplayName(_displayNameController.text);
                                  ref.read(loadingProvider.notifier).setLoadingToFalse();
                                  context.go("/home");
                                } catch (e) {
                                  Popup.showPopUp(text: "Error while updating profile", context: context);
                                  print(e);
                                } finally {
                                  ref.read(loadingProvider.notifier).setLoadingToFalse();
                                }
                              },
                              bgGradient: LinearGradient(
                                colors: [Colors.orangeAccent, Colors.purpleAccent],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              animationDuration: 5,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<bool> checkIfUsernameExists(String username) async {
    try {
      final response = await supabase.from('users').select('username').eq('username', username).limit(1);
      return response.isNotEmpty;
    } catch (e) {
      print('Error checking username existence: $e');
      return true; // rg3 true 3al e7tyat
    }
  }
}
