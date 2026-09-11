// Campi di input data e minuti dell'inserimento rapido.

import 'dart:async';
import 'package:flutter/material.dart';

class DateField extends StatelessWidget {
  const DateField({
    super.key,
    required this.controller,
    required this.onPickDate,
  });

  final TextEditingController controller;
  final Future<void> Function() onPickDate;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      key: const ValueKey('quick-entry-date-field'),
      controller: controller,
      readOnly: true,
      onTap: () => onPickDate(),
      decoration: const InputDecoration(
        labelText: 'Data',
        suffixIcon: Icon(Icons.calendar_today),
      ),
      validator: (value) {
        if (value == null || !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) {
          return 'Seleziona una data valida.';
        }

        return null;
      },
    );
  }
}

class MinutesField extends StatelessWidget {
  const MinutesField({
    super.key,
    required this.controller,
    required this.label,
  });

  final TextEditingController controller;
  final String label;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(labelText: label),
      validator: (value) {
        final parsedValue = int.tryParse(value?.trim() ?? '');
        if (parsedValue == null || parsedValue <= 0) {
          return 'Inserisci un numero di minuti valido.';
        }

        return null;
      },
    );
  }
}
