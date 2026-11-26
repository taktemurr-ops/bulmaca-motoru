import 'dart:math' as math;

import 'package:studio_core/core/rng.dart';

import 'free_core.dart';

/// Tuzaklı Bilmeceler: kalıp tabanlı mikro bulmacalar. Her bölüm bir
/// kalıp ve ondan üretilmiş parametrelerdir (yerler, sayılar, simgeler,
/// gizlenen nesne...). Bölümün çözüm betiği ([sol]) aynı mantıkla oynatılıp
/// kazanıldığı doğrulanır.
///
/// Dünya koordinatları: 1000 × 1300 (yönergenin altındaki oyun alanı).
class TrickLogic extends FreeLogic {
  const TrickLogic();

  @override
  String get id => 'tuzakli-bilmeceler';

  static const worldW = 1000.0, worldH = 1300.0;

  // kalıplar
  static const tFind = 0, tBiggest = 1, tCount = 2, tMath = 3, tOdd = 4, tNight = 5, tCandle = 6, tFill = 7;
  static const tTapN = 8, tOrder = 9, tWake = 10, tFeed = 11, tBalloons = 12, tHeavier = 13, tPairs = 14, tClean = 15;
  static const templateCount = 16;

  /// Yönerge anahtarları (metinler trick_texts.dart içinde 33 dilde).
  static const promptKeys = [
    'find', 'biggest', 'count', 'math', 'odd', 'night', 'candle', 'fill',
    'tapn', 'order', 'wake', 'feed', 'balloons', 'heavier', 'pairs', 'clean',
  ];

  /// Zorluğa göre izinli kalıplar.
  static List<int> allowed(int d) => [
        tFind, tBiggest, tCount, tOdd, tNight, tFill, tTapN, tBalloons, tPairs, tClean, tWake, tFeed,
        if (d >= 3) tOrder,
        if (d >= 3) tCandle,
        if (d >= 4) tMath,
        if (d >= 4) tHeavier,
      ];

  /// Simge sayısı (arayüzdeki simge listesiyle aynı uzunlukta).
  static const iconCount = 24;

  @override
  FLevel make(int d, SeededRandom r) {
    final list = allowed(d);
    for (var attempt = 0; attempt < 40; attempt++) {
      final t = list[r.nextInt(list.length)];
      final data = _gen(t, d, r);
      final lv = FLevel(id, d, r.nextInt(1 << 30), data);
      if (check(lv) == null) return lv;
    }
    throw StateError('trick');
  }

  static List<(double, double)> _spots(SeededRandom r, int n, double minD, {double x0 = 110, double x1 = 890, double y0 = 230, double y1 = 1020}) {
    final out = <(double, double)>[];
    for (var tries = 0; out.length < n && tries < 4000; tries++) {
      final x = x0 + r.nextDouble() * (x1 - x0), y = y0 + r.nextDouble() * (y1 - y0);
      if (out.every((p) => math.sqrt((p.$1 - x) * (p.$1 - x) + (p.$2 - y) * (p.$2 - y)) >= minD)) out.add((x, y));
    }
    return out;
  }

  static List<int> _distinctIcons(SeededRandom r, int n) {
    final l = [for (var i = 0; i < iconCount; i++) i];
    r.shuffle(l);
    return l.take(n).toList();
  }

  /// Nesne: [tür, simge, x, y, boyut, değer, renk, hareketli(1/0), açı*100]
  static List<num> obj(int kind, int icon, double x, double y, double s, {int val = 0, int color = 0, bool movable = false, double rot = 0}) =>
      [kind, icon, x.roundToDouble(), y.roundToDouble(), s.roundToDouble(), val, color, movable ? 1 : 0, (rot * 100).round()];

  // nesne türleri
  static const oItem = 0, oCover = 1, oNumber = 2, oButton = 3, oSun = 4, oCurtain = 5, oCreature = 6, oBox = 7, oFood = 8;
  static const oCandle = 9, oMatch = 10, oMatchBox = 11, oGlass = 12, oFaucet = 13, oBalloon = 14, oDirt = 15, oPlate = 16, oBell = 17;
  static const oPan = 18, oCloud = 19;

  Map<String, Object?> _gen(int t, int d, SeededRandom r) {
    final objs = <List<num>>[];
    final sol = <List<num>>[];
    var p0 = 0; // yönergeye giren sayı (ör. dokunma adedi)
    var p1 = 0; // ek parametre (doldurma hedefi ‰, hız ‰)
    var p2 = 0;
    switch (t) {
      case tFind:
        final n = math.min(3 + d ~/ 2, 7);
        final spots = _spots(r, n, 230);
        if (spots.length < n) return {};
        final icons = _distinctIcons(r, n);
        final k = r.nextInt(n);
        final style = r.nextInt(4);
        for (var i = 0; i < n; i++) {
          objs.add(obj(oItem, icons[i], spots[i].$1, spots[i].$2, 70));
        }
        for (var i = 0; i < n; i++) {
          objs.add(obj(oCover, style, spots[i].$1, spots[i].$2, 105, movable: true));
        }
        p0 = icons[k];
        final (x, y) = spots[k];
        sol.add([1, x, y, x, 1220]);
        sol.add([0, x, y]);
      case tBiggest:
        final n = 3 + math.min(d, 5).toInt();
        final spots = _spots(r, n, 210);
        if (spots.length < n) return {};
        final maxV = d <= 2 ? 20 : (d <= 5 ? 99 : 999);
        final vals = <int>{};
        while (vals.length < n) {
          vals.add(1 + r.nextInt(maxV));
        }
        final sorted = vals.toList()..sort();
        // yazı boyu değerle ters orantılı (tuzak)
        for (var i = 0; i < n; i++) {
          final v = sorted[i];
          final s = 150 - i * (90 / n) + r.nextInt(12);
          objs.add(obj(oNumber, 0, spots[i].$1, spots[i].$2, s, val: v, color: r.nextInt(6)));
        }
        final (x, y) = spots[n - 1];
        sol.add([0, x, y]);
      case tCount:
        final v = 3 + r.nextInt(math.min(3 + d, 8));
        final hidden = d >= 2 ? 1 : 0;
        final spots = _spots(r, v + hidden + 1, 150, y1: 900);
        if (spots.length < v + hidden + 1) return {};
        final icon = r.nextInt(iconCount);
        for (var i = 0; i < v + hidden; i++) {
          objs.add(obj(oItem, icon, spots[i].$1, spots[i].$2, 60));
        }
        if (hidden == 1) {
          final (hx, hy) = spots[v];
          objs.add(obj(oCloud, 0, hx, hy, 115, movable: true));
        } else {
          final (cx, cy) = spots[v];
          objs.add(obj(oCloud, 0, cx, cy, 115, movable: true));
        }
        final right = v + hidden;
        final opts = _options(r, right, [right - 1, right + 1, right + 2, right - 2]);
        for (var i = 0; i < 4; i++) {
          objs.add(obj(oButton, 0, 140 + i * 240, 1160, 95, val: opts[i]));
        }
        p0 = icon;
        sol.add([0, 140 + opts.indexOf(right) * 240, 1160]);
      case tMath:
        final a = 1 + r.nextInt(9), b = 2 + r.nextInt(8), c = 2 + r.nextInt(8);
        final mul = d >= 7 && r.chance(0.5);
        // a + b × c ya da a × b + c × ... (d yüksekse a × b − c)
        final right = mul ? a * b - c : a + b * c;
        final wrong = mul ? a * (b - c) : (a + b) * c;
        final opts = _options(r, right, [wrong, a + b + c, right + 1, right - 1, right + 10]);
        p0 = a;
        p1 = b;
        p2 = c * (mul ? -1 : 1);
        for (var i = 0; i < 4; i++) {
          objs.add(obj(oButton, 0, 140 + i * 240, 1100, 100, val: opts[i]));
        }
        sol.add([0, 140 + opts.indexOf(right) * 240, 1100]);
      case tOdd:
        final g = math.min(3 + d ~/ 3, 6);
        final icon = r.nextInt(iconCount);
        final k = r.nextInt(g * g);
        final cell = 820 / g;
        final kind = d <= 3 ? 0 : (d <= 6 ? 1 : 2); // 0 renk, 1 dönük, 2 küçük/aynalı
        for (var i = 0; i < g * g; i++) {
          final x = 90 + cell * (i % g + 0.5), y = 220 + cell * (i ~/ g + 0.5);
          final odd = i == k;
          objs.add(obj(oItem, icon, x, y, cell * 0.36 * (odd && kind == 2 ? 0.8 : 1),
              color: odd && kind == 0 ? 1 : 0, rot: odd && kind == 1 ? (d >= 6 ? 0.22 : 0.4) : 0, val: odd ? 1 : 0));
        }
        sol.add([0, 90 + cell * (k % g + 0.5), 220 + cell * (k ~/ g + 0.5)]);
      case tNight:
        final x = 180 + r.nextDouble() * 640, y = 300 + r.nextDouble() * 200;
        for (final (cx, cy) in _spots(r, 2, 260, y0: 260, y1: 600)) {
          if ((cx - x).abs() < 230 && (cy - y).abs() < 200) continue;
          objs.add(obj(oCloud, 1, cx, cy, 90));
        }
        objs.add(obj(oSun, 0, x, y, 110, movable: true));
        if (d >= 5) {
          objs.add(obj(oCloud, 1, x + (r.nextDouble() - 0.5) * 40, y + 10, 170, movable: true));
          sol.add([1, x, y + 10, x < 500 ? 820 : 180, 260]);
        }
        sol.add([1, x, y, x, 1220]);
      case tCandle:
        final sp = _spots(r, 3, 280, y0: 330, y1: 1000);
        if (sp.length < 3) return {};
        objs.add(obj(oCandle, 0, sp[0].$1, sp[0].$2, 110));
        objs.add(obj(oMatchBox, 0, sp[1].$1, sp[1].$2, 95));
        objs.add(obj(oMatch, 0, sp[2].$1, sp[2].$2, 85, movable: true));
        sol.add([1, sp[2].$1, sp[2].$2, sp[1].$1, sp[1].$2]);
        sol.add([1, sp[1].$1, sp[1].$2, sp[0].$1, sp[0].$2 - 90]);
      case tFill:
        final target = 400 + r.nextInt(450); // ‰
        final rate = 220 + d * 18; // ‰ / saniye
        final tol = math.max(30, 90 - d * 6);
        p0 = target;
        p1 = rate;
        p2 = tol;
        objs.add(obj(oFaucet, 0, 500, 330, 120));
        objs.add(obj(oGlass, 0, 500, 820, 230));
        final ms = (target / rate * 1000).round();
        sol.add([2, 500, 330, ms]);
      case tTapN:
        final n = 3 + r.nextInt(math.min(4 + d, 10));
        p0 = n;
        final x = 260 + r.nextDouble() * 480, y = 520 + r.nextDouble() * 300;
        objs.add(obj(oBell, 0, x, y, 150));
        for (var i = 0; i < n; i++) {
          sol.add([0, x, y]);
        }
      case tOrder:
        final n = math.min(3 + d ~/ 2, 7);
        final sp = _spots(r, n, 210);
        if (sp.length < n) return {};
        final vals = <int>{};
        while (vals.length < n) {
          vals.add(d >= 5 ? r.nextInt(41) - 20 : 1 + r.nextInt(30));
        }
        final vl = vals.toList();
        for (var i = 0; i < n; i++) {
          objs.add(obj(oNumber, 1, sp[i].$1, sp[i].$2, 100, val: vl[i], color: r.nextInt(6)));
        }
        final idx = [for (var i = 0; i < n; i++) i]..sort((a, b) => vl[a].compareTo(vl[b]));
        for (final i in idx) {
          sol.add([0, sp[i].$1, sp[i].$2]);
        }
      case tWake:
        final cx = 260 + r.nextDouble() * 480;
        final left = r.chance(0.5);
        final wx = left ? 280.0 : 720.0;
        objs.add(obj(oCurtain, 0, wx, 420, 170, movable: true));
        objs.add(obj(oCreature, r.nextInt(3), cx, 930, 150));
        objs.add(obj(oBell, 1, left ? 760 : 240, 640, 80));
        sol.add([1, wx, 420, left ? wx - 260 : wx + 260, 420]);
      case tFeed:
        final boxes = d >= 5 ? 2 : 1;
        final sp = _spots(r, boxes, 330, y0: 330, y1: 600);
        if (sp.length < boxes) return {};
        final k = r.nextInt(boxes);
        final cx = 260 + r.nextDouble() * 480;
        objs.add(obj(oCreature, r.nextInt(3), cx, 980, 150));
        for (var i = 0; i < boxes; i++) {
          objs.add(obj(oBox, i == k ? 1 : 0, sp[i].$1, sp[i].$2, 130));
        }
        sol.add([0, sp[k].$1, sp[k].$2]);
        sol.add([1, sp[k].$1, sp[k].$2 - 10, cx, 980]);
      case tBalloons:
        final n = math.min(3 + d ~/ 2, 7);
        final hidden = d >= 3 ? 1 : 0;
        final sp = _spots(r, n, 190, y1: 900);
        if (sp.length < n) return {};
        for (var i = 0; i < n; i++) {
          objs.add(obj(oBalloon, 0, sp[i].$1, sp[i].$2, 75, color: r.nextInt(6)));
        }
        if (hidden == 1) {
          final (hx, hy) = sp[n - 1];
          objs.add(obj(oCloud, 0, hx, hy, 130, movable: true));
          sol.add([1, hx, hy, hx, 1220]);
        }
        for (final (x, y) in sp) {
          sol.add([0, x, y]);
        }
      case tHeavier:
        final same = r.chance(0.5);
        final a = 1 + r.nextInt(9);
        final b = same ? a : (r.chance(0.5) ? a + 1 + r.nextInt(5) : math.max(1, a - 1 - r.nextInt(3)));
        final bb = b == a && !same ? a + 1 : b;
        // hafif görünen simge büyük sayıyla (tuzak)
        objs.add(obj(oPan, 0, 280, 640, 150, val: a, color: 0));
        objs.add(obj(oPan, 1, 720, 640, 150, val: bb, color: 1));
        final opts = [-1, 0, 1];
        for (var i = 0; i < 3; i++) {
          objs.add(obj(oButton, 1, 230 + i * 270, 1100, 100, val: opts[i]));
        }
        final right = a == bb ? 0 : (a > bb ? -1 : 1);
        sol.add([0, 230 + (right + 1) * 270, 1100]);
      case tPairs:
        final n = math.min(2 + d ~/ 3, 5);
        final sp = _spots(r, 2 * n, 170);
        if (sp.length < 2 * n) return {};
        final icons = _distinctIcons(r, n);
        for (var i = 0; i < n; i++) {
          objs.add(obj(oItem, icons[i], sp[2 * i].$1, sp[2 * i].$2, 70, movable: true, val: i));
          objs.add(obj(oItem, icons[i], sp[2 * i + 1].$1, sp[2 * i + 1].$2, 70, movable: true, val: i));
          sol.add([1, sp[2 * i].$1, sp[2 * i].$2, sp[2 * i + 1].$1, sp[2 * i + 1].$2]);
        }
      case tClean:
        final n = math.min(2 + d ~/ 2, 6);
        objs.add(obj(oPlate, 0, 500, 650, 360));
        final sp = _spots(r, n, 150, x0: 260, x1: 740, y0: 420, y1: 880);
        if (sp.length < n) return {};
        for (final (x, y) in sp) {
          objs.add(obj(oDirt, r.nextInt(3), x, y, 70));
          sol.add([3, x, y, 60, 6]);
        }
    }
    if (objs.isEmpty) return {};
    return {'t': t, 'o': objs, 'sol': sol, 'p0': p0, 'p1': p1, 'p2': p2};
  }

  static List<int> _options(SeededRandom r, int right, List<int> wrongs) {
    final set = <int>{right};
    for (final w in wrongs) {
      if (set.length >= 4) break;
      if (w >= 0 || right < 0) set.add(w);
    }
    var k = 3;
    while (set.length < 4) {
      set.add(right + k++);
    }
    final l = set.toList();
    r.shuffle(l);
    return l;
  }

  @override
  String? check(FLevel lv) {
    if (lv.data['o'] == null) return 'empty';
    final s = TrickState(lv);
    if (s.won) return 'already won';
    for (final a in s.sol) {
      s.perform(a);
      if (s.lost) return 'solution loses';
    }
    return s.won ? null : 'solution does not win';
  }
}

/// Bir nesnenin oyundaki durumu.
class TObj {
  final int kind, icon;
  double x, y, s;
  int val, color;
  bool movable;
  double rot;
  bool gone = false;
  int flag = 0; // türe özgü (açık kutu, yanan kibrit, kirlilik ‰ ...)
  final double ox, oy;
  TObj(this.kind, this.icon, this.x, this.y, this.s, this.val, this.color, this.movable, this.rot)
      : ox = x,
        oy = y;

  bool hit(double px, double py) => !gone && (px - x) * (px - x) + (py - y) * (py - y) <= s * s;
}

/// Bilmece durumu: dünya koordinatlarıyla dokunuş olayları (saf Dart).
class TrickState {
  final FLevel lv;
  final int t, p0, p1, p2;
  late List<TObj> objs;
  late final List<List<num>> sol;
  bool won = false, lost = false;
  int count = 0; // dokunma sayısı / sıradaki indeks
  double level = 0; // doldurma (‰)
  bool holding = false;
  int night = 0;
  int _drag = -1;
  double _dx = 0, _dy = 0, _sx = 0, _sy = 0, _lx = 0, _ly = 0;
  bool _moved = false;

  TrickState(this.lv)
      : t = lv.i('t'),
        p0 = lv.i('p0'),
        p1 = lv.i('p1'),
        p2 = lv.i('p2') {
    objs = [
      for (final o in (lv.data['o'] as List))
        () {
          final l = [for (final v in (o as List)) (v as num)];
          return TObj(l[0].toInt(), l[1].toInt(), l[2].toDouble(), l[3].toDouble(), l[4].toDouble(), l[5].toInt(), l[6].toInt(),
              l[7] == 1, l[8] / 100);
        }()
    ];
    sol = [for (final a in (lv.data['sol'] as List)) [for (final v in (a as List)) (v as num)]];
  }

  /// En üstteki (son çizilen) nesne.
  int topAt(double x, double y) {
    for (var i = objs.length - 1; i >= 0; i--) {
      final o = objs[i];
      if (o.kind == TrickLogic.oButton) {
        if (!o.gone && (x - o.x).abs() <= o.s && (y - o.y).abs() <= o.s * 0.8) return i;
        continue;
      }
      if (o.kind == TrickLogic.oNumber) {
        final half = o.s * 0.32 * math.max(1, '${o.val}'.length) + 20;
        if (!o.gone && (x - o.x).abs() <= half && (y - o.y).abs() <= o.s * 0.5) return i;
        continue;
      }
      if (o.kind == TrickLogic.oCurtain && !o.gone && (x - o.x).abs() <= o.s * 0.9 && (y - o.y).abs() <= o.s * 1.3) return i;
      if (o.hit(x, y)) return i;
    }
    return -1;
  }

  // ---- olaylar
  void down(double x, double y) {
    if (won || lost) return;
    _drag = topAt(x, y);
    _sx = _lx = x;
    _sy = _ly = y;
    _moved = false;
    if (_drag >= 0) {
      _dx = objs[_drag].x - x;
      _dy = objs[_drag].y - y;
    }
    if (t == TrickLogic.tFill && _drag >= 0 && objs[_drag].kind == TrickLogic.oFaucet) holding = true;
  }

  void move(double x, double y) {
    if (won || lost) return;
    if ((x - _sx).abs() + (y - _sy).abs() > 18) _moved = true;
    if (t == TrickLogic.tClean) _rub(x, y);
    if (_drag >= 0 && objs[_drag].movable) {
      final o = objs[_drag];
      o.x = (x + _dx).clamp(0, TrickLogic.worldW);
      o.y = (y + _dy).clamp(0, TrickLogic.worldH);
    }
    _lx = x;
    _ly = y;
  }

  void up() {
    if (won || lost) return;
    if (holding) {
      holding = false;
      final lo = p0 - p2, hi = p0 + p2;
      if (level >= lo && level <= hi) won = true;
    }
    final i = _drag;
    _drag = -1;
    if (i < 0) return;
    final o = objs[i];
    if (_moved && o.movable) {
      _drop(i);
    } else if (!_moved) {
      _tap(i);
    }
  }

  void tick(double dt) {
    if (won || lost) return;
    if (holding) {
      level += p1 * dt;
      if (level > p0 + p2 + 120) {
        // taştı: bardak boşalır, yeniden dene
        level = 0;
        holding = false;
      }
    }
  }

  void _rub(double x, double y) {
    final dist = math.sqrt((x - _lx) * (x - _lx) + (y - _ly) * (y - _ly));
    for (final o in objs) {
      if (o.kind != TrickLogic.oDirt || o.gone) continue;
      if ((x - o.x) * (x - o.x) + (y - o.y) * (y - o.y) <= (o.s + 30) * (o.s + 30)) {
        o.flag += dist.round();
        if (o.flag >= 260) o.gone = true;
      }
    }
    if (objs.where((o) => o.kind == TrickLogic.oDirt).every((o) => o.gone)) won = true;
  }

  void _tap(int i) {
    final o = objs[i];
    switch (t) {
      case TrickLogic.tFind:
        if (o.kind == TrickLogic.oItem && o.icon == p0) won = true;
      case TrickLogic.tBiggest:
        if (o.kind != TrickLogic.oNumber) return;
        final best = objs.where((q) => q.kind == TrickLogic.oNumber).map((q) => q.val).reduce(math.max);
        if (o.val == best) {
          won = true;
        } else {
          lost = true;
        }
      case TrickLogic.tCount || TrickLogic.tMath:
        if (o.kind != TrickLogic.oButton) return;
        final right = t == TrickLogic.tCount
            ? objs.where((q) => q.kind == TrickLogic.oItem).length
            : (p2 < 0 ? p0 * p1 + p2 : p0 + p1 * p2);
        if (o.val == right) {
          won = true;
        } else {
          lost = true;
        }
      case TrickLogic.tOdd:
        if (o.kind != TrickLogic.oItem) return;
        if (o.val == 1) {
          won = true;
        } else {
          lost = true;
        }
      case TrickLogic.tTapN:
        if (o.kind != TrickLogic.oBell) return;
        count++;
        o.flag++;
        if (count == p0) won = true;
      case TrickLogic.tOrder:
        if (o.kind != TrickLogic.oNumber) return;
        final rest = objs.where((q) => q.kind == TrickLogic.oNumber && !q.gone).map((q) => q.val).reduce(math.min);
        if (o.val == rest) {
          o.gone = true;
          if (objs.where((q) => q.kind == TrickLogic.oNumber).every((q) => q.gone)) won = true;
        } else {
          lost = true;
        }
      case TrickLogic.tFeed:
        if (o.kind == TrickLogic.oBox && o.flag == 0) {
          o.flag = 1;
          if (o.icon == 1) {
            objs.add(TObj(TrickLogic.oFood, 0, o.x, o.y - 10, 70, 0, 0, true, 0));
          }
        }
      case TrickLogic.tBalloons:
        if (o.kind != TrickLogic.oBalloon) return;
        o.gone = true;
        if (objs.where((q) => q.kind == TrickLogic.oBalloon).every((q) => q.gone)) won = true;
      case TrickLogic.tHeavier:
        if (o.kind != TrickLogic.oButton) return;
        final a = objs.firstWhere((q) => q.kind == TrickLogic.oPan && q.icon == 0).val;
        final b = objs.firstWhere((q) => q.kind == TrickLogic.oPan && q.icon == 1).val;
        final right = a == b ? 0 : (a > b ? -1 : 1);
        if (o.val == right) {
          won = true;
        } else {
          lost = true;
        }
      case TrickLogic.tWake:
        if (o.kind == TrickLogic.oBell) o.flag++; // çalar saat: işe yaramaz (tuzak)
    }
  }

  void _drop(int i) {
    final o = objs[i];
    double d2(TObj a, TObj b) => (a.x - b.x) * (a.x - b.x) + (a.y - b.y) * (a.y - b.y);
    switch (t) {
      case TrickLogic.tNight:
        if (o.kind == TrickLogic.oSun && o.y > 1080) {
          night = 1;
          won = true;
        }
      case TrickLogic.tCandle:
        if (o.kind != TrickLogic.oMatch) return;
        final box = objs.firstWhere((q) => q.kind == TrickLogic.oMatchBox);
        final candle = objs.firstWhere((q) => q.kind == TrickLogic.oCandle);
        if (d2(o, box) < 120 * 120) o.flag = 1;
        if (o.flag == 1 && (o.x - candle.x).abs() < 90 && (o.y - (candle.y - 90)).abs() < 110) {
          candle.flag = 1;
          won = true;
        }
      case TrickLogic.tWake:
        if (o.kind == TrickLogic.oCurtain && (o.x - o.ox).abs() > 150) {
          o.flag = 1;
          for (final c in objs) {
            if (c.kind == TrickLogic.oCreature) c.flag = 1;
          }
          won = true;
        }
      case TrickLogic.tFeed:
        if (o.kind != TrickLogic.oFood) return;
        final cr = objs.firstWhere((q) => q.kind == TrickLogic.oCreature);
        if (d2(o, cr) < 150 * 150) {
          o.gone = true;
          cr.flag = 1;
          won = true;
        }
      case TrickLogic.tPairs:
        if (o.kind != TrickLogic.oItem) return;
        for (final q in objs) {
          if (identical(q, o) || q.gone || q.kind != TrickLogic.oItem || q.val != o.val) continue;
          if (d2(q, o) < 110 * 110) {
            q.gone = true;
            o.gone = true;
          }
        }
        if (objs.where((q) => q.kind == TrickLogic.oItem).every((q) => q.gone)) won = true;
    }
  }

  /// Çözüm betiğinden bir eylem: [0 x y] dokun, [1 x0 y0 x1 y1] sürükle,
  /// [2 x y ms] basılı tut, [3 x y yarıçap tur] ov.
  void perform(List<num> a) {
    switch (a[0].toInt()) {
      case 0:
        down(a[1].toDouble(), a[2].toDouble());
        up();
      case 1:
        final x0 = a[1].toDouble(), y0 = a[2].toDouble(), x1 = a[3].toDouble(), y1 = a[4].toDouble();
        down(x0, y0);
        for (var k = 1; k <= 10; k++) {
          move(x0 + (x1 - x0) * k / 10, y0 + (y1 - y0) * k / 10);
        }
        up();
      case 2:
        down(a[1].toDouble(), a[2].toDouble());
        var ms = a[3].toInt();
        while (ms > 0) {
          tick(math.min(ms, 16) / 1000);
          ms -= 16;
        }
        up();
      case 3:
        final x = a[1].toDouble(), y = a[2].toDouble(), rad = a[3].toDouble();
        down(x - rad, y);
        for (var k = 0; k < a[4].toInt() * 2; k++) {
          move(k.isEven ? x + rad : x - rad, y + (k % 3 - 1) * rad * 0.4);
        }
        up();
    }
  }
}
