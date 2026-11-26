import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../texts.dart';
import 'free_paint.dart';
import 'free_view.dart';
import 'pin_logic.dart';

/// Pim Çekme oyunu: bir pime dokun (ya da sağa kaydır), pim çekilir ve
/// toplar akar. Renkli topları kavanoza indir; mürekkebi uzak tut.
class PinGame extends FreeGame {
  late PinSim sim;
  int _pulling = -1;
  double _pullT = 0, _acc = 0;
  int _hintPin = -1;
  double _hintT = 0;
  static const _stepDt = 1 / 32;

  PinGame(super.lv) {
    sim = PinSim(lv)..settle();
    for (var i = 0; i < sim.prev.length; i++) {
      sim.prev[i] = sim.cell[i];
    }
  }

  @override
  bool get won => sim.won;

  @override
  bool get lost => sim.lost;

  @override
  bool get busy => _pulling >= 0 || !sim.settled;

  @override
  bool get hintChanges => false;

  @override
  String status(String lang) => '${bt(lang, 'target')}: ${math.max(0, sim.cupColor)} / ${sim.tgt}';

  // ---- yerleşim
  double _cs = 10;
  Offset _o = Offset.zero;

  void _layout() {
    _cs = math.min(size.width * 0.94 / sim.w, size.height * 0.97 / sim.h);
    _o = Offset((size.width - _cs * sim.w) / 2, (size.height - _cs * sim.h) / 2);
  }

  Rect _cell(int i) => Rect.fromLTWH(_o.dx + (i % sim.w) * _cs, _o.dy + (i ~/ sim.w) * _cs, _cs, _cs);

  Rect _pinRect(int k) {
    Rect? r;
    for (var i = 0; i < sim.g.length; i++) {
      if (sim.g[i] == k) r = r == null ? _cell(i) : r.expandToInclude(_cell(i));
    }
    return r ?? Rect.zero;
  }

  int _pinAt(Offset p) {
    for (final k in sim.pinsLeft) {
      final r = _pinRect(k);
      if (r.inflate(_cs * 0.45).contains(p) || Rect.fromLTWH(r.right, r.top - _cs * 0.3, _cs * 1.2, r.height + _cs * 0.6).contains(p)) return k;
    }
    return -1;
  }

  @override
  bool down(Offset p) {
    if (_pulling >= 0) return false;
    _layout();
    final k = _pinAt(p);
    if (k < 0) return false;
    _pulling = k;
    _pullT = 0;
    _hintPin = -1;
    moves++;
    return true;
  }

  @override
  bool hint() {
    if (busy) return false;
    final s = PinLogic.solveFrom(sim);
    if (s == null || s.isEmpty) return false;
    _hintPin = s.first;
    _hintT = 0;
    return true;
  }

  @override
  bool step(double dt) {
    var anim = false;
    if (_hintPin >= 0) {
      _hintT += dt;
      anim = true;
    }
    if (_pulling >= 0) {
      _pullT += dt / 0.28;
      if (_pullT >= 1) {
        sim.pull(_pulling);
        _pulling = -1;
        _acc = 0;
      }
      return true;
    }
    if (!sim.settled) {
      _acc += dt;
      while (_acc >= _stepDt && !sim.settled) {
        _acc -= _stepDt;
        sim.step();
      }
      anim = true;
    }
    return anim;
  }

  // ---- çizim
  static const _ball = [Color(0xFFFF6B6B), Color(0xFFFFC145), Color(0xFF4DD4AC), Color(0xFF5DA9FF), Color(0xFFC77DFF)];

  @override
  void paint(Canvas c, Size size, FPalette p, double t) {
    this.size = size;
    _layout();
    final board = Rect.fromLTWH(_o.dx, _o.dy, _cs * sim.w, _cs * sim.h);
    c.drawRRect(RRect.fromRectAndRadius(board, Radius.circular(_cs * 0.5)), Paint()..color = const Color(0xFF6E5A4B));
    c.drawRRect(RRect.fromRectAndRadius(board.deflate(_cs * 0.12), Radius.circular(_cs * 0.42)), Paint()..color = const Color(0xFF8A7360));
    final glass = Paint()..color = const Color(0xFF1E2A3A);
    for (var i = 0; i < sim.g.length; i++) {
      if (sim.g[i] < 0) continue;
      c.drawRect(_cell(i).inflate(0.6), glass);
    }
    // kavanoz
    Rect? jar;
    for (final i in sim.cupCells) {
      jar = jar == null ? _cell(i) : jar.expandToInclude(_cell(i));
    }
    if (jar != null) {
      final jr = RRect.fromRectAndCorners(jar.inflate(_cs * 0.08), bottomLeft: Radius.circular(_cs * 0.6), bottomRight: Radius.circular(_cs * 0.6));
      c.drawRRect(jr, Paint()..color = const Color(0xFF26405A));
      c.drawRRect(jr, Paint()
        ..color = const Color(0xCCBFE7FF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = _cs * 0.14);
      final lineY = jar.bottom - (sim.tgt / (sim.cupCells.length)) * jar.height;
      dashLine(c, Offset(jar.left + 4, lineY), Offset(jar.right - 4, lineY), Paint()
        ..color = const Color(0x88FFFFFF)
        ..strokeWidth = 2);
    }
    // toplar
    final f = (_acc / _stepDt).clamp(0.0, 1.0);
    final settled = sim.settled;
    for (var id = 0; id < sim.type.length; id++) {
      final a = _cell(sim.prev[id]).center, b = _cell(sim.cell[id]).center;
      final pos = settled ? b : Offset.lerp(a, b, f)!;
      _paintBall(c, pos, sim.type[id], id, p);
    }
    // pimler
    for (final k in sim.pinsLeft) {
      final r = _pinRect(k);
      final dx = k == _pulling ? Curves.easeIn.transform(_pullT.clamp(0.0, 1.0)) * (r.width + _cs * 1.5) : 0.0;
      final bar = Rect.fromLTWH(r.left - _cs * 0.15 + dx, r.center.dy - _cs * 0.16, r.width + _cs * 0.6, _cs * 0.32);
      c.drawRRect(RRect.fromRectAndRadius(bar.shift(const Offset(0, 2)), Radius.circular(_cs * 0.16)), Paint()..color = const Color(0x66000000));
      c.drawRRect(
          RRect.fromRectAndRadius(bar, Radius.circular(_cs * 0.16)),
          Paint()
            ..shader = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFF2F4F7), Color(0xFF9AA3AF)])
                .createShader(bar));
      final knob = Offset(bar.right + _cs * 0.18, bar.center.dy);
      final hl = k == _hintPin && (_hintT * 3).floor().isEven;
      c.drawCircle(knob, _cs * 0.36, Paint()..color = hl ? const Color(0xFFFFD447) : const Color(0xFFE85D4A));
      c.drawCircle(knob, _cs * 0.36, Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2);
      if (k == _hintPin) freeText(c, '→', knob + Offset(_cs * 0.7, 0), _cs * 0.6, const Color(0xFFFFD447), bold: true);
    }
  }

  void _paintBall(Canvas c, Offset o, int type, int id, FPalette p) {
    final r = _cs * 0.46;
    switch (type) {
      case PinLogic.tColor:
        final col = _ball[id % _ball.length];
        c.drawCircle(o, r, Paint()..color = col);
        c.drawCircle(o - Offset(r * 0.3, r * 0.3), r * 0.28, Paint()..color = Colors.white.withValues(alpha: 0.45));
        if (p.colorBlind) freeText(c, '★', o, r * 0.9, Colors.white);
      case PinLogic.tGray:
        c.drawCircle(o, r, Paint()..color = const Color(0xFFB9BEC6));
        c.drawCircle(o - Offset(r * 0.3, r * 0.3), r * 0.25, Paint()..color = Colors.white.withValues(alpha: 0.4));
      case PinLogic.tInk:
        c.drawCircle(o, r * 1.02, Paint()..color = const Color(0xFF231B3B));
        c.drawCircle(o + Offset(r * 0.25, -r * 0.2), r * 0.22, Paint()..color = const Color(0xFF6C5BA8));
        if (p.colorBlind) freeText(c, '✖', o, r * 0.8, Colors.white70);
      case PinLogic.tWater:
        c.drawCircle(o, r, Paint()..color = const Color(0xCC7FD3FF));
        c.drawCircle(o - Offset(r * 0.25, r * 0.3), r * 0.22, Paint()..color = Colors.white.withValues(alpha: 0.7));
      default:
        c.drawRRect(RRect.fromRectAndRadius(Rect.fromCircle(center: o, radius: r * 0.92), Radius.circular(r * 0.4)),
            Paint()..color = const Color(0xFF8D8478));
    }
  }

  // ---- kayıt
  @override
  Map<String, Object?> save() => {
        'pl': sim.pinsLeft.toList()..sort(),
        'c': List.of(sim.cell),
        't': List.of(sim.type),
        'st': sim.steps,
        'm': moves,
      };

  @override
  void load(Map<String, Object?> j) {
    List<int> l(Object? o) => [for (final v in (o as List)) (v as num).toInt()];
    final s = PinSim(lv);
    final pl = l(j['pl']).toSet();
    for (final k in s.pinsLeft.toList()) {
      if (!pl.contains(k)) s.pull(k);
    }
    s.at.fillRange(0, s.at.length, -1);
    s.cell = l(j['c']);
    s.type = l(j['t']);
    for (var id = 0; id < s.cell.length; id++) {
      s.at[s.cell[id]] = id;
    }
    s.prev = List.of(s.cell);
    final steps = (j['st'] as num).toInt();
    s.steps = steps;
    s.settle();
    s.steps = steps;
    s.prev = List.of(s.cell);
    sim = s;
    moves = (j['m'] as num).toInt();
    _pulling = -1;
    _hintPin = -1;
  }
}
