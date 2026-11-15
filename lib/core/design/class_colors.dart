import 'package:flutter/material.dart';

class ClassColor {
  const ClassColor(this.name, this.accent, this.tint);

  final String name;
  final Color accent;
  final Color tint;
}

const classColors = <ClassColor>[
  ClassColor('Biru', Color(0xFF1762F3), Color(0xFFEAF2FF)),
  ClassColor('Toska', Color(0xFF087F80), Color(0xFFE4F6F3)),
  ClassColor('Ungu', Color(0xFF7353B8), Color(0xFFF1ECFA)),
  ClassColor('Jingga', Color(0xFFB45B24), Color(0xFFFFF0E4)),
  ClassColor('Hijau', Color(0xFF23834B), Color(0xFFE7F7EC)),
  ClassColor('Merah muda', Color(0xFFA84575), Color(0xFFFCEBF3)),
  ClassColor('Nila', Color(0xFF475BB2), Color(0xFFEBEEFC)),
  ClassColor('Kuning', Color(0xFF926C12), Color(0xFFFFF6DA)),
  ClassColor('Bata', Color(0xFFA34E43), Color(0xFFFBECE9)),
];

ClassColor classColor(int index) => classColors[index % classColors.length];
