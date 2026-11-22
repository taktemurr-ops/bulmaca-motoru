import 'dart:math' as math;
import 'dart:ui';

import 'package:studio_core/core/rng.dart';

import 'core.dart';

/// Basit bağlı bölge (delik ve köşe teması olmadan) büyütür; sınırı tek
/// bir kapalı çizgidir. W×H yüz ızgarasında.
List<bool> randomSimpleRegion(int W, int H, double fill, SeededRandom r) {
  final inR = List.filled(W * H, false);
  bool connected(bool Function(int) member, {bool outside = false}) {
    // outside: ızgara dışı da üye ve bağlantı noktası
    final seen = List.filled(W * H, false);
    final q = <int>[];
    if (outside) {
      for (var i = 0; i < W * H; i++) {
        final x = i % W, y = i ~/ W;
        if ((x == 0 || y == 0 || x == W - 1 || y == H - 1) && member(i)) {
          seen[i] = true;
          q.add(i);
        }
      }
    } else {
      final s = [for (var i = 0; i < W * H; i++) if (member(i)) i];
      if (s.isEmpty) return true;
      seen[s.first] = true;
      q.add(s.first);
    }
    for (var k = 0; k < q.length; k++) {
      final c = q[k];
      final x = c % W, y = c ~/ W;
      for (final nb in [if (x > 0) c - 1, if (x < W - 1) c + 1, if (y > 0) c - W, if (y < H - 1) c + W]) {
        if (!seen[nb] && member(nb)) {
          seen[nb] = true;
          q.add(nb);
        }
      }
    }
    for (var i = 0; i < W * H; i++) {
      if (member(i) && !seen[i]) return false;
    }
    return true;
  }

  bool pinch() {
    for (var y = 0; y + 1 < H; y++) {
      for (var x = 0; x + 1 < W; x++) {
        final a = inR[y * W + x], b = inR[y * W + x + 1], c = inR[(y + 1) * W + x], d = inR[(y + 1) * W + x + 1];
        if (a == d && b == c && a != b) return true;
      }
    }
    return false;
  }

  final start = r.nextInt(W * H);
  inR[start] = true;
  final target = math.max(2, (W * H * fill).round());
  var count = 1;
  for (var t = 0; t < W * H * 40 && count < target; t++) {
    final c = r.nextInt(W * H);
    if (inR[c]) continue;
    final x = c % W, y = c ~/ W;
    if (![if (x > 0) c - 1, if (x < W - 1) c + 1, if (y > 0) c - W, if (y < H - 1) c + W].any((nb) => inR[nb])) continue;
    inR[c] = true;
    if (pinch() || !connected((i) => !inR[i], outside: true)) {
      inR[c] = false;
      continue;
    }
    count++;
  }
  return inR;
}

// ---- bağ yardımcıları
/// [i] hücresinin yöndeki bağ değeri (0 yukarı, 1 sağ, 2 aşağı, 3 sol); dışarıda 0.
int linkDir(PLevel lv, List<int> links, int i, int dir) {
  final l = linkIndex(lv, i, dir);
  return l < 0 ? 0 : links[l];
}

int linkIndex(PLevel lv, int i, int dir) {
  final x = i % lv.w, y = i ~/ lv.w;
  switch (dir) {
    case 0:
      return y > 0 ? lv.downLink(x, y - 1) : -1;
    case 1:
      return x < lv.w - 1 ? lv.rightLink(x, y) : -1;
    case 2:
      return y < lv.h - 1 ? lv.downLink(x, y) : -1;
    default:
      return x > 0 ? lv.rightLink(x - 1, y) : -1;
  }
}

int neighborDir(PLevel lv, int i, int dir) => switch (dir) { 0 => i - lv.w, 1 => i + 1, 2 => i + lv.w, _ => i - 1 };

/// Hücrenin (bilinen bağlara göre) derecesi ve bilinmeyen sayısı.
(int, int) degree(PLevel lv, List<int> links, int i) {
  var d = 0, u = 0;
  for (var dir = 0; dir < 4; dir++) {
    final l = linkIndex(lv, i, dir);
    if (l < 0) continue;
    final v = links[l];
    if (v > 0) d++;
    if (v < 0) u++;
  }
  return (d, u);
}

/// Bağlı bileşenler (bağ > 0): her hücre için bileşen kimliği.
List<int> linkComponents(PLevel lv, List<int> links) {
  final comp = List.filled(lv.n, -1);
  var id = 0;
  for (var i = 0; i < lv.n; i++) {
    if (comp[i] >= 0) continue;
    comp[i] = id;
    final q = [i];
    for (var k = 0; k < q.length; k++) {
      final c = q[k];
      for (var dir = 0; dir < 4; dir++) {
        final l = linkIndex(lv, c, dir);
        if (l < 0 || links[l] <= 0) continue;
        final nb = neighborDir(lv, c, dir);
        if (comp[nb] < 0) {
          comp[nb] = id;
          q.add(nb);
        }
      }
    }
    id++;
  }
  return comp;
}

/// Kapalı döngü denetimi: bir bileşen döngü olarak kapandıysa (her hücre
/// derece 2 ve bilinmeyen bağı yoksa) dışında bağ kalmamalı.
/// [mustVisit] doğruysa o hücre döngüde olmalı.
bool loopClosureOk(PLevel lv, List<int> links, bool Function(int i) mustVisit) {
  final comp = linkComponents(lv, links);
  final size = <int, int>{};
  final closed = <int, bool>{};
  for (var i = 0; i < lv.n; i++) {
    final (d, u) = degree(lv, links, i);
    if (d == 0) continue;
    size[comp[i]] = (size[comp[i]] ?? 0) + 1;
    final c = closed[comp[i]] ?? true;
    closed[comp[i]] = c && d == 2 && u == 0;
  }
  final loops = [for (final e in closed.entries) if (e.value) e.key];
  if (loops.isEmpty) return true;
  if (loops.length > 1 || size.length > 1) return false;
  final lp = loops.first;
  for (var i = 0; i < lv.n; i++) {
    if (comp[i] != lp && mustVisit(i)) return false;
  }
  return true;
}

/// Bağların tek döngü oluşturduğu tam denetim.
bool singleLoop(PLevel lv, List<int> links, bool Function(int i) mustVisit, {bool Function(int i)? mustNot}) {
  var start = -1;
  for (var i = 0; i < lv.n; i++) {
    final (d, _) = degree(lv, links, i);
    if (d != 0 && d != 2) return false;
    if (d == 0 && mustVisit(i)) return false;
    if (d > 0 && mustNot != null && mustNot(i)) return false;
    if (d == 2 && start < 0) start = i;
  }
  if (start < 0) return false;
  final comp = linkComponents(lv, links);
  for (var i = 0; i < lv.n; i++) {
    final (d, _) = degree(lv, links, i);
    if (d > 0 && comp[i] != comp[start]) return false;
  }
  return true;
}

/// Bağ katmanı için hücre sırasına göre çözücü değişkenleri.
List<(int, int)> linkOrder(PLevel lv, {bool withCells = false}) {
  final out = <(int, int)>[];
  for (var i = 0; i < lv.n; i++) {
    final x = i % lv.w, y = i ~/ lv.w;
    if (withCells) out.add((0, i));
    if (x < lv.w - 1) out.add((1, lv.rightLink(x, y)));
    if (y < lv.h - 1) out.add((1, lv.downLink(x, y)));
  }
  return out;
}

/// Kenar katmanı için hücre sırasına göre değişkenler.
List<(int, int)> borderOrder(PLevel lv) {
  final out = <(int, int)>[];
  final seen = <int>{};
  for (var i = 0; i < lv.n; i++) {
    for (final e in lv.cellEdges(i)) {
      if (seen.add(e)) out.add((2, e));
    }
  }
  return out;
}

// ======================================================================
// Slitherlink (çevre)

/// Kenarlardan tek kapalı çizgi; sayılar hücrenin kaç kenarının çizgi
/// olduğunu söyler.
class LoopEdgeKind extends PuzzleKind {
  const LoopEdgeKind();
  @override
  String get id => 'slitherlink';

  @override
  CellInput get cellInput => CellInput.none;

  @override
  bool get usesBorders => true;

  @override
  List<(int, int)>? solveOrder(PLevel lv) => borderOrder(lv);

  @override
  bool tapCell(PLevel lv, int i) => false;

  @override
  CellLook look(PLevel lv, PState s, int i) {
    final c = lv.clues[i];
    if (c < 0) return const CellLook();
    var on = 0;
    for (final e in lv.cellEdges(i)) {
      if (s.borders[e] == 1) on++;
    }
    return CellLook(text: '$c', tone: on > c ? 2 : 1);
  }

  @override
  bool get gridLines => false;

  @override
  bool ok(PLevel lv, PState s, bool complete) {
    final b = s.borders;
    // köşe dereceleri
    final vw = lv.w + 1;
    final deg = List.filled(vw * (lv.h + 1), 0), unk = List.filled(vw * (lv.h + 1), 0);
    for (var e = 0; e < lv.borderCount; e++) {
      final (a, c) = lv.edgeVertices(e);
      if (b[e] == 1) {
        deg[a]++;
        deg[c]++;
      } else if (b[e] < 0) {
        unk[a]++;
        unk[c]++;
      }
    }
    for (var v = 0; v < deg.length; v++) {
      if (deg[v] > 2) return false;
      if (unk[v] == 0 && deg[v] == 1) return false;
      if (deg[v] == 1 && unk[v] == 0) return false;
    }
    for (var i = 0; i < lv.n; i++) {
      final c = lv.clues[i];
      if (c < 0) continue;
      var on = 0, u = 0;
      for (final e in lv.cellEdges(i)) {
        if (b[e] == 1) on++;
        if (b[e] < 0) u++;
      }
      if (on > c || on + u < c) return false;
    }
    // döngü: köşe grafiğinde
    final parent = List.generate(deg.length, (i) => i);
    int find(int x) {
      while (parent[x] != x) {
        parent[x] = parent[parent[x]];
        x = parent[x];
      }
      return x;
    }

    var loops = 0;
    for (var e = 0; e < lv.borderCount; e++) {
      if (b[e] != 1) continue;
      final (a, c) = lv.edgeVertices(e);
      final ra = find(a), rc = find(c);
      if (ra == rc) {
        loops++;
      } else {
        parent[ra] = rc;
      }
    }
    if (loops > 1) return false;
    if (loops == 1) {
      // kapalı döngü dışında çizgi olmamalı
      var root = -1;
      for (var e = 0; e < lv.borderCount; e++) {
        if (b[e] != 1) continue;
        final (a, _) = lv.edgeVertices(e);
        final ra = find(a);
        if (root < 0) {
          root = ra;
        } else if (ra != root) {
          return false;
        }
      }
      // döngü kapandıysa sayılar tamamlanmış olmalı
      for (var i = 0; i < lv.n; i++) {
        final c = lv.clues[i];
        if (c < 0) continue;
        var on = 0;
        for (final e in lv.cellEdges(i)) {
          if (b[e] == 1) on++;
        }
        if (on != c) return false;
      }
    }
    if (complete && loops != 1) return false;
    return true;
  }

  @override
  PLevel make(int difficulty, SeededRandom r) {
    final (w, h) = const [(4, 4), (5, 5), (5, 5), (6, 6), (6, 6), (7, 7), (7, 7), (8, 8), (9, 9), (10, 10)][difficulty - 1];
    final reg = randomSimpleRegion(w, h, 0.5, r);
    final probe = PLevel(kind: id, w: w, h: h, clues: List.filled(w * h, -1), givens: const []);
    final borders = List.filled(probe.borderCount, 0);
    for (var e = 0; e < probe.borderCount; e++) {
      final (a, c) = probe.edgeCells(e);
      final ia = a >= 0 && reg[a], ic = c >= 0 && reg[c];
      if (ia != ic) borders[e] = 1;
    }
    final clues = List.filled(w * h, -1);
    final p = difficulty <= 3 ? 0.75 : (difficulty <= 6 ? 0.6 : 0.5);
    for (var i = 0; i < w * h; i++) {
      if (r.chance(p)) clues[i] = probe.cellEdges(i).where((e) => borders[e] == 1).length;
    }
    return PLevel(kind: id, w: w, h: h, clues: clues, solBorders: borders, givens: List.filled(w * h, -1), givenBorders: List.filled(probe.borderCount, -1));
  }

  @override
  double maxGivenRatio(int difficulty) => 0.25;
}

// ======================================================================
// İnci (Masyu)

/// Hücre merkezlerinden geçen tek kapalı döngü; bütün incilerden geçer.
/// Beyaz incide düz geçer ve bir yanında döner; siyah incide döner ve
/// iki yönde birer hücre düz gider. clues: 1 beyaz, 2 siyah.
class PearlKind extends PuzzleKind {
  const PearlKind();
  @override
  String get id => 'inci';

  @override
  CellInput get cellInput => CellInput.none;

  @override
  bool get usesLinks => true;

  @override
  bool tapCell(PLevel lv, int i) => false;

  @override
  List<(int, int)>? solveOrder(PLevel lv) => linkOrder(lv);

  @override
  CellLook look(PLevel lv, PState s, int i) => switch (lv.clues[i]) { 1 => const CellLook(mark: Mark.ring), 2 => const CellLook(mark: Mark.disc), _ => const CellLook() };

  static bool pearlOk(PLevel lv, List<int> links, int i, int kind) {
    int ld(int c, int dir) => (c < 0 || c >= lv.n) ? 0 : linkDir(lv, links, c, dir);
    final u = ld(i, 0), rr = ld(i, 1), d = ld(i, 2), l = ld(i, 3);
    if (kind == 1) {
      if ((l == 1 || rr == 1) && (u == 1 || d == 1)) return false;
      if ((l == 1 && rr == 0) || (rr == 1 && l == 0) || (u == 1 && d == 0) || (d == 1 && u == 0)) return false;
      if (l == 0 && rr == 0 && u == 0 && d == 0) return false;
      if (l == 1 && rr == 1) {
        // iki uçtan en az biri dönmeli
        final a = i - 1, b = i + 1;
        final aStraight = ld(a, 3) == 1, bStraight = ld(b, 1) == 1;
        final aKnown = ld(a, 3) >= 0 && ld(a, 0) >= 0 && ld(a, 2) >= 0;
        final bKnown = ld(b, 1) >= 0 && ld(b, 0) >= 0 && ld(b, 2) >= 0;
        if (aKnown && bKnown && aStraight && bStraight) return false;
      }
      if (u == 1 && d == 1) {
        final a = i - lv.w, b = i + lv.w;
        final aStraight = ld(a, 0) == 1, bStraight = ld(b, 2) == 1;
        final aKnown = ld(a, 0) >= 0 && ld(a, 1) >= 0 && ld(a, 3) >= 0;
        final bKnown = ld(b, 2) >= 0 && ld(b, 1) >= 0 && ld(b, 3) >= 0;
        if (aKnown && bKnown && aStraight && bStraight) return false;
      }
      return true;
    }
    // siyah
    if ((l == 1 && rr == 1) || (u == 1 && d == 1)) return false;
    if (l == 0 && rr == 0) return false;
    if (u == 0 && d == 0) return false;
    for (final (dir, val) in [(0, u), (1, rr), (2, d), (3, l)]) {
      if (val != 1) continue;
      final nb = neighborDir(lv, i, dir);
      final cont = ld(nb, dir);
      if (cont == 0) return false;
      // komşu düz gitmeli: dik bağları 0
      final p1 = ld(nb, (dir + 1) % 4), p2 = ld(nb, (dir + 3) % 4);
      if (p1 == 1 || p2 == 1) return false;
    }
    return true;
  }

  @override
  bool ok(PLevel lv, PState s, bool complete) {
    final links = s.links;
    for (var i = 0; i < lv.n; i++) {
      final (d, u) = degree(lv, links, i);
      if (d > 2 || (u == 0 && d == 1)) return false;
      if (lv.clues[i] > 0) {
        if (u == 0 && d != 2) return false;
        if (!pearlOk(lv, links, i, lv.clues[i])) return false;
      }
    }
    if (!loopClosureOk(lv, links, (i) => lv.clues[i] > 0)) return false;
    if (complete) return singleLoop(lv, links, (i) => lv.clues[i] > 0);
    return true;
  }

  @override
  PLevel make(int difficulty, SeededRandom r) {
    final n = const [5, 6, 6, 7, 7, 8, 8, 9, 10, 10][difficulty - 1];
    for (var attempt = 0; attempt < 100; attempt++) {
      final reg = randomSimpleRegion(n - 1, n - 1, 0.45, r);
      final probe = PLevel(kind: id, w: n, h: n, clues: List.filled(n * n, -1), givens: const []);
      final links = _faceBoundaryLinks(probe, reg);
      final clues = List.filled(n * n, -1);
      for (var i = 0; i < n * n; i++) {
        final (d, _) = degree(probe, links, i);
        if (d != 2) continue;
        for (final k in [2, 1]) {
          if (pearlOk(probe, links, i, k) && r.chance(difficulty <= 3 ? 0.65 : 0.5)) {
            clues[i] = k;
            break;
          }
        }
      }
      if (clues.where((c) => c > 0).length < n) continue;
      return PLevel(kind: id, w: n, h: n, clues: clues, solLinks: links, givens: List.filled(n * n, -1), givenLinks: List.filled(probe.linkCount, -1));
    }
    throw StateError('masyu');
  }

  @override
  double maxGivenRatio(int difficulty) => 0.2;
}

/// (w-1)×(h-1) yüz bölgesinin sınırını hücre merkezleri arası bağlara çevirir.
List<int> _faceBoundaryLinks(PLevel lv, List<bool> reg) {
  final fw = lv.w - 1, fh = lv.h - 1;
  final links = List.filled(lv.linkCount, 0);
  bool inF(int fx, int fy) => fx >= 0 && fy >= 0 && fx < fw && fy < fh && reg[fy * fw + fx];
  for (var fy = 0; fy < fh; fy++) {
    for (var fx = 0; fx < fw; fx++) {
      if (!inF(fx, fy)) continue;
      if (!inF(fx - 1, fy)) links[lv.downLink(fx, fy)] = 1;
      if (!inF(fx + 1, fy)) links[lv.downLink(fx + 1, fy)] = 1;
      if (!inF(fx, fy - 1)) links[lv.rightLink(fx, fy)] = 1;
      if (!inF(fx, fy + 1)) links[lv.rightLink(fx, fy + 1)] = 1;
    }
  }
  return links;
}

/// Dışa açık: yüz bölgesi sınırı.
List<int> faceBoundaryLinks(PLevel lv, List<bool> reg) => _faceBoundaryLinks(lv, reg);

// ======================================================================
// Yajilin

/// Bazı hücreleri karala (karalar yan yana değmez); ipucu olmayan diğer
/// bütün hücrelerden tek döngü geçer. Oklu sayı, o yöndeki kara sayısıdır.
/// clues: -1 boş, 0..: ipucu (extra[0]: yön).
class ArrowLoopKind extends PuzzleKind {
  const ArrowLoopKind();
  @override
  String get id => 'yajilin';

  @override
  int cellStates(PLevel lv) => 3;

  @override
  int get markState => 2;

  @override
  bool get usesLinks => true;

  @override
  bool get dragLinks => true;

  @override
  List<int> cellDomain(PLevel lv, int i) => lv.clues[i] >= 0 ? const [0] : const [0, 1];

  @override
  bool tapCell(PLevel lv, int i) => lv.clues[i] < 0 && (lv.givens.isEmpty || lv.givens[i] < 0);

  @override
  bool canGive(PLevel lv, int i) => lv.clues[i] < 0;

  @override
  List<(int, int)>? solveOrder(PLevel lv) => linkOrder(lv, withCells: true);

  @override
  CellLook look(PLevel lv, PState s, int i) {
    if (lv.clues[i] >= 0) return CellLook(text: '${lv.clues[i]}', tone: 1, mark: Mark.none);
    final v = s.cells[i];
    return CellLook(mark: v == 1 ? Mark.fill : (v == 2 ? Mark.dot : Mark.none), tone: lv.givens.isNotEmpty && lv.givens[i] >= 0 ? 1 : 0);
  }

  @override
  void paintUnder(Canvas c, PLevel lv, PState s, Rect Function(int i) cell, double cs) {
    for (var i = 0; i < lv.n; i++) {
      if (lv.clues[i] < 0) continue;
      final r = cell(i);
      c.drawRect(r, Paint()..color = const Color(0x22806040));
      final dir = lv.extra[0][i];
      final o = r.center + Offset(const [0.0, 0.32, 0.0, -0.32][dir] * cs, const [-0.32, 0.0, 0.32, 0.0][dir] * cs);
      final u = Offset(const [0.0, 1.0, 0.0, -1.0][dir], const [-1.0, 0.0, 1.0, 0.0][dir]);
      final nrm = Offset(-u.dy, u.dx);
      final p = Paint()
        ..color = const Color(0xFF5A4A3F)
        ..strokeWidth = cs * 0.05
        ..strokeCap = StrokeCap.round;
      c.drawLine(o - u * cs * 0.08, o + u * cs * 0.1, p);
      c.drawLine(o + u * cs * 0.1, o + nrm * cs * 0.07, p);
      c.drawLine(o + u * cs * 0.1, o - nrm * cs * 0.07, p);
    }
  }

  @override
  bool ok(PLevel lv, PState s, bool complete) {
    final v = s.cells, links = s.links;
    for (var i = 0; i < lv.n; i++) {
      if (v[i] == 1) {
        if (i % lv.w < lv.w - 1 && v[i + 1] == 1) return false;
        if (i ~/ lv.w < lv.h - 1 && v[i + lv.w] == 1) return false;
      }
      final (d, u) = degree(lv, links, i);
      if (d > 2) return false;
      final block = lv.clues[i] >= 0 || v[i] == 1;
      if (block && d > 0) return false;
      if (v[i] == 0 && lv.clues[i] < 0) {
        if (u == 0 && d != 2) return false;
      }
      if (d == 1 && u == 0) return false;
    }
    for (var i = 0; i < lv.n; i++) {
      if (lv.clues[i] < 0) continue;
      final dir = lv.extra[0][i];
      var on = 0, unk = 0;
      var c = i;
      while (true) {
        final x = c % lv.w, y = c ~/ lv.w;
        if ((dir == 0 && y == 0) || (dir == 2 && y == lv.h - 1) || (dir == 1 && x == lv.w - 1) || (dir == 3 && x == 0)) break;
        c = neighborDir(lv, c, dir);
        if (lv.clues[c] >= 0) continue;
        if (v[c] == 1) on++;
        if (v[c] < 0) unk++;
      }
      if (on > lv.clues[i] || on + unk < lv.clues[i]) return false;
    }
    if (!loopClosureOk(lv, links, (i) => v[i] == 0 && lv.clues[i] < 0)) return false;
    if (complete) return singleLoop(lv, links, (i) => v[i] == 0 && lv.clues[i] < 0);
    return true;
  }

  @override
  bool solved(PLevel lv, PState player) {
    final s = normalized(lv, player);
    return ok(lv, s, true);
  }

  @override
  PLevel make(int difficulty, SeededRandom r) {
    final n = const [5, 6, 6, 7, 7, 8, 8, 9, 9, 10][difficulty - 1];
    for (var attempt = 0; attempt < 200; attempt++) {
      final reg = randomSimpleRegion(n - 1, n - 1, 0.55, r);
      final probe = PLevel(kind: id, w: n, h: n, clues: List.filled(n * n, -1), givens: const []);
      final links = _faceBoundaryLinks(probe, reg);
      final v = List.filled(n * n, 0);
      final clues = List.filled(n * n, -1);
      final off = [for (var i = 0; i < n * n; i++) if (degree(probe, links, i).$1 == 0) i];
      r.shuffle(off);
      for (final i in off) {
        if (probe.neighbors(i).any((nb) => v[nb] == 1)) continue;
        v[i] = 1;
      }
      final dirs = List.filled(n * n, 0);
      for (final i in off) {
        if (v[i] == 1) continue;
        // ipucu hücresi: rastgele yön ve sayı
        final dir = r.nextInt(4);
        var cnt = 0;
        var c = i;
        while (true) {
          final x = c % n, y = c ~/ n;
          if ((dir == 0 && y == 0) || (dir == 2 && y == n - 1) || (dir == 1 && x == n - 1) || (dir == 3 && x == 0)) break;
          c = neighborDir(probe, c, dir);
          if (v[c] == 1) cnt++;
        }
        clues[i] = cnt;
        dirs[i] = dir;
      }
      // ek ipuçları: bazı karaların yerine değil, döngü dışı yoksa yine de
      if (clues.where((c) => c >= 0).isEmpty) {
        // en az bir ipucu: karalardan birini ipucuna çevir olmaz; köşe karayı yönle say
        final i = off.isNotEmpty ? off.first : -1;
        if (i < 0) continue;
        v[i] = 0;
        clues[i] = 0;
        dirs[i] = 0;
        var cnt = 0;
        var c = i;
        while (c ~/ n > 0) {
          c -= n;
          if (v[c] == 1) cnt++;
        }
        clues[i] = cnt;
      }
      return PLevel(kind: id, w: n, h: n, clues: clues, extra: [dirs], solCells: v, solLinks: links, givens: List.filled(n * n, -1));
    }
    throw StateError('yajilin');
  }

  @override
  double maxGivenRatio(int difficulty) => 0.4;
}

// ======================================================================
// Raylar

/// Soldaki giriş ile alttaki çıkış arasında tek ray hattı; satır/sütundaki
/// sayılar raylı hücre sayısıdır. extra[0] satır, extra[1] sütun,
/// extra[2] [giriş, çıkış].
class TrackKind extends PuzzleKind {
  const TrackKind();
  @override
  String get id => 'raylar';

  @override
  CellInput get cellInput => CellInput.none;

  @override
  bool get usesLinks => true;

  @override
  bool tapCell(PLevel lv, int i) => false;

  @override
  List<(int, int)>? solveOrder(PLevel lv) => linkOrder(lv);

  @override
  CellLook look(PLevel lv, PState s, int i) => const CellLook();

  bool _end(PLevel lv, int i) => lv.extra[2][0] == i || lv.extra[2][1] == i;

  @override
  bool ok(PLevel lv, PState s, bool complete) {
    final links = s.links;
    final used = List.filled(lv.n, 0); // 1 evet, 0 hayır, -1 belirsiz
    for (var i = 0; i < lv.n; i++) {
      var (d, u) = degree(lv, links, i);
      if (_end(lv, i)) d++;
      if (d > 2) return false;
      if (d == 1 && u == 0) return false;
      if (_end(lv, i) && d == 1 && u == 0) return false;
      used[i] = d > 0 ? 1 : (u > 0 ? -1 : 0);
    }
    for (var y = 0; y < lv.h; y++) {
      var on = 0, unk = 0;
      for (var x = 0; x < lv.w; x++) {
        final q = used[y * lv.w + x];
        if (q == 1) on++;
        if (q < 0) unk++;
      }
      if (on > lv.extra[0][y] || on + unk < lv.extra[0][y]) return false;
    }
    for (var x = 0; x < lv.w; x++) {
      var on = 0, unk = 0;
      for (var y = 0; y < lv.h; y++) {
        final q = used[y * lv.w + x];
        if (q == 1) on++;
        if (q < 0) unk++;
      }
      if (on > lv.extra[1][x] || on + unk < lv.extra[1][x]) return false;
    }
    // döngü olmamalı
    final parent = List.generate(lv.n, (i) => i);
    int find(int x) {
      while (parent[x] != x) {
        parent[x] = parent[parent[x]];
        x = parent[x];
      }
      return x;
    }

    for (var l = 0; l < lv.linkCount; l++) {
      if (links[l] != 1) continue;
      final (a, b) = lv.linkCells(l);
      final ra = find(a), rb = find(b);
      if (ra == rb) return false;
      parent[ra] = rb;
    }
    if (complete) {
      final a = lv.extra[2][0], b = lv.extra[2][1];
      if (find(a) != find(b)) return false;
      for (var i = 0; i < lv.n; i++) {
        if (used[i] == 1 && find(i) != find(a)) return false;
      }
    }
    return true;
  }

  @override
  PLevel make(int difficulty, SeededRandom r) {
    final n = const [5, 6, 6, 7, 7, 8, 8, 9, 10, 10][difficulty - 1];
    for (var attempt = 0; attempt < 400; attempt++) {
      final probe = PLevel(kind: id, w: n, h: n, clues: const [], givens: const []);
      final start = r.nextInt(n) * n; // sol kenar
      final path = [start];
      final used = {start};
      var cur = start;
      var guard = 0;
      while (guard++ < n * n * 4) {
        if (cur ~/ n == n - 1 && path.length > n) break;
        final opts = probe.neighbors(cur).where((nb) => !used.contains(nb) && probe.neighbors(nb).where(used.contains).length <= 1).toList();
        if (opts.isEmpty) break;
        // aşağı ve sağa hafif eğilim
        opts.sort((a, b) => (b ~/ n + b % n).compareTo(a ~/ n + a % n));
        final pick = r.chance(0.45) ? opts.first : opts[r.nextInt(opts.length)];
        path.add(pick);
        used.add(pick);
        cur = pick;
      }
      if (cur ~/ n != n - 1 || path.length < n + 2) continue;
      final links = List.filled(probe.linkCount, 0);
      for (var k = 0; k + 1 < path.length; k++) {
        links[probe.linkBetween(path[k], path[k + 1])] = 1;
      }
      final rows = [for (var y = 0; y < n; y++) path.where((c) => c ~/ n == y).length];
      final cols = [for (var x = 0; x < n; x++) path.where((c) => c % n == x).length];
      final lv = PLevel(kind: id, w: n, h: n, clues: const [], extra: [rows, cols, [start, path.last]], solLinks: links, givens: List.filled(n * n, -1), givenLinks: List.filled(probe.linkCount, -1));
      if (!ok(lv, PState(List.filled(n * n, 0), links, List.filled(probe.borderCount, 0)), true)) continue;
      return lv;
    }
    throw StateError('tracks');
  }

  @override
  (double, double, double, double) margins(PLevel lv) => (0, 0, 0.8, 0.8);

  @override
  String outside(PLevel lv, PState s, int side, int index) => side == 2 ? '${lv.extra[1][index]}' : (side == 3 ? '${lv.extra[0][index]}' : '');

  @override
  void paintOver(Canvas c, PLevel lv, PState s, Rect Function(int i) cell, double cs) {
    final a = cell(lv.extra[2][0]), b = cell(lv.extra[2][1]);
    final p = Paint()
      ..color = const Color(0xFF8A5A34)
      ..strokeWidth = cs * 0.16
      ..strokeCap = StrokeCap.round;
    c.drawLine(a.centerLeft - Offset(cs * 0.3, 0), a.center, p);
    c.drawLine(b.bottomCenter + Offset(0, cs * 0.3), b.center, p);
  }

  @override
  double maxGivenRatio(int difficulty) => 0.4;
}

// ======================================================================
// Köprüler (Hashi)

/// Adaları yatay/dikey köprülerle (bir ya da iki) bağla; adadaki sayı
/// köprü sayısıdır; köprüler kesişmez; bütün adalar birbirine bağlı.
/// clues: ada sayısı (-1 su).
class BridgeKind extends PuzzleKind {
  const BridgeKind();
  @override
  String get id => 'kopruler';

  @override
  CellInput get cellInput => CellInput.none;

  @override
  bool get usesLinks => true;

  @override
  int get linkStates => 3;

  @override
  bool get nodeStyle => true;

  @override
  bool get gridLines => false;

  @override
  bool tapCell(PLevel lv, int i) => false;

  @override
  List<(int, int)>? solveOrder(PLevel lv) => linkOrder(lv);

  @override
  CellLook look(PLevel lv, PState s, int i) {
    final c = lv.clues[i];
    if (c < 0) return const CellLook();
    var sum = 0;
    for (var dir = 0; dir < 4; dir++) {
      sum += math.max(0, linkDir(lv, s.links, i, dir));
    }
    return CellLook(mark: Mark.ring, text: '$c', tone: sum > c ? 2 : (sum == c ? 0 : 1));
  }

  @override
  bool ok(PLevel lv, PState s, bool complete) {
    final links = s.links;
    for (var i = 0; i < lv.n; i++) {
      final u = linkDir(lv, links, i, 0), rr = linkDir(lv, links, i, 1), d = linkDir(lv, links, i, 2), l = linkDir(lv, links, i, 3);
      if (lv.clues[i] >= 0) {
        var sum = 0, unk = 0;
        for (final x in [u, rr, d, l]) {
          if (x > 0) sum += x;
          if (x < 0) unk++;
        }
        if (sum > lv.clues[i] || sum + unk * 2 < lv.clues[i]) return false;
        continue;
      }
      // su: köprü geçerse iki yanı eşit, kesişme yok
      if (u >= 0 && d >= 0 && u != d) return false;
      if (l >= 0 && rr >= 0 && l != rr) return false;
      final h = math.max(l, rr), v = math.max(u, d);
      if (h > 0 && v > 0) return false;
    }
    if (complete) {
      final islands = [for (var i = 0; i < lv.n; i++) if (lv.clues[i] >= 0) i];
      final comp = linkComponents(lv, links);
      for (final i in islands) {
        if (comp[i] != comp[islands.first]) return false;
      }
    }
    return true;
  }

  @override
  PLevel make(int difficulty, SeededRandom r) {
    final n = const [5, 6, 7, 7, 8, 9, 9, 10, 11, 12][difficulty - 1];
    for (var attempt = 0; attempt < 200; attempt++) {
      final probe = PLevel(kind: id, w: n, h: n, clues: const [], givens: const []);
      final island = List.filled(n * n, false);
      final occupied = List.filled(n * n, false); // köprü geçen su
      final links = List.filled(probe.linkCount, 0);
      final first = r.nextInt(n * n);
      island[first] = true;
      final list = [first];
      final target = (n * n * 0.22).round();
      for (var t = 0; t < 600 && list.length < target; t++) {
        final a = list[r.nextInt(list.length)];
        final dir = r.nextInt(4);
        final len = 2 + r.nextInt(math.max(1, n ~/ 2));
        final path = <int>[];
        var c = a;
        var okk = true;
        for (var k = 0; k < len; k++) {
          final x = c % n, y = c ~/ n;
          if ((dir == 0 && y == 0) || (dir == 2 && y == n - 1) || (dir == 1 && x == n - 1) || (dir == 3 && x == 0)) {
            okk = false;
            break;
          }
          c = neighborDir(probe, c, dir);
          if (island[c] || occupied[c]) {
            okk = false;
            break;
          }
          path.add(c);
        }
        if (!okk || path.length < 2) continue;
        final end = path.removeLast();
        // yeni ada başka adaya bitişik olmasın
        if (probe.neighbors(end).any((nb) => island[nb])) continue;
        island[end] = true;
        list.add(end);
        final val = r.chance(0.35) ? 2 : 1;
        var prev = a;
        for (final p in [...path, end]) {
          links[probe.linkBetween(prev, p)] = val;
          if (p != end) occupied[p] = true;
          prev = p;
        }
      }
      if (list.length < math.max(4, target ~/ 2)) continue;
      // hizalı komşu adalar arasında ek köprüler
      final clues = List.filled(n * n, -1);
      for (final i in list) {
        var sum = 0;
        for (var dir = 0; dir < 4; dir++) {
          sum += linkDir(probe, links, i, dir);
        }
        clues[i] = sum;
      }
      final lv = PLevel(kind: id, w: n, h: n, clues: clues, solLinks: links, givens: List.filled(n * n, -1), givenLinks: List.filled(probe.linkCount, -1));
      if (!ok(lv, PState(List.filled(n * n, 0), links, List.filled(probe.borderCount, 0)), true)) continue;
      return lv;
    }
    throw StateError('hashi');
  }

  @override
  List<int> linkDomain(PLevel lv) => const [0, 1, 2];

  @override
  double maxGivenRatio(int difficulty) => 0.3;
}

// ======================================================================
// Sayı bağlama ve Tek çizgi

/// Aynı sayıları yollarla birleştir; yollar kesişmez ve bütün hücreleri
/// doldurur. clues: uç noktalarda yol kimliği (1..), diğerleri -1.
/// [single] doğruysa tek yol (başlangıç 1, bitiş 2) bütün hücrelerden
/// geçer; delikler -2.
class PathLinkKind extends PuzzleKind {
  final bool single;
  const PathLinkKind({this.single = false});

  @override
  String get id => single ? 'tek-cizgi' : 'sayi-baglama';

  @override
  CellInput get cellInput => CellInput.none;

  @override
  bool get usesLinks => true;

  @override
  bool tapCell(PLevel lv, int i) => false;

  @override
  List<(int, int)>? solveOrder(PLevel lv) => linkOrder(lv);

  @override
  CellLook look(PLevel lv, PState s, int i) {
    final c = lv.clues[i];
    if (c == -2) return const CellLook(mark: Mark.wall);
    if (c > 0) {
      if (single) return CellLook(mark: c == 1 ? Mark.disc : Mark.ring);
      return CellLook(color: 1 + (c - 1) % 9, text: '$c', tone: 1);
    }
    return const CellLook();
  }

  @override
  Color? linkColor(PLevel lv, PState s, int l) {
    if (single) return null;
    // bağın bileşenindeki uç noktanın rengi
    final comp = linkComponents(lv, s.links);
    final (a, _) = lv.linkCells(l);
    for (var i = 0; i < lv.n; i++) {
      if (comp[i] == comp[a] && lv.clues[i] > 0) return _pathColor(lv.clues[i]);
    }
    return null;
  }

  static Color _pathColor(int k) => const [
        Color(0xFF2E4057),
        Color(0xFFD1495B),
        Color(0xFF00798C),
        Color(0xFFEDAE49),
        Color(0xFF66A182),
        Color(0xFF8E6C8A),
        Color(0xFFB5651D),
        Color(0xFF3F88C5),
        Color(0xFF9DBF9E),
      ][(k - 1) % 9];

  @override
  bool ok(PLevel lv, PState s, bool complete) {
    final links = s.links;
    for (var i = 0; i < lv.n; i++) {
      final (d, u) = degree(lv, links, i);
      final hole = lv.clues[i] == -2;
      final end = lv.clues[i] > 0;
      if (hole) {
        if (d > 0) return false;
        continue;
      }
      final want = end ? 1 : 2;
      if (d > want || d + u < want) return false;
    }
    // bileşenlerde farklı uçlar ve döngü olmamalı
    final parent = List.generate(lv.n, (i) => i);
    int find(int x) {
      while (parent[x] != x) {
        parent[x] = parent[parent[x]];
        x = parent[x];
      }
      return x;
    }

    for (var l = 0; l < lv.linkCount; l++) {
      if (links[l] != 1) continue;
      final (a, b) = lv.linkCells(l);
      final ra = find(a), rb = find(b);
      if (ra == rb) return false;
      parent[ra] = rb;
    }
    final endOf = <int, int>{};
    for (var i = 0; i < lv.n; i++) {
      final c = lv.clues[i];
      if (c <= 0) continue;
      final root = find(i);
      final key = single ? 1 : c;
      final prev = endOf[root];
      if (prev != null && prev != key) return false;
      endOf[root] = key;
    }
    if (complete) {
      // her yol iki ucu birleştirir: bileşen sayısı = yol sayısı
      final roots = <int>{};
      for (var i = 0; i < lv.n; i++) {
        if (lv.clues[i] != -2) roots.add(find(i));
      }
      final paths = single ? 1 : lv.clues.where((c) => c > 0).toSet().length;
      if (roots.length != paths) return false;
    }
    return true;
  }

  @override
  PLevel make(int difficulty, SeededRandom r) {
    final n = single ? const [4, 5, 5, 6, 6, 7, 7, 8, 8, 9][difficulty - 1] : const [5, 5, 6, 6, 7, 7, 8, 8, 9, 10][difficulty - 1];
    for (var attempt = 0; attempt < 300; attempt++) {
      final probe = PLevel(kind: id, w: n, h: n, clues: const [], givens: const []);
      final clues = List.filled(n * n, -1);
      final links = List.filled(probe.linkCount, 0);
      if (single) {
        final holes = difficulty >= 3 ? r.nextInt(n ~/ 2 + 1) : 0;
        for (var k = 0; k < holes; k++) {
          clues[r.nextInt(n * n)] = -2;
        }
        final path = _orthHamilton(n, clues, r);
        if (path == null) continue;
        for (var k = 0; k + 1 < path.length; k++) {
          links[probe.linkBetween(path[k], path[k + 1])] = 1;
        }
        clues[path.first] = 1;
        clues[path.last] = 2;
      } else {
        // yol birleştirme: başta her hücre ayrı yol
        final end = List.filled(n * n, true); // yol ucu mu (derece < 2)
        final root = List.generate(n * n, (i) => i);
        int find(int x) {
          while (root[x] != x) {
            root[x] = root[root[x]];
            x = root[x];
          }
          return x;
        }

        final deg = List.filled(n * n, 0);
        final size = List.filled(n * n, 1);
        final maxLen = difficulty <= 3 ? n + 2 : n * 2;
        for (var t = 0; t < n * n * 30; t++) {
          final a = r.nextInt(n * n);
          if (deg[a] >= 2) continue;
          final opts = probe.neighbors(a).where((b) => deg[b] < 2 && find(a) != find(b)).toList();
          if (opts.isEmpty) continue;
          final b = opts[r.nextInt(opts.length)];
          if (size[find(a)] + size[find(b)] > maxLen) continue;
          links[probe.linkBetween(a, b)] = 1;
          deg[a]++;
          deg[b]++;
          final s2 = size[find(a)] + size[find(b)];
          root[find(a)] = find(b);
          size[find(b)] = s2;
        }
        // tek hücrelik yollar olmamalı
        if (deg.contains(0)) continue;
        final ids = <int, int>{};
        for (var i = 0; i < n * n; i++) {
          if (deg[i] == 1) clues[i] = ids.putIfAbsent(find(i), () => ids.length + 1);
        }
        if (end.isEmpty) continue;
        if (ids.length > 9 + n) continue;
      }
      final lv = PLevel(kind: id, w: n, h: n, clues: clues, solLinks: links, givens: List.filled(n * n, -1), givenLinks: List.filled(probe.linkCount, -1));
      if (!ok(lv, PState(List.filled(n * n, 0), links, List.filled(probe.borderCount, 0)), true)) continue;
      return lv;
    }
    throw StateError('pathlink');
  }

  List<int>? _orthHamilton(int n, List<int> clues, SeededRandom r) {
    final total = clues.where((c) => c != -2).length;
    final probe = PLevel(kind: id, w: n, h: n, clues: const [], givens: const []);
    for (var tries = 0; tries < 60; tries++) {
      final starts = [for (var i = 0; i < n * n; i++) if (clues[i] != -2) i];
      var cur = starts[r.nextInt(starts.length)];
      final used = List.filled(n * n, false)..[cur] = true;
      final path = [cur];
      while (path.length < total) {
        final opts = probe.neighbors(cur).where((b) => !used[b] && clues[b] != -2).toList();
        if (opts.isEmpty) break;
        var best = <int>[];
        var bd = 99;
        for (final b in opts) {
          final dd = probe.neighbors(b).where((c) => !used[c] && clues[c] != -2).length;
          if (dd < bd) {
            bd = dd;
            best = [b];
          } else if (dd == bd) {
            best.add(b);
          }
        }
        cur = best[r.nextInt(best.length)];
        used[cur] = true;
        path.add(cur);
      }
      if (path.length == total) return path;
    }
    return null;
  }

  @override
  double maxGivenRatio(int difficulty) => 0.35;
}

// ======================================================================
// Eğik çizgi (Gokigen)

/// Her hücreye / ya da \; köşelerdeki sayı o noktaya değen çizgi sayısı;
/// çizgiler kapalı döngü oluşturmaz. Hücre: 1 '/', 2 '\'.
/// extra[0]: köşe ipuçları ((w+1)(h+1), -1 yok).
class SlantKind extends PuzzleKind {
  const SlantKind();
  @override
  String get id => 'egik-cizgi';

  @override
  int cellStates(PLevel lv) => 3;

  @override
  bool get zeroUnknown => true;

  @override
  bool tapCell(PLevel lv, int i) => lv.givens.isEmpty || lv.givens[i] < 0;

  @override
  CellLook look(PLevel lv, PState s, int i) {
    final v = s.cells[i];
    return CellLook(mark: v == 1 ? Mark.slashF : (v == 2 ? Mark.slashB : Mark.none), tone: lv.givens.isNotEmpty && lv.givens[i] >= 0 ? 1 : 0);
  }

  (int, int) _ends(PLevel lv, int i, int v) {
    final x = i % lv.w, y = i ~/ lv.w, vw = lv.w + 1;
    return v == 1 ? ((y + 1) * vw + x, y * vw + x + 1) : (y * vw + x, (y + 1) * vw + x + 1);
  }

  @override
  bool ok(PLevel lv, PState s, bool complete) {
    final v = s.cells;
    final vw = lv.w + 1;
    final nv = vw * (lv.h + 1);
    final deg = List.filled(nv, 0), unk = List.filled(nv, 0);
    final parent = List.generate(nv, (i) => i);
    int find(int x) {
      while (parent[x] != x) {
        parent[x] = parent[parent[x]];
        x = parent[x];
      }
      return x;
    }

    for (var i = 0; i < lv.n; i++) {
      final x = i % lv.w, y = i ~/ lv.w;
      if (v[i] < 0) {
        for (final c in [y * vw + x, y * vw + x + 1, (y + 1) * vw + x, (y + 1) * vw + x + 1]) {
          unk[c]++;
        }
        continue;
      }
      final (a, b) = _ends(lv, i, v[i]);
      deg[a]++;
      deg[b]++;
      final ra = find(a), rb = find(b);
      if (ra == rb) return false;
      parent[ra] = rb;
    }
    for (var c = 0; c < nv; c++) {
      final t = lv.extra[0][c];
      if (t < 0) continue;
      if (deg[c] > t || deg[c] + unk[c] < t) return false;
    }
    return true;
  }

  @override
  PLevel make(int difficulty, SeededRandom r) {
    final n = const [4, 5, 5, 6, 6, 7, 7, 8, 9, 10][difficulty - 1];
    final probe = PLevel(kind: id, w: n, h: n, clues: const [], extra: [List.filled((n + 1) * (n + 1), -1)], givens: const []);
    final v = List.filled(n * n, -1);
    for (var i = 0; i < n * n; i++) {
      final first = r.chance(0.5) ? 1 : 2;
      v[i] = first;
      if (!ok(probe, PState(v, const [], const []), false)) v[i] = 3 - first;
      if (!ok(probe, PState(v, const [], const []), false)) throw StateError('slant');
    }
    final vw = n + 1;
    final cnt = List.filled(vw * (n + 1), 0);
    for (var i = 0; i < n * n; i++) {
      final (a, b) = _ends(probe, i, v[i]);
      cnt[a]++;
      cnt[b]++;
    }
    final p = difficulty <= 3 ? 0.7 : (difficulty <= 6 ? 0.55 : 0.45);
    final clues = [for (final c in cnt) r.chance(p) ? c : -1];
    return PLevel(kind: id, w: n, h: n, clues: const [], extra: [clues], solCells: v, givens: List.filled(n * n, -1));
  }

  @override
  void paintOver(Canvas c, PLevel lv, PState s, Rect Function(int i) cell, double cs) {
    final vw = lv.w + 1;
    for (var k = 0; k < vw * (lv.h + 1); k++) {
      final t = lv.extra[0][k];
      if (t < 0) continue;
      final x = k % vw, y = k ~/ vw;
      final o = cell(0).topLeft + Offset(x * cs, y * cs);
      c.drawCircle(o, cs * 0.17, Paint()..color = const Color(0xFFF6EBD9));
      c.drawCircle(
          o,
          cs * 0.17,
          Paint()
            ..style = PaintingStyle.stroke
            ..color = const Color(0xFF5A4A3F)
            ..strokeWidth = cs * 0.03);
      final pb = ParagraphBuilder(ParagraphStyle(fontSize: cs * 0.22, textAlign: TextAlign.center))
        ..pushStyle(TextStyle(color: const Color(0xFF3B3A40), fontSize: cs * 0.22, fontWeight: FontWeight.w800))
        ..addText('$t');
      final p = pb.build()..layout(ParagraphConstraints(width: cs));
      c.drawParagraph(p, o - Offset(cs / 2, p.height / 2));
    }
  }

  @override
  double maxGivenRatio(int difficulty) => 0.5;
}
