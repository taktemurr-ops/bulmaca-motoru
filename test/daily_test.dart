import 'package:bulmaca_motoru/bulmaca_motoru.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studio_core/core/global_daily.dart';
import 'package:studio_core/core/level_plan.dart';

/// Günün Bulmacası: her bulmaca türü herkese aynı, doğrulanmış günlük bölüm verir.
void main() {
  final days = [for (var i = 0; i < 3; i++) GlobalDaily.shift('2026-11-23', i)];
  final rules = <String, PuzzleRules>{
    for (final id in kGridKinds.keys) 'oyun-$id': gridRules('oyun-$id', id),
    for (final v in kSudokuPack.keys) 'oyun-sudoku-$v': sudokuPackRules('oyun-sudoku-$v', v),
  };
  for (final e in rules.entries) {
    test('${e.key}: günlük bölüm belirlenimci ve geçerli', () {
      final r = e.value;
      expect(r.globalDaily, isTrue);
      expect(r.dailyRank, DailyRank.time);
      for (final d in days) {
        final a = r.globalDailySpec(d), b = r.globalDailySpec(d);
        expect(a.seed, b.seed);
        expect(a.mode, GameModeId.daily);
        final g1 = r.build(a);
        expect(g1.validation.ok, isTrue, reason: '${e.key} $d ${g1.validation.reason}');
        expect(r.build(b).puzzle.toJson(), g1.puzzle.toJson(), reason: '${e.key} $d herkese aynı');
      }
      expect(r.globalDailySpec(days[0]).seed, isNot(r.globalDailySpec(days[1]).seed));
    });
  }
}
