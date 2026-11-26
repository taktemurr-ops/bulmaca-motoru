import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:studio_core/core/strings.dart';

import '../texts.dart';
import 'free_paint.dart';
import 'free_view.dart';
import 'trick_logic.dart';
import 'trick_texts.dart';

/// Nesne simgeleri (TrickLogic.iconCount kadar).
const kTrickIcons = <IconData>[
  Icons.star_rounded, Icons.favorite_rounded, Icons.vpn_key_rounded, Icons.music_note_rounded, Icons.anchor_rounded,
  Icons.diamond_rounded, Icons.eco_rounded, Icons.bolt_rounded, Icons.local_florist_rounded, Icons.cake_rounded,
  Icons.icecream_rounded, Icons.cookie_rounded, Icons.egg_rounded, Icons.umbrella_rounded, Icons.rocket_launch_rounded,
  Icons.directions_car_rounded, Icons.home_rounded, Icons.lightbulb_rounded, Icons.forest_rounded, Icons.sports_soccer_rounded,
  Icons.toys_rounded, Icons.pets_rounded, Icons.spa_rounded, Icons.water_drop_rounded,
];

const _iconColors = [
  Color(0xFFFFC83D), Color(0xFFFF5C7A), Color(0xFFE0A030), Color(0xFF7B8CFF), Color(0xFF4F8CC9), Color(0xFF5CD6F0),
  Color(0xFF5BC26A), Color(0xFFFFB020), Color(0xFFFF7AB8), Color(0xFFFF9466), Color(0xFFFFB8D0), Color(0xFFC98B4E),
  Color(0xFFF7EBD0), Color(0xFF9B6BFF), Color(0xFFFF6B4A), Color(0xFF4FC3F7), Color(0xFFFF8A65), Color(0xFFFFE066),
  Color(0xFF3FA66B), Color(0xFFF0F0F0), Color(0xFFE57373), Color(0xFFD7A36B), Color(0xFF81C784), Color(0xFF64B5F6),
];

const _numColors = [Color(0xFFFF6B6B), Color(0xFFFFC145), Color(0xFF4DD4AC), Color(0xFF5DA9FF), Color(0xFFC77DFF), Color(0xFFFF8FB1)];

String trickPrompt(String key, String lang) => Strings.pick(kTrickPromptsRaw[key]!.split('|'), lang);

/// Tuzaklı Bilmeceler oyunu.
class TrickGame extends FreeGame {
  late TrickState st;
  int _hintStep = 0;
  List<num>? _ghost;
  double _ghostT = 0, _time = 0;

  TrickGame(super.lv) {
    st = TrickState(lv);
  }

  @override
  bool get won => st.won;

  @override
  bool get lost => st.lost;

  @override
  bool get busy => st.holding;

  @override
  String status(String lang) => switch (st.t) {
        TrickLogic.tTapN => '${st.count} / ${st.p0}',
        TrickLogic.tBalloons =>
          '${bt(lang, 'left')}: ${st.objs.where((o) => o.kind == TrickLogic.oBalloon && !o.gone).length}',
        _ => '${bt(lang, 'moves')}: $moves',
      };

  // ---- yerleşim
  double _band = 0, _s = 1;
  Offset _o = Offset.zero;

  void _layout() {
    _band = math.max(72, size.height * 0.13);
    _s = math.min(size.width / TrickLogic.worldW, (size.height - _band) / TrickLogic.worldH);
    _o = Offset((size.width - TrickLogic.worldW * _s) / 2, _band + (size.height - _band - TrickLogic.worldH * _s) / 2);
  }

  Offset _w(Offset p) => (p - _o) / _s;
  Offset _scr(double x, double y) => _o + Offset(x, y) * _s;

  @override
  bool down(Offset p) {
    _layout();
    final q = _w(p);
    st.down(q.dx, q.dy);
    _ghost = null;
    return true;
  }

  @override
  bool move(Offset p) {
    final q = _w(p);
    st.move(q.dx, q.dy);
    return true;
  }

  @override
  bool up(Offset p) {
    st.up();
    moves++;
    return true;
  }

  @override
  bool get wantsHold => st.t == TrickLogic.tFill;

  /// İpucu: bölümü baştan kur, çözümün ilk adımlarını oynat ve sıradakini göster.
  @override
  bool hint() {
    final s = TrickState(lv);
    final k = math.min(_hintStep, st.sol.length - 1);
    for (var i = 0; i < k; i++) {
      s.perform(st.sol[i]);
    }
    st = s;
    _ghost = st.sol[k];
    _ghostT = 0;
    _hintStep++;
    moves++;
    return true;
  }

  @override
  bool step(double dt) {
    _time += dt;
    st.tick(dt);
    if (_ghost != null) _ghostT += dt;
    return true;
  }

  // ---- çizim
  @override
  void paint(Canvas c, Size size, FPalette p, double t) {
    this.size = size;
    _layout();
    final area = Rect.fromLTWH(_o.dx, _o.dy, TrickLogic.worldW * _s, TrickLogic.worldH * _s);
    final night = st.t == TrickLogic.tNight;
    final dark = st.night == 1;
    c.drawRRect(
        RRect.fromRectAndRadius(area, Radius.circular(24 * _s)),
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: night
                ? (dark ? [const Color(0xFF0B1430), const Color(0xFF1C2A55)] : [const Color(0xFF8FD3FF), const Color(0xFFD9F1FF)])
                : [const Color(0xFFFFF6E5), const Color(0xFFF1E2C6)],
          ).createShader(area));
    if (night) {
      c.drawRect(Rect.fromLTWH(area.left, _scr(0, 1080).dy, area.width, area.bottom - _scr(0, 1080).dy),
          Paint()..color = dark ? const Color(0xFF1F3B2A) : const Color(0xFF6CC070));
      if (dark) {
        final rnd = math.Random(lv.seed);
        for (var i = 0; i < 26; i++) {
          c.drawCircle(_scr(rnd.nextDouble() * 1000, 60 + rnd.nextDouble() * 900), 2.2 + rnd.nextDouble() * 2,
              Paint()..color = Colors.white.withValues(alpha: 0.5 + 0.5 * math.sin(_time * 2 + i).abs()));
        }
        final m = _scr(760, 260);
        c.drawCircle(m, 70 * _s, Paint()..color = const Color(0xFFFFF4C2));
        c.drawCircle(m + Offset(28 * _s, -16 * _s), 62 * _s, Paint()..color = const Color(0xFF14204A));
      }
    }
    _paintPrompt(c, p);
    for (var i = 0; i < st.objs.length; i++) {
      final o = st.objs[i];
      if (o.gone && o.kind != TrickLogic.oNumber && o.kind != TrickLogic.oBalloon) continue;
      _paintObj(c, o, p);
    }
    _paintGhost(c);
  }

  void _paintPrompt(Canvas c, FPalette p) {
    final lang = p.lang;
    final key = TrickLogic.promptKeys[st.t];
    var text = trickPrompt(key, lang).replaceAll('{n}', '${st.p0}');
    final box = Rect.fromLTWH(10, 6, size.width - 20, _band - 12);
    c.drawRRect(RRect.fromRectAndRadius(box, const Radius.circular(18)), Paint()..color = const Color(0xE6FFFFFF));
    final fs = math.min(26.0, box.height * 0.34);
    final extra = st.t == TrickLogic.tFind || st.t == TrickLogic.tCount || st.t == TrickLogic.tMath;
    if (st.t == TrickLogic.tMath) {
      final b = st.p1, cc = st.p2.abs();
      text = '$text\n${st.p2 < 0 ? '${st.p0} × $b − $cc' : '${st.p0} + $b × $cc'} = ?';
    }
    final cx = extra && st.t != TrickLogic.tMath ? box.center.dx - box.height * 0.4 : box.center.dx;
    freeText(c, text, Offset(cx, box.center.dy), fs, const Color(0xFF263045), bold: true, maxWidth: box.width - box.height * 1.2);
    if (st.t == TrickLogic.tFind || st.t == TrickLogic.tCount) {
      final tp = TextPainter(text: TextSpan(text: text, style: TextStyle(fontSize: fs, fontWeight: FontWeight.w800)), textDirection: TextDirection.ltr)
        ..layout(maxWidth: box.width - box.height * 1.2);
      final ic = Offset(cx + tp.width / 2 + box.height * 0.45, box.center.dy);
      freeIcon(c, kTrickIcons[st.p0 % kTrickIcons.length], ic, box.height * 0.62, _iconColors[st.p0 % _iconColors.length]);
    }
  }

  void _paintObj(Canvas c, TObj o, FPalette p) {
    final ctr = _scr(o.x, o.y);
    final s = o.s * _s;
    switch (o.kind) {
      case TrickLogic.oItem:
        c.save();
        c.translate(ctr.dx, ctr.dy);
        c.rotate(o.rot);
        var col = _iconColors[o.icon % _iconColors.length];
        if (o.color == 1) col = HSVColor.fromColor(col).withHue((HSVColor.fromColor(col).hue + 40) % 360).toColor();
        if (o.movable) c.drawCircle(const Offset(0, 6), s * 0.95, Paint()..color = const Color(0x22000000));
        freeIcon(c, kTrickIcons[o.icon % kTrickIcons.length], Offset.zero, s * 1.9, col);
        if (p.colorBlind && o.color == 1) freeText(c, '•', Offset(0, s), s * 0.8, const Color(0xFF263045));
        c.restore();
      case TrickLogic.oCover:
        _cover(c, ctr, s, o.icon);
      case TrickLogic.oCloud:
        _cloud(c, ctr, s, o.icon == 0 ? const Color(0xFFF4F7FB) : Colors.white.withValues(alpha: 0.92));
      case TrickLogic.oNumber:
        final col = _numColors[o.color % _numColors.length];
        if (o.gone) {
          freeText(c, '✓', ctr, s * 0.6, const Color(0xFF2E9E5B), bold: true);
        } else {
          freeText(c, '${o.val}', ctr + const Offset(2, 3), s * 0.9, const Color(0x33000000), bold: true);
          freeText(c, '${o.val}', ctr, s * 0.9, col, bold: true);
        }
      case TrickLogic.oButton:
        final r = RRect.fromRectAndRadius(Rect.fromCenter(center: ctr, width: s * 1.8, height: s * 1.3), Radius.circular(s * 0.3));
        c.drawRRect(r.shift(Offset(0, 5 * _s)), Paint()..color = const Color(0x33000000));
        c.drawRRect(r, Paint()..color = const Color(0xFF3D5AFE));
        final label = o.icon == 1 ? (o.val < 0 ? '◀' : (o.val == 0 ? '=' : '▶')) : '${o.val}';
        freeText(c, label, ctr, s * 0.62, Colors.white, bold: true);
      case TrickLogic.oSun:
        if (st.night == 1) return;
        for (var k = 0; k < 10; k++) {
          final a = k * math.pi / 5 + _time * 0.4;
          c.drawLine(ctr + Offset(math.cos(a), math.sin(a)) * s * 1.05, ctr + Offset(math.cos(a), math.sin(a)) * s * 1.45,
              Paint()
                ..color = const Color(0xFFFFB300)
                ..strokeWidth = s * 0.12
                ..strokeCap = StrokeCap.round);
        }
        c.drawCircle(ctr, s * 0.9, Paint()..color = const Color(0xFFFFD43B));
      case TrickLogic.oCurtain:
        final win = Rect.fromCenter(center: _scr(o.ox, o.oy), width: s * 1.7, height: s * 2.4);
        c.drawRect(win, Paint()..color = o.flag == 1 ? const Color(0xFFFFF3B0) : const Color(0xFF9BD4FF));
        c.drawRect(win, Paint()
          ..color = const Color(0xFF8D6E63)
          ..style = PaintingStyle.stroke
          ..strokeWidth = s * 0.1);
        if (o.flag == 1) {
          final beam = Path()
            ..moveTo(win.left, win.bottom)
            ..lineTo(win.right, win.bottom)
            ..lineTo(_scr(500, 1150).dx + s * 1.5, _scr(500, 1150).dy)
            ..lineTo(_scr(500, 1150).dx - s * 1.5, _scr(500, 1150).dy)
            ..close();
          c.drawPath(beam, Paint()..color = const Color(0x33FFE680));
        }
        final cr = Rect.fromCenter(center: ctr, width: s * 1.8, height: s * 2.6);
        c.drawRRect(RRect.fromRectAndRadius(cr, Radius.circular(s * 0.1)), Paint()..color = const Color(0xFFC0392B));
        for (var k = 1; k < 5; k++) {
          final x = cr.left + cr.width * k / 5;
          c.drawLine(Offset(x, cr.top), Offset(x, cr.bottom), Paint()
            ..color = const Color(0x55000000)
            ..strokeWidth = 2);
        }
      case TrickLogic.oCreature:
        _creature(c, ctr, s, o.icon, o.flag == 1);
      case TrickLogic.oBox:
        final r = Rect.fromCenter(center: ctr, width: s * 1.6, height: s * 1.2);
        c.drawRRect(RRect.fromRectAndRadius(r, Radius.circular(s * 0.1)), Paint()..color = const Color(0xFFB07A4A));
        if (o.flag == 0) {
          c.drawRect(Rect.fromLTWH(r.left - s * 0.08, r.top - s * 0.25, r.width + s * 0.16, s * 0.3), Paint()..color = const Color(0xFF8D5A32));
          freeText(c, '?', r.center, s * 0.6, const Color(0x99FFFFFF), bold: true);
        } else {
          c.drawRect(Rect.fromLTWH(r.left, r.top, r.width, s * 0.18), Paint()..color = const Color(0xFF5D3A1E));
        }
      case TrickLogic.oFood:
        freeIcon(c, Icons.cookie_rounded, ctr, s * 1.9, const Color(0xFFC98B4E));
      case TrickLogic.oCandle:
        final body = Rect.fromCenter(center: ctr, width: s * 0.55, height: s * 1.4);
        c.drawRRect(RRect.fromRectAndRadius(body, Radius.circular(s * 0.1)), Paint()..color = const Color(0xFFFFF1E0));
        c.drawLine(Offset(ctr.dx, body.top), Offset(ctr.dx, body.top - s * 0.18), Paint()
          ..color = const Color(0xFF333333)
          ..strokeWidth = 3);
        if (o.flag == 1) _flame(c, Offset(ctr.dx, body.top - s * 0.42), s * 0.32);
      case TrickLogic.oMatchBox:
        final r = Rect.fromCenter(center: ctr, width: s * 1.6, height: s * 1.0);
        c.drawRRect(RRect.fromRectAndRadius(r, Radius.circular(s * 0.1)), Paint()..color = const Color(0xFF2E86DE));
        c.drawRect(Rect.fromLTWH(r.left, r.bottom - s * 0.25, r.width, s * 0.25), Paint()..color = const Color(0xFF6D4C41));
      case TrickLogic.oMatch:
        c.save();
        c.translate(ctr.dx, ctr.dy);
        c.rotate(-0.5);
        c.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset.zero, width: s * 0.18, height: s * 1.7), const Radius.circular(3)),
            Paint()..color = const Color(0xFFE8C98E));
        c.drawCircle(Offset(0, -s * 0.85), s * 0.16, Paint()..color = const Color(0xFFD32F2F));
        if (o.flag == 1) _flame(c, Offset(0, -s * 1.12), s * 0.22);
        c.restore();
      case TrickLogic.oGlass:
        final r = Rect.fromCenter(center: ctr, width: s * 1.2, height: s * 1.7);
        final lvl = (st.level / 1000).clamp(0.0, 1.0);
        final water = Rect.fromLTRB(r.left, r.bottom - r.height * lvl, r.right, r.bottom);
        c.drawRect(water, Paint()..color = const Color(0xAA4FC3F7));
        final ty = r.bottom - r.height * st.p0 / 1000;
        c.drawRect(Rect.fromLTRB(r.left, ty - r.height * st.p2 / 1000, r.right, ty + r.height * st.p2 / 1000),
            Paint()..color = const Color(0x2266BB6A));
        c.drawLine(Offset(r.left - 10, ty), Offset(r.right + 10, ty), Paint()
          ..color = const Color(0xFF2E7D32)
          ..strokeWidth = 3);
        final path = Path()
          ..moveTo(r.left - s * 0.08, r.top)
          ..lineTo(r.left, r.bottom)
          ..lineTo(r.right, r.bottom)
          ..lineTo(r.right + s * 0.08, r.top);
        c.drawPath(path, Paint()
          ..color = const Color(0xFF546E7A)
          ..style = PaintingStyle.stroke
          ..strokeWidth = s * 0.05);
      case TrickLogic.oFaucet:
        c.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: ctr, width: s * 1.6, height: s * 0.5), Radius.circular(s * 0.2)),
            Paint()..color = const Color(0xFF90A4AE));
        c.drawRect(Rect.fromLTWH(ctr.dx - s * 0.15, ctr.dy, s * 0.3, s * 0.55), Paint()..color = const Color(0xFF78909C));
        c.drawCircle(ctr - Offset(0, s * 0.45), s * 0.25, Paint()..color = st.holding ? const Color(0xFF43A047) : const Color(0xFFE53935));
        if (st.holding) {
          c.drawRect(Rect.fromLTWH(ctr.dx - s * 0.08, ctr.dy + s * 0.55, s * 0.16, _scr(500, 820).dy + 0.8 * 230 * _s - ctr.dy - s * 0.55),
              Paint()..color = const Color(0x994FC3F7));
        }
      case TrickLogic.oBalloon:
        if (o.gone) {
          freeText(c, '✦', ctr, s * 0.8, _numColors[o.color % _numColors.length].withValues(alpha: 0.5));
          return;
        }
        c.drawLine(ctr + Offset(0, s * 1.1), ctr + Offset(s * 0.1 * math.sin(_time * 2), s * 2.2), Paint()
          ..color = const Color(0xFF666666)
          ..strokeWidth = 1.5);
        c.drawOval(Rect.fromCenter(center: ctr, width: s * 1.6, height: s * 2.1), Paint()..color = _numColors[o.color % _numColors.length]);
        c.drawOval(Rect.fromCenter(center: ctr - Offset(s * 0.3, s * 0.4), width: s * 0.3, height: s * 0.5), Paint()..color = const Color(0x66FFFFFF));
      case TrickLogic.oDirt:
        final a = (1 - o.flag / 260).clamp(0.0, 1.0);
        c.drawCircle(ctr, s, Paint()..color = const Color(0xFF7A5230).withValues(alpha: 0.75 * a));
        c.drawCircle(ctr + Offset(s * 0.4, -s * 0.3), s * 0.45, Paint()..color = const Color(0xFF5D3A1E).withValues(alpha: 0.8 * a));
      case TrickLogic.oPlate:
        c.drawCircle(ctr + Offset(0, 8 * _s), s, Paint()..color = const Color(0x33000000));
        c.drawCircle(ctr, s, Paint()..color = Colors.white);
        c.drawCircle(ctr, s * 0.72, Paint()
          ..color = const Color(0xFFE3E7EC)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4);
      case TrickLogic.oBell:
        final shake = o.flag > 0 ? math.sin(_time * 40) * 0.08 * math.max(0, 1 - (_time % 1)) : 0.0;
        c.save();
        c.translate(ctr.dx, ctr.dy);
        c.rotate(shake);
        freeIcon(c, o.icon == 1 ? Icons.alarm_rounded : Icons.notifications_rounded, Offset.zero, s * 1.9,
            o.icon == 1 ? const Color(0xFF8E99A8) : const Color(0xFFFFB300));
        c.restore();
      case TrickLogic.oPan:
        final left = o.icon == 0;
        final beamY = _scr(500, 470).dy;
        if (left) {
          c.drawLine(_scr(500, 470), _scr(500, 900), Paint()
            ..color = const Color(0xFF6D4C41)
            ..strokeWidth = 10 * _s);
          c.drawLine(_scr(230, 470), _scr(770, 470), Paint()
            ..color = const Color(0xFF6D4C41)
            ..strokeWidth = 12 * _s);
        }
        c.drawLine(Offset(ctr.dx, beamY), ctr + Offset(0, s * 0.3), Paint()
          ..color = const Color(0xFF8D6E63)
          ..strokeWidth = 3);
        c.drawArc(Rect.fromCenter(center: ctr + Offset(0, s * 0.35), width: s * 1.8, height: s * 0.8), 0, math.pi, true,
            Paint()..color = const Color(0xFFB0BEC5));
        freeIcon(c, left ? Icons.cloud_rounded : Icons.fitness_center_rounded, ctr - Offset(0, s * 0.15), s * 1.1,
            left ? const Color(0xFFECEFF1) : const Color(0xFF455A64));
        final tag = Rect.fromCenter(center: ctr + Offset(0, s * 1.05), width: s * 0.9, height: s * 0.5);
        c.drawRRect(RRect.fromRectAndRadius(tag, Radius.circular(s * 0.12)), Paint()..color = const Color(0xFFFFF59D));
        freeText(c, '${o.val}', tag.center, s * 0.36, const Color(0xFF263045), bold: true);
    }
  }

  void _flame(Canvas c, Offset at, double s) {
    final f = 1 + 0.12 * math.sin(_time * 18);
    final path = Path()
      ..moveTo(at.dx, at.dy - s * 1.3 * f)
      ..quadraticBezierTo(at.dx + s, at.dy, at.dx, at.dy + s * 0.6)
      ..quadraticBezierTo(at.dx - s, at.dy, at.dx, at.dy - s * 1.3 * f);
    c.drawPath(path, Paint()..color = const Color(0xFFFF9800));
    c.drawCircle(at + Offset(0, s * 0.15), s * 0.3, Paint()..color = const Color(0xFFFFEB3B));
  }

  void _cloud(Canvas c, Offset ctr, double s, Color col) {
    final p = Paint()..color = col;
    c.drawCircle(ctr + Offset(-s * 0.45, s * 0.1), s * 0.5, p);
    c.drawCircle(ctr + Offset(s * 0.45, s * 0.12), s * 0.48, p);
    c.drawCircle(ctr + Offset(0, -s * 0.2), s * 0.62, p);
    c.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: ctr + Offset(0, s * 0.25), width: s * 1.8, height: s * 0.6), Radius.circular(s * 0.3)), p);
  }

  void _cover(Canvas c, Offset ctr, double s, int style) {
    switch (style) {
      case 0:
        final r = Rect.fromCenter(center: ctr, width: s * 1.8, height: s * 1.6);
        c.drawRRect(RRect.fromRectAndRadius(r.shift(Offset(0, 6 * _s)), Radius.circular(s * 0.12)), Paint()..color = const Color(0x33000000));
        c.drawRRect(RRect.fromRectAndRadius(r, Radius.circular(s * 0.12)), Paint()..color = const Color(0xFFC08A55));
        c.drawLine(r.topLeft, r.bottomRight, Paint()
          ..color = const Color(0xFF8D5A32)
          ..strokeWidth = s * 0.08);
        c.drawLine(r.topRight, r.bottomLeft, Paint()
          ..color = const Color(0xFF8D5A32)
          ..strokeWidth = s * 0.08);
      case 1:
        for (final (dx, dy, k) in const [(-0.5, 0.2, 0), (0.5, 0.25, 1), (0.0, -0.25, 2), (-0.2, 0.45, 1), (0.3, -0.1, 0)]) {
          c.drawOval(Rect.fromCenter(center: ctr + Offset(dx * s, dy * s), width: s * 1.1, height: s * 0.75),
              Paint()..color = [const Color(0xFF4CAF50), const Color(0xFF66BB6A), const Color(0xFF8BC34A)][k]);
        }
      case 2:
        _cloud(c, ctr, s, const Color(0xFFF4F7FB));
      default:
        c.drawOval(Rect.fromCenter(center: ctr + Offset(0, 6 * _s), width: s * 1.9, height: s * 1.5), Paint()..color = const Color(0x33000000));
        c.drawOval(Rect.fromCenter(center: ctr, width: s * 1.9, height: s * 1.5), Paint()..color = const Color(0xFF9E9E9E));
        c.drawOval(Rect.fromCenter(center: ctr - Offset(s * 0.3, s * 0.25), width: s * 0.6, height: s * 0.35), Paint()..color = const Color(0x55FFFFFF));
    }
  }

  void _creature(Canvas c, Offset ctr, double s, int kind, bool awake) {
    final col = [const Color(0xFFFFA94D), const Color(0xFF9775FA), const Color(0xFF69DB7C)][kind % 3];
    c.drawOval(Rect.fromCenter(center: ctr + Offset(0, s * 0.2), width: s * 1.9, height: s * 1.4), Paint()..color = col);
    for (final dx in [-0.55, 0.55]) {
      final ear = Path()
        ..moveTo(ctr.dx + dx * s - s * 0.25, ctr.dy - s * 0.3)
        ..lineTo(ctr.dx + dx * s, ctr.dy - s * 0.85)
        ..lineTo(ctr.dx + dx * s + s * 0.25, ctr.dy - s * 0.3)
        ..close();
      c.drawPath(ear, Paint()..color = col);
    }
    final eye = Paint()
      ..color = const Color(0xFF263045)
      ..strokeWidth = s * 0.08
      ..strokeCap = StrokeCap.round;
    for (final dx in [-0.35, 0.35]) {
      final e = ctr + Offset(dx * s, 0);
      if (awake) {
        c.drawCircle(e, s * 0.13, eye);
      } else {
        c.drawLine(e - Offset(s * 0.14, 0), e + Offset(s * 0.14, 0), eye);
      }
    }
    if (awake) {
      c.drawArc(Rect.fromCenter(center: ctr + Offset(0, s * 0.3), width: s * 0.5, height: s * 0.3), 0, math.pi, false,
          eye..style = PaintingStyle.stroke);
    } else {
      freeText(c, 'z Z', ctr + Offset(s * 0.9, -s * 0.9 - 6 * math.sin(_time * 2)), s * 0.4, const Color(0xFF5C6BC0), bold: true);
    }
  }

  void _paintGhost(Canvas c) {
    final g = _ghost;
    if (g == null) return;
    final ph = (_ghostT % 1.6) / 1.6;
    Offset at;
    switch (g[0].toInt()) {
      case 1:
        at = Offset.lerp(_scr(g[1].toDouble(), g[2].toDouble()), _scr(g[3].toDouble(), g[4].toDouble()), Curves.easeInOut.transform(ph))!;
      case 3:
        at = _scr(g[1].toDouble() + math.sin(ph * math.pi * 6) * g[3].toDouble(), g[2].toDouble());
      default:
        at = _scr(g[1].toDouble(), g[2].toDouble());
    }
    final r = (g[0] == 2 ? 30 + 20 * ph : 28 + 10 * math.sin(ph * math.pi * 2).abs()) * _s * 2;
    c.drawCircle(at, r, Paint()..color = const Color(0x55FFD447));
    c.drawCircle(at, r, Paint()
      ..color = const Color(0xFFFFB300)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4);
    freeIcon(c, Icons.touch_app_rounded, at + Offset(r * 0.4, r * 0.6), r * 1.2, const Color(0xFF263045));
  }

  // ---- kayıt
  @override
  Map<String, Object?> save() => {
        'o': [
          for (final o in st.objs) [o.x, o.y, o.gone ? 1 : 0, o.flag]
        ],
        'n': st.objs.length,
        'c': st.count,
        'l': st.level,
        'ni': st.night,
        'w': st.won ? 1 : 0,
        'lo': st.lost ? 1 : 0,
        'm': moves,
        'h': _hintStep,
      };

  @override
  void load(Map<String, Object?> j) {
    final s = TrickState(lv);
    final list = j['o'] as List;
    // Kutudan çıkan yiyecek gibi sonradan eklenen nesneler.
    while (s.objs.length < list.length) {
      final box = s.objs.firstWhere((o) => o.kind == TrickLogic.oBox && o.icon == 1, orElse: () => s.objs.first);
      s.objs.add(TObj(TrickLogic.oFood, 0, box.x, box.y - 10, 70, 0, 0, true, 0));
    }
    for (var i = 0; i < list.length; i++) {
      final e = list[i] as List;
      final o = s.objs[i];
      o.x = (e[0] as num).toDouble();
      o.y = (e[1] as num).toDouble();
      o.gone = e[2] == 1;
      o.flag = (e[3] as num).toInt();
    }
    s.count = (j['c'] as num).toInt();
    s.level = (j['l'] as num).toDouble();
    s.night = (j['ni'] as num).toInt();
    s.won = j['w'] == 1;
    s.lost = j['lo'] == 1;
    st = s;
    moves = (j['m'] as num).toInt();
    _hintStep = (j['h'] as num?)?.toInt() ?? _hintStep;
    _ghost = null;
  }
}
