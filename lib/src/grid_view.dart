import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:studio_core/app/game_api.dart';
import 'package:studio_core/app/services/audio.dart';
import 'package:studio_core/core/game_rules.dart';

import 'core.dart';
import 'symbols.dart';
import 'texts.dart';

/// Bütün ızgara bulmacaları için ortak ekran.
class PuzzleView extends StatefulWidget {
  final PlayContext ctx;
  final PuzzleKind Function(int difficulty) kindFor;
  const PuzzleView({super.key, required this.ctx, required this.kindFor});

  @override
  State<PuzzleView> createState() => _PuzzleViewState();
}

class _PuzzleViewState extends State<PuzzleView> {
  late PLevel lv;
  late PuzzleKind kind;
  late PState st;
  final _undo = <String>[];
  int? _sel;
  int _brush = 1;
  int _seconds = 0, _hints = 0, _moves = 0;
  bool _ended = false;
  Timer? _timer;
  // sürükleme
  int? _dragFrom;
  int? _paintValue;
  bool _dragged = false;

  PlayContext get ctx => widget.ctx;

  @override
  void initState() {
    super.initState();
    lv = (ctx.generated as GeneratedLevel<PLevel>).puzzle;
    kind = widget.kindFor(ctx.spec.difficulty);
    final snap = ctx.resume['snap'];
    st = (snap is String ? PState.restore(snap, lv) : null) ?? kind.initial(lv);
    _seconds = (ctx.resume['secs'] as num?)?.toInt() ?? 0;
    _hints = (ctx.resume['hints'] as num?)?.toInt() ?? 0;
    _moves = (ctx.resume['moves'] as num?)?.toInt() ?? 0;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!_ended && mounted) setState(() => _seconds++);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _persist() => ctx.saveResume({'snap': st.serialize(), 'secs': _seconds, 'hints': _hints, 'moves': _moves});

  bool _locked(int i) => lv.givens.isNotEmpty && lv.givens[i] >= 0;

  void _push() {
    _undo.add(st.serialize());
    if (_undo.length > 400) _undo.removeAt(0);
  }

  void _changed() {
    _moves++;
    _persist();
    if (kind.failed(lv, st)) {
      _ended = true;
      ctx.sfx(Sfx.lose);
      Future.delayed(const Duration(milliseconds: 700), () {
        if (!mounted) return;
        ctx.finish(RoundResult(won: false, seconds: _seconds, moves: _moves, hintsUsed: _hints));
      });
      return;
    }
    if (kind.solved(lv, st)) {
      _ended = true;
      ctx.sfx(Sfx.win);
      final stars = _hints == 0 ? 3 : (_hints <= 2 ? 2 : 1);
      Future.delayed(const Duration(milliseconds: 450), () {
        if (!mounted) return;
        ctx.finish(RoundResult(
          won: true,
          score: math.max(100, 2000 - _seconds * 2 - _hints * 150),
          stars: stars,
          seconds: _seconds,
          moves: _moves,
          hintsUsed: _hints,
          gameStats: {'puzzles_solved': 1, if (_hints == 0) 'clean_solves': 1},
        ));
      });
    }
  }

  // ---- geometri
  late double _cs;
  late Offset _origin;

  Rect _cell(int i) => Rect.fromLTWH(_origin.dx + (i % lv.w) * _cs, _origin.dy + (i ~/ lv.w) * _cs, _cs, _cs);

  int? _cellAt(Offset p) {
    final x = ((p.dx - _origin.dx) / _cs).floor(), y = ((p.dy - _origin.dy) / _cs).floor();
    if (x < 0 || y < 0 || x >= lv.w || y >= lv.h) return null;
    return y * lv.w + x;
  }

  /// Izgara dışındaki dokunuş: (taraf, sıra).
  (int, int)? _outsideAt(Offset p) {
    final fx = (p.dx - _origin.dx) / _cs, fy = (p.dy - _origin.dy) / _cs;
    if (fx >= 0 && fx < lv.w && fy < 0 && fy > -2.5) return (0, fx.floor());
    if (fx >= 0 && fx < lv.w && fy >= lv.h && fy < lv.h + 2.5) return (2, fx.floor());
    if (fy >= 0 && fy < lv.h && fx < 0 && fx > -2.5) return (1, fy.floor());
    if (fy >= 0 && fy < lv.h && fx >= lv.w && fx < lv.w + 2.5) return (3, fy.floor());
    return null;
  }

  Offset? _panOrigin, _panLast;
  final _path = <int>[];

  void _actPanStart(Offset p) {
    _panOrigin = p;
    _panLast = p;
    _path.clear();
    final i = _cellAt(p);
    if (i != null) _path.add(i);
  }

  void _actPanUpdate(Offset p) {
    _panLast = p;
    if (!kind.pathInput) return;
    final i = _cellAt(p);
    if (i == null || _path.isEmpty || _path.last == i) return;
    final a = _path.last;
    final dx = (i % lv.w - a % lv.w).abs(), dy = (i ~/ lv.w - a ~/ lv.w).abs();
    final adj = kind.pathDiagonal ? (dx <= 1 && dy <= 1) : (dx + dy == 1);
    if (!adj) return;
    if (_path.length >= 2 && _path[_path.length - 2] == i) {
      setState(() => _path.removeLast());
      return;
    }
    if (_path.contains(i)) return;
    setState(() => _path.add(i));
  }

  void _actPanEnd() {
    final a = _panOrigin, b = _panLast;
    _panOrigin = null;
    if (a == null || b == null || _ended) return;
    _push();
    var changed = false;
    if (kind.pathInput && _path.length >= 2) {
      changed = kind.pathMove(lv, st, List.of(_path));
    } else {
      final from = _cellAt(a), to = _cellAt(b);
      if (from != null && to != null && from != to) changed = kind.dragMove(lv, st, from, to);
      if (!changed) {
        final d = b - a;
        if (d.distance > _cs * 0.35) {
          final dir = d.dx.abs() > d.dy.abs() ? (d.dx > 0 ? 1 : 3) : (d.dy > 0 ? 2 : 0);
          changed = kind.swipe(lv, st, dir);
        }
      }
    }
    _path.clear();
    if (!changed) {
      _undo.removeLast();
      setState(() {});
      return;
    }
    setState(() {});
    ctx.sfx(Sfx.place);
    _changed();
  }

  /// En yakın kenar (dokunma kenara yeterince yakınsa).
  int? _edgeAt(Offset p) {
    final fx = (p.dx - _origin.dx) / _cs, fy = (p.dy - _origin.dy) / _cs;
    if (fx < -0.3 || fy < -0.3 || fx > lv.w + 0.3 || fy > lv.h + 0.3) return null;
    final rx = (fx - fx.round()).abs(), ry = (fy - fy.round()).abs();
    const tol = 0.28;
    if (rx < ry && rx < tol) {
      final x = fx.round(), y = fy.floor();
      if (y < 0 || y >= lv.h || x < 0 || x > lv.w) return null;
      return lv.leftEdge(x, y);
    }
    if (ry < tol) {
      final x = fx.floor(), y = fy.round();
      if (x < 0 || x >= lv.w || y < 0 || y > lv.h) return null;
      return lv.topEdge(x, y);
    }
    return null;
  }

  bool _outer(int e) {
    final (a, b) = lv.edgeCells(e);
    return a < 0 || b < 0;
  }

  // ---- girdi
  void _tapAt(Offset p) {
    if (_ended) return;
    if (kind.actionMode) {
      final i = _cellAt(p);
      _push();
      bool changed;
      if (i != null) {
        changed = kind.act(lv, st, i);
      } else {
        final o = _outsideAt(p);
        changed = o != null && kind.actOutside(lv, st, o.$1, o.$2);
      }
      if (!changed) {
        _undo.removeLast();
        return;
      }
      setState(() {});
      ctx.sfx(Sfx.tap);
      _changed();
      return;
    }
    if (kind.usesBorders) {
      final e = _edgeAt(p);
      if (e != null && !(kind.outerBordersFixed && _outer(e)) && (lv.givenBorders.isEmpty || lv.givenBorders[e] < 0)) {
        _push();
        setState(() => st.borders[e] = st.borders[e] == 0 ? 1 : (st.borders[e] == 1 ? 3 : 0));
        ctx.sfx(Sfx.tap);
        _changed();
        return;
      }
    }
    final i = _cellAt(p);
    if (i == null) return;
    if (kind.nodeStyle) {
      _bridgeTap(i);
      return;
    }
    if (kind.usesLinks && !kind.tapCell(lv, i)) {
      // Bağ ortasına dokunma: en yakın komşu bağı değiştir.
      final r = _cell(i);
      final d = p - r.center;
      if (d.distance > _cs * 0.18) {
        final nb = d.dx.abs() > d.dy.abs() ? (d.dx > 0 ? i + 1 : i - 1) : (d.dy > 0 ? i + lv.w : i - lv.w);
        final ok = d.dx.abs() > d.dy.abs() ? (nb ~/ lv.w == i ~/ lv.w && nb >= 0 && nb < lv.n) : (nb >= 0 && nb < lv.n);
        if (ok) {
          final l = lv.linkBetween(i, nb);
          if (l >= 0) _cycleLink(l);
        }
      }
      return;
    }
    if (!kind.tapCell(lv, i)) return;
    switch (kind.cellInput) {
      case CellInput.digits:
        setState(() => _sel = i);
        ctx.sfx(Sfx.tap);
      case CellInput.colors:
        _push();
        setState(() => kind.setColor(lv, st, i, st.cells[i] == _brush ? 0 : _brush));
        ctx.sfx(Sfx.place);
        _changed();
      case CellInput.cycle:
        _push();
        setState(() => kind.onTap(lv, st, i));
        ctx.sfx(Sfx.place);
        _changed();
      case CellInput.none:
        break;
    }
  }

  void _cycleLink(int l) {
    if (lv.givenLinks.isNotEmpty && lv.givenLinks[l] >= 0) return;
    _push();
    setState(() => st.links[l] = (st.links[l] + 1) % (kind.linkStates == 2 ? 3 : kind.linkStates));
    // ikili bağlarda 0 → 1 → 3 (çarpı) → 0 yerine 0 → 1 → 0: 2 değerini atla
    if (kind.linkStates == 2 && st.links[l] == 2) st.links[l] = 0;
    ctx.sfx(Sfx.tap);
    _changed();
  }

  int? _bridgeFrom;

  /// Köprü türü: iki ada arasındaki bütün bağları birlikte döngüle.
  bool _bridge(int a, int b) {
    if (a == b) return false;
    final ax = a % lv.w, ay = a ~/ lv.w, bx = b % lv.w, by = b ~/ lv.w;
    if (ax != bx && ay != by) return false;
    final step = ax == bx ? (by > ay ? lv.w : -lv.w) : (bx > ax ? 1 : -1);
    final links = <int>[];
    var c = a;
    while (c != b) {
      final nx = c + step;
      links.add(lv.linkBetween(c, nx));
      c = nx;
      if (c != b && lv.clues[c] >= 0) return false;
    }
    if (links.any((l) => l < 0 || (lv.givenLinks.isNotEmpty && lv.givenLinks[l] >= 0))) return false;
    _push();
    final next = (st.links[links.first] + 1) % kind.linkStates;
    setState(() {
      for (final l in links) {
        st.links[l] = next;
      }
    });
    ctx.sfx(Sfx.tap);
    _changed();
    return true;
  }

  /// Dokunulan boşluktaki köprü: iki yandaki en yakın adalar.
  bool _bridgeTap(int i) {
    if (lv.clues[i] >= 0) return false;
    final x = i % lv.w, y = i ~/ lv.w;
    int? find(int dx, int dy) {
      var nx = x + dx, ny = y + dy;
      while (nx >= 0 && ny >= 0 && nx < lv.w && ny < lv.h) {
        final c = ny * lv.w + nx;
        if (lv.clues[c] >= 0) return c;
        nx += dx;
        ny += dy;
      }
      return null;
    }

    // var olan köprü yönünü tercih et
    final hl = x > 0 ? st.links[lv.linkBetween(i - 1, i)] : 0;
    final order = hl > 0 || x == 0 ? const [(1, 0), (0, 1)] : const [(0, 1), (1, 0)];
    for (final (dx, dy) in order) {
      final a = find(-dx, -dy), b = find(dx, dy);
      if (a != null && b != null && _bridge(a, b)) return true;
    }
    return false;
  }

  void _panStart(Offset p) {
    if (kind.actionMode) return _actPanStart(p);
    _dragged = false;
    final i = _cellAt(p);
    _dragFrom = i;
    if (kind.nodeStyle) {
      _bridgeFrom = i != null && lv.clues[i] >= 0 ? i : null;
      return;
    }
    _paintValue = null;
    if (i != null && kind.cellInput == CellInput.cycle && !kind.dragLinks && kind.tapCell(lv, i)) {
      _push();
      setState(() => kind.onTap(lv, st, i));
      _paintValue = st.cells[i];
      _dragged = true;
    } else if (i != null && kind.cellInput == CellInput.colors && kind.tapCell(lv, i)) {
      _push();
      setState(() => kind.setColor(lv, st, i, st.cells[i] == _brush ? 0 : _brush));
      _paintValue = st.cells[i];
      _dragged = true;
    }
  }

  void _panUpdate(Offset p) {
    if (kind.actionMode) return _actPanUpdate(p);
    final i = _cellAt(p);
    if (kind.nodeStyle) {
      _dragFrom = i;
      return;
    }
    if (i == null || _dragFrom == null || i == _dragFrom) return;
    if (kind.dragLinks) {
      final l = lv.linkBetween(_dragFrom!, i);
      if (l >= 0 && (lv.givenLinks.isEmpty || lv.givenLinks[l] < 0)) {
        if (!_dragged) _push();
        _dragged = true;
        setState(() {
          if (kind.linkStates == 2) {
            st.links[l] = st.links[l] == 1 ? 0 : 1;
          } else {
            st.links[l] = (st.links[l] + 1) % kind.linkStates;
          }
        });
        ctx.sfx(Sfx.tap);
      }
      _dragFrom = i;
      return;
    }
    if (_paintValue != null && kind.tapCell(lv, i)) {
      if (kind.cellInput == CellInput.colors) {
        setState(() => kind.setColor(lv, st, i, _paintValue!));
      } else {
        setState(() => st.cells[i] = _paintValue!);
      }
    }
    _dragFrom = i;
  }

  void _panEnd() {
    if (kind.actionMode) return _actPanEnd();
    if (kind.nodeStyle) {
      final a = _bridgeFrom, b = _dragFrom;
      if (a != null && b != null && lv.clues[b] >= 0) _bridge(a, b);
      _bridgeFrom = null;
      _dragFrom = null;
      return;
    }
    if (_dragged) _changed();
    _dragFrom = null;
    _paintValue = null;
    _dragged = false;
  }

  void _digit(int v) {
    final i = _sel;
    if (i == null || _ended || _locked(i)) return;
    _push();
    setState(() => st.cells[i] = st.cells[i] == v ? 0 : v);
    ctx.sfx(Sfx.place);
    _changed();
  }

  void _undoMove() {
    if (_undo.isEmpty || _ended) return;
    final s = PState.restore(_undo.removeLast(), lv);
    if (s == null) return;
    setState(() => st = s);
    _persist();
  }

  void _clear() {
    if (_ended) return;
    _push();
    setState(() => st = kind.initial(lv));
    _persist();
  }

  Future<void> _hint() async {
    if (_ended || !kind.hintable) return;
    // Çözümden farklı ilk değer.
    int? layer, idx;
    if (kind.cellInput != CellInput.none && lv.solCells.isNotEmpty) {
      for (var i = 0; i < lv.n; i++) {
        if (_locked(i) || !kind.tapCell(lv, i)) continue;
        if (kind.norm(st.cells[i]) != kind.norm(lv.solCells[i]) && !(kind.cellInput != CellInput.digits && kind.norm(st.cells[i]) <= 0 && lv.solCells[i] <= 0)) {
          layer = 0;
          idx = i;
          break;
        }
      }
    }
    if (layer == null && kind.usesLinks && lv.solLinks.isNotEmpty) {
      for (var l = 0; l < lv.linkCount; l++) {
        final pv = st.links[l] == 3 ? 0 : st.links[l];
        if (pv != lv.solLinks[l]) {
          layer = 1;
          idx = l;
          break;
        }
      }
    }
    if (layer == null && kind.usesBorders && lv.solBorders.isNotEmpty) {
      for (var e = 0; e < lv.borderCount; e++) {
        final pv = st.borders[e] == 3 ? 0 : st.borders[e];
        if (pv != lv.solBorders[e] && !(kind.outerBordersFixed && _outer(e))) {
          layer = 2;
          idx = e;
          break;
        }
      }
    }
    if (layer == null || idx == null) return;
    if (!await ctx.requestHint()) return;
    if (!mounted) return;
    _push();
    _hints++;
    setState(() {
      if (layer == 0) {
        st.cells[idx!] = lv.solCells[idx];
        _sel = idx;
      } else if (layer == 1) {
        st.links[idx!] = lv.solLinks[idx];
      } else {
        st.borders[idx!] = lv.solBorders[idx];
      }
    });
    _changed();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final lang = ctx.lang;
    final status = kind.status(lv, st, lang);
    final (mt, ml, mb, mr) = kind.margins(lv);
    final digits = kind.cellInput == CellInput.digits;
    final colors = kind.cellInput == CellInput.colors;
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
        child: Row(children: [
          Icon(Icons.timer_outlined, size: 18, color: scheme.onSurface.withValues(alpha: 0.7)),
          const SizedBox(width: 4),
          Text('${_seconds ~/ 60}:${(_seconds % 60).toString().padLeft(2, '0')}'),
          const SizedBox(width: 12),
          Expanded(child: Text(status, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center)),
          IconButton(tooltip: bt(lang, 'undo'), onPressed: _undo.isEmpty ? null : _undoMove, icon: const Icon(Icons.undo)),
          IconButton(tooltip: bt(lang, 'clear'), onPressed: _clear, icon: const Icon(Icons.restart_alt)),
          if (kind.hintable) IconButton(tooltip: bt(lang, 'hint'), onPressed: _hint, icon: const Icon(Icons.lightbulb_outline)),
        ]),
      ),
      Expanded(
        child: LayoutBuilder(builder: (context, box) {
          final cols = lv.w + ml + mr, rows = lv.h + mt + mb;
          _cs = math.min((box.maxWidth - 16) / cols, (box.maxHeight - 16) / rows);
          final bw = _cs * cols, bh = _cs * rows;
          final left = (box.maxWidth - bw) / 2, top = (box.maxHeight - bh) / 2;
          _origin = Offset(left + ml * _cs, top + mt * _cs);
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: (d) => _tapAt(d.localPosition),
            onLongPressStart: kind.actionMode
                ? (d) {
                    final i = _cellAt(d.localPosition);
                    if (i == null || _ended) return;
                    _push();
                    if (kind.actAlt(lv, st, i)) {
                      setState(() {});
                      ctx.sfx(Sfx.tap);
                      _changed();
                    } else {
                      _undo.removeLast();
                    }
                  }
                : null,
            onPanStart: (d) => _panStart(d.localPosition),
            onPanUpdate: (d) => _panUpdate(d.localPosition),
            onPanEnd: (_) => _panEnd(),
            child: CustomPaint(
              size: Size(box.maxWidth, box.maxHeight),
              painter: _GridPainter(
                lv: lv,
                kind: kind,
                st: st,
                cs: _cs,
                origin: _origin,
                sel: digits ? _sel : null,
                path: List.of(_path),
                ink: scheme.onSurface,
                accent: ctx.pieceColors.isNotEmpty ? ctx.pieceColors[0] : scheme.primary,
                accent2: ctx.pieceColors.length > 1 ? ctx.pieceColors[1] : scheme.tertiary,
                paper: Color.alphaBlend(scheme.surface.withValues(alpha: 0.94), const Color(0xFFF6EBD9)),
                colorBlind: ctx.colorBlind,
                lang: lang,
              ),
            ),
          );
        }),
      ),
      if (digits) _numberPad(scheme),
      if (colors) _palette(scheme),
      const SizedBox(height: 6),
    ]);
  }

  Widget _numberPad(ColorScheme scheme) {
    final max = kind.cellStates(lv) - 1;
    final values = kind.padValues(lv, st) ?? [for (var v = 1; v <= max; v++) v];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 4,
        runSpacing: 4,
        children: [
          for (final v in values)
            SizedBox(
              width: values.length > 12 ? 38 : (max > 9 ? 40 : 44),
              height: 46,
              child: FilledButton.tonal(
                style: FilledButton.styleFrom(padding: EdgeInsets.zero),
                onPressed: () => _digit(v),
                child: Text(kind.digitLabel(v), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
              ),
            ),
          SizedBox(
            width: 52,
            height: 46,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(padding: EdgeInsets.zero),
              onPressed: () {
                final i = _sel;
                if (i == null || _locked(i) || st.cells[i] == 0) return;
                _push();
                setState(() => st.cells[i] = 0);
                _persist();
              },
              child: Icon(Icons.backspace_outlined, semanticLabel: bt(ctx.lang, 'erase')),
            ),
          ),
        ],
      ),
    );
  }

  Widget _palette(ColorScheme scheme) {
    final n = kind.cellStates(lv);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Wrap(spacing: 8, alignment: WrapAlignment.center, children: [
        for (var v = 1; v < n; v++)
          GestureDetector(
            onTap: () => setState(() => _brush = v),
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: puzzleColor(v),
                shape: BoxShape.circle,
                border: Border.all(color: v == _brush ? scheme.onSurface : Colors.transparent, width: 3),
              ),
              child: ctx.colorBlind ? Center(child: Text('$v', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))) : null,
            ),
          ),
      ]),
    );
  }
}

/// Renkli türler için özgün palet.
Color puzzleColor(int v) => const [
      Color(0xFFF6EBD9),
      Color(0xFF2E4057),
      Color(0xFFD1495B),
      Color(0xFF00798C),
      Color(0xFFEDAE49),
      Color(0xFF66A182),
      Color(0xFF8E6C8A),
      Color(0xFFB5651D),
      Color(0xFF3F88C5),
      Color(0xFF9DBF9E),
    ][v % 10];

class _GridPainter extends CustomPainter {
  final PLevel lv;
  final PuzzleKind kind;
  final PState st;
  final double cs;
  final Offset origin;
  final int? sel;
  final List<int> path;
  final Color ink, accent, accent2, paper;
  final bool colorBlind;
  final String lang;

  _GridPainter({
    required this.lv,
    required this.kind,
    required this.st,
    required this.cs,
    required this.origin,
    required this.sel,
    required this.path,
    required this.ink,
    required this.accent,
    required this.accent2,
    required this.paper,
    required this.colorBlind,
    required this.lang,
  });

  Rect cell(int i) => Rect.fromLTWH(origin.dx + (i % lv.w) * cs, origin.dy + (i ~/ lv.w) * cs, cs, cs);

  Offset vertex(int v) => origin + Offset((v % (lv.w + 1)) * cs, (v ~/ (lv.w + 1)) * cs);

  @override
  void paint(Canvas c, Size size) {
    final board = Rect.fromLTWH(origin.dx, origin.dy, lv.w * cs, lv.h * cs);
    c.drawRRect(RRect.fromRectAndRadius(board.inflate(cs * 0.08), Radius.circular(cs * 0.18)), Paint()..color = paper);
    // Bölge tonları
    if (kind.tintRegions && lv.regions.isNotEmpty) {
      for (var i = 0; i < lv.n; i++) {
        final t = regionTint(lv.regions[i]);
        c.drawRect(cell(i), Paint()..color = t);
      }
    }
    if (sel != null) c.drawRect(cell(sel!), Paint()..color = accent.withValues(alpha: 0.22));
    kind.paintUnder(c, lv, st, cell, cs);
    // Hücre içerikleri
    for (var i = 0; i < lv.n; i++) {
      final lk = kind.look(lv, st, i);
      final r = cell(i);
      if (lk.color >= 0) c.drawRect(r.deflate(cs * 0.02), Paint()..color = puzzleColor(lk.color));
      paintMark(c, lk.mark, r, ink: ink, accent: accent, accent2: accent2, dir: lk.arrowDir);
      if (lk.text.isNotEmpty) {
        final dark = lk.mark == Mark.fill || (lk.color > 0);
        final color = lk.tone == 2
            ? const Color(0xFFC0392B)
            : dark
                ? paper
                : (lk.tone == 1 ? ink : accent);
        final fs = cs * (lk.text.length > 2 ? 0.36 : 0.52);
        _text(c, lk.text, r.center, fs, color, lk.tone == 1 ? FontWeight.w800 : FontWeight.w600);
      }
    }
    // Izgara çizgileri
    if (kind.gridLines) {
      final p = Paint()
        ..color = ink.withValues(alpha: 0.22)
        ..strokeWidth = math.max(1, cs * 0.025);
      for (var x = 0; x <= lv.w; x++) {
        c.drawLine(origin + Offset(x * cs, 0), origin + Offset(x * cs, lv.h * cs), p);
      }
      for (var y = 0; y <= lv.h; y++) {
        c.drawLine(origin + Offset(0, y * cs), origin + Offset(lv.w * cs, y * cs), p);
      }
    }
    // Bölge sınırları
    if (lv.regions.isNotEmpty) {
      final p = Paint()
        ..color = ink.withValues(alpha: 0.85)
        ..strokeWidth = math.max(2, cs * 0.07)
        ..strokeCap = StrokeCap.round;
      for (var i = 0; i < lv.n; i++) {
        final x = i % lv.w, y = i ~/ lv.w;
        final r = cell(i);
        if (x + 1 < lv.w && lv.regions[i] != lv.regions[i + 1]) c.drawLine(r.topRight, r.bottomRight, p);
        if (y + 1 < lv.h && lv.regions[i] != lv.regions[i + lv.w]) c.drawLine(r.bottomLeft, r.bottomRight, p);
      }
      c.drawRect(board, p..style = PaintingStyle.stroke);
    } else if (kind.gridLines) {
      c.drawRect(
          board,
          Paint()
            ..style = PaintingStyle.stroke
            ..color = ink.withValues(alpha: 0.7)
            ..strokeWidth = math.max(2, cs * 0.05));
    }
    // Kenarlar
    if (kind.usesBorders) {
      for (var e = 0; e < lv.borderCount; e++) {
        final v = st.borders[e];
        if (v == 0) continue;
        final (a, b) = lv.edgeVertices(e);
        final pa = vertex(a), pb = vertex(b);
        final given = lv.givenBorders.isNotEmpty && lv.givenBorders[e] >= 0;
        if (v == 3) {
          final m = Offset.lerp(pa, pb, 0.5)!;
          final d = cs * 0.09;
          final p = Paint()
            ..color = ink.withValues(alpha: 0.45)
            ..strokeWidth = math.max(1.5, cs * 0.03);
          c.drawLine(m - Offset(d, d), m + Offset(d, d), p);
          c.drawLine(m - Offset(d, -d), m + Offset(d, -d), p);
        } else {
          c.drawLine(
              pa,
              pb,
              Paint()
                ..color = given ? ink : accent
                ..strokeWidth = cs * 0.11
                ..strokeCap = StrokeCap.round);
        }
      }
      if (kind.showVertices) {
        for (var v = 0; v < (lv.w + 1) * (lv.h + 1); v++) {
          c.drawCircle(vertex(v), math.max(1.5, cs * 0.05), Paint()..color = ink.withValues(alpha: 0.75));
        }
      }
    }
    // Bağlar
    if (kind.usesLinks) {
      for (var l = 0; l < lv.linkCount; l++) {
        final v = st.links[l];
        if (v == 0) continue;
        final (a, b) = lv.linkCells(l);
        final pa = cell(a).center, pb = cell(b).center;
        if (v == 3) {
          final m = Offset.lerp(pa, pb, 0.5)!;
          final d = cs * 0.08;
          final p = Paint()
            ..color = ink.withValues(alpha: 0.45)
            ..strokeWidth = math.max(1.5, cs * 0.03);
          c.drawLine(m - Offset(d, d), m + Offset(d, d), p);
          c.drawLine(m - Offset(d, -d), m + Offset(d, -d), p);
          continue;
        }
        final color = kind.linkColor(lv, st, l) ?? accent;
        final p = Paint()
          ..color = color
          ..strokeWidth = cs * (v == 2 ? 0.07 : 0.16)
          ..strokeCap = StrokeCap.round;
        if (v == 2) {
          final n = Offset(pb.dy - pa.dy, pa.dx - pb.dx);
          final u = n / n.distance * cs * 0.09;
          c.drawLine(pa + u, pb + u, p);
          c.drawLine(pa - u, pb - u, p);
        } else {
          c.drawLine(pa, pb, p);
        }
      }
    }
    kind.paintOver(c, lv, st, cell, cs);
    if (path.length >= 2) {
      final pp = Paint()
        ..color = accent.withValues(alpha: 0.6)
        ..strokeWidth = cs * 0.14
        ..strokeCap = StrokeCap.round;
      for (var k = 0; k + 1 < path.length; k++) {
        c.drawLine(cell(path[k]).center, cell(path[k + 1]).center, pp);
      }
    }
    // Dış ipuçları
    final (mt, ml, mb, mr) = kind.margins(lv);
    for (var side = 0; side < 4; side++) {
      final m = [mt, ml, mb, mr][side];
      if (m <= 0) continue;
      final count = side.isEven ? lv.w : lv.h;
      for (var k = 0; k < count; k++) {
        final t = kind.outside(lv, st, side, k);
        if (t.isEmpty) continue;
        final done = kind.outsideDone(lv, st, side, k);
        final color = done ? ink.withValues(alpha: 0.35) : ink;
        Rect area;
        switch (side) {
          case 0:
            area = Rect.fromLTWH(origin.dx + k * cs, origin.dy - m * cs, cs, m * cs);
          case 1:
            area = Rect.fromLTWH(origin.dx - m * cs, origin.dy + k * cs, m * cs, cs);
          case 2:
            area = Rect.fromLTWH(origin.dx + k * cs, origin.dy + lv.h * cs, cs, m * cs);
          default:
            area = Rect.fromLTWH(origin.dx + lv.w * cs, origin.dy + k * cs, m * cs, cs);
        }
        final parts = t.split(' ');
        if (parts.length > 1 && side.isEven) {
          // Sütun ipuçları alt alta
          final step = math.min(cs * 0.62, area.height / parts.length);
          final y0 = side == 0 ? area.bottom - step * parts.length : area.top;
          for (var q = 0; q < parts.length; q++) {
            _text(c, parts[q], Offset(area.center.dx, y0 + step * (q + 0.5)), math.min(cs * 0.42, step * 0.85), color, FontWeight.w700);
          }
        } else if (parts.length > 1) {
          final step = math.min(cs * 0.62, area.width / parts.length);
          final x0 = side == 1 ? area.right - step * parts.length : area.left;
          for (var q = 0; q < parts.length; q++) {
            _text(c, parts[q], Offset(x0 + step * (q + 0.5), area.center.dy), math.min(cs * 0.42, step * 0.85), color, FontWeight.w700);
          }
        } else {
          _text(c, t, area.center, cs * 0.44, color, FontWeight.w700);
        }
      }
    }
  }

  void _text(Canvas c, String s, Offset center, double size, Color color, FontWeight w) {
    final tp = TextPainter(
      text: TextSpan(text: s, style: TextStyle(fontSize: size, color: color, fontWeight: w)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(c, center - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant _GridPainter old) => true;
}

/// Bölge tonu: sıcak ve soğuk tonların sırayla dizildiği özgün palet.
Color regionTint(int r) => const [
      Color(0x33E3A857),
      Color(0x3361A89A),
      Color(0x33C76D7E),
      Color(0x337C8FCF),
      Color(0x33A3B86C),
      Color(0x33D9895B),
      Color(0x33A584C4),
      Color(0x3353A7C9),
      Color(0x33D4B35A),
      Color(0x3389A07B),
      Color(0x33C98BA8),
      Color(0x3378A6A0),
    ][r % 12];
