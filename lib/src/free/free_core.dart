import 'package:studio_core/core/game_rules.dart';
import 'package:studio_core/core/level_plan.dart';
import 'package:studio_core/core/missions.dart';
import 'package:studio_core/core/rng.dart';
import 'package:studio_core/core/stats.dart';
import '../core.dart' show campaignDifficulty;

/// Serbest biçimli bulmaca bölümü (ızgara dışı oyunlar: domino koşulları,
/// pim çekme, tuzaklı bilmeceler). Türe özgü veriler JSON uyumlu sözlükte.
class FLevel {
  final String kind;
  final int difficulty;
  final int seed;
  final Map<String, Object?> data;

  const FLevel(this.kind, this.difficulty, this.seed, this.data);

  List<int> ints(String k) => [for (final v in (data[k] as List? ?? const [])) (v as num).toInt()];
  int i(String k, [int def = 0]) => (data[k] as num?)?.toInt() ?? def;

  Map<String, Object?> toJson() => {'k': kind, 'd': difficulty, 's': seed, 'x': data};

  factory FLevel.fromJson(Map<String, Object?> j) =>
      FLevel(j['k'] as String, (j['d'] as num).toInt(), (j['s'] as num).toInt(), Map<String, Object?>.from(j['x'] as Map));
}

/// Serbest bulmacanın saf Dart mantığı: üretim ve doğrulama (Flutter'sız).
abstract class FreeLogic {
  const FreeLogic();
  String get id;

  /// Zorluk 1..10 için bölüm üretir (çözümü ya da çözüm yolu içinde).
  FLevel make(int d, SeededRandom r);

  /// Bölüm kurallara uygun ve çözülebilir mi: null = uygun, yoksa neden.
  String? check(FLevel lv);

  List<GameStat> get stats => const [
        GameStat('puzzles_solved', 'Çözülen bulmaca', 'Puzzles solved', scale: 10),
        GameStat('clean_solves', 'İpucusuz çözüm', 'Solved without hints', scale: 5),
      ];

  List<MissionTemplate> get missions => const [
        MissionTemplate('solve', 'puzzles_solved', [3, 10, 25]),
        MissionTemplate('clean', 'clean_solves', [1, 4, 10]),
      ];
}

/// Serbest bulmacaların oyun kuralları.
class FreeRules extends GameRules<FLevel> {
  @override
  final String gameId;
  final FreeLogic logic;
  final int levels;

  FreeRules({required this.gameId, required this.logic, this.levels = 100000});

  @override
  int get levelCount => levels;

  @override
  List<String> get optionalMechanics => const [];

  @override
  List<GameModeId> get modes => const [GameModeId.campaign, GameModeId.daily, GameModeId.weekly, GameModeId.challenge];

  @override
  List<GameStat> get gameStats => logic.stats;

  @override
  List<MissionTemplate> get missionTemplates => logic.missions;

  @override
  FLevel generate(LevelSpec spec) {
    final d = campaignDifficulty(spec).clamp(1, 10);
    try {
      return logic.make(d, SeededRandom(mixSeed([spec.seed, 8117])));
    } catch (_) {
      return logic.make(1, SeededRandom(mixSeed([spec.seed, 8118])));
    }
  }

  @override
  Validation validate(FLevel puzzle, LevelSpec spec) {
    if (puzzle.kind != logic.id) return const Validation.fail('kind mismatch');
    final why = logic.check(puzzle);
    return why == null ? const Validation.ok() : Validation.fail(why);
  }
}
