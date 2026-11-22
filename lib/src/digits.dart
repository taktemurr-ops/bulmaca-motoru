import 'dart:math' as math;
import 'dart:ui';

import 'package:studio_core/core/rng.dart';

import 'core.dart';

/// Rakam yerleştirilen bulmacaların ortak tabanı: hızlı çözücü (aday
/// maskeleri, en az adaylı hücre önce) ve ortak görünüş.
abstract class DigitKind extends PuzzleKind {
  const DigitKind();

  @override
  int get solveBudget => 150000;

  @override
  CellInput get cellInput => CellInput.digits;

  @override
  int cellStates(PLevel lv) => lv.param + 1;

  /// Rakam alan hücre mi (siyah/ipucu hücreleri değil).
  bool active(PLevel lv, int i) => lv.clues.isEmpty || lv.clues[i] < 0;

  int maxDigit(PLevel lv, int i) => lv.param;

  /// Birbirinden farklı olması gereken hücreler.
  List<List<int>> peersFor(PLevel lv);

  /// [i] hücresine dokunan kısıtlar (v: 0 bilinmeyen).
  bool local(PLevel lv, List<int> v, int i);

  /// Tam doldurulmuş ızgarada ek denetim.
  bool full(PLevel lv, List<int> v) => true;

  static final _peerCache = Expando<List<List<int>>>();
  List<List<int>> peers(PLevel lv) => _peerCache[lv] ??= peersFor(lv);

  @override
  bool canGive(PLevel lv, int i) => active(lv, i);

  @override
  bool tapCell(PLevel lv, int i) => active(lv, i) && (lv.givens.isEmpty || lv.givens[i] < 0);

  @override
  int reduceTries(int difficulty) => difficulty <= 2 ? 0 : (difficulty <= 5 ? 15 : 35);

  @override
  double extraGivenRatio(int difficulty) => difficulty <= 2 ? 0.3 : (difficulty <= 4 ? 0.15 : 0);

  @override
  bool solved(PLevel lv, PState player) {
    final v = [for (var i = 0; i < lv.n; i++) active(lv, i) ? player.cells[i] : 0];
    for (var i = 0; i < lv.n; i++) {
      if (active(lv, i) && v[i] <= 0) return false;
    }
    return consistent(lv, v, true);
  }

  @override
  bool ok(PLevel lv, PState s, bool complete) =>
      consistent(lv, [for (var i = 0; i < lv.n; i++) active(lv, i) ? math.max(0, s.cells[i]) : 0], complete);

  bool consistent(PLevel lv, List<int> v, bool complete) {
    final ps = peers(lv);
    for (var i = 0; i < lv.n; i++) {
      if (!active(lv, i)) continue;
      final x = v[i];
      if (x <= 0) {
        if (complete) return false;
        continue;
      }
      if (x > maxDigit(lv, i)) return false;
      for (final j in ps[i]) {
        if (j > i && v[j] == x) return false;
      }
    }
    for (var i = 0; i < lv.n; i++) {
      if (!local(lv, v, i)) return false;
    }
    return !complete || full(lv, v);
  }

  int _mask(PLevel lv, List<int> v, int i, List<List<int>> ps) {
    var m = ((1 << maxDigit(lv, i)) - 1) << 1;
    for (final j in ps[i]) {
      final x = v[j];
      if (x > 0) m &= ~(1 << x);
    }
    return m;
  }

  /// Yerleştirme sonrası denetlenecek hücreler (varsayılan: kendisi ve
  /// eşleri; türler genişletebilir).
  bool localAround(PLevel lv, List<int> v, int i) {
    if (!local(lv, v, i)) return false;
    for (final j in touch(lv, i)) {
      if (!local(lv, v, j)) return false;
    }
    return true;
  }

  /// [i] değişince yeniden denetlenecek komşular.
  List<int> touch(PLevel lv, int i) => const [];

  @override
  int? countSolutions(PLevel lv, {int limit = 2, int budget = 200000}) {
    final v = [for (var i = 0; i < lv.n; i++) active(lv, i) && lv.givens.isNotEmpty && lv.givens[i] > 0 ? lv.givens[i] : 0];
    if (!consistent(lv, v, false)) return 0;
    final ps = peers(lv);
    var found = 0, nodes = 0;
    var over = false;
    void go() {
      if (found >= limit || over) return;
      var best = -1, bestCount = 99, bestMask = 0;
      for (var i = 0; i < lv.n; i++) {
        if (!active(lv, i) || v[i] > 0) continue;
        final m = _mask(lv, v, i, ps);
        final c = _bits(m);
        if (c < bestCount) {
          best = i;
          bestCount = c;
          bestMask = m;
          if (c <= 1) break;
        }
      }
      if (best < 0) {
        if (consistent(lv, v, true)) found++;
        return;
      }
      if (bestCount == 0) return;
      for (var x = 1; x <= maxDigit(lv, best); x++) {
        if (bestMask & (1 << x) == 0) continue;
        if (++nodes > budget) {
          over = true;
          return;
        }
        v[best] = x;
        if (localAround(lv, v, best)) go();
        v[best] = 0;
        if (found >= limit || over) return;
      }
    }

    go();
    return over ? null : found;
  }

  /// Rastgele tam doldurma (yapı kurallarıyla).
  List<int>? randomFill(PLevel lv, SeededRandom r, int budget) {
    final v = List.filled(lv.n, 0);
    final ps = peers(lv);
    var nodes = 0;
    bool go() {
      var best = -1, bestCount = 99, bestMask = 0;
      for (var i = 0; i < lv.n; i++) {
        if (!active(lv, i) || v[i] > 0) continue;
        final m = _mask(lv, v, i, ps);
        final c = _bits(m);
        if (c < bestCount) {
          best = i;
          bestCount = c;
          bestMask = m;
          if (c <= 1) break;
        }
      }
      if (best < 0) return full(lv, v);
      for (final o in shuffled(maxDigit(lv, best), r)) {
        final x = o + 1;
        if (bestMask & (1 << x) == 0) continue;
        if (++nodes > budget) return false;
        v[best] = x;
        if (localAround(lv, v, best) && go()) return true;
        v[best] = 0;
        if (nodes > budget) return false;
      }
      return false;
    }

    return go() ? v : null;
  }

  static int _bits(int m) {
    var c = 0;
    while (m != 0) {
      m &= m - 1;
      c++;
    }
    return c;
  }

  /// Satır/sütun eşleri (Latin kare).
  static List<List<int>> latinPeers(int w, int h) => [
        for (var i = 0; i < w * h; i++)
          [
            for (var x = 0; x < w; x++) if (x != i % w) (i ~/ w) * w + x,
            for (var y = 0; y < h; y++) if (y != i ~/ w) y * w + i % w,
          ]
      ];

  @override
  CellLook look(PLevel lv, PState s, int i) {
    if (!active(lv, i)) return lookInactive(lv, s, i);
    final v = s.cells[i];
    if (v <= 0) return const CellLook();
    final given = lv.givens.isNotEmpty && lv.givens[i] >= 0;
    var clash = false;
    if (!given) {
      for (final j in peers(lv)[i]) {
        if (s.cells[j] == v) {
          clash = true;
          break;
        }
      }
    }
    return CellLook(text: digitLabel(v), tone: clash ? 2 : (given ? 1 : 0));
  }

  CellLook lookInactive(PLevel lv, PState s, int i) => const CellLook(mark: Mark.fill);
}

// ======================================================================
// Kakuro

/// Kakuro: beyaz hücrelere 1-9; her yatay/dikey koşunun toplamı ipucudur
/// ve koşuda rakam tekrar etmez. clues: -1 beyaz, 0 siyah.
/// extra[0] yatay toplam (siyah hücrenin sağındaki koşu), extra[1] dikey.
class KakuroKind extends DigitKind {
  const KakuroKind();
  @override
  String get id => 'kakuro';

  static (int, int) _size(int d) => switch (d) { 1 || 2 => (5, 5), 3 || 4 => (6, 6), 5 || 6 => (7, 7), 7 || 8 => (8, 8), _ => (9, 9) };

  List<List<int>> runs(PLevel lv) => _runCache[lv] ??= _runs(lv);
  static final _runCache = Expando<List<List<int>>>();

  /// Her koşu: [toplam, hücreler...]
  List<List<int>> _runs(PLevel lv) {
    final out = <List<int>>[];
    for (var i = 0; i < lv.n; i++) {
      if (lv.clues[i] < 0) continue;
      final x = i % lv.w, y = i ~/ lv.w;
      if (x + 1 < lv.w && lv.clues[i + 1] < 0) {
        final cells = <int>[];
        for (var k = x + 1; k < lv.w && lv.clues[y * lv.w + k] < 0; k++) {
          cells.add(y * lv.w + k);
        }
        out.add([lv.extra[0][i], ...cells]);
      }
      if (y + 1 < lv.h && lv.clues[i + lv.w] < 0) {
        final cells = <int>[];
        for (var k = y + 1; k < lv.h && lv.clues[k * lv.w + x] < 0; k++) {
          cells.add(k * lv.w + x);
        }
        out.add([lv.extra[1][i], ...cells]);
      }
    }
    return out;
  }

  @override
  List<List<int>> peersFor(PLevel lv) {
    final ps = [for (var i = 0; i < lv.n; i++) <int>{}];
    for (final r in runs(lv)) {
      for (final a in r.skip(1)) {
        for (final b in r.skip(1)) {
          if (a != b) ps[a].add(b);
        }
      }
    }
    return [for (final p in ps) p.toList()];
  }

  static final _cellRuns = Expando<List<List<List<int>>>>();
  List<List<List<int>>> cellRuns(PLevel lv) => _cellRuns[lv] ??= () {
        final out = [for (var i = 0; i < lv.n; i++) <List<int>>[]];
        for (final r in runs(lv)) {
          for (final c in r.skip(1)) {
            out[c].add(r);
          }
        }
        return out;
      }();

  @override
  bool local(PLevel lv, List<int> v, int i) {
    if (!active(lv, i)) return true;
    for (final r in cellRuns(lv)[i]) {
      final target = r[0];
      if (target <= 0) continue;
      var acc = 0, unk = 0;
      for (var q = 1; q < r.length; q++) {
        final x = v[r[q]];
        if (x <= 0) {
          unk++;
        } else {
          acc += x;
        }
      }
      if (unk == 0) {
        if (acc != target) return false;
      } else {
        // kalan hücreler en az 1,2,.. en çok 9,8,..
        final minRest = unk * (unk + 1) ~/ 2, maxRest = unk * (19 - unk) ~/ 2;
        if (acc + minRest > target || acc + maxRest < target) return false;
      }
    }
    return true;
  }

  @override
  PLevel make(int difficulty, SeededRandom r) {
    final (w, h) = _size(difficulty);
    for (var attempt = 0; attempt < 300; attempt++) {
      final black = List.filled(w * h, false);
      for (var i = 0; i < w * h; i++) {
        if (i % w == 0 || i ~/ w == 0) black[i] = true;
      }
      // Rastgele siyahlar (simetrik)
      final inner = (w - 1) * (h - 1);
      final want = (inner * (difficulty <= 3 ? 0.22 : 0.18)).round();
      for (var k = 0; k < want; k++) {
        final x = 1 + r.nextInt(w - 1), y = 1 + r.nextInt(h - 1);
        black[y * w + x] = true;
        final sx = w - x, sy = h - y; // 180° simetri (iç bölgede)
        if (sx >= 1 && sx < w && sy >= 1 && sy < h) black[sy * w + sx] = true;
      }
      // Tek hücrelik koşuları kapat; 9'dan uzun koşu olmasın.
      var changed = true;
      while (changed) {
        changed = false;
        for (var i = 0; i < w * h; i++) {
          if (black[i]) continue;
          final x = i % w, y = i ~/ w;
          final l = x > 0 && !black[i - 1], rr = x < w - 1 && !black[i + 1];
          final u = y > 0 && !black[i - w], dn = y < h - 1 && !black[i + w];
          if ((!l && !rr) || (!u && !dn)) {
            black[i] = true;
            changed = true;
          }
        }
      }
      final whites = [for (var i = 0; i < w * h; i++) if (!black[i]) i];
      if (whites.length < inner * 0.4) continue;
      // Beyazlar bağlı olmalı
      final seen = <int>{whites.first};
      final q = [whites.first];
      for (var k = 0; k < q.length; k++) {
        final c = q[k];
        for (final nb in [c - 1, c + 1, c - w, c + w]) {
          if (nb >= 0 && nb < w * h && !black[nb] && (nb ~/ w == c ~/ w || nb % w == c % w) && seen.add(nb)) q.add(nb);
        }
      }
      if (seen.length != whites.length) continue;
      final clues = [for (var i = 0; i < w * h; i++) black[i] ? 0 : -1];
      var lv = PLevel(kind: id, w: w, h: h, clues: clues, extra: [List.filled(w * h, 0), List.filled(w * h, 0)], givens: List.filled(w * h, -1), param: 9);
      final sol = randomFill(lv, r, 20000);
      if (sol == null) continue;
      final across = List.filled(w * h, 0), down = List.filled(w * h, 0);
      for (var i = 0; i < w * h; i++) {
        if (!black[i]) continue;
        final x = i % w, y = i ~/ w;
        for (var k = x + 1; k < w && !black[y * w + k]; k++) {
          across[i] += sol[y * w + k];
        }
        for (var k = y + 1; k < h && !black[k * w + x]; k++) {
          down[i] += sol[k * w + x];
        }
      }
      lv = PLevel(kind: id, w: w, h: h, clues: clues, extra: [across, down], solCells: sol, givens: List.filled(w * h, -1), param: 9);
      return lv;
    }
    throw StateError('kakuro');
  }

  @override
  CellLook lookInactive(PLevel lv, PState s, int i) => const CellLook();

  @override
  void paintUnder(Canvas c, PLevel lv, PState s, Rect Function(int i) cell, double cs) {
    for (var i = 0; i < lv.n; i++) {
      if (active(lv, i)) continue;
      final r = cell(i);
      c.drawRect(r, Paint()..color = const Color(0xFF3B3A40));
      final a = lv.extra[0][i], d = lv.extra[1][i];
      if (a > 0 || d > 0) {
        c.drawLine(r.topLeft, r.bottomRight, Paint()..color = const Color(0xFF8A8790)..strokeWidth = cs * 0.03);
      }
      if (a > 0) _txt(c, '$a', Offset(r.left + cs * 0.68, r.top + cs * 0.3), cs * 0.3);
      if (d > 0) _txt(c, '$d', Offset(r.left + cs * 0.3, r.top + cs * 0.7), cs * 0.3);
    }
  }
}

void _txt(Canvas c, String s, Offset center, double size, {Color color = const Color(0xFFF2EEE6)}) {
  final pb = ParagraphBuilder(ParagraphStyle(fontSize: size, fontWeight: FontWeight.w700, textAlign: TextAlign.center))
    ..pushStyle(TextStyle(color: color, fontSize: size, fontWeight: FontWeight.w700))
    ..addText(s);
  final p = pb.build()..layout(ParagraphConstraints(width: size * 4));
  c.drawParagraph(p, center - Offset(size * 2, p.height / 2));
}

/// Küçük metin (kafes etiketi vb.).
void smallText(Canvas c, String s, Offset center, double size, Color color) => _txt(c, s, center, size, color: color);

// ======================================================================
// Hesap kutusu (KenKen tipi)

/// Latin kare + işlemli kafesler. extra[0]: [işlem, hedef, uzunluk, hücreler]...
/// işlem: 0 toplama, 1 çıkarma, 2 çarpma, 3 bölme, 4 tek hücre.
class CalcBoxKind extends DigitKind {
  const CalcBoxKind();
  @override
  String get id => 'hesap-kutusu';

  static int sizeFor(int d) => const [4, 4, 5, 5, 6, 6, 7, 7, 8, 9][d - 1];

  @override
  List<List<int>> peersFor(PLevel lv) => DigitKind.latinPeers(lv.w, lv.h);

  static final _cageOf = Expando<List<List<int>>>();
  List<List<int>> cageOf(PLevel lv) => _cageOf[lv] ??= () {
        final out = List<List<int>>.filled(lv.n, const []);
        final e = lv.extra[0];
        var k = 0;
        while (k < e.length) {
          final len = e[k + 2];
          final cage = e.sublist(k, k + 3 + len);
          for (var q = 0; q < len; q++) {
            out[e[k + 3 + q]] = cage;
          }
          k += 3 + len;
        }
        return out;
      }();

  static bool cageOk(List<int> cage, List<int> v, int n) {
    final op = cage[0], target = cage[1], len = cage[2];
    final vals = [for (var q = 0; q < len; q++) v[cage[3 + q]]];
    final known = vals.where((x) => x > 0).toList();
    final full = known.length == len;
    switch (op) {
      case 0:
        final s = known.fold<int>(0, (a, b) => a + b);
        return full ? s == target : s + (len - known.length) <= target;
      case 1:
        if (!full) return true;
        return (vals[0] - vals[1]).abs() == target;
      case 2:
        final p = known.fold<int>(1, (a, b) => a * b);
        return full ? p == target : target % p == 0;
      case 3:
        if (!full) return true;
        final a = math.max(vals[0], vals[1]), b = math.min(vals[0], vals[1]);
        return a % b == 0 && a ~/ b == target;
      default:
        return !full || vals[0] == target;
    }
  }

  @override
  bool local(PLevel lv, List<int> v, int i) {
    final cage = cageOf(lv)[i];
    return cage.isEmpty || cageOk(cage, v, lv.w);
  }

  @override
  List<int> touch(PLevel lv, int i) => const [];

  @override
  PLevel make(int difficulty, SeededRandom r) {
    final n = sizeFor(difficulty);
    final base = PLevel(kind: id, w: n, h: n, clues: const [], extra: const [[]], givens: List.filled(n * n, -1), param: n);
    final sol = randomFill(base, r, 50000)!;
    final owner = List.filled(n * n, -1);
    final cages = <int>[];
    for (final start in shuffled(n * n, r)) {
      if (owner[start] >= 0) continue;
      final cells = [start];
      owner[start] = start;
      final target = difficulty <= 3 ? 1 + r.nextInt(3) : 1 + r.nextInt(4);
      while (cells.length < target) {
        final cand = <int>[];
        for (final c in cells) {
          final x = c % n, y = c ~/ n;
          for (final nb in [if (x > 0) c - 1, if (x < n - 1) c + 1, if (y > 0) c - n, if (y < n - 1) c + n]) {
            if (owner[nb] < 0) cand.add(nb);
          }
        }
        if (cand.isEmpty) break;
        final c = cand[r.nextInt(cand.length)];
        owner[c] = start;
        cells.add(c);
      }
      final vals = [for (final c in cells) sol[c]];
      int op, target2;
      if (cells.length == 1) {
        op = 4;
        target2 = vals[0];
      } else if (cells.length == 2 && r.chance(0.5)) {
        final a = math.max(vals[0], vals[1]), b = math.min(vals[0], vals[1]);
        if (a % b == 0 && r.chance(0.6)) {
          op = 3;
          target2 = a ~/ b;
        } else {
          op = 1;
          target2 = a - b;
        }
      } else {
        final prod = vals.fold<int>(1, (a, b) => a * b);
        if (r.chance(0.4) && prod <= 3000) {
          op = 2;
          target2 = prod;
        } else {
          op = 0;
          target2 = vals.fold<int>(0, (a, b) => a + b);
        }
      }
      cages.addAll([op, target2, cells.length, ...cells]);
    }
    return PLevel(kind: id, w: n, h: n, clues: const [], extra: [cages], solCells: sol, givens: List.filled(n * n, -1), param: n);
  }

  @override
  double extraGivenRatio(int difficulty) => 0;

  @override
  void paintUnder(Canvas c, PLevel lv, PState s, Rect Function(int i) cell, double cs) {
    final e = lv.extra[0];
    var k = 0;
    final edge = Paint()
      ..color = const Color(0xFF3B3A40)
      ..strokeWidth = math.max(2, cs * 0.06)
      ..strokeCap = StrokeCap.square;
    final cageOf = this.cageOf(lv);
    for (var i = 0; i < lv.n; i++) {
      final r = cell(i);
      final x = i % lv.w, y = i ~/ lv.w;
      if (x + 1 < lv.w && !identical(cageOf[i], cageOf[i + 1])) c.drawLine(r.topRight, r.bottomRight, edge);
      if (y + 1 < lv.h && !identical(cageOf[i], cageOf[i + lv.w])) c.drawLine(r.bottomLeft, r.bottomRight, edge);
    }
    while (k < e.length) {
      final op = e[k], target = e[k + 1], len = e[k + 2];
      final first = e.sublist(k + 3, k + 3 + len).reduce(math.min);
      final sym = const ['+', '−', '×', '÷', ''][op];
      final r = cell(first);
      final label = '$target$sym';
      final pb = ParagraphBuilder(ParagraphStyle(fontSize: cs * 0.22))
        ..pushStyle(TextStyle(color: const Color(0xFF3B3A40), fontSize: cs * 0.22, fontWeight: FontWeight.w700))
        ..addText(label);
      final p = pb.build()..layout(ParagraphConstraints(width: cs));
      c.drawParagraph(p, r.topLeft + Offset(cs * 0.07, cs * 0.03));
      k += 3 + len;
    }
  }
}

// ======================================================================
// Futoshiki

/// Latin kare + komşular arası büyüktür işaretleri. extra[0]: [büyük, küçük]...
class InequalityKind extends DigitKind {
  const InequalityKind();
  @override
  String get id => 'futoshiki';

  static int sizeFor(int d) => const [4, 4, 5, 5, 5, 6, 6, 7, 7, 8][d - 1];

  @override
  List<List<int>> peersFor(PLevel lv) => DigitKind.latinPeers(lv.w, lv.h);

  static final _rel = Expando<List<List<(int, bool)>>>();
  List<List<(int, bool)>> rel(PLevel lv) => _rel[lv] ??= () {
        final out = [for (var i = 0; i < lv.n; i++) <(int, bool)>[]];
        final e = lv.extra[0];
        for (var k = 0; k + 1 < e.length; k += 2) {
          out[e[k]].add((e[k + 1], true)); // i > j
          out[e[k + 1]].add((e[k], false)); // i < j
        }
        return out;
      }();

  @override
  bool local(PLevel lv, List<int> v, int i) {
    final x = v[i];
    final n = lv.w;
    for (final (j, greater) in rel(lv)[i]) {
      final y = v[j];
      if (x > 0 && y > 0) {
        if (greater ? x <= y : x >= y) return false;
      } else if (x > 0) {
        if (greater ? x == 1 : x == n) return false;
      }
    }
    return true;
  }

  @override
  List<int> touch(PLevel lv, int i) => [for (final (j, _) in rel(lv)[i]) j];

  @override
  PLevel make(int difficulty, SeededRandom r) {
    final n = sizeFor(difficulty);
    final base = PLevel(kind: id, w: n, h: n, clues: const [], extra: const [[]], givens: List.filled(n * n, -1), param: n);
    final sol = randomFill(base, r, 50000)!;
    final pairs = <int>[];
    final p = difficulty <= 4 ? 0.45 : 0.32;
    for (var i = 0; i < n * n; i++) {
      for (final j in [if (i % n < n - 1) i + 1, if (i ~/ n < n - 1) i + n]) {
        if (r.chance(p)) pairs.addAll(sol[i] > sol[j] ? [i, j] : [j, i]);
      }
    }
    return PLevel(kind: id, w: n, h: n, clues: const [], extra: [pairs], solCells: sol, givens: List.filled(n * n, -1), param: n);
  }

  @override
  void paintOver(Canvas c, PLevel lv, PState s, Rect Function(int i) cell, double cs) {
    final e = lv.extra[0];
    final p = Paint()
      ..color = const Color(0xFF4A4038)
      ..strokeWidth = cs * 0.05
      ..strokeCap = StrokeCap.round;
    for (var k = 0; k + 1 < e.length; k += 2) {
      final a = cell(e[k]).center, b = cell(e[k + 1]).center;
      final m = Offset.lerp(a, b, 0.5)!;
      final dir = (b - a) / (b - a).distance;
      final nrm = Offset(-dir.dy, dir.dx);
      final tip = m + dir * cs * 0.08;
      c.drawLine(tip, tip - dir * cs * 0.15 + nrm * cs * 0.12, p);
      c.drawLine(tip, tip - dir * cs * 0.15 - nrm * cs * 0.12, p);
    }
  }
}

// ======================================================================
// Gökdelenler

/// Latin kare; kenardaki sayı o yönden görülen bina sayısı (yüksek olan
/// alçağı saklar). extra: [üst, alt, sol, sağ] her biri n uzunlukta, 0 yok.
class SkylineKind extends DigitKind {
  const SkylineKind();
  @override
  String get id => 'gokdelenler';

  static int sizeFor(int d) => const [4, 4, 5, 5, 5, 6, 6, 6, 7, 7][d - 1];

  @override
  List<List<int>> peersFor(PLevel lv) => DigitKind.latinPeers(lv.w, lv.h);

  static int seen(List<int> vals) {
    var mx = 0, c = 0;
    for (final x in vals) {
      if (x > mx) {
        mx = x;
        c++;
      }
    }
    return c;
  }

  List<int> _line(PLevel lv, int side, int k) {
    final n = lv.w;
    return switch (side) {
      0 => [for (var y = 0; y < n; y++) y * n + k],
      1 => [for (var y = n - 1; y >= 0; y--) y * n + k],
      2 => [for (var x = 0; x < n; x++) k * n + x],
      _ => [for (var x = n - 1; x >= 0; x--) k * n + x],
    };
  }

  bool _lineOk(PLevel lv, List<int> v, int side, int k) {
    final clue = lv.extra[side][k];
    if (clue <= 0) return true;
    final cells = _line(lv, side, k);
    final vals = [for (final c in cells) v[c]];
    if (vals.every((x) => x > 0)) return seen(vals) == clue;
    // önek: ilk bilinmeyene kadar görülenler en az; en büyük bulunduysa sabit
    var mx = 0, c = 0;
    for (final x in vals) {
      if (x <= 0) break;
      if (x > mx) {
        mx = x;
        c++;
      }
    }
    if (c > clue) return false;
    if (mx == lv.w && c != clue) return false;
    return true;
  }

  @override
  bool local(PLevel lv, List<int> v, int i) {
    final x = i % lv.w, y = i ~/ lv.w;
    return _lineOk(lv, v, 0, x) && _lineOk(lv, v, 1, x) && _lineOk(lv, v, 2, y) && _lineOk(lv, v, 3, y);
  }

  @override
  PLevel make(int difficulty, SeededRandom r) {
    final n = sizeFor(difficulty);
    final base = PLevel(kind: id, w: n, h: n, clues: const [], extra: [List.filled(n, 0), List.filled(n, 0), List.filled(n, 0), List.filled(n, 0)], givens: List.filled(n * n, -1), param: n);
    final sol = randomFill(base, r, 50000)!;
    final keep = difficulty <= 3 ? 1.0 : (difficulty <= 6 ? 0.8 : 0.65);
    final extra = [
      for (var side = 0; side < 4; side++)
        [for (var k = 0; k < n; k++) r.chance(keep) ? seen([for (final c in _line(base, side, k)) sol[c]]) : 0]
    ];
    return PLevel(kind: id, w: n, h: n, clues: const [], extra: extra, solCells: sol, givens: List.filled(n * n, -1), param: n);
  }

  @override
  (double, double, double, double) margins(PLevel lv) => (0.8, 0.8, 0.8, 0.8);

  @override
  String outside(PLevel lv, PState s, int side, int index) {
    // görünüm tarafları: 0 üst, 1 sol, 2 alt, 3 sağ → veri: 0 üst, 2 sol, 1 alt, 3 sağ
    final d = const [0, 2, 1, 3][side];
    final v = lv.extra[d][index];
    return v > 0 ? '$v' : '';
  }
}

// ======================================================================
// Suguru

/// Bölgeler (1-5 hücre); n hücrelik bölgede 1..n bir kez; komşu (çapraz
/// dahil) hücreler aynı olamaz.
class GroupKind extends DigitKind {
  const GroupKind();
  @override
  String get id => 'suguru';

  static (int, int) sizeFor(int d) => switch (d) { 1 || 2 => (5, 5), 3 || 4 => (6, 6), 5 || 6 => (7, 7), 7 || 8 => (8, 8), _ => (9, 9) };

  static final _size = Expando<List<int>>();
  List<int> regionSize(PLevel lv) => _size[lv] ??= () {
        final cnt = <int, int>{};
        for (final g in lv.regions) {
          cnt[g] = (cnt[g] ?? 0) + 1;
        }
        return [for (final g in lv.regions) cnt[g]!];
      }();

  @override
  int maxDigit(PLevel lv, int i) => regionSize(lv)[i];

  @override
  List<List<int>> peersFor(PLevel lv) => [
        for (var i = 0; i < lv.n; i++)
          {
            ...lv.neighbors(i, diag: true),
            for (var j = 0; j < lv.n; j++) if (j != i && lv.regions[j] == lv.regions[i]) j,
          }.toList()
      ];

  @override
  bool local(PLevel lv, List<int> v, int i) => true;

  @override
  PLevel make(int difficulty, SeededRandom r) {
    final (w, h) = sizeFor(difficulty);
    for (var attempt = 0; attempt < 400; attempt++) {
      final reg = _partition(w, h, 5, r);
      final lv0 = PLevel(kind: id, w: w, h: h, clues: const [], regions: reg, givens: List.filled(w * h, -1), param: 5);
      final sol = randomFill(lv0, r, 3000);
      if (sol == null) continue;
      return PLevel(kind: id, w: w, h: h, clues: const [], regions: reg, solCells: sol, givens: List.filled(w * h, -1), param: 5);
    }
    throw StateError('suguru');
  }

  @override
  double extraGivenRatio(int difficulty) => difficulty <= 2 ? 0.2 : 0;
}

/// Izgarayı en çok [maxSize] hücrelik bağlı parçalara böler.
List<int> _partition(int w, int h, int maxSize, SeededRandom r) {
  final reg = List.filled(w * h, -1);
  var id = 0;
  for (final s in shuffled(w * h, r)) {
    if (reg[s] >= 0) continue;
    final target = 1 + r.nextInt(maxSize) + (r.chance(0.6) ? 1 : 0);
    final cells = [s];
    reg[s] = id;
    while (cells.length < math.min(target, maxSize)) {
      final cand = <int>[];
      for (final c in cells) {
        final x = c % w, y = c ~/ w;
        for (final nb in [if (x > 0) c - 1, if (x < w - 1) c + 1, if (y > 0) c - w, if (y < h - 1) c + w]) {
          if (reg[nb] < 0) cand.add(nb);
        }
      }
      if (cand.isEmpty) break;
      final c = cand[r.nextInt(cand.length)];
      reg[c] = id;
      cells.add(c);
    }
    id++;
  }
  return reg;
}

/// Dışa açık bölme yardımcısı.
List<int> partitionGrid(int w, int h, int maxSize, SeededRandom r) => _partition(w, h, maxSize, r);
