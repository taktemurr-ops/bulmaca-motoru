import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:studio_core/app/game_api.dart';
import 'package:studio_core/app/services/audio.dart';
import 'package:studio_core/core/game_rules.dart';

import 'board_style.dart';
import 'core.dart';
import 'symbols.dart';
import 'texts.dart';
import 'studio_chrome.dart';

/// Bütün ızgara bulmacaları için ortak ekran.
class PuzzleView extends StatefulWidget {
  final PlayContext ctx;
  final PuzzleRules rules;
  const PuzzleView({super.key, required this.ctx, required this.rules});

  @override
  State<PuzzleView> createState() => _PuzzleViewState();
}

class _PuzzleViewState extends State<PuzzleView> with SingleTickerProviderStateMixin {
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
  // kalem notları (aday rakamlar, bit maskesi) ve not kipi
  late List<int> _notes;
  bool _noteMode = false;
  // karalama kalemi: 0 döngü, 1 doldur, 2 işaretle
  int _pen = 0;
  // çözüm kutlaması
  late final AnimationController _win = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100));

  PlayContext get ctx => widget.ctx;

  @override
  void initState() {
    super.initState();
    lv = (ctx.generated as GeneratedLevel<PLevel>).puzzle;
    kind = widget.rules.kindForSpec(ctx.spec);
    final snap = ctx.resume['snap'];
    st = (snap is String ? PState.restore(snap, lv) : null) ?? kind.initial(lv);
    _notes = _parseNotes(ctx.resume['notes']);
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
    _win.dispose();
    super.dispose();
  }

  List<int> _parseNotes(Object? o) {
    final out = List<int>.filled(lv.n, 0);
    if (o is String && o.isNotEmpty) {
      final parts = o.split(',');
      if (parts.length == lv.n) {
        for (var i = 0; i < lv.n; i++) {
          out[i] = int.tryParse(parts[i]) ?? 0;
        }
      }
    }
    return out;
  }

  String get _notesText => _notes.any((v) => v != 0) ? _notes.join(',') : '';

  void _persist() =>
      ctx.saveResume({'snap': st.serialize(), 'notes': _notesText, 'secs': _seconds, 'hints': _hints, 'moves': _moves});

  bool _locked(int i) => lv.givens.isNotEmpty && lv.givens[i] >= 0;

  void _push() {
    _undo.add('${st.serialize()}#$_notesText');
    if (_undo.length > 400) _undo.removeAt(0);
  }

  void _changed() {
    _moves++;
    _persist();
    if (kind.failed(lv, st)) {
      _ended = true;
      ctx.sfx(Sfx.lose);
      Future.delayed(const Duration(milliseconds: 700), () async {
        if (!mounted) return;
        // Piyasadaki örneklerdeki gibi "devam et" teklifi (reklam/jeton):
        // kabul edilirse son hamle geri alınır ve oyun sürer.
        final more = await ctx.requestContinue();
        if (!mounted) return;
        if (more && _undo.isNotEmpty) {
          _ended = false;
          _undoMove();
          return;
        }
        ctx.finish(RoundResult(won: false, seconds: _seconds, moves: _moves, hintsUsed: _hints));
      });
      return;
    }
    if (kind.solved(lv, st)) {
      _ended = true;
      _sel = null;
      ctx.sfx(Sfx.win);
      final stars = _hints == 0 ? 3 : (_hints <= 2 ? 2 : 1);
      // Kutlama: tahtanın üstünden ışık geçer, hücreler sırayla parlar
      // (azaltılmış hareket seçiliyse yalnız kısa bekleme).
      if (!ctx.reducedMotion) _win.forward(from: 0);
      Future.delayed(Duration(milliseconds: ctx.reducedMotion ? 450 : 1250), () {
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
  double _csy = 1;
  late Offset _origin;

  Rect _cell(int i) => Rect.fromLTWH(_origin.dx + (i % lv.w) * _cs, _origin.dy + (i ~/ lv.w) * _csy, _cs, _csy);

  int? _cellAt(Offset p) {
    final x = ((p.dx - _origin.dx) / _cs).floor(), y = ((p.dy - _origin.dy) / _csy).floor();
    if (x < 0 || y < 0 || x >= lv.w || y >= lv.h) return null;
    return y * lv.w + x;
  }

  /// Izgara dışındaki dokunuş: (taraf, sıra).
  (int, int)? _outsideAt(Offset p) {
    final fx = (p.dx - _origin.dx) / _cs, fy = (p.dy - _origin.dy) / _csy;
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
    final fx = (p.dx - _origin.dx) / _cs, fy = (p.dy - _origin.dy) / _csy;
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
        setState(() => _cycleTap(i));
        ctx.sfx(Sfx.place);
        _changed();
      case CellInput.none:
        break;
    }
  }

  /// Döngülü hücre dokunuşu: kalem seçiliyse doldur/işaretle, yoksa türün döngüsü.
  void _cycleTap(int i) {
    if (_pen != 0 && kind.fillMarkTools(lv)) {
      final v = _pen == 1 ? 1 : kind.markState;
      st.cells[i] = st.cells[i] == v ? 0 : v;
    } else {
      kind.onTap(lv, st, i);
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
      setState(() => _cycleTap(i));
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
    if (_noteMode && kind.notesFor(lv) && st.cells[i] <= 0) {
      _push();
      setState(() => _notes[i] ^= 1 << v);
      ctx.sfx(Sfx.tap);
      _persist();
      return;
    }
    _push();
    setState(() {
      st.cells[i] = st.cells[i] == v ? 0 : v;
      if (st.cells[i] > 0) _placed(i, v);
    });
    ctx.sfx(Sfx.place);
    _changed();
  }

  /// Yerleştirilen rakam: hücrenin notları silinir, aynı rakam komşu
  /// hücrelerin notlarından düşer (piyasadaki Sudoku uygulamalarındaki gibi).
  void _placed(int i, int v) {
    _notes[i] = 0;
    for (final j in kind.digitPeers(lv, i)) {
      _notes[j] &= ~(1 << v);
    }
  }

  void _undoMove() {
    if (_undo.isEmpty || _ended) return;
    final raw = _undo.removeLast();
    final cut = raw.indexOf('#');
    final s = PState.restore(cut < 0 ? raw : raw.substring(0, cut), lv);
    if (s == null) return;
    setState(() {
      st = s;
      _notes = _parseNotes(cut < 0 ? '' : raw.substring(cut + 1));
    });
    _persist();
  }

  void _clear() {
    if (_ended) return;
    _push();
    setState(() {
      st = kind.initial(lv);
      _notes = List<int>.filled(lv.n, 0);
    });
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
        if (kind.cellInput == CellInput.digits) {
          _sel = idx;
          if (lv.solCells[idx] > 0) _placed(idx, lv.solCells[idx]);
        }
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
    // Tahta (kâğıt, mürekkep) oyunun alışılmış temasıyla çizilir; çevresindeki
    // arayüz (üst bilgi, rakam takımı, palet) onaylı stüdyo temasıyla.
    final scheme = Theme.of(context).colorScheme;
    return StudioChrome(child: Builder(builder: (context) => _build(context, scheme)));
  }

  Widget _build(BuildContext context, ColorScheme scheme) {
    final look = StudioLook.of(context);
    final style = BoardStyle.of(widget.rules.gameId, kind.id, scheme.primary);
    final lang = ctx.lang;
    final status = kind.status(lv, st, lang);
    final (mt, ml, mb, mr) = kind.margins(lv);
    final digits = kind.cellInput == CellInput.digits;
    final colors = kind.cellInput == CellInput.colors;
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
                  child: Text(status,
                      maxLines: 1,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: kStudioText, fontWeight: FontWeight.w800)))),
          IconButton(tooltip: bt(lang, 'undo'), onPressed: _undo.isEmpty ? null : _undoMove, icon: const Icon(Icons.undo)),
          IconButton(tooltip: bt(lang, 'clear'), onPressed: _clear, icon: const Icon(Icons.restart_alt)),
          if (kind.hintable) IconButton(tooltip: bt(lang, 'hint'), onPressed: _hint, icon: const Icon(Icons.lightbulb_outline)),
        ]),
      ),
      Expanded(
        child: LayoutBuilder(builder: (context, box) {
          final cols = lv.w + ml + mr, rows = lv.h + mt + mb;
          final asp = kind.cellAspect(lv);
          // Çerçeve payı (yarım hücre) tahtanın dışında kalır.
          _cs = math.min((box.maxWidth - 16) / (cols + 0.6), (box.maxHeight - 16) / (rows * asp + 0.6));
          _csy = _cs * asp;
          final bw = _cs * cols, bh = _csy * rows;
          final left = (box.maxWidth - bw) / 2, top = (box.maxHeight - bh) / 2;
          _origin = Offset(left + ml * _cs, top + mt * _csy);
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
                csy: _csy,
                origin: _origin,
                sel: digits ? _sel : null,
                path: List.of(_path),
                style: style,
                ink: style.ink,
                accent: style.accent ?? scheme.primary,
                accent2: ctx.pieceColors.length > 1 ? ctx.pieceColors[1] : scheme.tertiary,
                paper: style.paper,
                notes: digits ? _notes : const [],
                win: _win,
                colorBlind: ctx.colorBlind,
                lang: lang,
              ),
            ),
          );
        }),
      ),
      if (digits) _numberPad(scheme, style),
      if (kind.fillMarkTools(lv)) _penRow(),
      if (colors) _palette(scheme),
      const SizedBox(height: 6),
    ]);
  }

  Widget _numberPad(ColorScheme scheme, BoardStyle style) {
    final max = kind.cellStates(lv) - 1;
    final values = kind.padValues(lv, st) ?? [for (var v = 1; v <= max; v++) v];
    final notes = kind.notesFor(lv);
    final quota = kind.digitQuota(lv);
    final used = <int, int>{};
    if (quota > 0) {
      for (final v in st.cells) {
        if (v > 0) used[v] = (used[v] ?? 0) + 1;
      }
    }
    final selVal = _sel == null ? 0 : st.cells[_sel!];
    Widget key(int v, {double? width}) {
      final left = quota > 0 ? quota - (used[v] ?? 0) : -1;
      return _PadKey(
        width: width,
        active: selVal == v,
        done: left == 0,
        onTap: () => _digit(v),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(kind.digitLabel(v),
              style: TextStyle(
                  color: kStudioText,
                  fontSize: _noteMode && notes ? 17 : 22,
                  fontWeight: _noteMode && notes ? FontWeight.w600 : FontWeight.w800,
                  fontStyle: _noteMode && notes ? FontStyle.italic : FontStyle.normal)),
          if (left > 0) Text('$left', style: const TextStyle(color: kStudioTextDim, fontSize: 10, height: 1)),
        ]),
      );
    }

    final erase = _ToolKey(
      icon: Icons.backspace_outlined,
      label: bt(ctx.lang, 'erase'),
      onTap: () {
        final i = _sel;
        if (i == null || _locked(i) || (st.cells[i] == 0 && _notes[i] == 0)) return;
        _push();
        setState(() {
          st.cells[i] = 0;
          _notes[i] = 0;
        });
        _persist();
      },
    );
    final tools = Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        erase,
        if (notes) ...[
          const SizedBox(width: 10),
          _ToolKey(
            icon: Icons.edit_note,
            label: bt(ctx.lang, 'notes'),
            on: _noteMode,
            onTap: () => setState(() => _noteMode = !_noteMode),
          ),
        ],
      ]),
    );
    final row = values.length <= 10
        ? Row(children: [
            for (final v in values)
              Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 2), child: key(v))),
          ])
        : Wrap(
            alignment: WrapAlignment.center,
            spacing: 4,
            runSpacing: 4,
            children: [for (final v in values) key(v, width: 40)],
          );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Column(mainAxisSize: MainAxisSize.min, children: [tools, row]),
      ),
    );
  }

  Widget _penRow() => Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          _ToolKey(
            icon: Icons.crop_square_rounded,
            label: bt(ctx.lang, 'fill'),
            on: _pen == 1,
            onTap: () => setState(() => _pen = _pen == 1 ? 0 : 1),
          ),
          const SizedBox(width: 10),
          _ToolKey(
            icon: Icons.close_rounded,
            label: bt(ctx.lang, 'mark'),
            on: _pen == 2,
            onTap: () => setState(() => _pen = _pen == 2 ? 0 : 2),
          ),
        ]),
      );

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
                border: Border.all(
                    color: v == _brush ? StudioLook.of(context).accent : Colors.white38, width: v == _brush ? 4 : 1.2),
                boxShadow: v == _brush ? const [BoxShadow(color: Colors.black54, blurRadius: 6)] : null,
              ),
              child: ctx.colorBlind ? Center(child: Text('$v', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))) : null,
            ),
          ),
      ]),
    );
  }
}

/// Rakam takımının tuşu: koyu degrade kare, vurgu kenarı, beyaz rakam.
/// [done]: rakam ızgarada tamamlandı (soluk); [active]: seçili hücredeki rakam.
class _PadKey extends StatelessWidget {
  final double? width;
  final VoidCallback onTap;
  final Widget child;
  final bool active, done;
  const _PadKey({this.width, required this.onTap, required this.child, this.active = false, this.done = false});

  @override
  Widget build(BuildContext context) {
    final look = StudioLook.of(context);
    final r = BorderRadius.circular(12);
    return SizedBox(
      width: width,
      height: 52,
      child: Opacity(
        opacity: done ? 0.38 : 1,
        child: Material(
          color: Colors.transparent,
          borderRadius: r,
          child: InkWell(
            borderRadius: r,
            onTap: onTap,
            child: Ink(
              decoration: BoxDecoration(
                borderRadius: r,
                gradient: look.tile,
                border: Border.all(color: look.accent.withValues(alpha: active ? 1 : 0.5), width: active ? 2.4 : 1.2),
              ),
              child: Center(child: child),
            ),
          ),
        ),
      ),
    );
  }
}

/// Araç tuşu (sil, not): simge + kısa yazı; [on] açık durumu.
class _ToolKey extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool? on;
  const _ToolKey({required this.icon, required this.label, required this.onTap, this.on});

  @override
  Widget build(BuildContext context) {
    final look = StudioLook.of(context);
    final lit = on ?? false;
    final r = BorderRadius.circular(20);
    return Semantics(
      button: true,
      toggled: on,
      label: label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: r,
          onTap: onTap,
          child: Ink(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              borderRadius: r,
              color: lit ? look.accent.withValues(alpha: 0.85) : look.sheet.withValues(alpha: 0.85),
              border: Border.all(color: look.accent.withValues(alpha: 0.6), width: 1.2),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(icon, size: 20, color: kStudioText),
              const SizedBox(width: 6),
              Text(on == null ? label : '$label ${lit ? '✓' : ''}'.trim(),
                  style: const TextStyle(color: kStudioText, fontWeight: FontWeight.w700, fontSize: 13)),
            ]),
          ),
        ),
      ),
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
  final double csy;
  final Offset origin;
  final int? sel;
  final List<int> path;
  final Color ink, accent, accent2, paper;
  final BoardStyle style;
  final List<int> notes;
  final Animation<double> win;
  final bool colorBlind;
  final String lang;

  _GridPainter({
    required this.lv,
    required this.kind,
    required this.st,
    required this.cs,
    this.csy = 0,
    required this.origin,
    required this.sel,
    required this.path,
    required this.ink,
    required this.accent,
    required this.accent2,
    required this.paper,
    required this.style,
    required this.notes,
    required this.win,
    required this.colorBlind,
    required this.lang,
  }) : super(repaint: win);

  double get _cy => csy > 0 ? csy : cs;
  Rect cell(int i) => Rect.fromLTWH(origin.dx + (i % lv.w) * cs, origin.dy + (i ~/ lv.w) * _cy, cs, _cy);

  Offset vertex(int v) => origin + Offset((v % (lv.w + 1)) * cs, (v ~/ (lv.w + 1)) * cs);

  @override
  void paint(Canvas c, Size size) {
    final board = Rect.fromLTWH(origin.dx, origin.dy, lv.w * cs, lv.h * _cy);
    final (pt, pl, pb, pr) = kind.margins(lv);
    if (pt + pl + pb + pr > 0) {
      // İpuçları koyu mürekkeple yazılır: koyu dünya arka planında da okunsun diye kenar şeridi açık zemin.
      final outer = Rect.fromLTRB(board.left - pl * cs, board.top - pt * _cy, board.right + pr * cs, board.bottom + pb * _cy);
      final strip = RRect.fromRectAndRadius(outer.inflate(cs * 0.12), Radius.circular(cs * 0.25));
      c.drawRRect(strip.shift(Offset(0, math.max(2, cs * 0.05))), Paint()..color = const Color(0x26000000));
      c.drawRRect(strip, Paint()..color = Color.lerp(style.paper, style.paper2, 0.5)!.withValues(alpha: 0.94));
      c.drawRRect(
          strip,
          Paint()
            ..style = PaintingStyle.stroke
            ..color = style.frameColor.withValues(alpha: 0.45)
            ..strokeWidth = 1.2);
    }
    style.paintBoard(c, board, cs);
    // Bölge tonları
    if (kind.tintRegions && lv.regions.isNotEmpty) {
      for (var i = 0; i < lv.n; i++) {
        final t = regionTint(lv.regions[i]);
        c.drawRect(cell(i), Paint()..color = t.withValues(alpha: kind.regionTintStrength));
      }
    }
    final s0 = sel;
    if (s0 != null) {
      // Seçili hücrenin satır/sütun/kutusu ve aynı rakamlar (Sudoku.com gibi).
      final peerTint = Paint()..color = accent.withValues(alpha: 0.09);
      for (final j in kind.digitPeers(lv, s0)) {
        c.drawRect(cell(j), peerTint);
      }
      final v0 = st.cells[s0];
      if (v0 > 0) {
        final same = Paint()..color = accent.withValues(alpha: 0.20);
        for (var j = 0; j < lv.n; j++) {
          if (j != s0 && st.cells[j] == v0 && (lv.clues.isEmpty || lv.clues[j] < 0)) c.drawRect(cell(j), same);
        }
      }
      c.drawRect(cell(s0), Paint()..color = accent.withValues(alpha: 0.30));
    }
    kind.paintUnder(c, lv, st, cell, cs);
    // Hücre içerikleri
    for (var i = 0; i < lv.n; i++) {
      final lk = kind.look(lv, st, i);
      final r = cell(i);
      if (lk.color >= 0) c.drawRect(r.deflate(cs * 0.02), Paint()..color = puzzleColor(lk.color));
      paintMark(c, lk.mark, r, ink: ink, accent: accent, accent2: accent2, dir: lk.arrowDir);
      if (lk.text.isEmpty && i < notes.length && notes[i] != 0) _paintNotes(c, r, notes[i]);
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
    _paintWin(c, board);
  }

  /// Kalem notları: hücrede 3x3 küçük rakamlar; seçili rakam vurgulu.
  void _paintNotes(Canvas c, Rect r, int mask) {
    final hv = sel != null ? st.cells[sel!] : 0;
    for (var v = 1; v <= 9; v++) {
      if (mask & (1 << v) == 0) continue;
      final col = (v - 1) % 3, row = (v - 1) ~/ 3;
      final o = Offset(r.left + r.width * (col + 0.5) / 3, r.top + r.height * (row + 0.5) / 3);
      if (v == hv) c.drawCircle(o, r.width * 0.15, Paint()..color = accent.withValues(alpha: 0.25));
      _text(c, '$v', o, r.width * 0.24, ink.withValues(alpha: 0.72), v == hv ? FontWeight.w800 : FontWeight.w500);
    }
  }

  /// Çözüm kutlaması: hücreler köşegen dalga hâlinde parlar, üstünden ışık geçer.
  void _paintWin(Canvas c, Rect board) {
    final t = win.value;
    if (t <= 0 || t >= 1) return;
    final span = (lv.w + lv.h).toDouble();
    for (var i = 0; i < lv.n; i++) {
      final d = ((i % lv.w) + (i ~/ lv.w)) / span;
      final k = ((t * 1.6 - d) * 3).clamp(0.0, 1.0);
      final a = math.sin(k * math.pi);
      if (a <= 0.01) continue;
      c.drawRRect(RRect.fromRectAndRadius(cell(i).deflate(cs * 0.06), Radius.circular(cs * 0.14)),
          Paint()..color = accent.withValues(alpha: 0.28 * a));
    }
    final x = board.left - board.width * 0.4 + board.width * 1.8 * t;
    c.save();
    c.clipRect(board);
    c.drawRect(
        board,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [Colors.white.withValues(alpha: 0), Colors.white.withValues(alpha: 0.55), Colors.white.withValues(alpha: 0)],
          ).createShader(Rect.fromLTWH(x - board.width * 0.2, board.top, board.width * 0.4, board.height)));
    c.restore();
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
