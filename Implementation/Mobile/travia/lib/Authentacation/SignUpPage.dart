import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:modular_ui/modular_ui.dart';
import 'package:travia/Helpers/Constants.dart';
import 'package:travia/Helpers/DefaultText.dart';
import 'package:travia/Helpers/Loading.dart';
import 'package:travia/Providers/LoadingProvider.dart';
import 'package:travia/Providers/VisiblePasswordProvider.dart';

import '../Helpers/DefaultFormField.dart';
import '../Helpers/Icons.dart';
import 'AuthMethods.dart';

class SignUpPage extends ConsumerStatefulWidget {
  const SignUpPage({super.key});

  @override
  ConsumerState<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends ConsumerState<SignUpPage> {
  var _formKey;

  @override
  void initState() {
    super.initState();
    _formKey = GlobalKey<FormState>();
  }

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  bool visiblePassword = false;

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

    // State when the user asks to sign in
    final isLoading = ref.watch(loadingProvider);
    final visiblePassword = ref.watch(visibleProvider);

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
                DefaultText(
                  text: "SIGN UP",
                  color: Colors.black,
                  isBold: true,
                  size: 16,
                ),
                SizedBox(height: height * 0.05),
                Form(
                  key: _formKey,
                  child: Padding(
                    padding: padding,
                    child: Column(
                      children: [
                        DefaultTextFormField(
                          type: TextInputType.emailAddress,
                          controller: _emailController,
                          label: "Email Address",
                          icon: emailIcon,
                          validatorFun: (val) {
                            if (val.toString().isEmpty) {
                              return "Email cannot be empty";
                            } else {
                              return null;
                            }
                          },
                        ),
                        SizedBox(height: height * 0.03),
                        DefaultTextFormField(
                          type: TextInputType.visiblePassword,
                          controller: _passwordController,
                          label: "Password",
                          isSecure: !visiblePassword,
                          icon: lockIcon,
                          validatorFun: (val) {
                            if (val.toString().isEmpty) {
                              return "Password cannot be empty";
                            } else {
                              return null;
                            }
                          },
                        ),
                        SizedBox(height: height * 0.03),
                        DefaultTextFormField(
                          type: TextInputType.visiblePassword,
                          controller: _confirmPasswordController,
                          label: "Confirm Password",
                          isSecure: !visiblePassword,
                          icon: lockIconShield,
                          validatorFun: (val) {
                            if (val.toString().isEmpty) {
                              return "Confirmed Password cannot be empty";
                            } else if (val.toString() != _passwordController.text) {
                              return "Passwords don't match";
                            } else {
                              return null;
                            }
                          },
                        ),
                        SizedBox(height: height * 0.009),
                        Row(
                          children: [
                            DefaultText(
                              text: "Show Password",
                              color: Colors.black,
                              size: 12,
                            ),
                            SizedBox(width: width * 0.01),
                            Checkbox(
                              value: visiblePassword,
                              onChanged: (bool? newValue) {
                                ref.read(visibleProvider.notifier).toggleVisible(newValue!);
                              },
                            ),
                          ],
                        ),
                        SizedBox(height: height * 0.05),
                        isLoading
                            ? LoadingWidget()
                            : MUIGradientBlockButton(
                                text: "SIGN UP",
                                onPressed: () async {
                                  if (_formKey.currentState!.validate()) {
                                    await signUpWithEmailAndPassword(
                                      context,
                                      ref,
                                      email: _emailController.text,
                                      password: _passwordController.text,
                                    );
                                  } else {
                                    print("Not Valid");
                                  }
                                  FocusManager.instance.primaryFocus?.unfocus();
                                },
                                bgGradient: LinearGradient(colors: [Colors.orangeAccent, Colors.purpleAccent]),
                                animationDuration: 5,
                              )
                      ],
                    ),
                  ),
                ),
                SizedBox(height: height * 0.05),
                TextButton(
                  onPressed: () {
                    context.go("/signin");
                  },
                  child: DefaultText(
                    text: "I already have an account",
                    size: 12,
                    color: Colors.grey,
                    underlined: true,
                  ),
                ),
                SizedBox(height: height * 0.04),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
