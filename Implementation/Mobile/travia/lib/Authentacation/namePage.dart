import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:modular_ui/modular_ui.dart';
import 'package:travia/Helpers/Constants.dart';
import 'package:travia/Helpers/DefaultText.dart';

import '../Helpers/Loading.dart';
import '../Helpers/PopUp.dart';
import '../Helpers/defaultFormField.dart';
import '../Providers/LoadingProvider.dart';

class displayNamePage extends ConsumerStatefulWidget {
  const displayNamePage({super.key});

  @override
  ConsumerState<displayNamePage> createState() => _displayNamePageState();
}

class _displayNamePageState extends ConsumerState<displayNamePage> {
  var _formKey;

  @override
  void initState() {
    super.initState();
    _formKey = GlobalKey<FormState>();
  }

  final TextEditingController _phoneNumberController = TextEditingController();
  final TextEditingController _displayNameController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    double height = MediaQuery.sizeOf(context).height;
    double width = MediaQuery.sizeOf(context).width;

    // different padding based on platform, this is the padding between
    // left and right in the input fields, smaller in web
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
          padding: EdgeInsets.symmetric(vertical: 50),
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Image.asset("assets/TraviaLogo.png"),
                SizedBox(height: height * 0.01),
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 0, 10, 0),
                  child: DefaultText(
                    text: "Before you continue, Enter your display name",
                    color: Colors.black,
                    isBold: true,
                    size: 16,
                    center: true,
                  ),
                ),
                SizedBox(height: height * 0.05),
                Form(
                  key: _formKey,
                  child: Padding(
                    padding: padding,
                    child: Column(
                      children: [
                        defaultTextFormField(
                          type: TextInputType.text,
                          controller: _displayNameController,
                          label: "Display Name",
                          icon: const Icon(Icons.person, size: 20, color: Colors.grey),
                          validatorFun: (val) {
                            final name = val?.trim() ?? '';

                            // Check if the name is empty
                            if (name.isEmpty) return "Name cannot be empty";

                            // Check if the name contains any spaces
                            if (name.contains(' ')) return "No spaces allowed";

                            // Check for special characters (only '.' and '_')
                            final specialCharRegExp = RegExp(r'[^a-zA-Z0-9._]');
                            if (specialCharRegExp.hasMatch(name)) return "Only . and _ are allowed as special characters";

                            // Check if at least one letter is present
                            final letterRegExp = RegExp(r'[a-zA-Z]');
                            if (!letterRegExp.hasMatch(name)) return "Name must contain at least one letter";

                            // Check length restrictions
                            if (name.length < 4) return "At least 4 letters";
                            if (name.length > 15) return "At most 15 letters";

                            return null;
                          },
                        ),
                        SizedBox(height: height * 0.05),
                        isLoading
                            ? LoadingWidget()
                            : MUIGradientBlockButton(
                                widthFactor: 0.45,
                                text: "Done",
                                onPressed: () async {
                                  // Check if form is valid and user is logged in
                                  if (!_formKey.currentState!.validate()) {
                                    print("Form is not valid");
                                    return; // Early exit if form is invalid
                                  }
                                  if (FirebaseAuth.instance.currentUser == null) {
                                    context.go("/signin");
                                    return; // Early exit if the user is not logged in
                                  }
                                  try {
                                    // Update display name
                                    await FirebaseAuth.instance.currentUser!.updateDisplayName(_displayNameController.text);
                                    context.go("/homepage");
                                  } catch (e) {
                                    Popup.showPopUp(text: "Error while changing display name", context: context);
                                    print(e);
                                  }
                                },
                                bgGradient: LinearGradient(colors: [Colors.orangeAccent, Colors.purpleAccent]),
                                animationDuration: 5,
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
}
