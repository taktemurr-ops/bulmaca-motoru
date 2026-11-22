import 'dart:math' as math;
import 'dart:ui';

import 'package:studio_core/core/rng.dart';

import 'core.dart';
import 'digits.dart';

/// Sayı yolu: 1'den N'ye ardışık sayılar komşu hücrelerde. Komşuluk türe
/// göre: kral (çaprazlar dahil), at hamlesi ya da ok yönü (tabela).
/// clues: -1 hücre, -2 delik. extra[0] (tabela): ok yönü 0..7.
class NumberPathKind extends DigitKind {
  final String kindId;

  /// 0 kral, 1 at, 2 ok yönü
  final int adjacency;
  const NumberPathKind(this.kindId, this.adjacency);

  @override
  String get id => kindId;

  @override
  bool active(PLevel lv, int i) => lv.clues.isEmpty || lv.clues[i] != -2;

  @override
  bool canGive(PLevel lv, int i) => active(lv, i);

  @override
  int maxDigit(PLevel lv, int i) => lv.param;

  @override
  List<List<int>> peersFor(PLevel lv) => [for (var i = 0; i < lv.n; i++) const <int>[]];

  static const _dirs = [(0, -1), (1, -1), (1, 0), (1, 1), (0, 1), (-1, 1), (-1, 0), (-1, -1)];

  bool adjacent(PLevel lv, int a, int b) {
    final ax = a % lv.w, ay = a ~/ lv.w, bx = b % lv.w, by = b ~/ lv.w;
    final dx = bx - ax, dy = by - ay;
    switch (adjacency) {
      case 0:
        return (dx != 0 || dy != 0) && dx.abs() <= 1 && dy.abs() <= 1;
      case 1:
        return (dx.abs() == 1 && dy.abs() == 2) || (dx.abs() == 2 && dy.abs() == 1);
      default:
        if (lv.extra[0][a] < 0) return false;
        final (ux, uy) = _dirs[lv.extra[0][a]];
        if (dx == 0 && dy == 0) return false;
        // b, a'dan ok yönünde herhangi bir uzaklıkta
        if (ux == 0) return dx == 0 && dy.sign == uy;
        if (uy == 0) return dy == 0 && dx.sign == ux;
        return dx.abs() == dy.abs() && dx.sign == ux && dy.sign == uy;
    }
  }

  List<int> nexts(PLevel lv, int a) => [for (var b = 0; b < lv.n; b++) if (active(lv, b) && adjacent(lv, a, b)) b];

  @override
  bool local(PLevel lv, List<int> v, int i) => true;

  @override
  bool consistent(PLevel lv, List<int> v, bool complete) {
    final pos = List.filled(lv.param + 2, -1);
    for (var i = 0; i < lv.n; i++) {
      if (!active(lv, i)) continue;
      final x = v[i];
      if (x <= 0) {
        if (complete) return false;
        continue;
      }
      if (x > lv.param || pos[x] >= 0) return false;
      pos[x] = i;
    }
    for (var k = 1; k < lv.param; k++) {
      if (pos[k] >= 0 && pos[k + 1] >= 0 && !adjacent(lv, pos[k], pos[k + 1])) return false;
    }
    return true;
  }

  @override
  List<int>? padValues(PLevel lv, PState s) {
    final used = {for (var i = 0; i < lv.n; i++) if (active(lv, i)) s.cells[i]};
    return [for (var k = 1; k <= lv.param; k++) if (!used.contains(k)) k];
  }

  @override
  int? countSolutions(PLevel lv, {int limit = 2, int budget = 200000}) {
    final nn = lv.param;
    final pos = List.filled(nn + 2, -1);
    final taken = List.filled(lv.n, false);
    for (var i = 0; i < lv.n; i++) {
      if (lv.givens.isNotEmpty && lv.givens[i] > 0) {
        pos[lv.givens[i]] = i;
        taken[i] = true;
      }
    }
    final fixed = List.of(pos);
    lastFoundSolutions.clear();
    final adj = [for (var i = 0; i < lv.n; i++) active(lv, i) ? nexts(lv, i) : const <int>[]];
    // Uzaklık budaması (yalnız kral/at): k'dan sonraki verilene adım sayısı
    var found = 0, nodes = 0;
    var over = false;
    final nextGiven = List.filled(nn + 2, -1);
    var ng = -1;
    for (var k = nn; k >= 1; k--) {
      nextGiven[k] = ng;
      if (fixed[k] >= 0) ng = k;
    }
    int steps(int a, int b) {
      final ax = a % lv.w, ay = a ~/ lv.w, bx = b % lv.w, by = b ~/ lv.w;
      final dx = (ax - bx).abs(), dy = (ay - by).abs();
      if (adjacency == 0) return math.max(dx, dy);
      if (adjacency == 1) return ((dx + dy) / 3).ceil();
      return 0;
    }

    void go(int k) {
      if (found >= limit || over) return;
      if (k > nn) {
        found++;
        if (lastFoundSolutions.length < 2) {
          final cells = List.filled(lv.n, 0);
          for (var q = 1; q <= nn; q++) {
            if (pos[q] >= 0) cells[pos[q]] = q;
          }
          lastFoundSolutions.add(PState(cells, const [], const []));
        }
        return;
      }
      final prev = pos[k - 1];
      if (fixed[k] >= 0) {
        if (k == 1 || adj[prev].contains(fixed[k])) go(k + 1);
        return;
      }
      final cands = k == 1 ? [for (var i = 0; i < lv.n; i++) if (active(lv, i)) i] : adj[prev];
      for (final c in cands) {
        if (taken[c]) continue;
        final g = nextGiven[k];
        if (g > 0 && adjacency != 2 && steps(c, fixed[g]) > g - k) continue;
        if (++nodes > budget) {
          over = true;
          return;
        }
        taken[c] = true;
        pos[k] = c;
        go(k + 1);
        pos[k] = -1;
        taken[c] = false;
        if (found >= limit || over) return;
      }
    }

    if (fixed[1] >= 0) {
      pos[0] = -1;
    }
    go(1);
    return over ? null : found;
  }

  static (int, int) sizeFor(int d, int adjacency) => adjacency == 1
      ? switch (d) { 1 || 2 => (5, 5), 3 || 4 || 5 => (6, 6), 6 || 7 || 8 => (7, 7), _ => (8, 8) }
      : switch (d) { 1 || 2 => (4, 4), 3 || 4 => (5, 5), 5 || 6 => (6, 6), 7 || 8 => (7, 7), _ => (8, 8) };

  @override
  PLevel make(int difficulty, SeededRandom r) {
    final (w, h) = sizeFor(difficulty, adjacency);
    for (var attempt = 0; attempt < 200; attempt++) {
      final holes = adjacency == 0 && difficulty >= 4 ? r.nextInt(math.max(1, w * h ~/ 10)) : 0;
      final clues = List.filled(w * h, -1);
      for (var k = 0; k < holes; k++) {
        clues[r.nextInt(w * h)] = -2;
      }
      final cells = [for (var i = 0; i < w * h; i++) if (clues[i] != -2) i];
      final total = cells.length;
      // Warnsdorff sezgisiyle rastgele Hamilton yolu
      final path = _hamilton(w, h, clues, r);
      if (path == null || path.length != total) continue;
      final sol = List.filled(w * h, 0);
      for (var k = 0; k < path.length; k++) {
        sol[path[k]] = k + 1;
      }
      var extra = const <List<int>>[];
      if (adjacency == 2) {
        final dirs = List.filled(w * h, 0);
        for (var k = 0; k + 1 < path.length; k++) {
          final a = path[k], b = path[k + 1];
          final dx = (b % w - a % w).sign, dy = (b ~/ w - a ~/ w).sign;
          dirs[a] = _dirs.indexOf((dx, dy));
        }
        dirs[path.last] = -1;
        extra = [dirs];
      }
      final lv = PLevel(kind: id, w: w, h: h, clues: clues, extra: extra, solCells: sol, givens: List.filled(w * h, -1), param: total);
      // Uçlar her zaman verilir.
      final g = List.filled(w * h, -1);
      g[path.first] = 1;
      g[path.last] = total;
      return lv.withGivens(g);
    }
    throw StateError('path');
  }

  List<int>? _hamilton(int w, int h, List<int> clues, SeededRandom r) {
    final total = clues.where((c) => c != -2).length;
    final probe = PLevel(kind: id, w: w, h: h, clues: clues, extra: [List.filled(w * h, 0)], givens: const [], param: total);
    List<int> nb(int a) {
      if (adjacency == 2) {
        // ok türünde komşuluk yolu kral komşuluğu ile kurulur; oklar sonra
        return [
          for (var b = 0; b < w * h; b++)
            if (clues[b] != -2 && b != a && ((b % w - a % w).abs() == 0 || (b ~/ w - a ~/ w).abs() == 0 || (b % w - a % w).abs() == (b ~/ w - a ~/ w).abs()))
              b
        ];
      }
      return [for (var b = 0; b < w * h; b++) if (clues[b] != -2 && adjacent(probe, a, b)) b];
    }

    final adj = [for (var a = 0; a < w * h; a++) clues[a] == -2 ? const <int>[] : nb(a)];
    for (var tries = 0; tries < 40; tries++) {
      final starts = [for (var i = 0; i < w * h; i++) if (clues[i] != -2) i];
      var cur = starts[r.nextInt(starts.length)];
      final used = List.filled(w * h, false)..[cur] = true;
      final path = [cur];
      while (path.length < total) {
        final opts = [for (final b in adj[cur]) if (!used[b]) b];
        if (opts.isEmpty) break;
        // Warnsdorff: en az çıkışlı komşu; eşitlikte rastgele
        var best = <int>[];
        var bestDeg = 1 << 30;
        for (final b in opts) {
          final deg = adj[b].where((c) => !used[c]).length;
          if (deg < bestDeg) {
            bestDeg = deg;
            best = [b];
          } else if (deg == bestDeg) {
            best.add(b);
          }
        }
        cur = adjacency == 2 && r.chance(0.5) ? opts[r.nextInt(opts.length)] : best[r.nextInt(best.length)];
        used[cur] = true;
        path.add(cur);
      }
      if (path.length == total) return path;
    }
    return null;
  }

  @override
  CellLook lookInactive(PLevel lv, PState s, int i) => const CellLook(mark: Mark.hole);

  @override
  CellLook look(PLevel lv, PState s, int i) {
    if (!active(lv, i)) return lookInactive(lv, s, i);
    final v = s.cells[i];
    final given = lv.givens.isNotEmpty && lv.givens[i] >= 0;
    if (adjacency == 2) {
      final d = lv.extra[0][i];
      return CellLook(text: v > 0 ? '$v' : '', tone: given ? 1 : 0, mark: d >= 0 ? Mark.none : Mark.ring);
    }
    if (v <= 0) return const CellLook();
    // Çakışma: aynı sayı iki kez ya da ardışık komşu değil
    var bad = false;
    for (var j = 0; j < lv.n; j++) {
      if (j != i && active(lv, j) && s.cells[j] == v) bad = true;
    }
    return CellLook(text: '$v', tone: bad ? 2 : (given ? 1 : 0));
  }

  @override
  void paintUnder(Canvas c, PLevel lv, PState s, Rect Function(int i) cell, double cs) {
    if (adjacency != 2) {
      // ardışık sayıları ince çizgiyle bağla
      final pos = <int, int>{};
      for (var i = 0; i < lv.n; i++) {
        if (active(lv, i) && s.cells[i] > 0) pos[s.cells[i]] = i;
      }
      final p = Paint()
        ..color = const Color(0x5546A09A)
        ..strokeWidth = cs * 0.12
        ..strokeCap = StrokeCap.round;
      for (final e in pos.entries) {
        final nx = pos[e.key + 1];
        if (nx != null && adjacent(lv, e.value, nx)) c.drawLine(cell(e.value).center, cell(nx).center, p);
      }
      return;
    }
    // Tabela: her hücrede yön oku (köşede küçük)
    for (var i = 0; i < lv.n; i++) {
      final d = lv.extra[0][i];
      if (d < 0) continue;
      final r = cell(i);
      final (ux, uy) = _dirs[d];
      final o = r.center + Offset(ux * cs * 0.3, uy * cs * 0.3);
      final dir = Offset(ux.toDouble(), uy.toDouble());
      final u = dir / dir.distance;
      final nrm = Offset(-u.dy, u.dx);
      final p = Paint()
        ..color = const Color(0xFF6A5D52)
        ..strokeWidth = cs * 0.05
        ..strokeCap = StrokeCap.round;
      c.drawLine(o - u * cs * 0.12, o + u * cs * 0.08, p);
      c.drawLine(o + u * cs * 0.1, o + u * cs * 0.1 - u * cs * 0.1 + nrm * cs * 0.07, p);
      c.drawLine(o + u * cs * 0.1, o + u * cs * 0.1 - u * cs * 0.1 - nrm * cs * 0.07, p);
    }
  }
}

// ======================================================================
// Fillomino

/// Her hücreye bir sayı: aynı sayıdan oluşan her bölgenin büyüklüğü o
/// sayıdır; aynı büyüklükte iki bölge yan yana değmez.
class FillKind extends DigitKind {
  const FillKind();
  @override
  String get id => 'fillomino';

  @override
  List<List<int>> peersFor(PLevel lv) => [for (var i = 0; i < lv.n; i++) const <int>[]];

  @override
  bool local(PLevel lv, List<int> v, int i) {
    final x = v[i];
    if (x <= 0) return true;
    // i'nin bileşeni
    final comp = <int>[i];
    final seen = {i};
    var open = false;
    for (var q = 0; q < comp.length; q++) {
      for (final nb in lv.neighbors(comp[q])) {
        if (v[nb] == x && seen.add(nb)) {
          comp.add(nb);
          if (comp.length > x) return false;
        } else if (v[nb] <= 0) {
          open = true;
        }
      }
    }
    if (comp.length > x) return false;
    if (!open && comp.length < x) return false;
    return true;
  }

  @override
  List<int> touch(PLevel lv, int i) => lv.neighbors(i);

  @override
  bool full(PLevel lv, List<int> v) {
    for (var i = 0; i < lv.n; i++) {
      if (!local(lv, v, i)) return false;
    }
    return true;
  }

  @override
  PLevel make(int difficulty, SeededRandom r) {
    final s = const [5, 5, 6, 6, 7, 7, 8, 8, 9, 10][difficulty - 1];
    final maxSize = difficulty <= 3 ? 4 : (difficulty <= 6 ? 5 : 6);
    for (var attempt = 0; attempt < 400; attempt++) {
      final reg = List.filled(s * s, -1);
      final size = <int, int>{};
      var id = 0;
      var bad = false;
      for (final start in shuffled(s * s, r)) {
        if (reg[start] >= 0) continue;
        final cells = [start];
        reg[start] = id;
        final target = 1 + r.nextInt(maxSize);
        while (cells.length < target) {
          final cand = <int>[];
          for (final c in cells) {
            final x = c % s, y = c ~/ s;
            for (final nb in [if (x > 0) c - 1, if (x < s - 1) c + 1, if (y > 0) c - s, if (y < s - 1) c + s]) {
              if (reg[nb] < 0) cand.add(nb);
            }
          }
          if (cand.isEmpty) break;
          final c = cand[r.nextInt(cand.length)];
          reg[c] = id;
          cells.add(c);
        }
        // komşu bölgelerle aynı büyüklükte olmasın: gerekirse bir hücre daha
        bool clash() {
          for (final c in cells) {
            final x = c % s, y = c ~/ s;
            for (final nb in [if (x > 0) c - 1, if (x < s - 1) c + 1, if (y > 0) c - s, if (y < s - 1) c + s]) {
              if (reg[nb] >= 0 && reg[nb] != id && size[reg[nb]] == cells.length) return true;
            }
          }
          return false;
        }

        var guard = 0;
        while (clash() && guard++ < 4) {
          final cand = <int>[];
          for (final c in cells) {
            final x = c % s, y = c ~/ s;
            for (final nb in [if (x > 0) c - 1, if (x < s - 1) c + 1, if (y > 0) c - s, if (y < s - 1) c + s]) {
              if (reg[nb] < 0) cand.add(nb);
            }
          }
          if (cand.isEmpty || cells.length >= maxSize + 2) break;
          final c = cand[r.nextInt(cand.length)];
          reg[c] = id;
          cells.add(c);
        }
        if (clash()) {
          bad = true;
          break;
        }
        size[id] = cells.length;
        id++;
      }
      if (bad) continue;
      final sol = [for (final g in reg) size[g]!];
      // yeni büyüklükler sonradan komşuyla çakışmış olabilir
      var conflict = false;
      for (var i = 0; i < s * s && !conflict; i++) {
        for (final nb in [if (i % s < s - 1) i + 1, if (i ~/ s < s - 1) i + s]) {
          if (reg[i] != reg[nb] && sol[i] == sol[nb]) conflict = true;
        }
      }
      if (conflict) continue;
      final mx = sol.reduce(math.max);
      return PLevel(kind: this.id, w: s, h: s, clues: const [], solCells: sol, givens: List.filled(s * s, -1), param: mx);
    }
    throw StateError('fillomino');
  }

  @override
  double maxGivenRatio(int difficulty) => 0.75;

  @override
  void paintOver(Canvas c, PLevel lv, PState s, Rect Function(int i) cell, double cs) {
    // farklı sayılı komşular arasına kalın sınır
    final p = Paint()
      ..color = const Color(0xFF3B3A40)
      ..strokeWidth = cs * 0.06;
    for (var i = 0; i < lv.n; i++) {
      final r = cell(i);
      final a = s.cells[i];
      if (i % lv.w < lv.w - 1) {
        final b = s.cells[i + 1];
        if (a > 0 && b > 0 && a != b) c.drawLine(r.topRight, r.bottomRight, p);
      }
      if (i ~/ lv.w < lv.h - 1) {
        final b = s.cells[i + lv.w];
        if (a > 0 && b > 0 && a != b) c.drawLine(r.bottomLeft, r.bottomRight, p);
      }
    }
  }
}

// ======================================================================
// Matematik çengeli

/// 5x5 ızgara: 3x3 sayı hücresi ve aralarında işlemler. Her satır ve
/// sütun soldan sağa / yukarıdan aşağı işlem sırasıyla hesaplanır ve
/// kenardaki sonuca eşit olur. 1-9 rakamlarının her biri bir kez.
/// clues: sayı hücresi -1, işlem hücresi 10+işlem (0 +, 1 −, 2 ×, 3 ÷),
/// boş hücre 20. extra[0]: satır sonuçları (3), extra[1]: sütun sonuçları (3).
class MathCrossKind extends DigitKind {
  const MathCrossKind();
  @override
  String get id => 'matematik-cengeli';

  @override
  bool active(PLevel lv, int i) => lv.clues[i] == -1;

  @override
  List<List<int>> peersFor(PLevel lv) {
    final act = [for (var i = 0; i < lv.n; i++) if (active(lv, i)) i];
    return [for (var i = 0; i < lv.n; i++) active(lv, i) ? [for (final j in act) if (j != i) j] : const <int>[]];
  }

  static int? eval(List<int> nums, List<int> ops) {
    var acc = nums[0];
    for (var k = 0; k < ops.length; k++) {
      final b = nums[k + 1];
      switch (ops[k]) {
        case 0:
          acc += b;
        case 1:
          acc -= b;
        case 2:
          acc *= b;
        default:
          if (b == 0 || acc % b != 0) return null;
          acc ~/= b;
      }
    }
    return acc;
  }

  List<int> _rowCells(int k) => [k * 2 * 5, k * 2 * 5 + 2, k * 2 * 5 + 4];
  List<int> _rowOps(PLevel lv, int k) => [lv.clues[k * 10 + 1] - 10, lv.clues[k * 10 + 3] - 10];
  List<int> _colCells(int k) => [k * 2, 10 + k * 2, 20 + k * 2];
  List<int> _colOps(PLevel lv, int k) => [lv.clues[5 + k * 2] - 10, lv.clues[15 + k * 2] - 10];

  @override
  bool local(PLevel lv, List<int> v, int i) {
    if (!active(lv, i)) return true;
    final x = i % 5, y = i ~/ 5;
    final rk = y ~/ 2, ck = x ~/ 2;
    final rv = [for (final c in _rowCells(rk)) v[c]];
    if (rv.every((a) => a > 0) && eval(rv, _rowOps(lv, rk)) != lv.extra[0][rk]) return false;
    final cv = [for (final c in _colCells(ck)) v[c]];
    if (cv.every((a) => a > 0) && eval(cv, _colOps(lv, ck)) != lv.extra[1][ck]) return false;
    return true;
  }

  @override
  PLevel make(int difficulty, SeededRandom r) {
    for (var attempt = 0; attempt < 400; attempt++) {
      final perm = shuffled(9, r).map((x) => x + 1).toList();
      final clues = List.filled(25, 20);
      final sol = List.filled(25, 0);
      for (var k = 0; k < 9; k++) {
        final c = (k ~/ 3) * 10 + (k % 3) * 2;
        clues[c] = -1;
        sol[c] = perm[k];
      }
      final maxOp = difficulty <= 2 ? 2 : (difficulty <= 5 ? 3 : 4);
      for (final c in [1, 3, 11, 13, 21, 23, 5, 7, 9, 15, 17, 19]) {
        clues[c] = 10 + r.nextInt(maxOp);
      }
      final lv0 = PLevel(kind: id, w: 5, h: 5, clues: clues, extra: [List.filled(3, 0), List.filled(3, 0)], givens: List.filled(25, -1), param: 9);
      final rows = <int>[], cols = <int>[];
      var bad = false;
      for (var k = 0; k < 3; k++) {
        final rv = eval([for (final c in _rowCells(k)) sol[c]], _rowOps(lv0, k));
        final cv = eval([for (final c in _colCells(k)) sol[c]], _colOps(lv0, k));
        if (rv == null || cv == null || rv < 0 || cv < 0) bad = true;
        rows.add(rv ?? 0);
        cols.add(cv ?? 0);
      }
      if (bad) continue;
      return PLevel(kind: id, w: 5, h: 5, clues: clues, extra: [rows, cols], solCells: sol, givens: List.filled(25, -1), param: 9);
    }
    throw StateError('math');
  }

  @override
  double extraGivenRatio(int difficulty) => difficulty <= 3 ? 0.25 : 0;

  @override
  int reduceTries(int difficulty) => 9;

  @override
  CellLook lookInactive(PLevel lv, PState s, int i) {
    final c = lv.clues[i];
    if (c >= 10 && c < 20) return CellLook(text: const ['+', '−', '×', '÷'][c - 10], tone: 1);
    return const CellLook();
  }

  @override
  (double, double, double, double) margins(PLevel lv) => (0, 0, 1.0, 1.0);

  @override
  String outside(PLevel lv, PState s, int side, int index) {
    if (side == 3 && index.isEven) return '= ${lv.extra[0][index ~/ 2]}';
    if (side == 2 && index.isEven) return '${lv.extra[1][index ~/ 2]}';
    return '';
  }

  @override
  bool get gridLines => false;

  @override
  void paintUnder(Canvas c, PLevel lv, PState s, Rect Function(int i) cell, double cs) {
    for (var i = 0; i < lv.n; i++) {
      if (!active(lv, i)) continue;
      final r = cell(i).deflate(cs * 0.06);
      c.drawRRect(RRect.fromRectAndRadius(r, Radius.circular(cs * 0.14)), Paint()..color = const Color(0x22C26A3E));
      c.drawRRect(
          RRect.fromRectAndRadius(r, Radius.circular(cs * 0.14)),
          Paint()
            ..style = PaintingStyle.stroke
            ..color = const Color(0x88C26A3E)
            ..strokeWidth = cs * 0.03);
    }
  }
}
