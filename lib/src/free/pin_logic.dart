import 'package:studio_core/core/rng.dart';

import 'free_core.dart';

/// Pim Çekme: pimleri doğru sırayla çekip renkli topları kavanoza indir.
/// Hücre ızgarasında tane benzetimi (yerçekimi + çapraz kayma) ve
/// dokunma tepkimeleri:
///  * gri + renkli → gri boyanır (renkli olur)
///  * mürekkep + su → ikisi de taşa döner (zararsız)
///  * mürekkep renkli ya da gri topa değerse onu da mürekkeplendirir
/// Kazanma: durulunca kavanozda en az [tgt] renkli top, hiç gri ve
/// mürekkep yok. Kavanoza mürekkep girerse kaybedilir.
/// Bölüm verisi: w, h, g (-1 duvar, 0 boş, k>0 pim k), pt [hücre, tür ...],
/// cup (kavanoz hücreleri), np (pim sayısı), tgt, sol (çözüm sırası).
class PinLogic extends FreeLogic {
  const PinLogic();

  static const tColor = 1, tGray = 2, tInk = 3, tWater = 4, tStone = 5;

  @override
  String get id => 'pim-cekme';

  @override
  FLevel make(int d, SeededRandom r) {
    for (var attempt = 0; attempt < 120; attempt++) {
      final lv = _try(d, r);
      if (lv != null) return lv;
    }
    throw StateError('pin');
  }

  FLevel? _try(int d, SeededRandom r) {
    final shafts = d <= 2 ? 1 : (d <= 5 ? 2 : 3);
    final maxPins = const [2, 2, 3, 3, 4, 4, 5, 5, 6, 6][d - 1];
    const sw = 3;
    final w = shafts * (sw + 1) + 1;
    // Bölmeler: her şaft için yükseklik listesi (üstten alta).
    final comps = <List<int>>[for (var s = 0; s < shafts; s++) []];
    var pins = 0;
    for (var s = 0; s < shafts; s++) {
      comps[s].add(2 + r.nextInt(2));
      pins++;
    }
    while (pins < maxPins) {
      final s = r.nextInt(shafts);
      if (comps[s].length >= 3) {
        if (comps.every((c) => c.length >= 3)) break;
        continue;
      }
      comps[s].add(2 + r.nextInt(2));
      pins++;
    }
    final heights = [for (final c in comps) c.fold<int>(0, (a, b) => a + b + 1)];
    final hs = heights.reduce((a, b) => a > b ? a : b);
    final cupW = w - 2 < 5 ? w - 2 : 5;
    final funnel = ((w - 2) - cupW) ~/ 2;
    // İçerik türleri.
    final kinds = <List<int>>[for (final c in comps) List.filled(c.length, 0)];
    var balls = 0;
    for (var s = 0; s < shafts; s++) {
      for (var k = 0; k < comps[s].length; k++) {
        final x = r.nextInt(100);
        int t;
        if (d <= 1) {
          t = x < 60 ? tColor : tGray;
        } else if (d <= 3) {
          t = x < 40 ? tColor : (x < 65 ? tGray : (x < 85 ? tInk : tWater));
        } else {
          t = x < 32 ? tColor : (x < 52 ? tGray : (x < 74 ? tInk : (x < 94 ? tWater : 0)));
        }
        kinds[s][k] = t;
        if (t != 0) balls += comps[s][k] * sw;
      }
    }
    final all = [for (final k in kinds) ...k];
    if (!all.contains(tColor)) return null;
    if (d >= 4 && !all.contains(tInk)) return null;
    final cupD = (balls / cupW).ceil() + 1;
    final h = 1 + hs + funnel + cupD + 1;
    final g = List.filled(w * h, -1);
    final pt = <int>[];
    var pinId = 0;
    // şaftlar
    for (var s = 0; s < shafts; s++) {
      final x0 = 1 + s * (sw + 1);
      var y = 1 + hs - heights[s];
      for (var k = 0; k < comps[s].length; k++) {
        for (var row = 0; row < comps[s][k]; row++) {
          for (var x = x0; x < x0 + sw; x++) {
            final i = (y + row) * w + x;
            g[i] = 0;
            if (kinds[s][k] != 0) pt.addAll([i, kinds[s][k]]);
          }
        }
        y += comps[s][k];
        pinId++;
        for (var x = x0; x < x0 + sw; x++) {
          g[y * w + x] = pinId;
        }
        y++;
      }
    }
    // huni
    for (var f = 0; f < funnel; f++) {
      final y = 1 + hs + f;
      for (var x = 1 + f; x < w - 1 - f; x++) {
        g[y * w + x] = 0;
      }
    }
    // kavanoz
    final cup = <int>[];
    final cx0 = 1 + funnel;
    for (var k = 0; k < cupD; k++) {
      final y = 1 + hs + funnel + k;
      for (var x = cx0; x < cx0 + cupW; x++) {
        g[y * w + x] = 0;
        cup.add(y * w + x);
      }
    }
    final base = FLevel(id, d, r.nextInt(1 << 30), {'w': w, 'h': h, 'g': g, 'pt': pt, 'cup': cup, 'np': pinId, 'tgt': 0, 'sol': <int>[]});
    final res = explore(base);
    if (res.best <= 0) return null;
    final slack = d <= 2 ? 1 : 0;
    final tgt = res.best - slack < 1 ? 1 : res.best - slack;
    if (d >= 3 && !res.hasTrap) return null;
    final lv = FLevel(id, d, base.seed, {...base.data, 'tgt': tgt, 'sol': res.bestOrder});
    return check(lv) == null ? lv : null;
  }

  /// Bütün çekme sıralarını dolaşır: en iyi temiz kavanoz sayısı ve sırası,
  /// tuzak (kaybettiren sıra) var mı.
  static ({int best, List<int> bestOrder, bool hasTrap}) explore(FLevel lv) {
    final np = lv.i('np');
    var best = -1;
    var bestOrder = <int>[];
    var trap = false;
    final seen = <String>{};
    void go(PinSim s, List<int> order) {
      final q = s.cleanColor();
      if (q > best) {
        best = q;
        bestOrder = List.of(order);
      }
      if (s.inkInCup()) {
        trap = true;
        return;
      }
      if (!seen.add('${s.pinsLeft.join(',')}|${s.typesKey()}')) return;
      final left = [for (var k = 1; k <= np; k++) if (s.pinsLeft.contains(k)) k];
      if (left.isEmpty) {
        if (q < 0) trap = true;
        return;
      }
      for (final k in left) {
        final t = s.copy();
        t.pull(k);
        t.settle();
        go(t, [...order, k]);
      }
    }

    go(PinSim(lv)..settle(), []);
    // Hedefin altında kalan sıralar da tuzaktır.
    return (best: best, bestOrder: bestOrder, hasTrap: trap || _anyBelow(lv, best));
  }

  static bool _anyBelow(FLevel lv, int best) {
    // Pimleri dizin sırasıyla çekmek ya da tersten çekmek hedefe ulaşmıyorsa tuzak var.
    final np = lv.i('np');
    for (final order in [
      [for (var k = 1; k <= np; k++) k],
      [for (var k = np; k >= 1; k--) k]
    ]) {
      final s = PinSim(lv)..settle();
      var reached = false;
      for (final k in order) {
        s.pull(k);
        s.settle();
        if (s.inkInCup()) break;
        if (s.cleanColor() >= best) reached = true;
      }
      if (!reached) return true;
    }
    return false;
  }

  /// Bu durumdan kazandıran bir çekme sırası (yoksa null).
  static List<int>? solveFrom(PinSim start) {
    final seen = <String>{};
    List<int>? go(PinSim s, List<int> order) {
      if (s.won) return order;
      if (s.lost || s.inkInCup()) return null;
      if (!seen.add('${s.pinsLeft.join(',')}|${s.typesKey()}')) return null;
      for (final k in s.pinsLeft.toList()..sort()) {
        final t = s.copy()
          ..pull(k)
          ..settle();
        final r = go(t, [...order, k]);
        if (r != null) return r;
      }
      return null;
    }

    return go(start.copy()..settle(), []);
  }

  @override
  String? check(FLevel lv) {
    final tgt = lv.i('tgt');
    if (tgt < 1) return 'target';
    final s = PinSim(lv)..settle();
    if (s.won) return 'already solved';
    for (final k in lv.ints('sol')) {
      if (!s.pinsLeft.contains(k)) return 'bad order';
      s.pull(k);
      s.settle();
      if (s.lost) return 'solution loses';
      if (s.won) return null;
    }
    return s.won ? null : 'solution does not win';
  }
}

/// Pim çekme benzetimi (saf Dart, belirlenimci).
class PinSim {
  final FLevel lv;
  final int w, h, tgt;
  late List<int> g;
  late List<int> at; // hücre → parçacık kimliği (-1)
  late List<int> type, cell, prev;
  late Set<int> pinsLeft;
  late final Set<int> cupCells;
  int steps = 0;
  bool _settled = false;

  PinSim(this.lv)
      : w = lv.i('w'),
        h = lv.i('h'),
        tgt = lv.i('tgt') {
    g = lv.ints('g');
    final pt = lv.ints('pt');
    at = List.filled(w * h, -1);
    type = [];
    cell = [];
    for (var k = 0; k < pt.length; k += 2) {
      at[pt[k]] = type.length;
      cell.add(pt[k]);
      type.add(pt[k + 1]);
    }
    prev = List.of(cell);
    pinsLeft = {for (final v in g) if (v > 0) v};
    cupCells = lv.ints('cup').toSet();
  }

  PinSim._copy(PinSim o)
      : lv = o.lv,
        w = o.w,
        h = o.h,
        tgt = o.tgt {
    g = List.of(o.g);
    at = List.of(o.at);
    type = List.of(o.type);
    cell = List.of(o.cell);
    prev = List.of(o.prev);
    pinsLeft = Set.of(o.pinsLeft);
    cupCells = o.cupCells;
    steps = o.steps;
    _settled = o._settled;
  }

  PinSim copy() => PinSim._copy(this);

  bool get settled => _settled;

  bool free(int i) => g[i] == 0 && at[i] < 0;

  void pull(int k) {
    if (!pinsLeft.remove(k)) return;
    for (var i = 0; i < g.length; i++) {
      if (g[i] == k) g[i] = 0;
    }
    _settled = false;
  }

  /// Bir adım: hareket + tepkime. true: bir şey değişti.
  bool step() {
    steps++;
    for (var i = 0; i < cell.length; i++) {
      prev[i] = cell[i];
    }
    var changed = false;
    final moved = List.filled(type.length, false);
    final ltr = steps.isEven;
    for (var y = h - 2; y >= 0; y--) {
      for (var q = 0; q < w; q++) {
        final x = ltr ? q : w - 1 - q;
        final i = y * w + x;
        final id = at[i];
        if (id < 0 || moved[id]) continue;
        int to = -1;
        if (free(i + w)) {
          to = i + w;
        } else {
          final first = ((steps + x + y) & 1) == 0 ? -1 : 1;
          for (final dx in [first, -first]) {
            final nx = x + dx;
            if (nx < 0 || nx >= w) continue;
            if (free(y * w + nx) && free((y + 1) * w + nx)) {
              to = (y + 1) * w + nx;
              break;
            }
          }
        }
        if (to >= 0) {
          at[i] = -1;
          at[to] = id;
          cell[id] = to;
          moved[id] = true;
          changed = true;
        }
      }
    }
    if (_react()) changed = true;
    if (!changed) _settled = true;
    return changed;
  }

  bool _react() {
    final next = List.of(type);
    var any = false;
    for (var id = 0; id < type.length; id++) {
      final i = cell[id];
      final x = i % w;
      for (final j in [if (x < w - 1) i + 1, i + w]) {
        if (j >= at.length) continue;
        final o = at[j];
        if (o < 0) continue;
        final a = type[id], b = type[o];
        void set(int who, int t) {
          if (next[who] == t) return;
          // mürekkep ve taş önceliklidir
          if (next[who] == PinLogic.tStone) return;
          if (next[who] == PinLogic.tInk && t == PinLogic.tColor) return;
          next[who] = t;
          any = true;
        }

        if ((a == PinLogic.tInk && b == PinLogic.tWater) || (a == PinLogic.tWater && b == PinLogic.tInk)) {
          set(id, PinLogic.tStone);
          set(o, PinLogic.tStone);
        } else if (a == PinLogic.tInk && (b == PinLogic.tColor || b == PinLogic.tGray)) {
          set(o, PinLogic.tInk);
        } else if (b == PinLogic.tInk && (a == PinLogic.tColor || a == PinLogic.tGray)) {
          set(id, PinLogic.tInk);
        } else if (a == PinLogic.tGray && b == PinLogic.tColor) {
          set(id, PinLogic.tColor);
        } else if (b == PinLogic.tGray && a == PinLogic.tColor) {
          set(o, PinLogic.tColor);
        }
      }
    }
    if (any) type = next;
    return any;
  }

  void settle([int max = 600]) {
    for (var k = 0; k < max && !_settled; k++) {
      step();
    }
  }

  int _cupCount(int t) {
    var n = 0;
    for (var id = 0; id < type.length; id++) {
      if (type[id] == t && cupCells.contains(cell[id])) n++;
    }
    return n;
  }

  bool inkInCup() => _cupCount(PinLogic.tInk) > 0;

  /// Kavanoz temizse renkli sayısı, değilse -1.
  int cleanColor() {
    if (_cupCount(PinLogic.tInk) > 0 || _cupCount(PinLogic.tGray) > 0) return -1;
    return _cupCount(PinLogic.tColor);
  }

  int get cupColor => _cupCount(PinLogic.tColor);

  bool get won => _settled && cleanColor() >= tgt && tgt > 0;

  bool get lost {
    if (inkInCup()) return true;
    final alive = type.where((t) => t == PinLogic.tColor || t == PinLogic.tGray).length;
    if (alive < tgt) return true;
    return _settled && pinsLeft.isEmpty && !won;
  }

  String typesKey() {
    final b = StringBuffer();
    for (var id = 0; id < type.length; id++) {
      b
        ..write(cell[id])
        ..write(':')
        ..write(type[id])
        ..write(',');
    }
    return b.toString();
  }
}
