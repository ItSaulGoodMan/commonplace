import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme.dart';

/// Text with one phrase marked by a highlighter swipe, like a pen on paper.
///
/// The swipe follows the phrase across line breaks. [progress] (0 to 1) draws
/// it left to right, for the one-time reveal on a new note.
class HighlightedText extends StatelessWidget {
  const HighlightedText(
    this.text, {
    super.key,
    this.highlight = '',
    this.style,
    this.progress = 1,
    this.maxLines,
  });

  final String text;

  /// Exact substring of [text] to mark. Empty means no mark.
  final String highlight;
  final TextStyle? style;
  final double progress;
  final int? maxLines;

  @override
  Widget build(BuildContext context) {
    final palette = Palette.of(context);
    final base = DefaultTextStyle.of(context).style.merge(style);
    final start = highlight.isEmpty ? -1 : text.indexOf(highlight);
    final end = start < 0 ? -1 : start + highlight.length;

    final span = TextSpan(
      style: base,
      children: start < 0
          ? [TextSpan(text: text)]
          : [
              TextSpan(text: text.substring(0, start)),
              TextSpan(
                text: highlight,
                style: TextStyle(color: palette.onHighlighter),
              ),
              TextSpan(text: text.substring(end)),
            ],
    );

    return Semantics(
      label: text,
      excludeSemantics: true,
      child: _HighlightedParagraph(
        span: span,
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
        maxLines: maxLines,
        range: start < 0 ? null : TextRange(start: start, end: end),
        color: palette.highlighter,
        progress: progress.clamp(0, 1).toDouble(),
        seed: text.hashCode,
      ),
    );
  }
}

/// A paragraph that paints marker swipes under a range of its text.
///
/// A real render object (rather than a LayoutBuilder) so it can report
/// intrinsic sizes, like [Text] does. Slivers such as SliverFillRemaining and
/// IntrinsicHeight ask for those.
class _HighlightedParagraph extends LeafRenderObjectWidget {
  const _HighlightedParagraph({
    required this.span,
    required this.textDirection,
    required this.textScaler,
    required this.maxLines,
    required this.range,
    required this.color,
    required this.progress,
    required this.seed,
  });

  final InlineSpan span;
  final TextDirection textDirection;
  final TextScaler textScaler;
  final int? maxLines;
  final TextRange? range;
  final Color color;
  final double progress;
  final int seed;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderHighlightedParagraph(
        span: span,
        textDirection: textDirection,
        textScaler: textScaler,
        maxLines: maxLines,
        range: range,
        color: color,
        progress: progress,
        seed: seed,
      );

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderHighlightedParagraph renderObject,
  ) {
    renderObject
      ..span = span
      ..textDirection = textDirection
      ..textScaler = textScaler
      ..maxLines = maxLines
      ..range = range
      ..color = color
      ..progress = progress
      ..seed = seed;
  }
}

class _RenderHighlightedParagraph extends RenderBox {
  _RenderHighlightedParagraph({
    required InlineSpan span,
    required TextDirection textDirection,
    required TextScaler textScaler,
    required int? maxLines,
    required TextRange? range,
    required Color color,
    required double progress,
    required int seed,
  }) : _painter = TextPainter(
         text: span,
         textDirection: textDirection,
         textScaler: textScaler,
         maxLines: maxLines,
         ellipsis: maxLines == null ? null : '...',
       ),
       _range = range,
       _color = color,
       _progress = progress,
       _seed = seed;

  final TextPainter _painter;

  set span(InlineSpan value) {
    final diff = _painter.text?.compareTo(value) ?? RenderComparison.layout;
    if (diff == RenderComparison.identical) return;
    _painter.text = value;
    diff == RenderComparison.paint ? markNeedsPaint() : markNeedsLayout();
  }

  set textDirection(TextDirection value) {
    if (_painter.textDirection == value) return;
    _painter.textDirection = value;
    markNeedsLayout();
  }

  set textScaler(TextScaler value) {
    if (_painter.textScaler == value) return;
    _painter.textScaler = value;
    markNeedsLayout();
  }

  set maxLines(int? value) {
    if (_painter.maxLines == value) return;
    _painter
      ..maxLines = value
      ..ellipsis = value == null ? null : '...';
    markNeedsLayout();
  }

  TextRange? _range;
  set range(TextRange? value) {
    if (_range == value) return;
    _range = value;
    markNeedsPaint();
  }

  Color _color;
  set color(Color value) {
    if (_color == value) return;
    _color = value;
    markNeedsPaint();
  }

  double _progress;
  set progress(double value) {
    if (_progress == value) return;
    _progress = value;
    markNeedsPaint();
  }

  int _seed;
  set seed(int value) {
    if (_seed == value) return;
    _seed = value;
    markNeedsPaint();
  }

  void _layoutText(double maxWidth) => _painter.layout(maxWidth: maxWidth);

  @override
  double computeMinIntrinsicWidth(double height) {
    _layoutText(double.infinity);
    return _painter.minIntrinsicWidth;
  }

  @override
  double computeMaxIntrinsicWidth(double height) {
    _layoutText(double.infinity);
    return _painter.maxIntrinsicWidth;
  }

  @override
  double computeMinIntrinsicHeight(double width) {
    _layoutText(width);
    return _painter.height;
  }

  @override
  double computeMaxIntrinsicHeight(double width) =>
      computeMinIntrinsicHeight(width);

  @override
  Size computeDryLayout(covariant BoxConstraints constraints) {
    _layoutText(constraints.maxWidth);
    return constraints.constrain(Size(_painter.width, _painter.height));
  }

  @override
  void performLayout() {
    _layoutText(constraints.maxWidth);
    size = constraints.constrain(Size(_painter.width, _painter.height));
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final canvas = context.canvas;
    final r = _range;
    if (r != null && _progress > 0) {
      final boxes = _painter.getBoxesForSelection(
        TextSelection(baseOffset: r.start, extentOffset: r.end),
      );
      final rects = _mergeLines([
        for (final b in boxes) b.toRect().shift(offset),
      ]);
      final total = rects.fold<double>(0, (sum, rc) => sum + rc.width);
      var remaining = total * _progress;
      final paint = Paint()
        ..color = _color.withValues(alpha: 0.92)
        ..isAntiAlias = true;
      final rnd = math.Random(_seed);
      for (final rect in rects) {
        if (remaining <= 0) break;
        final visible = math.min(rect.width, remaining);
        remaining -= visible;
        canvas.drawPath(_swipe(rect, visible, rnd), paint);
      }
    }
    _painter.paint(canvas, offset);
  }

  /// One marker stroke: ends cut at a slight angle, edges not quite straight.
  static Path _swipe(Rect line, double visibleWidth, math.Random rnd) {
    final h = line.height;
    double j(double amount) => (rnd.nextDouble() - 0.5) * amount;
    final left = line.left - 3;
    final right = line.left + visibleWidth + 3;
    // Cover the full glyph height: the marked words are drawn in a dark ink,
    // so in dark mode any part of a letter outside the swipe would vanish
    // into the background.
    final top = line.top + h * 0.08;
    final bottom = line.bottom + h * 0.02;
    return Path()
      ..moveTo(left + 2 + j(2), top + j(2))
      ..quadraticBezierTo(
        (left + right) / 2,
        top - 1 + j(2),
        right + j(2),
        top + 1 + j(2),
      )
      ..lineTo(right - 3 + j(2), bottom + j(2))
      ..quadraticBezierTo(
        (left + right) / 2,
        bottom + 1.5 + j(2),
        left + j(2),
        bottom - 1 + j(2),
      )
      ..close();
  }

  /// Joins per-word boxes on the same line into one rect per line.
  static List<Rect> _mergeLines(List<Rect> rects) {
    final lines = <Rect>[];
    for (final rect in rects) {
      final i = lines.indexWhere(
        (l) => (l.center.dy - rect.center.dy).abs() < rect.height / 2,
      );
      if (i < 0) {
        lines.add(rect);
      } else {
        lines[i] = lines[i].expandToInclude(rect);
      }
    }
    return lines;
  }

  @override
  void dispose() {
    _painter.dispose();
    super.dispose();
  }
}

/// Plays the highlighter draw-in once, after [delay]. Respects reduced motion.
class HighlightReveal extends StatefulWidget {
  const HighlightReveal({
    super.key,
    required this.animate,
    required this.builder,
    this.delay = Duration.zero,
  });

  final bool animate;
  final Duration delay;
  final Widget Function(BuildContext context, double progress) builder;

  @override
  State<HighlightReveal> createState() => _HighlightRevealState();
}

class _HighlightRevealState extends State<HighlightReveal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: Motion.highlightStroke,
    value: widget.animate ? 0 : 1,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.value = 1;
    } else if (widget.animate && _controller.value == 0) {
      Future<void>.delayed(widget.delay, () {
        if (mounted) _controller.forward();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    builder: (context, _) =>
        widget.builder(context, Motion.curve.transform(_controller.value)),
  );
}
