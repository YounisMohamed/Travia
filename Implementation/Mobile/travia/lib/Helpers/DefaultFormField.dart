import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

Widget DefaultTextFormField({
  TextEditingController? controller,
  bool? isSecure,
  String? label,
  String? Function(String?)? validatorFun,
  double? height,
  required Icon? icon,
  double? borderRadius,
  TextInputType? type,
}) {
  return Container(
    height: height ?? 60,
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(borderRadius ?? 10.0),
      boxShadow: [
        BoxShadow(
          color: Colors.grey.withValues(alpha: 0.1),
          spreadRadius: 1,
          blurRadius: 8,
        ),
      ],
    ),
    child: Center(
      child: TextFormField(
        obscureText: isSecure ?? false,
        cursorColor: Colors.black,
        enableSuggestions: !(isSecure ?? false),
        autocorrect: !(isSecure ?? false),
        maxLines: 1,
        controller: controller,
        keyboardType: type ?? TextInputType.text,
        decoration: InputDecoration(
          prefixIcon: icon,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(borderRadius ?? 10.0),
            borderSide: BorderSide.none,
          ),
          hintText: label ?? "",
          hintStyle: GoogleFonts.poppins(
            color: Colors.grey.shade500,
            fontSize: 16,
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
          filled: true,
          fillColor: Colors.white,
          errorStyle: TextStyle(fontSize: 10),
        ),
        validator: validatorFun,
        style: GoogleFonts.poppins(
          color: Colors.black,
          fontSize: 16,
        ),
      ),
    ),
  );
}
