import 'dart:math' as math;
import 'dart:ui';

import 'package:studio_core/core/rng.dart';

import 'core.dart';
import 'digits.dart';

/// Kenar çizilen bölge bulmacalarının tabanı. Dış kenarlar sabit çizgi.
abstract class BorderRegionKind extends PuzzleKind {
  const BorderRegionKind();

  @override
  CellInput get cellInput => CellInput.none;

  @override
  bool get usesBorders => true;

  @override
  bool get outerBordersFixed => true;

  @override
  bool get showVertices => true;

  @override
  bool tapCell(PLevel lv, int i) => false;

  @override
  PState initial(PLevel lv) {
    final s = PState.empty(lv);
    for (var e = 0; e < lv.borderCount; e++) {
      final (a, b) = lv.edgeCells(e);
      if (a < 0 || b < 0) s.borders[e] = 1;
    }
    return s;
  }

  /// Kenarlara göre bölgeler (hücre → bölge kimliği).
  static List<int> regionsOf(PLevel lv, List<int> borders) {
    final reg = List.filled(lv.n, -1);
    var id = 0;
    for (var i = 0; i < lv.n; i++) {
      if (reg[i] >= 0) continue;
      reg[i] = id;
      final q = [i];
      for (var k = 0; k < q.length; k++) {
        final c = q[k];
        for (final nb in lv.neighbors(c)) {
          if (reg[nb] >= 0) continue;
          if (borders[lv.edgeBetween(c, nb)] == 1) continue;
          reg[nb] = id;
          q.add(nb);
        }
      }
      id++;
    }
    return reg;
  }

  /// İç kenar çizgileri yalnızca farklı bölgeleri ayırmalı.
  static bool noDangling(PLevel lv, List<int> borders, List<int> reg) {
    for (var e = 0; e < lv.borderCount; e++) {
      if (borders[e] != 1) continue;
      final (a, b) = lv.edgeCells(e);
      if (a >= 0 && b >= 0 && reg[a] == reg[b]) return false;
    }
    return true;
  }

  /// Bölgelerden çözüm kenarları.
  static List<int> bordersFromRegions(PLevel lv, List<int> reg) {
    final b = List.filled(lv.borderCount, 0);
    for (var e = 0; e < lv.borderCount; e++) {
      final (x, y) = lv.edgeCells(e);
      if (x < 0 || y < 0 || reg[x] != reg[y]) b[e] = 1;
    }
    return b;
  }

  @override
  bool solved(PLevel lv, PState player) {
    final b = [for (final v in player.borders) v == 1 ? 1 : 0];
    return ok(lv, PState(player.cells, player.links, b), true);
  }

  @override
  bool get gridLines => true;
}

// ======================================================================
// Galaksiler

/// Izgarayı bölgelere ayır: her bölge tam bir nokta içerir ve o nokta
/// etrafında 180° döndürülünce kendisiyle çakışır. extra[0]: noktalar
/// (çift katlı koordinat: 2x+1 hücre ortası).
class GalaxyKind extends BorderRegionKind {
  const GalaxyKind();
  @override
  String get id => 'galaksiler';

  @override
  bool ok(PLevel lv, PState s, bool complete) {
    final b = s.borders;
    final reg = BorderRegionKind.regionsOf(lv, b);
    if (!BorderRegionKind.noDangling(lv, b, reg)) return false;
    final dots = lv.extra[0];
    final dotReg = <int, int>{};
    for (var k = 0; k + 1 < dots.length; k += 2) {
      final dx = dots[k], dy = dots[k + 1];
      // noktaya değen hücreler aynı bölgede olmalı
      final cells = <int>[];
      for (final cx in {(dx - 1) ~/ 2, dx ~/ 2}) {
        for (final cy in {(dy - 1) ~/ 2, dy ~/ 2}) {
          if (cx >= 0 && cy >= 0 && cx < lv.w && cy < lv.h && (2 * cx + 1 - dx).abs() <= 1 && (2 * cy + 1 - dy).abs() <= 1) cells.add(cy * lv.w + cx);
        }
      }
      final g = reg[cells.first];
      if (cells.any((c) => reg[c] != g)) return false;
      if (dotReg.containsKey(g)) return false;
      dotReg[g] = k;
      // simetri
      for (var i = 0; i < lv.n; i++) {
        if (reg[i] != g) continue;
        final mx = dx - (2 * (i % lv.w) + 1), my = dy - (2 * (i ~/ lv.w) + 1);
        final ox = (dx + mx - 1) ~/ 2, oy = (dy + my - 1) ~/ 2;
        if (ox < 0 || oy < 0 || ox >= lv.w || oy >= lv.h) return false;
        if (reg[oy * lv.w + ox] != g) return false;
      }
    }
    // her bölgede nokta
    for (final g in reg.toSet()) {
      if (!dotReg.containsKey(g)) return false;
    }
    return true;
  }

  @override
  PLevel make(int difficulty, SeededRandom r) {
    final n = const [5, 5, 6, 6, 7, 7, 8, 9, 10, 10][difficulty - 1];
    final reg = List.filled(n * n, -1);
    final dots = <int>[];
    var id = 0;
    int mirror(int c, int dx, int dy) {
      final mx = dx - (2 * (c % n) + 1), my = dy - (2 * (c ~/ n) + 1);
      final ox = (dx + mx - 1) ~/ 2, oy = (dy + my - 1) ~/ 2;
      if (ox < 0 || oy < 0 || ox >= n || oy >= n) return -1;
      return oy * n + ox;
    }

    for (final s in shuffled(n * n, r)) {
      if (reg[s] >= 0) continue;
      // merkez: hücre ortası, kenar ya da köşe (komşu boşsa)
      final x = s % n, y = s ~/ n;
      final opts = <(int, int)>[(2 * x + 1, 2 * y + 1)];
      if (x + 1 < n && reg[s + 1] < 0) opts.add((2 * x + 2, 2 * y + 1));
      if (y + 1 < n && reg[s + n] < 0) opts.add((2 * x + 1, 2 * y + 2));
      if (x + 1 < n && y + 1 < n && reg[s + 1] < 0 && reg[s + n] < 0 && reg[s + n + 1] < 0) opts.add((2 * x + 2, 2 * y + 2));
      final (dx, dy) = opts[r.nextInt(opts.length)];
      final cells = <int>{};
      for (final cx in {(dx - 1) ~/ 2, dx ~/ 2}) {
        for (final cy in {(dy - 1) ~/ 2, dy ~/ 2}) {
          if ((2 * cx + 1 - dx).abs() <= 1 && (2 * cy + 1 - dy).abs() <= 1) cells.add(cy * n + cx);
        }
      }
      for (final c in cells) {
        reg[c] = id;
      }
      final target = 1 + r.nextInt(difficulty <= 4 ? 6 : 10);
      for (var t = 0; t < 40 && cells.length < target; t++) {
        final from = cells.elementAt(r.nextInt(cells.length));
        final fx = from % n, fy = from ~/ n;
        final nbs = [if (fx > 0) from - 1, if (fx < n - 1) from + 1, if (fy > 0) from - n, if (fy < n - 1) from + n];
        final c = nbs[r.nextInt(nbs.length)];
        if (reg[c] >= 0) continue;
        final m = mirror(c, dx, dy);
        if (m < 0 || reg[m] >= 0) continue;
        reg[c] = id;
        reg[m] = id;
        cells.addAll([c, m]);
      }
      dots.addAll([dx, dy]);
      id++;
    }
    final probe = PLevel(kind: id.toString(), w: n, h: n, clues: const [], givens: const []);
    final borders = BorderRegionKind.bordersFromRegions(probe, reg);
    final lv = PLevel(kind: this.id, w: n, h: n, clues: List.filled(n * n, -1), extra: [dots], solBorders: borders, givens: List.filled(n * n, -1), givenBorders: List.filled(probe.borderCount, -1));
    return lv;
  }

  @override
  CellLook look(PLevel lv, PState s, int i) => const CellLook();

  @override
  void paintOver(Canvas c, PLevel lv, PState s, Rect Function(int i) cell, double cs) {
    final d = lv.extra[0];
    final o = cell(0).topLeft;
    for (var k = 0; k + 1 < d.length; k += 2) {
      final p = o + Offset(d[k] * cs / 2, d[k + 1] * cs / 2);
      c.drawCircle(p, cs * 0.14, Paint()..color = const Color(0xFFF6EBD9));
      c.drawCircle(
          p,
          cs * 0.14,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = cs * 0.04
            ..color = const Color(0xFF3B3A40));
    }
  }
}

// ======================================================================
// Çit (Palisade)

/// Izgarayı [param] hücrelik bölgelere ayır; sayı, hücrenin kaç kenarının
/// çizgi olduğudur (dış kenarlar dahil).
class FenceKind extends BorderRegionKind {
  const FenceKind();
  @override
  String get id => 'cit';

  @override
  CellLook look(PLevel lv, PState s, int i) {
    final c = lv.clues[i];
    if (c < 0) return const CellLook();
    final on = lv.cellEdges(i).where((e) => s.borders[e] == 1).length;
    return CellLook(text: '$c', tone: on > c ? 2 : 1);
  }

  @override
  bool ok(PLevel lv, PState s, bool complete) {
    final b = s.borders;
    for (var i = 0; i < lv.n; i++) {
      final c = lv.clues[i];
      if (c >= 0 && lv.cellEdges(i).where((e) => b[e] == 1).length != c) return false;
    }
    final reg = BorderRegionKind.regionsOf(lv, b);
    if (!BorderRegionKind.noDangling(lv, b, reg)) return false;
    final size = <int, int>{};
    for (final g in reg) {
      size[g] = (size[g] ?? 0) + 1;
    }
    return size.values.every((v) => v == lv.param);
  }

  @override
  PLevel make(int difficulty, SeededRandom r) {
    final (w, h, k) = const [(4, 4, 4), (5, 4, 4), (6, 4, 4), (5, 5, 5), (6, 5, 5), (6, 6, 4), (7, 5, 5), (7, 6, 6), (8, 6, 6), (8, 8, 8)][difficulty - 1];
    for (var attempt = 0; attempt < 300; attempt++) {
      final reg = List.filled(w * h, -1);
      var id = 0;
      var bad = false;
      for (var i = 0; i < w * h && !bad; i++) {
        if (reg[i] >= 0) continue;
        final cells = [i];
        reg[i] = id;
        for (var t = 0; t < 60 && cells.length < k; t++) {
          final from = cells[r.nextInt(cells.length)];
          final fx = from % w, fy = from ~/ w;
          final nbs = [if (fx > 0) from - 1, if (fx < w - 1) from + 1, if (fy > 0) from - w, if (fy < h - 1) from + w].where((c) => reg[c] < 0).toList();
          if (nbs.isEmpty) continue;
          final c = nbs[r.nextInt(nbs.length)];
          reg[c] = id;
          cells.add(c);
        }
        if (cells.length < k) bad = true;
        id++;
      }
      if (bad) continue;
      final probe = PLevel(kind: this.id, w: w, h: h, clues: const [], givens: const []);
      final borders = BorderRegionKind.bordersFromRegions(probe, reg);
      final p = difficulty <= 3 ? 0.65 : 0.5;
      final clues = [for (var i = 0; i < w * h; i++) r.chance(p) ? probe.cellEdges(i).where((e) => borders[e] == 1).length : -1];
      return PLevel(kind: this.id, w: w, h: h, clues: clues, solBorders: borders, givens: List.filled(w * h, -1), givenBorders: List.filled(probe.borderCount, -1), param: k);
    }
    throw StateError('palisade');
  }

  @override
  String status(PLevel lv, PState s, String lang) => '▦ ${lv.param}';
}

// ======================================================================
// Dikdörtgenler (Shikaku)

/// Izgarayı dikdörtgenlere böl; her dikdörtgende tek sayı vardır ve sayı
/// dikdörtgenin alanıdır.
class RectKind extends BorderRegionKind {
  const RectKind();
  @override
  String get id => 'dikdortgenler';

  @override
  CellLook look(PLevel lv, PState s, int i) => lv.clues[i] > 0 ? CellLook(text: '${lv.clues[i]}', tone: 1) : const CellLook();

  @override
  bool ok(PLevel lv, PState s, bool complete) {
    final b = s.borders;
    final reg = BorderRegionKind.regionsOf(lv, b);
    if (!BorderRegionKind.noDangling(lv, b, reg)) return false;
    final groups = <int, List<int>>{};
    for (var i = 0; i < lv.n; i++) {
      groups.putIfAbsent(reg[i], () => []).add(i);
    }
    for (final cells in groups.values) {
      final xs = cells.map((c) => c % lv.w), ys = cells.map((c) => c ~/ lv.w);
      final bw = xs.reduce(math.max) - xs.reduce(math.min) + 1, bh = ys.reduce(math.max) - ys.reduce(math.min) + 1;
      if (bw * bh != cells.length) return false;
      final nums = cells.where((c) => lv.clues[c] > 0).toList();
      if (nums.length != 1 || lv.clues[nums.first] != cells.length) return false;
    }
    return true;
  }

  /// Tam örtü sayımı: her sayı için olası dikdörtgenler.
  @override
  int? countSolutions(PLevel lv, {int limit = 2, int budget = 200000}) {
    final nums = [for (var i = 0; i < lv.n; i++) if (lv.clues[i] > 0) i];
    final cand = <List<List<int>>>[];
    for (final c in nums) {
      final area = lv.clues[c];
      final cx = c % lv.w, cy = c ~/ lv.w;
      final list = <List<int>>[];
      for (var rw = 1; rw <= area; rw++) {
        if (area % rw != 0) continue;
        final rh = area ~/ rw;
        for (var x0 = cx - rw + 1; x0 <= cx; x0++) {
          for (var y0 = cy - rh + 1; y0 <= cy; y0++) {
            if (x0 < 0 || y0 < 0 || x0 + rw > lv.w || y0 + rh > lv.h) continue;
            final cells = [for (var y = y0; y < y0 + rh; y++) for (var x = x0; x < x0 + rw; x++) y * lv.w + x];
            if (cells.any((q) => q != c && lv.clues[q] > 0)) continue;
            list.add(cells);
          }
        }
      }
      cand.add(list);
    }
    final used = List.filled(lv.n, false);
    var found = 0, nodes = 0;
    var over = false;
    final order = [for (var k = 0; k < nums.length; k++) k]..sort((a, b) => cand[a].length.compareTo(cand[b].length));
    void go(int k) {
      if (found >= limit || over) return;
      if (k == order.length) {
        if (!used.contains(false)) found++;
        return;
      }
      for (final rect in cand[order[k]]) {
        if (rect.any((q) => used[q])) continue;
        if (++nodes > budget) {
          over = true;
          return;
        }
        for (final q in rect) {
          used[q] = true;
        }
        go(k + 1);
        for (final q in rect) {
          used[q] = false;
        }
        if (found >= limit || over) return;
      }
    }

    go(0);
    return over ? null : found;
  }

  @override
  PLevel make(int difficulty, SeededRandom r) {
    final n = const [5, 5, 6, 7, 7, 8, 9, 10, 11, 12][difficulty - 1];
    for (var attempt = 0; attempt < 400; attempt++) {
      // özyinelemeli rastgele bölme
      final reg = List.filled(n * n, -1);
      var id = 0;
      void cut(int x0, int y0, int x1, int y1) {
        final rw = x1 - x0, rh = y1 - y0;
        final area = rw * rh;
        final maxArea = difficulty <= 3 ? 6 : 10;
        if (area <= maxArea && (area <= 2 || r.chance(0.5)) || (rw == 1 && rh == 1)) {
          for (var y = y0; y < y1; y++) {
            for (var x = x0; x < x1; x++) {
              reg[y * n + x] = id;
            }
          }
          id++;
          return;
        }
        if ((rw >= rh && rw > 1) || rh == 1) {
          final c = x0 + 1 + r.nextInt(rw - 1);
          cut(x0, y0, c, y1);
          cut(c, y0, x1, y1);
        } else {
          final c = y0 + 1 + r.nextInt(rh - 1);
          cut(x0, y0, x1, c);
          cut(x0, c, x1, y1);
        }
      }

      cut(0, 0, n, n);
      final clues = List.filled(n * n, -1);
      final groups = <int, List<int>>{};
      for (var i = 0; i < n * n; i++) {
        groups.putIfAbsent(reg[i], () => []).add(i);
      }
      for (final cells in groups.values) {
        clues[cells[r.nextInt(cells.length)]] = cells.length;
      }
      final probe = PLevel(kind: this.id, w: n, h: n, clues: clues, givens: const []);
      if (countSolutions(probe, budget: 60000) != 1) continue;
      final borders = BorderRegionKind.bordersFromRegions(probe, reg);
      return PLevel(kind: this.id, w: n, h: n, clues: clues, solBorders: borders, givens: List.filled(n * n, -1), givenBorders: List.filled(probe.borderCount, -1));
    }
    throw StateError('shikaku');
  }

  @override
  double maxGivenRatio(int difficulty) => 0;
}

// ======================================================================
// Dominosa

/// 0..k sayılarıyla dolu ızgara; her hücreyi bir komşusuyla domino yap.
/// Her sayı çifti tam bir kez kullanılır. Bağlar dominoları gösterir.
class DominoPairKind extends PuzzleKind {
  const DominoPairKind();
  @override
  String get id => 'dominosa';

  @override
  CellInput get cellInput => CellInput.none;

  @override
  bool get usesLinks => true;

  @override
  bool tapCell(PLevel lv, int i) => false;

  @override
  bool get gridLines => false;

  @override
  CellLook look(PLevel lv, PState s, int i) => CellLook(text: '${lv.clues[i]}', tone: 1);

  @override
  bool ok(PLevel lv, PState s, bool complete) {
    final links = s.links;
    final seen = <int>{};
    final k = lv.param;
    for (var i = 0; i < lv.n; i++) {
      var d = 0, u = 0;
      for (final nb in lv.neighbors(i)) {
        final l = lv.linkBetween(i, nb);
        if (links[l] == 1) d++;
        if (links[l] < 0) u++;
      }
      if (d > 1 || d + u < 1) return false;
    }
    for (var l = 0; l < lv.linkCount; l++) {
      if (links[l] != 1) continue;
      final (a, b) = lv.linkCells(l);
      final x = math.min(lv.clues[a], lv.clues[b]), y = math.max(lv.clues[a], lv.clues[b]);
      if (!seen.add(x * (k + 1) + y)) return false;
    }
    return true;
  }

  @override
  int? countSolutions(PLevel lv, {int limit = 2, int budget = 200000}) {
    final used = List.filled(lv.n, false);
    final pairs = <int>{};
    final k = lv.param;
    var found = 0, nodes = 0;
    var over = false;
    final given = <int>{};
    for (var l = 0; l < lv.givenLinks.length; l++) {
      if (lv.givenLinks[l] == 1) given.add(l);
    }
    for (final l in given) {
      final (a, b) = lv.linkCells(l);
      used[a] = true;
      used[b] = true;
      pairs.add(math.min(lv.clues[a], lv.clues[b]) * (k + 1) + math.max(lv.clues[a], lv.clues[b]));
    }
    void go() {
      if (found >= limit || over) return;
      // en az seçenekli boş hücre
      var best = -1, bestOpts = <int>[];
      for (var i = 0; i < lv.n; i++) {
        if (used[i]) continue;
        final opts = <int>[];
        for (final nb in lv.neighbors(i)) {
          if (used[nb]) continue;
          final key = math.min(lv.clues[i], lv.clues[nb]) * (k + 1) + math.max(lv.clues[i], lv.clues[nb]);
          if (!pairs.contains(key)) opts.add(nb);
        }
        if (best < 0 || opts.length < bestOpts.length) {
          best = i;
          bestOpts = opts;
          if (opts.length <= 1) break;
        }
      }
      if (best < 0) {
        found++;
        return;
      }
      for (final nb in bestOpts) {
        if (++nodes > budget) {
          over = true;
          return;
        }
        final key = math.min(lv.clues[best], lv.clues[nb]) * (k + 1) + math.max(lv.clues[best], lv.clues[nb]);
        used[best] = true;
        used[nb] = true;
        pairs.add(key);
        go();
        pairs.remove(key);
        used[best] = false;
        used[nb] = false;
        if (found >= limit || over) return;
      }
    }

    go();
    return over ? null : found;
  }

  @override
  int get givenLayer => 1;

  @override
  PLevel make(int difficulty, SeededRandom r) {
    final k = const [2, 3, 3, 4, 4, 5, 5, 6, 6, 7][difficulty - 1];
    final w = k + 2, h = k + 1;
    for (var attempt = 0; attempt < 200; attempt++) {
      // rastgele domino döşemesi
      final reg = List.filled(w * h, -1);
      final probe = PLevel(kind: id, w: w, h: h, clues: const [], givens: const []);
      final links = List.filled(probe.linkCount, 0);
      var g = 0;
      var bad = false;
      for (var i = 0; i < w * h && !bad; i++) {
        if (reg[i] >= 0) continue;
        final x = i % w, y = i ~/ w;
        final opts = [if (x < w - 1 && reg[i + 1] < 0) i + 1, if (y < h - 1) i + w];
        if (opts.isEmpty) {
          bad = true;
          break;
        }
        final j = opts[r.nextInt(opts.length)];
        reg[i] = g;
        reg[j] = g;
        links[probe.linkBetween(i, j)] = 1;
        g++;
      }
      if (bad || reg.contains(-1)) continue;
      // çiftleri dağıt
      final all = <(int, int)>[for (var a = 0; a <= k; a++) for (var b = a; b <= k; b++) (a, b)];
      r.shuffle(all);
      final clues = List.filled(w * h, 0);
      for (var l = 0, d = 0; l < probe.linkCount; l++) {
        if (links[l] != 1) continue;
        final (a, b) = probe.linkCells(l);
        final (p, q) = all[d++];
        if (r.chance(0.5)) {
          clues[a] = p;
          clues[b] = q;
        } else {
          clues[a] = q;
          clues[b] = p;
        }
      }
      return PLevel(kind: id, w: w, h: h, clues: clues, solLinks: links, givens: List.filled(w * h, -1), givenLinks: List.filled(probe.linkCount, -1), param: k);
    }
    throw StateError('dominosa');
  }

  @override
  void paintUnder(Canvas c, PLevel lv, PState s, Rect Function(int i) cell, double cs) {
    for (var l = 0; l < lv.linkCount; l++) {
      if (s.links[l] != 1) continue;
      final (a, b) = lv.linkCells(l);
      final r = cell(a).expandToInclude(cell(b)).deflate(cs * 0.08);
      c.drawRRect(RRect.fromRectAndRadius(r, Radius.circular(cs * 0.2)), Paint()..color = const Color(0x44C26A3E));
    }
  }

  @override
  double maxGivenRatio(int difficulty) => 0.3;
}

// ======================================================================
// Boru döndürme

/// Her hücrede boru parçası; dokununca 90° döner. Bütün borular tek ağaç
/// halinde birleşsin, açık uç kalmasın. clues: çözümdeki bağlantı maskesi
/// (bit 0 yukarı, 1 sağ, 2 aşağı, 3 sol). Hücre değeri: döndürme sayısı.
/// extra[0]: başlangıç döndürmeleri.
class PipeKind extends PuzzleKind {
  const PipeKind();
  @override
  String get id => 'boru-dondurme';

  @override
  int cellStates(PLevel lv) => 4;

  @override
  bool get cluesEditable => true;

  @override
  bool tapCell(PLevel lv, int i) => true;

  @override
  bool get gridLines => true;

  @override
  PState initial(PLevel lv) => PState(List.of(lv.extra[0]), List.filled(lv.linkCount, 0), List.filled(lv.borderCount, 0));

  static int rot(int mask, int k) {
    var m = mask;
    for (var t = 0; t < (k % 4 + 4) % 4; t++) {
      m = ((m << 1) | (m >> 3)) & 15;
    }
    return m;
  }

  /// Oyuncu durumunda hücrenin maskesi: çözüm maskesi ters döndürülmüş
  /// başlangıç + oyuncu döndürmesi; 0 döndürme = çözüm.
  int maskAt(PLevel lv, List<int> cells, int i) => rot(lv.clues[i], cells[i]);

  @override
  bool ok(PLevel lv, PState s, bool complete) {
    final c = s.cells;
    for (var i = 0; i < lv.n; i++) {
      final m = maskAt(lv, c, i);
      final x = i % lv.w, y = i ~/ lv.w;
      if (m & 1 != 0 && (y == 0 || maskAt(lv, c, i - lv.w) & 4 == 0)) return false;
      if (m & 2 != 0 && (x == lv.w - 1 || maskAt(lv, c, i + 1) & 8 == 0)) return false;
      if (m & 4 != 0 && (y == lv.h - 1 || maskAt(lv, c, i + lv.w) & 1 == 0)) return false;
      if (m & 8 != 0 && (x == 0 || maskAt(lv, c, i - 1) & 2 == 0)) return false;
    }
    // bağlılık
    final seen = List.filled(lv.n, false)..[0] = true;
    final q = [0];
    for (var k = 0; k < q.length; k++) {
      final i = q[k];
      final m = maskAt(lv, c, i);
      for (var dir = 0; dir < 4; dir++) {
        if (m & (1 << dir) == 0) continue;
        final nb = switch (dir) { 0 => i - lv.w, 1 => i + 1, 2 => i + lv.w, _ => i - 1 };
        if (!seen[nb]) {
          seen[nb] = true;
          q.add(nb);
        }
      }
    }
    return q.length == lv.n;
  }

  @override
  void onTap(PLevel lv, PState s, int i) {
    s.cells[i] = (s.cells[i] + 1) % 4;
  }

  @override
  PLevel make(int difficulty, SeededRandom r) {
    final n = const [4, 4, 5, 5, 6, 6, 7, 8, 9, 10][difficulty - 1];
    // rastgele kapsayan ağaç (Prim)
    final mask = List.filled(n * n, 0);
    final inTree = List.filled(n * n, false);
    final start = r.nextInt(n * n);
    inTree[start] = true;
    final frontier = <(int, int)>[];
    void addF(int i) {
      final x = i % n, y = i ~/ n;
      if (y > 0) frontier.add((i, 0));
      if (x < n - 1) frontier.add((i, 1));
      if (y < n - 1) frontier.add((i, 2));
      if (x > 0) frontier.add((i, 3));
    }

    addF(start);
    while (frontier.isNotEmpty) {
      final (a, dir) = frontier.removeAt(r.nextInt(frontier.length));
      final b = switch (dir) { 0 => a - n, 1 => a + 1, 2 => a + n, _ => a - 1 };
      if (inTree[b]) continue;
      // dört yollu kavşak sınırla
      if (_bits(mask[a]) >= 3) continue;
      inTree[b] = true;
      mask[a] |= 1 << dir;
      mask[b] |= 1 << ((dir + 2) % 4);
      addF(b);
    }
    if (inTree.contains(false)) {
      // kısıt yüzünden kalanlar: sınırsız bağla
      for (var i = 0; i < n * n; i++) {
        if (inTree[i]) continue;
        final x = i % n, y = i ~/ n;
        for (final (dir, nb) in [if (y > 0) (0, i - n), if (x < n - 1) (1, i + 1), if (y < n - 1) (2, i + n), if (x > 0) (3, i - 1)]) {
          if (inTree[nb]) {
            mask[i] |= 1 << dir;
            mask[nb] |= 1 << ((dir + 2) % 4);
            inTree[i] = true;
            break;
          }
        }
      }
    }
    final scramble = [for (var i = 0; i < n * n; i++) r.nextInt(4)];
    // başlangıç çözümle aynı olmasın
    if (scramble.every((x) => x == 0)) scramble[0] = 1;
    return PLevel(kind: id, w: n, h: n, clues: mask, extra: [scramble], solCells: List.filled(n * n, 0), givens: List.filled(n * n, -1));
  }

  static int _bits(int m) => (m & 1) + ((m >> 1) & 1) + ((m >> 2) & 1) + ((m >> 3) & 1);

  @override
  CellLook look(PLevel lv, PState s, int i) => const CellLook();

  @override
  void paintOver(Canvas c, PLevel lv, PState s, Rect Function(int i) cell, double cs) {
    // ana kaynaktan ulaşılanlar dolu renkle
    final reach = List.filled(lv.n, false)..[0] = true;
    final q = [0];
    for (var k = 0; k < q.length; k++) {
      final i = q[k];
      final m = maskAt(lv, s.cells, i);
      final x = i % lv.w, y = i ~/ lv.w;
      for (var dir = 0; dir < 4; dir++) {
        if (m & (1 << dir) == 0) continue;
        if ((dir == 0 && y == 0) || (dir == 1 && x == lv.w - 1) || (dir == 2 && y == lv.h - 1) || (dir == 3 && x == 0)) continue;
        final nb = switch (dir) { 0 => i - lv.w, 1 => i + 1, 2 => i + lv.w, _ => i - 1 };
        if (maskAt(lv, s.cells, nb) & (1 << ((dir + 2) % 4)) == 0) continue;
        if (!reach[nb]) {
          reach[nb] = true;
          q.add(nb);
        }
      }
    }
    for (var i = 0; i < lv.n; i++) {
      final r = cell(i);
      final m = maskAt(lv, s.cells, i);
      final p = Paint()
        ..color = reach[i] ? const Color(0xFF2B8C8A) : const Color(0xFF8A847C)
        ..strokeWidth = cs * 0.2
        ..strokeCap = StrokeCap.round;
      for (var dir = 0; dir < 4; dir++) {
        if (m & (1 << dir) == 0) continue;
        final end = switch (dir) { 0 => r.topCenter, 1 => r.centerRight, 2 => r.bottomCenter, _ => r.centerLeft };
        c.drawLine(r.center, end, p);
      }
      c.drawCircle(r.center, cs * 0.12, Paint()..color = reach[i] ? const Color(0xFF2B8C8A) : const Color(0xFF8A847C));
      if (i == 0) c.drawCircle(r.center, cs * 0.2, Paint()..color = const Color(0xFFEDAE49));
    }
  }

  @override
  bool get hintable => true;
}

// ======================================================================
// Harita boyama

/// Her bölgeyi dört renkten biriyle boya; komşu bölgeler aynı renk olmaz.
/// Bazı bölgeler boyalı verilir.
class MapColorKind extends PuzzleKind {
  const MapColorKind();
  @override
  String get id => 'harita-boyama';

  @override
  CellInput get cellInput => CellInput.colors;

  @override
  int cellStates(PLevel lv) => 5;

  @override
  bool get zeroUnknown => true;

  @override
  bool tapCell(PLevel lv, int i) => lv.givens.isEmpty || lv.givens[i] < 0;

  @override
  bool get gridLines => false;

  @override
  CellLook look(PLevel lv, PState s, int i) => CellLook(color: s.cells[i] > 0 ? s.cells[i] : -1, tone: lv.givens.isNotEmpty && lv.givens[i] >= 0 ? 1 : 0);

  @override
  bool ok(PLevel lv, PState s, bool complete) {
    final v = s.cells;
    for (var i = 0; i < lv.n; i++) {
      if (v[i] <= 0) continue;
      for (final nb in lv.neighbors(i)) {
        if (v[nb] <= 0) continue;
        if (lv.regions[nb] == lv.regions[i] && v[nb] != v[i]) return false;
        if (lv.regions[nb] != lv.regions[i] && v[nb] == v[i]) return false;
      }
    }
    return true;
  }

  /// Bölge grafiğinde boyama sayımı.
  @override
  int? countSolutions(PLevel lv, {int limit = 2, int budget = 200000}) {
    final regs = lv.regions.toSet().toList()..sort();
    final adj = {for (final g in regs) g: <int>{}};
    for (var i = 0; i < lv.n; i++) {
      for (final nb in lv.neighbors(i)) {
        if (lv.regions[nb] != lv.regions[i]) adj[lv.regions[i]]!.add(lv.regions[nb]);
      }
    }
    final color = <int, int>{};
    for (var i = 0; i < lv.n; i++) {
      if (lv.givens.isNotEmpty && lv.givens[i] > 0) color[lv.regions[i]] = lv.givens[i];
    }
    final order = [for (final g in regs) if (!color.containsKey(g)) g]..sort((a, b) => adj[b]!.length.compareTo(adj[a]!.length));
    var found = 0, nodes = 0;
    var over = false;
    void go(int k) {
      if (found >= limit || over) return;
      if (k == order.length) {
        found++;
        return;
      }
      final g = order[k];
      for (var col = 1; col <= 4; col++) {
        if (adj[g]!.any((h) => color[h] == col)) continue;
        if (++nodes > budget) {
          over = true;
          return;
        }
        color[g] = col;
        go(k + 1);
        color.remove(g);
        if (found >= limit || over) return;
      }
    }

    go(0);
    return over ? null : found;
  }

  @override
  PLevel make(int difficulty, SeededRandom r) {
    final n = const [5, 6, 6, 7, 8, 8, 9, 10, 11, 12][difficulty - 1];
    for (var attempt = 0; attempt < 100; attempt++) {
      final reg = randomRegions(n, n, (n * n / (difficulty <= 3 ? 4 : 5)).round(), r);
      if (reg.contains(-1)) continue;
      final probe = PLevel(kind: id, w: n, h: n, clues: const [], regions: reg, givens: const []);
      // açgözlü + geri izleme ile 4 renk
      final regs = reg.toSet().toList();
      final adj = {for (final g in regs) g: <int>{}};
      for (var i = 0; i < n * n; i++) {
        for (final nb in probe.neighbors(i)) {
          if (reg[nb] != reg[i]) adj[reg[i]]!.add(reg[nb]);
        }
      }
      final color = <int, int>{};
      var nodes = 0;
      bool go(int k) {
        if (k == regs.length) return true;
        final g = regs[k];
        for (final o in shuffled(4, r)) {
          final col = o + 1;
          if (adj[g]!.any((h) => color[h] == col)) continue;
          if (++nodes > 20000) return false;
          color[g] = col;
          if (go(k + 1)) return true;
          color.remove(g);
        }
        return false;
      }

      if (!go(0)) continue;
      final sol = [for (final g in reg) color[g]!];
      return PLevel(kind: id, w: n, h: n, clues: const [], regions: reg, solCells: sol, givens: List.filled(n * n, -1));
    }
    throw StateError('map');
  }

  @override
  double maxGivenRatio(int difficulty) => 0.6;

  @override
  void setColor(PLevel lv, PState s, int i, int value) {
    for (var j = 0; j < lv.n; j++) {
      if (lv.regions[j] == lv.regions[i] && (lv.givens.isEmpty || lv.givens[j] < 0)) s.cells[j] = value;
    }
  }
}

/// Kullanılmayan uyarısını önlemek için.
int digitPeersCount(DigitKind k, PLevel lv) => k.peers(lv).length;
