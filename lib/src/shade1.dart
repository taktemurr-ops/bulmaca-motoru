import 'dart:math' as math;
import 'dart:ui';

import 'package:studio_core/core/rng.dart';

import 'core.dart';
import 'digits.dart';

/// Karalama bulmacalarının tabanı: 0 boş, 1 dolu (ya da simge), 2 nokta.
abstract class ShadeKind extends PuzzleKind {
  const ShadeKind();

  @override
  int cellStates(PLevel lv) => 3;

  @override
  int get markState => 2;

  /// Dolu hücrenin simgesi.
  Mark get onMark => Mark.fill;

  @override
  List<int> cellDomain(PLevel lv, int i) => (lv.clues.isNotEmpty && lv.clues[i] >= 0 && !shadeClues) ? const [0] : const [0, 1];

  /// İpucu hücreleri de karalanabilir mi (ör. Hitori).
  bool get shadeClues => false;

  @override
  bool tapCell(PLevel lv, int i) => (lv.givens.isEmpty || lv.givens[i] < 0) && (shadeClues || lv.clues.isEmpty || lv.clues[i] < 0);

  @override
  bool canGive(PLevel lv, int i) => shadeClues || lv.clues.isEmpty || lv.clues[i] < 0;

  @override
  double maxGivenRatio(int difficulty) => 0.5;

  @override
  CellLook look(PLevel lv, PState s, int i) {
    final v = s.cells[i];
    final clue = lv.clues.isNotEmpty ? lv.clues[i] : -1;
    final given = lv.givens.isNotEmpty && lv.givens[i] >= 0;
    final mark = v == 1 ? onMark : (v == 2 ? Mark.dot : Mark.none);
    if (clue >= 0) return CellLook(text: clueText(lv, i), tone: 1, mark: shadeClues && v == 1 ? Mark.fill : (v == 2 && shadeClues ? Mark.circle : Mark.none));
    return CellLook(mark: given && v == 0 ? Mark.dot : mark, tone: given ? 1 : 0);
  }

  String clueText(PLevel lv, int i) => '${lv.clues[i]}';

  // ---- ortak yardımcılar
  /// Karasız (0) ve bilinmeyen hücreler birbirine bağlı mı?
  static bool whitesConnected(PLevel lv, List<int> v, {bool unknownCounts = true, bool Function(int i)? skip}) {
    var start = -1;
    var total = 0;
    for (var i = 0; i < lv.n; i++) {
      if (skip != null && skip(i)) continue;
      if (v[i] == 0 || (unknownCounts && v[i] < 0)) {
        total++;
        if (start < 0 && v[i] == 0) start = i;
      }
    }
    if (start < 0) return true;
    final seen = List.filled(lv.n, false)..[start] = true;
    final q = [start];
    for (var k = 0; k < q.length; k++) {
      for (final nb in lv.neighbors(q[k])) {
        if (seen[nb] || (skip != null && skip(nb))) continue;
        if (v[nb] == 0 || (unknownCounts && v[nb] < 0)) {
          seen[nb] = true;
          q.add(nb);
        }
      }
    }
    return q.length == total;
  }

  static bool shadedConnected(PLevel lv, List<int> v, {bool unknownCounts = true}) {
    var start = -1, total = 0;
    for (var i = 0; i < lv.n; i++) {
      if (v[i] == 1 || (unknownCounts && v[i] < 0)) {
        total++;
        if (start < 0 && v[i] == 1) start = i;
      }
    }
    if (start < 0) return true;
    final seen = List.filled(lv.n, false)..[start] = true;
    final q = [start];
    for (var k = 0; k < q.length; k++) {
      for (final nb in lv.neighbors(q[k])) {
        if (!seen[nb] && (v[nb] == 1 || (unknownCounts && v[nb] < 0))) {
          seen[nb] = true;
          q.add(nb);
        }
      }
    }
    return q.length == total;
  }

  static bool noAdjacentShaded(PLevel lv, List<int> v) {
    for (var i = 0; i < lv.n; i++) {
      if (v[i] != 1) continue;
      if (i % lv.w < lv.w - 1 && v[i + 1] == 1) return false;
      if (i ~/ lv.w < lv.h - 1 && v[i + lv.w] == 1) return false;
    }
    return true;
  }

  static bool no2x2(PLevel lv, List<int> v, int val) {
    for (var y = 0; y + 1 < lv.h; y++) {
      for (var x = 0; x + 1 < lv.w; x++) {
        final i = y * lv.w + x;
        if (v[i] == val && v[i + 1] == val && v[i + lv.w] == val && v[i + lv.w + 1] == val) return false;
      }
    }
    return true;
  }

  /// Rastgele, komşusuz ve beyazları bölmeyen karalar.
  static List<int> randomSparse(int w, int h, double density, SeededRandom r, {bool Function(int i)? allowed}) {
    final lv = PLevel(kind: '', w: w, h: h, clues: const [], givens: const []);
    final v = List.filled(w * h, 0);
    for (final i in shuffled(w * h, r)) {
      if (!r.chance(density * 2)) continue;
      if (allowed != null && !allowed(i)) continue;
      if (lv.neighbors(i).any((nb) => v[nb] == 1)) continue;
      v[i] = 1;
      if (!whitesConnected(lv, v, unknownCounts: false)) v[i] = 0;
    }
    return v;
  }
}

// ======================================================================
// Nonogram (tek renk ve renkli)

/// Satır/sütun ipuçları: ardışık dolu hücre gruplarının uzunlukları.
/// Renkli türde her grup renkliyse aynı renkli gruplar arasında boşluk
/// zorunlu, farklı renkler bitişebilir.
/// extra: ilk h satır, sonra w sütun; her biri [uzunluk, renk, ...].
class NonogramKind extends PuzzleKind {
  final bool colored;
  const NonogramKind({this.colored = false});

  @override
  String get id => colored ? 'renkli-nonogram' : 'nonogram';

  @override
  CellInput get cellInput => colored ? CellInput.colors : CellInput.cycle;

  @override
  int cellStates(PLevel lv) => colored ? lv.param + 1 : 3;

  @override
  int get markState => colored ? -1 : 2;

  static (int, int) sizeFor(int d, bool colored) =>
      colored ? const [(5, 5), (6, 6), (7, 7), (8, 8), (8, 8), (10, 10), (10, 10), (12, 12), (12, 12), (14, 14)][d - 1] : const [(5, 5), (6, 6), (8, 8), (10, 10), (10, 10), (12, 12), (12, 12), (15, 15), (15, 15), (15, 15)][d - 1];

  static List<int> runsOf(List<int> line) {
    final out = <int>[];
    var k = 0;
    while (k < line.length) {
      if (line[k] <= 0) {
        k++;
        continue;
      }
      final col = line[k];
      var len = 0;
      while (k < line.length && line[k] == col) {
        len++;
        k++;
      }
      out.addAll([len, col]);
    }
    return out;
  }

  List<int> _line(PLevel lv, List<int> v, int idx) =>
      idx < lv.h ? v.sublist(idx * lv.w, idx * lv.w + lv.w) : [for (var y = 0; y < lv.h; y++) v[y * lv.w + idx - lv.h]];

  List<int> _lineCells(PLevel lv, int idx) =>
      idx < lv.h ? [for (var x = 0; x < lv.w; x++) idx * lv.w + x] : [for (var y = 0; y < lv.h; y++) y * lv.w + idx - lv.h];

  /// Satır çözücü: bilinmeyenler -1. Her hücre için olası değerler
  /// kümesi (bit maskesi) döner; çelişkide null.
  static List<int>? solveLine(List<int> cells, List<int> clue, int colors) {
    final n = cells.length;
    final m = clue.length ~/ 2;
    // reach[k][i]: ilk k grup, ilk i hücreye sığar mı (i'den sonra serbest)
    // İleri ve geri DP ile her hücrede değer olasılığı.
    bool can(int i, int col) => cells[i] < 0 || cells[i] == col;
    // fwd[k][i]: ilk k grup ilk i hücreye yerleştirilebilir (i hücre tüketilmiş)
    final fwd = List.generate(m + 1, (_) => List.filled(n + 1, false));
    fwd[0][0] = true;
    for (var i = 1; i <= n; i++) {
      fwd[0][i] = fwd[0][i - 1] && can(i - 1, 0);
    }
    for (var k = 1; k <= m; k++) {
      final len = clue[(k - 1) * 2], col = clue[(k - 1) * 2 + 1];
      final prevCol = k >= 2 ? clue[(k - 2) * 2 + 1] : -1;
      for (var i = 1; i <= n; i++) {
        // i-1 boş
        var ok = fwd[k][i - 1] && can(i - 1, 0);
        if (!ok && i >= len) {
          // grup [i-len, i)
          var fits = true;
          for (var q = i - len; q < i; q++) {
            if (!can(q, col)) {
              fits = false;
              break;
            }
          }
          if (fits) {
            final start = i - len;
            if (k == 1) {
              ok = fwd[0][start];
            } else if (prevCol == col) {
              ok = start >= 1 && can(start - 1, 0) && fwd[k - 1][start - 1];
            } else {
              ok = fwd[k - 1][start] || (start >= 1 && can(start - 1, 0) && fwd[k - 1][start - 1]);
            }
          }
        }
        fwd[k][i] = ok;
      }
    }
    if (!fwd[m][n]) return null;
    // geri: bwd[k][i]: k..m-1 grupları [i, n) aralığına sığar
    final bwd = List.generate(m + 2, (_) => List.filled(n + 2, false));
    bwd[m][n] = true;
    for (var i = n - 1; i >= 0; i--) {
      bwd[m][i] = bwd[m][i + 1] && can(i, 0);
    }
    for (var k = m - 1; k >= 0; k--) {
      final len = clue[k * 2], col = clue[k * 2 + 1];
      final nextCol = k + 1 < m ? clue[(k + 1) * 2 + 1] : -1;
      for (var i = n - 1; i >= 0; i--) {
        var ok = bwd[k][i + 1] && can(i, 0);
        if (!ok && i + len <= n) {
          var fits = true;
          for (var q = i; q < i + len; q++) {
            if (!can(q, col)) {
              fits = false;
              break;
            }
          }
          if (fits) {
            final end = i + len;
            if (k == m - 1) {
              ok = bwd[m][end];
            } else if (nextCol == col) {
              ok = end < n && can(end, 0) && bwd[k + 1][end + 1];
            } else {
              ok = bwd[k + 1][end] || (end < n && can(end, 0) && bwd[k + 1][end + 1]);
            }
          }
        }
        bwd[k][i] = ok;
      }
    }
    // Olasılıklar
    final poss = List.filled(n, 0);
    // boş: i hücresi boş olabilir mi: bir k için fwd[k][i] && bwd[k][i+1]
    for (var i = 0; i < n; i++) {
      if (!can(i, 0)) continue;
      for (var k = 0; k <= m; k++) {
        if (fwd[k][i] && bwd[k][i + 1]) {
          poss[i] |= 1;
          break;
        }
      }
    }
    // grup k [s, s+len) yerleşimi: fwd'ye göre önceki gruplar s'ye kadar, bwd'ye göre sonrakiler
    for (var k = 0; k < m; k++) {
      final len = clue[k * 2], col = clue[k * 2 + 1];
      final prevCol = k >= 1 ? clue[(k - 1) * 2 + 1] : -1;
      final nextCol = k + 1 < m ? clue[(k + 1) * 2 + 1] : -1;
      for (var s = 0; s + len <= n; s++) {
        var fits = true;
        for (var q = s; q < s + len; q++) {
          if (!can(q, col)) {
            fits = false;
            break;
          }
        }
        if (!fits) continue;
        bool before;
        if (k == 0) {
          before = fwd[0][s];
        } else if (prevCol == col) {
          before = s >= 1 && can(s - 1, 0) && fwd[k][s - 1];
        } else {
          before = fwd[k][s] || (s >= 1 && can(s - 1, 0) && fwd[k][s - 1]);
        }
        if (!before) continue;
        final end = s + len;
        bool after;
        if (k == m - 1) {
          after = bwd[m][end];
        } else if (nextCol == col) {
          after = end < n && can(end, 0) && bwd[k + 1][end + 1];
        } else {
          after = bwd[k + 1][end] || (end < n && can(end, 0) && bwd[k + 1][end + 1]);
        }
        if (!after) continue;
        for (var q = s; q < end; q++) {
          poss[q] |= 1 << col;
        }
      }
    }
    for (final p in poss) {
      if (p == 0) return null;
    }
    return poss;
  }

  List<int> clueOf(PLevel lv, int idx) => lv.extra[idx];

  @override
  bool ok(PLevel lv, PState s, bool complete) {
    final v = s.cells;
    for (var idx = 0; idx < lv.h + lv.w; idx++) {
      final line = _line(lv, v, idx);
      if (complete || !line.contains(-1)) {
        final runs = runsOf(line);
        final clue = clueOf(lv, idx);
        if (runs.length != clue.length) return false;
        for (var k = 0; k < runs.length; k++) {
          if (runs[k] != clue[k]) return false;
        }
      } else if (solveLine(line, clueOf(lv, idx), lv.param) == null) {
        return false;
      }
    }
    return true;
  }

  @override
  bool solved(PLevel lv, PState player) {
    final v = [for (final x in player.cells) x == 2 && !colored ? 0 : x];
    return ok(lv, PState(v, const [], const []), true);
  }

  @override
  int? countSolutions(PLevel lv, {int limit = 2, int budget = 200000}) {
    final v = [for (var i = 0; i < lv.n; i++) lv.givens.isNotEmpty && lv.givens[i] >= 0 ? lv.givens[i] : -1];
    var found = 0, nodes = 0;
    var over = false;
    // Satır mantığıyla sabit noktaya kadar ilerle.
    bool propagate(List<int> v) {
      var changed = true;
      while (changed) {
        changed = false;
        for (var idx = 0; idx < lv.h + lv.w; idx++) {
          if (++nodes > budget) {
            over = true;
            return false;
          }
          final cells = _lineCells(lv, idx);
          final line = [for (final c in cells) v[c]];
          if (!line.contains(-1)) {
            if (solveLine(line, clueOf(lv, idx), lv.param) == null) return false;
            continue;
          }
          final poss = solveLine(line, clueOf(lv, idx), lv.param);
          if (poss == null) return false;
          for (var q = 0; q < cells.length; q++) {
            if (line[q] >= 0) continue;
            final p = poss[q];
            if (p & (p - 1) == 0) {
              var val = 0;
              while ((1 << val) != p) {
                val++;
              }
              v[cells[q]] = val;
              changed = true;
            }
          }
        }
      }
      return true;
    }

    void go(List<int> v) {
      if (found >= limit || over) return;
      if (!propagate(v)) return;
      final i = v.indexOf(-1);
      if (i < 0) {
        found++;
        return;
      }
      final maxCol = colored ? lv.param : 1;
      for (var val = 0; val <= maxCol; val++) {
        final c = List.of(v)..[i] = val;
        go(c);
        if (found >= limit || over) return;
      }
    }

    go(v);
    return over ? null : found;
  }

  @override
  PLevel make(int difficulty, SeededRandom r) {
    final (w, h) = sizeFor(difficulty, colored);
    final colors = colored ? (difficulty <= 3 ? 2 : (difficulty <= 7 ? 3 : 4)) : 1;
    // Yumuşak lekeler: rastgele doldur ve hücresel kuralla düzle.
    var g = [for (var i = 0; i < w * h; i++) r.chance(0.55) ? 1 + r.nextInt(colors) : 0];
    for (var pass = 0; pass < 2; pass++) {
      final ng = List.of(g);
      for (var i = 0; i < w * h; i++) {
        final x = i % w, y = i ~/ w;
        final cnt = List.filled(colors + 1, 0);
        for (var dy = -1; dy <= 1; dy++) {
          for (var dx = -1; dx <= 1; dx++) {
            final nx = x + dx, ny = y + dy;
            if (nx < 0 || ny < 0 || nx >= w || ny >= h) continue;
            cnt[g[ny * w + nx]]++;
          }
        }
        var best = 0;
        for (var c = 1; c <= colors; c++) {
          if (cnt[c] > cnt[best]) best = c;
        }
        if (cnt[best] >= 5) ng[i] = best;
      }
      g = ng;
    }
    // Her satır/sütunda en az bir dolu
    for (var y = 0; y < h; y++) {
      if (!g.sublist(y * w, y * w + w).any((c) => c > 0)) g[y * w + r.nextInt(w)] = 1 + r.nextInt(colors);
    }
    final probe = PLevel(kind: id, w: w, h: h, clues: const [], givens: const [], param: colors);
    final extra = [for (var idx = 0; idx < h + w; idx++) runsOf(_line(probe, g, idx))];
    return PLevel(kind: id, w: w, h: h, clues: const [], extra: extra, solCells: g, givens: List.filled(w * h, -1), param: colors);
  }

  @override
  double maxGivenRatio(int difficulty) => 0.4;

  @override
  (double, double, double, double) margins(PLevel lv) {
    var mt = 1, ml = 1;
    for (var idx = 0; idx < lv.h; idx++) {
      ml = math.max(ml, lv.extra[idx].length ~/ 2);
    }
    for (var idx = lv.h; idx < lv.h + lv.w; idx++) {
      mt = math.max(mt, lv.extra[idx].length ~/ 2);
    }
    return (math.min(mt * 0.6, lv.h * 0.5), math.min(ml * 0.62, lv.w * 0.6), 0, 0);
  }

  @override
  String outside(PLevel lv, PState s, int side, int index) {
    final List<int> clue;
    if (side == 1) {
      clue = lv.extra[index];
    } else if (side == 0) {
      clue = lv.extra[lv.h + index];
    } else {
      return '';
    }
    if (clue.isEmpty) return '0';
    return [for (var k = 0; k < clue.length; k += 2) '${clue[k]}'].join(' ');
  }

  @override
  bool outsideDone(PLevel lv, PState s, int side, int index) {
    if (side > 1) return false;
    final idx = side == 1 ? index : lv.h + index;
    final line = _line(lv, [for (final x in s.cells) x == 2 && !colored ? 0 : x], idx);
    final runs = runsOf(line);
    final clue = clueOf(lv, idx);
    if (runs.length != clue.length) return false;
    for (var k = 0; k < runs.length; k++) {
      if (runs[k] != clue[k]) return false;
    }
    return true;
  }

  @override
  CellLook look(PLevel lv, PState s, int i) {
    final v = s.cells[i];
    final given = lv.givens.isNotEmpty && lv.givens[i] >= 0;
    if (colored) return CellLook(color: v > 0 ? v : -1, mark: given && v == 0 ? Mark.dot : Mark.none);
    return CellLook(mark: v == 1 ? Mark.fill : (v == 2 || (given && v == 0) ? Mark.dot : Mark.none), tone: given ? 1 : 0);
  }

  @override
  void paintOver(Canvas c, PLevel lv, PState s, Rect Function(int i) cell, double cs) {
    // her beş hücrede bir kalın kılavuz çizgi
    final p = Paint()
      ..color = const Color(0x55302A26)
      ..strokeWidth = math.max(1.5, cs * 0.05);
    for (var x = 5; x < lv.w; x += 5) {
      c.drawLine(cell(x).topLeft, cell((lv.h - 1) * lv.w + x).bottomLeft, p);
    }
    for (var y = 5; y < lv.h; y += 5) {
      c.drawLine(cell(y * lv.w).topLeft, cell(y * lv.w + lv.w - 1).topRight, p);
    }
    if (colored) {
      // renkli ipuçlarını renk noktalarıyla göster
      for (var idx = 0; idx < lv.h + lv.w; idx++) {
        final clue = lv.extra[idx];
        final m = clue.length ~/ 2;
        for (var k = 0; k < m; k++) {
          final col = clue[k * 2 + 1];
          Offset o;
          if (idx < lv.h) {
            final step = math.min(cs * 0.62 * 1.0, cs * 0.62);
            final r0 = cell(idx * lv.w);
            o = Offset(r0.left - step * (m - k) + step * 0.5, r0.center.dy + cs * 0.3);
          } else {
            final r0 = cell(idx - lv.h);
            final step = cs * 0.6;
            o = Offset(r0.center.dx + cs * 0.3, r0.top - step * (m - k) + step * 0.5);
          }
          c.drawCircle(o, cs * 0.07, Paint()..color = _palette(col));
        }
      }
    }
  }

  static Color _palette(int v) => const [
        Color(0x00000000),
        Color(0xFF2E4057),
        Color(0xFFD1495B),
        Color(0xFF00798C),
        Color(0xFFEDAE49),
      ][v % 5];
}

// ======================================================================
// Hitori

/// Bazı hücreleri karala: karasız hücrelerde satır/sütunda aynı sayı
/// olmasın; karalar yan yana değmesin; karasızlar tek parça kalsın.
class HitoriKind extends ShadeKind {
  const HitoriKind();
  @override
  String get id => 'hitori';

  @override
  bool get shadeClues => true;

  @override
  bool ok(PLevel lv, PState s, bool complete) {
    final v = s.cells;
    if (!ShadeKind.noAdjacentShaded(lv, v)) return false;
    // aynı satır/sütunda iki karasız eş sayı
    for (var y = 0; y < lv.h; y++) {
      final seen = <int>{};
      for (var x = 0; x < lv.w; x++) {
        final i = y * lv.w + x;
        if (v[i] == 0 && !seen.add(lv.clues[i])) return false;
      }
    }
    for (var x = 0; x < lv.w; x++) {
      final seen = <int>{};
      for (var y = 0; y < lv.h; y++) {
        final i = y * lv.w + x;
        if (v[i] == 0 && !seen.add(lv.clues[i])) return false;
      }
    }
    return ShadeKind.whitesConnected(lv, v);
  }

  @override
  PLevel make(int difficulty, SeededRandom r) {
    final n = const [5, 5, 6, 6, 7, 7, 8, 8, 9, 9][difficulty - 1];
    final base = PLevel(kind: 'latin', w: n, h: n, clues: const [], givens: List.filled(n * n, -1), param: n);
    final latin = const _LatinFill().randomFill(base, r, 40000)!;
    final shade = ShadeKind.randomSparse(n, n, 0.18, r);
    final clues = List.of(latin);
    for (var i = 0; i < n * n; i++) {
      if (shade[i] != 1) continue;
      // satır ya da sütundan bir eş sayı
      final x = i % n, y = i ~/ n;
      final opts = <int>[
        for (var k = 0; k < n; k++) if (k != x && shade[y * n + k] == 0) latin[y * n + k],
        for (var k = 0; k < n; k++) if (k != y && shade[k * n + x] == 0) latin[k * n + x],
      ];
      clues[i] = opts[r.nextInt(opts.length)];
    }
    return PLevel(kind: id, w: n, h: n, clues: clues, solCells: shade, givens: List.filled(n * n, -1), param: n);
  }

  @override
  double maxGivenRatio(int difficulty) => 0.4;
}

class _LatinFill extends DigitKind {
  const _LatinFill();
  @override
  String get id => 'latin';
  @override
  List<List<int>> peersFor(PLevel lv) => DigitKind.latinPeers(lv.w, lv.h);
  @override
  bool local(PLevel lv, List<int> v, int i) => true;
  @override
  PLevel make(int difficulty, SeededRandom r) => throw UnimplementedError();
}

/// Rastgele Latin kare.
List<int> randomLatin(int n, SeededRandom r) =>
    const _LatinFill().randomFill(PLevel(kind: 'latin', w: n, h: n, clues: const [], givens: List.filled(n * n, -1), param: n), r, 40000)!;

// ======================================================================
// Nurikabe

/// Sayılı her ada o kadar hücre; adalar birbirine değmez; deniz (kara)
/// tek parça ve 2x2 kara blok yok.
class IslandKind extends ShadeKind {
  const IslandKind();
  @override
  String get id => 'nurikabe';

  @override
  bool ok(PLevel lv, PState s, bool complete) {
    final v = s.cells;
    if (!ShadeKind.no2x2(lv, v, 1)) return false;
    // adalar: karasız (0) bileşenler
    final seen = List.filled(lv.n, false);
    for (var i = 0; i < lv.n; i++) {
      if (seen[i] || v[i] != 0) continue;
      final comp = [i];
      seen[i] = true;
      var open = false;
      var nums = 0, target = 0;
      for (var q = 0; q < comp.length; q++) {
        final c = comp[q];
        if (lv.clues[c] > 0) {
          nums++;
          target = lv.clues[c];
        }
        for (final nb in lv.neighbors(c)) {
          if (v[nb] < 0) open = true;
          if (!seen[nb] && v[nb] == 0) {
            seen[nb] = true;
            comp.add(nb);
          }
        }
      }
      if (nums > 1) return false;
      if (nums == 1 && comp.length > target) return false;
      if (nums == 1 && !open && comp.length < target) return false;
      if (nums == 0 && !open) return false;
    }
    // her sayı: kendisi + bilinmeyenlerle ulaşılabilir alan en az hedef
    if (!complete) {
      for (var i = 0; i < lv.n; i++) {
        if (lv.clues[i] <= 0) continue;
        final comp = [i];
        final sn = {i};
        for (var q = 0; q < comp.length && comp.length < lv.clues[i]; q++) {
          for (final nb in lv.neighbors(comp[q])) {
            if (v[nb] != 1 && sn.add(nb)) comp.add(nb);
          }
        }
        if (comp.length < lv.clues[i]) return false;
      }
    }
    return ShadeKind.shadedConnected(lv, v);
  }

  @override
  PLevel make(int difficulty, SeededRandom r) {
    final n = const [5, 5, 6, 6, 7, 7, 8, 8, 9, 10][difficulty - 1];
    for (var attempt = 0; attempt < 300; attempt++) {
      // tümü deniz; adaları büyüt
      final v = List.filled(n * n, 1);
      final clues = List.filled(n * n, -1);
      final probe = PLevel(kind: id, w: n, h: n, clues: clues, givens: const []);
      final islands = (n * n * 0.13).round() + r.nextInt(3);
      for (var k = 0; k < islands * 3; k++) {
        final s = r.nextInt(n * n);
        if (v[s] == 0 || probe.neighbors(s).any((nb) => v[nb] == 0)) continue;
        final size = 1 + r.nextInt(difficulty <= 4 ? 4 : 6);
        final cells = [s];
        v[s] = 0;
        while (cells.length < size) {
          final cand = <int>[];
          for (final c in cells) {
            for (final nb in probe.neighbors(c)) {
              if (v[nb] == 1 && probe.neighbors(nb).every((m) => v[m] == 1 || cells.contains(m))) cand.add(nb);
            }
          }
          if (cand.isEmpty) break;
          final c = cand[r.nextInt(cand.length)];
          v[c] = 0;
          cells.add(c);
          if (!ShadeKind.shadedConnected(probe, v, unknownCounts: false)) {
            v[c] = 1;
            cells.remove(c);
            break;
          }
        }
        clues[cells[r.nextInt(cells.length)]] = cells.length;
      }
      if (!ShadeKind.no2x2(probe, v, 1)) {
        // 2x2 deniz bloklarını tek hücrelik adayla kır
        var fixed = true;
        for (var y = 0; y + 1 < n && fixed; y++) {
          for (var x = 0; x + 1 < n; x++) {
            final i = y * n + x;
            if (v[i] == 1 && v[i + 1] == 1 && v[i + n] == 1 && v[i + n + 1] == 1) {
              final opts = [i, i + 1, i + n, i + n + 1].where((c) => probe.neighbors(c).every((m) => v[m] == 1)).toList();
              if (opts.isEmpty) {
                fixed = false;
                break;
              }
              final c = opts[r.nextInt(opts.length)];
              v[c] = 0;
              clues[c] = 1;
              if (!ShadeKind.shadedConnected(probe, v, unknownCounts: false)) {
                fixed = false;
                break;
              }
            }
          }
        }
        if (!fixed || !ShadeKind.no2x2(probe, v, 1)) continue;
      }
      final lv = PLevel(kind: id, w: n, h: n, clues: clues, solCells: v, givens: List.filled(n * n, -1));
      if (ok(lv, PState(v, const [], const []), true)) return lv;
    }
    throw StateError('nurikabe');
  }
}

// ======================================================================
// Heyawake

/// Odalardaki sayı, o odadaki kara hücre sayısıdır; karalar yan yana
/// değmez; beyazlar tek parça; beyaz düz bir şerit iki oda sınırını
/// geçemez. clues: odanın sol üst hücresinde sayı (yoksa -1).
class RoomsKind extends ShadeKind {
  const RoomsKind();
  @override
  String get id => 'heyawake';

  @override
  List<int> cellDomain(PLevel lv, int i) => const [0, 1];

  @override
  bool tapCell(PLevel lv, int i) => lv.givens.isEmpty || lv.givens[i] < 0;

  @override
  bool canGive(PLevel lv, int i) => true;

  @override
  CellLook look(PLevel lv, PState s, int i) {
    final v = s.cells[i];
    final given = lv.givens.isNotEmpty && lv.givens[i] >= 0;
    final clue = lv.clues[i];
    return CellLook(
      mark: v == 1 ? Mark.fill : (v == 2 || (given && v == 0) ? Mark.dot : Mark.none),
      text: clue >= 0 ? '$clue' : '',
      tone: 1,
    );
  }

  @override
  bool ok(PLevel lv, PState s, bool complete) {
    final v = s.cells;
    if (!ShadeKind.noAdjacentShaded(lv, v)) return false;
    // oda sayıları
    final rooms = <int, List<int>>{};
    for (var i = 0; i < lv.n; i++) {
      rooms.putIfAbsent(lv.regions[i], () => []).add(i);
    }
    for (var i = 0; i < lv.n; i++) {
      if (lv.clues[i] < 0) continue;
      final cells = rooms[lv.regions[i]]!;
      var shaded = 0, unk = 0;
      for (final c in cells) {
        if (v[c] == 1) shaded++;
        if (v[c] < 0) unk++;
      }
      if (shaded > lv.clues[i] || shaded + unk < lv.clues[i]) return false;
    }
    // şerit kuralı: karasız ardışık hücreler üç odaya yayılamaz
    for (var y = 0; y < lv.h; y++) {
      var regs = <int>[];
      for (var x = 0; x < lv.w; x++) {
        final i = y * lv.w + x;
        if (v[i] == 0) {
          if (regs.isEmpty || regs.last != lv.regions[i]) regs.add(lv.regions[i]);
          if (regs.length > 2) return false;
        } else {
          regs = [];
        }
      }
    }
    for (var x = 0; x < lv.w; x++) {
      var regs = <int>[];
      for (var y = 0; y < lv.h; y++) {
        final i = y * lv.w + x;
        if (v[i] == 0) {
          if (regs.isEmpty || regs.last != lv.regions[i]) regs.add(lv.regions[i]);
          if (regs.length > 2) return false;
        } else {
          regs = [];
        }
      }
    }
    return ShadeKind.whitesConnected(lv, v);
  }

  @override
  PLevel make(int difficulty, SeededRandom r) {
    final n = const [5, 5, 6, 6, 7, 7, 8, 8, 9, 10][difficulty - 1];
    for (var attempt = 0; attempt < 200; attempt++) {
      final reg = _rectRooms(n, n, r);
      final probe = PLevel(kind: id, w: n, h: n, clues: List.filled(n * n, -1), regions: reg, givens: const []);
      final v = List.filled(n * n, 0);
      for (final i in shuffled(n * n, r)) {
        if (!r.chance(0.42)) continue;
        if (probe.neighbors(i).any((nb) => v[nb] == 1)) continue;
        v[i] = 1;
        if (!ShadeKind.whitesConnected(probe, v, unknownCounts: false)) v[i] = 0;
      }
      // şerit kuralını boz(an) uzun beyazları karala
      if (!ok(probe, PState(v, const [], const []), true)) {
        var fixedAll = true;
        for (var pass = 0; pass < 30 && !ok(probe, PState(v, const [], const []), true); pass++) {
          var did = false;
          for (final i in shuffled(n * n, r)) {
            if (v[i] == 1 || probe.neighbors(i).any((nb) => v[nb] == 1)) continue;
            v[i] = 1;
            if (!ShadeKind.whitesConnected(probe, v, unknownCounts: false)) {
              v[i] = 0;
              continue;
            }
            did = true;
            break;
          }
          if (!did) {
            fixedAll = false;
            break;
          }
        }
        if (!fixedAll || !ok(probe, PState(v, const [], const []), true)) continue;
      }
      final clues = List.filled(n * n, -1);
      final firsts = <int, int>{};
      for (var i = 0; i < n * n; i++) {
        firsts.putIfAbsent(reg[i], () => i);
      }
      final show = difficulty <= 4 ? 0.9 : 0.7;
      for (final e in firsts.entries) {
        if (!r.chance(show)) continue;
        clues[e.value] = [for (var i = 0; i < n * n; i++) if (reg[i] == e.key && v[i] == 1) i].length;
      }
      return PLevel(kind: id, w: n, h: n, clues: clues, regions: reg, solCells: v, givens: List.filled(n * n, -1));
    }
    throw StateError('heyawake');
  }
}

/// Dikdörtgen odalara bölme (özyinelemeli kesme).
List<int> _rectRooms(int w, int h, SeededRandom r) {
  final reg = List.filled(w * h, 0);
  var next = 0;
  void cut(int x0, int y0, int x1, int y1) {
    final rw = x1 - x0, rh = y1 - y0;
    final big = rw * rh > 6 || rw > 3 || rh > 3;
    if (!big || (rw * rh <= 9 && r.chance(0.35))) {
      for (var y = y0; y < y1; y++) {
        for (var x = x0; x < x1; x++) {
          reg[y * w + x] = next;
        }
      }
      next++;
      return;
    }
    if (rw >= rh && rw > 1) {
      final c = x0 + 1 + r.nextInt(rw - 1);
      cut(x0, y0, c, y1);
      cut(c, y0, x1, y1);
    } else {
      final c = y0 + 1 + r.nextInt(rh - 1);
      cut(x0, y0, x1, c);
      cut(x0, c, x1, y1);
    }
  }

  cut(0, 0, w, h);
  return reg;
}

/// Dışa açık oda bölme yardımcısı.
List<int> rectRooms(int w, int h, SeededRandom r) => _rectRooms(w, h, r);

// ======================================================================
// Menzil (Kurodoko) ve Kuromasu

/// Sayılı hücreden dört yöne görülen beyaz hücre sayısı (kendisi dahil
/// ya da hariç). Karalar yan yana değmez, beyazlar tek parça.
class SightKind extends ShadeKind {
  final bool includeSelf;
  const SightKind({this.includeSelf = true});

  @override
  String get id => includeSelf ? 'menzil' : 'kuromasu';

  int seen(PLevel lv, List<int> v, int i, {bool optimistic = false}) {
    var c = includeSelf ? 1 : 0;
    final x = i % lv.w, y = i ~/ lv.w;
    for (final (dx, dy) in const [(1, 0), (-1, 0), (0, 1), (0, -1)]) {
      var nx = x + dx, ny = y + dy;
      while (nx >= 0 && ny >= 0 && nx < lv.w && ny < lv.h) {
        final val = v[ny * lv.w + nx];
        if (val == 1 || (!optimistic && val < 0)) break;
        c++;
        nx += dx;
        ny += dy;
      }
    }
    return c;
  }

  @override
  bool ok(PLevel lv, PState s, bool complete) {
    final v = s.cells;
    if (!ShadeKind.noAdjacentShaded(lv, v)) return false;
    for (var i = 0; i < lv.n; i++) {
      final t = lv.clues[i];
      if (t < 0) continue;
      if (v[i] == 1) return false;
      final lo = seen(lv, v, i), hi = seen(lv, v, i, optimistic: true);
      if (lo > t || hi < t) return false;
    }
    return ShadeKind.whitesConnected(lv, v);
  }

  @override
  PLevel make(int difficulty, SeededRandom r) {
    final n = const [5, 5, 6, 6, 7, 7, 8, 8, 9, 9][difficulty - 1];
    final v = ShadeKind.randomSparse(n, n, 0.2, r);
    final probe = PLevel(kind: id, w: n, h: n, clues: List.filled(n * n, -1), givens: const []);
    final clues = List.filled(n * n, -1);
    final whites = [for (var i = 0; i < n * n; i++) if (v[i] == 0) i];
    r.shuffle(whites);
    final count = (n * n * (difficulty <= 4 ? 0.28 : 0.2)).round();
    for (final i in whites.take(count)) {
      final s = seen(probe, v, i);
      if (s > 1 || includeSelf) clues[i] = s;
    }
    return PLevel(kind: id, w: n, h: n, clues: clues, solCells: v, givens: List.filled(n * n, -1));
  }
}

// ======================================================================
// Işık yak (Akari)

/// Duvarlar (siyah; sayılı olanlar komşu ampul sayısı) dışındaki her
/// hücre aydınlansın; ampuller birbirini görmesin.
/// clues: -1 boş hücre, 5 sayısız duvar, 0..4 sayılı duvar.
class LightKind extends ShadeKind {
  const LightKind();
  @override
  String get id => 'isik-yak';

  @override
  Mark get onMark => Mark.bulb;

  bool wall(PLevel lv, int i) => lv.clues[i] >= 0;

  @override
  CellLook look(PLevel lv, PState s, int i) {
    if (wall(lv, i)) {
      final c = lv.clues[i];
      return CellLook(mark: Mark.fill, text: c < 5 ? '$c' : '', tone: 1);
    }
    final v = s.cells[i];
    final given = lv.givens.isNotEmpty && lv.givens[i] >= 0;
    return CellLook(mark: v == 1 ? Mark.bulb : (v == 2 || (given && v == 0) ? Mark.dot : Mark.none));
  }

  @override
  void paintUnder(Canvas c, PLevel lv, PState s, Rect Function(int i) cell, double cs) {
    final lit = _lit(lv, s.cells);
    for (var i = 0; i < lv.n; i++) {
      if (!wall(lv, i) && lit[i] > 0) c.drawRect(cell(i), Paint()..color = const Color(0x55F6D365));
    }
  }

  List<int> _lit(PLevel lv, List<int> v) {
    final lit = List.filled(lv.n, 0);
    for (var i = 0; i < lv.n; i++) {
      if (v[i] != 1 || wall(lv, i)) continue;
      lit[i]++;
      final x = i % lv.w, y = i ~/ lv.w;
      for (final (dx, dy) in const [(1, 0), (-1, 0), (0, 1), (0, -1)]) {
        var nx = x + dx, ny = y + dy;
        while (nx >= 0 && ny >= 0 && nx < lv.w && ny < lv.h && !wall(lv, ny * lv.w + nx)) {
          lit[ny * lv.w + nx]++;
          nx += dx;
          ny += dy;
        }
      }
    }
    return lit;
  }

  @override
  bool ok(PLevel lv, PState s, bool complete) {
    final v = s.cells;
    // ampuller birbirini görmesin
    for (var i = 0; i < lv.n; i++) {
      if (v[i] != 1 || wall(lv, i)) continue;
      final x = i % lv.w, y = i ~/ lv.w;
      for (final (dx, dy) in const [(1, 0), (0, 1)]) {
        var nx = x + dx, ny = y + dy;
        while (nx < lv.w && ny < lv.h && !wall(lv, ny * lv.w + nx)) {
          if (v[ny * lv.w + nx] == 1) return false;
          nx += dx;
          ny += dy;
        }
      }
    }
    // sayılı duvarlar
    for (var i = 0; i < lv.n; i++) {
      final c = lv.clues[i];
      if (c < 0 || c > 4) continue;
      var on = 0, unk = 0;
      for (final nb in lv.neighbors(i)) {
        if (wall(lv, nb)) continue;
        if (v[nb] == 1) on++;
        if (v[nb] < 0) unk++;
      }
      if (on > c || on + unk < c) return false;
    }
    if (complete) {
      final lit = _lit(lv, v);
      for (var i = 0; i < lv.n; i++) {
        if (!wall(lv, i) && lit[i] == 0) return false;
      }
    } else {
      // her hücre en az bir aday ampulle aydınlanabilmeli
      for (var i = 0; i < lv.n; i++) {
        if (wall(lv, i) || v[i] == 1 || v[i] < 0) continue;
        var can = false;
        final x = i % lv.w, y = i ~/ lv.w;
        for (final (dx, dy) in const [(1, 0), (-1, 0), (0, 1), (0, -1)]) {
          var nx = x + dx, ny = y + dy;
          while (nx >= 0 && ny >= 0 && nx < lv.w && ny < lv.h && !wall(lv, ny * lv.w + nx)) {
            final q = v[ny * lv.w + nx];
            if (q == 1 || q < 0) {
              can = true;
              break;
            }
            nx += dx;
            ny += dy;
          }
          if (can) break;
        }
        if (!can) return false;
      }
    }
    return true;
  }

  @override
  List<int> cellDomain(PLevel lv, int i) => wall(lv, i) ? const [0] : const [0, 1];

  @override
  PLevel make(int difficulty, SeededRandom r) {
    final n = const [5, 6, 6, 7, 7, 8, 8, 9, 10, 10][difficulty - 1];
    final clues = List.filled(n * n, -1);
    for (var i = 0; i < n * n; i++) {
      if (r.chance(0.2)) {
        clues[i] = 5;
        clues[n * n - 1 - i] = 5;
      }
    }
    final probe = PLevel(kind: id, w: n, h: n, clues: clues, givens: const []);
    // ampulleri açgözlü yerleştir: aydınlanmamış hücrelere
    final v = List.filled(n * n, 0);
    for (final i in shuffled(n * n, r)) {
      if (wall(probe, i)) continue;
      if (_lit(probe, v)[i] > 0) continue;
      v[i] = 1;
    }
    for (var i = 0; i < n * n; i++) {
      if (clues[i] == 5 && r.chance(difficulty <= 4 ? 0.75 : 0.55)) {
        clues[i] = probe.neighbors(i).where((nb) => v[nb] == 1).length;
      }
    }
    final lv = PLevel(kind: id, w: n, h: n, clues: clues, solCells: v, givens: List.filled(n * n, -1));
    return lv;
  }
}

// ======================================================================
// Mozaik (dolgu)

/// Her sayı, kendisi ve sekiz komşusundaki dolu hücre sayısıdır.
class MosaicKind extends ShadeKind {
  const MosaicKind();
  @override
  String get id => 'mozaik';

  @override
  bool get shadeClues => true;

  @override
  CellLook look(PLevel lv, PState s, int i) {
    final v = s.cells[i];
    final c = lv.clues[i];
    return CellLook(mark: v == 1 ? Mark.fill : (v == 2 ? Mark.dot : Mark.none), text: c >= 0 ? '$c' : '', tone: 1);
  }

  @override
  bool ok(PLevel lv, PState s, bool complete) {
    final v = s.cells;
    for (var i = 0; i < lv.n; i++) {
      final c = lv.clues[i];
      if (c < 0) continue;
      var on = v[i] == 1 ? 1 : 0, unk = v[i] < 0 ? 1 : 0;
      for (final nb in lv.neighbors(i, diag: true)) {
        if (v[nb] == 1) on++;
        if (v[nb] < 0) unk++;
      }
      if (on > c || on + unk < c) return false;
    }
    return true;
  }

  @override
  PLevel make(int difficulty, SeededRandom r) {
    final n = const [5, 6, 7, 8, 8, 9, 10, 10, 12, 12][difficulty - 1];
    final v = [for (var i = 0; i < n * n; i++) r.chance(0.45) ? 1 : 0];
    final probe = PLevel(kind: id, w: n, h: n, clues: const [], givens: const []);
    final clues = List.filled(n * n, -1);
    final p = difficulty <= 3 ? 0.7 : (difficulty <= 6 ? 0.55 : 0.45);
    for (var i = 0; i < n * n; i++) {
      if (r.chance(p)) clues[i] = v[i] + probe.neighbors(i, diag: true).where((nb) => v[nb] == 1).length;
    }
    return PLevel(kind: id, w: n, h: n, clues: clues, solCells: v, givens: List.filled(n * n, -1));
  }
}

// ======================================================================
// Kakurasu

/// Karalanan hücrelerin sütun numaraları toplamı satırın sağındaki
/// sayıya, satır numaraları toplamı sütunun altındaki sayıya eşittir.
/// extra[0]: satır hedefleri, extra[1]: sütun hedefleri.
class IndexSumKind extends ShadeKind {
  const IndexSumKind();
  @override
  String get id => 'kakurasu';

  @override
  bool ok(PLevel lv, PState s, bool complete) {
    final v = s.cells;
    for (var y = 0; y < lv.h; y++) {
      var on = 0, can = 0;
      for (var x = 0; x < lv.w; x++) {
        final q = v[y * lv.w + x];
        if (q == 1) on += x + 1;
        if (q < 0) can += x + 1;
      }
      if (on > lv.extra[0][y] || on + can < lv.extra[0][y]) return false;
    }
    for (var x = 0; x < lv.w; x++) {
      var on = 0, can = 0;
      for (var y = 0; y < lv.h; y++) {
        final q = v[y * lv.w + x];
        if (q == 1) on += y + 1;
        if (q < 0) can += y + 1;
      }
      if (on > lv.extra[1][x] || on + can < lv.extra[1][x]) return false;
    }
    return true;
  }

  @override
  PLevel make(int difficulty, SeededRandom r) {
    final n = const [4, 4, 5, 5, 6, 6, 7, 7, 8, 9][difficulty - 1];
    final v = [for (var i = 0; i < n * n; i++) r.chance(0.45) ? 1 : 0];
    final rows = [for (var y = 0; y < n; y++) [for (var x = 0; x < n; x++) if (v[y * n + x] == 1) x + 1].fold<int>(0, (a, b) => a + b)];
    final cols = [for (var x = 0; x < n; x++) [for (var y = 0; y < n; y++) if (v[y * n + x] == 1) y + 1].fold<int>(0, (a, b) => a + b)];
    return PLevel(kind: id, w: n, h: n, clues: const [], extra: [rows, cols], solCells: v, givens: List.filled(n * n, -1));
  }

  @override
  (double, double, double, double) margins(PLevel lv) => (0.6, 0.6, 0.8, 0.8);

  @override
  String outside(PLevel lv, PState s, int side, int index) => switch (side) {
        0 || 1 => '${index + 1}',
        2 => '${lv.extra[1][index]}',
        _ => '${lv.extra[0][index]}',
      };
}

// ======================================================================
// Sumplete

/// Bazı sayıları sil (karala): kalanların satır/sütun toplamları kenardaki
/// hedeflere eşit olsun. extra[0]: satır hedefleri, extra[1]: sütun.
class SumDeleteKind extends ShadeKind {
  const SumDeleteKind();
  @override
  String get id => 'sumplete';

  @override
  bool get shadeClues => true;

  @override
  Mark get onMark => Mark.cross;

  @override
  CellLook look(PLevel lv, PState s, int i) {
    final v = s.cells[i];
    return CellLook(mark: v == 1 ? Mark.cross : (v == 2 ? Mark.circle : Mark.none), text: '${lv.clues[i]}', tone: v == 1 ? 0 : 1);
  }

  @override
  bool ok(PLevel lv, PState s, bool complete) {
    final v = s.cells;
    for (var y = 0; y < lv.h; y++) {
      var keep = 0, unk = 0;
      for (var x = 0; x < lv.w; x++) {
        final i = y * lv.w + x;
        if (v[i] == 0) keep += lv.clues[i];
        if (v[i] < 0) unk += lv.clues[i];
      }
      if (keep > lv.extra[0][y] || keep + unk < lv.extra[0][y]) return false;
    }
    for (var x = 0; x < lv.w; x++) {
      var keep = 0, unk = 0;
      for (var y = 0; y < lv.h; y++) {
        final i = y * lv.w + x;
        if (v[i] == 0) keep += lv.clues[i];
        if (v[i] < 0) unk += lv.clues[i];
      }
      if (keep > lv.extra[1][x] || keep + unk < lv.extra[1][x]) return false;
    }
    return true;
  }

  @override
  PLevel make(int difficulty, SeededRandom r) {
    final n = const [3, 4, 4, 5, 5, 6, 6, 7, 7, 8][difficulty - 1];
    final clues = [for (var i = 0; i < n * n; i++) 1 + r.nextInt(difficulty <= 3 ? 9 : 19)];
    final v = [for (var i = 0; i < n * n; i++) r.chance(0.35) ? 1 : 0];
    final rows = [for (var y = 0; y < n; y++) [for (var x = 0; x < n; x++) if (v[y * n + x] == 0) clues[y * n + x]].fold<int>(0, (a, b) => a + b)];
    final cols = [for (var x = 0; x < n; x++) [for (var y = 0; y < n; y++) if (v[y * n + x] == 0) clues[y * n + x]].fold<int>(0, (a, b) => a + b)];
    return PLevel(kind: id, w: n, h: n, clues: clues, extra: [rows, cols], solCells: v, givens: List.filled(n * n, -1));
  }

  @override
  (double, double, double, double) margins(PLevel lv) => (0, 0, 0.8, 0.9);

  @override
  String outside(PLevel lv, PState s, int side, int index) => switch (side) {
        2 => '${lv.extra[1][index]}',
        3 => '${lv.extra[0][index]}',
        _ => '',
      };
}

// ======================================================================
// İkili bulmaca (Binairo/Takuzu)

/// Her hücreye ○ ya da ●: bir satır/sütunda yan yana üç aynı olmaz, her
/// satır/sütunda eşit sayıda; iki satır (ya da sütun) aynı olamaz.
/// Değerler: 1 ○, 2 ●; 0 boş.
class BinaryKind extends PuzzleKind {
  const BinaryKind();
  @override
  String get id => 'binairo';

  @override
  int cellStates(PLevel lv) => 3;

  @override
  bool get zeroUnknown => true;

  @override
  bool tapCell(PLevel lv, int i) => lv.givens.isEmpty || lv.givens[i] < 0;

  @override
  CellLook look(PLevel lv, PState s, int i) {
    final v = s.cells[i];
    final given = lv.givens.isNotEmpty && lv.givens[i] >= 0;
    return CellLook(mark: v == 1 ? Mark.ring : (v == 2 ? Mark.disc : Mark.none), tone: given ? 1 : 0);
  }

  bool _lineOk(List<int> vals, int n) {
    var a = 0, b = 0;
    for (var k = 0; k < vals.length; k++) {
      if (vals[k] == 1) a++;
      if (vals[k] == 2) b++;
      if (k >= 2 && vals[k] > 0 && vals[k] == vals[k - 1] && vals[k] == vals[k - 2]) return false;
    }
    return a <= n ~/ 2 && b <= n ~/ 2;
  }

  @override
  bool ok(PLevel lv, PState s, bool complete) {
    final v = s.cells;
    final n = lv.w;
    final rows = <String>{}, cols = <String>{};
    for (var y = 0; y < n; y++) {
      final line = v.sublist(y * n, y * n + n);
      if (!_lineOk(line, n)) return false;
      if (!line.contains(-1) && !rows.add(line.join())) return false;
    }
    for (var x = 0; x < n; x++) {
      final line = [for (var y = 0; y < n; y++) v[y * n + x]];
      if (!_lineOk(line, n)) return false;
      if (!line.contains(-1) && !cols.add(line.join())) return false;
    }
    return true;
  }

  @override
  PLevel make(int difficulty, SeededRandom r) {
    final n = const [4, 6, 6, 8, 8, 8, 10, 10, 12, 12][difficulty - 1];
    // rastgele geçerli doldurma: genel çözücü ile
    final probe = PLevel(kind: id, w: n, h: n, clues: const [], givens: List.filled(n * n, -1));
    final v = List.filled(n * n, -1);
    var nodes = 0;
    bool go(int i) {
      if (i == n * n) return true;
      final order = r.chance(0.5) ? const [1, 2] : const [2, 1];
      for (final x in order) {
        if (++nodes > 200000) return false;
        v[i] = x;
        if (ok(probe, PState(v, const [], const []), false) && go(i + 1)) return true;
      }
      v[i] = -1;
      return false;
    }

    if (!go(0)) throw StateError('binairo');
    return PLevel(kind: id, w: n, h: n, clues: const [], solCells: List.of(v), givens: List.filled(n * n, -1));
  }

  @override
  double maxGivenRatio(int difficulty) => 0.7;

  @override
  double extraGivenRatio(int difficulty) => difficulty <= 2 ? 0.15 : 0;

  @override
  int reduceTries(int difficulty) => difficulty <= 3 ? 0 : 25;
}
