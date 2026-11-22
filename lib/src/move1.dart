import 'dart:math' as math;
import 'dart:ui';

import 'package:studio_core/core/rng.dart';

import 'core.dart';
import 'digits.dart';
import 'regions.dart';

/// Hamle bulmacalarının tabanı.
abstract class MoveKind extends PuzzleKind {
  const MoveKind();

  @override
  bool get actionMode => true;

  @override
  CellInput get cellInput => CellInput.none;

  @override
  bool get hintable => false;

  @override
  bool get gridLines => false;

  @override
  bool tapCell(PLevel lv, int i) => false;

  @override
  CellLook look(PLevel lv, PState s, int i) => const CellLook();

  @override
  bool ok(PLevel lv, PState s, bool complete) => solved(lv, s);

  @override
  int? countSolutions(PLevel lv, {int limit = 2, int budget = 200000}) => 1;

  /// Kare taş çizimi.
  static void tile(Canvas c, Rect r, Color fill, String text, Color ink, {double radius = 0.16}) {
    final s = r.width;
    c.drawRRect(RRect.fromRectAndRadius(r.deflate(s * 0.05), Radius.circular(s * radius)), Paint()..color = fill);
    if (text.isNotEmpty) smallText(c, text, r.center, s * (text.length > 3 ? 0.26 : (text.length > 2 ? 0.32 : 0.42)), ink);
  }
}

/// Değer → sıcak/soğuk özgün renk.
Color expColor(int e) => const [
      Color(0xFFE9DCC9),
      Color(0xFFF3E3C3),
      Color(0xFFF0CF9B),
      Color(0xFFEDA96B),
      Color(0xFFE88A5A),
      Color(0xFFDD6B4D),
      Color(0xFFC9544A),
      Color(0xFFB8A04A),
      Color(0xFF9DB55A),
      Color(0xFF5FA88B),
      Color(0xFF3F8FB0),
      Color(0xFF5468B8),
      Color(0xFF7B55A8),
      Color(0xFF3A3548),
    ][e.clamp(0, 13)];

// ======================================================================
// 2048

/// Kaydır: aynı sayılar birleşir; hedef taşa ulaş. Hücre: üs (0 boş).
/// aux[0]: rastgele durum.
class MergeSlideKind extends MoveKind {
  const MergeSlideKind();
  @override
  String get id => '2048';

  int target(PLevel lv) => lv.param;

  @override
  PState initial(PLevel lv) {
    final s = PState(List.filled(lv.n, 0), List.filled(lv.linkCount, 0), List.filled(lv.borderCount, 0), [lv.extra[0][0]]);
    _spawn(lv, s);
    _spawn(lv, s);
    return s;
  }

  void _spawn(PLevel lv, PState s) {
    final r = SeededRandom.fromState(s.aux[0]);
    final empty = [for (var i = 0; i < lv.n; i++) if (s.cells[i] == 0) i];
    if (empty.isNotEmpty) s.cells[empty[r.nextInt(empty.length)]] = r.chance(0.9) ? 1 : 2;
    s.aux[0] = r.state;
  }

  static bool slide(List<int> cells, int w, int h, int dir) {
    var moved = false;
    final lines = dir.isEven ? w : h;
    final len = dir.isEven ? h : w;
    for (var a = 0; a < lines; a++) {
      final idx = [
        for (var b = 0; b < len; b++)
          switch (dir) { 0 => b * w + a, 2 => (h - 1 - b) * w + a, 3 => a * w + b, _ => a * w + (w - 1 - b) }
      ];
      final vals = [for (final i in idx) cells[i]].where((v) => v > 0).toList();
      final out = <int>[];
      for (var k = 0; k < vals.length; k++) {
        if (k + 1 < vals.length && vals[k] == vals[k + 1]) {
          out.add(vals[k] + 1);
          k++;
        } else {
          out.add(vals[k]);
        }
      }
      for (var b = 0; b < len; b++) {
        final v = b < out.length ? out[b] : 0;
        if (cells[idx[b]] != v) moved = true;
        cells[idx[b]] = v;
      }
    }
    return moved;
  }

  @override
  bool swipe(PLevel lv, PState s, int dir) {
    if (!slide(s.cells, lv.w, lv.h, dir)) return false;
    _spawn(lv, s);
    return true;
  }

  @override
  bool solved(PLevel lv, PState s) => s.cells.any((v) => v >= target(lv));

  @override
  bool failed(PLevel lv, PState s) {
    if (solved(lv, s) || s.cells.contains(0)) return false;
    for (var dir = 0; dir < 4; dir++) {
      if (slide(List.of(s.cells), lv.w, lv.h, dir)) return false;
    }
    return true;
  }

  @override
  PLevel make(int difficulty, SeededRandom r) {
    final n = difficulty <= 2 ? 5 : 4;
    final t = const [6, 7, 7, 8, 8, 9, 9, 10, 10, 11][difficulty - 1];
    final goal = List.filled(n * n, 0)..[0] = t;
    return PLevel(kind: id, w: n, h: n, clues: const [], extra: [[r.nextUint32()]], solCells: goal, givens: const [], param: t);
  }

  @override
  void paintOver(Canvas c, PLevel lv, PState s, Rect Function(int i) cell, double cs) {
    for (var i = 0; i < lv.n; i++) {
      final e = s.cells[i];
      MoveKind.tile(c, cell(i), expColor(e), e > 0 ? '${1 << e}' : '', e >= 3 ? const Color(0xFFFFFFFF) : const Color(0xFF4A4038));
    }
  }

  @override
  String status(PLevel lv, PState s, String lang) => '→ ${1 << target(lv)}';
}

// ======================================================================
// Sayı birleştirme (zincir)

/// Aynı sayılardan (ya da bir öncekinin iki katına geçerek) komşu hücre
/// zinciri çiz; zincirin toplamı son hücrede tek taş olur. Hedefe ulaş.
class ChainMergeKind extends MoveKind {
  const ChainMergeKind();
  @override
  String get id => 'sayi-birlestirme';

  @override
  bool get pathInput => true;

  @override
  bool get pathDiagonal => true;

  @override
  PState initial(PLevel lv) {
    final r = SeededRandom(lv.extra[0][0]);
    final cells = [for (var i = 0; i < lv.n; i++) 1 + r.nextInt(4)];
    return PState(cells, List.filled(lv.linkCount, 0), List.filled(lv.borderCount, 0), [r.state]);
  }

  bool validChain(List<int> cells, List<int> path) {
    if (path.length < 2) return false;
    for (var k = 1; k < path.length; k++) {
      final a = cells[path[k - 1]], b = cells[path[k]];
      if (b != a && b != a + 1) return false;
      if (k == 1 && b != a) return false;
    }
    return true;
  }

  @override
  bool pathMove(PLevel lv, PState s, List<int> path) {
    if (!validChain(s.cells, path)) return false;
    var sum = 0;
    for (final i in path) {
      sum += 1 << s.cells[i];
    }
    var e = 0;
    while ((1 << e) < sum) {
      e++;
    }
    for (final i in path) {
      s.cells[i] = 0;
    }
    s.cells[path.last] = e;
    // yerçekimi ve yeni taşlar
    final r = SeededRandom.fromState(s.aux[0]);
    final low = math.max(1, (s.cells.reduce(math.max) - 5));
    for (var x = 0; x < lv.w; x++) {
      final col = [for (var y = lv.h - 1; y >= 0; y--) s.cells[y * lv.w + x]].where((v) => v > 0).toList();
      for (var k = 0; k < lv.h; k++) {
        final y = lv.h - 1 - k;
        s.cells[y * lv.w + x] = k < col.length ? col[k] : low + r.nextInt(3);
      }
    }
    s.aux[0] = r.state;
    return true;
  }

  @override
  bool solved(PLevel lv, PState s) => s.cells.any((v) => v >= lv.param);

  @override
  bool failed(PLevel lv, PState s) {
    if (solved(lv, s)) return false;
    for (var i = 0; i < lv.n; i++) {
      for (final nb in lv.neighbors(i, diag: true)) {
        if (s.cells[nb] == s.cells[i]) return false;
      }
    }
    return true;
  }

  @override
  PLevel make(int difficulty, SeededRandom r) {
    final t = const [7, 8, 8, 9, 9, 10, 10, 11, 11, 12][difficulty - 1];
    final goal = List.filled(30, 1)..[0] = t;
    return PLevel(kind: id, w: 5, h: 6, clues: const [], extra: [[r.nextUint32()]], solCells: goal, givens: const [], param: t);
  }

  @override
  void paintOver(Canvas c, PLevel lv, PState s, Rect Function(int i) cell, double cs) {
    for (var i = 0; i < lv.n; i++) {
      final e = s.cells[i];
      final v = 1 << e;
      final label = v >= 1000000 ? '${v ~/ 1000000}M' : (v >= 10000 ? '${v ~/ 1000}K' : '$v');
      final r = cell(i);
      c.drawCircle(r.center, cs * 0.42, Paint()..color = expColor(e));
      smallText(c, label, r.center, cs * (label.length > 3 ? 0.26 : 0.34), e >= 3 ? const Color(0xFFFFFFFF) : const Color(0xFF4A4038));
    }
  }

  @override
  String status(PLevel lv, PState s, String lang) => '→ ${1 << lv.param}';
}

// ======================================================================
// Kayan sayılar ve Resim kaydırma

/// Boşluğun satır/sütunundaki taşa dokun: taşlar boşluğa kayar. Sırala.
/// Hücre: taş numarası (0 boşluk). extra[0]: başlangıç.
class SlidingKind extends MoveKind {
  final bool picture;
  const SlidingKind({this.picture = false});

  @override
  String get id => picture ? 'resim-kaydirma' : 'kayan-sayilar';

  @override
  PState initial(PLevel lv) => PState(List.of(lv.extra[0]), List.filled(lv.linkCount, 0), List.filled(lv.borderCount, 0));

  @override
  bool act(PLevel lv, PState s, int i) {
    final b = s.cells.indexOf(0);
    final bx = b % lv.w, by = b ~/ lv.w, x = i % lv.w, y = i ~/ lv.w;
    if (i == b || (bx != x && by != y)) return false;
    final step = bx == x ? (y > by ? lv.w : -lv.w) : (x > bx ? 1 : -1);
    var c = b;
    while (c != i) {
      s.cells[c] = s.cells[c + step];
      c += step;
    }
    s.cells[i] = 0;
    return true;
  }

  @override
  bool swipe(PLevel lv, PState s, int dir) {
    // kaydırma yönündeki taş boşluğa gelir
    final b = s.cells.indexOf(0);
    final bx = b % lv.w, by = b ~/ lv.w;
    final from = switch (dir) { 0 => by < lv.h - 1 ? b + lv.w : -1, 2 => by > 0 ? b - lv.w : -1, 1 => bx > 0 ? b - 1 : -1, _ => bx < lv.w - 1 ? b + 1 : -1 };
    return from >= 0 && act(lv, s, from);
  }

  @override
  bool solved(PLevel lv, PState s) {
    for (var i = 0; i < lv.n - 1; i++) {
      if (s.cells[i] != i + 1) return false;
    }
    return s.cells[lv.n - 1] == 0;
  }

  @override
  PLevel make(int difficulty, SeededRandom r) {
    final n = const [3, 3, 3, 4, 4, 4, 4, 5, 5, 5][difficulty - 1];
    final goal = [for (var i = 1; i < n * n; i++) i, 0];
    final st = PState(List.of(goal), const [], const []);
    final probe = PLevel(kind: id, w: n, h: n, clues: const [], givens: const []);
    var prev = -1;
    final moves = 20 + difficulty * 25;
    for (var k = 0; k < moves; k++) {
      final b = st.cells.indexOf(0);
      final opts = probe.neighbors(b).where((c) => c != prev).toList();
      final c = opts[r.nextInt(opts.length)];
      prev = b;
      act(probe, st, c);
    }
    if (solved(probe, st)) act(probe, st, probe.neighbors(st.cells.indexOf(0)).first);
    return PLevel(kind: id, w: n, h: n, clues: const [], extra: [st.cells], solCells: goal, givens: const [], param: r.nextInt(1 << 20));
  }

  @override
  void paintOver(Canvas c, PLevel lv, PState s, Rect Function(int i) cell, double cs) {
    final board = cell(0).expandToInclude(cell(lv.n - 1));
    for (var i = 0; i < lv.n; i++) {
      final t = s.cells[i];
      if (t == 0) continue;
      final r = cell(i).deflate(cs * 0.04);
      if (!picture) {
        MoveKind.tile(c, cell(i), expColor(2 + (t - 1) * 9 ~/ (lv.n - 1)), '$t', const Color(0xFF3A3548));
        continue;
      }
      // resmin bu taşa düşen parçası
      final hx = (t - 1) % lv.w, hy = (t - 1) ~/ lv.w;
      c.save();
      c.clipRRect(RRect.fromRectAndRadius(r, Radius.circular(cs * 0.1)));
      c.translate(r.left - board.left - hx * cs, r.top - board.top - hy * cs);
      paintArt(c, board.size, lv.param);
      c.restore();
      smallText(c, '$t', r.topLeft + Offset(cs * 0.16, cs * 0.14), cs * 0.18, const Color(0xCCFFFFFF));
    }
  }
}

/// Bölüm tohumundan özgün soyut resim (taşlar için).
void paintArt(Canvas c, Size size, int seed) {
  final r = SeededRandom(seed);
  final base = expColor(2 + r.nextInt(10));
  final rect = Offset.zero & size;
  c.drawRect(
      rect,
      Paint()
        ..shader = Gradient.linear(rect.topLeft, rect.bottomRight, [base, expColor(2 + r.nextInt(10)), expColor(1 + r.nextInt(12))], const [0, 0.55, 1]));
  for (var k = 0; k < 9; k++) {
    final o = Offset(r.nextDouble() * size.width, r.nextDouble() * size.height);
    final rad = (0.08 + r.nextDouble() * 0.22) * size.shortestSide;
    c.drawCircle(o, rad, Paint()..color = expColor(1 + r.nextInt(13)).withValues(alpha: 0.75));
  }
  final p = Paint()
    ..color = const Color(0x55FFFFFF)
    ..strokeWidth = size.shortestSide * 0.02
    ..style = PaintingStyle.stroke;
  for (var k = 0; k < 4; k++) {
    final y = r.nextDouble() * size.height;
    final path = Path()..moveTo(0, y);
    for (var x = 0.0; x <= size.width; x += size.width / 8) {
      path.lineTo(x, y + math.sin(x / size.width * math.pi * (2 + k)) * size.height * 0.08);
    }
    c.drawPath(path, p);
  }
}

// ======================================================================
// Döndür (2x2 döndürme)

/// Bir hücreye dokun: o hücreden başlayan 2x2 blok saat yönünde döner
/// (uzun basma tersine). Sayıları sırala.
class TwiddleKind extends MoveKind {
  const TwiddleKind();
  @override
  String get id => 'dondur';

  @override
  PState initial(PLevel lv) => PState(List.of(lv.extra[0]), List.filled(lv.linkCount, 0), List.filled(lv.borderCount, 0));

  static void rotate(List<int> c, int w, int i, bool cw) {
    final a = i, b = i + 1, d = i + w, e = i + w + 1;
    if (cw) {
      final t = c[a];
      c[a] = c[d];
      c[d] = c[e];
      c[e] = c[b];
      c[b] = t;
    } else {
      final t = c[a];
      c[a] = c[b];
      c[b] = c[e];
      c[e] = c[d];
      c[d] = t;
    }
  }

  int _anchor(PLevel lv, int i) {
    var x = i % lv.w, y = i ~/ lv.w;
    if (x == lv.w - 1) x--;
    if (y == lv.h - 1) y--;
    return y * lv.w + x;
  }

  @override
  bool act(PLevel lv, PState s, int i) {
    rotate(s.cells, lv.w, _anchor(lv, i), true);
    return true;
  }

  @override
  bool actAlt(PLevel lv, PState s, int i) {
    rotate(s.cells, lv.w, _anchor(lv, i), false);
    return true;
  }

  @override
  bool solved(PLevel lv, PState s) {
    for (var i = 0; i < lv.n; i++) {
      if (s.cells[i] != i + 1) return false;
    }
    return true;
  }

  @override
  PLevel make(int difficulty, SeededRandom r) {
    final n = const [3, 3, 3, 4, 4, 4, 5, 5, 5, 6][difficulty - 1];
    final goal = [for (var i = 1; i <= n * n; i++) i];
    final c = List.of(goal);
    for (var k = 0; k < 3 + difficulty * 3; k++) {
      rotate(c, n, r.nextInt(n - 1) + r.nextInt(n - 1) * n, true);
    }
    if (c.join() == goal.join()) rotate(c, n, 0, true);
    return PLevel(kind: id, w: n, h: n, clues: const [], extra: [c], solCells: goal, givens: const []);
  }

  @override
  void paintOver(Canvas c, PLevel lv, PState s, Rect Function(int i) cell, double cs) {
    for (var i = 0; i < lv.n; i++) {
      final t = s.cells[i];
      MoveKind.tile(c, cell(i), expColor(1 + (t - 1) * 11 ~/ lv.n), '$t', const Color(0xFF3A3548));
    }
  }
}

// ======================================================================
// On altı (satır/sütun kaydırma)

/// Kenardaki oklarla satırı ya da sütunu döngüsel kaydır; sayıları sırala.
class ShiftKind extends MoveKind {
  const ShiftKind();
  @override
  String get id => 'on-alti';

  @override
  PState initial(PLevel lv) => PState(List.of(lv.extra[0]), List.filled(lv.linkCount, 0), List.filled(lv.borderCount, 0));

  static void shift(List<int> c, int w, int h, int side, int k) {
    final idx = side.isEven ? [for (var y = 0; y < h; y++) y * w + k] : [for (var x = 0; x < w; x++) k * w + x];
    final vals = [for (final i in idx) c[i]];
    // 0 üst: yukarı, 2 alt: aşağı, 1 sol: sola, 3 sağ: sağa
    final fwd = side == 0 || side == 1;
    for (var q = 0; q < idx.length; q++) {
      c[idx[q]] = fwd ? vals[(q + 1) % vals.length] : vals[(q - 1 + vals.length) % vals.length];
    }
  }

  @override
  bool actOutside(PLevel lv, PState s, int side, int index) {
    shift(s.cells, lv.w, lv.h, side, index);
    return true;
  }

  @override
  (double, double, double, double) margins(PLevel lv) => (0.7, 0.7, 0.7, 0.7);

  @override
  String outside(PLevel lv, PState s, int side, int index) => const ['▲', '◀', '▼', '▶'][side];

  @override
  bool solved(PLevel lv, PState s) {
    for (var i = 0; i < lv.n; i++) {
      if (s.cells[i] != i + 1) return false;
    }
    return true;
  }

  @override
  PLevel make(int difficulty, SeededRandom r) {
    final n = const [3, 3, 3, 4, 4, 4, 4, 5, 5, 6][difficulty - 1];
    final goal = [for (var i = 1; i <= n * n; i++) i];
    final c = List.of(goal);
    for (var k = 0; k < 2 + difficulty * 2; k++) {
      shift(c, n, n, r.nextInt(4), r.nextInt(n));
    }
    if (c.join(',') == goal.join(',')) shift(c, n, n, 1, 0);
    return PLevel(kind: id, w: n, h: n, clues: const [], extra: [c], solCells: goal, givens: const []);
  }

  @override
  void paintOver(Canvas c, PLevel lv, PState s, Rect Function(int i) cell, double cs) {
    for (var i = 0; i < lv.n; i++) {
      final t = s.cells[i];
      MoveKind.tile(c, cell(i), expColor(1 + (t - 1) * 11 ~/ lv.n), '$t', const Color(0xFF3A3548));
    }
  }
}

// ======================================================================
// Kaydırmalı ağ

/// Boru ağı: satır ve sütunları kenardaki oklarla döngüsel kaydır; bütün
/// borular tek ağ olsun. Hücre: boru maskesi.
class NetSlideKind extends MoveKind {
  const NetSlideKind();
  @override
  String get id => 'kaydirmali-ag';

  @override
  PState initial(PLevel lv) => PState(List.of(lv.extra[0]), List.filled(lv.linkCount, 0), List.filled(lv.borderCount, 0));

  @override
  bool actOutside(PLevel lv, PState s, int side, int index) {
    ShiftKind.shift(s.cells, lv.w, lv.h, side, index);
    return true;
  }

  @override
  (double, double, double, double) margins(PLevel lv) => (0.7, 0.7, 0.7, 0.7);

  @override
  String outside(PLevel lv, PState s, int side, int index) => const ['▲', '◀', '▼', '▶'][side];

  @override
  bool solved(PLevel lv, PState s) {
    final probe = PLevel(kind: 'boru', w: lv.w, h: lv.h, clues: s.cells, givens: const []);
    return const PipeKind().ok(probe, PState(List.filled(lv.n, 0), const [], const []), true);
  }

  @override
  PLevel make(int difficulty, SeededRandom r) {
    final base = const PipeKind().make(math.min(10, difficulty + 1), r);
    final n = math.min(base.w, 6);
    final probe = n == base.w ? base : const PipeKind().make(const [1, 1, 3, 3, 5, 5, 5, 5, 5, 5][difficulty - 1], r);
    final goal = List.of(probe.clues);
    final c = List.of(goal);
    for (var k = 0; k < 2 + difficulty * 2; k++) {
      ShiftKind.shift(c, probe.w, probe.h, r.nextInt(4), r.nextInt(probe.w));
    }
    if (c.join(',') == goal.join(',')) ShiftKind.shift(c, probe.w, probe.h, 1, 0);
    return PLevel(kind: id, w: probe.w, h: probe.h, clues: const [], extra: [c], solCells: goal, givens: const []);
  }

  @override
  void paintOver(Canvas c, PLevel lv, PState s, Rect Function(int i) cell, double cs) {
    final probe = PLevel(kind: 'boru', w: lv.w, h: lv.h, clues: s.cells, givens: const []);
    const PipeKind().paintOver(c, probe, PState(List.filled(lv.n, 0), const [], const []), cell, cs);
  }
}

// ======================================================================
// Hanoi kulesi

/// Bütün diskleri en sağdaki çubuğa taşı; büyük disk küçüğün üstüne
/// konmaz. Çubuğa dokunarak seç, sonra hedef çubuğa dokun.
/// Hücre i: i. diskin (0 en küçük) çubuğu. aux[0]: seçili çubuk (-1).
class HanoiKind extends MoveKind {
  const HanoiKind();
  @override
  String get id => 'hanoi-kulesi';

  int disks(PLevel lv) => lv.param;

  @override
  PState initial(PLevel lv) => PState(List.filled(lv.n, 0)..setAll(0, List.filled(disks(lv), 0)), List.filled(lv.linkCount, 0), List.filled(lv.borderCount, 0), [-1]);

  int top(PState s, int peg, int count) {
    for (var d = 0; d < count; d++) {
      if (s.cells[d] == peg) return d;
    }
    return -1;
  }

  @override
  bool act(PLevel lv, PState s, int i) {
    final peg = i % 3;
    final n = disks(lv);
    final sel = s.aux[0];
    if (sel < 0) {
      if (top(s, peg, n) < 0) return false;
      s.aux[0] = peg;
      return true;
    }
    if (sel == peg) {
      s.aux[0] = -1;
      return true;
    }
    final d = top(s, sel, n), t = top(s, peg, n);
    if (t >= 0 && t < d) {
      s.aux[0] = -1;
      return true;
    }
    s.cells[d] = peg;
    s.aux[0] = -1;
    return true;
  }

  @override
  bool solved(PLevel lv, PState s) {
    for (var d = 0; d < disks(lv); d++) {
      if (s.cells[d] != 2) return false;
    }
    return true;
  }

  @override
  PLevel make(int difficulty, SeededRandom r) {
    final n = const [3, 3, 4, 4, 5, 5, 6, 6, 7, 8][difficulty - 1];
    final h = n + 2;
    final goal = List.filled(3 * h, 0)..setAll(0, List.filled(n, 2));
    return PLevel(kind: id, w: 3, h: h, clues: const [], solCells: goal, givens: const [], param: n);
  }

  @override
  void paintOver(Canvas c, PLevel lv, PState s, Rect Function(int i) cell, double cs) {
    final n = disks(lv);
    final base = cell(lv.n - 3).bottomLeft;
    final width = cs * 3;
    c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(base.dx, base.dy - cs * 0.3, width, cs * 0.3), Radius.circular(cs * 0.1)), Paint()..color = const Color(0xFF8A5A34));
    for (var p = 0; p < 3; p++) {
      final x = base.dx + (p + 0.5) * cs;
      final sel = s.aux.isNotEmpty && s.aux[0] == p;
      c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x - cs * 0.05, base.dy - cs * (lv.h - 0.4), cs * 0.1, cs * (lv.h - 0.7)), Radius.circular(cs * 0.05)),
          Paint()..color = sel ? const Color(0xFFEDAE49) : const Color(0xFFA67B5B));
      var level = 0;
      for (var d = n - 1; d >= 0; d--) {
        if (s.cells[d] != p) continue;
        final dw = cs * (0.3 + 0.65 * (d + 1) / n);
        final y = base.dy - cs * 0.3 - (level + 1) * cs * 0.8;
        c.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(x, y + cs * 0.4), width: dw, height: cs * 0.7), Radius.circular(cs * 0.2)), Paint()..color = expColor(2 + d * 10 ~/ n));
        level++;
      }
    }
  }

  @override
  String status(PLevel lv, PState s, String lang) => '★ ${(1 << disks(lv)) - 1}';
}

// ======================================================================
// Taş zıplatma

/// Bir taşı komşusunun üzerinden boş deliğe zıplat; atlanan taş kalkar.
/// Tek taş kalsın. Hücre: -1 tahta dışı, 0 delik, 1 taş. aux[0]: seçili.
class PegJumpKind extends MoveKind {
  const PegJumpKind();
  @override
  String get id => 'tas-ziplatma';

  @override
  PState initial(PLevel lv) => PState(List.of(lv.extra[0]), List.filled(lv.linkCount, 0), List.filled(lv.borderCount, 0), [-1]);

  List<(int, int)> jumps(PLevel lv, List<int> c, int from) {
    final out = <(int, int)>[];
    final x = from % lv.w, y = from ~/ lv.w;
    for (final (dx, dy) in const [(1, 0), (-1, 0), (0, 1), (0, -1)]) {
      final mx = x + dx, my = y + dy, tx = x + 2 * dx, ty = y + 2 * dy;
      if (tx < 0 || ty < 0 || tx >= lv.w || ty >= lv.h) continue;
      final m = my * lv.w + mx, t = ty * lv.w + tx;
      if (c[m] == 1 && c[t] == 0) out.add((m, t));
    }
    return out;
  }

  @override
  bool act(PLevel lv, PState s, int i) {
    final sel = s.aux[0];
    if (s.cells[i] == 1) {
      s.aux[0] = sel == i ? -1 : i;
      return true;
    }
    if (sel < 0 || s.cells[i] != 0) return false;
    for (final (m, t) in jumps(lv, s.cells, sel)) {
      if (t == i) {
        s.cells[sel] = 0;
        s.cells[m] = 0;
        s.cells[t] = 1;
        s.aux[0] = t;
        return true;
      }
    }
    return false;
  }

  @override
  bool dragMove(PLevel lv, PState s, int from, int to) {
    if (s.cells[from] != 1) return false;
    s.aux[0] = from;
    return act(lv, s, to);
  }

  @override
  bool solved(PLevel lv, PState s) => s.cells.where((v) => v == 1).length == 1;

  @override
  bool failed(PLevel lv, PState s) {
    if (solved(lv, s)) return false;
    for (var i = 0; i < lv.n; i++) {
      if (s.cells[i] == 1 && jumps(lv, s.cells, i).isNotEmpty) return false;
    }
    return true;
  }

  @override
  PLevel make(int difficulty, SeededRandom r) {
    final n = difficulty <= 3 ? 5 : 7;
    final cells = List.filled(n * n, 0);
    if (n == 7) {
      for (var i = 0; i < 49; i++) {
        final x = i % 7, y = i ~/ 7;
        if ((x < 2 || x > 4) && (y < 2 || y > 4)) cells[i] = -1;
      }
    }
    final probe = PLevel(kind: id, w: n, h: n, clues: const [], givens: const []);
    // tek taştan geriye doğru zıplamalar
    final valid = [for (var i = 0; i < n * n; i++) if (cells[i] == 0) i];
    final start = valid[r.nextInt(valid.length)];
    cells[start] = 1;
    final goal = List.of(cells);
    final target = math.min(valid.length - 2, 3 + difficulty * 2);
    var pegs = 1;
    for (var t = 0; t < 4000 && pegs < target; t++) {
      final a = r.nextInt(n * n);
      if (cells[a] != 1) continue;
      final x = a % n, y = a ~/ n;
      final (dx, dy) = const [(1, 0), (-1, 0), (0, 1), (0, -1)][r.nextInt(4)];
      final bx = x + dx, by = y + dy, cx = x + 2 * dx, cy = y + 2 * dy;
      if (cx < 0 || cy < 0 || cx >= n || cy >= n) continue;
      final b = by * n + bx, c = cy * n + cx;
      if (cells[b] != 0 || cells[c] != 0) continue;
      cells[a] = 0;
      cells[b] = 1;
      cells[c] = 1;
      pegs++;
    }
    if (pegs < 2) return make(difficulty, r);
    return PLevel(kind: id, w: n, h: n, clues: const [], extra: [cells], solCells: goal, givens: const []);
  }

  @override
  void paintOver(Canvas c, PLevel lv, PState s, Rect Function(int i) cell, double cs) {
    for (var i = 0; i < lv.n; i++) {
      final v = s.cells[i];
      if (v < 0) continue;
      final r = cell(i);
      c.drawCircle(r.center, cs * 0.18, Paint()..color = const Color(0x55302A26));
      if (v == 1) {
        final sel = s.aux.isNotEmpty && s.aux[0] == i;
        c.drawCircle(r.center, cs * 0.34, Paint()..color = sel ? const Color(0xFFEDAE49) : const Color(0xFFC0603A));
        c.drawCircle(r.center - Offset(cs * 0.1, cs * 0.1), cs * 0.08, Paint()..color = const Color(0x66FFFFFF));
      }
    }
  }
}

// ======================================================================
// Sayı eşleştirme (Ona tamamla)

/// Eşit ya da toplamı 10 olan iki sayıyı seç: aynı satır/sütun/çaprazda
/// aralarında yalnız silinmiş hücre olmalı ya da okuma sırasında
/// ardışık olmalı. Boşalan satır kalkar. Alttaki düğme kalan sayıları
/// sona ekler (sınırlı). Hücre: 1-9, 0 silinmiş, -1 boş yer.
/// aux[0]: seçili hücre, aux[1]: kalan ekleme hakkı.
class NumberMatchKind extends MoveKind {
  const NumberMatchKind();
  @override
  String get id => 'sayi-eslestirme';

  @override
  PState initial(PLevel lv) => PState(List.of(lv.extra[0]), List.filled(lv.linkCount, 0), List.filled(lv.borderCount, 0), [-1, 3]);

  bool connected(PLevel lv, List<int> c, int a, int b) {
    if (a == b) return false;
    final lo = math.min(a, b), hi = math.max(a, b);
    // okuma sırası
    var clear = true;
    for (var k = lo + 1; k < hi; k++) {
      if (c[k] > 0) {
        clear = false;
        break;
      }
    }
    if (clear) return true;
    final ax = a % lv.w, ay = a ~/ lv.w, bx = b % lv.w, by = b ~/ lv.w;
    final dx = (bx - ax).sign, dy = (by - ay).sign;
    if (!(ax == bx || ay == by || (bx - ax).abs() == (by - ay).abs())) return false;
    var x = ax + dx, y = ay + dy;
    while (x != bx || y != by) {
      if (c[y * lv.w + x] > 0) return false;
      x += dx;
      y += dy;
    }
    return true;
  }

  bool match(List<int> c, int a, int b) => c[a] > 0 && c[b] > 0 && (c[a] == c[b] || c[a] + c[b] == 10);

  @override
  bool act(PLevel lv, PState s, int i) {
    if (s.cells[i] <= 0) return false;
    final sel = s.aux[0];
    if (sel < 0 || sel == i) {
      s.aux[0] = sel == i ? -1 : i;
      return true;
    }
    if (match(s.cells, sel, i) && connected(lv, s.cells, sel, i)) {
      s.cells[sel] = 0;
      s.cells[i] = 0;
      s.aux[0] = -1;
      _collapse(lv, s);
      return true;
    }
    s.aux[0] = i;
    return true;
  }

  void _collapse(PLevel lv, PState s) {
    final rows = <List<int>>[];
    for (var y = 0; y < lv.h; y++) {
      final row = s.cells.sublist(y * lv.w, y * lv.w + lv.w);
      if (row.every((v) => v == 0)) continue;
      rows.add(row);
    }
    final flat = [for (final r in rows) ...r];
    for (var i = 0; i < lv.n; i++) {
      s.cells[i] = i < flat.length ? flat[i] : -1;
    }
  }

  @override
  bool actOutside(PLevel lv, PState s, int side, int index) {
    if (side != 2 || s.aux[1] <= 0) return false;
    final rest = s.cells.where((v) => v > 0).toList();
    var end = s.cells.lastIndexWhere((v) => v >= 0) + 1;
    for (final v in rest) {
      if (end >= lv.n) break;
      s.cells[end++] = v;
    }
    s.aux[1]--;
    return true;
  }

  @override
  (double, double, double, double) margins(PLevel lv) => (0, 0, 0.9, 0);

  @override
  String outside(PLevel lv, PState s, int side, int index) => side == 2 && index == lv.w ~/ 2 ? '+${s.aux.length > 1 ? s.aux[1] : 0}' : '';

  @override
  bool solved(PLevel lv, PState s) => !s.cells.any((v) => v > 0);

  @override
  bool failed(PLevel lv, PState s) {
    if (solved(lv, s) || (s.aux.length > 1 && s.aux[1] > 0)) return false;
    for (var a = 0; a < lv.n; a++) {
      if (s.cells[a] <= 0) continue;
      for (var b = a + 1; b < lv.n; b++) {
        if (match(s.cells, a, b) && connected(lv, s.cells, a, b)) return false;
      }
    }
    return true;
  }

  @override
  PLevel make(int difficulty, SeededRandom r) {
    const w = 9;
    final pairs = const [10, 12, 14, 16, 18, 20, 22, 24, 26, 27][difficulty - 1];
    final seq = <int>[];
    for (var k = 0; k < pairs; k++) {
      final a = 1 + r.nextInt(9);
      final b = r.chance(0.5) ? a : 10 - a;
      final pos = seq.isEmpty ? 0 : r.nextInt(seq.length + 1);
      seq.insertAll(pos, r.chance(0.5) ? [a, b] : [b, a]);
    }
    final h = (seq.length / w).ceil() + 4;
    final cells = [for (var i = 0; i < w * h; i++) i < seq.length ? seq[i] : -1];
    return PLevel(kind: id, w: w, h: h, clues: const [], extra: [cells], solCells: List.filled(w * h, -1), givens: const []);
  }

  @override
  void paintOver(Canvas c, PLevel lv, PState s, Rect Function(int i) cell, double cs) {
    for (var i = 0; i < lv.n; i++) {
      final v = s.cells[i];
      if (v < 0) continue;
      final r = cell(i);
      final sel = s.aux.isNotEmpty && s.aux[0] == i;
      c.drawRRect(RRect.fromRectAndRadius(r.deflate(cs * 0.05), Radius.circular(cs * 0.12)),
          Paint()..color = sel ? const Color(0xFFEDAE49) : (v == 0 ? const Color(0x22000000) : const Color(0xFFF6EBD9)));
      if (v > 0) smallText(c, '$v', r.center, cs * 0.5, expColor(3 + v));
    }
  }
}

// ======================================================================
// Mayın tarlası

/// Mayınsız hücreleri aç; sayı komşu mayın sayısıdır. Uzun bas: bayrak.
/// Tahmin gerektirmeyen üretim. extra[0]: mayınlar; extra[1][0]: başlangıç.
/// Hücre: 0 kapalı, 1 açık, 2 bayrak. aux[0]: patlama (1).
class MinesKind extends MoveKind {
  const MinesKind();
  @override
  String get id => 'mayin-tarlasi';

  int count(PLevel lv, int i) => lv.neighbors(i, diag: true).where((nb) => lv.extra[0][nb] == 1).length;

  void reveal(PLevel lv, List<int> c, int i) {
    final q = [i];
    while (q.isNotEmpty) {
      final x = q.removeLast();
      if (c[x] == 1) continue;
      c[x] = 1;
      if (count(lv, x) == 0) {
        for (final nb in lv.neighbors(x, diag: true)) {
          if (c[nb] == 0 && lv.extra[0][nb] == 0) q.add(nb);
        }
      }
    }
  }

  @override
  PState initial(PLevel lv) {
    final c = List.filled(lv.n, 0);
    reveal(lv, c, lv.extra[1][0]);
    return PState(c, List.filled(lv.linkCount, 0), List.filled(lv.borderCount, 0), [0]);
  }

  @override
  bool act(PLevel lv, PState s, int i) {
    if (s.cells[i] == 2) return false;
    if (s.cells[i] == 1) {
      // akor: bayraklar tamamsa komşuları aç
      final nbs = lv.neighbors(i, diag: true);
      if (nbs.where((nb) => s.cells[nb] == 2).length != count(lv, i)) return false;
      var any = false;
      for (final nb in nbs) {
        if (s.cells[nb] != 0) continue;
        any = true;
        if (lv.extra[0][nb] == 1) {
          s.aux[0] = 1;
          s.cells[nb] = 1;
        } else {
          reveal(lv, s.cells, nb);
        }
      }
      return any;
    }
    if (lv.extra[0][i] == 1) {
      s.aux[0] = 1;
      s.cells[i] = 1;
      return true;
    }
    reveal(lv, s.cells, i);
    return true;
  }

  @override
  bool actAlt(PLevel lv, PState s, int i) {
    if (s.cells[i] == 1) return false;
    s.cells[i] = s.cells[i] == 2 ? 0 : 2;
    return true;
  }

  @override
  bool failed(PLevel lv, PState s) => s.aux.isNotEmpty && s.aux[0] == 1;

  @override
  bool solved(PLevel lv, PState s) {
    if (s.aux.isNotEmpty && s.aux[0] == 1) return false;
    for (var i = 0; i < lv.n; i++) {
      if (lv.extra[0][i] == 0 && s.cells[i] != 1) return false;
    }
    return true;
  }

  /// Basit mantıkla (tek nokta ve alt küme kuralları) çözülebilir mi.
  bool logicSolvable(PLevel lv) {
    final c = List.filled(lv.n, 0);
    reveal(lv, c, lv.extra[1][0]);
    final flag = List.filled(lv.n, false);
    var progress = true;
    while (progress) {
      progress = false;
      for (var i = 0; i < lv.n; i++) {
        if (c[i] != 1) continue;
        final nbs = lv.neighbors(i, diag: true);
        final hidden = nbs.where((nb) => c[nb] == 0 && !flag[nb]).toList();
        if (hidden.isEmpty) continue;
        final flags = nbs.where((nb) => flag[nb]).length;
        final need = count(lv, i) - flags;
        if (need == 0) {
          for (final h in hidden) {
            reveal(lv, c, h);
          }
          progress = true;
        } else if (need == hidden.length) {
          for (final h in hidden) {
            flag[h] = true;
          }
          progress = true;
        } else {
          // alt küme: komşu açık hücre j'nin gizlileri i'ninkileri kapsıyorsa
          for (final j in nbs) {
            if (c[j] != 1) continue;
            final hj = lv.neighbors(j, diag: true).where((nb) => c[nb] == 0 && !flag[nb]).toSet();
            if (hj.length <= hidden.length || !hidden.every(hj.contains)) continue;
            final needJ = count(lv, j) - lv.neighbors(j, diag: true).where((nb) => flag[nb]).length;
            final rest = hj.difference(hidden.toSet());
            if (needJ - need == 0) {
              for (final h in rest) {
                reveal(lv, c, h);
              }
              progress = true;
            } else if (needJ - need == rest.length) {
              for (final h in rest) {
                flag[h] = true;
              }
              progress = true;
            }
          }
        }
      }
    }
    for (var i = 0; i < lv.n; i++) {
      if (lv.extra[0][i] == 0 && c[i] != 1) return false;
    }
    return true;
  }

  @override
  PLevel make(int difficulty, SeededRandom r) {
    final (w, h, m) = const [(6, 6, 5), (7, 7, 7), (8, 8, 10), (8, 8, 12), (9, 9, 14), (9, 10, 17), (10, 10, 19), (10, 12, 23), (12, 12, 28), (12, 14, 34)][difficulty - 1];
    PLevel? last;
    for (var attempt = 0; attempt < 120; attempt++) {
      final start = r.nextInt(w * h);
      final probe = PLevel(kind: id, w: w, h: h, clues: const [], givens: const []);
      final safe = {start, ...probe.neighbors(start, diag: true)};
      final mines = List.filled(w * h, 0);
      var placed = 0;
      for (final i in shuffled(w * h, r)) {
        if (placed >= m) break;
        if (safe.contains(i)) continue;
        mines[i] = 1;
        placed++;
      }
      final lv = PLevel(kind: id, w: w, h: h, clues: const [], extra: [mines, [start]], solCells: const [], givens: const []);
      last = lv;
      if (logicSolvable(lv)) break;
    }
    final lv = last!;
    final goal = [for (var i = 0; i < w * h; i++) lv.extra[0][i] == 0 ? 1 : 0];
    return PLevel(kind: id, w: w, h: h, clues: const [], extra: lv.extra, solCells: goal, givens: const []);
  }

  @override
  bool ok(PLevel lv, PState s, bool complete) {
    for (var i = 0; i < lv.n; i++) {
      if (lv.extra[0][i] == 0 && s.cells[i] != 1) return false;
    }
    return true;
  }

  @override
  void paintOver(Canvas c, PLevel lv, PState s, Rect Function(int i) cell, double cs) {
    final boom = s.aux.isNotEmpty && s.aux[0] == 1;
    for (var i = 0; i < lv.n; i++) {
      final r = cell(i).deflate(cs * 0.04);
      final v = s.cells[i];
      if (v == 1) {
        c.drawRect(r, Paint()..color = const Color(0xFFF1E6D3));
        if (lv.extra[0][i] == 1) {
          c.drawCircle(r.center, cs * 0.28, Paint()..color = const Color(0xFF2B2B33));
          continue;
        }
        final n = count(lv, i);
        if (n > 0) smallText(c, '$n', r.center, cs * 0.5, expColor(8 + n));
      } else {
        c.drawRRect(RRect.fromRectAndRadius(r, Radius.circular(cs * 0.1)), Paint()..color = const Color(0xFF9DB5A0));
        if (v == 2) {
          final p = Path()
            ..moveTo(r.center.dx - cs * 0.1, r.center.dy - cs * 0.25)
            ..lineTo(r.center.dx + cs * 0.22, r.center.dy - cs * 0.12)
            ..lineTo(r.center.dx - cs * 0.1, r.center.dy)
            ..close();
          c.drawPath(p, Paint()..color = const Color(0xFFD1495B));
          c.drawLine(Offset(r.center.dx - cs * 0.1, r.center.dy - cs * 0.25), Offset(r.center.dx - cs * 0.1, r.center.dy + cs * 0.25),
              Paint()..color = const Color(0xFF3A3548)..strokeWidth = cs * 0.05);
        }
        if (boom && lv.extra[0][i] == 1) c.drawCircle(r.center, cs * 0.24, Paint()..color = const Color(0xFF2B2B33));
      }
    }
  }

  @override
  String status(PLevel lv, PState s, String lang) => '✹ ${lv.extra[0].where((v) => v == 1).length - s.cells.where((v) => v == 2).length}';
}

// ======================================================================
// Kara kutu

/// Kutudaki gizli topları bul. Kenara dokunarak ışın gönder: H (topa
/// çarptı), R (geri döndü) ya da aynı harfle çıktığı yer. Topları
/// hücrelere işaretle; işaret sayısı top sayısına ulaşınca denetlenir.
/// extra[0]: toplar. aux: 4n kenar sonucu + sayaç.
class BlackBoxKind extends MoveKind {
  const BlackBoxKind();
  @override
  String get id => 'kara-kutu';

  int balls(PLevel lv) => lv.extra[0].where((v) => v == 1).length;

  @override
  PState initial(PLevel lv) => PState(List.filled(lv.n, 0), List.filled(lv.linkCount, 0), List.filled(lv.borderCount, 0), List.filled(4 * lv.w + 1, 0));

  int _edge(PLevel lv, int side, int index) => side * lv.w + index;

  /// Işın: sonuç (-1 çarpma, -2 geri dönme, aksi çıkış kenarı).
  int fire(PLevel lv, int side, int index) {
    final n = lv.w;
    bool ball(int x, int y) => x >= 0 && y >= 0 && x < n && y < n && lv.extra[0][y * n + x] == 1;
    var (x, y, dx, dy) = switch (side) { 0 => (index, -1, 0, 1), 2 => (index, n, 0, -1), 1 => (-1, index, 1, 0), _ => (n, index, -1, 0) };
    // giriş anında yansıma
    final fx = x + dx, fy = y + dy;
    if (ball(fx, fy)) return -1;
    if (ball(fx + dy, fy + dx) || ball(fx - dy, fy - dx)) return -2;
    for (var step = 0; step < 400; step++) {
      final nx = x + dx, ny = y + dy;
      if (ball(nx, ny)) return -1;
      final l = ball(nx + dy, ny + dx) , rr = ball(nx - dy, ny - dx);
      if (l && rr) {
        dx = -dx;
        dy = -dy;
        continue;
      }
      if (l) {
        final t = dx;
        dx = -dy;
        dy = -t;
        continue;
      }
      if (rr) {
        final t = dx;
        dx = dy;
        dy = t;
        continue;
      }
      x = nx;
      y = ny;
      if (x < 0) return _edge(lv, 1, y);
      if (x >= n) return _edge(lv, 3, y);
      if (y < 0) return _edge(lv, 0, x);
      if (y >= n) return _edge(lv, 2, x);
    }
    return -2;
  }

  @override
  bool actOutside(PLevel lv, PState s, int side, int index) {
    final e = _edge(lv, side, index);
    if (s.aux[e] != 0) return false;
    final res = fire(lv, side, index);
    if (res < 0) {
      s.aux[e] = res;
    } else if (res == e) {
      s.aux[e] = -2;
    } else {
      s.aux[4 * lv.w]++;
      s.aux[e] = s.aux[4 * lv.w];
      s.aux[res] = s.aux[4 * lv.w];
    }
    return true;
  }

  @override
  bool act(PLevel lv, PState s, int i) {
    s.cells[i] = s.cells[i] == 1 ? 0 : 1;
    return true;
  }

  @override
  bool solved(PLevel lv, PState s) {
    for (var i = 0; i < lv.n; i++) {
      if ((s.cells[i] == 1) != (lv.extra[0][i] == 1)) return false;
    }
    return true;
  }

  @override
  bool ok(PLevel lv, PState s, bool complete) => solved(lv, s);

  @override
  PLevel make(int difficulty, SeededRandom r) {
    final n = const [5, 5, 6, 6, 7, 7, 8, 8, 8, 8][difficulty - 1];
    final k = const [2, 3, 3, 4, 4, 4, 5, 5, 6, 6][difficulty - 1];
    final b = List.filled(n * n, 0);
    for (final i in shuffled(n * n, r).take(k)) {
      b[i] = 1;
    }
    return PLevel(kind: id, w: n, h: n, clues: const [], extra: [b], solCells: b, givens: const []);
  }

  @override
  (double, double, double, double) margins(PLevel lv) => (0.8, 0.8, 0.8, 0.8);

  @override
  String outside(PLevel lv, PState s, int side, int index) {
    if (s.aux.isEmpty) return '·';
    final v = s.aux[_edge(lv, side, index)];
    if (v == 0) return '·';
    if (v == -1) return 'H';
    if (v == -2) return 'R';
    return String.fromCharCode(64 + v);
  }

  @override
  bool get gridLines => true;

  @override
  void paintOver(Canvas c, PLevel lv, PState s, Rect Function(int i) cell, double cs) {
    for (var i = 0; i < lv.n; i++) {
      if (s.cells[i] == 1) c.drawCircle(cell(i).center, cs * 0.3, Paint()..color = const Color(0xFF3F88C5));
    }
  }

  @override
  String status(PLevel lv, PState s, String lang) => '● ${s.cells.where((v) => v == 1).length} / ${balls(lv)}';
}

// ======================================================================
// Kod kırıcı

/// Gizli renk dizisini bul. Etkin satırdaki deliklere dokunarak renk seç,
/// sağdaki düğmeyle dene: siyah işaret doğru renk doğru yer, beyaz doğru
/// renk yanlış yer. extra[0]: gizli kod. aux[0]: etkin satır; aux[1..]:
/// satır başına (tam, kısmi).
class CodeKind extends MoveKind {
  const CodeKind();
  @override
  String get id => 'kod-kirici';

  int len(PLevel lv) => lv.w - 1;
  int colors(PLevel lv) => lv.param;

  @override
  PState initial(PLevel lv) => PState(List.filled(lv.n, 0), List.filled(lv.linkCount, 0), List.filled(lv.borderCount, 0), [0, ...List.filled(lv.h * 2, 0)]);

  (int, int) score(List<int> guess, List<int> code) {
    var exact = 0;
    final cg = <int, int>{}, cc = <int, int>{};
    for (var k = 0; k < code.length; k++) {
      if (guess[k] == code[k]) {
        exact++;
      } else {
        cg[guess[k]] = (cg[guess[k]] ?? 0) + 1;
        cc[code[k]] = (cc[code[k]] ?? 0) + 1;
      }
    }
    var part = 0;
    for (final e in cg.entries) {
      part += math.min(e.value, cc[e.key] ?? 0);
    }
    return (exact, part);
  }

  @override
  bool act(PLevel lv, PState s, int i) {
    final row = s.aux[0];
    final x = i % lv.w, y = i ~/ lv.w;
    if (y != row || row >= lv.h) return false;
    if (x < len(lv)) {
      s.cells[i] = s.cells[i] % colors(lv) + 1;
      return true;
    }
    final guess = [for (var k = 0; k < len(lv); k++) s.cells[y * lv.w + k]];
    if (guess.contains(0)) return false;
    final (e, p) = score(guess, lv.extra[0]);
    s.aux[1 + row * 2] = e;
    s.aux[2 + row * 2] = p;
    s.aux[0] = row + 1;
    return true;
  }

  @override
  bool actAlt(PLevel lv, PState s, int i) {
    final row = s.aux[0];
    if (i ~/ lv.w != row || i % lv.w >= len(lv)) return false;
    s.cells[i] = (s.cells[i] - 2 + colors(lv)) % colors(lv) + 1;
    return true;
  }

  @override
  bool solved(PLevel lv, PState s) {
    final row = s.aux.isEmpty ? 0 : s.aux[0];
    return row > 0 && s.aux[1 + (row - 1) * 2] == len(lv);
  }

  @override
  bool failed(PLevel lv, PState s) => !solved(lv, s) && s.aux.isNotEmpty && s.aux[0] >= lv.h;

  @override
  bool ok(PLevel lv, PState s, bool complete) => true;

  @override
  PLevel make(int difficulty, SeededRandom r) {
    final l = const [3, 3, 4, 4, 4, 4, 5, 5, 5, 5][difficulty - 1];
    final c = const [4, 5, 5, 6, 6, 7, 6, 7, 8, 8][difficulty - 1];
    final rows = const [8, 8, 9, 9, 8, 8, 10, 10, 9, 9][difficulty - 1];
    final code = [for (var k = 0; k < l; k++) 1 + r.nextInt(c)];
    return PLevel(kind: id, w: l + 1, h: rows, clues: const [], extra: [code], solCells: const [], givens: const [], param: c);
  }

  @override
  void paintOver(Canvas c, PLevel lv, PState s, Rect Function(int i) cell, double cs) {
    final active = s.aux.isEmpty ? 0 : s.aux[0];
    for (var y = 0; y < lv.h; y++) {
      if (y == active) c.drawRect(cell(y * lv.w).expandToInclude(cell(y * lv.w + lv.w - 1)), Paint()..color = const Color(0x22EDAE49));
      for (var x = 0; x < len(lv); x++) {
        final i = y * lv.w + x;
        final v = s.cells[i];
        final r = cell(i);
        if (v > 0) {
          c.drawCircle(r.center, cs * 0.34, Paint()..color = puzzleColorAt(v));
        } else {
          c.drawCircle(r.center, cs * 0.12, Paint()..color = const Color(0x33302A26));
        }
      }
      final fr = cell(y * lv.w + lv.w - 1);
      if (y < active) {
        final e = s.aux[1 + y * 2], p = s.aux[2 + y * 2];
        for (var k = 0; k < len(lv); k++) {
          final o = fr.topLeft + Offset(cs * (0.25 + (k % 3) * 0.25), cs * (0.3 + (k ~/ 3) * 0.4));
          final col = k < e ? const Color(0xFF2B2B33) : (k < e + p ? const Color(0xFFFFFFFF) : const Color(0x22302A26));
          c.drawCircle(o, cs * 0.09, Paint()..color = col);
          c.drawCircle(o, cs * 0.09, Paint()..color = const Color(0x66302A26)..style = PaintingStyle.stroke..strokeWidth = 1);
        }
      } else if (y == active) {
        MoveKind.tile(c, fr, const Color(0xFF66A182), '✓', const Color(0xFFFFFFFF));
      }
    }
  }
}

/// Renk numarasından palet rengi.
Color puzzleColorAt(int v) => const [
      Color(0xFFF6EBD9),
      Color(0xFFD1495B),
      Color(0xFF00798C),
      Color(0xFFEDAE49),
      Color(0xFF66A182),
      Color(0xFF8E6C8A),
      Color(0xFF2E4057),
      Color(0xFFB5651D),
      Color(0xFF3F88C5),
    ][v % 9];
