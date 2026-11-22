import 'package:bulmaca_motoru/bulmaca_motoru.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studio_core/core/level_plan.dart';

void main() {
  const only = String.fromEnvironment('KINDS');
  final ids = only.isEmpty ? kGridKinds.keys.toList() : only.split(',');
  for (final id in ids) {
    test('$id: üretim, doğrulama, çözüm kabulü', () {
      final rules = gridRules('oyun-$id', id);
      final planner = LevelPlanner(gameId: 'oyun-$id', optionalMechanics: const []);
      for (final lv in [1, 800, 6000, 40000, 99000]) {
        final sw = Stopwatch()..start();
        final gl = rules.build(planner.spec(lv));
        final ms = sw.elapsedMilliseconds;
        expect(gl.validation.ok, isTrue, reason: '$id $lv ${gl.validation.reason}');
        final k = rules.kindFor(gl.spec.difficulty);
        final p = gl.puzzle;
        final sol = PState(
          p.solCells.isEmpty ? List.filled(p.n, 0) : List.of(p.solCells),
          p.solLinks.isEmpty ? List.filled(p.linkCount, 0) : List.of(p.solLinks),
          p.solBorders.isEmpty ? List.filled(p.borderCount, 0) : List.of(p.solBorders),
        );
        final toggles = id == 'isiklari-sondur' || id == 'cevir' || k.actionMode;
        expect(toggles ? k.ok(p, sol, true) : k.solved(p, sol), isTrue, reason: '$id $lv çözüm kabul edilmedi');
        final start = k.initial(p);
        if (k.actionMode) {
          // başlangıç durumu kurulabilmeli ve oyun başta bitmiş olmamalı
          expect(k.failed(p, start), isFalse, reason: '$id $lv başta kaybedilmiş');
          PState.restore(start.serialize(), p);
        }
        if (!k.actionMode && (!kNonUniqueKinds.contains(id) || id == 'boru-dondurme')) {
          expect(k.solved(p, start), isFalse, reason: '$id $lv başlangıç çözülmüş');
        }
        final sw2 = Stopwatch()..start();
        final c = rules.unique ? k.countSolutions(p, budget: 300000) : -1;
        final given = p.givens.where((g) => g >= 0).length + p.givenLinks.where((g) => g >= 0).length + p.givenBorders.where((g) => g >= 0).length;
        // ignore: avoid_print
        print('$id $lv d=${gl.spec.difficulty} ${p.w}x${p.h} given=$given sols=$c gen=${ms}ms count=${sw2.elapsedMilliseconds}ms attempts=${gl.attempts}');
        final back = PLevel.fromJson(p.toJson());
        expect(back.toJson().toString(), p.toJson().toString());
      }
    }, timeout: const Timeout(Duration(minutes: 6)));
  }
}
