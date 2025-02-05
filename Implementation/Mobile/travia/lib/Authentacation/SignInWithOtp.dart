import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:travia/Helpers/Constants.dart';
import 'package:travia/Helpers/Loading.dart';
import 'package:travia/Helpers/PoppinsText.dart';
import 'package:travia/Providers/LoadingProvider.dart';

import '../Helpers/defaultFormField.dart';

class SignInWithOtp extends ConsumerStatefulWidget {
  const SignInWithOtp({super.key});

  @override
  ConsumerState<SignInWithOtp> createState() => SignInWithOtpState();
}

class SignInWithOtpState extends ConsumerState<SignInWithOtp> {
  var _formKey;

  void initState() {
    super.initState();
    _formKey = GlobalKey<FormState>();
  }

  final TextEditingController _phoneController = TextEditingController();

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
                text: "SIGN IN With OTP",
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
                        type: TextInputType.phone,
                        controller: _phoneController,
                        label: "Phone Number",
                        icon: const Icon(Icons.phone, size: 20, color: Colors.grey),
                        validatorFun: (val) {
                          if (val.toString().isEmpty) {
                            return "Email cannot be empty";
                          } else {
                            return null;
                          }
                        },
                      ),
                      SizedBox(height: height * 0.05),
                      isLoading
                          ? LoadingWidget()
                          : ElevatedButton(
                              onPressed: () async {
                                if (_formKey.currentState!.validate()) {
                                  ref.read(loadingProvider.notifier).setLoadingToTrue();
                                  //await signUpWithOtp(context, ref, phoneNumber: _phoneController.text);
                                } else {
                                  print("Not Valid");
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.orangeAccent,
                                padding: const EdgeInsets.symmetric(vertical: 15.0, horizontal: 50.0),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30.0),
                                ),
                              ),
                              child: const Text(
                                'SIGN IN',
                                style: TextStyle(
                                  color: Colors.black,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: height * 0.05),
              TextButton(
                onPressed: () {
                  context.go("/signup");
                },
                child: PoppinsText(
                  text: "I don't have an account",
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
