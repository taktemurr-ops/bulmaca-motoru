import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bulmaca_motoru/bulmaca_motoru.dart';
import 'package:bulmaca_motoru/src/board_style.dart';
import 'package:bulmaca_motoru/src/studio_chrome.dart';
import 'package:studio_core/app/game_api.dart';
import 'package:studio_core/core/game_rules.dart';
import 'package:studio_core/core/level_plan.dart';

PlayContext _ctx(GeneratedLevel gl, {bool reduced = true, void Function(RoundResult r)? done}) => PlayContext(
      spec: gl.spec,
      generated: gl,
      resume: const {},
      pieceColors: const [Color(0xFF3E6FB0), Color(0xFFC8553D)],
      background: const [Color(0xFF1A2E5C), Color(0xFF3A6FC4)],
      colorBlind: false,
      reducedMotion: reduced,
      leftHanded: false,
      lang: 'tr',
      t: (k, [p = const {}]) => k,
      finish: done ?? (_) {},
      saveResume: (_) {},
      requestHint: () async => true,
      requestBooster: () async => true,
      requestContinue: () async => false,
      sfx: (_) {},
    );

Widget _host(Widget child) => MaterialApp(
      theme: ThemeData(brightness: Brightness.light, extensions: const [StudioLook()]),
      home: Scaffold(body: SafeArea(child: child)),
    );

void main() {
  test('kampanya zorluk eğrisi: 1. bölüm en kolay, 5. orta-kolay, 10. en az 4', () {
    final planner = LevelPlanner(gameId: 'oyun-sudoku', optionalMechanics: const []);
    expect(campaignDifficulty(planner.spec(1)), 1);
    expect(campaignDifficulty(planner.spec(2)), greaterThanOrEqualTo(2));
    expect(campaignDifficulty(planner.spec(5)), greaterThanOrEqualTo(3));
    expect(campaignDifficulty(planner.spec(10)), greaterThanOrEqualTo(4));
    expect(campaignDifficulty(planner.spec(500)), planner.spec(500).difficulty);
  });

  test('Sudoku: 1. bölüm 4x4, 2. 6x6, 5. bölümden itibaren 9x9', () {
    final rules = gridRules('oyun-sudoku', 'sudoku');
    final planner = LevelPlanner(gameId: rules.gameId, optionalMechanics: const []);
    expect(rules.build(planner.spec(1)).puzzle.w, 4);
    expect(rules.build(planner.spec(2)).puzzle.w, 6);
    for (final l in [5, 10]) {
      final gl = rules.build(planner.spec(l));
      expect(gl.validation.ok, isTrue);
      expect(gl.puzzle.w, 9);
    }
  });

  test('her oyunun tahtası kendine özgü: aileler ve vurgu renkleri ayrışır', () {
    final looks = <String>{};
    for (final id in kGridKinds.keys) {
      final s = BoardStyle.of('oyun-$id', id, Color(0xFF000000 | (id.hashCode & 0xFFFFFF)));
      looks.add('${s.texture}|${s.frame}|${s.paper.toARGB32()}');
    }
    expect(looks.length, greaterThanOrEqualTo(14));
    // Paket içindeki tür tek başına oyundan farklı görünür.
    final a = BoardStyle.of('oyun-nonogram', 'nonogram', Colors.blue);
    final b = BoardStyle.of('oyun-mantik-bulmacasi-uzun-kuyrugu-nonogram-mini', 'nonogram', Colors.blue);
    expect(a.texture == b.texture && a.paper == b.paper, isFalse);
  });

  testWidgets('Sudoku: not kipi, rakam yerleştirince komşu notlar silinir, geri al notları geri getirir', (t) async {
    t.view.physicalSize = const Size(1080, 2340);
    t.view.devicePixelRatio = 2.75;
    addTearDown(t.view.reset);
    final rules = gridRules('oyun-sudoku', 'sudoku');
    final planner = LevelPlanner(gameId: rules.gameId, optionalMechanics: const []);
    final gl = rules.build(planner.spec(5));
    await t.pumpWidget(_host(PuzzleView(ctx: _ctx(gl), rules: rules)));
    await t.pump(const Duration(milliseconds: 300));
    expect(find.byIcon(Icons.edit_note), findsOneWidget);
    // boş bir hücreye dokun
    final p = gl.puzzle;
    final empty = [for (var i = 0; i < p.n; i++) if (p.givens[i] < 0) i];
    final paint = find.byWidgetPredicate((w) => w is CustomPaint && w.painter != null && w.painter.runtimeType.toString() == '_GridPainter');
    expect(paint, findsOneWidget);
    final box = t.getRect(paint);
    // tahtanın sol üst köşesi ve hücre boyu painter ile aynı formülle
    final cs = (box.width - 16) / (9 + 0.6) < (box.height - 16) / (9 + 0.6) ? (box.width - 16) / 9.6 : (box.height - 16) / 9.6;
    final origin = box.topLeft + Offset((box.width - cs * 9) / 2, (box.height - cs * 9) / 2);
    Offset at(int i) => origin + Offset((i % 9 + 0.5) * cs, (i ~/ 9 + 0.5) * cs);
    final a = empty.first;
    await t.tapAt(at(a));
    await t.pump();
    await t.tap(find.byIcon(Icons.edit_note));
    await t.pump();
    final v = p.solCells[a];
    final w = (v % 9) + 1;
    await t.tap(find.text('$w').last);
    await t.pump();
    await t.tap(find.text('$v').last);
    await t.pump();
    expect(t.takeException(), isNull);
    // not kipini kapat, rakam yerleştir
    await t.tap(find.byIcon(Icons.edit_note));
    await t.pump();
    await t.tap(find.text('$v').last);
    await t.pump();
    expect(t.takeException(), isNull);
    await t.tap(find.byIcon(Icons.undo));
    await t.pump();
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 2));
  });

  testWidgets('Çözüm kutlaması: son hamleden sonra sonuç bildirilir', (t) async {
    t.view.physicalSize = const Size(1080, 2340);
    t.view.devicePixelRatio = 2.75;
    addTearDown(t.view.reset);
    final rules = gridRules('oyun-sudoku', 'sudoku');
    final planner = LevelPlanner(gameId: rules.gameId, optionalMechanics: const []);
    final gl = rules.build(planner.spec(1));
    RoundResult? res;
    await t.pumpWidget(_host(PuzzleView(ctx: _ctx(gl, reduced: false, done: (r) => res = r), rules: rules)));
    await t.pump(const Duration(milliseconds: 300));
    // İpucu düğmesiyle bütün boşlukları doldur.
    final p = gl.puzzle;
    final empty = p.givens.where((g) => g < 0).length;
    for (var k = 0; k < empty; k++) {
      await t.tap(find.byIcon(Icons.lightbulb_outline));
      await t.pump(const Duration(milliseconds: 50));
    }
    await t.pump(const Duration(milliseconds: 600));
    expect(res, isNull, reason: 'kutlama sürerken sonuç ekranı açılmamalı');
    await t.pump(const Duration(milliseconds: 900));
    expect(res?.won, isTrue);
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 2));
  });

  testWidgets('Nonogram: doldur/işaretle kalemi ve mayın sonrası devam teklifi hatasız', (t) async {
    t.view.physicalSize = const Size(1080, 2340);
    t.view.devicePixelRatio = 2.75;
    addTearDown(t.view.reset);
    for (final id in const ['nonogram', 'mayin-tarlasi', 'hitori']) {
      final rules = gridRules('oyun-$id', id);
      final planner = LevelPlanner(gameId: rules.gameId, optionalMechanics: const []);
      final gl = rules.build(planner.spec(5));
      await t.pumpWidget(_host(PuzzleView(key: ValueKey(id), ctx: _ctx(gl), rules: rules)));
      await t.pump(const Duration(milliseconds: 300));
      if (id != 'mayin-tarlasi') {
        expect(find.byIcon(Icons.close_rounded), findsOneWidget, reason: id);
        await t.tap(find.byIcon(Icons.close_rounded));
        await t.pump();
      }
      final size = t.view.physicalSize / t.view.devicePixelRatio;
      for (var k = 0; k < 12; k++) {
        await t.tapAt(Offset(size.width * (0.2 + 0.05 * k), size.height * (0.3 + 0.03 * k)));
        await t.pump(const Duration(milliseconds: 100));
      }
      await t.pump(const Duration(seconds: 2));
      expect(t.takeException(), isNull, reason: id);
    }
    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 2));
  });
}
