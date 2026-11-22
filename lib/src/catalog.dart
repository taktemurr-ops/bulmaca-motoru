import 'core.dart';
import 'digits.dart';
import 'lines.dart';
import 'move1.dart';
import 'move2.dart';
import 'move3.dart';
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
  'sayi-baglama': (_) => const PathLinkKind(fill: false),
  'renk-akisi': (_) => const PathLinkKind(),
  'sekiz-vezir': (_) => const QueensKind(),
  'at-turu-ve-8-vezir': (d) => d.isOdd ? const NumberPathKind('at-turu', 1) : const QueensKind(),
  'sudoku-cesitleri': (_) => SudokuKind('sudoku-cesitleri', (d) => SudokuSpec(9, const [{SRule.diag}, {SRule.jigsaw}, {SRule.hyper}][d % 3])),
  'tek-cizgi': (_) => const PathLinkKind(single: true),
  'egik-cizgi': (_) => const SlantKind(),
  'galaksiler': (_) => const GalaxyKind(),
  'cit': (_) => const FenceKind(),
  'dikdortgenler': (_) => const RectKind(),
  'dominosa': (_) => const DominoPairKind(),
  'boru-dondurme': (_) => const PipeKind(),
  'harita-boyama': (_) => const MapColorKind(),
  '2048': (_) => const MergeSlideKind(),
  'sayi-birlestirme': (_) => const ChainMergeKind(),
  'kayan-sayilar': (_) => const SlidingKind(),
  'resim-kaydirma': (_) => const SlidingKind(picture: true),
  'dondur': (_) => const TwiddleKind(),
  'on-alti': (_) => const ShiftKind(),
  'kaydirmali-ag': (_) => const NetSlideKind(),
  'hanoi-kulesi': (_) => const HanoiKind(),
  'tas-ziplatma': (_) => const PegJumpKind(),
  'sayi-eslestirme': (_) => const NumberMatchKind(),
  'mayin-tarlasi': (_) => const MinesKind(),
  'kara-kutu': (_) => const BlackBoxKind(),
  'kod-kirici': (_) => const CodeKind(),
  'su-siralama': (_) => const SortKind(0),
  'top-siralama': (_) => const SortKind(1),
  'vida-sokme': (_) => const SortKind(2),
  'altigen-siralama': (_) => const SortKind(3),
  'ok-kacisi': (_) => const EscapeKind(),
  'tikla-kaldir-taslar': (_) => const EscapeKind(blocks: true),
  'otobus-yolcu-sikismasi': (_) => const BusKind(),
  'araba-cikarma': (_) => const SlideBlockKind(),
  'kayan-bloklar': (_) => const SlideBlockKind(klotski: true),
  'sokoban': (_) => const BoxPushKind(),
  'buz-kaydirma': (_) => const IceKind(),
  'atalet': (_) => const IceKind(inertia: true),
  'labirent': (_) => const MazeKind(),
  'tangram': (_) => const TangramKind(),
  'yapboz': (_) => const JigsawKind(),
  'cozme': (_) => const UntangleKind(),
  'ip-cozme': (_) => const UntangleKind(ropes: true),
  'fizik-cizgi-bulmacasi': (_) => const LinePhysicsKind(),
  'sihirli-kup': (_) => const CubeKind(),
  'hayaletler': (_) => const MirrorKind(),
  'mantik-izgarasi': (_) => const ZebraKind(),
};

/// Hamle oyunları (benzersizlik ve hücre çözümü yok).
bool isMoveKind(String id) => kGridKinds[id]!(1).actionMode;

/// Çözümü birden çok olabilen (kurala uyan her yanıt kabul) türler.
const kNonUniqueKinds = {'isiklari-sondur', 'cevir', 'galaksiler', 'cit', 'boru-dondurme'};

bool _nonUnique(String id) => kNonUniqueKinds.contains(id) || isMoveKind(id);

/// Oyun kuralları.
PuzzleRules gridRules(String gameId, String kind, {int levels = 100000}) =>
    PuzzleRules(gameId: gameId, kindFor: kGridKinds[kind]!, levels: levels, unique: !_nonUnique(kind));

/// Sudoku çeşit paketi: 30 kural birleşimi.
final Map<String, SudokuSpec Function(int d)> kSudokuPack = {
  'mini': (_) => const SudokuSpec(4, {}),
  'alti': (_) => const SudokuSpec(6, {}),
  'sekiz': (_) => const SudokuSpec(8, {}),
  'capraz': (_) => const SudokuSpec(9, {SRule.diag}),
  'pencere': (_) => const SudokuSpec(9, {SRule.hyper}),
  'parcali': (d) => SudokuSpec(d <= 3 ? 6 : 9, const {SRule.jigsaw}),
  'kafes': (_) => const SudokuSpec(9, {SRule.killer}),
  'termometre': (_) => const SudokuSpec(9, {SRule.thermo}),
  'ok': (_) => const SudokuSpec(9, {SRule.arrow}),
  'nokta': (_) => const SudokuSpec(9, {SRule.kropki}),
  'xv': (_) => const SudokuSpec(9, {SRule.xv}),
  'buyuk-kucuk': (d) => SudokuSpec(d <= 4 ? 6 : 9, const {SRule.greater}),
  'sandvic': (_) => const SudokuSpec(9, {SRule.sandwich}),
  'cift-tek': (_) => const SudokuSpec(9, {SRule.evenOdd}),
  'at-hamlesi': (_) => const SudokuSpec(9, {SRule.antiKnight}),
  'sah-hamlesi': (_) => const SudokuSpec(9, {SRule.antiKing}),
  'ardisik-yok': (_) => const SudokuSpec(9, {SRule.nonConsec}),
  'ayrik-gruplar': (_) => const SudokuSpec(9, {SRule.disjoint}),
  'merkez-nokta': (_) => const SudokuSpec(9, {SRule.centerDot}),
  'yildiz': (_) => const SudokuSpec(9, {SRule.asterisk}),
  'palindrom': (_) => const SudokuSpec(9, {SRule.palindrome}),
  'ardisik-cizgi': (_) => const SudokuSpec(9, {SRule.renban}),
  'fisilti': (_) => const SudokuSpec(9, {SRule.whisper}),
  'ardisik-nokta': (_) => const SudokuSpec(9, {SRule.consecutive}),
  'toplamsiz-kafes': (_) => const SudokuSpec(9, {SRule.cageNoSum}),
  'capraz-parcali': (_) => const SudokuSpec(9, {SRule.diag, SRule.jigsaw}),
  'capraz-pencere': (_) => const SudokuSpec(9, {SRule.diag, SRule.hyper}),
  'capraz-kafes': (_) => const SudokuSpec(9, {SRule.diag, SRule.killer}),
  'termometre-ok': (_) => const SudokuSpec(9, {SRule.thermo, SRule.arrow}),
  'capraz-sah': (_) => const SudokuSpec(9, {SRule.diag, SRule.antiKing}),
};

/// Sudoku paketinden bir çeşidin kuralları.
PuzzleRules sudokuPackRules(String gameId, String variant) =>
    PuzzleRules(gameId: gameId, kindFor: (_) => SudokuKind(gameId, kSudokuPack[variant]!));

/// Mantık bulmacası uzun kuyruğu: 30 tür × iki boyut (küçük ve büyük).
const kLogicTail = [
  'hitori', 'nurikabe', 'heyawake', 'menzil', 'kuromasu', 'isik-yak', 'mozaik', 'kakurasu', 'sumplete', 'binairo',
  'yildiz-savasi', 'kraliceler', 'cadirlar', 'gemiler', 'akvaryum', 'norinori', 'lits', 'tapa', 'miknatislar', 'slitherlink',
  'inci', 'yajilin', 'raylar', 'kopruler', 'egik-cizgi', 'dikdortgenler', 'dominosa', 'fillomino', 'suguru', 'hayaletler',
];

/// Uzun kuyruk çeşidi: 'tür:mini' ya da 'tür:dev'.
PuzzleRules logicTailRules(String gameId, String variant) {
  final parts = variant.split(':');
  final kind = parts[0];
  final big = parts.length > 1 && parts[1] == 'dev';
  return PuzzleRules(
    gameId: gameId,
    kindFor: kGridKinds[kind]!,
    unique: !_nonUnique(kind),
    diffMap: big ? (d) => d + 3 : (d) => (d + 1) ~/ 2,
  );
}
