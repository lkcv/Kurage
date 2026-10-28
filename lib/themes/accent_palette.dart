import 'package:flutter/material.dart';

/// Curated accent colors. [toneDark] and [toneLight] are the paired colors
/// used by controls and picker previews; [gradientEnd] colors navigation bars.
class AccentOption {
  const AccentOption({
    required this.name,
    required this.color,
    required this.toneDark,
    required this.toneLight,
    required this.gradientEnd,
  });

  final String name;
  final Color color;
  final Color toneDark;
  final Color toneLight;
  final Color gradientEnd;

  Color toneFor(Brightness brightness) =>
      brightness == Brightness.dark ? toneDark : toneLight;
}

class AccentPalette {
  const AccentPalette._();

  static const defaultAccent = Color(0xFFAA5CC3);
  static const defaultGradientEnd = Color(0xFF00A4DC);

  static const options = <AccentOption>[
    AccentOption(
      name: 'Scarlet', color: Color(0xFFD23B35),
      toneDark: Color(0xFFE15A47), toneLight: Color(0xFF923B2E),
      gradientEnd: Color(0xFFFF305B),
    ),
    AccentOption(
      name: 'Vermilion', color: Color(0xFFE34234),
      toneDark: Color(0xFFF04063), toneLight: Color(0xFF9C2A40),
      gradientEnd: Color(0xFFFD3F92),
    ),
    AccentOption(
      name: 'Raspberry', color: Color(0xFFBD335C),
      toneDark: Color(0xFFD3566E), toneLight: Color(0xFF893848),
      gradientEnd: Color(0xFFFF188A),
    ),
    AccentOption(
      name: 'Tangerine', color: Color(0xFFEF8532),
      toneDark: Color(0xFFF2A13F), toneLight: Color(0xFF9D6929),
      gradientEnd: Color(0xFFF5BD4C),
    ),
    AccentOption(
      name: 'Saffron', color: Color(0xFFF4C430),
      toneDark: Color(0xFFF2A431), toneLight: Color(0xFF9D6B20),
      gradientEnd: Color(0xFFEF8532),
    ),
    AccentOption(
      name: 'Emerald', color: Color(0xFF258557),
      toneDark: Color(0xFF269E7E), toneLight: Color(0xFF186652),
      gradientEnd: Color(0xFF26B6A5),
    ),
    AccentOption(
      name: 'Sea Glass', color: Color(0xFF1BA89E),
      toneDark: Color(0xFF82D5CD), toneLight: Color(0xFF006B65),
      gradientEnd: Color(0xFF58C6AF),
    ),
    AccentOption(
      name: 'Sky Blue', color: Color(0xFF169CCC),
      toneDark: Color(0xFF328AD4), toneLight: Color(0xFF215A8A),
      gradientEnd: Color(0xFF4F78DD),
    ),
    AccentOption(
      name: 'Azure', color: Color(0xFF007FFF),
      toneDark: Color(0xFF28A2F6), toneLight: Color(0xFF1A69A0),
      gradientEnd: Color(0xFF4FC4ED),
    ),
    AccentOption(
      name: 'Nord', color: Color(0xFF73A1BE),
      toneDark: Color(0xFF88C0D0), toneLight: Color(0xFF4B697C),
      gradientEnd: Color(0xFF5E81AC),
    ),
    AccentOption(
      name: 'Steel', color: Color(0xFF65758B),
      toneDark: Color(0xFF7E8DA2), toneLight: Color(0xFF525C69),
      gradientEnd: Color(0xFF97A5B9),
    ),
    AccentOption(
      name: 'Iris', color: Color(0xFF6562C6),
      toneDark: Color(0xFF816BCF), toneLight: Color(0xFF544687),
      gradientEnd: Color(0xFF9D74D8),
    ),
    AccentOption(
      name: 'Lavender', color: Color(0xFFA17BD8),
      toneDark: Color(0xFFB48FE0), toneLight: Color(0xFF755D92),
      gradientEnd: Color(0xFFC7A3E9),
    ),
    AccentOption(
      name: 'Azalea', color: Color(0xFFE065A6),
      toneDark: Color(0xFFDA68BD), toneLight: Color(0xFF985476),
      gradientEnd: Color(0xFFD04CC0),
    ),
    AccentOption(
      name: 'Rose', color: Color(0xFFFF0088),
      toneDark: Color(0xFFEB007A), toneLight: Color(0xFF99004F),
      gradientEnd: Color(0xFFD6006C),
    ),
    AccentOption(
      name: 'Fuchsia', color: Color(0xFFFF00FF),
      toneDark: Color(0xFFFF3AE4), toneLight: Color(0xFFA62594),
      gradientEnd: Color(0xFFFF73C9),
    ),
  ];

  static AccentOption? forColor(Color? color) {
    if (color == null) return null;
    for (final option in options) {
      if (option.color == color) return option;
    }
    return null;
  }
}
