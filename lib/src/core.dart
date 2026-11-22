import 'dart:ui';

import 'package:studio_core/core/game_rules.dart';
import 'package:studio_core/core/level_plan.dart';
import 'package:studio_core/core/missions.dart';
import 'package:studio_core/core/rng.dart';
import 'package:studio_core/core/stats.dart';

/// Izgara bulmacası bölümü. Oyuncunun düzenlediği üç katman vardır:
/// hücreler, komşu hücre merkezlerini birleştiren bağlar ve hücre
/// kenarları. Her tür bu katmanlardan gerekenleri kullanır.
///
/// Bağ dizini: (x, y) hücresinin sağ bağı y*(w-1)+x, alt bağı
/// (w-1)*h + y*w + x. Kenar dizini: (x, y) hücresinin üst kenarı y*w+x
/// (y 0..h), sol kenarı (h+1)*w + y*(w+1) + x (x 0..w).
class PLevel {
  final String kind;
  final int w, h;

  /// Hücre ipuçları (-1 yok). Anlamı türe göre değişir.
  final List<int> clues;

  /// Bölge kimlikleri (boşsa bölge yok).
  final List<int> regions;

  /// Türe özgü ek veriler (kafesler, satır ipuçları vb.).
  final List<List<int>> extra;

  /// Çözüm katmanları.
  final List<int> solCells, solLinks, solBorders;

  /// Verilen (kilitli) hücreler: -1 değilse çözümdeki değer.
  final List<int> givens;

  /// Verilen (kilitli) bağlar ve kenarlar: -1 değilse değer.
  final List<int> givenLinks, givenBorders;

  /// Rakam türlerinde en büyük rakam; durum türlerinde ek parametre.
  final int param;

  const PLevel({
    required this.kind,
    required this.w,
    required this.h,
    required this.clues,
    this.regions = const [],
    this.extra = const [],
    this.solCells = const [],
    this.solLinks = const [],
    this.solBorders = const [],
    required this.givens,
    this.givenLinks = const [],
    this.givenBorders = const [],
    this.param = 0,
  });

  int get n => w * h;
  int get linkCount => (w - 1) * h + w * (h - 1);
  int get borderCount => (h + 1) * w + (w + 1) * h;

  PLevel withGivens(List<int> g, [List<int>? gl, List<int>? gb]) => PLevel(
        kind: kind,
        w: w,
        h: h,
        clues: clues,
        regions: regions,
        extra: extra,
        solCells: solCells,
        solLinks: solLinks,
        solBorders: solBorders,
        givens: g,
        givenLinks: gl ?? givenLinks,
        givenBorders: gb ?? givenBorders,
        param: param,
      );

  PLevel copyWith({List<int>? clues, List<List<int>>? extra, List<int>? regions}) => PLevel(
        kind: kind,
        w: w,
        h: h,
        clues: clues ?? this.clues,
        regions: regions ?? this.regions,
        extra: extra ?? this.extra,
        solCells: solCells,
        solLinks: solLinks,
        solBorders: solBorders,
        givens: givens,
        givenLinks: givenLinks,
        givenBorders: givenBorders,
        param: param,
      );

  // ---- yardımcılar
  int rightLink(int x, int y) => y * (w - 1) + x;
  int downLink(int x, int y) => (w - 1) * h + y * w + x;

  /// İki komşu hücre arasındaki bağ (değilse -1).
  int linkBetween(int a, int b) {
    if (a > b) return linkBetween(b, a);
    final ax = a % w, ay = a ~/ w, bx = b % w, by = b ~/ w;
    if (ay == by && bx == ax + 1) return rightLink(ax, ay);
    if (ax == bx && by == ay + 1) return downLink(ax, ay);
    return -1;
  }

  /// Bağın iki hücresi.
  (int, int) linkCells(int l) {
    final r = (w - 1) * h;
    if (l < r) {
      final y = l ~/ (w - 1), x = l % (w - 1);
      return (y * w + x, y * w + x + 1);
    }
    final k = l - r;
    final y = k ~/ w, x = k % w;
    return (y * w + x, (y + 1) * w + x);
  }

  int topEdge(int x, int y) => y * w + x;
  int leftEdge(int x, int y) => (h + 1) * w + y * (w + 1) + x;

  /// Hücreyi çevreleyen dört kenar: üst, sağ, alt, sol.
  List<int> cellEdges(int i) {
    final x = i % w, y = i ~/ w;
    return [topEdge(x, y), leftEdge(x + 1, y), topEdge(x, y + 1), leftEdge(x, y)];
  }

  /// İki komşu hücre arasındaki kenar.
  int edgeBetween(int a, int b) {
    if (a > b) return edgeBetween(b, a);
    final ax = a % w, ay = a ~/ w;
    if (b == a + 1) return leftEdge(ax + 1, ay);
    return topEdge(ax, ay + 1);
  }

  /// Kenarın iki ucundaki köşe noktaları ((w+1) genişlikli dizin).
  (int, int) edgeVertices(int e) {
    final hz = (h + 1) * w;
    if (e < hz) {
      final y = e ~/ w, x = e % w;
      return (y * (w + 1) + x, y * (w + 1) + x + 1);
    }
    final k = e - hz;
    final y = k ~/ (w + 1), x = k % (w + 1);
    return (y * (w + 1) + x, (y + 1) * (w + 1) + x);
  }

  /// Kenarın iki yanındaki hücreler (-1 dış).
  (int, int) edgeCells(int e) {
    final hz = (h + 1) * w;
    if (e < hz) {
      final y = e ~/ w, x = e % w;
      return (y > 0 ? (y - 1) * w + x : -1, y < h ? y * w + x : -1);
    }
    final k = e - hz;
    final y = k ~/ (w + 1), x = k % (w + 1);
    return (x > 0 ? y * w + x - 1 : -1, x < w ? y * w + x : -1);
  }

  List<int> neighbors(int i, {bool diag = false}) {
    final x = i % w, y = i ~/ w;
    final out = <int>[];
    for (var dy = -1; dy <= 1; dy++) {
      for (var dx = -1; dx <= 1; dx++) {
        if (dx == 0 && dy == 0) continue;
        if (!diag && dx != 0 && dy != 0) continue;
        final nx = x + dx, ny = y + dy;
        if (nx >= 0 && ny >= 0 && nx < w && ny < h) out.add(ny * w + nx);
      }
    }
    return out;
  }

  Map<String, Object?> toJson() => {
        'k': kind,
        'w': w,
        'h': h,
        'c': clues,
        'r': regions,
        'x': extra,
        'sc': solCells,
        'sl': solLinks,
        'sb': solBorders,
        'g': givens,
        'gl': givenLinks,
        'gb': givenBorders,
        'p': param,
      };

  static List<int> _l(Object? o) => [for (final v in (o as List? ?? const [])) (v as num).toInt()];

  factory PLevel.fromJson(Map<String, Object?> j) => PLevel(
        kind: j['k'] as String,
        w: (j['w'] as num).toInt(),
        h: (j['h'] as num).toInt(),
        clues: _l(j['c']),
        regions: _l(j['r']),
        extra: [for (final e in (j['x'] as List? ?? const [])) _l(e)],
        solCells: _l(j['sc']),
        solLinks: _l(j['sl']),
        solBorders: _l(j['sb']),
        givens: _l(j['g']),
        givenLinks: _l(j['gl']),
        givenBorders: _l(j['gb']),
        param: (j['p'] as num?)?.toInt() ?? 0,
      );
}

/// Oyuncunun (ya da çözücünün) durumu. Çözücüde -1 bilinmeyen demektir.
class PState {
  final List<int> cells, links, borders;

  /// Türe özgü ek durum (hamle oyunları: seçim, sayaç, rastgele durum).
  final List<int> aux;
  PState(this.cells, this.links, this.borders, [List<int>? aux]) : aux = aux ?? <int>[];

  factory PState.empty(PLevel lv, {int fill = 0}) => PState(
        [for (var i = 0; i < lv.n; i++) lv.givens.isNotEmpty && lv.givens[i] >= 0 ? lv.givens[i] : fill],
        [for (var i = 0; i < lv.linkCount; i++) lv.givenLinks.isNotEmpty && lv.givenLinks[i] >= 0 ? lv.givenLinks[i] : fill],
        [for (var i = 0; i < lv.borderCount; i++) lv.givenBorders.isNotEmpty && lv.givenBorders[i] >= 0 ? lv.givenBorders[i] : fill],
      );

  PState copy() => PState(List.of(cells), List.of(links), List.of(borders), List.of(aux));

  String serialize() => '${cells.join(',')}|${links.join(',')}|${borders.join(',')}|${aux.join(',')}';

  static PState? restore(String s, PLevel lv) {
    final p = s.split('|');
    if (p.length != 3 && p.length != 4) return null;
    List<int> parse(String t) => t.isEmpty ? <int>[] : [for (final v in t.split(',')) int.tryParse(v) ?? 0];
    final st = PState(parse(p[0]), parse(p[1]), parse(p[2]), p.length == 4 ? parse(p[3]) : null);
    if (st.cells.length != lv.n || st.links.length != lv.linkCount || st.borders.length != lv.borderCount) return null;
    return st;
  }
}

/// Hücrenin görünüşü.
enum Mark { none, fill, dot, star, bulb, tent, tree, ship, circle, cross, slashF, slashB, plus, minus, ghost, vampire, zombie, mirrorF, mirrorB, gem, arrow, wall, hole, disc, ring }

class CellLook {
  final Mark mark;
  final String text;

  /// 0 normal, 1 verilen/ipucu, 2 hatalı, 3 vurgulu
  final int tone;

  /// Hücre zemin rengi sırası (-1 yok): renkli türler için.
  final int color;
  final int arrowDir;
  const CellLook({this.mark = Mark.none, this.text = '', this.tone = 0, this.color = -1, this.arrowDir = 0});
}

/// Oyuncu hücreye nasıl müdahale eder.
enum CellInput { none, digits, cycle, colors }

/// Bulmaca türü: üretim, kural denetimi ve görünüş.
abstract class PuzzleKind {
  const PuzzleKind();

  String get id;

  CellInput get cellInput => CellInput.cycle;

  /// cycle türlerinde durum sayısı (0 boş dahil). digits türlerinde en büyük rakam + 1.
  int cellStates(PLevel lv) => 2;

  /// Kural denetiminde boş sayılan işaret durumu (ör. nokta); yoksa -1.
  int get markState => -1;

  bool get usesLinks => false;
  int get linkStates => 2;
  bool get usesBorders => false;
  int get borderStates => 2;

  /// Bağlar sürükleyerek çizilir; kenarlar dokunarak.
  /// Dış kenarlar oyunda değiştirilemez mi?
  bool get outerBordersFixed => false;

  /// Zorluk 1..10 için çözümlü bir bölüm üretir (verilen hücre yok).
  PLevel make(int difficulty, SeededRandom r);

  /// Kurallara uygunluk. Çözücüde bilinmeyenler -1; [complete] ise
  /// bilinmeyen yoktur ve bütün kurallar tam denetlenir.
  bool ok(PLevel lv, PState s, bool complete);

  /// Hücrenin oyuncu değerini kural değerine çevirir (işaret → 0,
  /// rakam türünde 0 → -1).
  int norm(int v) {
    if (cellInput == CellInput.digits || zeroUnknown) return v <= 0 ? -1 : v;
    if (v == markState) return 0;
    return v;
  }

  /// Oyuncu durumunu kural durumuna çevir.
  PState normalized(PLevel lv, PState s) => PState(
        [for (final v in s.cells) norm(v)],
        [for (final v in s.links) v == 3 ? 0 : v],
        [for (final v in s.borders) v == 3 ? 0 : v],
      );

  /// Kazanıldı mı?
  bool solved(PLevel lv, PState player) {
    final s = normalized(lv, player);
    if ((cellInput == CellInput.digits || zeroUnknown) && s.cells.contains(-1)) return false;
    return ok(lv, s, true);
  }

  CellLook look(PLevel lv, PState s, int i);

  /// Çözücü değişkenleri: hücreler, sonra bağlar, sonra kenarlar.
  /// Hücre değişkeni olmayan türler false döner.
  bool get solveCells => cellInput != CellInput.none;

  /// Döngülü türde 0 "boş" değil "bilinmiyor" mu (ör. ikili bulmaca).
  bool get zeroUnknown => false;

  /// Rakam düğmeleri (null: 1..en büyük).
  List<int>? padValues(PLevel lv, PState s) => null;

  List<int> cellDomain(PLevel lv, int i) => cellInput == CellInput.digits || zeroUnknown
      ? [for (var v = 1; v < cellStates(lv); v++) v]
      : [for (var v = 0; v < cellStates(lv); v++) if (v != markState) v];

  List<int> linkDomain(PLevel lv) => [for (var v = 0; v < linkStates; v++) v];
  List<int> borderDomain(PLevel lv) => const [0, 1];

  /// Çözüm sayısı (en çok [limit]); bütçe aşılırsa null.
  int? countSolutions(PLevel lv, {int limit = 2, int budget = 200000}) =>
      genericCount(this, lv, limit: limit, budget: budget);

  /// Benzersizlik için verilen ekleme yöntemi: hangi katman?
  /// 0 hücre, 1 bağ, 2 kenar.
  int get givenLayer => usesLinks && !solveCells ? 1 : (usesBorders && !solveCells ? 2 : 0);

  /// Bölümün ilk durumunda kilitli olmayan, ipucu taşıyan hücrelere
  /// verilen konulabilir mi?
  bool canGive(PLevel lv, int i) => lv.clues.isEmpty || lv.clues[i] < 0;

  /// Bölüme göre en çok verilen oranı.
  double maxGivenRatio(int difficulty) => 0.6;

  /// Benzersizlikten sonra kolaylık için eklenecek verilen oranı
  /// (verilebilir hücrelerin kalan kısmına göre).
  double extraGivenRatio(int difficulty) => 0;

  /// Benzersizlik aramasının bütçesi (genel çözücüde kural denetimi sayısı).
  int get solveBudget => 40000;

  /// Benzersizlikten sonra kaç verilenin kaldırılması denenecek.
  int reduceTries(int difficulty) => 0;

  /// Durum satırı (ör. kalan yıldız).
  String status(PLevel lv, PState s, String lang) => '';

  // ---- görünüş kancaları
  /// Izgara dışında ipucu payı (hücre biriminde): üst, sol, alt, sağ.
  (double, double, double, double) margins(PLevel lv) => (0, 0, 0, 0);

  /// Dış ipucu metni. side: 0 üst (sütun), 1 sol (satır), 2 alt, 3 sağ.
  String outside(PLevel lv, PState s, int side, int index) => '';

  /// Dış ipucu karşılandı mı (soluk gösterilir).
  bool outsideDone(PLevel lv, PState s, int side, int index) => false;

  /// Bölgeleri renkle ayır.
  bool get tintRegions => false;

  /// Hücre çizgileri (ızgara) gösterilsin mi.
  bool get gridLines => true;

  /// Bağlar daire merkezli düğümler arasında mı (ör. köprüler).
  bool get nodeStyle => false;

  void paintUnder(Canvas c, PLevel lv, PState s, Rect Function(int i) cell, double cs) {}
  void paintOver(Canvas c, PLevel lv, PState s, Rect Function(int i) cell, double cs) {}

  /// Kenar dokunuşu yerine bağ/hücre sürüklemesi kullanılsın mı.
  bool get dragLinks => usesLinks;

  /// Hücreye dokunmak bağları değil hücreyi değiştirir mi.
  bool tapCell(PLevel lv, int i) => cellInput != CellInput.none && (lv.givens.isEmpty || lv.givens[i] < 0) && (lv.clues.isEmpty || lv.clues[i] < 0 || cluesEditable);

  // ---- hamle oyunları
  /// Hamle türü: dokunma, kaydırma ve sürükleme doğrudan türe gider.
  bool get actionMode => false;

  /// Hücreye dokunma; durum değiştiyse true.
  bool act(PLevel lv, PState s, int i) => false;

  /// Uzun basma.
  bool actAlt(PLevel lv, PState s, int i) => false;

  /// Izgara dışındaki ipucu alanına dokunma (side: 0 üst, 1 sol, 2 alt, 3 sağ).
  bool actOutside(PLevel lv, PState s, int side, int index) => false;

  /// Kaydırma (0 yukarı, 1 sağ, 2 aşağı, 3 sol).
  bool swipe(PLevel lv, PState s, int dir) => false;

  /// Bir hücreden diğerine sürükleme.
  bool dragMove(PLevel lv, PState s, int from, int to) => false;

  /// Sürüklenen hücre yolu (komşu hücreler) ile hamle.
  bool get pathInput => false;
  bool pathMove(PLevel lv, PState s, List<int> path) => false;

  /// Çapraz komşular da yola eklenebilir mi.
  bool get pathDiagonal => false;

  /// Kaybedildi mi (ör. mayına basmak).
  bool failed(PLevel lv, PState s) => false;

  /// Oyunun başlangıç durumu.
  PState initial(PLevel lv) => PState.empty(lv);

  /// İpucu düğmesi çözümden değer gösterebilir mi.
  bool get hintable => true;

  /// Çözücü değişken sırası (null: hücreler, bağlar, kenarlar sırayla).
  List<(int, int)>? solveOrder(PLevel lv) => null;

  /// Rakam düğmesindeki etiket.
  String digitLabel(int v) => '$v';

  /// Kenar türlerinde köşe noktaları gösterilsin mi.
  bool get showVertices => usesBorders;

  /// Bağ rengi (null: vurgu rengi).
  Color? linkColor(PLevel lv, PState s, int l) => null;

  /// İpucu hücreleri de düzenlenebilir mi (ör. ışıkları söndür).
  bool get cluesEditable => false;

  /// Renk türlerinde hücreye renk ver (harita: bütün bölge).
  void setColor(PLevel lv, PState s, int i, int value) {
    s.cells[i] = value;
  }

  /// Dokunma bir hücreyi döngüleyince ek etki (ör. komşuları çevirmek).
  void onTap(PLevel lv, PState s, int i) {
    s.cells[i] = (s.cells[i] + 1) % cellStates(lv);
  }
}

/// Son sayımda bulunan çözümler (verilen seçimi için; en çok iki).
final List<PState> lastFoundSolutions = [];

/// Genel geri izlemeli çözücü: değişkenleri sırayla dener, her adımda
/// [PuzzleKind.ok] ile budar.
int? genericCount(PuzzleKind k, PLevel lv, {int limit = 2, int budget = 200000}) {
  final s = PState(
    [for (var i = 0; i < lv.n; i++) k.solveCells ? (lv.givens.isNotEmpty && lv.givens[i] >= 0 ? lv.givens[i] : -1) : 0],
    [for (var i = 0; i < lv.linkCount; i++) k.usesLinks ? (lv.givenLinks.isNotEmpty && lv.givenLinks[i] >= 0 ? lv.givenLinks[i] : -1) : 0],
    [for (var i = 0; i < lv.borderCount; i++) k.usesBorders ? (lv.givenBorders.isNotEmpty && lv.givenBorders[i] >= 0 ? lv.givenBorders[i] : -1) : 0],
  );
  final custom = k.solveOrder(lv);
  final vars = <(int, int)>[];
  if (custom != null) {
    for (final v in custom) {
      final list = v.$1 == 0 ? s.cells : (v.$1 == 1 ? s.links : s.borders);
      if (list[v.$2] < 0) vars.add(v);
    }
  } else if (k.solveCells) {
    for (var i = 0; i < lv.n; i++) {
      if (s.cells[i] < 0) vars.add((0, i));
    }
  }
  if (custom == null && k.usesLinks) {
    for (var i = 0; i < lv.linkCount; i++) {
      if (s.links[i] < 0) vars.add((1, i));
    }
  }
  if (custom == null && k.usesBorders) {
    for (var i = 0; i < lv.borderCount; i++) {
      if (s.borders[i] < 0) vars.add((2, i));
    }
  }
  final cellDom = [for (var i = 0; i < lv.n; i++) k.cellDomain(lv, i)];
  final linkDom = k.linkDomain(lv), borderDom = k.borderDomain(lv);
  List<int> listOf(int layer) => layer == 0 ? s.cells : (layer == 1 ? s.links : s.borders);
  List<int> domOf(int layer, int i) => layer == 0 ? cellDom[i] : (layer == 1 ? linkDom : borderDom);
  lastFoundSolutions.clear();
  if (!k.ok(lv, s, vars.isEmpty)) return 0;
  var count = 0, calls = 0;
  var over = false;
  bool test() {
    if (++calls > budget) {
      over = true;
      return false;
    }
    return k.ok(lv, s, false);
  }

  // Tekil değer yayılımı: yalnız bir değeri kurala uyan değişkeni ata.
  bool propagate(List<(int, int)> trail) {
    var changed = true;
    while (changed) {
      changed = false;
      for (final (layer, i) in vars) {
        final list = listOf(layer);
        if (list[i] >= 0) continue;
        var good = 0, last = -1;
        for (final v in domOf(layer, i)) {
          list[i] = v;
          final t = test();
          list[i] = -1;
          if (over) return false;
          if (t) {
            good++;
            last = v;
            if (good > 1) break;
          }
        }
        if (good == 0) return false;
        if (good == 1) {
          list[i] = last;
          trail.add((layer, i));
          changed = true;
        }
      }
    }
    return true;
  }

  void undo(List<(int, int)> trail) {
    for (final (layer, i) in trail) {
      listOf(layer)[i] = -1;
    }
  }

  void go() {
    if (count >= limit || over) return;
    final trail = <(int, int)>[];
    if (!propagate(trail)) {
      undo(trail);
      return;
    }
    (int, int)? pick;
    for (final v in vars) {
      if (listOf(v.$1)[v.$2] < 0) {
        pick = v;
        break;
      }
    }
    if (pick == null) {
      if (k.ok(lv, s, true)) {
        count++;
        if (lastFoundSolutions.length < 2) lastFoundSolutions.add(s.copy());
      }
      undo(trail);
      return;
    }
    final (layer, i) = pick;
    final list = listOf(layer);
    for (final v in domOf(layer, i)) {
      list[i] = v;
      if (test()) go();
      list[i] = -1;
      if (count >= limit || over) break;
    }
    undo(trail);
  }

  go();
  return over ? null : count;
}

/// Benzersiz çözüm için verilen ekleyerek bölümü bitirir.
PLevel finishWithGivens(PuzzleKind k, PLevel lv, int difficulty, SeededRandom r, {int? budget0}) {
  final budget = budget0 ?? k.solveBudget;
  final layer = k.givenLayer;
  final sol = layer == 0 ? lv.solCells : (layer == 1 ? lv.solLinks : lv.solBorders);
  final total = sol.length;
  final pre = layer == 0 ? lv.givens : (layer == 1 ? lv.givenLinks : lv.givenBorders);
  final g = [for (var i = 0; i < total; i++) pre.length == total ? pre[i] : -1];
  PLevel build() => layer == 0
      ? lv.withGivens(g)
      : (layer == 1 ? lv.withGivens(List.filled(lv.n, -1), g) : lv.withGivens(List.filled(lv.n, -1), null, g));
  final order = [for (var i = 0; i < total; i++) i]..removeWhere((i) => g[i] >= 0 || (layer == 0 && !k.canGive(lv, i)) || (layer > 0 && sol[i] <= 0));
  r.shuffle(order);
  var cur = build();
  final maxGive = (order.length * k.maxGivenRatio(difficulty)).round();
  var given = 0;
  for (var round = 0; round < 200; round++) {
    final c = k.countSolutions(cur, budget: budget);
    if (c == 1) {
      // Zor bölümlerde gereksiz verilenleri ayıkla.
      final tries = k.reduceTries(difficulty);
      if (tries > 0) {
        final have = [for (var i = 0; i < total; i++) if (g[i] >= 0 && !(pre.length == total && pre[i] >= 0)) i];
        r.shuffle(have);
        var t = 0;
        for (final i in have) {
          if (t++ >= tries) break;
          final keep = g[i];
          g[i] = -1;
          if (k.countSolutions(build(), budget: budget ~/ 3) != 1) {
            g[i] = keep;
          } else {
            order.insert(0, i);
          }
        }
        cur = build();
      }
      final extra = (order.length * k.extraGivenRatio(difficulty)).round();
      for (var e = 0; e < extra && order.isNotEmpty; e++) {
        final i = order.removeLast();
        g[i] = sol[i];
      }
      return extra > 0 ? build() : cur;
    }
    if (c == 0) break; // olmamalı
    // Çok çözümlü: iki çözümün ayrıldığı bir yeri ver.
    if (c == 2 && lastFoundSolutions.length >= 2 && given < maxGive) {
      final a = lastFoundSolutions[0], b = lastFoundSolutions[1];
      final la = layer == 0 ? a.cells : (layer == 1 ? a.links : a.borders);
      final lb = layer == 0 ? b.cells : (layer == 1 ? b.links : b.borders);
      int? pick;
      for (final i in order.reversed) {
        if (i < la.length && i < lb.length && la[i] != lb[i]) {
          pick = i;
          break;
        }
      }
      if (pick != null) {
        order.remove(pick);
        g[pick] = sol[pick];
        given++;
        cur = build();
        continue;
      }
    }
    // Belirsiz ya da çok çözümlü: birkaç verilen ekle.
    final step = c == null ? 3 : 1;
    var added = 0;
    while (added < step && order.isNotEmpty && given < maxGive) {
      final i = order.removeLast();
      g[i] = sol[i];
      given++;
      added++;
    }
    if (added == 0) break;
    cur = build();
  }
  return cur;
}

/// Bulmaca türünün oyun kuralları (studio-core GameRules).
class PuzzleRules extends GameRules<PLevel> {
  @override
  final String gameId;
  final PuzzleKind Function(int difficulty) kindFor;
  final int levels;
  final bool unique;

  PuzzleRules({required this.gameId, required this.kindFor, this.levels = 100000, this.unique = true});

  @override
  int get levelCount => levels;

  @override
  List<String> get optionalMechanics => const [];

  @override
  List<GameModeId> get modes => const [GameModeId.campaign, GameModeId.daily, GameModeId.weekly, GameModeId.challenge];

  @override
  List<GameStat> get gameStats => const [
        GameStat('puzzles_solved', 'Çözülen bulmaca', 'Puzzles solved', scale: 10),
        GameStat('clean_solves', 'İpucusuz çözüm', 'Solved without hints', scale: 5),
      ];

  @override
  List<MissionTemplate> get missionTemplates => const [
        MissionTemplate('solve', 'puzzles_solved', [3, 10, 25]),
        MissionTemplate('clean', 'clean_solves', [1, 4, 10]),
      ];

  @override
  PLevel generate(LevelSpec spec) {
    final k = kindFor(spec.difficulty);
    final r = SeededRandom(mixSeed([spec.seed, 7331]));
    final lv = k.make(spec.difficulty, r);
    return unique ? finishWithGivens(k, lv, spec.difficulty, r) : lv;
  }

  @override
  Validation validate(PLevel puzzle, LevelSpec spec) {
    final k = kindFor(spec.difficulty);
    final sol = PState(
      puzzle.solCells.isEmpty ? List.filled(puzzle.n, 0) : List.of(puzzle.solCells),
      puzzle.solLinks.isEmpty ? List.filled(puzzle.linkCount, 0) : List.of(puzzle.solLinks),
      puzzle.solBorders.isEmpty ? List.filled(puzzle.borderCount, 0) : List.of(puzzle.solBorders),
    );
    if (!k.ok(puzzle, sol, true)) return const Validation.fail('solution breaks rules');
    // Verilenler çözümle uyumlu olmalı.
    for (var i = 0; i < puzzle.givens.length; i++) {
      if (puzzle.givens[i] >= 0 && puzzle.solCells.isNotEmpty && puzzle.givens[i] != puzzle.solCells[i]) {
        return const Validation.fail('given mismatch');
      }
    }
    var empty = 0;
    for (var i = 0; i < puzzle.n; i++) {
      if (puzzle.givens.isEmpty || puzzle.givens[i] < 0) empty++;
    }
    return Validation.ok(empty);
  }
}

/// Rastgele permütasyon.
List<int> shuffled(int n, SeededRandom r) {
  final l = [for (var i = 0; i < n; i++) i];
  r.shuffle(l);
  return l;
}

/// Bağlı bölgeler (aynı değerli komşu hücreler) — [same] doğruysa aynı bölge.
List<List<int>> components(PLevel lv, bool Function(int a) member, {bool Function(int a, int b)? same}) {
  final seen = List.filled(lv.n, false);
  final out = <List<int>>[];
  for (var i = 0; i < lv.n; i++) {
    if (seen[i] || !member(i)) continue;
    final comp = <int>[i];
    seen[i] = true;
    for (var q = 0; q < comp.length; q++) {
      for (final nb in lv.neighbors(comp[q])) {
        if (!seen[nb] && member(nb) && (same == null || same(comp[q], nb))) {
          seen[nb] = true;
          comp.add(nb);
        }
      }
    }
    out.add(comp);
  }
  return out;
}

/// Izgarayı rastgele bölgelere ayırır (her bölge [minSize]..[maxSize]).
List<int> randomRegions(int w, int h, int count, SeededRandom r) {
  final n = w * h;
  final reg = List.filled(n, -1);
  final seeds = shuffled(n, r).take(count).toList();
  for (var k = 0; k < seeds.length; k++) {
    reg[seeds[k]] = k;
  }
  var frontier = List.of(seeds);
  var left = n - seeds.length;
  var guard = 0;
  while (left > 0 && guard++ < n * 50) {
    final i = frontier[r.nextInt(frontier.length)];
    final x = i % w, y = i ~/ w;
    final opts = <int>[
      if (x > 0 && reg[i - 1] < 0) i - 1,
      if (x < w - 1 && reg[i + 1] < 0) i + 1,
      if (y > 0 && reg[i - w] < 0) i - w,
      if (y < h - 1 && reg[i + w] < 0) i + w,
    ];
    if (opts.isEmpty) {
      frontier.remove(i);
      if (frontier.isEmpty) {
        frontier = [for (var j = 0; j < n; j++) if (reg[j] >= 0) j];
      }
      continue;
    }
    final j = opts[r.nextInt(opts.length)];
    reg[j] = reg[i];
    frontier.add(j);
    left--;
  }
  return reg;
}
