import 'package:bulmaca_motoru/bulmaca_motoru.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studio_core/core/level_plan.dart';

void main() {
  final variants = <String, SudokuSpec>{
    'klasik4': const SudokuSpec(4, {}),
    'klasik6': const SudokuSpec(6, {}),
    'klasik9': const SudokuSpec(9, {}),
    'x': const SudokuSpec(9, {SRule.diag}),
    'hiper': const SudokuSpec(9, {SRule.hyper}),
    'parca': const SudokuSpec(9, {SRule.jigsaw}),
    'kafes': const SudokuSpec(9, {SRule.killer}),
    'termo': const SudokuSpec(9, {SRule.thermo}),
    'ok': const SudokuSpec(9, {SRule.arrow}),
    'nokta': const SudokuSpec(9, {SRule.kropki}),
    'xv': const SudokuSpec(9, {SRule.xv}),
    'buyuk': const SudokuSpec(6, {SRule.greater}),
    'sandvic': const SudokuSpec(9, {SRule.sandwich}),
    'ciftTek': const SudokuSpec(9, {SRule.evenOdd}),
    'at': const SudokuSpec(9, {SRule.antiKnight}),
    'sah': const SudokuSpec(9, {SRule.antiKing}),
    'ardisikYok': const SudokuSpec(9, {SRule.nonConsec}),
    'ayrik': const SudokuSpec(9, {SRule.disjoint}),
    'cizgi': const SudokuSpec(9, {SRule.palindrome, SRule.renban, SRule.whisper}),
  };
  variants.forEach((name, spec) {
    test('sudoku $name: üretim, tek çözüm, doğrulama', () {
      final rules = PuzzleRules(gameId: 'sudoku-$name', kindFor: (_) => SudokuKind('sudoku-$name', (_) => spec));
      final planner = LevelPlanner(gameId: 'sudoku-$name', optionalMechanics: const []);
      for (final lv in [1, 500, 30000]) {
        final sw = Stopwatch()..start();
        final gl = rules.build(planner.spec(lv));
        expect(gl.validation.ok, isTrue, reason: '$name $lv');
        final k = rules.kindFor(gl.spec.difficulty);
        final c = k.countSolutions(gl.puzzle, budget: 400000);
        final given = gl.puzzle.givens.where((g) => g >= 0).length;
        // ignore: avoid_print
        print('$name $lv d=${gl.spec.difficulty} given=$given sols=$c ${sw.elapsedMilliseconds}ms');
        final solved = PState(List.of(gl.puzzle.solCells), const [], const []);
        expect(k.solved(gl.puzzle, PState(solved.cells, List.filled(gl.puzzle.linkCount, 0), List.filled(gl.puzzle.borderCount, 0))), isTrue);
        final back = PLevel.fromJson(gl.puzzle.toJson());
        expect(back.toJson().toString(), gl.puzzle.toJson().toString());
      }
    }, timeout: const Timeout(Duration(minutes: 5)));
  });
}
