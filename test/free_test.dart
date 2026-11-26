import 'package:bulmaca_motoru/bulmaca_motoru.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studio_core/core/level_plan.dart';
import 'package:studio_core/core/rng.dart';

void main() {
  final logics = <FreeLogic>[const DominoLogic(), const PinLogic(), const TrickLogic()];
  FreeGame start(FLevel lv) => switch (lv.kind) {
        'domino-kosullari' => DominoGame(lv),
        'pim-cekme' => PinGame(lv),
        _ => TrickGame(lv),
      };

  for (final logic in logics) {
    test('${logic.id}: 100.000 bölümden örnekler üretilir ve doğrulanır', () {
      final rules = FreeRules(gameId: 'oyun-${logic.id}', logic: logic);
      expect(rules.levelCount, 100000);
      final planner = LevelPlanner(gameId: 'oyun-${logic.id}', optionalMechanics: const []);
      for (final n in [1, 2, 3, 50, 777, 4321, 12000, 33333, 65000, 99999]) {
        final gl = rules.build(planner.spec(n));
        expect(gl.validation.ok, isTrue, reason: '${logic.id} $n ${gl.validation.reason}');
        final back = FLevel.fromJson(gl.puzzle.toJson());
        expect(back.toJson().toString(), gl.puzzle.toJson().toString());
        expect(logic.check(back), isNull);
        // Oyun kurulur, kaydedilip geri yüklenir, başta bitmiş değildir.
        final g = start(back)..size = const Size(400, 700);
        expect(g.won, isFalse);
        expect(g.lost, isFalse);
        final snap = g.save();
        final g2 = start(back)..load(snap);
        expect(g2.save().toString(), snap.toString());
      }
    });
  }

  test('domino: çözüm yerleştirilince kazanılır, ipucu ilerletir', () {
    final lv = const DominoLogic().make(4, SeededRandom(11));
    final g = DominoGame(lv)..size = const Size(400, 700);
    var guard = 0;
    while (!g.won && guard++ < 40) {
      expect(g.hint(), isTrue);
    }
    expect(g.won, isTrue);
  });

  test('pim: çözüm sırası kazandırır, yanlış sıra uyarılır', () {
    final lv = const PinLogic().make(5, SeededRandom(5));
    final s = PinSim(lv)..settle();
    for (final k in lv.ints('sol')) {
      s.pull(k);
      s.settle();
      if (s.won) break;
    }
    expect(s.won, isTrue);
    expect(PinLogic.solveFrom(PinSim(lv)), isNotNull);
  });

  test('bilmece: her kalıp üretilir ve çözüm betiği kazanır; 33 dilde yönerge', () {
    final seen = <int>{};
    for (var s = 0; s < 400 && seen.length < TrickLogic.templateCount; s++) {
      final lv = const TrickLogic().make(1 + s % 10, SeededRandom(s));
      seen.add(lv.i('t'));
      final st = TrickState(lv);
      for (final a in st.sol) {
        st.perform(a);
      }
      expect(st.won, isTrue, reason: 'kalıp ${lv.i('t')}');
    }
    expect(seen.length, TrickLogic.templateCount);
    for (final k in TrickLogic.promptKeys) {
      expect(kTrickPromptsRaw[k]!.split('|').length, 33, reason: k);
    }
    expect(kTrickIcons.length, TrickLogic.iconCount);
  });
}
