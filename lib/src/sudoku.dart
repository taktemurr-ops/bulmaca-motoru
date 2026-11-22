import 'dart:math' as math;
import 'dart:ui';

import 'package:studio_core/core/rng.dart';

import 'core.dart';

/// Sudoku kural parçaları; çeşitler bunların birleşimidir.
enum SRule {
  diag, // iki köşegen
  hyper, // dört ek pencere
  jigsaw, // düzensiz bölgeler
  killer, // toplam kafesleri
  thermo, // termometre: haznededen uca artar
  arrow, // ok: dairedeki rakam ok üzerindekilerin toplamı
  kropki, // beyaz nokta ardışık, siyah nokta iki kat (hepsi gösterilir)
  xv, // X toplam 10, V toplam 5 (hepsi gösterilir)
  greater, // komşular arası büyüktür işaretleri
  sandwich, // 1 ile en büyük rakam arasındaki toplam
  evenOdd, // çift/tek işaretli hücreler
  antiKnight, // at hamlesi uzaklığında aynı rakam yok
  antiKing, // çapraz komşularda aynı rakam yok
  nonConsec, // yan yana hücreler ardışık olamaz
  disjoint, // kutulardaki aynı konumlar farklı
  centerDot, // kutu merkezleri farklı
  asterisk, // yıldız biçimli dokuz hücre farklı
  palindrome, // çizgi iki yönden aynı okunur
  renban, // çizgide ardışık rakamlar (sırasız)
  whisper, // çizgide komşular arasında en az 5 fark
  consecutive, // yalnızca ardışık çiftler işaretli (beyaz nokta, hepsi gösterilir)
  cageNoSum, // toplamsız kafes: yalnız farklı rakamlar
}

class SudokuSpec {
  final int n; // 4, 6, 8, 9
  final Set<SRule> rules;
  const SudokuSpec(this.n, this.rules);
}

/// extra dizinleri
const _xGroups = 0, _xCages = 1, _xThermo = 2, _xArrows = 3, _xPairs = 4, _xParity = 5, _xSandwich = 6, _xLines = 7, _xFlags = 8;

class SudokuKind extends PuzzleKind {
  final String kindId;
  final SudokuSpec Function(int d) specFor;
  const SudokuKind(this.kindId, this.specFor);

  @override
  String get id => kindId;

  @override
  CellInput get cellInput => CellInput.digits;

  @override
  int cellStates(PLevel lv) => lv.param + 1;

  @override
  double extraGivenRatio(int d) => d <= 2 ? 0.35 : (d <= 4 ? 0.2 : (d <= 6 ? 0.08 : 0));

  @override
  double maxGivenRatio(int d) => 0.8;

  static (int, int) boxDims(int n) => switch (n) { 4 => (2, 2), 6 => (3, 2), 8 => (4, 2), _ => (3, 3) };

  // ------------------------------------------------------------------ üretim
  @override
  PLevel make(int d, SeededRandom r) {
    final sp = specFor(d);
    for (var attempt = 0; attempt < 30; attempt++) {
      final lv = _tryMake(sp, d, r);
      if (lv != null) return lv;
    }
    // Güvenli geri dönüş: klasik
    return _tryMake(SudokuSpec(sp.n, const {}), d, r)!;
  }

  PLevel? _tryMake(SudokuSpec sp, int d, SeededRandom r) {
    final n = sp.n;
    final (bw, bh) = boxDims(n);
    List<int> regions;
    if (sp.rules.contains(SRule.jigsaw)) {
      final j = jigsawRegions(n, r);
      if (j == null) return null;
      regions = j;
    } else {
      regions = [for (var i = 0; i < n * n; i++) ((i ~/ n) ~/ bh) * (n ~/ bw) + (i % n) ~/ bw];
    }
    final groups = <int>[];
    void addGroup(List<int> g) => groups.addAll([g.length, ...g]);
    if (sp.rules.contains(SRule.diag)) {
      addGroup([for (var k = 0; k < n; k++) k * n + k]);
      addGroup([for (var k = 0; k < n; k++) k * n + (n - 1 - k)]);
    }
    if (sp.rules.contains(SRule.hyper) && n == 9) {
      for (final (ox, oy) in const [(1, 1), (5, 1), (1, 5), (5, 5)]) {
        addGroup([for (var y = 0; y < 3; y++) for (var x = 0; x < 3; x++) (oy + y) * 9 + ox + x]);
      }
    }
    if (sp.rules.contains(SRule.disjoint) && !sp.rules.contains(SRule.jigsaw)) {
      for (var p = 0; p < bw * bh; p++) {
        addGroup([
          for (var by = 0; by < n ~/ bh; by++)
            for (var bx = 0; bx < n ~/ bw; bx++) (by * bh + p ~/ bw) * n + bx * bw + p % bw
        ]);
      }
    }
    if (sp.rules.contains(SRule.centerDot) && n == 9) {
      addGroup([for (var by = 0; by < 3; by++) for (var bx = 0; bx < 3; bx++) (by * 3 + 1) * 9 + bx * 3 + 1]);
    }
    if (sp.rules.contains(SRule.asterisk) && n == 9) {
      addGroup(const [13, 20, 24, 36, 40, 44, 56, 60, 67]);
    }
    final flags = [
      sp.rules.contains(SRule.antiKnight) ? 1 : 0,
      sp.rules.contains(SRule.antiKing) ? 1 : 0,
      sp.rules.contains(SRule.nonConsec) ? 1 : 0,
      sp.rules.contains(SRule.kropki) || sp.rules.contains(SRule.consecutive) ? 1 : 0, // negatif nokta kuralı
      sp.rules.contains(SRule.xv) ? 1 : 0, // negatif XV
    ];
    var lv = PLevel(
      kind: id,
      w: n,
      h: n,
      clues: const [],
      regions: regions,
      extra: [groups, const [], const [], const [], const [], const [], const [], const [], flags],
      givens: List.filled(n * n, -1),
      param: n,
    );
    // Yapısal kurallarla rastgele tam çözüm.
    final solver = _SudokuSolver(lv);
    final sol = solver.randomFill(r, 60000);
    if (sol == null) return null;
    final extra = [for (final e in lv.extra) List.of(e)];
    // Çözümden türetilen ipuçları
    if (sp.rules.contains(SRule.killer) || sp.rules.contains(SRule.cageNoSum)) {
      extra[_xCages] = _cages(n, sol, r, sp.rules.contains(SRule.cageNoSum) ? 0 : 1, d);
    }
    if (sp.rules.contains(SRule.thermo)) extra[_xThermo] = _thermos(n, sol, r, d);
    if (sp.rules.contains(SRule.arrow)) extra[_xArrows] = _arrows(n, sol, r, d);
    final pairs = <int>[];
    if (sp.rules.contains(SRule.kropki) || sp.rules.contains(SRule.consecutive)) {
      for (var i = 0; i < n * n; i++) {
        for (final j in [if (i % n < n - 1) i + 1, if (i ~/ n < n - 1) i + n]) {
          final a = sol[i], b = sol[j];
          if ((a - b).abs() == 1) {
            pairs.addAll([i, j, 0]);
          } else if (!sp.rules.contains(SRule.consecutive) && (a == 2 * b || b == 2 * a)) {
            pairs.addAll([i, j, 1]);
          }
        }
      }
    }
    if (sp.rules.contains(SRule.xv)) {
      for (var i = 0; i < n * n; i++) {
        for (final j in [if (i % n < n - 1) i + 1, if (i ~/ n < n - 1) i + n]) {
          final s = sol[i] + sol[j];
          if (s == 10) pairs.addAll([i, j, 2]);
          if (s == 5) pairs.addAll([i, j, 3]);
        }
      }
    }
    if (sp.rules.contains(SRule.greater)) {
      for (var i = 0; i < n * n; i++) {
        for (final j in [if (i % n < n - 1) i + 1, if (i ~/ n < n - 1) i + n]) {
          if (r.chance(d <= 4 ? 0.55 : 0.4)) pairs.addAll(sol[i] > sol[j] ? [i, j, 4] : [j, i, 4]);
        }
      }
    }
    extra[_xPairs] = pairs;
    if (sp.rules.contains(SRule.evenOdd)) {
      final par = List.filled(n * n, -1);
      for (var i = 0; i < n * n; i++) {
        if (r.chance(0.32)) par[i] = sol[i] % 2;
      }
      extra[_xParity] = par;
    }
    if (sp.rules.contains(SRule.sandwich)) {
      final sw = <int>[];
      for (var line = 0; line < 2 * n; line++) {
        final cells = line < n ? [for (var x = 0; x < n; x++) line * n + x] : [for (var y = 0; y < n; y++) y * n + line - n];
        final vals = [for (final c in cells) sol[c]];
        final a = vals.indexOf(1), b = vals.indexOf(n);
        final lo = math.min(a, b), hi = math.max(a, b);
        var sum = 0;
        for (var k = lo + 1; k < hi; k++) {
          sum += vals[k];
        }
        sw.add(sum);
      }
      extra[_xSandwich] = sw;
    }
    final lines = <int>[];
    for (final (rule, code) in [(SRule.palindrome, 0), (SRule.renban, 1), (SRule.whisper, 2)]) {
      if (sp.rules.contains(rule)) lines.addAll(_lines(n, sol, r, code, d));
    }
    extra[_xLines] = lines;
    lv = PLevel(
      kind: id,
      w: n,
      h: n,
      clues: const [],
      regions: regions,
      extra: extra,
      solCells: sol,
      givens: List.filled(n * n, -1),
      param: n,
    );
    return lv;
  }

  static List<int>? jigsawRegions(int n, SeededRandom r) {
    for (var attempt = 0; attempt < 200; attempt++) {
      final reg = List.filled(n * n, -1);
      final size = List.filled(n, 0);
      // Tohumlar: her satıra bir tane, dağınık sütunlar.
      final cols = shuffled(n, r);
      for (var k = 0; k < n; k++) {
        reg[k * n + cols[k]] = k;
        size[k] = 1;
      }
      var stuck = false;
      for (var step = 0; step < n * n * 8 && !stuck; step++) {
        // En küçük bölgeyi büyüt.
        var best = -1;
        for (var k = 0; k < n; k++) {
          if (size[k] < n && (best < 0 || size[k] < size[best] || (size[k] == size[best] && r.chance(0.5)))) best = k;
        }
        if (best < 0) break;
        final cand = <int>[];
        for (var i = 0; i < n * n; i++) {
          if (reg[i] != best) continue;
          final x = i % n, y = i ~/ n;
          if (x > 0 && reg[i - 1] < 0) cand.add(i - 1);
          if (x < n - 1 && reg[i + 1] < 0) cand.add(i + 1);
          if (y > 0 && reg[i - n] < 0) cand.add(i - n);
          if (y < n - 1 && reg[i + n] < 0) cand.add(i + n);
        }
        if (cand.isEmpty) {
          stuck = true;
          break;
        }
        final c = cand[r.nextInt(cand.length)];
        reg[c] = best;
        size[best]++;
      }
      if (!stuck && !reg.contains(-1)) return reg;
    }
    return null;
  }

  static List<int> _cages(int n, List<int> sol, SeededRandom r, int withSum, int d) {
    final owner = List.filled(n * n, -1);
    final out = <int>[];
    final maxSize = d <= 3 ? 3 : (d <= 6 ? 4 : 5);
    for (final start in shuffled(n * n, r)) {
      if (owner[start] >= 0) continue;
      final cage = [start];
      owner[start] = start;
      final target = 1 + r.nextInt(maxSize);
      while (cage.length < target) {
        final cand = <int>[];
        for (final c in cage) {
          final x = c % n, y = c ~/ n;
          for (final nb in [if (x > 0) c - 1, if (x < n - 1) c + 1, if (y > 0) c - n, if (y < n - 1) c + n]) {
            if (owner[nb] < 0 && !cage.any((q) => sol[q] == sol[nb])) cand.add(nb);
          }
        }
        if (cand.isEmpty) break;
        final c = cand[r.nextInt(cand.length)];
        owner[c] = start;
        cage.add(c);
      }
      if (cage.length == 1 && withSum == 0) continue; // tek hücrelik toplamsız kafes anlamsız
      final sum = withSum == 1 ? cage.fold<int>(0, (a, c) => a + sol[c]) : 0;
      out.addAll([sum, cage.length, ...cage]);
    }
    return out;
  }

  static List<int> _walk(int n, List<int> sol, SeededRandom r, int start, bool Function(int from, int to, List<int> path) good, int maxLen) {
    final path = [start];
    while (path.length < maxLen) {
      final c = path.last;
      final x = c % n, y = c ~/ n;
      final cand = <int>[];
      for (var dy = -1; dy <= 1; dy++) {
        for (var dx = -1; dx <= 1; dx++) {
          if (dx == 0 && dy == 0) continue;
          final nx = x + dx, ny = y + dy;
          if (nx < 0 || ny < 0 || nx >= n || ny >= n) continue;
          final nb = ny * n + nx;
          if (!path.contains(nb) && good(c, nb, path)) cand.add(nb);
        }
      }
      if (cand.isEmpty) break;
      path.add(cand[r.nextInt(cand.length)]);
    }
    return path;
  }

  static List<int> _thermos(int n, List<int> sol, SeededRandom r, int d) {
    final used = <int>{};
    final out = <int>[];
    final count = n <= 6 ? 3 : (d <= 4 ? 6 : 5);
    for (final s in shuffled(n * n, r)) {
      if (out.isNotEmpty && out.where((_) => true).length > 400) break;
      if (used.contains(s) || sol[s] > n ~/ 2) continue;
      final p = _walk(n, sol, r, s, (a, b, path) => sol[b] > sol[a] && !used.contains(b), n <= 6 ? 4 : 6);
      if (p.length < 3) continue;
      used.addAll(p);
      out.addAll([p.length, ...p]);
      if (_countLines(out) >= count) break;
    }
    return out;
  }

  static int _countLines(List<int> l) {
    var k = 0, i = 0;
    while (i < l.length) {
      i += l[i] + 1;
      k++;
    }
    return k;
  }

  static List<int> _arrows(int n, List<int> sol, SeededRandom r, int d) {
    final used = <int>{};
    final out = <int>[];
    final count = n <= 6 ? 3 : 6;
    for (final s in shuffled(n * n, r)) {
      if (used.contains(s) || sol[s] < 3) continue;
      // Daireden çıkan ve toplamı daireye eşit yol ara.
      for (var tries = 0; tries < 12; tries++) {
        var sum = 0;
        final p = _walk(n, sol, r, s, (a, b, path) {
          if (used.contains(b)) return false;
          final add = sol[b];
          if (sum + add > sol[s]) return false;
          return true;
        }, 4);
        // Toplamı yol boyunca hesapla, hedefe ulaşan önek
        var acc = 0;
        var cut = -1;
        for (var k = 1; k < p.length; k++) {
          acc += sol[p[k]];
          if (acc == sol[s] && k >= 2) {
            cut = k;
            break;
          }
          if (acc > sol[s]) break;
        }
        sum = 0;
        if (cut > 0) {
          final arrow = p.sublist(0, cut + 1);
          used.addAll(arrow);
          out.addAll([arrow.length, ...arrow]);
          break;
        }
      }
      if (_countLines(out) >= count) break;
    }
    return out;
  }

  /// Çizgiler: [uzunluk+1? kod, hücreler]: biçim [len, code, cells...]
  static List<int> _lines(int n, List<int> sol, SeededRandom r, int code, int d) {
    final out = <int>[];
    final used = <int>{};
    final want = n <= 6 ? 2 : 4;
    var made = 0;
    for (final s in shuffled(n * n, r)) {
      if (used.contains(s)) continue;
      List<int> p;
      switch (code) {
        case 0: // palindrom: iki uçtan eş değerler; ortadan büyüt
          p = _palin(n, sol, r, s, used);
        case 1: // renban: ardışık küme
          p = _walk(n, sol, r, s, (a, b, path) {
            if (used.contains(b)) return false;
            final vals = [for (final c in path) sol[c], sol[b]];
            if (vals.toSet().length != vals.length) return false;
            final mx = vals.reduce(math.max), mn = vals.reduce(math.min);
            return mx - mn == vals.length - 1;
          }, n <= 6 ? 3 : 4);
        default: // fısıltı: en az 5 fark (9'luk), en az n/2 fark
          final gap = n == 9 ? 5 : (n ~/ 2);
          p = _walk(n, sol, r, s, (a, b, path) => !used.contains(b) && (sol[a] - sol[b]).abs() >= gap, 5);
      }
      if (p.length < 3) continue;
      used.addAll(p);
      out.addAll([p.length, code, ...p]);
      if (++made >= want) break;
    }
    return out;
  }

  static List<int> _palin(int n, List<int> sol, SeededRandom r, int s, Set<int> used) {
    // Komşu iki hücreden başlayıp iki yöne eş değerlerle uzat; tek
    // ortalı da olabilir (s ortada).
    var left = [s];
    var right = <int>[];
    List<int> nbs(int c) {
      final x = c % n, y = c ~/ n;
      return [
        for (var dy = -1; dy <= 1; dy++)
          for (var dx = -1; dx <= 1; dx++)
            if ((dx != 0 || dy != 0) && x + dx >= 0 && y + dy >= 0 && x + dx < n && y + dy < n) (y + dy) * n + x + dx
      ];
    }

    for (var step = 0; step < 3; step++) {
      final a = left.last;
      final b = right.isEmpty ? s : right.last;
      final opts = <(int, int)>[];
      for (final p in nbs(a)) {
        for (final q in nbs(b)) {
          if (p == q || used.contains(p) || used.contains(q)) continue;
          if (left.contains(p) || left.contains(q) || right.contains(p) || right.contains(q)) continue;
          if (sol[p] == sol[q]) opts.add((p, q));
        }
      }
      if (opts.isEmpty) break;
      final (p, q) = opts[r.nextInt(opts.length)];
      left = [...left, p];
      right = [...right, q];
    }
    if (right.isEmpty) return const [];
    return [...left.reversed, ...right];
  }

  // ------------------------------------------------------------------ kurallar
  @override
  bool ok(PLevel lv, PState s, bool complete) => _SudokuSolver(lv).consistent(s.cells, complete);

  @override
  int? countSolutions(PLevel lv, {int limit = 2, int budget = 200000}) {
    final sv = _SudokuSolver(lv);
    final start = [for (var i = 0; i < lv.n; i++) lv.givens.isNotEmpty && lv.givens[i] >= 0 ? lv.givens[i] : 0];
    return sv.count(start, limit, budget ~/ 4);
  }

  @override
  CellLook look(PLevel lv, PState s, int i) {
    final v = s.cells[i];
    if (v <= 0) return const CellLook();
    final given = lv.givens.isNotEmpty && lv.givens[i] >= 0;
    // Çakışma: aynı grupta aynı rakam
    var clash = false;
    if (!given) {
      for (final j in _SudokuSolver.peersOf(lv)[i]) {
        if (s.cells[j] == v) {
          clash = true;
          break;
        }
      }
    }
    return CellLook(text: '$v', tone: clash ? 2 : (given ? 1 : 0));
  }

  @override
  (double, double, double, double) margins(PLevel lv) => lv.extra[_xSandwich].isEmpty ? (0, 0, 0, 0) : (0.8, 0.8, 0, 0);

  @override
  String outside(PLevel lv, PState s, int side, int index) {
    final sw = lv.extra[_xSandwich];
    if (sw.isEmpty) return '';
    if (side == 1) return '${sw[index]}';
    if (side == 0) return '${sw[lv.w + index]}';
    return '';
  }

  @override
  void paintUnder(Canvas c, PLevel lv, PState s, Rect Function(int i) cell, double cs) {
    final n = lv.w;
    // Ek gruplar: hafif gölge
    final g = lv.extra[_xGroups];
    var k = 0, gi = 0;
    while (k < g.length) {
      final len = g[k];
      final shade = Paint()..color = (gi.isEven ? const Color(0x22806040) : const Color(0x22406080));
      for (var q = 0; q < len; q++) {
        c.drawRect(cell(g[k + 1 + q]), shade);
      }
      k += len + 1;
      gi++;
    }
    // Çift/tek: daire (tek) ve kare (çift) zemin
    final par = lv.extra[_xParity];
    for (var i = 0; i < par.length; i++) {
      if (par[i] < 0) continue;
      final r = cell(i);
      final p = Paint()..color = const Color(0x33707070);
      if (par[i] == 1) {
        c.drawCircle(r.center, cs * 0.4, p);
      } else {
        c.drawRect(r.deflate(cs * 0.12), p);
      }
    }
    // Termometreler
    final th = lv.extra[_xThermo];
    k = 0;
    while (k < th.length) {
      final len = th[k];
      final cells = th.sublist(k + 1, k + 1 + len);
      final p = Paint()
        ..color = const Color(0x66A0A8B0)
        ..strokeWidth = cs * 0.28
        ..strokeCap = StrokeCap.round;
      for (var q = 0; q + 1 < cells.length; q++) {
        c.drawLine(cell(cells[q]).center, cell(cells[q + 1]).center, p);
      }
      c.drawCircle(cell(cells[0]).center, cs * 0.36, Paint()..color = const Color(0x66A0A8B0));
      k += len + 1;
    }
    // Çizgiler
    final ln = lv.extra[_xLines];
    k = 0;
    while (k < ln.length) {
      final len = ln[k], code = ln[k + 1];
      final cells = ln.sublist(k + 2, k + 2 + len);
      final p = Paint()
        ..color = [const Color(0x55888888), const Color(0x55A066C8), const Color(0x5550A060)][code]
        ..strokeWidth = cs * 0.2
        ..strokeCap = StrokeCap.round;
      for (var q = 0; q + 1 < cells.length; q++) {
        c.drawLine(cell(cells[q]).center, cell(cells[q + 1]).center, p);
      }
      k += len + 2;
    }
    // Oklar
    final ar = lv.extra[_xArrows];
    k = 0;
    while (k < ar.length) {
      final len = ar[k];
      final cells = ar.sublist(k + 1, k + 1 + len);
      final p = Paint()
        ..color = const Color(0x99707A84)
        ..strokeWidth = cs * 0.05
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;
      c.drawCircle(cell(cells[0]).center, cs * 0.4, p);
      for (var q = 0; q + 1 < cells.length; q++) {
        var a = cell(cells[q]).center, b = cell(cells[q + 1]).center;
        if (q == 0) a = Offset.lerp(a, b, 0.4 / ((b - a).distance / cs))!;
        c.drawLine(a, b, p);
      }
      final last = cell(cells.last).center, prev = cell(cells[cells.length - 2]).center;
      final dir = (last - prev) / (last - prev).distance;
      final nrm = Offset(-dir.dy, dir.dx);
      c.drawLine(last, last - dir * cs * 0.22 + nrm * cs * 0.14, p);
      c.drawLine(last, last - dir * cs * 0.22 - nrm * cs * 0.14, p);
      k += len + 1;
    }
    // Kafesler
    final cg = lv.extra[_xCages];
    k = 0;
    final dash = Paint()
      ..color = const Color(0xAA5A5048)
      ..strokeWidth = math.max(1, cs * 0.025);
    while (k < cg.length) {
      final sum = cg[k], len = cg[k + 1];
      final cells = cg.sublist(k + 2, k + 2 + len).toSet();
      final inset = cs * 0.09;
      for (final i in cells) {
        final r = cell(i).deflate(inset);
        final x = i % n, y = i ~/ n;
        if (y == 0 || !cells.contains(i - n)) _dashed(c, r.topLeft, r.topRight, dash);
        if (y == n - 1 || !cells.contains(i + n)) _dashed(c, r.bottomLeft, r.bottomRight, dash);
        if (x == 0 || !cells.contains(i - 1)) _dashed(c, r.topLeft, r.bottomLeft, dash);
        if (x == n - 1 || !cells.contains(i + 1)) _dashed(c, r.topRight, r.bottomRight, dash);
      }
      if (sum > 0) {
        final first = cells.reduce(math.min);
        _small(c, '$sum', cell(first).topLeft + Offset(cs * 0.12, cs * 0.04), cs * 0.24);
      }
      k += len + 2;
    }
    if (lv.extra[_xGroups].isNotEmpty) {
      // köşegenler görünür olsun
    }
  }

  @override
  void paintOver(Canvas c, PLevel lv, PState s, Rect Function(int i) cell, double cs) {
    final pr = lv.extra[_xPairs];
    for (var k = 0; k + 2 < pr.length; k += 3) {
      final a = cell(pr[k]).center, b = cell(pr[k + 1]).center;
      final m = Offset.lerp(a, b, 0.5)!;
      switch (pr[k + 2]) {
        case 0:
          c.drawCircle(m, cs * 0.1, Paint()..color = const Color(0xFFFFFFFF));
          c.drawCircle(
              m,
              cs * 0.1,
              Paint()
                ..style = PaintingStyle.stroke
                ..color = const Color(0xFF333333)
                ..strokeWidth = cs * 0.03);
        case 1:
          c.drawCircle(m, cs * 0.1, Paint()..color = const Color(0xFF333333));
        case 2:
          _badge(c, 'X', m, cs);
        case 3:
          _badge(c, 'V', m, cs);
        default:
          // a > b: işaret büyük taraftan küçüğe açılır
          final dir = (b - a) / (b - a).distance;
          final nrm = Offset(-dir.dy, dir.dx);
          final tip = m + dir * cs * 0.09;
          final p = Paint()
            ..color = const Color(0xFF4A4038)
            ..strokeWidth = cs * 0.05
            ..strokeCap = StrokeCap.round;
          c.drawLine(tip, tip - dir * cs * 0.16 + nrm * cs * 0.12, p);
          c.drawLine(tip, tip - dir * cs * 0.16 - nrm * cs * 0.12, p);
      }
    }
  }

  void _badge(Canvas c, String t, Offset m, double cs) {
    c.drawCircle(m, cs * 0.14, Paint()..color = const Color(0xFFF6EBD9));
    _small(c, t, m - Offset(cs * 0.07, cs * 0.12), cs * 0.22, bold: true);
  }

  void _small(Canvas c, String s, Offset tl, double size, {bool bold = false}) {
    final pb = ParagraphBuilder(ParagraphStyle(fontSize: size, fontWeight: bold ? FontWeight.w800 : FontWeight.w600))
      ..pushStyle(TextStyle(color: const Color(0xFF4A4038), fontSize: size))
      ..addText(s);
    final p = pb.build()..layout(const ParagraphConstraints(width: 200));
    c.drawParagraph(p, tl);
  }

  void _dashed(Canvas c, Offset a, Offset b, Paint p) {
    final len = (b - a).distance;
    const seg = 5.0;
    final dir = (b - a) / len;
    for (var t = 0.0; t < len; t += seg * 2) {
      c.drawLine(a + dir * t, a + dir * math.min(len, t + seg), p);
    }
  }
}

/// Hızlı sudoku çözücüsü: aday maskeleri, en az adaylı hücre önce.
class _SudokuSolver {
  final PLevel lv;
  final int n;
  late final List<List<int>> peers;
  late final List<List<int>> cons; // hücre → kısıt dizinleri
  final kinds = <int>[]; // 0 kafes, 1 termo, 2 ok, 3 çift, 4 sandviç satır/sütun, 5 çizgi
  final data = <List<int>>[];
  late final List<int> flags;

  static final _peerCache = <PLevel, List<List<int>>>{};
  static List<List<int>> peersOf(PLevel lv) => _peerCache.putIfAbsent(lv, () {
        if (_peerCache.length > 8) _peerCache.clear();
        return _SudokuSolver(lv).peers;
      });

  _SudokuSolver(this.lv) : n = lv.w {
    final nn = n * n;
    final ps = [for (var i = 0; i < nn; i++) <int>{}];
    void group(List<int> g) {
      for (final a in g) {
        for (final b in g) {
          if (a != b) ps[a].add(b);
        }
      }
    }

    for (var y = 0; y < n; y++) {
      group([for (var x = 0; x < n; x++) y * n + x]);
    }
    for (var x = 0; x < n; x++) {
      group([for (var y = 0; y < n; y++) y * n + x]);
    }
    for (var reg = 0; reg < n; reg++) {
      group([for (var i = 0; i < nn; i++) if (lv.regions[i] == reg) i]);
    }
    final g = lv.extra[_xGroups];
    var k = 0;
    while (k < g.length) {
      group(g.sublist(k + 1, k + 1 + g[k]));
      k += g[k] + 1;
    }
    flags = lv.extra.length > _xFlags ? lv.extra[_xFlags] : const [0, 0, 0, 0, 0];
    if (flags[0] == 1 || flags[1] == 1) {
      for (var i = 0; i < nn; i++) {
        final x = i % n, y = i ~/ n;
        final moves = <(int, int)>[
          if (flags[0] == 1) ...const [(1, 2), (2, 1), (-1, 2), (-2, 1), (1, -2), (2, -1), (-1, -2), (-2, -1)],
          if (flags[1] == 1) ...const [(1, 1), (-1, 1), (1, -1), (-1, -1)],
        ];
        for (final (dx, dy) in moves) {
          final nx = x + dx, ny = y + dy;
          if (nx >= 0 && ny >= 0 && nx < n && ny < n) ps[i].add(ny * n + nx);
        }
      }
    }
    peers = [for (final p in ps) p.toList()];
    cons = [for (var i = 0; i < nn; i++) <int>[]];
    void add(int kind, List<int> d, Iterable<int> cells) {
      kinds.add(kind);
      data.add(d);
      for (final c in cells) {
        cons[c].add(kinds.length - 1);
      }
    }

    final cg = lv.extra[_xCages];
    k = 0;
    while (k < cg.length) {
      final len = cg[k + 1];
      final cells = cg.sublist(k + 2, k + 2 + len);
      add(0, [cg[k], ...cells], cells);
      // kafes içi farklılık
      for (final a in cells) {
        for (final b in cells) {
          if (a != b && !peers[a].contains(b)) peers[a].add(b);
        }
      }
      k += len + 2;
    }
    final th = lv.extra[_xThermo];
    k = 0;
    while (k < th.length) {
      final cells = th.sublist(k + 1, k + 1 + th[k]);
      add(1, cells, cells);
      k += th[k] + 1;
    }
    final ar = lv.extra[_xArrows];
    k = 0;
    while (k < ar.length) {
      final cells = ar.sublist(k + 1, k + 1 + ar[k]);
      add(2, cells, cells);
      k += ar[k] + 1;
    }
    final pr = lv.extra[_xPairs];
    final marked = <int>{};
    for (var q = 0; q + 2 < pr.length; q += 3) {
      add(3, [pr[q], pr[q + 1], pr[q + 2]], [pr[q], pr[q + 1]]);
      marked.add(pr[q] * nn + pr[q + 1]);
      marked.add(pr[q + 1] * nn + pr[q]);
    }
    // Negatif kurallar ve ardışık yasağı: işaretsiz komşu çiftleri
    if (flags[2] == 1 || flags[3] == 1 || flags[4] == 1) {
      for (var i = 0; i < nn; i++) {
        for (final j in [if (i % n < n - 1) i + 1, if (i ~/ n < n - 1) i + n]) {
          if (marked.contains(i * nn + j)) continue;
          add(3, [i, j, 10 + (flags[2] == 1 ? 1 : 0) + (flags[3] == 1 ? 2 : 0) + (flags[4] == 1 ? 4 : 0)], [i, j]);
        }
      }
    }
    final sw = lv.extra[_xSandwich];
    if (sw.isNotEmpty) {
      for (var line = 0; line < 2 * n; line++) {
        final cells = line < n ? [for (var x = 0; x < n; x++) line * n + x] : [for (var y = 0; y < n; y++) y * n + line - n];
        add(4, [sw[line], ...cells], cells);
      }
    }
    final ln = lv.extra[_xLines];
    k = 0;
    while (k < ln.length) {
      final cells = ln.sublist(k + 2, k + 2 + ln[k]);
      add(5, [ln[k + 1], ...cells], cells);
      if (ln[k + 1] == 1) {
        for (final a in cells) {
          for (final b in cells) {
            if (a != b && !peers[a].contains(b)) peers[a].add(b);
          }
        }
      }
      k += ln[k] + 2;
    }
  }

  bool _check(List<int> v, int ci, bool complete) {
    final d = data[ci];
    switch (kinds[ci]) {
      case 0:
        final sum = d[0];
        var acc = 0, unk = 0;
        for (var q = 1; q < d.length; q++) {
          final x = v[d[q]];
          if (x <= 0) {
            unk++;
          } else {
            acc += x;
          }
        }
        if (sum == 0) return true;
        if (unk == 0) return acc == sum;
        // en küçük/en büyük olası katkılar
        return acc + unk <= sum && acc + unk * n >= sum;
      case 1:
        var last = 0, gap = 0;
        for (var q = 0; q < d.length; q++) {
          final x = v[d[q]];
          if (x <= 0) {
            gap++;
            continue;
          }
          if (x <= last + gap) return false;
          if (x + (d.length - 1 - q) > n) return false;
          last = x;
          gap = 0;
        }
        return true;
      case 2:
        final c0 = v[d[0]];
        var acc = 0, unk = 0;
        for (var q = 1; q < d.length; q++) {
          final x = v[d[q]];
          if (x <= 0) {
            unk++;
          } else {
            acc += x;
          }
        }
        if (c0 <= 0) return acc + unk <= n;
        if (unk == 0) return acc == c0;
        return acc + unk <= c0;
      case 3:
        final a = v[d[0]], b = v[d[1]], t = d[2];
        if (a <= 0 || b <= 0) return true;
        switch (t) {
          case 0:
            return (a - b).abs() == 1;
          case 1:
            return a == 2 * b || b == 2 * a;
          case 2:
            return a + b == 10;
          case 3:
            return a + b == 5;
          case 4:
            return a > b;
          default:
            final f = t - 10;
            if (f & 1 == 1 && (a - b).abs() == 1) return false;
            if (f & 2 == 2 && ((a - b).abs() == 1 || a == 2 * b || b == 2 * a)) return false;
            if (f & 4 == 4 && (a + b == 10 || a + b == 5)) return false;
            return true;
        }
      case 4:
        final target = d[0];
        var p1 = -1, pn = -1;
        for (var q = 1; q < d.length; q++) {
          final x = v[d[q]];
          if (x == 1) p1 = q;
          if (x == n) pn = q;
        }
        if (p1 < 0 || pn < 0) return true;
        final lo = math.min(p1, pn), hi = math.max(p1, pn);
        var acc = 0;
        for (var q = lo + 1; q < hi; q++) {
          final x = v[d[q]];
          if (x <= 0) return true;
          acc += x;
        }
        return acc == target;
      default:
        final code = d[0];
        final cells = d.sublist(1);
        final vals = [for (final c in cells) v[c]];
        if (code == 0) {
          for (var q = 0; q < vals.length ~/ 2; q++) {
            final a = vals[q], b = vals[vals.length - 1 - q];
            if (a > 0 && b > 0 && a != b) return false;
          }
          return true;
        }
        if (code == 1) {
          final known = [for (final x in vals) if (x > 0) x];
          if (known.isEmpty) return true;
          final mx = known.reduce(math.max), mn = known.reduce(math.min);
          return mx - mn <= vals.length - 1;
        }
        final gap = n == 9 ? 5 : n ~/ 2;
        for (var q = 0; q + 1 < vals.length; q++) {
          if (vals[q] > 0 && vals[q + 1] > 0 && (vals[q] - vals[q + 1]).abs() < gap) return false;
        }
        return true;
    }
  }

  bool consistent(List<int> v, bool complete) {
    final nn = n * n;
    for (var i = 0; i < nn; i++) {
      final x = v[i];
      if (x <= 0) {
        if (complete) return false;
        continue;
      }
      if (x > n) return false;
      for (final j in peers[i]) {
        if (j > i && v[j] == x) return false;
      }
    }
    for (var ci = 0; ci < kinds.length; ci++) {
      if (!_check(v, ci, complete)) return false;
    }
    return true;
  }

  bool _okAt(List<int> v, int i) {
    for (final ci in cons[i]) {
      if (!_check(v, ci, false)) return false;
    }
    return true;
  }

  int _mask(List<int> v, int i) {
    var m = ((1 << n) - 1) << 1;
    for (final j in peers[i]) {
      final x = v[j];
      if (x > 0) m &= ~(1 << x);
    }
    return m;
  }

  int? count(List<int> start, int limit, int budget) {
    final v = List.of(start);
    for (var i = 0; i < v.length; i++) {
      if (v[i] > 0 && !_okAt(v, i)) return 0;
    }
    if (!consistent(v, false)) return 0;
    var found = 0, nodes = 0;
    var over = false;
    void go() {
      if (found >= limit || over) return;
      // en az adaylı hücre
      var best = -1, bestCount = 99, bestMask = 0;
      for (var i = 0; i < v.length; i++) {
        if (v[i] > 0) continue;
        final m = _mask(v, i);
        final c = _bits(m);
        if (c < bestCount) {
          best = i;
          bestCount = c;
          bestMask = m;
          if (c <= 1) break;
        }
      }
      if (best < 0) {
        if (consistent(v, true)) found++;
        return;
      }
      if (bestCount == 0) return;
      for (var x = 1; x <= n; x++) {
        if (bestMask & (1 << x) == 0) continue;
        if (++nodes > budget) {
          over = true;
          return;
        }
        v[best] = x;
        if (_okAt(v, best)) go();
        v[best] = 0;
        if (found >= limit || over) return;
      }
    }

    go();
    return over ? null : found;
  }

  /// Rastgele sırayla tam bir çözüm bul.
  List<int>? randomFill(SeededRandom r, int budget) {
    final v = List.filled(n * n, 0);
    var nodes = 0;
    bool go() {
      var best = -1, bestCount = 99, bestMask = 0;
      for (var i = 0; i < v.length; i++) {
        if (v[i] > 0) continue;
        final m = _mask(v, i);
        final c = _bits(m);
        if (c < bestCount) {
          best = i;
          bestCount = c;
          bestMask = m;
          if (c <= 1) break;
        }
      }
      if (best < 0) return true;
      final order = shuffled(n, r);
      for (final o in order) {
        final x = o + 1;
        if (bestMask & (1 << x) == 0) continue;
        if (++nodes > budget) return false;
        v[best] = x;
        if (_okAt(v, best) && go()) return true;
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
}
