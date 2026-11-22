import 'dart:math' as math;
import 'dart:ui';

import 'package:studio_core/core/rng.dart';

import 'core.dart';
import 'digits.dart';
import 'move1.dart';

// ======================================================================
// Tangram (çeyrek üçgen kafesi)

/// Yedi parçayla gölgeyi doldur. Parça: (x, y, q) çeyrek üçgenleri
/// (q: 0 üst, 1 sağ, 2 alt, 3 sol). Alttaki tepsiden parça seç, gölgede
/// bir hücreye dokunarak yerleştir; uzun basma döndürür, üstteki düğmeler
/// döndürür/çevirir. Yerleşmiş parçaya dokunmak onu geri alır.
/// extra[0]: gölge (hücre başına 4 bit), extra[1]: çözüm yerleşimi.
/// aux: [seçili, (yerleşti, x, y, dönme, ayna) × 7].
class TangramKind extends MoveKind {
  const TangramKind();
  @override
  String get id => 'tangram';

  static const _polys = [
    [(0.0, 0.0), (4.0, 0.0), (2.0, 2.0)],
    [(0.0, 0.0), (2.0, 2.0), (0.0, 4.0)],
    [(4.0, 2.0), (4.0, 4.0), (2.0, 4.0)],
    [(4.0, 0.0), (4.0, 2.0), (3.0, 1.0)],
    [(2.0, 2.0), (3.0, 3.0), (1.0, 3.0)],
    [(2.0, 2.0), (3.0, 1.0), (4.0, 2.0), (3.0, 3.0)],
    [(0.0, 4.0), (1.0, 3.0), (3.0, 3.0), (2.0, 4.0)],
  ];

  static bool _inside(List<(double, double)> poly, double px, double py) {
    var ins = false;
    for (var i = 0, j = poly.length - 1; i < poly.length; j = i++) {
      final (xi, yi) = poly[i];
      final (xj, yj) = poly[j];
      if ((yi > py) != (yj > py) && px < (xj - xi) * (py - yi) / (yj - yi) + xi) ins = !ins;
    }
    return ins;
  }

  static const _qc = [(0.5, 0.17), (0.83, 0.5), (0.5, 0.83), (0.17, 0.5)];

  /// Parçaların temel biçimleri (normalleştirilmiş).
  static final List<List<(int, int, int)>> shapes = [
    for (final poly in _polys)
      _norm([
        for (var y = 0; y < 4; y++)
          for (var x = 0; x < 4; x++)
            for (var q = 0; q < 4; q++)
              if (_inside(poly, x + _qc[q].$1, y + _qc[q].$2)) (x, y, q)
      ])
  ];

  static List<(int, int, int)> _norm(List<(int, int, int)> s) {
    final mx = s.map((e) => e.$1).reduce(math.min), my = s.map((e) => e.$2).reduce(math.min);
    return [for (final (x, y, q) in s) (x - mx, y - my, q)];
  }

  static List<(int, int, int)> oriented(int piece, int rot, int flip) {
    var s = shapes[piece];
    if (flip == 1) s = _norm([for (final (x, y, q) in s) (-x - 1, y, q == 1 ? 3 : (q == 3 ? 1 : q))]);
    for (var k = 0; k < rot; k++) {
      s = _norm([for (final (x, y, q) in s) (-y - 1, x, (q + 1) % 4)]);
    }
    return s;
  }

  static (int, int) dims(List<(int, int, int)> s) => (s.map((e) => e.$1).reduce(math.max) + 1, s.map((e) => e.$2).reduce(math.max) + 1);

  int _base(int k) => 1 + k * 5;

  @override
  PState initial(PLevel lv) => PState(List.filled(lv.n, 0), List.filled(lv.linkCount, 0), List.filled(lv.borderCount, 0), [0, for (var k = 0; k < 7; k++) ...[0, 0, 0, 0, 0]]);

  /// Durumdaki dolu çeyrekler (hücre başına maske) ve sahipleri.
  List<int> occupancy(PLevel lv, PState s, {int skip = -1}) {
    final occ = List.filled(lv.n, 0);
    for (var k = 0; k < 7; k++) {
      if (k == skip) continue;
      final b = _base(k);
      if (s.aux[b] != 1) continue;
      for (final (x, y, q) in oriented(k, s.aux[b + 3], s.aux[b + 4])) {
        final cx = s.aux[b + 1] + x, cy = s.aux[b + 2] + y;
        if (cx >= 0 && cy >= 0 && cx < lv.w && cy < lv.h) occ[cy * lv.w + cx] |= 1 << q;
      }
    }
    return occ;
  }

  bool _fits(PLevel lv, PState s, int k, int ax, int ay) {
    final b = _base(k);
    final occ = occupancy(lv, s, skip: k);
    for (final (x, y, q) in oriented(k, s.aux[b + 3], s.aux[b + 4])) {
      final cx = ax + x, cy = ay + y;
      if (cx < 0 || cy < 0 || cx >= lv.w || cy >= lv.h) return false;
      final i = cy * lv.w + cx;
      if (lv.extra[0][i] & (1 << q) == 0 || occ[i] & (1 << q) != 0) return false;
    }
    return true;
  }

  int _pieceAt(PLevel lv, PState s, int i) {
    for (var k = 0; k < 7; k++) {
      final b = _base(k);
      if (s.aux[b] != 1) continue;
      for (final (x, y, _) in oriented(k, s.aux[b + 3], s.aux[b + 4])) {
        if ((s.aux[b + 2] + y) * lv.w + s.aux[b + 1] + x == i) return k;
      }
    }
    return -1;
  }

  @override
  bool act(PLevel lv, PState s, int i) {
    final hit = _pieceAt(lv, s, i);
    if (hit >= 0) {
      s.aux[_base(hit)] = 0;
      s.aux[0] = hit;
      return true;
    }
    final k = s.aux[0];
    if (k < 0 || s.aux[_base(k)] == 1) return false;
    final b = _base(k);
    final (pw, ph) = dims(oriented(k, s.aux[b + 3], s.aux[b + 4]));
    // dokunulan hücre parçanın ortasına gelsin; olmazsa yakın konumlar
    for (final (ox, oy) in [(pw ~/ 2, ph ~/ 2), (0, 0), (pw - 1, 0), (0, ph - 1), (pw - 1, ph - 1), (pw ~/ 2, 0), (0, ph ~/ 2)]) {
      final ax = i % lv.w - ox, ay = i ~/ lv.w - oy;
      if (_fits(lv, s, k, ax, ay)) {
        s.aux[b] = 1;
        s.aux[b + 1] = ax;
        s.aux[b + 2] = ay;
        s.aux[0] = _nextFree(s, k);
        return true;
      }
    }
    return false;
  }

  int _nextFree(PState s, int from) {
    for (var d = 1; d <= 7; d++) {
      final k = (from + d) % 7;
      if (s.aux[_base(k)] == 0) return k;
    }
    return -1;
  }

  @override
  bool dragMove(PLevel lv, PState s, int from, int to) {
    final k = _pieceAt(lv, s, from);
    if (k < 0) return false;
    final b = _base(k);
    final ax = s.aux[b + 1] + to % lv.w - from % lv.w, ay = s.aux[b + 2] + to ~/ lv.w - from ~/ lv.w;
    if (!_fits(lv, s, k, ax, ay)) return false;
    s.aux[b + 1] = ax;
    s.aux[b + 2] = ay;
    return true;
  }

  bool _turn(PState s, int k, bool flip) {
    if (k < 0) return false;
    final b = _base(k);
    if (s.aux[b] == 1) return false;
    if (flip) {
      s.aux[b + 4] = 1 - s.aux[b + 4];
    } else {
      s.aux[b + 3] = (s.aux[b + 3] + 1) % 4;
    }
    return true;
  }

  @override
  bool actAlt(PLevel lv, PState s, int i) {
    final hit = _pieceAt(lv, s, i);
    if (hit >= 0) {
      s.aux[_base(hit)] = 0;
      s.aux[0] = hit;
    }
    return _turn(s, s.aux[0], false);
  }

  @override
  bool actOutside(PLevel lv, PState s, int side, int index) {
    if (side == 0) return _turn(s, s.aux[0], index >= lv.w ~/ 2);
    if (side == 2) {
      final k = (index * 7 ~/ lv.w).clamp(0, 6);
      if (s.aux[_base(k)] == 1) s.aux[_base(k)] = 0;
      s.aux[0] = k;
      return true;
    }
    return false;
  }

  @override
  bool solved(PLevel lv, PState s) {
    for (var k = 0; k < 7; k++) {
      if (s.aux.length <= _base(k) || s.aux[_base(k)] != 1) return false;
    }
    return true;
  }

  @override
  bool ok(PLevel lv, PState s, bool complete) => true;

  static bool _touch(Map<int, int> occ, int w, int x, int y, int q) {
    // aynı hücrede başka çeyrek ya da ortak kenarlı komşu hücre çeyreği
    final own = occ[y * 64 + x] ?? 0;
    if (own != 0) return true;
    final (dx, dy) = const [(0, -1), (1, 0), (0, 1), (-1, 0)][q];
    final nb = occ[(y + dy) * 64 + x + dx] ?? 0;
    return nb & (1 << ((q + 2) % 4)) != 0;
  }

  @override
  PLevel make(int difficulty, SeededRandom r) {
    for (var attempt = 0; attempt < 200; attempt++) {
      final occ = <int, int>{};
      final place = <(int, int, int, int)>[];
      final order = shuffled(7, r);
      var okAll = true;
      for (var n = 0; n < 7; n++) {
        final k = order[n];
        var done = false;
        for (var t = 0; t < 300 && !done; t++) {
          final rot = r.nextInt(4), flip = k == 6 && r.chance(0.5) ? 1 : 0;
          final sh = oriented(k, rot, flip);
          final ax = n == 0 ? 20 : 12 + r.nextInt(18), ay = n == 0 ? 20 : 12 + r.nextInt(18);
          var clash = false, touch = n == 0;
          for (final (x, y, q) in sh) {
            final key = (ay + y) * 64 + ax + x;
            if ((occ[key] ?? 0) & (1 << q) != 0) {
              clash = true;
              break;
            }
            if (!touch && _touch(occ, 64, ax + x, ay + y, q)) touch = true;
          }
          if (clash || !touch) continue;
          // tek çeyrek değmesi değil, kenar paylaşımı yeterli; kompakt kalsın
          for (final (x, y, q) in sh) {
            final key = (ay + y) * 64 + ax + x;
            occ[key] = (occ[key] ?? 0) | (1 << q);
          }
          place.add((k, ax, ay, rot * 2 + flip));
          done = true;
        }
        if (!done) okAll = false;
      }
      if (!okAll) continue;
      final xs = occ.keys.map((k) => k % 64), ys = occ.keys.map((k) => k ~/ 64);
      final mx = xs.reduce(math.min), my = ys.reduce(math.min);
      final w = xs.reduce(math.max) - mx + 1, h = ys.reduce(math.max) - my + 1;
      if (w > 12 || h > 12) continue;
      final sil = List.filled(w * h, 0);
      for (final e in occ.entries) {
        sil[(e.key ~/ 64 - my) * w + e.key % 64 - mx] = e.value;
      }
      final solution = [for (final (k, ax, ay, rf) in place) ...[k, ax - mx, ay - my, rf ~/ 2, rf % 2]];
      return PLevel(kind: id, w: w, h: h, clues: const [], extra: [sil, solution], solCells: const [], givens: const [], param: difficulty);
    }
    throw StateError('tangram');
  }

  @override
  (double, double, double, double) margins(PLevel lv) => (0.9, 0, 2.2, 0);

  @override
  String outside(PLevel lv, PState s, int side, int index) => side == 0 && (index == 0 || index == lv.w - 1) ? (index == 0 ? '⟳' : '⇋') : '';

  static Color pieceColor(int k) => const [Color(0xFFD1495B), Color(0xFF00798C), Color(0xFFEDAE49), Color(0xFF66A182), Color(0xFF8E6C8A), Color(0xFF3F88C5), Color(0xFFB5651D)][k];

  static Path quarter(Rect r, int q) {
    final p = Path();
    final o = r.center;
    final (a, b) = switch (q) { 0 => (r.topLeft, r.topRight), 1 => (r.topRight, r.bottomRight), 2 => (r.bottomRight, r.bottomLeft), _ => (r.bottomLeft, r.topLeft) };
    p
      ..moveTo(a.dx, a.dy)
      ..lineTo(b.dx, b.dy)
      ..lineTo(o.dx, o.dy)
      ..close();
    return p;
  }

  @override
  void paintOver(Canvas c, PLevel lv, PState s, Rect Function(int i) cell, double cs) {
    for (var i = 0; i < lv.n; i++) {
      final m = lv.extra[0][i];
      for (var q = 0; q < 4; q++) {
        if (m & (1 << q) != 0) c.drawPath(quarter(cell(i), q), Paint()..color = const Color(0xFF3A3548));
      }
    }
    if (lv.param <= 3) {
      // kolay bölümlerde parça sınırları ipucu olarak görünür
      final sol = lv.extra[1];
      for (var k = 0; k + 4 < sol.length; k += 5) {
        for (final (x, y, q) in oriented(sol[k], sol[k + 3], sol[k + 4])) {
          final cx = sol[k + 1] + x, cy = sol[k + 2] + y;
          c.drawPath(
              quarter(cell(cy * lv.w + cx), q),
              Paint()
                ..style = PaintingStyle.stroke
                ..color = const Color(0x22FFFFFF)
                ..strokeWidth = 1);
        }
      }
    }
    if (s.aux.isEmpty) return;
    for (var k = 0; k < 7; k++) {
      final b = _base(k);
      final sh = oriented(k, s.aux[b + 3], s.aux[b + 4]);
      if (s.aux[b] == 1) {
        for (final (x, y, q) in sh) {
          final i = (s.aux[b + 2] + y) * lv.w + s.aux[b + 1] + x;
          c.drawPath(quarter(cell(i), q), Paint()..color = pieceColor(k));
        }
        continue;
      }
      // tepside küçük çizim
      final (pw, ph) = dims(sh);
      final slot = lv.w * cs / 7;
      final scale = math.min(slot / (pw + 0.5), cs * 1.9 / (ph + 0.5));
      final origin = cell((lv.h - 1) * lv.w).bottomLeft + Offset(k * slot + (slot - pw * scale) / 2, cs * 0.2);
      if (s.aux[0] == k) {
        c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(k * slot + cell(0).left, origin.dy - cs * 0.1, slot, cs * 2), Radius.circular(cs * 0.2)), Paint()..color = const Color(0x33EDAE49));
      }
      for (final (x, y, q) in sh) {
        c.drawPath(quarter(Rect.fromLTWH(origin.dx + x * scale, origin.dy + y * scale, scale, scale), q), Paint()..color = pieceColor(k));
      }
    }
  }
}

// ======================================================================
// Yapboz

/// Resim parçaları karışık: iki parçaya dokunarak (ya da sürükleyerek)
/// yer değiştir. İleri bölümlerde parçalar dönük; uzun basma döndürür.
/// Hücre: parça (1..n). aux: dönmeler + seçili.
class JigsawKind extends MoveKind {
  const JigsawKind();
  @override
  String get id => 'yapboz';

  bool rotates(PLevel lv) => lv.extra[1][0] == 1;

  @override
  PState initial(PLevel lv) => PState(List.of(lv.extra[0]), List.filled(lv.linkCount, 0), List.filled(lv.borderCount, 0), [...lv.extra[2], -1]);

  @override
  bool act(PLevel lv, PState s, int i) {
    final sel = s.aux[lv.n];
    if (sel < 0) {
      s.aux[lv.n] = i;
      return true;
    }
    if (sel == i) {
      s.aux[lv.n] = -1;
      return true;
    }
    return _swap(lv, s, sel, i);
  }

  bool _swap(PLevel lv, PState s, int a, int b) {
    final t = s.cells[a];
    s.cells[a] = s.cells[b];
    s.cells[b] = t;
    final rt = s.aux[a];
    s.aux[a] = s.aux[b];
    s.aux[b] = rt;
    s.aux[lv.n] = -1;
    return true;
  }

  @override
  bool dragMove(PLevel lv, PState s, int from, int to) => _swap(lv, s, from, to);

  @override
  bool actAlt(PLevel lv, PState s, int i) {
    if (!rotates(lv)) return false;
    s.aux[i] = (s.aux[i] + 1) % 4;
    return true;
  }

  @override
  bool solved(PLevel lv, PState s) {
    for (var i = 0; i < lv.n; i++) {
      if (s.cells[i] != i + 1) return false;
      if (s.aux.length > i && s.aux[i] != 0) return false;
    }
    return true;
  }

  @override
  bool ok(PLevel lv, PState s, bool complete) => true;

  @override
  PLevel make(int difficulty, SeededRandom r) {
    final n = const [3, 3, 4, 4, 5, 5, 6, 6, 7, 8][difficulty - 1];
    final perm = [for (var i = 1; i <= n * n; i++) i];
    r.shuffle(perm);
    if (perm.first == 1) {
      final t = perm[0];
      perm[0] = perm[1];
      perm[1] = t;
    }
    final rot = difficulty >= 6;
    final rots = [for (var i = 0; i < n * n; i++) rot ? r.nextInt(4) : 0];
    return PLevel(kind: id, w: n, h: n, clues: const [], extra: [perm, [rot ? 1 : 0], rots], solCells: const [], givens: const [], param: r.nextInt(1 << 20));
  }

  @override
  void paintOver(Canvas c, PLevel lv, PState s, Rect Function(int i) cell, double cs) {
    final board = cell(0).expandToInclude(cell(lv.n - 1));
    final sel = s.aux.length > lv.n ? s.aux[lv.n] : -1;
    for (var i = 0; i < lv.n; i++) {
      final t = s.cells[i] - 1;
      final r = cell(i);
      final hx = t % lv.w, hy = t ~/ lv.w;
      c.save();
      c.clipRRect(RRect.fromRectAndRadius(r.deflate(cs * 0.02), Radius.circular(cs * 0.08)));
      c.translate(r.center.dx, r.center.dy);
      c.rotate((s.aux.length > i ? s.aux[i] : 0) * math.pi / 2);
      c.translate(-cs / 2 - hx * cs, -cs / 2 - hy * cs);
      paintArt(c, board.size, lv.param);
      c.restore();
      // yapboz kulakçıkları
      final p = Paint()..color = const Color(0x55FFFFFF);
      c.drawCircle(r.centerRight, cs * 0.1, p);
      c.drawCircle(r.bottomCenter, cs * 0.1, p);
      if (i == sel) {
        c.drawRect(r.deflate(cs * 0.03), Paint()..style = PaintingStyle.stroke..strokeWidth = cs * 0.08..color = const Color(0xFFEDAE49));
      }
    }
  }
}

// ======================================================================
// Çözme ve İp çözme

/// Düğümleri sürükle: hiçbir çizgi kesişmesin. [ropes] türünde
/// düğümler renkli iplerin uçları ve kancalarıdır. Hücre: düğüm numarası
/// (0 boş). extra[0]: kenarlar (a, b çiftleri), extra[1]: başlangıç,
/// extra[2]: kenar renkleri (ip türü).
class UntangleKind extends MoveKind {
  final bool ropes;
  const UntangleKind({this.ropes = false});

  @override
  String get id => ropes ? 'ip-cozme' : 'cozme';

  @override
  PState initial(PLevel lv) => PState(List.of(lv.extra[1]), List.filled(lv.linkCount, 0), List.filled(lv.borderCount, 0), [-1]);

  @override
  bool dragMove(PLevel lv, PState s, int from, int to) {
    if (s.cells[from] == 0 || s.cells[to] != 0) return false;
    s.cells[to] = s.cells[from];
    s.cells[from] = 0;
    s.aux[0] = -1;
    return true;
  }

  @override
  bool act(PLevel lv, PState s, int i) {
    final sel = s.aux[0];
    if (s.cells[i] != 0) {
      s.aux[0] = sel == i ? -1 : i;
      return true;
    }
    if (sel < 0) return false;
    return dragMove(lv, s, sel, i);
  }

  static bool crosses((int, int) a, (int, int) b, (int, int) c, (int, int) d) {
    int orient((int, int) p, (int, int) q, (int, int) r) {
      final v = (q.$1 - p.$1) * (r.$2 - p.$2) - (q.$2 - p.$2) * (r.$1 - p.$1);
      return v.sign;
    }

    bool onSeg((int, int) p, (int, int) q, (int, int) r) =>
        math.min(p.$1, r.$1) <= q.$1 && q.$1 <= math.max(p.$1, r.$1) && math.min(p.$2, r.$2) <= q.$2 && q.$2 <= math.max(p.$2, r.$2);
    if (a == c || a == d || b == c || b == d) {
      // ortak uç: yalnız üst üste binme sayılır
      final o = a == c || a == d ? a : b;
      final p = o == a ? b : a;
      final q = o == c ? d : c;
      return orient(o, p, q) == 0 && ((p.$1 - o.$1) * (q.$1 - o.$1) + (p.$2 - o.$2) * (q.$2 - o.$2)) > 0;
    }
    final o1 = orient(a, b, c), o2 = orient(a, b, d), o3 = orient(c, d, a), o4 = orient(c, d, b);
    if (o1 != o2 && o3 != o4) return true;
    if (o1 == 0 && onSeg(a, c, b)) return true;
    if (o2 == 0 && onSeg(a, d, b)) return true;
    if (o3 == 0 && onSeg(c, a, d)) return true;
    if (o4 == 0 && onSeg(c, b, d)) return true;
    return false;
  }

  List<(int, int)> _pos(PLevel lv, List<int> cells) {
    final count = lv.extra[0].isEmpty ? 0 : lv.extra[0].reduce(math.max) + 1;
    final pos = List.filled(count, (0, 0));
    for (var i = 0; i < lv.n; i++) {
      if (cells[i] > 0) pos[cells[i] - 1] = (i % lv.w, i ~/ lv.w);
    }
    return pos;
  }

  int crossings(PLevel lv, List<int> cells) {
    final e = lv.extra[0];
    final pos = _pos(lv, cells);
    var n = 0;
    for (var a = 0; a + 1 < e.length; a += 2) {
      for (var b = a + 2; b + 1 < e.length; b += 2) {
        if (crosses(pos[e[a]], pos[e[a + 1]], pos[e[b]], pos[e[b + 1]])) n++;
      }
    }
    return n;
  }

  @override
  bool solved(PLevel lv, PState s) => crossings(lv, s.cells) == 0;

  @override
  bool ok(PLevel lv, PState s, bool complete) => true;

  @override
  PLevel make(int difficulty, SeededRandom r) {
    final n = const [6, 7, 7, 8, 8, 9, 9, 10, 11, 12][difficulty - 1];
    final nodes = const [6, 7, 8, 10, 11, 13, 15, 17, 20, 24][difficulty - 1];
    for (var attempt = 0; attempt < 200; attempt++) {
      final cells = shuffled(n * n, r).take(nodes).toList();
      final pos = [for (final c in cells) (c % n, c ~/ n)];
      final edges = <int>[];
      final colors = <int>[];
      bool free(int a, int b) {
        for (var k = 0; k + 1 < edges.length; k += 2) {
          if (crosses(pos[a], pos[b], pos[edges[k]], pos[edges[k + 1]])) return false;
        }
        // kenar başka düğümün üstünden geçmesin
        for (var c = 0; c < nodes; c++) {
          if (c == a || c == b) continue;
          if (crosses(pos[a], pos[b], pos[c], pos[c])) return false;
        }
        return true;
      }

      if (ropes) {
        // ipler: 2-3 düğümlük yollar
        final left = shuffled(nodes, r);
        var col = 1;
        while (left.length >= 2) {
          final len = left.length >= 3 && r.chance(0.5) ? 3 : 2;
          final path = left.sublist(0, len);
          left.removeRange(0, len);
          var good = true;
          for (var k = 0; k + 1 < path.length; k++) {
            if (!free(path[k], path[k + 1])) {
              good = false;
              break;
            }
          }
          if (!good) continue;
          for (var k = 0; k + 1 < path.length; k++) {
            edges.addAll([path[k], path[k + 1]]);
            colors.add(col);
          }
          col++;
        }
      } else {
        final cand = <(int, int, int)>[];
        for (var a = 0; a < nodes; a++) {
          for (var b = a + 1; b < nodes; b++) {
            final d = (pos[a].$1 - pos[b].$1).abs() + (pos[a].$2 - pos[b].$2).abs();
            cand.add((d * 100 + r.nextInt(100), a, b));
          }
        }
        cand.sort((x, y) => x.$1.compareTo(y.$1));
        for (final (_, a, b) in cand) {
          if (edges.length ~/ 2 >= nodes * 2 - 2) break;
          if (free(a, b)) {
            edges.addAll([a, b]);
            colors.add(1);
          }
        }
      }
      if (edges.length < (ropes ? nodes ~/ 2 : nodes)) continue;
      // karıştır: düğümleri rastgele hücrelere dağıt
      final start = List.filled(n * n, 0);
      final spots = shuffled(n * n, r).take(nodes).toList();
      for (var k = 0; k < nodes; k++) {
        start[spots[k]] = k + 1;
      }
      final lv = PLevel(kind: id, w: n, h: n, clues: const [], extra: [edges, start, colors], solCells: const [], givens: const []);
      final goal = List.filled(n * n, 0);
      for (var k = 0; k < nodes; k++) {
        goal[cells[k]] = k + 1;
      }
      if (crossings(lv, start) < 2 + difficulty ~/ 2) continue;
      return PLevel(kind: id, w: n, h: n, clues: const [], extra: [edges, start, colors], solCells: goal, givens: const []);
    }
    throw StateError('untangle');
  }

  @override
  void paintOver(Canvas c, PLevel lv, PState s, Rect Function(int i) cell, double cs) {
    final e = lv.extra[0];
    final pos = _pos(lv, s.cells);
    Offset at((int, int) p) => cell(p.$2 * lv.w + p.$1).center;
    for (var k = 0; k + 1 < e.length; k += 2) {
      var bad = false;
      for (var j = 0; j + 1 < e.length; j += 2) {
        if (j != k && crosses(pos[e[k]], pos[e[k + 1]], pos[e[j]], pos[e[j + 1]])) {
          bad = true;
          break;
        }
      }
      final col = ropes ? puzzleColorAt(lv.extra[2][k ~/ 2] % 8 + 1) : (bad ? const Color(0xFFD1495B) : const Color(0xFF66A182));
      c.drawLine(at(pos[e[k]]), at(pos[e[k + 1]]),
          Paint()
            ..color = bad && ropes ? col.withValues(alpha: 0.55) : col
            ..strokeWidth = cs * (ropes ? 0.16 : 0.08)
            ..strokeCap = StrokeCap.round);
    }
    final sel = s.aux.isEmpty ? -1 : s.aux[0];
    for (var i = 0; i < lv.n; i++) {
      if (s.cells[i] == 0) continue;
      final r = cell(i);
      c.drawCircle(r.center, cs * 0.28, Paint()..color = i == sel ? const Color(0xFFEDAE49) : const Color(0xFF3A3548));
      c.drawCircle(r.center, cs * 0.14, Paint()..color = const Color(0xFFF6EBD9));
    }
  }

  @override
  String status(PLevel lv, PState s, String lang) => '✕ ${crossings(lv, s.cells)}';
}

// ======================================================================
// Fizik çizgi bulmacası

/// Parmağınla bir çizgi çiz; top düşer ve çizgilerden yuvarlanır. Topu
/// sepete ulaştır. Hücre: 1 duvar. extra[0]: [top hücresi, sepet hücresi].
/// aux: çizilen yol (hücreler) ve sonuç (son eleman: 1 başarı).
class LinePhysicsKind extends MoveKind {
  const LinePhysicsKind();
  @override
  String get id => 'fizik-cizgi-bulmacasi';

  @override
  bool get pathInput => true;

  @override
  bool get pathDiagonal => true;

  @override
  PState initial(PLevel lv) => PState(List.of(lv.extra[1]), List.filled(lv.linkCount, 0), List.filled(lv.borderCount, 0), [0]);

  /// Benzetim: topun izi ve başarı.
  static (List<Offset>, bool) simulate(PLevel lv, List<int> walls, List<int> path) {
    final segs = <(Offset, Offset)>[];
    Offset ctr(int i) => Offset(i % lv.w + 0.5, i ~/ lv.w + 0.5);
    for (var k = 0; k + 1 < path.length; k++) {
      segs.add((ctr(path[k]), ctr(path[k + 1])));
    }
    for (var i = 0; i < lv.n; i++) {
      if (walls[i] != 1) continue;
      final x = (i % lv.w).toDouble(), y = (i ~/ lv.w).toDouble();
      segs.addAll([(Offset(x, y), Offset(x + 1, y)), (Offset(x + 1, y), Offset(x + 1, y + 1)), (Offset(x, y + 1), Offset(x + 1, y + 1)), (Offset(x, y), Offset(x, y + 1))]);
    }
    final cup = lv.extra[0][1];
    final cw = lv.extra[0].length > 2 ? lv.extra[0][2] : 1;
    final cupRect = Rect.fromLTWH((cup % lv.w).toDouble(), (cup ~/ lv.w).toDouble(), cw.toDouble(), 1);
    // sepet kenarları
    segs.add((cupRect.topLeft, cupRect.bottomLeft));
    segs.add((cupRect.topRight, cupRect.bottomRight));
    segs.add((cupRect.bottomLeft, cupRect.bottomRight));
    var p = ctr(lv.extra[0][0]);
    var v = Offset.zero;
    const g = 18.0, dt = 1 / 120, rad = 0.26;
    final trail = <Offset>[p];
    for (var step = 0; step < 2400; step++) {
      v = v + const Offset(0, g * dt);
      p = p + v * dt;
      for (final (a, b) in segs) {
        final ab = b - a;
        final len2 = ab.dx * ab.dx + ab.dy * ab.dy;
        var t = len2 == 0 ? 0.0 : ((p - a).dx * ab.dx + (p - a).dy * ab.dy) / len2;
        t = t.clamp(0.0, 1.0);
        final q = a + ab * t;
        final d = p - q;
        final dist = d.distance;
        if (dist < rad && dist > 1e-9) {
          final nrm = d / dist;
          p = q + nrm * rad;
          final vn = v.dx * nrm.dx + v.dy * nrm.dy;
          if (vn < 0) {
            final vt = v - nrm * vn;
            v = vt * 0.995 - nrm * vn * 0.25;
          }
        }
      }
      if (step % 6 == 0) trail.add(p);
      if (cupRect.deflate(0.05).contains(p)) return (trail, true);
      if (p.dy > lv.h + 1 || p.dx < -1 || p.dx > lv.w + 1) return (trail, false);
      if (step > 600 && v.distance < 0.02) return (trail, false);
    }
    return (trail, false);
  }

  @override
  bool pathMove(PLevel lv, PState s, List<int> path) {
    if (path.any((i) => s.cells[i] == 1 || i == lv.extra[0][0])) return false;
    final (_, okk) = simulate(lv, s.cells, path);
    s.aux
      ..clear()
      ..addAll([...path, okk ? 1 : 0]);
    return true;
  }

  @override
  bool solved(PLevel lv, PState s) => s.aux.length > 2 && s.aux.last == 1;

  @override
  bool ok(PLevel lv, PState s, bool complete) => true;

  @override
  PLevel make(int difficulty, SeededRandom r) {
    final w = 8 + difficulty ~/ 3, h = 10 + difficulty ~/ 3;
    for (var attempt = 0; attempt < 600; attempt++) {
      final bx = 1 + r.nextInt(w - 2), by = 1;
      final cupW = difficulty <= 5 ? 3 : 2;
      final cx = r.nextInt(w - cupW + 1), cy = h - 1 - r.nextInt(2);
      if (bx >= cx - 1 && bx <= cx + cupW) continue;
      final walls = List.filled(w * h, 0);
      final probe = PLevel(kind: id, w: w, h: h, clues: const [], extra: [[by * w + bx, cy * w + cx, cupW]], givens: const []);
      // engeller: topun hemen altında değil
      for (var k = 0; k < difficulty; k++) {
        final i = r.nextInt(w * h);
        final x = i % w, y = i ~/ w;
        if (y <= 2 || (x == bx) || (x >= cx - 1 && x <= cx + cupW && y >= cy - 2)) continue;
        walls[i] = 1;
      }
      // bilinen çözüm: topun altından sepetin üstüne eğimli rampa
      final path = <int>[];
      var x = bx, y = by + 2;
      final tx = cx + cupW ~/ 2, ty = cy - 2;
      path.add(y * w + x);
      while (x != tx || y != ty) {
        if (x != tx) x += (tx - x).sign;
        if (y < ty && (r.chance(0.5) || x == tx)) y++;
        path.add(y * w + x);
      }
      if (path.any((i) => walls[i] == 1) || path.length < 3) continue;
      final (_, okk) = simulate(probe, walls, path);
      // çözümsüz düz düşüş olmasın
      final (_, direct) = simulate(probe, walls, const []);
      if (!okk || direct) continue;
      return PLevel(kind: id, w: w, h: h, clues: const [], extra: [[by * w + bx, cy * w + cx, cupW], walls, path], solCells: const [], givens: const []);
    }
    throw StateError('physics');
  }

  @override
  bool get hintable => false;

  @override
  void paintOver(Canvas c, PLevel lv, PState s, Rect Function(int i) cell, double cs) {
    for (var i = 0; i < lv.n; i++) {
      if (s.cells[i] == 1) c.drawRRect(RRect.fromRectAndRadius(cell(i).deflate(cs * 0.04), Radius.circular(cs * 0.1)), Paint()..color = const Color(0xFF7D8B91));
    }
    final cup = cell(lv.extra[0][1]).expandToInclude(cell(lv.extra[0][1] + (lv.extra[0].length > 2 ? lv.extra[0][2] : 1) - 1));
    final p = Paint()
      ..color = const Color(0xFF8A5A34)
      ..strokeWidth = cs * 0.1
      ..strokeCap = StrokeCap.round;
    c.drawLine(cup.topLeft, cup.bottomLeft, p);
    c.drawLine(cup.bottomLeft, cup.bottomRight, p);
    c.drawLine(cup.bottomRight, cup.topRight, p);
    final o = cell(0).topLeft;
    final path = s.aux.length > 2 ? s.aux.sublist(0, s.aux.length - 1) : const <int>[];
    if (path.length >= 2) {
      final lp = Paint()
        ..color = const Color(0xFF3A3548)
        ..strokeWidth = cs * 0.12
        ..strokeCap = StrokeCap.round;
      for (var k = 0; k + 1 < path.length; k++) {
        c.drawLine(cell(path[k]).center, cell(path[k + 1]).center, lp);
      }
      final (trail, _) = simulate(lv, s.cells, path);
      for (final t in trail) {
        c.drawCircle(o + t * cs, cs * 0.04, Paint()..color = const Color(0x88D1495B));
      }
      c.drawCircle(o + trail.last * cs, cs * 0.26, Paint()..color = const Color(0xFFD1495B));
    } else {
      c.drawCircle(cell(lv.extra[0][0]).center, cs * 0.26, Paint()..color = const Color(0xFFD1495B));
    }
  }
}

// ======================================================================
// Sihirli küp (açılım)

/// Küpün açılımı: bir yüzdeki hücreye dokun, o yüz saat yönünde döner
/// (uzun basma ters). Her yüz tek renk olsun. Hücre: renk (-1 açılım dışı).
class CubeKind extends MoveKind {
  const CubeKind();
  @override
  String get id => 'sihirli-kup';

  int size(PLevel lv) => lv.w ~/ 4;

  @override
  PState initial(PLevel lv) => PState(List.of(lv.extra[0]), List.filled(lv.linkCount, 0), List.filled(lv.borderCount, 0));

  /// Yüz sırası: 0 U, 1 L, 2 F, 3 R, 4 B, 5 D; açılım konumu.
  static const _facePos = [(1, 0), (0, 1), (1, 1), (2, 1), (3, 1), (1, 2)];
  static const _normals = [(0, 1, 0), (-1, 0, 0), (0, 0, 1), (1, 0, 0), (0, 0, -1), (0, -1, 0)];

  /// Yüz ve yüz içi (sütun, satır) → çıkartma konumu (çift katlı koordinat).
  static (int, int, int) stickerPos(int face, int col, int row, int n) {
    final a = 2 * col - (n - 1), b = 2 * row - (n - 1);
    final m = n;
    return switch (face) {
      2 => (a, -b, m),
      3 => (m, -b, -a),
      4 => (-a, -b, -m),
      1 => (-m, -b, a),
      0 => (a, m, b),
      _ => (a, -m, -b),
    };
  }

  static (int, int, int) _locate((int, int, int) p, (int, int, int) nrm, int n) {
    final face = _normals.indexOf(nrm);
    for (var row = 0; row < n; row++) {
      for (var col = 0; col < n; col++) {
        if (stickerPos(face, col, row, n) == p) return (face, col, row);
      }
    }
    return (face, 0, 0);
  }

  static (int, int, int) _rot((int, int, int) v, int axis, bool pos) {
    final (x, y, z) = v;
    return switch (axis) {
      0 => pos ? (x, -z, y) : (x, z, -y),
      1 => pos ? (z, y, -x) : (-z, y, x),
      _ => pos ? (-y, x, z) : (y, -x, z),
    };
  }

  static void turn(List<int> cells, int n, int face, bool cw) {
    final w = 4 * n;
    final (nx, ny, nz) = _normals[face];
    final axis = nx != 0 ? 0 : (ny != 0 ? 1 : 2);
    final sign = nx + ny + nz;
    final pos = (sign > 0) != cw;
    final out = List.of(cells);
    for (var f = 0; f < 6; f++) {
      for (var row = 0; row < n; row++) {
        for (var col = 0; col < n; col++) {
          final p = stickerPos(f, col, row, n);
          final coord = axis == 0 ? p.$1 : (axis == 1 ? p.$2 : p.$3);
          if (coord * sign < n - 1) continue;
          final np = _rot(p, axis, pos), nn = _rot(_normals[f], axis, pos);
          final (tf, tc, tr) = _locate(np, nn, n);
          final (sx, sy) = _facePos[f];
          final (dx, dy) = _facePos[tf];
          out[(dy * n + tr) * w + dx * n + tc] = cells[(sy * n + row) * w + sx * n + col];
        }
      }
    }
    cells.setAll(0, out);
  }

  int _faceOf(PLevel lv, int i) {
    final n = size(lv);
    final fx = (i % lv.w) ~/ n, fy = (i ~/ lv.w) ~/ n;
    return _facePos.indexOf((fx, fy));
  }

  @override
  bool act(PLevel lv, PState s, int i) {
    final f = _faceOf(lv, i);
    if (f < 0) return false;
    turn(s.cells, size(lv), f, true);
    return true;
  }

  @override
  bool actAlt(PLevel lv, PState s, int i) {
    final f = _faceOf(lv, i);
    if (f < 0) return false;
    turn(s.cells, size(lv), f, false);
    return true;
  }

  @override
  bool solved(PLevel lv, PState s) {
    final n = size(lv);
    for (var f = 0; f < 6; f++) {
      final (fx, fy) = _facePos[f];
      final first = s.cells[(fy * n) * lv.w + fx * n];
      for (var row = 0; row < n; row++) {
        for (var col = 0; col < n; col++) {
          if (s.cells[(fy * n + row) * lv.w + fx * n + col] != first) return false;
        }
      }
    }
    return true;
  }

  @override
  PLevel make(int difficulty, SeededRandom r) {
    final n = difficulty <= 4 ? 2 : 3;
    final w = 4 * n, h = 3 * n;
    final goal = List.filled(w * h, -1);
    for (var f = 0; f < 6; f++) {
      final (fx, fy) = _facePos[f];
      for (var row = 0; row < n; row++) {
        for (var col = 0; col < n; col++) {
          goal[(fy * n + row) * w + fx * n + col] = f + 1;
        }
      }
    }
    final c = List.of(goal);
    final moves = const [2, 3, 4, 6, 3, 4, 6, 8, 12, 20][difficulty - 1];
    var last = -1;
    for (var k = 0; k < moves; k++) {
      var f = r.nextInt(6);
      if (f == last) f = (f + 1) % 6;
      turn(c, n, f, r.chance(0.5));
      last = f;
    }
    if (c.join(',') == goal.join(',')) turn(c, n, 2, true);
    return PLevel(kind: id, w: w, h: h, clues: const [], extra: [c], solCells: goal, givens: const []);
  }

  @override
  void paintOver(Canvas c, PLevel lv, PState s, Rect Function(int i) cell, double cs) {
    const cols = [Color(0xFFF6EBD9), Color(0xFFEDAE49), Color(0xFFD1495B), Color(0xFF00798C), Color(0xFF66A182), Color(0xFF3F88C5)];
    for (var i = 0; i < lv.n; i++) {
      final v = s.cells[i];
      if (v <= 0) continue;
      c.drawRRect(RRect.fromRectAndRadius(cell(i).deflate(cs * 0.06), Radius.circular(cs * 0.14)), Paint()..color = cols[v - 1]);
    }
  }
}

// ======================================================================
// Hayaletler (aynalar)

/// Aynalı ızgara: boş hücrelere hayalet, vampir ya da zombi koy. Kenar
/// sayısı o yönden bakınca görülen yaratık sayısıdır: zombi hep görünür,
/// vampir yalnız doğrudan (aynadan önce), hayalet yalnız aynada (sonra).
/// clues: 1 '/', 2 '\' ayna. Hücre: 1 hayalet, 2 vampir, 3 zombi.
/// extra[0]: kenar ipuçları (üst, alt, sol, sağ; -1 yok), extra[1]: toplamlar.
class MirrorKind extends PuzzleKind {
  const MirrorKind();
  @override
  String get id => 'hayaletler';

  @override
  int cellStates(PLevel lv) => 4;

  @override
  bool get zeroUnknown => true;

  @override
  List<int> cellDomain(PLevel lv, int i) => lv.clues[i] > 0 ? const [0] : const [1, 2, 3];

  @override
  bool tapCell(PLevel lv, int i) => lv.clues[i] <= 0 && (lv.givens.isEmpty || lv.givens[i] < 0);

  @override
  bool canGive(PLevel lv, int i) => lv.clues[i] <= 0;

  @override
  int norm(int v) => v <= 0 ? -1 : v;

  @override
  bool solved(PLevel lv, PState player) {
    final v = [for (var i = 0; i < lv.n; i++) lv.clues[i] > 0 ? 0 : (player.cells[i] <= 0 ? -1 : player.cells[i])];
    if (v.contains(-1)) return false;
    return ok(lv, PState(v, const [], const []), true);
  }

  static final _paths = Expando<List<List<(int, bool)>>>();

  /// Kenar başına görüş yolu: (hücre, aynadan sonra mı).
  List<List<(int, bool)>> paths(PLevel lv) => _paths[lv] ??= () {
        final out = <List<(int, bool)>>[];
        final n = lv.w;
        for (var side = 0; side < 4; side++) {
          for (var k = 0; k < n; k++) {
            var (x, y, dx, dy) = switch (side) { 0 => (k, -1, 0, 1), 1 => (k, n, 0, -1), 2 => (-1, k, 1, 0), _ => (n, k, -1, 0) };
            final path = <(int, bool)>[];
            var after = false;
            for (var step = 0; step < 4 * n * n; step++) {
              x += dx;
              y += dy;
              if (x < 0 || y < 0 || x >= n || y >= n) break;
              final i = y * n + x;
              final m = lv.clues[i];
              if (m == 1) {
                final t = dx;
                dx = -dy;
                dy = -t;
                after = true;
              } else if (m == 2) {
                final t = dx;
                dx = dy;
                dy = t;
                after = true;
              } else {
                path.add((i, after));
              }
            }
            out.add(path);
          }
        }
        return out;
      }();

  static bool visible(int v, bool after) => v == 3 || (v == 2 && !after) || (v == 1 && after);

  @override
  bool ok(PLevel lv, PState s, bool complete) {
    final v = s.cells;
    final ps = paths(lv);
    for (var e = 0; e < ps.length; e++) {
      final t = lv.extra[0][e];
      if (t < 0) continue;
      var lo = 0, unk = 0;
      for (final (i, after) in ps[e]) {
        if (v[i] < 0) {
          unk++;
        } else if (visible(v[i], after)) {
          lo++;
        }
      }
      if (lo > t || lo + unk < t) return false;
    }
    for (var m = 1; m <= 3; m++) {
      var c = 0, unk = 0;
      for (var i = 0; i < lv.n; i++) {
        if (lv.clues[i] > 0) continue;
        if (v[i] == m) c++;
        if (v[i] < 0) unk++;
      }
      final t = lv.extra[1][m - 1];
      if (c > t || c + unk < t) return false;
    }
    return true;
  }

  @override
  PLevel make(int difficulty, SeededRandom r) {
    final n = const [4, 4, 5, 5, 5, 6, 6, 6, 7, 7][difficulty - 1];
    final clues = [for (var i = 0; i < n * n; i++) r.chance(0.3) ? 1 + r.nextInt(2) : 0];
    final v = [for (var i = 0; i < n * n; i++) clues[i] > 0 ? 0 : 1 + r.nextInt(3)];
    final probe = PLevel(kind: id, w: n, h: n, clues: clues, givens: const []);
    final edges = [
      for (final p in paths(probe)) p.where((e) => visible(v[e.$1], e.$2)).length
    ];
    final keep = difficulty <= 5 ? 1.0 : 0.8;
    final shown = [for (final e in edges) r.chance(keep) ? e : -1];
    final totals = [for (var m = 1; m <= 3; m++) v.where((x) => x == m).length];
    return PLevel(kind: id, w: n, h: n, clues: clues, extra: [shown, totals], solCells: v, givens: List.filled(n * n, -1));
  }

  @override
  CellLook look(PLevel lv, PState s, int i) {
    if (lv.clues[i] == 1) return const CellLook(mark: Mark.mirrorF);
    if (lv.clues[i] == 2) return const CellLook(mark: Mark.mirrorB);
    final v = s.cells[i];
    return CellLook(mark: switch (v) { 1 => Mark.ghost, 2 => Mark.vampire, 3 => Mark.zombie, _ => Mark.none }, tone: lv.givens.isNotEmpty && lv.givens[i] >= 0 ? 1 : 0);
  }

  @override
  (double, double, double, double) margins(PLevel lv) => (0.7, 0.7, 0.7, 0.7);

  @override
  String outside(PLevel lv, PState s, int side, int index) {
    final e = const [0, 2, 1, 3][side] * lv.w + index;
    final t = lv.extra[0][e];
    return t < 0 ? '' : '$t';
  }

  @override
  String status(PLevel lv, PState s, String lang) => '👻 ${lv.extra[1][0]}  🧛 ${lv.extra[1][1]}  🧟 ${lv.extra[1][2]}';
}

// ======================================================================
// Mantık ızgarası (simgeli)

/// Her satır bir özellik (renk, biçim, sayı, harf); sütunlar konumlar.
/// Her satırda her öğe bir kez. Aşağıdaki simgeli ipuçlarına uy:
/// "a = b" aynı sütun, "a ≠ b" farklı, "a ▸ b" a hemen solunda,
/// "a ↔ b" yan yana, "a … b" a solda bir yerde, "a @k" k. sütunda.
/// Hücre: öğe (1..n). extra[0]: ipuçları [tür, s1, ö1, s2, ö2].
class ZebraKind extends PuzzleKind {
  const ZebraKind();
  @override
  String get id => 'mantik-izgarasi';

  @override
  int cellStates(PLevel lv) => lv.w + 1;

  @override
  bool get zeroUnknown => true;

  @override
  bool tapCell(PLevel lv, int i) => lv.givens.isEmpty || lv.givens[i] < 0;

  int _pos(PLevel lv, List<int> v, int cat, int item) {
    for (var x = 0; x < lv.w; x++) {
      if (v[cat * lv.w + x] == item) return x;
    }
    return -1;
  }

  @override
  bool ok(PLevel lv, PState s, bool complete) {
    final v = s.cells;
    for (var cat = 0; cat < lv.h; cat++) {
      final seen = <int>{};
      for (var x = 0; x < lv.w; x++) {
        final q = v[cat * lv.w + x];
        if (q > 0 && !seen.add(q)) return false;
      }
    }
    final cl = lv.extra[0];
    for (var k = 0; k + 4 < cl.length; k += 5) {
      final t = cl[k];
      final a = _pos(lv, v, cl[k + 1], cl[k + 2]), b = t == 5 || t == 6 ? cl[k + 3] : _pos(lv, v, cl[k + 3], cl[k + 4]);
      if (a < 0 || b < 0) continue;
      final good = switch (t) { 0 => a == b, 1 => a != b, 2 => a + 1 == b, 3 => (a - b).abs() == 1, 4 => a < b, 5 => a == b, _ => a != b };
      if (!good) return false;
    }
    return true;
  }

  @override
  PLevel make(int difficulty, SeededRandom r) {
    final n = const [3, 3, 4, 4, 4, 5, 5, 5, 5, 5][difficulty - 1];
    final cats = difficulty <= 3 ? 3 : 4;
    final sol = <int>[];
    for (var cat = 0; cat < cats; cat++) {
      sol.addAll([for (final p in shuffled(n, r)) p + 1]);
    }
    int posOf(int cat, int item) => sol.sublist(cat * n, cat * n + n).indexOf(item);
    final clues = <int>[];
    final probeSol = PState(sol, const [], const []);
    var lv = PLevel(kind: id, w: n, h: cats, clues: const [], extra: [clues], solCells: sol, givens: List.filled(n * cats, -1));
    for (var t = 0; t < 400; t++) {
      final c = genericCount(this, lv, budget: 20000);
      if (c == 1) break;
      // doğru bir ipucu ekle
      final type = r.nextInt(7);
      final c1 = r.nextInt(cats), i1 = 1 + r.nextInt(n);
      var c2 = r.nextInt(cats), i2 = 1 + r.nextInt(n);
      final a = posOf(c1, i1);
      List<int>? clue;
      switch (type) {
        case 0:
          if (c2 == c1) c2 = (c1 + 1) % cats;
          clue = [0, c1, i1, c2, sol[c2 * n + a]];
        case 1:
          if (c2 == c1) c2 = (c1 + 1) % cats;
          final b = posOf(c2, i2);
          if (b != a) clue = [1, c1, i1, c2, i2];
        case 2:
          if (a + 1 < n) clue = [2, c1, i1, c2, sol[c2 * n + a + 1]];
        case 3:
          final b = a + (r.chance(0.5) ? 1 : -1);
          if (b >= 0 && b < n) clue = [3, c1, i1, c2, sol[c2 * n + b]];
        case 4:
          final b = posOf(c2, i2);
          if (a < b) clue = [4, c1, i1, c2, i2];
        case 5:
          if (difficulty <= 6 || r.chance(0.3)) clue = [5, c1, i1, a, 0];
        default:
          final p = r.nextInt(n);
          if (p != a) clue = [6, c1, i1, p, 0];
      }
      if (clue == null) continue;
      clues.addAll(clue);
      lv = PLevel(kind: id, w: n, h: cats, clues: const [], extra: [List.of(clues)], solCells: sol, givens: List.filled(n * cats, -1));
      if (!ok(lv, probeSol, true)) {
        clues.removeRange(clues.length - 5, clues.length);
      }
    }
    return lv;
  }

  @override
  double maxGivenRatio(int difficulty) => 0.3;

  @override
  CellLook look(PLevel lv, PState s, int i) => const CellLook();

  @override
  (double, double, double, double) margins(PLevel lv) {
    final rows = (lv.extra[0].length ~/ 5 / 2).ceil();
    return (0, 0, rows * 0.75 + 0.3, 0);
  }

  static void icon(Canvas c, int cat, int item, Offset o, double s) {
    final col = puzzleColorAt(item);
    switch (cat) {
      case 0:
        c.drawCircle(o, s * 0.36, Paint()..color = col);
      case 1:
        final p = Paint()..color = const Color(0xFF3A3548);
        switch (item) {
          case 1:
            c.drawCircle(o, s * 0.32, p);
          case 2:
            c.drawRect(Rect.fromCenter(center: o, width: s * 0.6, height: s * 0.6), p);
          case 3:
            c.drawPath(Path()..moveTo(o.dx, o.dy - s * 0.34)..lineTo(o.dx + s * 0.34, o.dy + s * 0.28)..lineTo(o.dx - s * 0.34, o.dy + s * 0.28)..close(), p);
          case 4:
            c.drawPath(Path()..moveTo(o.dx, o.dy - s * 0.36)..lineTo(o.dx + s * 0.3, o.dy)..lineTo(o.dx, o.dy + s * 0.36)..lineTo(o.dx - s * 0.3, o.dy)..close(), p);
          default:
            c.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: o, width: s * 0.7, height: s * 0.36), Radius.circular(s * 0.18)), p);
        }
      case 2:
        smallText(c, '$item', o, s * 0.55, const Color(0xFF8A5A34));
      default:
        smallText(c, String.fromCharCode(64 + item), o, s * 0.55, const Color(0xFF00798C));
    }
  }

  @override
  void paintOver(Canvas c, PLevel lv, PState s, Rect Function(int i) cell, double cs) {
    for (var i = 0; i < lv.n; i++) {
      final v = s.cells[i];
      if (v > 0) icon(c, i ~/ lv.w, v, cell(i).center, cs * 0.9);
    }
    // ipuçları: iki sütun halinde
    final cl = lv.extra[0];
    final base = cell(lv.n - lv.w).bottomLeft + Offset(0, cs * 0.25);
    final colW = lv.w * cs / 2;
    final sc = cs * 0.55;
    for (var k = 0, row = 0; k + 4 < cl.length; k += 5, row++) {
      final ox = base.dx + (row.isOdd ? colW : 0), oy = base.dy + (row ~/ 2) * cs * 0.75;
      final t = cl[k];
      icon(c, cl[k + 1], cl[k + 2], Offset(ox + sc * 0.6, oy + sc * 0.5), sc);
      smallText(c, const ['=', '≠', '▸', '↔', '…', '@', '≠@'][t], Offset(ox + sc * 1.5, oy + sc * 0.5), sc * 0.6, const Color(0xFF3A3548));
      if (t >= 5) {
        smallText(c, '${cl[k + 3] + 1}', Offset(ox + sc * 2.4, oy + sc * 0.5), sc * 0.6, const Color(0xFF3A3548));
      } else {
        icon(c, cl[k + 3], cl[k + 4], Offset(ox + sc * 2.4, oy + sc * 0.5), sc);
      }
    }
  }
}
