import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:travia/Helpers/Constants.dart';
import 'package:travia/Helpers/PoppinsText.dart';

import '../Helpers/defaultFormField.dart';

class displayNamePage extends StatefulWidget {
  const displayNamePage({super.key});

  @override
  State<displayNamePage> createState() => _displayNamePageState();
}

class _displayNamePageState extends State<displayNamePage> {
  var _formKey;

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
                text: "Before you continue, Enter your display name",
                color: Colors.black,
                isBold: true,
                size: 16,
                center: true,
              ),
              SizedBox(height: height * 0.1),
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
                          String name = val.toString();
                          if (name.isEmpty) {
                            return "Name cannot be empty";
                          } else if (name.length < 3) {
                            return "At least 3 letters";
                          } else {
                            return null;
                          }
                        },
                      ),
                      SizedBox(height: height * 0.05),
                      ElevatedButton(
                        onPressed: () async {
                          if (_formKey.currentState!.validate()) {
                            String displayName = _displayNameController.text.trim();
                            // to do update name
                          } else {
                            print("Not valid");
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
                          'Verify Number',
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
            ],
          ),
        ),
      ),
    );
  }
}
