import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Serbest bulmacaların ortak çizim yardımcıları.
void freeText(Canvas c, String s, Offset center, double size, Color color, {bool bold = false, double? maxWidth}) {
  final tp = TextPainter(
    text: TextSpan(text: s, style: TextStyle(fontSize: size, color: color, fontWeight: bold ? FontWeight.w800 : FontWeight.w600, height: 1.1)),
    textDirection: TextDirection.ltr,
    textAlign: TextAlign.center,
  )..layout(maxWidth: maxWidth ?? double.infinity);
  tp.paint(c, center - Offset(tp.width / 2, tp.height / 2));
}

/// Material simgesini tuvale çizer (nesne görselleri).
void freeIcon(Canvas c, IconData icon, Offset center, double size, Color color) {
  final tp = TextPainter(
    text: TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(fontSize: size, color: color, fontFamily: icon.fontFamily, package: icon.fontPackage, height: 1)),
    textDirection: TextDirection.ltr,
  )..layout();
  tp.paint(c, center - Offset(tp.width / 2, tp.height / 2));
}

void dashLine(Canvas c, Offset a, Offset b, Paint p, {double dash = 6, double gap = 4}) {
  final d = b - a;
  final len = d.distance;
  if (len <= 0) return;
  final u = d / len;
  var t = 0.0;
  while (t < len) {
    final e = math.min(t + dash, len);
    c.drawLine(a + u * t, a + u * e, p);
    t = e + gap;
  }
}

/// Domino taşı: [r] dikdörtgeninde iki yarı (dikeyse üst/alt).
void paintDomino(Canvas c, Rect r, int a, int b, bool vertical, {bool lifted = false}) {
  final rr = RRect.fromRectAndRadius(r, Radius.circular(math.min(r.width, r.height) * 0.18));
  c.drawRRect(rr.shift(Offset(0, lifted ? 7 : 3)), Paint()..color = const Color(0x55000000));
  c.drawRRect(rr, Paint()..color = const Color(0xFFFBF6EA));
  c.drawRRect(rr, Paint()
    ..color = const Color(0xFF9C8B6E)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.4);
  final h1 = vertical ? Rect.fromLTWH(r.left, r.top, r.width, r.height / 2) : Rect.fromLTWH(r.left, r.top, r.width / 2, r.height);
  final h2 = vertical ? Rect.fromLTWH(r.left, r.center.dy, r.width, r.height / 2) : Rect.fromLTWH(r.center.dx, r.top, r.width / 2, r.height);
  final line = Paint()
    ..color = const Color(0xFF9C8B6E)
    ..strokeWidth = 1.6;
  if (vertical) {
    c.drawLine(Offset(r.left + r.width * 0.15, r.center.dy), Offset(r.right - r.width * 0.15, r.center.dy), line);
  } else {
    c.drawLine(Offset(r.center.dx, r.top + r.height * 0.15), Offset(r.center.dx, r.bottom - r.height * 0.15), line);
  }
  paintPips(c, h1, a);
  paintPips(c, h2, b);
}

/// 0..6 zar düzeninde noktalar.
void paintPips(Canvas c, Rect r, int n) {
  final s = math.min(r.width, r.height);
  final q = s * 0.26;
  final o = r.center;
  const pos = {
    0: <(int, int)>[],
    1: [(0, 0)],
    2: [(-1, -1), (1, 1)],
    3: [(-1, -1), (0, 0), (1, 1)],
    4: [(-1, -1), (1, -1), (-1, 1), (1, 1)],
    5: [(-1, -1), (1, -1), (0, 0), (-1, 1), (1, 1)],
    6: [(-1, -1), (1, -1), (-1, 0), (1, 0), (-1, 1), (1, 1)],
  };
  final paint = Paint()..color = const Color(0xFF23314A);
  for (final (x, y) in pos[n.clamp(0, 6)]!) {
    c.drawCircle(o + Offset(x * q, y * q), s * 0.085, paint);
  }
}
