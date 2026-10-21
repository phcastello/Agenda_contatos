import 'package:flutter/services.dart';

// E-mail tem tamanho variável: a formatação remove espaços, sem fixar domínio.
class EmailInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (!newValue.composing.isCollapsed) return newValue;
    String format(String text) =>
        text.replaceAll(RegExp(r'\s'), '').toLowerCase();
    final text = format(newValue.text);
    int offset(int value) => value < 0
        ? text.length
        : format(
            newValue.text.substring(0, value.clamp(0, newValue.text.length)),
          ).length;
    return TextEditingValue(
      text: text,
      selection: TextSelection(
        baseOffset: offset(newValue.selection.baseOffset),
        extentOffset: offset(newValue.selection.extentOffset),
      ),
    );
  }
}

bool isValidEmail(String email) {
  if (email.length > 254) return false;
  final parts = email.split('@');
  if (parts.length != 2) return false;
  final local = parts[0];
  final domain = parts[1];
  if (local.isEmpty ||
      local.length > 64 ||
      local.startsWith('.') ||
      local.endsWith('.') ||
      local.contains('..')) {
    return false;
  }
  if (!RegExp(r"^[a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+$").hasMatch(local)) {
    return false;
  }
  final labels = domain.split('.');
  if (labels.length < 2 || !RegExp(r'^[a-zA-Z]{2,}$').hasMatch(labels.last)) {
    return false;
  }
  return labels.every(
    (label) =>
        label.length <= 63 &&
        RegExp(r'^[a-zA-Z0-9](?:[a-zA-Z0-9-]*[a-zA-Z0-9])?$').hasMatch(label),
  );
}
