import 'dart:math' as math;
import 'dart:ui';

import 'package:studio_core/core/rng.dart';

import 'core.dart';
import 'digits.dart';
import 'move1.dart';

// ======================================================================
// Sıralama bulmacaları (su, top, somun, altıgen)

/// Tüp sıralama. Sütun x bir tüp; hücre (h-1-k)*w + x tüpün k. katı
/// (0 dip). Değer: renk (0 boş; somunda eksi değer gizli renk).
/// mode: 0 su (aynı renkli üst grup akar), 1 top (tek top), 2 somun
/// (grup, alttakiler gizli), 3 altıgen (yalnız komşu tüplere grup).
/// aux[0]: seçili tüp.
class SortKind extends MoveKind {
  final int mode;
  const SortKind(this.mode);

  @override
  String get id => const ['su-siralama', 'top-siralama', 'vida-sokme', 'altigen-siralama'][mode];

  @override
  double cellAspect(PLevel lv) => lv.h <= 4 ? 1.6 : (lv.h <= 6 ? 1.35 : 1.15);

  @override
  PState initial(PLevel lv) => PState(List.of(lv.extra[0]), List.filled(lv.linkCount, 0), List.filled(lv.borderCount, 0), [-1]);

  static List<List<int>> tubes(List<int> c, int w, int h) => [
        for (var x = 0; x < w; x++) [for (var k = 0; k < h; k++) c[(h - 1 - k) * w + x]].where((v) => v != 0).toList()
      ];

  static void store(List<int> c, List<List<int>> t, int w, int h) {
    for (var x = 0; x < w; x++) {
      for (var k = 0; k < h; k++) {
        c[(h - 1 - k) * w + x] = k < t[x].length ? t[x][k] : 0;
      }
    }
  }

  /// Altıgen türünde yalnız yan yana tüpler arasında hamle.
  static bool hexAdjacent(int a, int b, int w) => true;

  /// a'dan b'ye hamle; yapılabildiyse yeni tüpler.
  static bool move(List<List<int>> t, int a, int b, int h, int mode, int w) {
    if (a == b || t[a].isEmpty || t[b].length >= h) return false;
    if (mode == 3 && !hexAdjacent(a, b, w)) return false;
    final top = t[a].last.abs();
    if (t[a].last < 0) return false;
    if (t[b].isNotEmpty && t[b].last.abs() != top) return false;
    var count = 1;
    if (mode != 1) {
      while (count < t[a].length && t[a][t[a].length - 1 - count] == top) {
        count++;
      }
    }
    final room = h - t[b].length;
    final moving = math.min(count, room);
    for (var k = 0; k < moving; k++) {
      t[b].add(t[a].removeLast());
    }
    if (t[a].isNotEmpty && t[a].last < 0) t[a][t[a].length - 1] = -t[a].last;
    return true;
  }

  @override
  bool stuck(PLevel lv, PState s) {
    if (solved(lv, s)) return false;
    final t = tubes(s.cells, lv.w, lv.h);
    for (var a = 0; a < t.length; a++) {
      for (var b = 0; b < t.length; b++) {
        if (a == b) continue;
        final copy = [for (final x in t) List.of(x)];
        if (move(copy, a, b, lv.h, mode, lv.w)) return false;
      }
    }
    return true;
  }

  @override
  bool act(PLevel lv, PState s, int i) {
    final x = i % lv.w;
    final sel = s.aux[0];
    if (sel < 0) {
      final t = tubes(s.cells, lv.w, lv.h);
      if (t[x].isEmpty) return false;
      s.aux[0] = x;
      return true;
    }
    if (sel == x) {
      s.aux[0] = -1;
      return true;
    }
    final t = tubes(s.cells, lv.w, lv.h);
    if (move(t, sel, x, lv.h, mode, lv.w)) {
      store(s.cells, t, lv.w, lv.h);
      s.aux[0] = -1;
      return true;
    }
    s.aux[0] = t[x].isEmpty ? -1 : x;
    return true;
  }

  @override
  bool dragMove(PLevel lv, PState s, int from, int to) {
    s.aux[0] = -1;
    if (!act(lv, s, from)) return false;
    return act(lv, s, to);
  }

  static bool sortedTubes(List<List<int>> t, int h) {
    for (final tube in t) {
      if (tube.isEmpty) continue;
      if (tube.length != h || tube.any((v) => v.abs() != tube.first.abs())) return false;
    }
    return true;
  }

  @override
  bool solved(PLevel lv, PState s) => sortedTubes(tubes(s.cells, lv.w, lv.h), lv.h);

  /// Derinlik öncelikli çözücü (tekrarlı durumlar elenir).
  static bool solvable(List<List<int>> start, int h, int mode, int w, {int budget = 60000}) {
    final seen = <String>{};
    var nodes = 0;
    String key(List<List<int>> t) => (t.map((e) => e.join('.')).toList()..sort()).join('|');
    bool go(List<List<int>> t) {
      if (sortedTubes(t, h)) return true;
      if (++nodes > budget) return false;
      if (!seen.add(key(t))) return false;
      for (var a = 0; a < t.length; a++) {
        for (var b = 0; b < t.length; b++) {
          final c = [for (final x in t) List.of(x)];
          if (!move(c, a, b, h, mode, w)) continue;
          // boş tüpe tamamen tek renkli tüpü taşımak anlamsız
          if (t[b].isEmpty && t[a].every((v) => v == t[a].first)) continue;
          if (go(c)) return true;
        }
      }
      return false;
    }

    return go([for (final x in start) List.of(x)]);
  }

  @override
  PLevel make(int difficulty, SeededRandom r) {
    final colors = const [3, 4, 5, 5, 6, 7, 8, 9, 10, 11][difficulty - 1];
    final h = mode == 3 ? 5 : 4;
    final empty = difficulty <= 6 ? 2 : (mode == 3 ? 3 : 2);
    final w = colors + empty;
    for (var attempt = 0; attempt < 200; attempt++) {
      final pool = [for (var c = 1; c <= colors; c++) for (var k = 0; k < h; k++) c];
      r.shuffle(pool);
      final t = [for (var x = 0; x < w; x++) <int>[]];
      for (var k = 0; k < pool.length; k++) {
        t[k ~/ h].add(pool[k]);
      }
      if (sortedTubes(t, h)) continue;
      if (!solvable(t, h, mode, w)) continue;
      if (mode == 2) {
        for (final tube in t) {
          for (var k = 0; k + 1 < tube.length; k++) {
            if (difficulty >= 4 && r.chance(0.5)) tube[k] = -tube[k];
          }
        }
      }
      final cells = List.filled(w * h, 0);
      store(cells, t, w, h);
      final goalT = [for (var c = 1; c <= colors; c++) List.filled(h, c), for (var e = 0; e < empty; e++) <int>[]];
      final goal = List.filled(w * h, 0);
      store(goal, goalT, w, h);
      return PLevel(kind: id, w: w, h: h, clues: const [], extra: [cells], solCells: goal, givens: const []);
    }
    throw StateError('sort');
  }

  @override
  void paintOver(Canvas c, PLevel lv, PState s, Rect Function(int i) cell, double cs) {
    final sel = s.aux.isEmpty ? -1 : s.aux[0];
    for (var x = 0; x < lv.w; x++) {
      final top = cell(x), bot = cell((lv.h - 1) * lv.w + x);
      const dy = 0.0;
      final tubeRect = Rect.fromLTRB(top.left + cs * 0.12, top.top - cs * 0.1 + dy, top.right - cs * 0.12, bot.bottom + dy).shift(Offset(0, x == sel ? -cs * 0.25 : 0));
      final shape = mode == 3
          ? RRect.fromRectAndRadius(tubeRect, Radius.circular(cs * 0.12))
          : RRect.fromRectAndCorners(tubeRect, bottomLeft: Radius.circular(cs * 0.38), bottomRight: Radius.circular(cs * 0.38), topLeft: Radius.circular(cs * 0.08), topRight: Radius.circular(cs * 0.08));
      c.drawRRect(shape, Paint()..color = const Color(0x22FFFFFF));
      if (mode == 2) {
        c.drawLine(tubeRect.topCenter, tubeRect.bottomCenter, Paint()..color = const Color(0xFF8A847C)..strokeWidth = cs * 0.12);
      }
      for (var k = 0; k < lv.h; k++) {
        final v = s.cells[(lv.h - 1 - k) * lv.w + x];
        if (v == 0) continue;
        final r = cell((lv.h - 1 - k) * lv.w + x).shift(Offset(tubeRect.left - top.left - cs * 0.12, x == sel ? -cs * 0.25 : 0)).deflate(cs * 0.14);
        final col = v < 0 ? const Color(0xFF6F6A66) : puzzleColorAt(v);
        switch (mode) {
          case 0:
            c.drawRect(r.inflate(cs * 0.06), Paint()..color = col);
          case 1:
            c.drawCircle(r.center, r.width * 0.55, Paint()..color = col);
          case 3:
            final hex = Path();
            for (var q = 0; q < 6; q++) {
              final a = q * math.pi / 3;
              final p = r.center + Offset(math.cos(a), math.sin(a) * 0.55) * r.width * 0.62;
              q == 0 ? hex.moveTo(p.dx, p.dy) : hex.lineTo(p.dx, p.dy);
            }
            hex.close();
            c.drawPath(hex, Paint()..color = col);
          default:
            c.drawRRect(RRect.fromRectAndRadius(r.inflate(cs * 0.04), Radius.circular(cs * 0.08)), Paint()..color = col);
            c.drawCircle(r.center, cs * 0.1, Paint()..color = const Color(0x66000000));
            if (v < 0) smallText(c, '?', r.center, cs * 0.3, const Color(0xFFFFFFFF));
        }
      }
      c.drawRRect(
          shape,
          Paint()
            ..style = PaintingStyle.stroke
            ..color = x == sel ? const Color(0xFFEDAE49) : const Color(0x99302A26)
            ..strokeWidth = cs * 0.05);
    }
  }
}

// ======================================================================
// Ok kaçışı ve Tıkla-kaldır taşlar

/// Oklar: dokunulan ok, yolu açıksa kendi yönünde ızgaradan çıkar.
/// Hepsini çıkar. [blocks] türünde 1-3 hücrelik bloklar.
/// Hücre: blok kimliği (0 boş); extra[0]: blok yönleri (kimlik-1 sırasıyla),
/// extra[1]: başlangıç hücreleri.
class EscapeKind extends MoveKind {
  final bool blocks;
  const EscapeKind({this.blocks = false});

  @override
  String get id => blocks ? 'tikla-kaldir-taslar' : 'ok-kacisi';

  @override
  PState initial(PLevel lv) => PState(List.of(lv.extra[1]), List.filled(lv.linkCount, 0), List.filled(lv.borderCount, 0));

  static const _d = [(0, -1), (1, 0), (0, 1), (-1, 0)];

  bool canLeave(PLevel lv, List<int> c, int id) {
    final dir = lv.extra[0][id - 1];
    final (dx, dy) = _d[dir];
    for (var i = 0; i < lv.n; i++) {
      if (c[i] != id) continue;
      var x = i % lv.w + dx, y = i ~/ lv.w + dy;
      while (x >= 0 && y >= 0 && x < lv.w && y < lv.h) {
        final v = c[y * lv.w + x];
        if (v != 0 && v != id) return false;
        x += dx;
        y += dy;
      }
    }
    return true;
  }

  @override
  bool act(PLevel lv, PState s, int i) {
    final id = s.cells[i];
    if (id == 0 || !canLeave(lv, s.cells, id)) return false;
    for (var k = 0; k < lv.n; k++) {
      if (s.cells[k] == id) s.cells[k] = 0;
    }
    return true;
  }

  @override
  bool solved(PLevel lv, PState s) => s.cells.every((v) => v == 0);

  @override
  PLevel make(int difficulty, SeededRandom r) {
    final n = const [4, 5, 5, 6, 6, 7, 7, 8, 9, 10][difficulty - 1];
    final c = List.filled(n * n, 0);
    final dirs = <int>[];
    final fill = 0.55 + difficulty * 0.03;
    for (var t = 0; t < n * n * 6 && c.where((v) => v != 0).length < n * n * fill; t++) {
      final start = r.nextInt(n * n);
      if (c[start] != 0) continue;
      final dir = r.nextInt(4);
      final (dx, dy) = _d[dir];
      // blok: yön ekseninde 1-3 hücre (geriye doğru)
      final len = blocks ? 1 + r.nextInt(3) : 1;
      final cells = <int>[];
      var x = start % n, y = start ~/ n;
      for (var k = 0; k < len; k++) {
        if (x < 0 || y < 0 || x >= n || y >= n || c[y * n + x] != 0) break;
        cells.add(y * n + x);
        x -= dx;
        y -= dy;
      }
      if (cells.isEmpty) continue;
      // önden kenara kadar yol boş olmalı (sonra çıkacak bloklar burada)
      var fx = start % n + dx, fy = start ~/ n + dy;
      var clear = true;
      while (fx >= 0 && fy >= 0 && fx < n && fy < n) {
        if (c[fy * n + fx] != 0) {
          clear = false;
          break;
        }
        fx += dx;
        fy += dy;
      }
      if (!clear) continue;
      dirs.add(dir);
      for (final q in cells) {
        c[q] = dirs.length;
      }
    }
    return PLevel(kind: id, w: n, h: n, clues: const [], extra: [dirs, c], solCells: List.filled(n * n, 0), givens: const []);
  }

  @override
  void paintOver(Canvas c, PLevel lv, PState s, Rect Function(int i) cell, double cs) {
    for (var i = 0; i < lv.n; i++) {
      final id = s.cells[i];
      if (id == 0) {
        c.drawCircle(cell(i).center, cs * 0.05, Paint()..color = const Color(0x33302A26));
        continue;
      }
      final dir = lv.extra[0][id - 1];
      final r = cell(i);
      final col = blocks ? expColor(3 + id % 9) : const Color(0xFF3A3548);
      if (blocks) c.drawRRect(RRect.fromRectAndRadius(r.deflate(cs * 0.06), Radius.circular(cs * 0.14)), Paint()..color = col);
      final u = Offset(_d[dir].$1.toDouble(), _d[dir].$2.toDouble());
      final nrm = Offset(-u.dy, u.dx);
      final p = Paint()
        ..color = blocks ? const Color(0xFFFFFFFF) : col
        ..strokeWidth = cs * (blocks ? 0.07 : 0.1)
        ..strokeCap = StrokeCap.round;
      final o = r.center;
      c.drawLine(o - u * cs * 0.28, o + u * cs * 0.28, p);
      c.drawLine(o + u * cs * 0.3, o + u * cs * 0.08 + nrm * cs * 0.16, p);
      c.drawLine(o + u * cs * 0.3, o + u * cs * 0.08 - nrm * cs * 0.16, p);
    }
  }

  @override
  String status(PLevel lv, PState s, String lang) => '◆ ${s.cells.toSet().where((v) => v != 0).length}';
}

// ======================================================================
// Otobüs/yolcu sıkışması

/// Araçlara dokun: yolu açıksa otoparka (en çok 4 yer) çıkar. Sıradaki
/// yolcular otoparktaki aynı renkli araca biner; dolan (3 yolcu) araç
/// ayrılır. Otopark dolar ve binen olmazsa kaybedersin.
/// Hücre: araç kimliği; extra[0]: yönler, extra[1]: başlangıç, extra[2]:
/// araç renkleri, extra[3]: yolcu sırası. aux: [sıra konumu, 4 yer araç
/// kimliği, 4 yer yolcu sayısı].
class BusKind extends MoveKind {
  const BusKind();
  @override
  String get id => 'otobus-yolcu-sikismasi';

  static const slots = 4, seats = 3;

  @override
  PState initial(PLevel lv) => PState(List.of(lv.extra[1]), List.filled(lv.linkCount, 0), List.filled(lv.borderCount, 0), [0, ...List.filled(slots * 2, 0)]);

  void _board(PLevel lv, PState s) {
    final q = lv.extra[3];
    var moved = true;
    while (moved && s.aux[0] < q.length) {
      moved = false;
      final col = q[s.aux[0]];
      for (var k = 0; k < slots; k++) {
        final car = s.aux[1 + k];
        if (car > 0 && lv.extra[2][car - 1] == col && s.aux[1 + slots + k] < seats) {
          s.aux[1 + slots + k]++;
          s.aux[0]++;
          if (s.aux[1 + slots + k] == seats) {
            s.aux[1 + k] = 0;
            s.aux[1 + slots + k] = 0;
          }
          moved = true;
          break;
        }
      }
    }
  }

  @override
  bool act(PLevel lv, PState s, int i) {
    final id = s.cells[i];
    if (id == 0) return false;
    const esc = EscapeKind();
    final probe = PLevel(kind: 'x', w: lv.w, h: lv.h, clues: const [], extra: [lv.extra[0]], givens: const []);
    if (!esc.canLeave(probe, s.cells, id)) return false;
    final free = [for (var k = 0; k < slots; k++) if (s.aux[1 + k] == 0) k];
    if (free.isEmpty) return false;
    for (var k = 0; k < lv.n; k++) {
      if (s.cells[k] == id) s.cells[k] = 0;
    }
    s.aux[1 + free.first] = id;
    _board(lv, s);
    return true;
  }

  @override
  bool solved(PLevel lv, PState s) => s.aux.isNotEmpty && s.aux[0] >= lv.extra[3].length;

  @override
  bool failed(PLevel lv, PState s) {
    if (solved(lv, s)) return false;
    final full = [for (var k = 0; k < slots; k++) s.aux[1 + k]].every((v) => v > 0);
    return full;
  }

  @override
  bool ok(PLevel lv, PState s, bool complete) => true;

  @override
  PLevel make(int difficulty, SeededRandom r) {
    final base = const EscapeKind().make(math.min(10, difficulty + 1), r);
    final n = base.w;
    final dirs = base.extra[0];
    final cars = dirs.length;
    final colorsN = math.min(6, 3 + difficulty ~/ 2);
    final colors = [for (var k = 0; k < cars; k++) 1 + r.nextInt(colorsN)];
    // çıkış sırası: üretim sırasının tersi her zaman mümkün
    final order = [for (var k = cars; k >= 1; k--) k];
    final queue = <int>[];
    for (final car in order) {
      queue.addAll(List.filled(seats, colors[car - 1]));
    }
    // küçük karıştırma: komşu grupları ara sıra değiştir (hâlâ çözülebilir: 4 yer)
    for (var k = 0; k + seats * 2 <= queue.length; k += seats) {
      if (r.chance(0.3)) {
        final a = queue.sublist(k, k + seats), b = queue.sublist(k + seats, k + seats * 2);
        queue.setAll(k, [a[0], b[0], a[1]]);
        queue.setAll(k + seats, [b[1], a[2], b[2]]);
      }
    }
    return PLevel(kind: id, w: n, h: n, clues: const [], extra: [dirs, base.extra[1], colors, queue], solCells: const [], givens: const []);
  }

  @override
  (double, double, double, double) margins(PLevel lv) => (1.6, 0, 0, 0);

  @override
  void paintOver(Canvas c, PLevel lv, PState s, Rect Function(int i) cell, double cs) {
    const esc = EscapeKind();
    final probe = PLevel(kind: 'x', w: lv.w, h: lv.h, clues: const [], extra: [lv.extra[0]], givens: const []);
    for (var i = 0; i < lv.n; i++) {
      final id = s.cells[i];
      if (id == 0) continue;
      final r = cell(i).deflate(cs * 0.08);
      c.drawRRect(RRect.fromRectAndRadius(r, Radius.circular(cs * 0.16)), Paint()..color = puzzleColorAt(lv.extra[2][id - 1]));
      final dir = lv.extra[0][id - 1];
      final u = Offset(EscapeKind._d[dir].$1.toDouble(), EscapeKind._d[dir].$2.toDouble());
      c.drawCircle(r.center + u * cs * 0.22, cs * 0.08, Paint()..color = esc.canLeave(probe, s.cells, id) ? const Color(0xFFFFFFFF) : const Color(0x66FFFFFF));
    }
    // otopark ve yolcular
    final top = cell(0).topLeft;
    for (var k = 0; k < slots; k++) {
      final r = Rect.fromLTWH(top.dx + k * cs * 1.1, top.dy - cs * 1.5, cs, cs * 0.7);
      c.drawRRect(RRect.fromRectAndRadius(r, Radius.circular(cs * 0.12)), Paint()..color = const Color(0x33302A26));
      final car = s.aux.isEmpty ? 0 : s.aux[1 + k];
      if (car > 0) {
        c.drawRRect(RRect.fromRectAndRadius(r.deflate(cs * 0.05), Radius.circular(cs * 0.12)), Paint()..color = puzzleColorAt(lv.extra[2][car - 1]));
        smallText(c, '${s.aux[1 + slots + k]}/$seats', r.center, cs * 0.24, const Color(0xFFFFFFFF));
      }
    }
    final q = lv.extra[3];
    final pos = s.aux.isEmpty ? 0 : s.aux[0];
    for (var k = 0; k < 8 && pos + k < q.length; k++) {
      final o = Offset(top.dx + slots * cs * 1.1 + cs * 0.3 + k * cs * 0.32, top.dy - cs * 1.15);
      c.drawCircle(o, cs * 0.13, Paint()..color = puzzleColorAt(q[pos + k]));
    }
  }

  @override
  String status(PLevel lv, PState s, String lang) => '👥 ${lv.extra[3].length - (s.aux.isEmpty ? 0 : s.aux[0])}';
}

// ======================================================================
// Araba çıkarma ve Kayan bloklar

/// Blokları kendi eksenlerinde (kayan bloklarda her yöne) kaydır; ana
/// bloğu çıkışa getir. Hücre: blok kimliği (1 ana blok).
/// extra[0]: blok başına [genişlik, yükseklik, eksen(0 yatay,1 dikey,2 serbest)].
/// extra[1]: başlangıç. extra[2]: [çıkış hücresi (ana bloğun sol üstü)].
class SlideBlockKind extends MoveKind {
  final bool klotski;
  const SlideBlockKind({this.klotski = false});

  @override
  String get id => klotski ? 'kayan-bloklar' : 'araba-cikarma';

  @override
  PState initial(PLevel lv) => PState(List.of(lv.extra[1]), List.filled(lv.linkCount, 0), List.filled(lv.borderCount, 0));

  static int anchor(List<int> c, int id) => c.indexOf(id);

  /// Bloğu (dx,dy) bir adım kaydırabilir mi; kaydırır.
  static bool step(List<int> c, int w, int h, List<int> spec, int id, int dx, int dy) {
    final a = anchor(c, id);
    if (a < 0) return false;
    final bw = spec[(id - 1) * 3], bh = spec[(id - 1) * 3 + 1];
    final ax = a % w + dx, ay = a ~/ w + dy;
    if (ax < 0 || ay < 0 || ax + bw > w || ay + bh > h) return false;
    for (var y = ay; y < ay + bh; y++) {
      for (var x = ax; x < ax + bw; x++) {
        final v = c[y * w + x];
        if (v != 0 && v != id) return false;
      }
    }
    for (var i = 0; i < c.length; i++) {
      if (c[i] == id) c[i] = 0;
    }
    for (var y = ay; y < ay + bh; y++) {
      for (var x = ax; x < ax + bw; x++) {
        c[y * w + x] = id;
      }
    }
    return true;
  }

  @override
  bool dragMove(PLevel lv, PState s, int from, int to) {
    final id = s.cells[from];
    if (id == 0) return false;
    final axis = lv.extra[0][(id - 1) * 3 + 2];
    var dx = to % lv.w - from % lv.w, dy = to ~/ lv.w - from ~/ lv.w;
    if (axis == 0) dy = 0;
    if (axis == 1) dx = 0;
    if (axis == 2) {
      if (dx.abs() >= dy.abs()) {
        dy = 0;
      } else {
        dx = 0;
      }
    }
    var moved = false;
    for (var k = 0; k < dx.abs() + dy.abs(); k++) {
      if (!step(s.cells, lv.w, lv.h, lv.extra[0], id, dx.sign, dy.sign)) break;
      moved = true;
    }
    return moved;
  }

  @override
  bool solved(PLevel lv, PState s) => anchor(s.cells, 1) == lv.extra[2][0];

  @override
  bool ok(PLevel lv, PState s, bool complete) => true;

  /// Genişlik öncelikli en kısa çözüm (hamle sayısı; yoksa -1).
  static int bfs(List<int> start, int w, int h, List<int> spec, int exit, {int limit = 15000}) {
    final seen = <String>{start.join(',')};
    var frontier = [start];
    final ids = start.where((v) => v > 0).toSet().toList();
    for (var depth = 0; depth < 200; depth++) {
      final next = <List<int>>[];
      for (final c in frontier) {
        if (anchor(c, 1) == exit) return depth;
        for (final id in ids) {
          for (final (dx, dy) in const [(1, 0), (-1, 0), (0, 1), (0, -1)]) {
            final axis = spec[(id - 1) * 3 + 2];
            if ((axis == 0 && dy != 0) || (axis == 1 && dx != 0)) continue;
            final cc = List.of(c);
            // aynı yönde birden çok adım tek hamle
            var any = false;
            while (step(cc, w, h, spec, id, dx, dy)) {
              any = true;
              if (seen.add(cc.join(','))) next.add(List.of(cc));
              if (seen.length > limit) return -1;
            }
            if (!any) continue;
          }
        }
      }
      if (next.isEmpty) return -1;
      frontier = next;
    }
    return -1;
  }

  @override
  PLevel make(int difficulty, SeededRandom r) {
    final w = klotski ? 4 : 6, h = klotski ? 5 : 6;
    final want = klotski ? const [3, 5, 8, 12, 16, 20, 25, 30, 35, 40][difficulty - 1] : const [2, 4, 6, 8, 10, 13, 16, 20, 24, 28][difficulty - 1];
    List<int>? best;
    var bestD = -1, bestSpec = <int>[], exit = 0;
    for (var attempt = 0; attempt < (klotski ? 10 : 30); attempt++) {
      final c = List.filled(w * h, 0);
      final spec = <int>[];
      bool place(int bw, int bh, int axis, int x, int y) {
        if (x < 0 || y < 0 || x + bw > w || y + bh > h) return false;
        for (var yy = y; yy < y + bh; yy++) {
          for (var xx = x; xx < x + bw; xx++) {
            if (c[yy * w + xx] != 0) return false;
          }
        }
        spec.addAll([bw, bh, axis]);
        final id = spec.length ~/ 3;
        for (var yy = y; yy < y + bh; yy++) {
          for (var xx = x; xx < x + bw; xx++) {
            c[yy * w + xx] = id;
          }
        }
        return true;
      }

      if (klotski) {
        place(2, 2, 2, r.nextInt(3), r.nextInt(2));
        exit = (h - 2) * w + 1;
        for (var t = 0; t < 200 && c.where((v) => v == 0).length > 2; t++) {
          final kind = r.nextInt(3);
          final (bw, bh) = kind == 0 ? (1, 1) : (kind == 1 ? (1, 2) : (2, 1));
          place(bw, bh, 2, r.nextInt(w), r.nextInt(h));
        }
      } else {
        place(2, 1, 0, r.nextInt(3), 2);
        exit = 2 * w + 4;
        final count = 6 + r.nextInt(5) + difficulty ~/ 2;
        for (var t = 0; t < 300 && spec.length ~/ 3 < count; t++) {
          final len = r.chance(0.7) ? 2 : 3;
          final hor = r.chance(0.5);
          if (hor && r.nextInt(6) == 2) continue; // ana sırada yatay araç yok
          place(hor ? len : 1, hor ? 1 : len, hor ? 0 : 1, r.nextInt(w), r.nextInt(h));
        }
      }
      final d = bfs(c, w, h, spec, exit);
      if (d > bestD) {
        bestD = d;
        best = List.of(c);
        bestSpec = List.of(spec);
      }
      if (bestD >= want) break;
    }
    if (best == null || bestD <= 0) return make(math.max(1, difficulty - 1), r);
    return PLevel(kind: id, w: w, h: h, clues: const [], extra: [bestSpec, best, [exit]], solCells: const [], givens: const [], param: bestD);
  }

  @override
  void paintOver(Canvas c, PLevel lv, PState s, Rect Function(int i) cell, double cs) {
    final seen = <int>{};
    for (var i = 0; i < lv.n; i++) {
      final id = s.cells[i];
      if (id == 0 || !seen.add(id)) continue;
      final bw = lv.extra[0][(id - 1) * 3], bh = lv.extra[0][(id - 1) * 3 + 1];
      final r = cell(i).expandToInclude(cell(i + (bh - 1) * lv.w + bw - 1)).deflate(cs * 0.06);
      final col = id == 1 ? const Color(0xFFD1495B) : expColor(7 + id % 6);
      c.drawRRect(RRect.fromRectAndRadius(r, Radius.circular(cs * 0.18)), Paint()..color = col);
      if (!klotski) {
        // tekerlek izleri
        final p = Paint()..color = const Color(0x55000000);
        c.drawRRect(RRect.fromRectAndRadius(r.deflate(cs * 0.18), Radius.circular(cs * 0.1)), p);
      }
    }
    // çıkış işareti
    final ex = lv.extra[2][0];
    final er = cell(ex);
    if (klotski) {
      c.drawLine(er.bottomLeft + Offset(0, cs * 1.0 + cs * 0.06), er.bottomLeft + Offset(cs * 2, cs * 1.0 + cs * 0.06),
          Paint()..color = const Color(0xFFD1495B)..strokeWidth = cs * 0.1);
    } else {
      final r = cell(ex + 1);
      c.drawLine(r.topRight + Offset(cs * 0.08, 0), r.bottomRight + Offset(cs * 0.08, 0), Paint()..color = const Color(0xFFD1495B)..strokeWidth = cs * 0.1);
    }
  }

  @override
  bool get gridLines => true;

  @override
  String status(PLevel lv, PState s, String lang) => '★ ${lv.param}';
}

// ======================================================================
// Kutu itme (depo)

/// Kendini kaydırarak hareket ettir; kutuları iterek hedeflere yerleştir.
/// Hücre: 0 zemin, 1 duvar, 2 kutu. extra[0]: hedefler, extra[1]:
/// başlangıç, extra[2]: [oyuncu]. aux[0]: oyuncu.
class BoxPushKind extends MoveKind {
  const BoxPushKind();
  @override
  String get id => 'sokoban';

  @override
  PState initial(PLevel lv) => PState(List.of(lv.extra[1]), List.filled(lv.linkCount, 0), List.filled(lv.borderCount, 0), [lv.extra[2][0]]);

  static const _d = [(0, -1), (1, 0), (0, 1), (-1, 0)];

  bool _move(PLevel lv, PState s, int dir) {
    final p = s.aux[0];
    final (dx, dy) = _d[dir];
    final x = p % lv.w + dx, y = p ~/ lv.w + dy;
    if (x < 0 || y < 0 || x >= lv.w || y >= lv.h) return false;
    final t = y * lv.w + x;
    if (s.cells[t] == 1) return false;
    if (s.cells[t] == 2) {
      final x2 = x + dx, y2 = y + dy;
      if (x2 < 0 || y2 < 0 || x2 >= lv.w || y2 >= lv.h) return false;
      final t2 = y2 * lv.w + x2;
      if (s.cells[t2] != 0) return false;
      s.cells[t2] = 2;
      s.cells[t] = 0;
    }
    s.aux[0] = t;
    return true;
  }

  @override
  bool swipe(PLevel lv, PState s, int dir) => _move(lv, s, dir);

  @override
  bool act(PLevel lv, PState s, int i) {
    final p = s.aux[0];
    final dx = i % lv.w - p % lv.w, dy = i ~/ lv.w - p ~/ lv.w;
    if (dx.abs() + dy.abs() != 1) return false;
    return _move(lv, s, dx == 1 ? 1 : (dx == -1 ? 3 : (dy == 1 ? 2 : 0)));
  }

  @override
  bool solved(PLevel lv, PState s) {
    for (var i = 0; i < lv.n; i++) {
      if (lv.extra[0][i] == 1 && s.cells[i] != 2) return false;
    }
    return true;
  }

  @override
  bool ok(PLevel lv, PState s, bool complete) => true;

  @override
  PLevel make(int difficulty, SeededRandom r) {
    final n = const [6, 6, 7, 7, 8, 8, 9, 9, 10, 10][difficulty - 1];
    final boxes = const [1, 2, 2, 3, 3, 3, 4, 4, 5, 5][difficulty - 1];
    for (var attempt = 0; attempt < 300; attempt++) {
      // oda: kenarlar duvar, içerde rastgele duvar parçaları
      final c = List.filled(n * n, 0);
      for (var i = 0; i < n * n; i++) {
        final x = i % n, y = i ~/ n;
        if (x == 0 || y == 0 || x == n - 1 || y == n - 1 || r.chance(0.12)) c[i] = 1;
      }
      final floor = [for (var i = 0; i < n * n; i++) if (c[i] == 0) i];
      final probe = PLevel(kind: id, w: n, h: n, clues: const [], givens: const []);
      // zemin bağlı olmalı
      if (components(probe, (i) => c[i] == 0).length != 1 || floor.length < boxes * 4 + 4) continue;
      final goals = List.filled(n * n, 0);
      final fs = List.of(floor);
      r.shuffle(fs);
      final boxPos = fs.take(boxes).toList();
      for (final b in boxPos) {
        goals[b] = 1;
        c[b] = 2;
      }
      var player = fs.firstWhere((i) => c[i] == 0, orElse: () => -1);
      if (player < 0) continue;
      // geriye çekme: oyuncu kutuyu kendine doğru çeker
      final pulls = 10 + difficulty * 8;
      var did = 0;
      for (var t = 0; t < pulls * 20 && did < pulls; t++) {
        // oyuncuyu rastgele gezdir
        final dir = r.nextInt(4);
        final (dx, dy) = _d[dir];
        final px = player % n, py = player ~/ n;
        final nx = px + dx, ny = py + dy;
        final np = ny * n + nx;
        if (c[np] != 0) continue;
        // ardındaki kutuyu çek
        final bx = px - dx, by = py - dy;
        final bp = by * n + bx;
        if (r.chance(0.6) && c[bp] == 2) {
          c[bp] = 0;
          c[player] = 2;
          did++;
        }
        player = np;
      }
      if (did < boxes) continue;
      final st = PState(c, const [], const [], [player]);
      final lv = PLevel(kind: id, w: n, h: n, clues: const [], extra: [goals, c, [player]], solCells: const [], givens: const []);
      if (solved(lv, st)) continue;
      return lv;
    }
    throw StateError('sokoban');
  }

  @override
  void paintOver(Canvas c, PLevel lv, PState s, Rect Function(int i) cell, double cs) {
    for (var i = 0; i < lv.n; i++) {
      final r = cell(i);
      final v = s.cells[i];
      if (v == 1) {
        paintWall(c, r);
        continue;
      }
      c.drawRect(r, Paint()..color = const Color(0xFFEFE3CF));
      if (lv.extra[0][i] == 1) c.drawCircle(r.center, cs * 0.2, Paint()..color = const Color(0x8866A182));
      if (v == 2) {
        final on = lv.extra[0][i] == 1;
        c.drawRRect(RRect.fromRectAndRadius(r.deflate(cs * 0.1), Radius.circular(cs * 0.1)), Paint()..color = on ? const Color(0xFF66A182) : const Color(0xFFB5651D));
        c.drawLine(r.deflate(cs * 0.2).topLeft, r.deflate(cs * 0.2).bottomRight, Paint()..color = const Color(0x55000000)..strokeWidth = cs * 0.05);
        c.drawLine(r.deflate(cs * 0.2).topRight, r.deflate(cs * 0.2).bottomLeft, Paint()..color = const Color(0x55000000)..strokeWidth = cs * 0.05);
      }
    }
    if (s.aux.isNotEmpty) paintHero(c, cell(s.aux[0]));
  }
}

void paintWall(Canvas c, Rect r) {
  c.drawRect(r, Paint()..color = const Color(0xFF5A4A3F));
  final s = r.width;
  final p = Paint()
    ..color = const Color(0xFF473A31)
    ..strokeWidth = math.max(1, s * 0.03);
  c.drawLine(r.centerLeft, r.centerRight, p);
  c.drawLine(Offset(r.center.dx, r.top), Offset(r.center.dx, r.center.dy), p);
  c.drawLine(Offset(r.left + s * 0.25, r.center.dy), Offset(r.left + s * 0.25, r.bottom), p);
  c.drawLine(Offset(r.left + s * 0.75, r.center.dy), Offset(r.left + s * 0.75, r.bottom), p);
}

/// Oyuncu figürü: yuvarlak gövde ve göz.
void paintHero(Canvas c, Rect r) {
  final s = r.width;
  c.drawCircle(r.center, s * 0.32, Paint()..color = const Color(0xFF3F88C5));
  c.drawCircle(r.center + Offset(s * 0.08, -s * 0.06), s * 0.07, Paint()..color = const Color(0xFFFFFFFF));
}

// ======================================================================
// Buz kaydırma ve Atalet

/// Buzda kayarsın: bir yöne gidince duvara ya da kayaya çarpana kadar
/// durmazsın. [inertia] türünde duraklarda (çukur) da durursun, mücevherleri
/// topla, mayınlardan kaç. Hücre: 0 buz, 1 kaya, 2 çıkış, 3 durak,
/// 4 mücevher, 5 mayın. aux[0]: oyuncu, aux[1]: patlama.
class IceKind extends MoveKind {
  final bool inertia;
  const IceKind({this.inertia = false});

  @override
  String get id => inertia ? 'atalet' : 'buz-kaydirma';

  @override
  PState initial(PLevel lv) => PState(List.of(lv.extra[0]), List.filled(lv.linkCount, 0), List.filled(lv.borderCount, 0), [lv.extra[1][0], 0]);

  static const _d = [(0, -1), (1, 0), (0, 1), (-1, 0)];

  /// Kayma sonucu (yeni konum, toplanan mücevherler, patlama).
  static (int, List<int>, bool) slide(List<int> c, int w, int h, int p, int dir, bool inertia) {
    final (dx, dy) = _d[dir];
    var x = p % w, y = p ~/ w;
    final got = <int>[];
    while (true) {
      final nx = x + dx, ny = y + dy;
      if (nx < 0 || ny < 0 || nx >= w || ny >= h) break;
      final v = c[ny * w + nx];
      if (v == 1) break;
      x = nx;
      y = ny;
      if (v == 5) return (y * w + x, got, true);
      if (v == 4) got.add(y * w + x);
      if (v == 2 && !inertia) break;
      if (v == 3) break;
    }
    return (y * w + x, got, false);
  }

  @override
  bool swipe(PLevel lv, PState s, int dir) {
    final (np, got, boom) = slide(s.cells, lv.w, lv.h, s.aux[0], dir, inertia);
    if (np == s.aux[0]) return false;
    for (final g in got) {
      s.cells[g] = 0;
    }
    s.aux[0] = np;
    if (boom) s.aux[1] = 1;
    return true;
  }

  @override
  bool act(PLevel lv, PState s, int i) {
    final p = s.aux[0];
    final dx = i % lv.w - p % lv.w, dy = i ~/ lv.w - p ~/ lv.w;
    if (dx != 0 && dy != 0 || (dx == 0 && dy == 0)) return false;
    return swipe(lv, s, dx > 0 ? 1 : (dx < 0 ? 3 : (dy > 0 ? 2 : 0)));
  }

  @override
  bool solved(PLevel lv, PState s) {
    if (s.aux.length > 1 && s.aux[1] == 1) return false;
    if (inertia) return !s.cells.contains(4);
    return s.aux.isNotEmpty && s.cells[s.aux[0]] == 2;
  }

  @override
  bool failed(PLevel lv, PState s) => s.aux.length > 1 && s.aux[1] == 1;

  @override
  bool ok(PLevel lv, PState s, bool complete) => true;

  /// En kısa çözüm uzunluğu (yoksa -1).
  static int shortest(List<int> c, int w, int h, int start, bool inertia) {
    final gems = [for (var i = 0; i < c.length; i++) if (c[i] == 4) i];
    final gi = {for (var k = 0; k < gems.length; k++) gems[k]: k};
    final full = (1 << gems.length) - 1;
    final seen = <int>{start * 4096};
    var frontier = [(start, 0)];
    for (var depth = 0; depth < 80; depth++) {
      final next = <(int, int)>[];
      for (final (p, mask) in frontier) {
        if (inertia ? mask == full : c[p] == 2) return depth;
        for (var dir = 0; dir < 4; dir++) {
          final cc = List.of(c);
          for (var k = 0; k < gems.length; k++) {
            if (mask & (1 << k) != 0) cc[gems[k]] = 0;
          }
          final (np, got, boom) = slide(cc, w, h, p, dir, inertia);
          if (boom || np == p) continue;
          var m = mask;
          for (final g in got) {
            m |= 1 << gi[g]!;
          }
          if (seen.add(np * 4096 + m)) next.add((np, m));
        }
      }
      if (next.isEmpty) return -1;
      frontier = next;
    }
    return -1;
  }

  @override
  PLevel make(int difficulty, SeededRandom r) {
    final n = const [6, 7, 7, 8, 8, 9, 9, 10, 11, 12][difficulty - 1];
    final want = 3 + difficulty;
    List<int>? best;
    var bestStart = 0, bestD = -1;
    for (var attempt = 0; attempt < 80; attempt++) {
      final c = [for (var i = 0; i < n * n; i++) r.chance(0.16) ? 1 : 0];
      final free = [for (var i = 0; i < n * n; i++) if (c[i] == 0) i];
      if (free.length < 6) continue;
      r.shuffle(free);
      final start = free[0];
      if (inertia) {
        for (final i in free.skip(1).take(3 + difficulty ~/ 2)) {
          c[i] = 4;
        }
        for (final i in free.skip(8).take(n)) {
          c[i] = 3;
        }
        for (final i in free.skip(8 + n).take(difficulty ~/ 2)) {
          c[i] = 5;
        }
      } else {
        c[free[1]] = 2;
      }
      final d = shortest(c, n, n, start, inertia);
      if (d > bestD) {
        bestD = d;
        best = List.of(c);
        bestStart = start;
      }
      if (bestD >= want) break;
    }
    if (best == null || bestD <= 0) return make(math.max(1, difficulty - 1), r);
    return PLevel(kind: id, w: n, h: n, clues: const [], extra: [best, [bestStart]], solCells: const [], givens: const [], param: bestD);
  }

  @override
  void paintOver(Canvas c, PLevel lv, PState s, Rect Function(int i) cell, double cs) {
    for (var i = 0; i < lv.n; i++) {
      final r = cell(i);
      c.drawRect(r, Paint()..color = const Color(0xFFD9ECF2));
      switch (s.cells[i]) {
        case 1:
          c.drawRRect(RRect.fromRectAndRadius(r.deflate(cs * 0.06), Radius.circular(cs * 0.25)), Paint()..color = const Color(0xFF7D8B91));
        case 2:
          c.drawRect(r.deflate(cs * 0.12), Paint()..color = const Color(0xFF66A182));
        case 3:
          c.drawCircle(r.center, cs * 0.3, Paint()..color = const Color(0x557D8B91));
        case 4:
          final p = Path()
            ..moveTo(r.center.dx, r.center.dy - cs * 0.3)
            ..lineTo(r.center.dx + cs * 0.25, r.center.dy)
            ..lineTo(r.center.dx, r.center.dy + cs * 0.3)
            ..lineTo(r.center.dx - cs * 0.25, r.center.dy)
            ..close();
          c.drawPath(p, Paint()..color = const Color(0xFF8E6C8A));
        case 5:
          c.drawCircle(r.center, cs * 0.26, Paint()..color = const Color(0xFF2B2B33));
          c.drawCircle(r.center - Offset(cs * 0.08, cs * 0.08), cs * 0.06, Paint()..color = const Color(0xFFD1495B));
      }
    }
    if (s.aux.isNotEmpty) paintHero(c, cell(s.aux[0]));
  }

  @override
  String status(PLevel lv, PState s, String lang) => inertia ? '◆ ${s.cells.where((v) => v == 4).length}' : '★ ${lv.param}';
}

// ======================================================================
// Labirent

/// Labirentte girişten çıkışa yol çiz (parmağını sürükle). Duvarlar
/// kenarlardır. extra[0]: kenar başına duvar (1). aux[0]: oyuncu.
class MazeKind extends MoveKind {
  const MazeKind();
  @override
  String get id => 'labirent';

  @override
  bool get pathInput => true;

  @override
  PState initial(PLevel lv) => PState(List.filled(lv.n, 0), List.filled(lv.linkCount, 0), List.filled(lv.borderCount, 0), [0]);

  @override
  bool pathMove(PLevel lv, PState s, List<int> path) {
    if (path.first != s.aux[0]) return false;
    for (var k = 1; k < path.length; k++) {
      if (lv.extra[0][lv.edgeBetween(path[k - 1], path[k])] == 1) return false;
    }
    for (final p in path) {
      s.cells[p] = 1;
    }
    s.aux[0] = path.last;
    return true;
  }

  @override
  bool swipe(PLevel lv, PState s, int dir) {
    // koridor boyunca ilk kavşağa kadar ilerle
    var p = s.aux[0];
    var moved = false;
    var d = dir;
    for (var k = 0; k < lv.n; k++) {
      final x = p % lv.w, y = p ~/ lv.w;
      final nx = x + const [0, 1, 0, -1][d], ny = y + const [-1, 0, 1, 0][d];
      if (nx < 0 || ny < 0 || nx >= lv.w || ny >= lv.h) break;
      final np = ny * lv.w + nx;
      if (lv.extra[0][lv.edgeBetween(p, np)] == 1) break;
      p = np;
      s.cells[p] = 1;
      moved = true;
      if (p == lv.n - 1) break;
      final exits = [for (var e = 0; e < 4; e++) if (e != (d + 2) % 4 && _open(lv, p, e)) e];
      if (exits.length != 1) break;
      d = exits.first;
    }
    s.aux[0] = p;
    return moved;
  }

  bool _open(PLevel lv, int p, int dir) {
    final x = p % lv.w + const [0, 1, 0, -1][dir], y = p ~/ lv.w + const [-1, 0, 1, 0][dir];
    if (x < 0 || y < 0 || x >= lv.w || y >= lv.h) return false;
    return lv.extra[0][lv.edgeBetween(p, y * lv.w + x)] == 0;
  }

  @override
  bool solved(PLevel lv, PState s) => s.aux.isNotEmpty && s.aux[0] == lv.n - 1;

  @override
  bool ok(PLevel lv, PState s, bool complete) => true;

  @override
  PLevel make(int difficulty, SeededRandom r) {
    final n = const [6, 8, 10, 12, 14, 16, 18, 20, 22, 24][difficulty - 1];
    final probe = PLevel(kind: id, w: n, h: n, clues: const [], givens: const []);
    final walls = List.filled(probe.borderCount, 1);
    final seen = List.filled(n * n, false)..[0] = true;
    final stack = [0];
    while (stack.isNotEmpty) {
      final c = stack.last;
      final opts = probe.neighbors(c).where((nb) => !seen[nb]).toList();
      if (opts.isEmpty) {
        stack.removeLast();
        continue;
      }
      final nb = opts[r.nextInt(opts.length)];
      walls[probe.edgeBetween(c, nb)] = 0;
      seen[nb] = true;
      stack.add(nb);
    }
    // birkaç ek geçit (döngüler)
    for (var k = 0; k < n ~/ 2; k++) {
      final c = r.nextInt(n * n);
      final nbs = probe.neighbors(c);
      walls[probe.edgeBetween(c, nbs[r.nextInt(nbs.length)])] = 0;
    }
    return PLevel(kind: id, w: n, h: n, clues: const [], extra: [walls], solCells: const [], givens: const []);
  }

  @override
  void paintOver(Canvas c, PLevel lv, PState s, Rect Function(int i) cell, double cs) {
    for (var i = 0; i < lv.n; i++) {
      if (s.cells[i] == 1) c.drawRect(cell(i).deflate(cs * 0.2), Paint()..color = const Color(0x553F88C5));
    }
    c.drawRect(cell(lv.n - 1).deflate(cs * 0.12), Paint()..color = const Color(0xFF66A182));
    final p = Paint()
      ..color = const Color(0xFF3A3548)
      ..strokeWidth = math.max(2, cs * 0.12)
      ..strokeCap = StrokeCap.round;
    final o = cell(0).topLeft;
    for (var e = 0; e < lv.borderCount; e++) {
      if (lv.extra[0][e] != 1) continue;
      final (a, b) = lv.edgeVertices(e);
      final pa = o + Offset((a % (lv.w + 1)) * cs, (a ~/ (lv.w + 1)) * cs);
      final pb = o + Offset((b % (lv.w + 1)) * cs, (b ~/ (lv.w + 1)) * cs);
      c.drawLine(pa, pb, p);
    }
    if (s.aux.isNotEmpty) paintHero(c, cell(s.aux[0]));
  }
}
