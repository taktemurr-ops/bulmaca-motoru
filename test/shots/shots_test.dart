// Oyun testi ekran görüntüleri (yalnız SHOTS=true ile): gerçek yazı tipleriyle
// telefon (393x852) ve tablet (1280x800) boyutunda bölüm açılışı, oyun ortası
// ve çözüm anı. CI'da yapıt olarak yüklenir.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bulmaca_motoru/bulmaca_motoru.dart';
import 'package:bulmaca_motoru/src/studio_chrome.dart';
import 'package:studio_core/app/game_api.dart';
import 'package:studio_core/core/game_rules.dart';
import 'package:studio_core/core/level_plan.dart';

const _on = bool.fromEnvironment('SHOTS');

Future<void> _fonts() async {
  final root = Platform.environment['FLUTTER_ROOT'] ?? '';
  final dir = Directory('$root/bin/cache/artifacts/material_fonts');
  if (!dir.existsSync()) return;
  final files = dir.listSync().whereType<File>().toList();
  final roboto = FontLoader('Roboto');
  for (final f in files.where((f) => f.path.contains('Roboto') && f.path.endsWith('.ttf'))) {
    roboto.addFont(Future.value(f.readAsBytesSync().buffer.asByteData()));
  }
  await roboto.load();
  // Tuvale yazılan metinler (TextPainter, aile belirtilmemiş) test motorunun
  // varsayılan ailesini kullanır: onu da gerçek yazı tipiyle doldur.
  for (final fam in const ['FlutterTest', 'Ahem']) {
    final l = FontLoader(fam);
    for (final f in files.where((f) => f.path.contains('Roboto-Regular') || f.path.contains('Roboto-Bold'))) {
      l.addFont(Future.value(f.readAsBytesSync().buffer.asByteData()));
    }
    await l.load();
  }
  // Arapça (RTL) ve CJK görüntüleri için sistem Noto yazı tipleri (CI'da kurulur).
  const extra = {
    'NotoArabic': '/usr/share/fonts/truetype/noto/NotoSansArabic-Regular.ttf',
    'NotoCJK': '/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc',
  };
  for (final e in extra.entries) {
    final f = File(e.value);
    if (!f.existsSync()) continue;
    for (final fam in [e.key, 'FlutterTest', 'Roboto']) {
      final l = FontLoader(fam)..addFont(Future.value(f.readAsBytesSync().buffer.asByteData()));
      await l.load();
    }
  }
  final icons = FontLoader('MaterialIcons');
  for (final f in files.where((f) => f.path.contains('MaterialIcons'))) {
    icons.addFont(Future.value(f.readAsBytesSync().buffer.asByteData()));
  }
  await icons.load();
}

PlayContext _ctx(GeneratedLevel gl, [String lang = 'tr']) => PlayContext(
      spec: gl.spec,
      generated: gl,
      resume: const {},
      pieceColors: const [Color(0xFF3E6FB0), Color(0xFFC8553D)],
      background: const [Color(0xFF1A2E5C), Color(0xFF3A6FC4)],
      colorBlind: false,
      reducedMotion: false,
      leftHanded: false,
      lang: lang,
      t: (k, [p = const {}]) => k,
      finish: (_) {},
      saveResume: (_) {},
      requestHint: () async => true,
      requestBooster: () async => true,
      requestContinue: () async => false,
      sfx: (_) {},
    );

final _key = GlobalKey();

Widget _host(Widget child, Color seed, [String lang = 'tr']) => RepaintBoundary(
      key: _key,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
            colorSchemeSeed: seed,
            fontFamily: 'Roboto',
            fontFamilyFallback: const ['NotoArabic', 'NotoCJK'],
            extensions: [StudioLook.fromSeed(seed)]),
        home: Scaffold(
          body: DecoratedBox(
            decoration: const BoxDecoration(
                gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF1B2347), Color(0xFF2B3C78)])),
            child: SafeArea(child: Directionality(textDirection: lang == 'ar' ? TextDirection.rtl : TextDirection.ltr, child: child)),
          ),
        ),
      ),
    );

Future<void> _snap(WidgetTester t, String name) async {
  await t.runAsync(() async {
    final b = _key.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final img = await b.toImage(pixelRatio: 1);
    final data = await img.toByteData(format: ui.ImageByteFormat.png);
    final f = File('build/shots/$name.png')..createSync(recursive: true);
    f.writeAsBytesSync(data!.buffer.asUint8List());
  });
}

/// Oyun kimliği → tohum rengi (ince depolardaki seedColor).
const _seeds = {
  'sudoku': Color(0xFF3D5A80),
  'killer-sudoku': Color(0xFF8C3B4A),
  'kakuro': Color(0xFF6B4E71),
  'nonogram': Color(0xFF2E4057),
  'kraliceler': Color(0xFFA4485E),
  'su-siralama': Color(0xFF3F88C5),
  '2048': Color(0xFFE88A5A),
  'mayin-tarlasi': Color(0xFF66A182),
  'araba-cikarma': Color(0xFFD1495B),
  'renk-akisi': Color(0xFF3F88C5),
  'kopruler': Color(0xFF3F88C5),
  'cadirlar': Color(0xFF4E8A5B),
  'slitherlink': Color(0xFF8A5A34),
  'futoshiki': Color(0xFF66A182),
  'hitori': Color(0xFF5468B8),
  'top-siralama': Color(0xFFD1495B),
};

void main() {
  if (!_on) return;
  final ids = const String.fromEnvironment('IDS').isEmpty ? _seeds.keys.toList() : const String.fromEnvironment('IDS').split(',');
  final levels = const String.fromEnvironment('LV').isEmpty ? const [1, 5, 10] : [for (final s in const String.fromEnvironment('LV').split(',')) int.parse(s)];
  for (final id in ids) {
    testWidgets('shots $id', (t) async {
      await _fonts();
      for (final dev in const [('p', Size(393, 852)), ('t', Size(1280, 800))]) {
        t.view.physicalSize = dev.$2;
        t.view.devicePixelRatio = 1;
        for (final lv in dev.$1 == 't' ? [levels.last] : levels) {
          final rules = gridRules('oyun-$id', id);
          final planner = LevelPlanner(gameId: rules.gameId, optionalMechanics: const []);
          final gl = rules.build(planner.spec(lv));
          await t.pumpWidget(_host(PuzzleView(key: ValueKey('$id$lv${dev.$1}'), ctx: _ctx(gl), rules: rules), _seeds[id] ?? const Color(0xFF5468B8)));
          await t.pump(const Duration(milliseconds: 200));
          await _snap(t, '${id}_L${lv}_${dev.$1}_0acilis');
          if (dev.$1 == 't') continue;
          // Oyun ortası: birkaç ipucu + bir hücre seçimi
          final hint = find.byIcon(Icons.lightbulb_outline);
          if (hint.evaluate().isNotEmpty) {
            final p = gl.puzzle;
            final todo = p.givens.where((g) => g < 0).length;
            for (var k = 0; k < (todo ~/ 3).clamp(2, 12); k++) {
              await t.tap(hint);
              await t.pump(const Duration(milliseconds: 30));
            }
          }
          if (find.byIcon(Icons.edit_note).evaluate().isNotEmpty) {
            await t.tap(find.byIcon(Icons.edit_note));
            await t.pump();
            final keys = find.byType(InkWell);
            for (var k = 0; k < 3 && k < keys.evaluate().length; k++) {
              await t.tap(keys.at(keys.evaluate().length - 2 - k), warnIfMissed: false);
              await t.pump();
            }
          }
          await t.pump(const Duration(milliseconds: 200));
          await _snap(t, '${id}_L${lv}_${dev.$1}_1orta');
          // Çözüm: ipucuyla bitir, kutlama ortasında görüntü
          if (hint.evaluate().isNotEmpty && lv == levels.first) {
            for (var k = 0; k < 120; k++) {
              if (hint.evaluate().isEmpty) break;
              await t.tap(hint, warnIfMissed: false);
              await t.pump(const Duration(milliseconds: 20));
            }
            await t.pump(const Duration(milliseconds: 450));
            await _snap(t, '${id}_L${lv}_${dev.$1}_2cozum');
          }
          await t.pumpWidget(const SizedBox());
          await t.pump(const Duration(seconds: 2));
        }
      }
      // Dil: Arapça (RTL) ve Japonca birer görüntü (ilk tür, 5. bölüm).
      if (id == ids.first) {
        t.view.physicalSize = const Size(393, 852);
        t.view.devicePixelRatio = 1;
        for (final lang in const ['ar', 'ja']) {
          final rules = gridRules('oyun-$id', id);
          final planner = LevelPlanner(gameId: rules.gameId, optionalMechanics: const []);
          final gl = rules.build(planner.spec(5));
          await t.pumpWidget(_host(PuzzleView(key: ValueKey('$id$lang'), ctx: _ctx(gl, lang), rules: rules), _seeds[id] ?? const Color(0xFF5468B8), lang));
          await t.pump(const Duration(milliseconds: 200));
          await _snap(t, '${id}_L5_p_dil_$lang');
          await t.pumpWidget(const SizedBox());
          await t.pump(const Duration(seconds: 2));
        }
      }
      t.view.reset();
    }, timeout: const Timeout(Duration(minutes: 5)));
  }
}
