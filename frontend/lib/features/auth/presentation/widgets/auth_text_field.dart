import 'package:flutter/material.dart';

/// Feature-local form field. Per docs/architecture — Flutter Web
/// Application Architecture, §7: reuse is about other *features* needing
/// the same thing, not complexity alone — this stays inside
/// features/auth/ unless a second feature later needs the identical
/// component, at which point it's promoted to shared_widgets/.
class AuthTextField extends StatelessWidget {
  const AuthTextField({
    super.key,
    required this.controller,
    required this.label,
    this.obscureText = false,
    this.validator,
    this.keyboardType,
    this.autofillHints,
  });

  final TextEditingController controller;
  final String label;
  final bool obscureText;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final Iterable<String>? autofillHints;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      validator: validator,
      keyboardType: keyboardType,
      autofillHints: autofillHints,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
    );
  }
}
