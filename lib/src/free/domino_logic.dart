import 'package:studio_core/core/rng.dart';

import 'free_core.dart';

/// Domino Koşulları: verilen dominoları tahtaya yerleştir; renkli
/// bölgelerin koşulları (toplam, eşit, farklı, küçük, büyük) sağlansın.
/// Bölüm verisi:
///  * w, h: ızgara; m: etkin hücre (1/0)
///  * reg: hücre başına bölge (-1 koşulsuz); rc: bölge başına [tür, değer]
///    tür 0 toplam = değer, 1 hepsi eşit, 2 hepsi farklı, 3 toplam < değer,
///    4 toplam > değer
///  * dom: dominolar [a0, b0, a1, b1, ...] (a <= b)
///  * sol: çözüm değerleri (-1 etkin değil); pair: çözümdeki eş hücre
class DominoLogic extends FreeLogic {
  const DominoLogic();

  static const cSum = 0, cEq = 1, cDiff = 2, cLess = 3, cMore = 4;

  @override
  String get id => 'domino-kosullari';

  static int dominoCount(int d) => const [3, 4, 5, 6, 7, 8, 9, 10, 12, 14][d.clamp(1, 10) - 1];

  @override
  FLevel make(int d, SeededRandom r) {
    for (var attempt = 0; attempt < 60; attempt++) {
      final lv = _try(d, r);
      if (lv != null) return lv;
    }
    throw StateError('domino');
  }

  FLevel? _try(int d, SeededRandom r) {
    final n = dominoCount(d);
    final side = n <= 4 ? 4 : (n <= 6 ? 5 : (n <= 9 ? 6 : 7));
    final w = side, h = side;
    final m = List.filled(w * h, 0);
    final pair = List.filled(w * h, -1);
    List<int> nb(int i) {
      final x = i % w, y = i ~/ w;
      return [if (x > 0) i - 1, if (x < w - 1) i + 1, if (y > 0) i - w, if (y < h - 1) i + w];
    }

    // Biçim: ortadan büyüyen domino döşemesi.
    final c0 = (h ~/ 2) * w + (w ~/ 2) - 1;
    m[c0] = 1;
    m[c0 + 1] = 1;
    pair[c0] = c0 + 1;
    pair[c0 + 1] = c0;
    for (var k = 1; k < n; k++) {
      final cands = <(int, int, int)>[];
      for (var a = 0; a < w * h; a++) {
        if (m[a] == 1) continue;
        final touch = nb(a).where((j) => m[j] == 1).length;
        if (touch == 0) continue;
        for (final b in nb(a)) {
          if (m[b] == 1) continue;
          final tb = nb(b).where((j) => m[j] == 1).length;
          cands.add((a, b, touch + tb));
        }
      }
      if (cands.isEmpty) return null;
      // Toplu biçim için çok dokunan adaylar daha olası.
      var total = 0;
      for (final c in cands) {
        total += c.$3 * c.$3;
      }
      var pick = r.nextInt(total);
      var chosen = cands.first;
      for (final c in cands) {
        pick -= c.$3 * c.$3;
        if (pick < 0) {
          chosen = c;
          break;
        }
      }
      m[chosen.$1] = 1;
      m[chosen.$2] = 1;
      pair[chosen.$1] = chosen.$2;
      pair[chosen.$2] = chosen.$1;
    }
    // Dominolar: farklı taşlar (kolayda küçük sayılar).
    final maxPip = d <= 2 ? 4 : (d <= 4 ? 5 : 6);
    final all = <(int, int)>[
      for (var a = 0; a <= maxPip; a++)
        for (var b = a; b <= maxPip; b++) (a, b)
    ];
    r.shuffle(all);
    if (all.length < n) return null;
    final chosen = all.take(n).toList();
    final sol = List.filled(w * h, -1);
    var di = 0;
    for (var i = 0; i < w * h; i++) {
      if (m[i] == 0 || sol[i] >= 0) continue;
      final j = pair[i];
      final (a, b) = chosen[di++];
      if (r.chance(0.5)) {
        sol[i] = a;
        sol[j] = b;
      } else {
        sol[i] = b;
        sol[j] = a;
      }
    }
    // Bölgeler.
    final reg = List.filled(w * h, -1);
    final regions = <List<int>>[];
    final order = [for (var i = 0; i < w * h; i++) if (m[i] == 1) i];
    r.shuffle(order);
    final maxSize = d <= 2 ? 2 : (d <= 5 ? 3 : 4);
    for (final s in order) {
      if (reg[s] >= 0) continue;
      final id = regions.length;
      final cells = [s];
      reg[s] = id;
      final target = r.chance(0.15) ? 1 : 2 + r.nextInt(maxSize - 1);
      while (cells.length < target) {
        final opts = <int>[
          for (final c in cells)
            for (final j in nb(c))
              if (m[j] == 1 && reg[j] < 0) j
        ];
        if (opts.isEmpty) break;
        final j = opts[r.nextInt(opts.length)];
        reg[j] = id;
        cells.add(j);
      }
      regions.add(cells);
    }
    // Koşullar: bir kısmı koşulsuz kalır.
    final free = d <= 3 ? 0.08 : (d <= 6 ? 0.2 : 0.32);
    final rc = <List<int>>[];
    final keep = <List<int>>[];
    for (final cells in regions) {
      if (r.nextDouble() < free) {
        for (final c in cells) {
          reg[c] = -1;
        }
        continue;
      }
      final vals = [for (final c in cells) sol[c]];
      final sum = vals.fold<int>(0, (a, b) => a + b);
      final opts = <List<int>>[];
      final hard = d >= 5;
      opts.add([cSum, sum]);
      if (!hard) opts.add([cSum, sum]);
      if (cells.length >= 2 && vals.toSet().length == 1) {
        opts.addAll([
          [cEq, 0],
          [cEq, 0]
        ]);
      }
      if (cells.length >= 2 && vals.toSet().length == cells.length && d >= 3) opts.add([cDiff, 0]);
      if (d >= 3) {
        opts.add([cLess, sum + 1 + r.nextInt(hard ? 3 : 2)]);
        if (sum > 0) opts.add([cMore, sum - 1 - r.nextInt(sum >= 3 && hard ? 3 : 1)]);
      }
      final c = opts[r.nextInt(opts.length)];
      if (c[0] == cMore && c[1] < 0) c[1] = 0;
      final id = keep.length;
      for (final x in cells) {
        reg[x] = id;
      }
      keep.add(cells);
      rc.add(c);
    }
    // Benzersizlik: iki çözümün ayrıldığı hücreyi sıkılaştır.
    for (var round = 0; round < 60; round++) {
      final lv = _level(d, r, w, h, m, reg, rc, chosen, sol, pair);
      final found = <List<int>>[];
      final cnt = countSolutions(lv, limit: 2, budget: 120000, out: found);
      if (cnt == 1) return _loosen(d, r, w, h, m, reg, rc, chosen, sol, pair) ?? lv;
      int cell;
      if (cnt != null && cnt >= 2 && found.length >= 2) {
        final diff = [for (var i = 0; i < w * h; i++) if (m[i] == 1 && found[0][i] != found[1][i]) i];
        if (diff.isEmpty) return null;
        cell = diff[r.nextInt(diff.length)];
      } else {
        // Bütçe aşıldı: en az bilgili hücreyi sabitle.
        final loose = [for (var i = 0; i < w * h; i++) if (m[i] == 1 && (reg[i] < 0 || rc[reg[i]][0] != cSum || _regionSize(reg, reg[i]) > 1)) i];
        if (loose.isEmpty) return null;
        cell = loose[r.nextInt(loose.length)];
      }
      _tighten(cell, w, reg, rc, sol);
    }
    return null;
  }

  /// Benzersizliği bozmadan koşulları gevşet: bitişik toplamları birleştir,
  /// koşul kaldır, toplamı eşitsizliğe çevir. Zorluk arttıkça daha çok denenir.
  FLevel? _loosen(int d, SeededRandom r, int w, int h, List<int> m, List<int> reg, List<List<int>> rc, List<(int, int)> doms,
      List<int> sol, List<int> pair) {
    bool unique() => countSolutions(_level(d, r.copy(), w, h, m, reg, rc, doms, sol, pair), limit: 2, budget: 60000) == 1;
    List<int> cellsOf(int id) => [for (var i = 0; i < reg.length; i++) if (reg[i] == id) i];
    final tries = 4 + 3 * d;
    final maxRegion = d <= 3 ? 3 : (d <= 6 ? 4 : 5);
    for (var t = 0; t < tries; t++) {
      final ids = [for (var id = 0; id < rc.length; id++) if (reg.contains(id)) id];
      if (ids.isEmpty) break;
      final id = ids[r.nextInt(ids.length)];
      final cells = cellsOf(id);
      final sum = cells.fold<int>(0, (a, c) => a + sol[c]);
      final op = r.nextInt(d <= 3 ? 1 : 3);
      final saveReg = List.of(reg);
      final saveRc = [for (final c in rc) List.of(c)];
      if (op == 0) {
        // Bitişik bir toplam bölgesiyle birleştir.
        if (rc[id][0] != cSum) continue;
        final nbIds = <int>{};
        for (final c in cells) {
          final x = c % w;
          for (final j in [if (x > 0) c - 1, if (x < w - 1) c + 1, c - w, c + w]) {
            if (j >= 0 && j < reg.length && reg[j] >= 0 && reg[j] != id && rc[reg[j]][0] == cSum) nbIds.add(reg[j]);
          }
        }
        if (nbIds.isEmpty) continue;
        final o = nbIds.elementAt(r.nextInt(nbIds.length));
        final oc = cellsOf(o);
        if (oc.length + cells.length > maxRegion) continue;
        for (final c in oc) {
          reg[c] = id;
        }
        rc[id] = [cSum, sum + oc.fold<int>(0, (a, c) => a + sol[c])];
      } else if (op == 1) {
        if (d < 5) continue;
        for (final c in cells) {
          reg[c] = -1;
        }
      } else {
        final vals = [for (final c in cells) sol[c]];
        if (cells.length >= 2 && vals.toSet().length == 1 && r.chance(0.5)) {
          rc[id] = [cEq, 0];
        } else if (r.chance(0.5)) {
          rc[id] = [cLess, sum + 1];
        } else if (sum > 0) {
          rc[id] = [cMore, sum - 1];
        } else {
          continue;
        }
      }
      if (!unique()) {
        reg.setAll(0, saveReg);
        rc
          ..clear()
          ..addAll(saveRc);
      }
    }
    final lv = _level(d, r, w, h, m, reg, rc, doms, sol, pair);
    return countSolutions(lv, limit: 2, budget: 120000) == 1 ? lv : null;
  }

  static int _regionSize(List<int> reg, int id) => reg.where((x) => x == id).length;

  /// Hücreyi tam bilgiye yaklaştır: koşulsuzsa tek hücreli toplam, koşulu
  /// toplam değilse toplama çevir, çok hücreli toplamsa ayır.
  void _tighten(int cell, int w, List<int> reg, List<List<int>> rc, List<int> sol) {
    final id = reg[cell];
    if (id < 0) {
      reg[cell] = rc.length;
      rc.add([cSum, sol[cell]]);
      return;
    }
    final cells = [for (var i = 0; i < reg.length; i++) if (reg[i] == id) i];
    final sum = cells.fold<int>(0, (a, c) => a + sol[c]);
    if (rc[id][0] != cSum) {
      rc[id] = [cSum, sum];
      return;
    }
    if (cells.length > 2) {
      // Hücreyi bölgedeki bir komşusuyla ayır (ikili toplam).
      final x = cell % w;
      final mates = [for (final j in [if (x > 0) cell - 1, if (x < w - 1) cell + 1, cell - w, cell + w]) if (j >= 0 && j < reg.length && reg[j] == id) j];
      final part = [cell, if (mates.isNotEmpty) mates.first];
      final nid = rc.length;
      for (final c in part) {
        reg[c] = nid;
      }
      final ps = part.fold<int>(0, (a, c) => a + sol[c]);
      rc.add([cSum, ps]);
      rc[id] = [cSum, sum - ps];
    } else if (cells.length > 1) {
      reg[cell] = rc.length;
      rc.add([cSum, sol[cell]]);
      rc[id] = [cSum, sum - sol[cell]];
    }
  }

  FLevel _level(int d, SeededRandom r, int w, int h, List<int> m, List<int> reg, List<List<int>> rc, List<(int, int)> doms,
      List<int> sol, List<int> pair) {
    final sorted = List.of(doms)..sort((a, b) => a.$1 != b.$1 ? a.$1 - b.$1 : a.$2 - b.$2);
    // Bölge kimliklerini sıkıştır (boş kalanlar atılır).
    final remap = <int, int>{};
    final reg2 = [
      for (final v in reg)
        if (v < 0) -1 else remap.putIfAbsent(v, () => remap.length)
    ];
    final rc2 = List.filled(remap.length, const <int>[]);
    remap.forEach((old, nw) => rc2[nw] = rc[old]);
    return FLevel(id, d, r.nextInt(1 << 30), {
      'w': w,
      'h': h,
      'm': List.of(m),
      'reg': reg2,
      'rc': [for (final c in rc2) List.of(c)],
      'dom': [for (final x in sorted) ...[x.$1, x.$2]],
      'sol': List.of(sol),
      'pair': List.of(pair),
    });
  }

  static List<List<int>> rcOf(FLevel lv) => [for (final c in (lv.data['rc'] as List)) [for (final v in (c as List)) (v as num).toInt()]];

  /// Bölge koşulu; [vals] bölgenin dolu hücreleri, [left] boş hücre sayısı.
  static bool regionOk(List<int> c, List<int> vals, int left) {
    var s = 0;
    for (final v in vals) {
      s += v;
    }
    switch (c[0]) {
      case cSum:
        return s <= c[1] && s + 6 * left >= c[1] && (left > 0 || s == c[1]);
      case cEq:
        return vals.every((v) => v == vals.first);
      case cDiff:
        return vals.toSet().length == vals.length;
      case cLess:
        return s < c[1];
      case cMore:
        return s + 6 * left > c[1];
    }
    return true;
  }

  /// Hücre değerleri ([-1] boş) bütün koşulları sağlıyor mu.
  static bool allOk(FLevel lv, List<int> vals, {bool complete = true}) {
    final reg = lv.ints('reg');
    final rc = rcOf(lv);
    for (var id = 0; id < rc.length; id++) {
      final v = <int>[];
      var left = 0;
      for (var i = 0; i < reg.length; i++) {
        if (reg[i] != id) continue;
        if (vals[i] < 0) {
          left++;
        } else {
          v.add(vals[i]);
        }
      }
      if (complete && left > 0) return false;
      if (!regionOk(rc[id], v, left)) return false;
    }
    return true;
  }

  /// Farklı değer atamalı çözüm sayısı (en çok [limit]); bütçe aşılırsa null.
  static int? countSolutions(FLevel lv, {int limit = 2, int budget = 100000, List<List<int>>? out}) {
    final w = lv.i('w'), h = lv.i('h');
    final m = lv.ints('m'), reg = lv.ints('reg');
    final rc = rcOf(lv);
    final dom = lv.ints('dom');
    final nd = dom.length ~/ 2;
    final used = List.filled(nd, false);
    final vals = List.filled(w * h, -1);
    final regCells = <List<int>>[for (var i = 0; i < rc.length; i++) []];
    for (var i = 0; i < reg.length; i++) {
      if (reg[i] >= 0) regCells[reg[i]].add(i);
    }
    bool okAt(int cell) {
      final id = reg[cell];
      if (id < 0) return true;
      final v = <int>[];
      var left = 0;
      for (final c in regCells[id]) {
        if (vals[c] < 0) {
          left++;
        } else {
          v.add(vals[c]);
        }
      }
      return regionOk(rc[id], v, left);
    }

    final seen = <String>{};
    var nodes = 0;
    var over = false;
    void go(int from) {
      if (seen.length >= limit || over) return;
      var c = from;
      while (c < w * h && (m[c] == 0 || vals[c] >= 0)) {
        c++;
      }
      if (c >= w * h) {
        final key = vals.join(',');
        if (seen.add(key)) out?.add(List.of(vals));
        return;
      }
      final x = c % w;
      final partners = [if (x < w - 1 && m[c + 1] == 1 && vals[c + 1] < 0) c + 1, if (c + w < w * h && m[c + w] == 1 && vals[c + w] < 0) c + w];
      for (final p in partners) {
        for (var k = 0; k < nd; k++) {
          if (used[k]) continue;
          final a = dom[2 * k], b = dom[2 * k + 1];
          for (var o = 0; o < (a == b ? 1 : 2); o++) {
            if (++nodes > budget) {
              over = true;
              return;
            }
            vals[c] = o == 0 ? a : b;
            vals[p] = o == 0 ? b : a;
            if (okAt(c) && okAt(p)) {
              used[k] = true;
              go(c + 1);
              used[k] = false;
            }
            vals[c] = -1;
            vals[p] = -1;
            if (seen.length >= limit || over) return;
          }
        }
      }
    }

    go(0);
    if (over && seen.length < limit) return null;
    return seen.length;
  }

  @override
  String? check(FLevel lv) {
    final m = lv.ints('m'), sol = lv.ints('sol'), pair = lv.ints('pair');
    final dom = lv.ints('dom');
    // Çözüm döşemesi verilen dominoları tam bir kez kullanır.
    final need = <String>[for (var k = 0; k < dom.length; k += 2) '${dom[k]}-${dom[k + 1]}']..sort();
    final got = <String>[];
    for (var i = 0; i < m.length; i++) {
      if (m[i] == 0) continue;
      final j = pair[i];
      if (j < 0 || pair[j] != i || m[j] == 0) return 'bad tiling';
      final dx = (i - j).abs();
      if (dx != 1 && dx != lv.i('w')) return 'not adjacent';
      if (i < j) {
        final a = sol[i] < sol[j] ? sol[i] : sol[j], b = sol[i] < sol[j] ? sol[j] : sol[i];
        got.add('$a-$b');
      }
    }
    got.sort();
    if (got.join() != need.join()) return 'domino set';
    if (!allOk(lv, sol)) return 'solution breaks rules';
    final c = countSolutions(lv, limit: 2, budget: 120000);
    if (c != 1) return 'not unique ($c)';
    return null;
  }
}
