import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'core.dart';

/// Hücre işaretlerinin özgün çizimleri (yalnızca temel şekiller).
void paintMark(Canvas c, Mark m, Rect r, {required Color ink, required Color accent, required Color accent2, int dir = 0}) {
  final s = r.width;
  final o = r.center;
  final fill = Paint()..color = ink;
  final stroke = Paint()
    ..color = ink
    ..style = PaintingStyle.stroke
    ..strokeWidth = math.max(1.5, s * 0.07)
    ..strokeCap = StrokeCap.round;
  switch (m) {
    case Mark.none:
      return;
    case Mark.fill:
      c.drawRRect(RRect.fromRectAndRadius(r.deflate(s * 0.04), Radius.circular(s * 0.1)), Paint()..color = ink.withValues(alpha: 0.86));
    case Mark.dot:
      c.drawCircle(o, s * 0.09, Paint()..color = ink.withValues(alpha: 0.5));
    case Mark.cross:
      final d = s * 0.2;
      final p = Paint()
        ..color = ink.withValues(alpha: 0.5)
        ..strokeWidth = math.max(1.5, s * 0.06)
        ..strokeCap = StrokeCap.round;
      c.drawLine(o - Offset(d, d), o + Offset(d, d), p);
      c.drawLine(o - Offset(d, -d), o + Offset(d, -d), p);
    case Mark.star:
      final path = Path();
      for (var k = 0; k < 10; k++) {
        final a = -math.pi / 2 + k * math.pi / 5;
        final rad = (k.isEven ? 0.38 : 0.16) * s;
        final p = o + Offset(math.cos(a) * rad, math.sin(a) * rad);
        k == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
      }
      path.close();
      c.drawPath(path, Paint()..color = accent);
    case Mark.bulb:
      c.drawCircle(o, s * 0.3, Paint()..color = const Color(0xFFF2C14E));
      c.drawCircle(o, s * 0.3, stroke..color = const Color(0xFF8A6A1F));
      c.drawCircle(o - Offset(s * 0.09, s * 0.09), s * 0.07, Paint()..color = Colors.white70);
    case Mark.tent:
      final path = Path()
        ..moveTo(o.dx, o.dy - s * 0.3)
        ..lineTo(o.dx + s * 0.33, o.dy + s * 0.28)
        ..lineTo(o.dx - s * 0.33, o.dy + s * 0.28)
        ..close();
      c.drawPath(path, Paint()..color = const Color(0xFFD9895B));
      c.drawLine(o + Offset(0, -s * 0.05), o + Offset(0, s * 0.28), Paint()..color = const Color(0xFF6B3E26)..strokeWidth = s * 0.06);
    case Mark.tree:
      c.drawRect(Rect.fromCenter(center: o + Offset(0, s * 0.22), width: s * 0.1, height: s * 0.2), Paint()..color = const Color(0xFF7A5230));
      c.drawCircle(o + Offset(0, -s * 0.05), s * 0.26, Paint()..color = const Color(0xFF4E8A5B));
    case Mark.ship:
      c.drawRRect(RRect.fromRectAndRadius(r.deflate(s * 0.14), Radius.circular(s * 0.3)), Paint()..color = const Color(0xFF3B5F7A));
    case Mark.circle:
      c.drawCircle(o, s * 0.3, stroke..color = ink);
    case Mark.ring:
      c.drawCircle(o, s * 0.32, Paint()..color = Colors.white);
      c.drawCircle(o, s * 0.32, stroke..color = ink);
    case Mark.disc:
      c.drawCircle(o, s * 0.32, fill);
    case Mark.slashF:
      c.drawLine(r.bottomLeft + Offset(s * 0.12, -s * 0.12), r.topRight + Offset(-s * 0.12, s * 0.12), stroke..color = accent..strokeWidth = s * 0.1);
    case Mark.slashB:
      c.drawLine(r.topLeft + Offset(s * 0.12, s * 0.12), r.bottomRight - Offset(s * 0.12, s * 0.12), stroke..color = accent..strokeWidth = s * 0.1);
    case Mark.mirrorF:
      c.drawLine(r.bottomLeft + Offset(s * 0.1, -s * 0.1), r.topRight + Offset(-s * 0.1, s * 0.1), stroke..color = ink..strokeWidth = s * 0.08);
    case Mark.mirrorB:
      c.drawLine(r.topLeft + Offset(s * 0.1, s * 0.1), r.bottomRight - Offset(s * 0.1, s * 0.1), stroke..color = ink..strokeWidth = s * 0.08);
    case Mark.plus:
      c.drawCircle(o, s * 0.34, Paint()..color = const Color(0xFFD1495B));
      final p = Paint()
        ..color = Colors.white
        ..strokeWidth = s * 0.09
        ..strokeCap = StrokeCap.round;
      c.drawLine(o - Offset(s * 0.16, 0), o + Offset(s * 0.16, 0), p);
      c.drawLine(o - Offset(0, s * 0.16), o + Offset(0, s * 0.16), p);
    case Mark.minus:
      c.drawCircle(o, s * 0.34, Paint()..color = const Color(0xFF2E6F95));
      c.drawLine(
          o - Offset(s * 0.16, 0),
          o + Offset(s * 0.16, 0),
          Paint()
            ..color = Colors.white
            ..strokeWidth = s * 0.09
            ..strokeCap = StrokeCap.round);
    case Mark.ghost:
      // Hayalet: dalgalı etekli yuvarlak gövde
      final path = Path()
        ..moveTo(o.dx - s * 0.28, o.dy + s * 0.3)
        ..lineTo(o.dx - s * 0.28, o.dy - s * 0.02)
        ..arcToPoint(Offset(o.dx + s * 0.28, o.dy - s * 0.02), radius: Radius.circular(s * 0.28))
        ..lineTo(o.dx + s * 0.28, o.dy + s * 0.3)
        ..lineTo(o.dx + s * 0.14, o.dy + s * 0.2)
        ..lineTo(o.dx, o.dy + s * 0.3)
        ..lineTo(o.dx - s * 0.14, o.dy + s * 0.2)
        ..close();
      c.drawPath(path, Paint()..color = const Color(0xFFE8E4F0));
      c.drawPath(path, stroke..color = const Color(0xFF6F6A80)..strokeWidth = s * 0.04);
      c.drawCircle(o + Offset(-s * 0.09, -s * 0.03), s * 0.045, Paint()..color = const Color(0xFF3A3548));
      c.drawCircle(o + Offset(s * 0.09, -s * 0.03), s * 0.045, Paint()..color = const Color(0xFF3A3548));
    case Mark.vampire:
      // Pelerinli üçgen ve iki diş
      final path = Path()
        ..moveTo(o.dx, o.dy - s * 0.32)
        ..lineTo(o.dx + s * 0.32, o.dy + s * 0.3)
        ..lineTo(o.dx - s * 0.32, o.dy + s * 0.3)
        ..close();
      c.drawPath(path, Paint()..color = const Color(0xFF7B2D3B));
      c.drawCircle(o + Offset(0, -s * 0.06), s * 0.14, Paint()..color = const Color(0xFFF1E3D3));
      c.drawCircle(o + Offset(-s * 0.05, -s * 0.08), s * 0.025, Paint()..color = const Color(0xFF7B2D3B));
      c.drawCircle(o + Offset(s * 0.05, -s * 0.08), s * 0.025, Paint()..color = const Color(0xFF7B2D3B));
    case Mark.zombie:
      c.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: o, width: s * 0.56, height: s * 0.6), Radius.circular(s * 0.12)),
          Paint()..color = const Color(0xFF8DB580));
      c.drawLine(o + Offset(-s * 0.16, -s * 0.08), o + Offset(-s * 0.04, -s * 0.08), Paint()..color = const Color(0xFF2F4A2A)..strokeWidth = s * 0.05);
      c.drawCircle(o + Offset(s * 0.1, -s * 0.08), s * 0.05, Paint()..color = const Color(0xFF2F4A2A));
      c.drawLine(o + Offset(-s * 0.12, s * 0.14), o + Offset(s * 0.12, s * 0.12), Paint()..color = const Color(0xFF2F4A2A)..strokeWidth = s * 0.04);
    case Mark.gem:
      final path = Path()
        ..moveTo(o.dx, o.dy - s * 0.3)
        ..lineTo(o.dx + s * 0.26, o.dy)
        ..lineTo(o.dx, o.dy + s * 0.3)
        ..lineTo(o.dx - s * 0.26, o.dy)
        ..close();
      c.drawPath(path, Paint()..color = accent2);
    case Mark.arrow:
      c.save();
      c.translate(o.dx, o.dy);
      c.rotate(dir * math.pi / 4);
      final p = Paint()
        ..color = ink
        ..strokeWidth = s * 0.08
        ..strokeCap = StrokeCap.round;
      c.drawLine(Offset(0, s * 0.28), Offset(0, -s * 0.24), p);
      c.drawLine(Offset(0, -s * 0.28), Offset(-s * 0.14, -s * 0.12), p);
      c.drawLine(Offset(0, -s * 0.28), Offset(s * 0.14, -s * 0.12), p);
      c.restore();
    case Mark.wall:
      c.drawRect(r, Paint()..color = const Color(0xFF5A4A3F));
      final p = Paint()
        ..color = const Color(0xFF3F332B)
        ..strokeWidth = math.max(1, s * 0.03);
      c.drawLine(r.centerLeft, r.centerRight, p);
      c.drawLine(Offset(o.dx, r.top), Offset(o.dx, o.dy), p);
      c.drawLine(Offset(r.left + s * 0.25, o.dy), Offset(r.left + s * 0.25, r.bottom), p);
      c.drawLine(Offset(r.left + s * 0.75, o.dy), Offset(r.left + s * 0.75, r.bottom), p);
    case Mark.hole:
      c.drawCircle(o, s * 0.32, Paint()..color = const Color(0xFF2B2B33));
  }
}
