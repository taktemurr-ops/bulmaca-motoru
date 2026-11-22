import 'core.dart';
import 'digits.dart';
import 'lines.dart';
import 'numpath.dart';
import 'regions.dart';
import 'shade1.dart';
import 'shade2.dart';
import 'sudoku.dart';

/// Izgara bulmaca türleri: oyun kimliği → zorluğa göre tür.
/// Benzersiz çözüm denetimi yapılmayan türler [kNonUniqueKinds] içinde.
final Map<String, PuzzleKind Function(int d)> kGridKinds = {
  'sudoku': (_) => SudokuKind('sudoku', (d) => SudokuSpec(d <= 1 ? 4 : (d <= 2 ? 6 : 9), const {})),
  'killer-sudoku': (_) => SudokuKind('killer-sudoku', (d) => SudokuSpec(d <= 2 ? 6 : 9, const {SRule.killer})),
  'kakuro': (_) => const KakuroKind(),
  'hesap-kutusu': (_) => const CalcBoxKind(),
  'futoshiki': (_) => const InequalityKind(),
  'gokdelenler': (_) => const SkylineKind(),
  'suguru': (_) => const GroupKind(),
  'sayi-yolu': (_) => const NumberPathKind('sayi-yolu', 0),
  'at-turu': (_) => const NumberPathKind('at-turu', 1),
  'tabela': (_) => const NumberPathKind('tabela', 2),
  'fillomino': (_) => const FillKind(),
  'matematik-cengeli': (_) => const MathCrossKind(),
  'nonogram': (_) => const NonogramKind(),
  'renkli-nonogram': (_) => const NonogramKind(colored: true),
  'hitori': (_) => const HitoriKind(),
  'nurikabe': (_) => const IslandKind(),
  'heyawake': (_) => const RoomsKind(),
  'menzil': (_) => const SightKind(),
  'kuromasu': (_) => const SightKind(includeSelf: false),
  'isik-yak': (_) => const LightKind(),
  'mozaik': (_) => const MosaicKind(),
  'kakurasu': (_) => const IndexSumKind(),
  'sumplete': (_) => const SumDeleteKind(),
  'binairo': (_) => const BinaryKind(),
  'yildiz-savasi': (_) => const StarKind(),
  'kraliceler': (_) => const StarKind(queens: true),
  'cadirlar': (_) => const TentKind(),
  'gemiler': (_) => const FleetKind(),
  'akvaryum': (_) => const AquariumKind(),
  'norinori': (_) => const PairShadeKind(),
  'lits': (_) => const TetroKind(),
  'tapa': (_) => const TapKind(),
  'miknatislar': (_) => const MagnetKind(),
  'isiklari-sondur': (_) => const TogglesKind(),
  'cevir': (_) => const TogglesKind(perCell: true),
  'slitherlink': (_) => const LoopEdgeKind(),
  'inci': (_) => const PearlKind(),
  'yajilin': (_) => const ArrowLoopKind(),
  'raylar': (_) => const TrackKind(),
  'kopruler': (_) => const BridgeKind(),
  'sayi-baglama': (_) => const PathLinkKind(),
  'tek-cizgi': (_) => const PathLinkKind(single: true),
  'egik-cizgi': (_) => const SlantKind(),
  'galaksiler': (_) => const GalaxyKind(),
  'cit': (_) => const FenceKind(),
  'dikdortgenler': (_) => const RectKind(),
  'dominosa': (_) => const DominoPairKind(),
  'boru-dondurme': (_) => const PipeKind(),
  'harita-boyama': (_) => const MapColorKind(),
};

/// Çözümü birden çok olabilen (kurala uyan her yanıt kabul) türler.
const kNonUniqueKinds = {'isiklari-sondur', 'cevir', 'galaksiler', 'cit', 'boru-dondurme'};

/// Oyun kuralları.
PuzzleRules gridRules(String gameId, String kind, {int levels = 100000}) =>
    PuzzleRules(gameId: gameId, kindFor: kGridKinds[kind]!, levels: levels, unique: !kNonUniqueKinds.contains(kind));
