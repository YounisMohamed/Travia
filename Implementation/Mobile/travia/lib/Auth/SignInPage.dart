import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:modular_ui/modular_ui.dart';
import 'package:travia/Helpers/GoogleTexts.dart';
import 'package:travia/Helpers/Icons.dart';
import 'package:travia/Helpers/Loading.dart';
import 'package:travia/Providers/VisiblePasswordProvider.dart';

import '../Helpers/AppColors.dart';
import '../Helpers/DefaultFormField.dart';
import '../Helpers/GoogleSignInWidget.dart';
import '../Providers/LoadingProvider.dart';
import 'AuthMethods.dart';

class SignInPage extends ConsumerStatefulWidget {
  const SignInPage({super.key});

  @override
  ConsumerState<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends ConsumerState<SignInPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

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
    final visiblePassword = ref.watch(visibleProvider);

    return Container(
      color: backgroundColor,
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        body: Padding(
          padding: const EdgeInsets.symmetric(vertical: 50),
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Image.asset(
                  "assets/TraviaLogo.png",
                  height: 130,
                  width: 130,
                ),
                IBMPlexSansText(
                  text: "SIGN IN",
                  color: Colors.black,
                  isBold: true,
                  size: 16,
                ),
                SizedBox(height: height * 0.05),
                GoogleSignInButton(
                  contextOfParent: context,
                  ref: ref,
                ),
                SizedBox(height: height * 0.1),
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
                            }
                            return null;
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
                            }
                            if (val.toString().length < 6) {
                              return "Password is less than 6";
                            }
                            return null;
                          },
                        ),
                        SizedBox(height: height * 0.009),
                        Row(
                          children: [
                            IBMPlexSansText(
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
                                text: "SIGN IN",
                                onPressed: () async {
                                  if (_formKey.currentState!.validate()) {
                                    ref.read(loadingProvider.notifier).state = true;
                                    await signInWithEmailAndPassword(
                                      context,
                                      ref,
                                      email: _emailController.text,
                                      password: _passwordController.text,
                                    );
                                  }
                                },
                                bgGradient: LinearGradient(colors: [kDeepPinkLight, kDeepPink]),
                                animationDuration: 5,
                              ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: height * 0.05),
                TextButton(
                  onPressed: () {
                    context.push("/signup");
                  },
                  child: RedHatText(
                    text: "I don't have an account",
                    size: 12,
                    color: Colors.grey,
                    underlined: true,
                  ),
                ),
                TextButton(
                  onPressed: () {
                    context.push("/forgotpassword");
                  },
                  child: RedHatText(
                    text: "I forgot my password",
                    size: 12,
                    color: Colors.grey,
                    underlined: true,
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
