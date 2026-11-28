import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Tahta dokusu: her oyunun kendine özgü kâğıdı/zemini.
enum BoardTexture { plain, graph, wood, parchment, stone, waves, grass, stars, kraft, linen, dots, rays, asphalt, cork, blueprint, tiles }

/// Tahta çerçevesi.
enum BoardFrame { soft, wood, doubleLine, metal, inset, tape }

/// Bir oyunun oyun içi görsel kimliği: kâğıt, mürekkep, doku, çerçeve ve
/// vurgu rengi. Aynı motoru kullanan oyunlar böylece birbirinin kopyası gibi
/// görünmez (ör. Sudoku gazete kâğıdında, Nonogram kareli defterde, Kakuro
/// kraft kâğıtta, Çadırlar çimenlikte). Vurgu rengi oyunun kendi tohum
/// renginden gelir.
class BoardStyle {
  final BoardTexture texture;
  final BoardFrame frame;
  final Color paper, paper2, ink, frameColor, pattern;

  /// Oyuncunun yazdığı rakam/çizgi rengi (null: oyunun tohum rengi).
  final Color? accent;

  const BoardStyle({
    required this.texture,
    required this.frame,
    required this.paper,
    required this.paper2,
    required this.ink,
    required this.frameColor,
    required this.pattern,
    this.accent,
  });

  BoardStyle withAccent(Color a) => BoardStyle(
      texture: texture, frame: frame, paper: paper, paper2: paper2, ink: ink, frameColor: frameColor, pattern: pattern, accent: a);

  // ------------------------------------------------------------------ aileler
  static const newsprint = BoardStyle(
      texture: BoardTexture.plain,
      frame: BoardFrame.doubleLine,
      paper: Color(0xFFFBFAF6),
      paper2: Color(0xFFEFEDE6),
      ink: Color(0xFF1E2532),
      frameColor: Color(0xFF2B3446),
      pattern: Color(0x0F1E2532));
  static const graph = BoardStyle(
      texture: BoardTexture.graph,
      frame: BoardFrame.metal,
      paper: Color(0xFFF3F8F5),
      paper2: Color(0xFFE3EEE8),
      ink: Color(0xFF1F2E36),
      frameColor: Color(0xFF6E7F86),
      pattern: Color(0x2A2E8C7A));
  static const maple = BoardStyle(
      texture: BoardTexture.wood,
      frame: BoardFrame.wood,
      paper: Color(0xFFF0D9B0),
      paper2: Color(0xFFE2C390),
      ink: Color(0xFF3A2716),
      frameColor: Color(0xFF7A4E2A),
      pattern: Color(0x22704018));
  static const parchment = BoardStyle(
      texture: BoardTexture.parchment,
      frame: BoardFrame.doubleLine,
      paper: Color(0xFFF6E8C8),
      paper2: Color(0xFFE8D2A4),
      ink: Color(0xFF45301C),
      frameColor: Color(0xFF7B5530),
      pattern: Color(0x2A8A6030));
  static const slate = BoardStyle(
      texture: BoardTexture.stone,
      frame: BoardFrame.metal,
      paper: Color(0xFFE6EBF0),
      paper2: Color(0xFFD3DBE3),
      ink: Color(0xFF1E2B38),
      frameColor: Color(0xFF55636F),
      pattern: Color(0x24344A5E));
  static const sea = BoardStyle(
      texture: BoardTexture.waves,
      frame: BoardFrame.inset,
      paper: Color(0xFFE6F4FA),
      paper2: Color(0xFFCFE7F2),
      ink: Color(0xFF15374B),
      frameColor: Color(0xFF2D6E8E),
      pattern: Color(0x2A2D7FA8));
  static const meadow = BoardStyle(
      texture: BoardTexture.grass,
      frame: BoardFrame.soft,
      paper: Color(0xFFEEF6E2),
      paper2: Color(0xFFDCEBC8),
      ink: Color(0xFF283A1F),
      frameColor: Color(0xFF5E8446),
      pattern: Color(0x305E8C3E));
  static const night = BoardStyle(
      texture: BoardTexture.stars,
      frame: BoardFrame.inset,
      paper: Color(0xFFEEEBF8),
      paper2: Color(0xFFDCD6F0),
      ink: Color(0xFF29224A),
      frameColor: Color(0xFF4F4585),
      pattern: Color(0x405A4CA0));
  static const kraft = BoardStyle(
      texture: BoardTexture.kraft,
      frame: BoardFrame.tape,
      paper: Color(0xFFEBD8B6),
      paper2: Color(0xFFDCC39A),
      ink: Color(0xFF35261A),
      frameColor: Color(0xFF8C6A44),
      pattern: Color(0x26553A20));
  static const linen = BoardStyle(
      texture: BoardTexture.linen,
      frame: BoardFrame.soft,
      paper: Color(0xFFF7F1E9),
      paper2: Color(0xFFEBE1D4),
      ink: Color(0xFF33282C),
      frameColor: Color(0xFF8E7A70),
      pattern: Color(0x1C6A4A50));
  static const blush = BoardStyle(
      texture: BoardTexture.dots,
      frame: BoardFrame.soft,
      paper: Color(0xFFFBEEF1),
      paper2: Color(0xFFF1DCE2),
      ink: Color(0xFF3D2330),
      frameColor: Color(0xFFB0697F),
      pattern: Color(0x30B0607A));
  static const sunny = BoardStyle(
      texture: BoardTexture.rays,
      frame: BoardFrame.soft,
      paper: Color(0xFFFCF6DC),
      paper2: Color(0xFFF3E6B4),
      ink: Color(0xFF3A3218),
      frameColor: Color(0xFFB08A2A),
      pattern: Color(0x22C9A227));
  static const street = BoardStyle(
      texture: BoardTexture.asphalt,
      frame: BoardFrame.metal,
      paper: Color(0xFFE9E8E4),
      paper2: Color(0xFFD8D6D0),
      ink: Color(0xFF26282C),
      frameColor: Color(0xFF5E6168),
      pattern: Color(0x30FFFFFF));
  static const cork = BoardStyle(
      texture: BoardTexture.cork,
      frame: BoardFrame.wood,
      paper: Color(0xFFEBCFA4),
      paper2: Color(0xFFDDB985),
      ink: Color(0xFF3B2A18),
      frameColor: Color(0xFF6E4A28),
      pattern: Color(0x307A5020));
  static const blueprint = BoardStyle(
      texture: BoardTexture.blueprint,
      frame: BoardFrame.metal,
      paper: Color(0xFFE5EEF9),
      paper2: Color(0xFFD2E1F3),
      ink: Color(0xFF1B3354),
      frameColor: Color(0xFF3A5D8C),
      pattern: Color(0x283A6EB0));
  static const mint = BoardStyle(
      texture: BoardTexture.tiles,
      frame: BoardFrame.soft,
      paper: Color(0xFFE8F6F0),
      paper2: Color(0xFFD4EDE2),
      ink: Color(0xFF1D3A32),
      frameColor: Color(0xFF3F8C76),
      pattern: Color(0x223F8C76));

  /// Tür kimliği → aile. Listede olmayanlar kimliğin karmasıyla seçilir.
  static const Map<String, BoardStyle> _byKind = {
    'sudoku': newsprint,
    'killer-sudoku': linen,
    'sudoku-cesitleri': blueprint,
    'kakuro': kraft,
    'hesap-kutusu': kraft,
    'matematik-cengeli': graph,
    'kakurasu': cork,
    'sumplete': kraft,
    'futoshiki': linen,
    'gokdelenler': blueprint,
    'suguru': mint,
    'sayi-yolu': parchment,
    'tabela': linen,
    'fillomino': meadow,
    'nonogram': graph,
    'renkli-nonogram': blush,
    'mozaik': graph,
    'binairo': newsprint,
    'hitori': slate,
    'nurikabe': sea,
    'heyawake': linen,
    'menzil': slate,
    'kuromasu': slate,
    'isik-yak': sunny,
    'isiklari-sondur': sunny,
    'cevir': sunny,
    'tapa': cork,
    'yildiz-savasi': night,
    'kraliceler': blush,
    'cadirlar': meadow,
    'gemiler': sea,
    'akvaryum': sea,
    'norinori': blush,
    'lits': meadow,
    'miknatislar': slate,
    'slitherlink': parchment,
    'inci': night,
    'yajilin': linen,
    'raylar': parchment,
    'kopruler': sea,
    'sayi-baglama': mint,
    'renk-akisi': blueprint,
    'tek-cizgi': blush,
    'egik-cizgi': parchment,
    'galaksiler': night,
    'cit': meadow,
    'dikdortgenler': graph,
    'dominosa': maple,
    'boru-dondurme': blueprint,
    'harita-boyama': parchment,
    '2048': cork,
    'sayi-birlestirme': mint,
    'kayan-sayilar': maple,
    'resim-kaydirma': maple,
    'dondur': blush,
    'on-alti': cork,
    'kaydirmali-ag': blueprint,
    'hanoi-kulesi': maple,
    'tas-ziplatma': maple,
    'sayi-eslestirme': newsprint,
    'mayin-tarlasi': meadow,
    'kara-kutu': slate,
    'kod-kirici': slate,
    'su-siralama': sea,
    'top-siralama': blush,
    'vida-sokme': street,
    'altigen-siralama': mint,
    'ok-kacisi': street,
    'tikla-kaldir-taslar': maple,
    'otobus-yolcu-sikismasi': street,
    'araba-cikarma': street,
    'kayan-bloklar': maple,
    'sokoban': cork,
    'buz-kaydirma': sea,
    'atalet': night,
    'labirent': meadow,
    'tangram': maple,
    'yapboz': cork,
    'cozme': mint,
    'ip-cozme': blush,
    'fizik-cizgi-bulmacasi': blueprint,
    'sihirli-kup': slate,
    'hayaletler': night,
    'mantik-izgarasi': parchment,
    'at-turu': parchment,
    'sekiz-vezir': maple,
    'at-turu-ve-8-vezir': parchment,
  };

  static const _all = [newsprint, graph, maple, parchment, slate, sea, meadow, night, kraft, linen, blush, sunny, street, cork, blueprint, mint];

  /// Oyunun görsel kimliği: tür ailesi + oyunun tohum rengiyle vurgu.
  static BoardStyle of(String gameId, String kindId, Color seed) {
    var base = _byKind[kindId] ?? _all[_hash(gameId) % _all.length];
    // Aynı türü paket içinde oynatan oyunlar (ör. Mantık Bulmacası Uzun
    // Kuyruğu) tek başına oyunun kâğıdını değil komşu bir aileyi alır.
    if (_byKind.containsKey(kindId) && !gameId.endsWith(kindId)) {
      base = _all[(_all.indexOf(base) + 1 + _hash(gameId) % 5) % _all.length];
    }
    // Vurgu: tohum rengi kâğıt üstünde okunacak kadar koyu ve doygun olsun.
    final hsl = HSLColor.fromColor(seed);
    final accent = hsl.withLightness(hsl.lightness.clamp(0.30, 0.44)).withSaturation(math.max(0.45, hsl.saturation)).toColor();
    return base.withAccent(accent);
  }

  static int _hash(String s) {
    var h = 0x811C9DC5;
    for (final c in s.codeUnits) {
      h = ((h ^ c) * 0x01000193) & 0x7FFFFFFF;
    }
    return h;
  }

  // ------------------------------------------------------------------ çizim
  /// Tahtanın zemini, dokusu ve çerçevesi.
  void paintBoard(Canvas c, Rect board, double cs, {bool shadow = true}) {
    final pad = cs * 0.1;
    final outer = board.inflate(pad);
    final radius = Radius.circular(math.min(cs * 0.22, 18));
    final rr = RRect.fromRectAndRadius(outer, radius);
    // gölge
    if (shadow) c.drawRRect(rr.shift(Offset(0, math.max(2, cs * 0.06))), Paint()..color = const Color(0x33000000));
    // çerçeve (zeminin altında, dışa taşar)
    _paintFrame(c, rr, cs);
    // kâğıt
    c.drawRRect(
        rr,
        Paint()
          ..shader = LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [paper, paper2])
              .createShader(outer));
    c.save();
    c.clipRRect(rr);
    _paintTexture(c, outer, cs);
    c.restore();
    if (frame == BoardFrame.doubleLine) {
      final p = Paint()
        ..style = PaintingStyle.stroke
        ..color = frameColor.withValues(alpha: 0.55)
        ..strokeWidth = math.max(1, cs * 0.02);
      c.drawRRect(rr.inflate(math.max(3, cs * 0.08)), p);
    }
    if (frame == BoardFrame.tape) _paintTape(c, outer, cs);
  }

  void _paintFrame(Canvas c, RRect rr, double cs) {
    switch (frame) {
      case BoardFrame.wood:
        final w = math.max(5.0, cs * 0.16);
        final o = rr.inflate(w);
        c.drawRRect(
            o,
            Paint()
              ..shader = LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color.lerp(frameColor, Colors.white, 0.18)!, frameColor, Color.lerp(frameColor, Colors.black, 0.25)!])
                  .createShader(o.outerRect));
        final grain = Paint()
          ..color = Colors.black.withValues(alpha: 0.10)
          ..strokeWidth = 1;
        for (var k = 1; k < 4; k++) {
          c.drawRRect(rr.inflate(w * k / 4), grain..style = PaintingStyle.stroke);
        }
      case BoardFrame.metal:
        final w = math.max(3.0, cs * 0.09);
        final o = rr.inflate(w);
        c.drawRRect(
            o,
            Paint()
              ..shader = LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color.lerp(frameColor, Colors.white, 0.45)!, frameColor, Color.lerp(frameColor, Colors.white, 0.25)!])
                  .createShader(o.outerRect));
      case BoardFrame.inset:
        final w = math.max(4.0, cs * 0.12);
        final o = rr.inflate(w);
        c.drawRRect(o, Paint()..color = frameColor);
        c.drawRRect(
            rr.inflate(w * 0.35),
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = math.max(1, w * 0.25)
              ..color = Colors.white.withValues(alpha: 0.35));
      case BoardFrame.soft:
        final w = math.max(3.0, cs * 0.08);
        c.drawRRect(rr.inflate(w), Paint()..color = frameColor.withValues(alpha: 0.85));
      case BoardFrame.doubleLine:
        c.drawRRect(rr.inflate(math.max(1.5, cs * 0.03)), Paint()..color = frameColor);
      case BoardFrame.tape:
        c.drawRRect(rr.inflate(math.max(1.5, cs * 0.03)), Paint()..color = frameColor.withValues(alpha: 0.6));
    }
  }

  void _paintTape(Canvas c, Rect r, double cs) {
    final tw = math.max(28.0, cs * 1.1), th = math.max(10.0, cs * 0.34);
    // Kâğıt bant: yarı saydam krem (vurgu rengi okun gibi görünüyordu).
    final p = Paint()..color = const Color(0xB8F4E9CF);
    final edge = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = const Color(0x33000000);
    for (final (o, a) in [(r.topLeft, -0.6), (r.topRight, 0.6), (r.bottomLeft, 0.6), (r.bottomRight, -0.6)]) {
      c.save();
      c.translate(o.dx, o.dy);
      c.rotate(a);
      c.drawRect(Rect.fromCenter(center: Offset.zero, width: tw, height: th), p);
      c.drawRect(Rect.fromCenter(center: Offset.zero, width: tw, height: th), edge);
      c.restore();
    }
  }

  /// Sözde rastgele (deterministik) 0..1 değeri.
  static double _rnd(int i) {
    final x = math.sin(i * 12.9898 + 78.233) * 43758.5453;
    return x - x.floorToDouble();
  }

  void _paintTexture(Canvas c, Rect r, double cs) {
    final p = Paint()..color = pattern;
    switch (texture) {
      case BoardTexture.plain:
        // ince gazete kâğıdı lifleri
        final l = Paint()
          ..color = pattern
          ..strokeWidth = 0.6;
        for (var k = 0; k < 40; k++) {
          final y = r.top + _rnd(k) * r.height, x = r.left + _rnd(k + 99) * r.width;
          c.drawLine(Offset(x, y), Offset(x + 6 + _rnd(k + 7) * 18, y + _rnd(k + 3) * 2 - 1), l);
        }
      case BoardTexture.graph:
        final step = math.max(4.0, cs / 4);
        final l = Paint()
          ..color = pattern
          ..strokeWidth = 0.7;
        for (var x = r.left; x <= r.right; x += step) {
          c.drawLine(Offset(x, r.top), Offset(x, r.bottom), l);
        }
        for (var y = r.top; y <= r.bottom; y += step) {
          c.drawLine(Offset(r.left, y), Offset(r.right, y), l);
        }
      case BoardTexture.wood:
        final l = Paint()
          ..style = PaintingStyle.stroke
          ..color = pattern
          ..strokeWidth = 1.2;
        final gap = math.max(5.0, cs * 0.18);
        var k = 0;
        for (var y = r.top; y < r.bottom; y += gap) {
          final path = Path()..moveTo(r.left, y);
          for (var x = r.left; x <= r.right + 20; x += 20) {
            path.lineTo(x, y + math.sin((x + k * 37) / 46) * gap * 0.35);
          }
          c.drawPath(path, l);
          k++;
        }
      case BoardTexture.parchment:
        // kenarlarda koyulaşma ve lifler
        c.drawRect(
            r,
            Paint()
              ..shader = RadialGradient(colors: [Colors.transparent, pattern.withValues(alpha: 0.35)], stops: const [0.62, 1])
                  .createShader(r));
        final l = Paint()
          ..color = pattern
          ..strokeWidth = 0.8;
        for (var k = 0; k < 30; k++) {
          final x = r.left + _rnd(k) * r.width, y = r.top + _rnd(k + 51) * r.height;
          c.drawLine(Offset(x, y), Offset(x + 10 * _rnd(k + 5) - 5, y + 10 * _rnd(k + 9) - 5), l);
        }
      case BoardTexture.stone:
        for (var k = 0; k < 160; k++) {
          c.drawCircle(Offset(r.left + _rnd(k) * r.width, r.top + _rnd(k + 300) * r.height), 0.6 + _rnd(k + 600) * 1.4, p);
        }
      case BoardTexture.waves:
        final l = Paint()
          ..style = PaintingStyle.stroke
          ..color = pattern
          ..strokeWidth = 1.1;
        final gap = math.max(8.0, cs * 0.5);
        var row = 0;
        for (var y = r.top + gap / 2; y < r.bottom; y += gap) {
          for (var x = r.left + (row.isOdd ? gap : 0); x < r.right; x += gap * 2) {
            c.drawArc(Rect.fromCenter(center: Offset(x, y), width: gap, height: gap * 0.6), math.pi * 1.1, math.pi * 0.8, false, l);
          }
          row++;
        }
      case BoardTexture.grass:
        final l = Paint()
          ..color = pattern
          ..strokeWidth = 1.1
          ..strokeCap = StrokeCap.round;
        for (var k = 0; k < 90; k++) {
          final o = Offset(r.left + _rnd(k) * r.width, r.top + _rnd(k + 211) * r.height);
          final h = 3 + _rnd(k + 17) * 4;
          c.drawLine(o, o + Offset(-1.5, -h), l);
          c.drawLine(o, o + Offset(1.5, -h * 0.8), l);
        }
      case BoardTexture.stars:
        for (var k = 0; k < 70; k++) {
          final o = Offset(r.left + _rnd(k) * r.width, r.top + _rnd(k + 77) * r.height);
          final s = 0.8 + _rnd(k + 5) * 1.8;
          c.drawCircle(o, s, p);
          if (k % 9 == 0) {
            final l = Paint()
              ..color = pattern
              ..strokeWidth = 0.8;
            c.drawLine(o - Offset(s * 3, 0), o + Offset(s * 3, 0), l);
            c.drawLine(o - Offset(0, s * 3), o + Offset(0, s * 3), l);
          }
        }
      case BoardTexture.kraft:
        final l = Paint()
          ..color = pattern
          ..strokeWidth = 0.7;
        for (var k = 0; k < 120; k++) {
          final x = r.left + _rnd(k) * r.width, y = r.top + _rnd(k + 400) * r.height;
          final a = _rnd(k + 800) * math.pi;
          c.drawLine(Offset(x, y), Offset(x + math.cos(a) * 5, y + math.sin(a) * 5), l);
        }
      case BoardTexture.linen:
        final l = Paint()
          ..color = pattern
          ..strokeWidth = 0.6;
        for (var x = r.left; x <= r.right; x += 3) {
          c.drawLine(Offset(x, r.top), Offset(x, r.bottom), l);
        }
        for (var y = r.top; y <= r.bottom; y += 3) {
          c.drawLine(Offset(r.left, y), Offset(r.right, y), l);
        }
      case BoardTexture.dots:
        final step = math.max(8.0, cs * 0.34);
        var row = 0;
        for (var y = r.top + step / 2; y < r.bottom; y += step) {
          for (var x = r.left + (row.isOdd ? step / 2 : 0); x < r.right; x += step) {
            c.drawCircle(Offset(x, y), math.max(0.8, step * 0.08), p);
          }
          row++;
        }
      case BoardTexture.rays:
        final o = r.topLeft;
        final len = r.longestSide * 1.6;
        for (var k = 0; k < 14; k += 2) {
          final a0 = k * math.pi / 28, a1 = (k + 1) * math.pi / 28;
          c.drawPath(
              Path()
                ..moveTo(o.dx, o.dy)
                ..lineTo(o.dx + math.cos(a0) * len, o.dy + math.sin(a0) * len)
                ..lineTo(o.dx + math.cos(a1) * len, o.dy + math.sin(a1) * len)
                ..close(),
              p);
        }
      case BoardTexture.asphalt:
        for (var k = 0; k < 200; k++) {
          c.drawCircle(Offset(r.left + _rnd(k) * r.width, r.top + _rnd(k + 333) * r.height), 0.7, Paint()..color = const Color(0x22000000));
        }
        final l = Paint()
          ..color = pattern
          ..strokeWidth = math.max(1.5, cs * 0.04);
        final y = r.center.dy;
        for (var x = r.left; x < r.right; x += cs * 0.8) {
          c.drawLine(Offset(x, y), Offset(x + cs * 0.4, y), l);
        }
      case BoardTexture.cork:
        for (var k = 0; k < 220; k++) {
          final o = Offset(r.left + _rnd(k) * r.width, r.top + _rnd(k + 500) * r.height);
          c.drawOval(Rect.fromCenter(center: o, width: 1.5 + _rnd(k + 9) * 2.5, height: 1 + _rnd(k + 19) * 1.5), p);
        }
      case BoardTexture.blueprint:
        final step = math.max(6.0, cs / 2);
        final l = Paint()
          ..color = pattern.withValues(alpha: pattern.a * 0.6)
          ..strokeWidth = 0.6;
        final major = Paint()
          ..color = pattern
          ..strokeWidth = 1;
        var i = 0;
        for (var x = r.left; x <= r.right; x += step) {
          c.drawLine(Offset(x, r.top), Offset(x, r.bottom), i++ % 4 == 0 ? major : l);
        }
        i = 0;
        for (var y = r.top; y <= r.bottom; y += step) {
          c.drawLine(Offset(r.left, y), Offset(r.right, y), i++ % 4 == 0 ? major : l);
        }
      case BoardTexture.tiles:
        final step = math.max(10.0, cs * 0.5);
        final l = Paint()
          ..style = PaintingStyle.stroke
          ..color = pattern
          ..strokeWidth = 1;
        var row = 0;
        for (var y = r.top; y < r.bottom; y += step) {
          for (var x = r.left - (row.isOdd ? step / 2 : 0); x < r.right; x += step) {
            c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x + 1, y + 1, step - 2, step - 2), const Radius.circular(3)), l);
          }
          row++;
        }
    }
  }
}
