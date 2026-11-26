import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:studio_core/app/game_api.dart';
import 'package:studio_core/app/services/audio.dart';
import 'package:studio_core/core/game_rules.dart';

import '../studio_chrome.dart';
import '../texts.dart';
import 'free_core.dart';

/// Ekrana verilen renkler ve seçenekler.
class FPalette {
  final List<Color> pieces;
  final Color ink, accent;
  final bool colorBlind, reducedMotion;
  final String lang;
  const FPalette({
    required this.pieces,
    required this.ink,
    required this.accent,
    required this.colorBlind,
    required this.reducedMotion,
    required this.lang,
  });
  Color piece(int i) => pieces[i % pieces.length];
}

/// Oynanan serbest bulmaca (değişebilir durum). [FreeView] dokunuşları
/// buraya iletir, her karede çizdirir ve [step] ile canlandırır.
abstract class FreeGame {
  final FLevel lv;
  FreeGame(this.lv);

  /// Son çizimdeki alan (dokunuş hesapları için).
  Size size = Size.zero;
  int moves = 0;
  final Map<String, int> stats = {};
  void bump(String k, [int n = 1]) => stats[k] = (stats[k] ?? 0) + n;

  /// Parmak değdi / kaydı / kalktı. true: durum değişti.
  bool down(Offset p) => false;
  bool move(Offset p) => false;
  bool up(Offset p) => false;

  /// Uzun basma (ör. bekletme bilmeceleri).
  bool get wantsHold => false;

  bool get won;
  bool get lost => false;

  /// Üst satırdaki kısa durum.
  String status(String lang);

  /// İpucu: bir adımı göster ya da yap. false: gösterecek bir şey yok.
  bool hint();

  /// İpucu durumu değiştirir mi (geri alma kaydı alınır).
  bool get hintChanges => true;

  /// Animasyon; true dönerse çizim sürer.
  bool step(double dt) => false;

  /// Animasyon sürerken kazanma/kaybetme denetimi bekletilsin mi.
  bool get busy => false;

  void paint(Canvas c, Size size, FPalette p, double t);

  Map<String, Object?> save();
  void load(Map<String, Object?> j);

  int stars(int hints) => hints == 0 ? 3 : (hints <= 2 ? 2 : 1);
}

/// Serbest bulmacaların ortak ekranı (onaylı stüdyo üst çubuğu ile).
class FreeView extends StatefulWidget {
  final PlayContext ctx;
  final FreeGame Function(FLevel lv) create;
  const FreeView({super.key, required this.ctx, required this.create});

  @override
  State<FreeView> createState() => _FreeViewState();
}

class _FreeViewState extends State<FreeView> with SingleTickerProviderStateMixin {
  late FreeGame g;
  final _undo = <Map<String, Object?>>[];
  late Map<String, Object?> _start;
  int _seconds = 0, _hints = 0, _undos = 0, _lastMoves = 0;
  bool _ended = false;
  Timer? _timer;
  late final Ticker _ticker;
  Duration _last = Duration.zero;
  double _t = 0;

  PlayContext get ctx => widget.ctx;

  @override
  void initState() {
    super.initState();
    final lv = (ctx.generated as GeneratedLevel<FLevel>).puzzle;
    g = widget.create(lv);
    _start = g.save();
    final snap = ctx.resume['snap'];
    if (snap is Map) {
      try {
        g.load(Map<String, Object?>.from(snap));
      } catch (_) {
        g.load(_start);
      }
    }
    _seconds = (ctx.resume['secs'] as num?)?.toInt() ?? 0;
    _hints = (ctx.resume['hints'] as num?)?.toInt() ?? 0;
    _lastMoves = g.moves;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!_ended && mounted) setState(() => _seconds++);
    });
    _ticker = createTicker(_onTick)..start();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _ticker.dispose();
    super.dispose();
  }

  void _onTick(Duration now) {
    final dt = _last == Duration.zero ? 0.0 : (now - _last).inMicroseconds / 1e6;
    _last = now;
    _t += dt;
    final anim = g.step(math.min(dt, 0.05));
    if (mounted && (anim || dt > 0)) setState(() {});
    _afterChange();
  }

  void _persist() => ctx.saveResume({'snap': g.save(), 'secs': _seconds, 'hints': _hints});

  void _afterChange() {
    if (_ended) return;
    if (g.moves != _lastMoves && !g.busy) {
      _lastMoves = g.moves;
      _persist();
    }
    if (g.busy) return;
    if (g.won) {
      _ended = true;
      ctx.sfx(Sfx.win);
      final stars = g.stars(_hints);
      Future.delayed(const Duration(milliseconds: 600), () {
        if (!mounted) return;
        ctx.finish(RoundResult(
          won: true,
          score: math.max(100, 2000 - _seconds * 2 - _hints * 150),
          stars: stars,
          seconds: _seconds,
          moves: g.moves,
          hintsUsed: _hints,
          undosUsed: _undos,
          gameStats: {'puzzles_solved': 1, if (_hints == 0) 'clean_solves': 1, ...g.stats},
        ));
      });
    } else if (g.lost) {
      _ended = true;
      ctx.sfx(Sfx.lose);
      Future.delayed(const Duration(milliseconds: 700), () {
        if (!mounted) return;
        ctx.finish(RoundResult(won: false, seconds: _seconds, moves: g.moves, hintsUsed: _hints, gameStats: g.stats));
      });
    }
  }

  void _input(bool Function() f) {
    if (_ended) return;
    final before = g.save();
    final m0 = g.moves;
    if (f()) {
      if (g.moves != m0) {
        _undo.add(before);
        if (_undo.length > 80) _undo.removeAt(0);
        ctx.sfx(Sfx.tap);
      }
      setState(() {});
    }
  }

  void _doUndo() {
    if (_undo.isEmpty || _ended) return;
    setState(() {
      g.load(_undo.removeLast());
      _undos++;
      _lastMoves = g.moves;
    });
    _persist();
  }

  void _restart() {
    if (_ended) return;
    setState(() {
      g.load(_start);
      _undo.clear();
      _lastMoves = g.moves;
    });
    _persist();
  }

  Future<void> _hint() async {
    if (_ended) return;
    if (!await ctx.requestHint()) return;
    if (!mounted) return;
    final before = g.save();
    setState(() {
      if (g.hint()) {
        _hints++;
        if (g.hintChanges) _undo.add(before);
      }
    });
    _persist();
  }

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    final pal = FPalette(
      pieces: ctx.pieceColors,
      ink: s.onSurface,
      accent: s.primary,
      colorBlind: ctx.colorBlind,
      reducedMotion: ctx.reducedMotion,
      lang: ctx.lang,
    );
    return StudioChrome(child: Builder(builder: (context) => _build(context, pal)));
  }

  Widget _build(BuildContext context, FPalette pal) {
    final look = StudioLook.of(context);
    final lang = ctx.lang;
    return Column(children: [
      Container(
        margin: const EdgeInsets.fromLTRB(8, 6, 8, 0),
        padding: const EdgeInsetsDirectional.only(start: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: LinearGradient(colors: [look.sheet.withValues(alpha: 0.92), look.base.withValues(alpha: 0.92)]),
          border: Border.all(color: look.accent.withValues(alpha: 0.45), width: 1.2),
        ),
        child: Row(children: [
          StudioTag(icon: Icons.timer_outlined, text: '${_seconds ~/ 60}:${(_seconds % 60).toString().padLeft(2, '0')}'),
          const SizedBox(width: 10),
          Expanded(
              child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(g.status(lang),
                      maxLines: 1,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: kStudioText, fontWeight: FontWeight.w800)))),
          IconButton(tooltip: bt(lang, 'undo'), onPressed: _undo.isEmpty ? null : _doUndo, icon: const Icon(Icons.undo)),
          IconButton(tooltip: bt(lang, 'restart'), onPressed: _restart, icon: const Icon(Icons.restart_alt)),
          IconButton(tooltip: bt(lang, 'hint'), onPressed: _hint, icon: const Icon(Icons.lightbulb_outline)),
        ]),
      ),
      Expanded(
        child: LayoutBuilder(builder: (context, box) {
          final size = Size(box.maxWidth, box.maxHeight);
          g.size = size;
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onPanDown: (d) => _input(() => g.down(d.localPosition)),
            onPanUpdate: (d) => _input(() => g.move(d.localPosition)),
            onPanEnd: (d) => _input(() => g.up(Offset.infinite)),
            onPanCancel: () => _input(() => g.up(Offset.infinite)),
            child: CustomPaint(size: size, painter: _FreePainter(g, pal, _t)),
          );
        }),
      ),
    ]);
  }
}

class _FreePainter extends CustomPainter {
  final FreeGame g;
  final FPalette p;
  final double t;
  _FreePainter(this.g, this.p, this.t);

  @override
  void paint(Canvas canvas, Size size) => g.paint(canvas, size, p, t);

  @override
  bool shouldRepaint(covariant _FreePainter old) => true;
}
