import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class RoundedField extends StatelessWidget {
  const RoundedField({
    super.key,
    required this.controller,
    required this.hint,
    required this.fill,
    required this.onSubmitted,
    this.inputFormatters,
    this.readOnly = false,
  });

  final TextEditingController controller;
  final String hint;
  final Color fill;
  final ValueChanged<String> onSubmitted;
  final List<TextInputFormatter>? inputFormatters;
  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      textInputAction: TextInputAction.done,
      inputFormatters: inputFormatters,
      readOnly: readOnly,
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: fill,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
      onSubmitted: onSubmitted,
    );
  }
}

class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onTap,
  });

  final String label;
  final VoidCallback onTap;

  static const Color orange = Color(0xFFF36C21);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: orange,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.2,
          ),
        ),
      ),
    );
  }
}
