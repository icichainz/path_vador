import 'dart:ui' show PathMetric;

import 'package:flutter/material.dart';

import 'theme.dart';
import 'tokens.dart';

/// Uppercase section label in the tertiary colour ("WINDOW", "TERMINAL").
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: Theme.of(
        context,
      ).textTheme.labelMedium?.copyWith(color: context.pv.tertiary),
    );
  }
}

/// A 1px dashed rounded border around [child].
class DashedBorder extends StatelessWidget {
  const DashedBorder({
    super.key,
    required this.child,
    this.color,
    this.radius = PvRadius.card,
    this.dash = 6,
    this.gap = 4,
    this.strokeWidth = 1,
  });

  final Widget child;
  final Color? color;
  final double radius;
  final double dash;
  final double gap;
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DashedRRectPainter(
        color: color ?? context.pv.outline,
        radius: radius,
        dash: dash,
        gap: gap,
        strokeWidth: strokeWidth,
      ),
      child: child,
    );
  }
}

class _DashedRRectPainter extends CustomPainter {
  const _DashedRRectPainter({
    required this.color,
    required this.radius,
    required this.dash,
    required this.gap,
    required this.strokeWidth,
  });

  final Color color;
  final double radius;
  final double dash;
  final double gap;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final inset = strokeWidth / 2;
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        inset,
        inset,
        size.width - strokeWidth,
        size.height - strokeWidth,
      ),
      Radius.circular(radius),
    );
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    for (final PathMetric metric
        in (Path()..addRRect(rrect)).computeMetrics()) {
      var d = 0.0;
      while (d < metric.length) {
        canvas.drawPath(metric.extractPath(d, d + dash), paint);
        d += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedRRectPainter old) =>
      old.color != color ||
      old.radius != radius ||
      old.dash != dash ||
      old.gap != gap ||
      old.strokeWidth != strokeWidth;
}

/// Small uppercase badge ("DETECTED", "ASSUMED").
class PvBadge extends StatelessWidget {
  const PvBadge(this.text, {super.key, this.color});

  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? context.pv.tertiary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: c.withValues(alpha: 0.6)),
      ),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.1,
          color: c,
        ),
      ),
    );
  }
}

/// One selectable row of a single-choice list: a radio dot, a title, an
/// optional mono example and an optional trailing widget.
class ChoiceRow extends StatelessWidget {
  const ChoiceRow({
    super.key,
    required this.title,
    required this.selected,
    required this.onTap,
    this.example,
    this.trailing,
  });

  final String title;
  final String? example;
  final bool selected;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final pv = context.pv;
    final shape = BorderRadius.circular(12);
    return Semantics(
      inMutuallyExclusiveGroup: true,
      checked: selected,
      button: true,
      child: Material(
        color: selected ? pv.surfaceContainerHigh : pv.surfaceContainer,
        shape: RoundedRectangleBorder(
          borderRadius: shape,
          side: BorderSide(
            color: selected ? pv.primary : pv.outline,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: InkWell(
          borderRadius: shape,
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 64),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  _RadioDot(selected: selected),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (example != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            example!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: pvMono(
                              context,
                              size: 12.5,
                              color: pv.onSurfaceMuted,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (trailing != null) ...[
                    const SizedBox(width: 12),
                    trailing!,
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RadioDot extends StatelessWidget {
  const _RadioDot({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    final pv = context.pv;
    return Container(
      width: 18,
      height: 18,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: selected ? pv.primary : pv.onSurfaceSubtle,
          width: 1.5,
        ),
      ),
      alignment: Alignment.center,
      child: selected
          ? Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: pv.primary,
              ),
            )
          : null,
    );
  }
}

/// A line in a [TerminalBlock].
class TerminalLine {
  const TerminalLine.comment(this.text) : prompt = null, _kind = _Kind.comment;
  const TerminalLine.command(this.text, {this.prompt = r'$'})
    : _kind = _Kind.command;
  const TerminalLine.output(this.text) : prompt = null, _kind = _Kind.output;

  final String text;
  final String? prompt;
  final _Kind _kind;
}

enum _Kind { comment, command, output }

/// A dark code block with prompts, commands and output (always uses the
/// dark tokens: [PvColors.terminal] is dark in both themes).
class TerminalBlock extends StatelessWidget {
  const TerminalBlock({super.key, required this.lines});

  final List<TerminalLine> lines;

  @override
  Widget build(BuildContext context) {
    const d = PvColors.dark;
    final bg = context.pv.terminal;
    TextStyle mono(Color c) => pvMono(context, size: 13, color: c, height: 1.6);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(PvRadius.card),
        border: Border.all(color: d.outlineSubtle),
      ),
      child: SelectionArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final l in lines)
              switch (l._kind) {
                _Kind.comment => Text(l.text, style: mono(d.onSurfaceSubtle)),
                _Kind.output => Text(l.text, style: mono(d.onSurfaceMuted)),
                _Kind.command => Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(text: '${l.prompt} ', style: mono(d.tertiary)),
                      TextSpan(text: l.text, style: mono(d.onSurface)),
                    ],
                  ),
                ),
              },
          ],
        ),
      ),
    );
  }
}
