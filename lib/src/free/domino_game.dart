import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../texts.dart';
import 'domino_logic.dart';
import 'free_paint.dart';
import 'free_view.dart';

/// Domino Koşulları oyunu: alttaki tepsiden dominoları sürükle ya da seçip
/// tahtaya dokun; seçili dominoya yeniden dokunmak döndürür; tahtadaki
/// dominoya dokunmak tepsiye geri alır.
class DominoGame extends FreeGame {
  late final int w, h, nd;
  late final List<int> m, reg, dom, sol, pair;
  late final List<List<int>> rc;

  /// Domino başına bağlama hücresi (-1 tepside) ve yönü (0..3).
  late List<int> place, orient;
  int sel = -1;

  // sürükleme
  int _drag = -1;
  bool _fromBoard = false, _moved = false;
  Offset _p0 = Offset.zero, _pos = Offset.zero;
  double _flash = 0;

  DominoGame(super.lv) {
    w = lv.i('w');
    h = lv.i('h');
    m = lv.ints('m');
    reg = lv.ints('reg');
    dom = lv.ints('dom');
    sol = lv.ints('sol');
    pair = lv.ints('pair');
    rc = DominoLogic.rcOf(lv);
    nd = dom.length ~/ 2;
    place = List.filled(nd, -1);
    orient = List.filled(nd, 0);
  }

  // ---- model
  (int, int) cellsOf(int k, int anchor, int o) => (anchor, o.isEven ? anchor + 1 : anchor + w);
  (int, int) valsOf(int k, int o) => o < 2 ? (dom[2 * k], dom[2 * k + 1]) : (dom[2 * k + 1], dom[2 * k]);

  List<int> get values {
    final v = List.filled(w * h, -1);
    for (var k = 0; k < nd; k++) {
      if (place[k] < 0) continue;
      final (a, b) = cellsOf(k, place[k], orient[k]);
      final (va, vb) = valsOf(k, orient[k]);
      v[a] = va;
      v[b] = vb;
    }
    return v;
  }

  int occupant(int cell) {
    for (var k = 0; k < nd; k++) {
      if (place[k] < 0) continue;
      final (a, b) = cellsOf(k, place[k], orient[k]);
      if (a == cell || b == cell) return k;
    }
    return -1;
  }

  bool canPlace(int k, int anchor, int o) {
    if (anchor < 0 || anchor >= w * h) return false;
    if (o.isEven && anchor % w == w - 1) return false;
    final (a, b) = cellsOf(k, anchor, o);
    if (b >= w * h || m[a] == 0 || m[b] == 0) return false;
    final oa = occupant(a), ob = occupant(b);
    return (oa < 0 || oa == k) && (ob < 0 || ob == k);
  }

  @override
  bool get won => place.every((p) => p >= 0) && DominoLogic.allOk(lv, values);

  @override
  String status(String lang) => '${bt(lang, 'left')}: ${place.where((p) => p < 0).length}';

  // ---- yerleşim
  late Rect _board;
  late double _cs, _slot;
  int _minX = 0, _minY = 0;

  void _layout() {
    var minX = w, maxX = 0, minY = h, maxY = 0;
    for (var i = 0; i < w * h; i++) {
      if (m[i] == 0) continue;
      minX = math.min(minX, i % w);
      maxX = math.max(maxX, i % w);
      minY = math.min(minY, i ~/ w);
      maxY = math.max(maxY, i ~/ w);
    }
    _minX = minX;
    _minY = minY;
    final bw = maxX - minX + 1, bh = maxY - minY + 1;
    final areaH = size.height * 0.62;
    _cs = math.min(math.min(size.width * 0.92 / bw, areaH * 0.9 / bh), 84);
    _board = Rect.fromCenter(center: Offset(size.width / 2, areaH / 2 + 4), width: bw * _cs, height: bh * _cs);
    final perRow = math.min(nd, 7);
    final rows = (nd / perRow).ceil();
    _slot = math.min(size.width / perRow, size.height * 0.36 / rows);
  }

  Rect cellRect(int i) => Rect.fromLTWH(_board.left + (i % w - _minX) * _cs, _board.top + (i ~/ w - _minY) * _cs, _cs, _cs);

  int? cellAt(Offset p) {
    if (!_board.contains(p)) return null;
    final x = ((p.dx - _board.left) / _cs).floor() + _minX, y = ((p.dy - _board.top) / _cs).floor() + _minY;
    if (x < 0 || y < 0 || x >= w || y >= h) return null;
    final i = y * w + x;
    return m[i] == 1 ? i : null;
  }

  Rect slotRect(int k) {
    final perRow = math.min(nd, 7);
    final rows = (nd / perRow).ceil();
    final row = k ~/ perRow, col = k % perRow;
    final inRow = row == rows - 1 ? nd - perRow * row : perRow;
    final top = size.height * 0.63 + (size.height * 0.37 - rows * _slot) / 2;
    return Rect.fromLTWH((size.width - inRow * _slot) / 2 + col * _slot, top + row * _slot, _slot, _slot);
  }

  int _slotAt(Offset p) {
    for (var k = 0; k < nd; k++) {
      if (place[k] < 0 && slotRect(k).contains(p)) return k;
    }
    return -1;
  }

  // ---- giriş
  @override
  bool down(Offset p) {
    _layout();
    _moved = false;
    _p0 = p;
    _pos = p;
    final k = _slotAt(p);
    if (k >= 0) {
      _drag = k;
      _fromBoard = false;
      return true;
    }
    final c = cellAt(p);
    if (c == null) return false;
    final occ = occupant(c);
    if (occ >= 0) {
      _drag = occ;
      _fromBoard = true;
      return true;
    }
    if (sel >= 0) return _tryPlaceAt(sel, c);
    return false;
  }

  bool _tryPlaceAt(int k, int c) {
    final o = orient[k];
    for (final anchor in [c, o.isEven ? c - 1 : c - w]) {
      if (canPlace(k, anchor, o)) {
        place[k] = anchor;
        moves++;
        sel = -1;
        return true;
      }
    }
    _flash = 0.4;
    return true;
  }

  @override
  bool move(Offset p) {
    if (_drag < 0) return false;
    _pos = p;
    if ((p - _p0).distance > 10) _moved = true;
    return true;
  }

  @override
  bool up(Offset p) {
    if (_drag < 0) return false;
    final k = _drag;
    _drag = -1;
    if (!_moved) {
      if (_fromBoard) {
        place[k] = -1;
        sel = k;
        moves++;
      } else if (sel == k) {
        orient[k] = (orient[k] + 1) % 4;
      } else {
        sel = k;
      }
      return true;
    }
    // Bırakma: ilk yarının merkezi parmağın biraz solunda/üstünde.
    final o = orient[k];
    final first = o.isEven ? _pos - Offset(_cs / 2, 0) : _pos - Offset(0, _cs / 2);
    final c = cellAt(first);
    final was = place[k];
    if (c != null && canPlace(k, c, o)) {
      place[k] = c;
      if (c != was) moves++;
      if (sel == k) sel = -1;
      return true;
    }
    if (_fromBoard) {
      place[k] = -1;
      moves++;
    }
    return true;
  }

  // ---- ipucu: çözümden bir dominoyu yerine koy
  @override
  bool hint() {
    final cur = values;
    for (var i = 0; i < w * h; i++) {
      if (m[i] == 0) continue;
      final j = pair[i];
      if (j < i) continue;
      if (cur[i] == sol[i] && cur[j] == sol[j] && occupant(i) == occupant(j) && occupant(i) >= 0) continue;
      final lo = math.min(sol[i], sol[j]), hi = math.max(sol[i], sol[j]);
      var k = -1;
      for (var q = 0; q < nd; q++) {
        if (dom[2 * q] == lo && dom[2 * q + 1] == hi) k = q;
      }
      if (k < 0) return false;
      for (final c in [i, j]) {
        final o = occupant(c);
        if (o >= 0) place[o] = -1;
      }
      place[k] = -1;
      final horiz = j == i + 1;
      final o = horiz ? (sol[i] == dom[2 * k] ? 0 : 2) : (sol[i] == dom[2 * k] ? 1 : 3);
      orient[k] = o;
      place[k] = i;
      moves++;
      sel = -1;
      return true;
    }
    return false;
  }

  @override
  bool step(double dt) {
    if (_flash > 0) _flash = math.max(0, _flash - dt);
    return _flash > 0;
  }

  // ---- çizim
  static const _tints = [
    Color(0xFFF4A261), Color(0xFF8AB17D), Color(0xFF7FB7E6), Color(0xFFE76F51), Color(0xFFB392F0),
    Color(0xFFE9C46A), Color(0xFF5FC9B8), Color(0xFFF28FB3), Color(0xFF9AA7FF), Color(0xFFC9A66B),
  ];

  String _badge(List<int> c) => switch (c[0]) {
        DominoLogic.cSum => '${c[1]}',
        DominoLogic.cEq => '=',
        DominoLogic.cDiff => '≠',
        DominoLogic.cLess => '<${c[1]}',
        _ => '>${c[1]}',
      };

  @override
  void paint(Canvas c, Size size, FPalette p, double t) {
    this.size = size;
    _layout();
    final v = values;
    // Tahta zemini
    c.drawRRect(RRect.fromRectAndRadius(_board.inflate(_cs * 0.18), Radius.circular(_cs * 0.3)), Paint()..color = const Color(0x33000000));
    for (var i = 0; i < w * h; i++) {
      if (m[i] == 0) continue;
      final r = cellRect(i).deflate(1.5);
      final id = reg[i];
      final col = id < 0 ? const Color(0xFFEDE6D8) : Color.lerp(_tints[id % _tints.length], Colors.white, 0.35)!;
      c.drawRRect(RRect.fromRectAndRadius(r, Radius.circular(_cs * 0.14)), Paint()..color = col);
      if (id >= 0) {
        // bölge sınırları (kesikli)
        final edge = Paint()
          ..color = _tints[id % _tints.length].withValues(alpha: 0.95)
          ..strokeWidth = math.max(2, _cs * 0.05)
          ..style = PaintingStyle.stroke;
        final x = i % w;
        final cr = cellRect(i).deflate(_cs * 0.06);
        if (x == 0 || reg[i - 1] != id) dashLine(c, cr.topLeft, cr.bottomLeft, edge);
        if (x == w - 1 || reg[i + 1] != id) dashLine(c, cr.topRight, cr.bottomRight, edge);
        if (i < w || reg[i - w] != id) dashLine(c, cr.topLeft, cr.topRight, edge);
        if (i + w >= w * h || reg[i + w] != id) dashLine(c, cr.bottomLeft, cr.bottomRight, edge);
      }
    }
    // dominolar
    for (var k = 0; k < nd; k++) {
      if (place[k] < 0 || (k == _drag && _moved)) continue;
      final (a, b) = cellsOf(k, place[k], orient[k]);
      final (va, vb) = valsOf(k, orient[k]);
      paintDomino(c, cellRect(a).expandToInclude(cellRect(b)).deflate(_cs * 0.07), va, vb, orient[k].isOdd);
    }
    // bölge rozetleri (dominoların üstünde)
    for (var id = 0; id < rc.length; id++) {
      var first = -1, left = 0;
      final vals = <int>[];
      for (var i = 0; i < w * h; i++) {
        if (reg[i] != id) continue;
        if (first < 0) first = i;
        if (v[i] < 0) {
          left++;
        } else {
          vals.add(v[i]);
        }
      }
      if (first < 0) continue;
      final ok = DominoLogic.regionOk(rc[id], vals, left);
      final done = left == 0;
      final r = cellRect(first);
      final txt = _badge(rc[id]);
      final bw = _cs * (0.34 + 0.13 * txt.length);
      final br = RRect.fromRectAndRadius(Rect.fromLTWH(r.left - _cs * 0.12, r.top - _cs * 0.14, bw, _cs * 0.4), Radius.circular(_cs * 0.2));
      c.drawRRect(br, Paint()..color = done ? (ok ? const Color(0xFF2E9E5B) : const Color(0xFFD64545)) : (!ok ? const Color(0xFFD64545) : _tints[id % _tints.length]));
      c.drawRRect(br, Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6);
      freeText(c, txt, br.outerRect.center, _cs * 0.26, Colors.white, bold: true);
    }
    // tepsi
    for (var k = 0; k < nd; k++) {
      final s = slotRect(k);
      c.drawRRect(RRect.fromRectAndRadius(s.deflate(4), Radius.circular(_slot * 0.16)), Paint()..color = const Color(0x22FFFFFF));
      if (place[k] >= 0 || (k == _drag && _moved)) continue;
      final o = orient[k];
      final u = _slot * 0.36;
      final r = Rect.fromCenter(center: s.center, width: o.isEven ? 2 * u : u, height: o.isEven ? u : 2 * u);
      if (sel == k) {
        c.drawRRect(RRect.fromRectAndRadius(r.inflate(5), Radius.circular(u * 0.3)), Paint()..color = p.accent.withValues(alpha: 0.85));
      }
      final (va, vb) = valsOf(k, o);
      paintDomino(c, r, va, vb, o.isOdd);
      if (sel == k) freeText(c, '⟳', Offset(s.right - _slot * 0.14, s.top + _slot * 0.16), _slot * 0.18, Colors.white70);
    }
    // sürüklenen
    if (_drag >= 0 && _moved) {
      final o = orient[_drag];
      final r = Rect.fromCenter(center: _pos, width: o.isEven ? 2 * _cs : _cs, height: o.isEven ? _cs : 2 * _cs).deflate(_cs * 0.07);
      final (va, vb) = valsOf(_drag, o);
      paintDomino(c, r.shift(const Offset(0, -6)), va, vb, o.isOdd, lifted: true);
    }
    if (_flash > 0) {
      c.drawRRect(RRect.fromRectAndRadius(_board.inflate(_cs * 0.2), Radius.circular(_cs * 0.3)),
          Paint()
            ..color = const Color(0xFFD64545).withValues(alpha: _flash)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 4);
    }
  }

  // ---- kayıt
  @override
  Map<String, Object?> save() => {'p': List.of(place), 'o': List.of(orient), 'm': moves, 's': sel};

  @override
  void load(Map<String, Object?> j) {
    List<int> l(Object? o) => [for (final v in (o as List)) (v as num).toInt()];
    place = l(j['p']);
    orient = l(j['o']);
    moves = (j['m'] as num).toInt();
    sel = (j['s'] as num?)?.toInt() ?? -1;
    _drag = -1;
  }
}
