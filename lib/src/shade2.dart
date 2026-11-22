import 'dart:math' as math;
import 'dart:ui';

import 'package:studio_core/core/rng.dart';

import 'core.dart';
import 'digits.dart';
import 'shade1.dart';

// ======================================================================
// Yıldız savaşı ve Kraliçeler

/// Her satırda, sütunda ve bölgede k yıldız; yıldızlar birbirine
/// (çapraz dahil) değmez.
class StarKind extends ShadeKind {
  final bool queens;
  const StarKind({this.queens = false});

  @override
  String get id => queens ? 'kraliceler' : 'yildiz-savasi';

  @override
  Mark get onMark => queens ? Mark.gem : Mark.star;

  @override
  bool get tintRegions => true;

  static (int, int) sizeFor(int d, bool queens) => queens
      ? const [(5, 1), (5, 1), (6, 1), (6, 1), (7, 1), (7, 1), (8, 1), (8, 1), (9, 1), (10, 1)][d - 1]
      : const [(5, 1), (6, 1), (6, 1), (7, 1), (8, 1), (8, 2), (9, 2), (10, 2), (10, 2), (10, 2)][d - 1];

  @override
  bool ok(PLevel lv, PState s, bool complete) {
    final v = s.cells;
    final k = lv.param;
    final n = lv.w;
    for (var i = 0; i < lv.n; i++) {
      if (v[i] != 1) continue;
      for (final nb in lv.neighbors(i, diag: true)) {
        if (v[nb] == 1) return false;
      }
    }
    bool group(Iterable<int> cells) {
      var on = 0, unk = 0;
      for (final c in cells) {
        if (v[c] == 1) on++;
        if (v[c] < 0) unk++;
      }
      return on <= k && on + unk >= k;
    }

    for (var y = 0; y < n; y++) {
      if (!group([for (var x = 0; x < n; x++) y * n + x])) return false;
    }
    for (var x = 0; x < n; x++) {
      if (!group([for (var y = 0; y < n; y++) y * n + x])) return false;
    }
    for (var g = 0; g < n; g++) {
      if (!group([for (var i = 0; i < lv.n; i++) if (lv.regions[i] == g) i])) return false;
    }
    return true;
  }

  @override
  PLevel make(int difficulty, SeededRandom r) {
    final (n, k) = sizeFor(difficulty, queens);
    for (var attempt = 0; attempt < 400; attempt++) {
      // önce yıldızlar: satır satır, sütun ve komşuluk kurallarıyla
      final v = List.filled(n * n, 0);
      final colCount = List.filled(n, 0);
      final probe = PLevel(kind: id, w: n, h: n, clues: const [], givens: const []);
      var nodes = 0;
      bool row(int y) {
        if (y == n) return true;
        final opts = shuffled(n, r);
        bool pick(int from, int need, List<int> chosen) {
          if (need == 0) {
            for (final x in chosen) {
              v[y * n + x] = 1;
              colCount[x]++;
            }
            if (row(y + 1)) return true;
            for (final x in chosen) {
              v[y * n + x] = 0;
              colCount[x]--;
            }
            return false;
          }
          for (var q = from; q < opts.length; q++) {
            if (++nodes > 20000) return false;
            final x = opts[q];
            final i = y * n + x;
            if (colCount[x] >= k) continue;
            if (chosen.any((c) => (c - x).abs() <= 1)) continue;
            if (probe.neighbors(i, diag: true).any((nb) => v[nb] == 1)) continue;
            // kalan satırlar sütun kotasını doldurabilmeli
            if (pick(q + 1, need - 1, [...chosen, x])) return true;
          }
          return false;
        }

        return pick(0, k, []);
      }

      if (!row(0)) continue;
      // bölgeler: yıldız grupları (k=2: yakın iki yıldız) tohum; büyüt
      final stars = [for (var i = 0; i < n * n; i++) if (v[i] == 1) i];
      final reg = List.filled(n * n, -1);
      if (k == 1) {
        for (var g = 0; g < stars.length; g++) {
          reg[stars[g]] = g;
        }
      } else {
        // yıldızları yakınlığa göre eşle
        final left = List.of(stars);
        r.shuffle(left);
        var g = 0;
        while (left.isNotEmpty) {
          final a = left.removeLast();
          left.sort((p, q) => ((p % n - a % n).abs() + (p ~/ n - a ~/ n).abs()).compareTo((q % n - a % n).abs() + (q ~/ n - a ~/ n).abs()));
          final b = left.removeAt(0);
          // a'dan b'ye düz yol: hücreleri bölgeye kat (yıldız olmayanlar)
          var c = a;
          reg[a] = g;
          while (c != b) {
            final cx = c % n, cy = c ~/ n, bx = b % n, by = b ~/ n;
            c = cx != bx ? c + (bx > cx ? 1 : -1) : c + (by > cy ? n : -n);
            if (c != b && (v[c] == 1 || reg[c] >= 0)) break;
            reg[c] = g;
          }
          if (reg[b] != g) break;
          g++;
        }
        if (stars.any((c) => reg[c] < 0)) continue;
      }
      var remaining = reg.where((x) => x < 0).length;
      var guard = 0;
      while (remaining > 0 && guard++ < 60000) {
        final i = r.nextInt(n * n);
        if (reg[i] < 0) continue;
        final x = i % n, y = i ~/ n;
        final opts = [if (x > 0) i - 1, if (x < n - 1) i + 1, if (y > 0) i - n, if (y < n - 1) i + n].where((c) => reg[c] < 0 && v[c] == 0).toList();
        if (opts.isEmpty) continue;
        reg[opts[r.nextInt(opts.length)]] = reg[i];
        remaining--;
      }
      if (remaining > 0) continue;
      return PLevel(kind: id, w: n, h: n, clues: const [], regions: reg, solCells: v, givens: List.filled(n * n, -1), param: k);
    }
    throw StateError('star');
  }

  @override
  double maxGivenRatio(int difficulty) => 0.3;
}

// ======================================================================
// Çadırlar

/// Her ağaca bitişik (yatay/dikey) tek çadır; çadırlar birbirine değmez;
/// satır/sütun sayıları. clues: 1 ağaç. extra[0] satır, extra[1] sütun.
class TentKind extends ShadeKind {
  const TentKind();
  @override
  String get id => 'cadirlar';

  @override
  Mark get onMark => Mark.tent;

  @override
  CellLook look(PLevel lv, PState s, int i) {
    if (lv.clues[i] == 1) return const CellLook(mark: Mark.tree);
    final v = s.cells[i];
    final given = lv.givens.isNotEmpty && lv.givens[i] >= 0;
    return CellLook(mark: v == 1 ? Mark.tent : (v == 2 || (given && v == 0) ? Mark.dot : Mark.none));
  }

  @override
  List<int> cellDomain(PLevel lv, int i) => lv.clues[i] == 1 || !lv.neighbors(i).any((nb) => lv.clues[nb] == 1) ? const [0] : const [0, 1];

  @override
  bool ok(PLevel lv, PState s, bool complete) {
    final v = s.cells;
    for (var i = 0; i < lv.n; i++) {
      if (v[i] != 1) continue;
      for (final nb in lv.neighbors(i, diag: true)) {
        if (v[nb] == 1) return false;
      }
    }
    for (var y = 0; y < lv.h; y++) {
      var on = 0, unk = 0;
      for (var x = 0; x < lv.w; x++) {
        final q = v[y * lv.w + x];
        if (q == 1) on++;
        if (q < 0) unk++;
      }
      if (on > lv.extra[0][y] || on + unk < lv.extra[0][y]) return false;
    }
    for (var x = 0; x < lv.w; x++) {
      var on = 0, unk = 0;
      for (var y = 0; y < lv.h; y++) {
        final q = v[y * lv.w + x];
        if (q == 1) on++;
        if (q < 0) unk++;
      }
      if (on > lv.extra[1][x] || on + unk < lv.extra[1][x]) return false;
    }
    // ağaç-çadır eşleşmesi (tamamlanınca)
    if (complete || !v.contains(-1)) {
      final trees = [for (var i = 0; i < lv.n; i++) if (lv.clues[i] == 1) i];
      final tents = [for (var i = 0; i < lv.n; i++) if (v[i] == 1) i];
      if (trees.length != tents.length) return false;
      final match = <int, int>{};
      bool aug(int t, Set<int> seen) {
        for (final nb in lv.neighbors(t)) {
          if (lv.clues[nb] != 1 || !seen.add(nb)) continue;
          if (!match.containsKey(nb) || aug(match[nb]!, seen)) {
            match[nb] = t;
            return true;
          }
        }
        return false;
      }

      for (final t in tents) {
        if (!aug(t, <int>{})) return false;
      }
    } else {
      // her ağacın yanında çadır olabilecek yer kalmalı
      for (var i = 0; i < lv.n; i++) {
        if (lv.clues[i] != 1) continue;
        if (!lv.neighbors(i).any((nb) => v[nb] == 1 || v[nb] < 0)) return false;
      }
    }
    return true;
  }

  @override
  PLevel make(int difficulty, SeededRandom r) {
    final n = const [5, 6, 6, 7, 8, 8, 9, 10, 10, 12][difficulty - 1];
    final probe = PLevel(kind: id, w: n, h: n, clues: const [], givens: const []);
    final tents = List.filled(n * n, 0);
    final clues = List.filled(n * n, -1);
    for (final i in shuffled(n * n, r)) {
      if (!r.chance(0.5)) continue;
      if (clues[i] == 1 || tents[i] == 1) continue;
      if (probe.neighbors(i, diag: true).any((nb) => tents[nb] == 1)) continue;
      final spots = probe.neighbors(i).where((nb) => clues[nb] != 1 && tents[nb] == 0).toList();
      if (spots.isEmpty) continue;
      // çadır i, ağaç komşulardan biri
      tents[i] = 1;
      clues[spots[r.nextInt(spots.length)]] = 1;
    }
    final rows = [for (var y = 0; y < n; y++) tents.sublist(y * n, y * n + n).where((x) => x == 1).length];
    final cols = [for (var x = 0; x < n; x++) [for (var y = 0; y < n; y++) tents[y * n + x]].where((x) => x == 1).length];
    return PLevel(kind: id, w: n, h: n, clues: clues, extra: [rows, cols], solCells: tents, givens: List.filled(n * n, -1));
  }

  @override
  (double, double, double, double) margins(PLevel lv) => (0.7, 0.7, 0, 0);

  @override
  String outside(PLevel lv, PState s, int side, int index) => side == 0 ? '${lv.extra[1][index]}' : (side == 1 ? '${lv.extra[0][index]}' : '');
}

// ======================================================================
// Gemiler

/// Filo (1x4, 2x3, 3x2, 4x1 gibi) ızgaraya gizlenmiş; gemiler birbirine
/// (çapraz dahil) değmez; satır/sütun sayıları ve bazı açık hücreler.
/// extra[0] satır, extra[1] sütun, extra[2] filo uzunlukları.
class FleetKind extends ShadeKind {
  const FleetKind();
  @override
  String get id => 'gemiler';

  @override
  Mark get onMark => Mark.ship;

  @override
  bool ok(PLevel lv, PState s, bool complete) {
    final v = s.cells;
    // çapraz değme yok
    for (var i = 0; i < lv.n; i++) {
      if (v[i] != 1) continue;
      final x = i % lv.w, y = i ~/ lv.w;
      for (final (dx, dy) in const [(1, 1), (-1, 1)]) {
        final nx = x + dx, ny = y + dy;
        if (nx >= 0 && nx < lv.w && ny < lv.h && v[ny * lv.w + nx] == 1) return false;
      }
    }
    for (var y = 0; y < lv.h; y++) {
      var on = 0, unk = 0;
      for (var x = 0; x < lv.w; x++) {
        final q = v[y * lv.w + x];
        if (q == 1) on++;
        if (q < 0) unk++;
      }
      if (on > lv.extra[0][y] || on + unk < lv.extra[0][y]) return false;
    }
    for (var x = 0; x < lv.w; x++) {
      var on = 0, unk = 0;
      for (var y = 0; y < lv.h; y++) {
        final q = v[y * lv.w + x];
        if (q == 1) on++;
        if (q < 0) unk++;
      }
      if (on > lv.extra[1][x] || on + unk < lv.extra[1][x]) return false;
    }
    // gemiler düz ve filo uyumlu
    final fleet = List.of(lv.extra[2])..sort();
    final ships = <int>[];
    final seen = List.filled(lv.n, false);
    for (var i = 0; i < lv.n; i++) {
      if (v[i] != 1 || seen[i]) continue;
      final comp = [i];
      seen[i] = true;
      var open = false;
      for (var q = 0; q < comp.length; q++) {
        for (final nb in lv.neighbors(comp[q])) {
          if (v[nb] < 0) open = true;
          if (!seen[nb] && v[nb] == 1) {
            seen[nb] = true;
            comp.add(nb);
          }
        }
      }
      final xs = comp.map((c) => c % lv.w).toSet(), ys = comp.map((c) => c ~/ lv.w).toSet();
      if (xs.length > 1 && ys.length > 1) return false;
      if (comp.length > fleet.last) return false;
      if (!open) ships.add(comp.length);
    }
    if (complete || !v.contains(-1)) {
      ships.sort();
      if (ships.length != fleet.length) return false;
      for (var k = 0; k < ships.length; k++) {
        if (ships[k] != fleet[k]) return false;
      }
    } else {
      // kapalı gemiler filoda fazla olmamalı
      final cnt = <int, int>{};
      for (final f in fleet) {
        cnt[f] = (cnt[f] ?? 0) + 1;
      }
      for (final sh in ships) {
        final c = cnt[sh] ?? 0;
        if (c == 0) return false;
        cnt[sh] = c - 1;
      }
    }
    return true;
  }

  @override
  PLevel make(int difficulty, SeededRandom r) {
    final n = difficulty <= 3 ? 6 : (difficulty <= 7 ? 8 : 10);
    final fleet = n == 6 ? [3, 2, 2, 1, 1, 1] : (n == 8 ? [4, 3, 3, 2, 2, 1, 1, 1] : [4, 3, 3, 2, 2, 2, 1, 1, 1, 1]);
    for (var attempt = 0; attempt < 200; attempt++) {
      final v = List.filled(n * n, 0);
      var okk = true;
      for (final len in fleet) {
        var placed = false;
        for (var t = 0; t < 200 && !placed; t++) {
          final hor = r.chance(0.5);
          final x = r.nextInt(hor ? n - len + 1 : n), y = r.nextInt(hor ? n : n - len + 1);
          final cells = [for (var k = 0; k < len; k++) hor ? y * n + x + k : (y + k) * n + x];
          final probe = PLevel(kind: id, w: n, h: n, clues: const [], givens: const []);
          if (cells.any((c) => v[c] == 1 || probe.neighbors(c, diag: true).any((nb) => v[nb] == 1))) continue;
          for (final c in cells) {
            v[c] = 1;
          }
          placed = true;
        }
        if (!placed) okk = false;
      }
      if (!okk) continue;
      final rows = [for (var y = 0; y < n; y++) v.sublist(y * n, y * n + n).where((x) => x == 1).length];
      final cols = [for (var x = 0; x < n; x++) [for (var y = 0; y < n; y++) v[y * n + x]].where((x) => x == 1).length];
      return PLevel(kind: id, w: n, h: n, clues: const [], extra: [rows, cols, fleet], solCells: v, givens: List.filled(n * n, -1));
    }
    throw StateError('fleet');
  }

  @override
  (double, double, double, double) margins(PLevel lv) => (0.7, 0.7, 0, 0);

  @override
  String outside(PLevel lv, PState s, int side, int index) => side == 0 ? '${lv.extra[1][index]}' : (side == 1 ? '${lv.extra[0][index]}' : '');

  @override
  String status(PLevel lv, PState s, String lang) => (List.of(lv.extra[2])..sort((a, b) => b - a)).map((x) => '▮' * x).join('  ');
}

// ======================================================================
// Akvaryum

/// Her akvaryum (bölge) dipten belli bir seviyeye kadar su ile dolar:
/// bir hücre doluysa aynı akvaryumda daha alçaktaki her hücre de dolu,
/// aynı yükseklikteki hücreler de dolu. Satır/sütun sayıları.
class AquariumKind extends ShadeKind {
  const AquariumKind();
  @override
  String get id => 'akvaryum';

  @override
  bool ok(PLevel lv, PState s, bool complete) {
    final v = s.cells;
    // seviye kuralı
    for (var i = 0; i < lv.n; i++) {
      if (v[i] != 1) continue;
      final y = i ~/ lv.w;
      for (var j = 0; j < lv.n; j++) {
        if (lv.regions[j] != lv.regions[i]) continue;
        if (j ~/ lv.w >= y && v[j] == 0) return false;
      }
    }
    for (var y = 0; y < lv.h; y++) {
      var on = 0, unk = 0;
      for (var x = 0; x < lv.w; x++) {
        final q = v[y * lv.w + x];
        if (q == 1) on++;
        if (q < 0) unk++;
      }
      if (on > lv.extra[0][y] || on + unk < lv.extra[0][y]) return false;
    }
    for (var x = 0; x < lv.w; x++) {
      var on = 0, unk = 0;
      for (var y = 0; y < lv.h; y++) {
        final q = v[y * lv.w + x];
        if (q == 1) on++;
        if (q < 0) unk++;
      }
      if (on > lv.extra[1][x] || on + unk < lv.extra[1][x]) return false;
    }
    return true;
  }

  @override
  PLevel make(int difficulty, SeededRandom r) {
    final n = const [4, 5, 6, 6, 7, 8, 8, 9, 10, 10][difficulty - 1];
    final reg = partitionGrid(n, n, 6, r);
    final groups = <int, List<int>>{};
    for (var i = 0; i < n * n; i++) {
      groups.putIfAbsent(reg[i], () => []).add(i);
    }
    final v = List.filled(n * n, 0);
    for (final g in groups.values) {
      final ys = g.map((c) => c ~/ n).toSet().toList()..sort();
      // seviye: rastgele bir satırdan aşağısı dolu (ya da boş)
      final level = r.nextInt(ys.length + 1);
      if (level == ys.length) continue;
      final top = ys[level];
      for (final c in g) {
        if (c ~/ n >= top) v[c] = 1;
      }
    }
    final rows = [for (var y = 0; y < n; y++) v.sublist(y * n, y * n + n).where((x) => x == 1).length];
    final cols = [for (var x = 0; x < n; x++) [for (var y = 0; y < n; y++) v[y * n + x]].where((x) => x == 1).length];
    return PLevel(kind: id, w: n, h: n, clues: const [], regions: reg, extra: [rows, cols], solCells: v, givens: List.filled(n * n, -1));
  }

  @override
  CellLook look(PLevel lv, PState s, int i) {
    final v = s.cells[i];
    final given = lv.givens.isNotEmpty && lv.givens[i] >= 0;
    return CellLook(color: v == 1 ? 8 : -1, mark: v == 2 || (given && v == 0) ? Mark.dot : Mark.none);
  }

  @override
  (double, double, double, double) margins(PLevel lv) => (0.7, 0.7, 0, 0);

  @override
  String outside(PLevel lv, PState s, int side, int index) => side == 0 ? '${lv.extra[1][index]}' : (side == 1 ? '${lv.extra[0][index]}' : '');

  @override
  void onTap(PLevel lv, PState s, int i) {
    // Dokunulan hücreye kadar akvaryumu doldur/boşalt
    final y = i ~/ lv.w;
    final fill = s.cells[i] != 1;
    for (var j = 0; j < lv.n; j++) {
      if (lv.regions[j] != lv.regions[i]) continue;
      if (lv.givens.isNotEmpty && lv.givens[j] >= 0) continue;
      final yj = j ~/ lv.w;
      if (fill && yj >= y) s.cells[j] = 1;
      if (!fill && yj <= y) s.cells[j] = 0;
    }
  }
}

// ======================================================================
// Norinori

/// Her bölgede tam iki kara; her kara hücrenin tam bir kara komşusu var
/// (karalar ikişerli domino).
class PairShadeKind extends ShadeKind {
  const PairShadeKind();
  @override
  String get id => 'norinori';

  @override
  bool get tintRegions => true;

  @override
  bool ok(PLevel lv, PState s, bool complete) {
    final v = s.cells;
    final cnt = <int, (int, int)>{};
    for (var i = 0; i < lv.n; i++) {
      final (a, b) = cnt[lv.regions[i]] ?? (0, 0);
      cnt[lv.regions[i]] = (a + (v[i] == 1 ? 1 : 0), b + (v[i] < 0 ? 1 : 0));
    }
    for (final e in cnt.values) {
      if (e.$1 > 2 || e.$1 + e.$2 < 2) return false;
    }
    for (var i = 0; i < lv.n; i++) {
      if (v[i] != 1) continue;
      var on = 0, unk = 0;
      for (final nb in lv.neighbors(i)) {
        if (v[nb] == 1) on++;
        if (v[nb] < 0) unk++;
      }
      if (on > 1 || on + unk < 1) return false;
    }
    return true;
  }

  @override
  PLevel make(int difficulty, SeededRandom r) {
    final n = const [5, 6, 6, 7, 8, 8, 9, 10, 10, 10][difficulty - 1];
    for (var attempt = 0; attempt < 300; attempt++) {
      final v = List.filled(n * n, 0);
      final probe = PLevel(kind: id, w: n, h: n, clues: const [], givens: const []);
      final dominos = <List<int>>[];
      for (final i in shuffled(n * n, r)) {
        if (v[i] == 1 || probe.neighbors(i).any((nb) => v[nb] == 1)) continue;
        final opts = probe.neighbors(i).where((nb) => v[nb] == 0 && probe.neighbors(nb).every((m) => m == i || v[m] == 0)).toList();
        if (opts.isEmpty) continue;
        if (!r.chance(0.6)) continue;
        final j = opts[r.nextInt(opts.length)];
        v[i] = 1;
        v[j] = 1;
        dominos.add([i, j]);
      }
      // her domino kendi bölgesinin tohumu; bölgeleri büyüt
      final reg = List.filled(n * n, -1);
      for (var g = 0; g < dominos.length; g++) {
        reg[dominos[g][0]] = g;
        reg[dominos[g][1]] = g;
      }
      if (dominos.length < n) continue;
      var left = reg.where((x) => x < 0).length;
      var guard = 0;
      while (left > 0 && guard++ < 60000) {
        final i = r.nextInt(n * n);
        if (reg[i] < 0) continue;
        final x = i % n, y = i ~/ n;
        final opts = [if (x > 0) i - 1, if (x < n - 1) i + 1, if (y > 0) i - n, if (y < n - 1) i + n].where((c) => reg[c] < 0).toList();
        if (opts.isEmpty) continue;
        reg[opts[r.nextInt(opts.length)]] = reg[i];
        left--;
      }
      if (left > 0) continue;
      return PLevel(kind: id, w: n, h: n, clues: const [], regions: reg, solCells: v, givens: List.filled(n * n, -1));
    }
    throw StateError('norinori');
  }
}

// ======================================================================
// LITS (dörtlü bloklar)

/// Her bölgede bağlı dört kara hücre (L, I, T ya da S biçimi); aynı biçimde
/// iki blok yan yana değmez; bütün karalar tek parça; 2x2 kara yok.
class TetroKind extends ShadeKind {
  const TetroKind();
  @override
  String get id => 'lits';

  @override
  bool get tintRegions => true;

  static int shapeOf(List<int> cells, int w) {
    // 0 L, 1 I, 2 T, 3 S (yansıma ve dönmeler dahil); -1 diğer
    final xs = cells.map((c) => c % w).toList(), ys = cells.map((c) => c ~/ w).toList();
    final minx = xs.reduce(math.min), miny = ys.reduce(math.min);
    final pts = [for (var k = 0; k < 4; k++) (xs[k] - minx, ys[k] - miny)];
    final bw = pts.map((p) => p.$1).reduce(math.max) + 1, bh = pts.map((p) => p.$2).reduce(math.max) + 1;
    if (bw == 4 || bh == 4) return 1;
    if (bw == 2 && bh == 2) return -1;
    // komşu sayıları
    final deg = [
      for (final p in pts) pts.where((q) => (q.$1 - p.$1).abs() + (q.$2 - p.$2).abs() == 1).length
    ];
    if (deg.contains(3)) return 2;
    // L ve S: L'de bir uç ve köşe tek doğru üzerinde 3 hücre
    final lines = <int>{};
    for (var x = 0; x < bw; x++) {
      if (pts.where((p) => p.$1 == x).length == 3) lines.add(x);
    }
    for (var y = 0; y < bh; y++) {
      if (pts.where((p) => p.$2 == y).length == 3) lines.add(10 + y);
    }
    return lines.isNotEmpty ? 0 : 3;
  }

  @override
  bool ok(PLevel lv, PState s, bool complete) {
    final v = s.cells;
    if (!ShadeKind.no2x2(lv, v, 1)) return false;
    final regs = <int, List<int>>{};
    for (var i = 0; i < lv.n; i++) {
      regs.putIfAbsent(lv.regions[i], () => []).add(i);
    }
    final shapeAt = List.filled(lv.n, -2);
    for (final cells in regs.values) {
      final on = cells.where((c) => v[c] == 1).toList();
      final unk = cells.where((c) => v[c] < 0).length;
      if (on.length > 4 || on.length + unk < 4) return false;
      if (on.length == 4) {
        // bağlı mı
        final pr = components(lv, (c) => on.contains(c));
        if (pr.length != 1) return false;
        final sh = shapeOf(on, lv.w);
        if (sh < 0) return false;
        for (final c in on) {
          shapeAt[c] = sh;
        }
      }
    }
    for (var i = 0; i < lv.n; i++) {
      if (shapeAt[i] < 0) continue;
      for (final nb in lv.neighbors(i)) {
        if (lv.regions[nb] != lv.regions[i] && shapeAt[nb] == shapeAt[i]) return false;
      }
    }
    return ShadeKind.shadedConnected(lv, v);
  }

  @override
  PLevel make(int difficulty, SeededRandom r) {
    final n = const [5, 5, 6, 6, 6, 7, 7, 7, 8, 8][difficulty - 1];
    for (var attempt = 0; attempt < 300; attempt++) {
      final reg = partitionGrid(n, n, 7, r);
      // her bölge en az 4 hücre olmalı: küçükleri komşuya kat
      final size = <int, int>{};
      for (final g in reg) {
        size[g] = (size[g] ?? 0) + 1;
      }
      for (var pass = 0; pass < 6; pass++) {
        for (var i = 0; i < n * n; i++) {
          if ((size[reg[i]] ?? 0) >= 4) continue;
          final x = i % n, y = i ~/ n;
          final nbs = [if (x > 0) i - 1, if (x < n - 1) i + 1, if (y > 0) i - n, if (y < n - 1) i + n].where((c) => reg[c] != reg[i]).toList();
          if (nbs.isEmpty) continue;
          final old = reg[i], to = reg[nbs[r.nextInt(nbs.length)]];
          for (var j = 0; j < n * n; j++) {
            if (reg[j] == old) reg[j] = to;
          }
          size[to] = (size[to] ?? 0) + (size[old] ?? 0);
          size.remove(old);
        }
      }
      // yeniden numarala
      final ids = <int, int>{};
      final reg2 = [for (final g in reg) ids.putIfAbsent(g, () => ids.length)];
      final probe = PLevel(kind: id, w: n, h: n, clues: const [], regions: reg2, givens: const []);
      if (reg2.toSet().any((g) => reg2.where((x) => x == g).length < 4 || components(probe, (c) => reg2[c] == g).length != 1)) continue;
      // her bölgede bir tetromino seç; geri izleme ile kurallara uygun
      final regs = <int, List<int>>{};
      for (var i = 0; i < n * n; i++) {
        regs.putIfAbsent(reg2[i], () => []).add(i);
      }
      final order = regs.keys.toList();
      r.shuffle(order);
      final v = List.filled(n * n, 0);
      var nodes = 0;
      List<List<int>> tetros(List<int> cells) {
        final out = <List<int>>[];
        final set = cells.toSet();
        for (final a in cells) {
          // 4 hücrelik bağlı alt kümeler (a'dan başlayıp büyüt)
          void grow(List<int> cur) {
            if (cur.length == 4) {
              final sorted = List.of(cur)..sort();
              if (!out.any((o) => o[0] == sorted[0] && o[1] == sorted[1] && o[2] == sorted[2] && o[3] == sorted[3]) && shapeOf(sorted, n) >= 0) out.add(sorted);
              return;
            }
            for (final c in cur) {
              for (final nb in probe.neighbors(c)) {
                if (set.contains(nb) && !cur.contains(nb) && nb > a) grow([...cur, nb]);
              }
            }
          }

          grow([a]);
        }
        r.shuffle(out);
        return out;
      }

      bool go(int k) {
        if (k == order.length) return ShadeKind.shadedConnected(probe, v, unknownCounts: false) && ok(probe, PState(v, const [], const []), true);
        for (final t in tetros(regs[order[k]]!).take(12)) {
          if (++nodes > 4000) return false;
          for (final c in t) {
            v[c] = 1;
          }
          final partial = [for (var i = 0; i < n * n; i++) v[i] == 1 ? 1 : (regs.keys.toList().indexOf(reg2[i]) >= 0 && order.indexOf(reg2[i]) > k ? -1 : 0)];
          if (ok(probe, PState(partial, const [], const []), false) && go(k + 1)) return true;
          for (final c in t) {
            v[c] = 0;
          }
        }
        return false;
      }

      if (!go(0)) continue;
      return PLevel(kind: id, w: n, h: n, clues: const [], regions: reg2, solCells: v, givens: List.filled(n * n, -1));
    }
    throw StateError('lits');
  }
}

// ======================================================================
// Tapa

/// İpucu hücresindeki sayılar, çevresindeki 8 hücrede ardışık kara
/// grupların uzunluklarıdır. Karalar tek parça; 2x2 kara yok.
/// extra[0]: her hücre için ipucu dizisi kodu (-1 yok), extra[1..]: dizi.
class TapKind extends ShadeKind {
  const TapKind();
  @override
  String get id => 'tapa';

  static const _ring = [(-1, -1), (0, -1), (1, -1), (1, 0), (1, 1), (0, 1), (-1, 1), (-1, 0)];

  static List<int> ringRuns(List<int> ring) {
    // dairesel ardışık 1 grupları
    if (ring.every((x) => x == 1)) return [8];
    var start = ring.indexOf(0);
    final out = <int>[];
    var run = 0;
    for (var k = 1; k <= 8; k++) {
      final x = ring[(start + k) % 8];
      if (x == 1) {
        run++;
      } else if (run > 0) {
        out.add(run);
        run = 0;
      }
    }
    if (run > 0) out.add(run);
    out.sort();
    return out;
  }

  List<int> _ringVals(PLevel lv, List<int> v, int i) {
    final x = i % lv.w, y = i ~/ lv.w;
    return [
      for (final (dx, dy) in _ring) (x + dx >= 0 && y + dy >= 0 && x + dx < lv.w && y + dy < lv.h) ? v[(y + dy) * lv.w + x + dx] : 0
    ];
  }

  List<int> clueOf(PLevel lv, int i) {
    final code = lv.extra[0][i];
    return code < 0 ? const [] : lv.extra[1 + code];
  }

  @override
  List<int> cellDomain(PLevel lv, int i) => lv.extra[0][i] >= 0 ? const [0] : const [0, 1];

  @override
  bool tapCell(PLevel lv, int i) => lv.extra[0][i] < 0 && (lv.givens.isEmpty || lv.givens[i] < 0);

  @override
  bool canGive(PLevel lv, int i) => lv.extra[0][i] < 0;

  @override
  CellLook look(PLevel lv, PState s, int i) {
    final c = clueOf(lv, i);
    if (lv.extra[0][i] >= 0) return CellLook(text: c.isEmpty ? '0' : c.join(' '), tone: 1);
    final v = s.cells[i];
    final given = lv.givens.isNotEmpty && lv.givens[i] >= 0;
    return CellLook(mark: v == 1 ? Mark.fill : (v == 2 || (given && v == 0) ? Mark.dot : Mark.none));
  }

  @override
  bool ok(PLevel lv, PState s, bool complete) {
    final v = s.cells;
    if (!ShadeKind.no2x2(lv, v, 1)) return false;
    for (var i = 0; i < lv.n; i++) {
      if (lv.extra[0][i] < 0) continue;
      final ring = _ringVals(lv, v, i);
      final clue = List.of(clueOf(lv, i))..sort();
      if (!ring.contains(-1)) {
        final runs = ringRuns(ring);
        if (runs.length != clue.length) return false;
        for (var k = 0; k < runs.length; k++) {
          if (runs[k] != clue[k]) return false;
        }
      } else {
        final on = ring.where((x) => x == 1).length, unk = ring.where((x) => x < 0).length;
        final need = clue.fold<int>(0, (a, b) => a + b);
        if (on > need || on + unk < need) return false;
      }
    }
    return ShadeKind.shadedConnected(lv, v);
  }

  @override
  PLevel make(int difficulty, SeededRandom r) {
    final n = const [5, 5, 6, 6, 7, 7, 8, 8, 9, 10][difficulty - 1];
    for (var attempt = 0; attempt < 300; attempt++) {
      final probe = PLevel(kind: id, w: n, h: n, clues: const [], givens: const []);
      // bağlı kara yılan: rastgele büyüme, 2x2 yok
      final v = List.filled(n * n, 0);
      final start = r.nextInt(n * n);
      v[start] = 1;
      final target = (n * n * 0.45).round();
      var count = 1;
      for (var t = 0; t < n * n * 30 && count < target; t++) {
        final i = r.nextInt(n * n);
        if (v[i] == 1 || !probe.neighbors(i).any((nb) => v[nb] == 1)) continue;
        v[i] = 1;
        if (!ShadeKind.no2x2(probe, v, 1)) {
          v[i] = 0;
          continue;
        }
        count++;
      }
      final codes = List.filled(n * n, -1);
      final lists = <List<int>>[];
      final whites = [for (var i = 0; i < n * n; i++) if (v[i] == 0) i];
      r.shuffle(whites);
      final want = (n * n * (difficulty <= 4 ? 0.18 : 0.13)).round();
      for (final i in whites.take(want)) {
        final runs = ringRuns(_ringVals(probe, v, i));
        codes[i] = lists.length;
        lists.add(runs);
      }
      if (lists.isEmpty) continue;
      return PLevel(kind: id, w: n, h: n, clues: const [], extra: [codes, ...lists], solCells: v, givens: List.filled(n * n, -1));
    }
    throw StateError('tapa');
  }
}

// ======================================================================
// Mıknatıslar

/// Izgara dominolara bölünmüş; her domino ya mıknatıs (+ ve −) ya da
/// boştur. Aynı kutuplar yan yana gelmez; satır/sütundaki + ve − sayıları
/// verilir. regions: domino kimliği. Hücre: 0 boş, 1 +, 2 −, 3 nötr.
/// extra[0] satır +, extra[1] satır −, extra[2] sütun +, extra[3] sütun −.
class MagnetKind extends PuzzleKind {
  const MagnetKind();
  @override
  String get id => 'miknatislar';

  @override
  int cellStates(PLevel lv) => 4;

  @override
  bool get zeroUnknown => true;

  @override
  List<int> cellDomain(PLevel lv, int i) => const [1, 2, 3];

  @override
  bool tapCell(PLevel lv, int i) => lv.givens.isEmpty || lv.givens[i] < 0;

  int partner(PLevel lv, int i) {
    final g = lv.regions[i];
    for (final nb in lv.neighbors(i)) {
      if (lv.regions[nb] == g) return nb;
    }
    return i;
  }

  @override
  void onTap(PLevel lv, PState s, int i) {
    final p = partner(lv, i);
    final next = (s.cells[i] + 1) % 4;
    s.cells[i] = next;
    s.cells[p] = next == 0 ? 0 : (next == 3 ? 3 : 3 - next);
  }

  @override
  CellLook look(PLevel lv, PState s, int i) {
    final v = s.cells[i];
    return CellLook(mark: switch (v) { 1 => Mark.plus, 2 => Mark.minus, 3 => Mark.cross, _ => Mark.none }, tone: lv.givens.isNotEmpty && lv.givens[i] >= 0 ? 1 : 0);
  }

  @override
  bool ok(PLevel lv, PState s, bool complete) {
    final v = s.cells;
    for (var i = 0; i < lv.n; i++) {
      final p = partner(lv, i);
      final a = v[i], b = v[p];
      if (a > 0 && b > 0) {
        if ((a == 3) != (b == 3)) return false;
        if (a != 3 && a == b) return false;
      }
      if (a == 1 || a == 2) {
        for (final nb in lv.neighbors(i)) {
          if (v[nb] == a) return false;
        }
      }
    }
    for (var y = 0; y < lv.h; y++) {
      for (final (val, ex) in const [(1, 0), (2, 1)]) {
        var on = 0, unk = 0;
        for (var x = 0; x < lv.w; x++) {
          final q = v[y * lv.w + x];
          if (q == val) on++;
          if (q < 0) unk++;
        }
        final t = lv.extra[ex][y];
        if (t >= 0 && (on > t || on + unk < t)) return false;
      }
    }
    for (var x = 0; x < lv.w; x++) {
      for (final (val, ex) in const [(1, 2), (2, 3)]) {
        var on = 0, unk = 0;
        for (var y = 0; y < lv.h; y++) {
          final q = v[y * lv.w + x];
          if (q == val) on++;
          if (q < 0) unk++;
        }
        final t = lv.extra[ex][x];
        if (t >= 0 && (on > t || on + unk < t)) return false;
      }
    }
    return true;
  }

  @override
  PLevel make(int difficulty, SeededRandom r) {
    final (w, h) = const [(4, 4), (4, 4), (5, 4), (6, 4), (6, 6), (6, 6), (8, 6), (8, 6), (8, 8), (10, 8)][difficulty - 1];
    for (var attempt = 0; attempt < 200; attempt++) {
      // domino döşeme
      final reg = List.filled(w * h, -1);
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
        g++;
      }
      if (bad || reg.contains(-1)) continue;
      final probe = PLevel(kind: id, w: w, h: h, clues: const [], regions: reg, givens: const [], extra: [List.filled(h, -1), List.filled(h, -1), List.filled(w, -1), List.filled(w, -1)]);
      final v = List.filled(w * h, -1);
      for (final i in shuffled(w * h, r)) {
        if (v[i] >= 0) continue;
        final p = partner(probe, i);
        final opts = r.chance(0.35) ? [3] : (r.chance(0.5) ? [1, 2] : [2, 1]);
        var placed = false;
        for (final a in [...opts, 3]) {
          v[i] = a;
          v[p] = a == 3 ? 3 : 3 - a;
          if (ok(probe, PState(v, const [], const []), false)) {
            placed = true;
            break;
          }
        }
        if (!placed) {
          v[i] = 3;
          v[p] = 3;
        }
      }
      final rp = [for (var y = 0; y < h; y++) v.sublist(y * w, y * w + w).where((q) => q == 1).length];
      final rm = [for (var y = 0; y < h; y++) v.sublist(y * w, y * w + w).where((q) => q == 2).length];
      final cp = [for (var x = 0; x < w; x++) [for (var y = 0; y < h; y++) v[y * w + x]].where((q) => q == 1).length];
      final cm = [for (var x = 0; x < w; x++) [for (var y = 0; y < h; y++) v[y * w + x]].where((q) => q == 2).length];
      final lv = PLevel(kind: id, w: w, h: h, clues: const [], regions: reg, extra: [rp, rm, cp, cm], solCells: v, givens: List.filled(w * h, -1));
      if (ok(lv, PState(v, const [], const []), true)) return lv;
    }
    throw StateError('magnet');
  }

  @override
  (double, double, double, double) margins(PLevel lv) => (0.7, 0.7, 0.7, 0.7);

  @override
  String outside(PLevel lv, PState s, int side, int index) => switch (side) {
        0 => '${lv.extra[2][index]}',
        1 => '${lv.extra[0][index]}',
        2 => '${lv.extra[3][index]}',
        _ => '${lv.extra[1][index]}',
      };

  @override
  void paintUnder(Canvas c, PLevel lv, PState s, Rect Function(int i) cell, double cs) {
    // kenar işaretleri: üst/sol +, alt/sağ −
    final (mt, ml, _, _) = margins(lv);
    final r0 = cell(0);
    smallText(c, '+', r0.topLeft - Offset(ml * cs * 0.5, mt * cs * 0.5), cs * 0.36, const Color(0xFFD1495B));
    final rl = cell(lv.n - 1);
    smallText(c, '−', rl.bottomRight + Offset(ml * cs * 0.5, mt * cs * 0.5), cs * 0.36, const Color(0xFF2E6F95));
  }

  @override
  bool get tintRegions => false;

  @override
  double maxGivenRatio(int difficulty) => 0.5;
}

// ======================================================================
// Işıkları söndür ve Çevir

/// Bir hücreye dokunmak onu ve [pattern] ile belirlenen hücreleri çevirir.
/// Amaç bütün ışıkları söndürmek. clues: başlangıç ışıkları (0/1).
/// Çevir türünde her hücrenin kendi deseni vardır (extra[0]: hücre başına
/// 9 bitlik 3x3 maske).
class TogglesKind extends PuzzleKind {
  final bool perCell;
  const TogglesKind({this.perCell = false});

  @override
  String get id => perCell ? 'cevir' : 'isiklari-sondur';

  @override
  bool get cluesEditable => true;

  @override
  bool tapCell(PLevel lv, int i) => true;

  @override
  PState initial(PLevel lv) => togglesStart(lv);

  @override
  bool get hintable => false;

  List<int> affected(PLevel lv, int i) {
    final x = i % lv.w, y = i ~/ lv.w;
    if (!perCell) return [i, ...lv.neighbors(i)];
    final mask = lv.extra[0][i];
    final out = <int>[];
    for (var k = 0; k < 9; k++) {
      if (mask & (1 << k) == 0) continue;
      final nx = x + k % 3 - 1, ny = y + k ~/ 3 - 1;
      if (nx >= 0 && ny >= 0 && nx < lv.w && ny < lv.h) out.add(ny * lv.w + nx);
    }
    return out;
  }

  @override
  void onTap(PLevel lv, PState s, int i) {
    for (final j in affected(lv, i)) {
      s.cells[j] = 1 - s.cells[j];
    }
  }

  @override
  bool solved(PLevel lv, PState player) => player.cells.every((x) => x == 0);

  @override
  bool ok(PLevel lv, PState s, bool complete) {
    // Çözüm: solCells basılacak hücreler; başlangıçtan uygulanınca hepsi sönük
    final cur = List.of(lv.clues);
    for (var i = 0; i < lv.n; i++) {
      if (s.cells[i] == 1) {
        for (final j in affected(lv, i)) {
          cur[j] = 1 - cur[j];
        }
      }
    }
    return cur.every((x) => x == 0);
  }

  @override
  PLevel make(int difficulty, SeededRandom r) {
    final n = const [3, 4, 4, 5, 5, 5, 6, 6, 7, 7][difficulty - 1];
    final masks = <int>[];
    if (perCell) {
      for (var i = 0; i < n * n; i++) {
        var m = 1 << 4;
        for (var k = 0; k < 9; k++) {
          if (k != 4 && r.chance(0.35)) m |= 1 << k;
        }
        masks.add(m);
      }
    }
    final probe = PLevel(kind: id, w: n, h: n, clues: List.filled(n * n, 0), extra: [masks], givens: const []);
    final presses = List.filled(n * n, 0);
    final count = math.min(n * n - 1, 2 + difficulty + r.nextInt(3));
    for (final i in shuffled(n * n, r).take(count)) {
      presses[i] = 1;
    }
    final lights = List.filled(n * n, 0);
    for (var i = 0; i < n * n; i++) {
      if (presses[i] == 1) {
        for (final j in affected(probe, i)) {
          lights[j] = 1 - lights[j];
        }
      }
    }
    if (lights.every((x) => x == 0)) lights[0] = 1; // olmamalı; güvenlik
    final lv = PLevel(kind: id, w: n, h: n, clues: lights, extra: [masks], solCells: presses, givens: const []);
    if (!ok(lv, PState(presses, const [], const []), true)) {
      // güvenlik ağı: tek basış
      final l2 = List.filled(n * n, 0);
      for (final j in affected(probe, 0)) {
        l2[j] = 1;
      }
      final p2 = List.filled(n * n, 0)..[0] = 1;
      return PLevel(kind: id, w: n, h: n, clues: l2, extra: [masks], solCells: p2, givens: const []);
    }
    return lv;
  }

  @override
  CellLook look(PLevel lv, PState s, int i) => CellLook(mark: s.cells[i] == 1 ? Mark.bulb : Mark.circle);

  @override
  void paintOver(Canvas c, PLevel lv, PState s, Rect Function(int i) cell, double cs) {
    if (!perCell) return;
    // her hücrenin desenini küçük noktalarla göster
    for (var i = 0; i < lv.n; i++) {
      final r = cell(i);
      final m = lv.extra[0][i];
      for (var k = 0; k < 9; k++) {
        if (m & (1 << k) == 0) continue;
        final o = r.topLeft + Offset(cs * (0.2 + (k % 3) * 0.3), cs * (0.2 + (k ~/ 3) * 0.3));
        c.drawCircle(o, cs * 0.035, Paint()..color = const Color(0x99403830));
      }
    }
  }

  @override
  String status(PLevel lv, PState s, String lang) => '💡 ${s.cells.where((x) => x == 1).length}';
}

/// Toggles için başlangıç durumunu ipuçlarından kur (PState.empty yerine).
PState togglesStart(PLevel lv) => PState(List.of(lv.clues), List.filled(lv.linkCount, 0), List.filled(lv.borderCount, 0));
