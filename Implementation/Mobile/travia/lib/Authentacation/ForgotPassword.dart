import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:modular_ui/modular_ui.dart';
import 'package:travia/Authentacation/AuthMethods.dart';
import 'package:travia/Helpers/Constants.dart';
import 'package:travia/Helpers/DefaultText.dart';
import 'package:travia/Helpers/Icons.dart';
import 'package:travia/Helpers/Loading.dart';
import 'package:travia/Providers/LoadingProvider.dart';

import '../Helpers/defaultFormField.dart';

class ForgotPassword extends ConsumerStatefulWidget {
  const ForgotPassword({super.key});

  @override
  ConsumerState<ForgotPassword> createState() => SignInWithOtpState();
}

class SignInWithOtpState extends ConsumerState<ForgotPassword> {
  var _formKey;

  @override
  void initState() {
    super.initState();
    _formKey = GlobalKey<FormState>();
  }

  final TextEditingController _emailController = TextEditingController();

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
    final _isLoading = ref.watch(loadingProvider);

    return SafeArea(
      child: Container(
        color: backgroundColor,
        child: Scaffold(
          resizeToAvoidBottomInset: true,
          body: Padding(
            padding: EdgeInsets.symmetric(vertical: 25),
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Image.asset("assets/TraviaLogo.png"),
                  SizedBox(height: height * 0.01),
                  DefaultText(
                    text: "Reset your password",
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
                            label: "Email",
                            icon: emailIcon,
                            validatorFun: (val) {
                              if (val.toString().isEmpty) {
                                return "Email cannot be empty";
                              } else {
                                return null;
                              }
                            },
                          ),
                          SizedBox(height: height * 0.05),
                          _isLoading
                              ? LoadingWidget()
                              : MUIGradientBlockButton(
                                  widthFactor: 0.45,
                                  text: "Send",
                                  onPressed: () async {
                                    if (_formKey.currentState!.validate()) {
                                      await forgotPassword(context, ref, _emailController.text);
                                    } else {
                                      print("Not Valid");
                                    }
                                  },
                                  bgGradient: LinearGradient(colors: [Colors.orangeAccent, Colors.purpleAccent]),
                                  animationDuration: 5,
                                ),
                          SizedBox(height: height * 0.05),
                          DefaultText(
                            text: "A link will be sent to your email address, If the email is not registered you won't recieve a link",
                            italic: true,
                            center: true,
                            size: 16,
                          ),
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
                      text: "Go back to Sign In",
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
      ),
    );
  }
}
