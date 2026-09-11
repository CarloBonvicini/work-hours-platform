// Lettura e modifica dei canali RGB di un colore per l'editor aspetto.

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

String formatColorHex(Color color) {
  return '#'
          '${colorChannel(color, RgbColorChannel.red).toRadixString(16).padLeft(2, '0')}'
          '${colorChannel(color, RgbColorChannel.green).toRadixString(16).padLeft(2, '0')}'
          '${colorChannel(color, RgbColorChannel.blue).toRadixString(16).padLeft(2, '0')}'
      .toUpperCase();
}

enum RgbColorChannel { red, green, blue }

int colorChannel(Color color, RgbColorChannel channel) {
  final value = switch (channel) {
    RgbColorChannel.red => color.r,
    RgbColorChannel.green => color.g,
    RgbColorChannel.blue => color.b,
  };
  return (value * 255).round().clamp(0, 255);
}

Color replaceColorChannel(Color color, {int? red, int? green, int? blue}) {
  return Color.fromARGB(
    (color.a * 255).round().clamp(0, 255),
    red ?? colorChannel(color, RgbColorChannel.red),
    green ?? colorChannel(color, RgbColorChannel.green),
    blue ?? colorChannel(color, RgbColorChannel.blue),
  );
}
