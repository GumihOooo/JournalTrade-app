import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// GumiBook shared text field (DESIGN.md §6: `GumiTextField`).
class GumiTextField extends StatelessWidget {
  const GumiTextField({
    super.key,
    required this.label,
    this.controller,
    this.hint,
    this.prefixIcon,
    this.suffixIcon,
    this.suffix,
    this.obscure = false,
    this.enabled = true,
    this.keyboardType,
    this.validator,
    this.onChanged,
    this.maxLines = 1,
    this.minLines,
    this.maxLength,
    this.textInputAction,
    this.autofillHints,
    this.hintText,
    this.inputFormatters,
  });

  final String label;
  final TextEditingController? controller;
  final String? hint;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final Widget? suffix;
  final bool obscure;
  final bool enabled;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onChanged;
  final int maxLines;
  final int? minLines;
  final int? maxLength;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final String? hintText;
  final List<TextInputFormatter>? inputFormatters;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      enabled: enabled,
      keyboardType: keyboardType,
      validator: validator,
      onChanged: onChanged,
      maxLines: obscure ? 1 : maxLines,
      minLines: obscure ? 1 : minLines,
      maxLength: maxLength,
      textInputAction: textInputAction,
      autofillHints: autofillHints,
      inputFormatters: inputFormatters,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint ?? hintText,
        prefixIcon: prefixIcon,
        suffixIcon: suffixIcon,
        suffix: suffix,
      ),
    );
  }
}

/// Password field with visibility toggle (DESIGN.md §5.3).
class GumiPasswordField extends StatefulWidget {
  const GumiPasswordField({
    super.key,
    required this.label,
    this.controller,
    this.validator,
    this.onChanged,
    this.autofillHints,
  });

  final String label;
  final TextEditingController? controller;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onChanged;
  final Iterable<String>? autofillHints;

  @override
  State<GumiPasswordField> createState() => _GumiPasswordFieldState();
}

class _GumiPasswordFieldState extends State<GumiPasswordField> {
  bool _obscured = true;

  @override
  Widget build(BuildContext context) {
    return GumiTextField(
      label: widget.label,
      controller: widget.controller,
      obscure: _obscured,
      validator: widget.validator,
      onChanged: widget.onChanged,
      autofillHints: widget.autofillHints,
      keyboardType: TextInputType.visiblePassword,
      textInputAction: TextInputAction.done,
      suffixIcon: IconButton(
        onPressed: () => setState(() => _obscured = !_obscured),
        icon: Icon(_obscured ? Icons.visibility_outlined : Icons.visibility_off_outlined),
        tooltip: _obscured ? 'Show password' : 'Hide password',
      ),
    );
  }
}

/// Numeric field for financial values (DESIGN.md §5.7: numeric keyboard).
/// [allowNegative] (S-3): Android decimal keyboards ship no minus key,
/// so the field accepts a leading `-` via input formatters; the value
/// stays editable and is validated by the caller's validator.
class NumericField extends StatelessWidget {
  const NumericField({
    super.key,
    required this.label,
    this.controller,
    this.hint,
    this.validator,
    this.onChanged,
    this.decimals = true,
    this.allowNegative = false,
    this.suffixText,
  });

  final String label;
  final TextEditingController? controller;
  final String? hint;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onChanged;
  final bool decimals;
  final bool allowNegative;
  final String? suffixText;

  @override
  Widget build(BuildContext context) {
    return GumiTextField(
      label: label,
      controller: controller,
      hint: hint,
      validator: validator,
      onChanged: onChanged,
      keyboardType:
          decimals ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.number,
      inputFormatters: [
        FilteringTextInputFormatter.allow(
          RegExp(allowNegative ? r'^-?[0-9.]*' : r'^[0-9.]*'),
          replacementString: '',
        ),
      ],
      // suffixText aligns with the theme contentPadding, unlike a
      // hand-padded suffixIcon.
      suffix: suffixText == null
          ? null
          : Text(
              suffixText!,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
    );
  }
}
