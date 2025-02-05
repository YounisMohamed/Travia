import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:modular_ui/modular_ui.dart';
import 'package:travia/Helpers/Constants.dart';
import 'package:travia/Helpers/Loading.dart';
import 'package:travia/Helpers/PoppinsText.dart';
import 'package:travia/Providers/LoadingProvider.dart';

import '../Helpers/Methods.dart';
import '../Helpers/defaultFormField.dart';

class SignUpPage extends ConsumerStatefulWidget {
  const SignUpPage({super.key});

  @override
  ConsumerState<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends ConsumerState<SignUpPage> {
  var _formKey;

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

    return Container(
      color: backgroundColor,
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        appBar: AppBar(
          forceMaterialTransparency: true,
        ),
        body: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Image.asset("assets/TraviaLogo.png"),
              SizedBox(height: height * 0.01),
              PoppinsText(
                text: "SIGN UP",
                color: Colors.black,
                isBold: true,
                size: 16,
              ),
              SizedBox(height: height * 0.1),
              Form(
                key: _formKey,
                child: Padding(
                  padding: padding,
                  child: Column(
                    children: [
                      defaultTextFormField(
                        type: TextInputType.emailAddress,
                        controller: _emailController,
                        label: "Email Address",
                        icon: const Icon(Icons.email_outlined, size: 20, color: Colors.grey),
                        validatorFun: (val) {
                          if (val.toString().isEmpty) {
                            return "Email cannot be empty";
                          } else {
                            return null;
                          }
                        },
                      ),
                      SizedBox(height: height * 0.03),
                      defaultTextFormField(
                        type: TextInputType.visiblePassword,
                        controller: _passwordController,
                        label: "Password",
                        isSecure: !visiblePassword,
                        icon: const Icon(Icons.lock, size: 20, color: Colors.grey),
                        validatorFun: (val) {
                          if (val.toString().isEmpty) {
                            return "Password cannot be empty";
                          } else {
                            return null;
                          }
                        },
                      ),
                      SizedBox(height: height * 0.03),
                      defaultTextFormField(
                        type: TextInputType.visiblePassword,
                        controller: _confirmPasswordController,
                        label: "Confirm Password",
                        isSecure: !visiblePassword,
                        icon: const Icon(Icons.lock, size: 20, color: Colors.grey),
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
                          PoppinsText(
                            text: "Show Password",
                            color: Colors.black,
                            size: 12,
                          ),
                          SizedBox(width: width * 0.01),
                          Checkbox(
                            value: visiblePassword,
                            onChanged: (bool? newValue) {
                              setState(() {
                                visiblePassword = newValue!;
                              });
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
                child: PoppinsText(
                  text: "I already have an account",
                  size: 12,
                  color: Colors.grey,
                  underlined: true,
                ),
              ),
              SizedBox(height: height * 0.05),
              TextButton(
                onPressed: () {
                  context.go("/signinotp");
                },
                child: PoppinsText(
                  text: "Sign up with OTP",
                  size: 12,
                  color: Colors.grey,
                  underlined: true,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
