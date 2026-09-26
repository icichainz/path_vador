import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/theme.dart' show pvMonoFamily;
import '../theme/tokens.dart';

/// The [PvColors] matching the ambient brightness. Read directly from the
/// tokens so the inspector does not depend on the app theme extension.
PvColors ipColors(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
    ? PvColors.dark
    : PvColors.light;

/// Monospace text style used for every path and command.
TextStyle ipMono(
  BuildContext context, {
  double size = 14,
  Color? color,
  FontWeight? weight,
}) {
  return TextStyle(
    fontFamily: pvMonoFamily,
    fontFamilyFallback: const [
      'SF Mono',
      'Menlo',
      'Cascadia Mono',
      'Consolas',
      'DejaVu Sans Mono',
      'monospace',
    ],
    fontSize: size,
    height: 1.35,
    color: color ?? ipColors(context).onSurface,
    fontWeight: weight,
  );
}

/// Duration of every "Copied" confirmation.
const copiedDuration = Duration(milliseconds: 1600);

/// Puts [text] on the clipboard and shows a floating "Copied" snack bar.
Future<void> copyToClipboard(BuildContext context, String text) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  final colors = ipColors(context);
  await Clipboard.setData(ClipboardData(text: text));
  messenger
    ?..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        duration: copiedDuration,
        width: 180,
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check, size: 16, color: colors.tertiary),
            const SizedBox(width: PvSpace.sm),
            const Text('Copied'),
          ],
        ),
      ),
    );
}

/// 1px-outlined, radius-14 container used by every result list.
class OutlinedCard extends StatelessWidget {
  /// Creates the card.
  const OutlinedCard({super.key, required this.child, this.padding});

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final c = ipColors(context);
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: c.surfaceContainer,
        border: Border.all(color: c.outline),
        borderRadius: BorderRadius.circular(PvRadius.card),
      ),
      child: child,
    );
  }
}

/// "Copy" button that reads "Copied" in tertiary for 1.6 s after a click.
/// With [filled] it is the primary FilledButton with a copy icon.
class CopyButton extends StatefulWidget {
  /// Creates the button; a null [value] disables it.
  const CopyButton({super.key, required this.value, this.filled = false});

  final String? value;
  final bool filled;

  @override
  State<CopyButton> createState() => _CopyButtonState();
}

class _CopyButtonState extends State<CopyButton> {
  bool _copied = false;
  Timer? _timer;

  Future<void> _copy() async {
    final value = widget.value;
    if (value == null) return;
    await copyToClipboard(context, value);
    if (!mounted) return;
    _timer?.cancel();
    setState(() => _copied = true);
    _timer = Timer(copiedDuration, () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = ipColors(context);
    final label = _copied ? 'Copied' : 'Copy';
    final onPressed = widget.value == null ? null : _copy;
    if (widget.filled) {
      return FilledButton.icon(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: c.primary,
          foregroundColor: c.onPrimary,
          minimumSize: const Size(96, pvTouchTarget),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(PvRadius.control),
          ),
        ),
        icon: Icon(_copied ? Icons.check : Icons.copy_rounded, size: 18),
        label: Text(label),
      );
    }
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: _copied ? c.tertiary : c.onSurfaceMuted,
        minimumSize: const Size(64, pvTouchTarget),
        padding: const EdgeInsets.symmetric(horizontal: PvSpace.md),
      ),
      child: Text(label),
    );
  }
}

/// One labelled value of a result list: label (92 px), mono value, an
/// optional "→ env" button and a [CopyButton]. An empty [value] shows
/// "(none)" in the subtle colour and cannot be copied.
class ResultRow extends StatefulWidget {
  /// Creates the row.
  const ResultRow({
    super.key,
    required this.label,
    required this.value,
    this.valueSize = 15,
    this.onSendToEnv,
    this.onFocused,
    this.trailing = const [],
  });

  final String label;
  final String value;
  final double valueSize;

  /// Shows the "→ env" button when set.
  final VoidCallback? onSendToEnv;

  /// Called when the row or one of its buttons gains focus.
  final VoidCallback? onFocused;

  /// Extra buttons placed before Copy.
  final List<Widget> trailing;

  @override
  State<ResultRow> createState() => _ResultRowState();
}

class _ResultRowState extends State<ResultRow> {
  final _focus = FocusNode(debugLabel: 'ResultRow');

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = ipColors(context);
    final empty = widget.value.isEmpty;
    return Focus(
      focusNode: _focus,
      onFocusChange: (has) {
        if (has) widget.onFocused?.call();
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _focus.requestFocus,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 52),
          child: Padding(
            padding: const EdgeInsets.only(left: PvSpace.lg, right: PvSpace.xs),
            child: Row(
              children: [
                SizedBox(
                  width: 92,
                  child: Text(
                    widget.label,
                    style: TextStyle(
                      color: c.onSurfaceSubtle,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: PvSpace.md),
                    child: Text(
                      empty ? '(none)' : widget.value,
                      softWrap: true,
                      style: ipMono(
                        context,
                        size: widget.valueSize,
                        color: empty ? c.onSurfaceSubtle : c.onSurface,
                      ),
                    ),
                  ),
                ),
                if (widget.onSendToEnv != null)
                  SizedBox.square(
                    dimension: 40,
                    child: IconButton(
                      tooltip: 'Send to Env',
                      padding: EdgeInsets.zero,
                      iconSize: 18,
                      color: c.onSurfaceMuted,
                      onPressed: empty ? null : widget.onSendToEnv,
                      icon: const Icon(Icons.arrow_forward),
                    ),
                  ),
                ...widget.trailing,
                CopyButton(value: empty ? null : widget.value),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A box with a dashed rounded border, used for empty states and the drop
/// overlay.
class DashedBox extends StatelessWidget {
  /// Creates the box.
  const DashedBox({
    super.key,
    required this.child,
    this.color,
    this.radius = PvRadius.card,
    this.strokeWidth = 1,
    this.padding = const EdgeInsets.all(PvSpace.xxl),
  });

  final Widget child;
  final Color? color;
  final double radius;
  final double strokeWidth;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DashedPainter(
        color: color ?? ipColors(context).outline,
        radius: radius,
        strokeWidth: strokeWidth,
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

class _DashedPainter extends CustomPainter {
  _DashedPainter({
    required this.color,
    required this.radius,
    required this.strokeWidth,
  });

  final Color color;
  final double radius;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;
    final inset = strokeWidth / 2;
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        inset,
        inset,
        size.width - 2 * inset,
        size.height - 2 * inset,
      ),
      Radius.circular(radius),
    );
    const dash = 6.0;
    const gap = 5.0;
    for (final metric in (Path()..addRRect(rrect)).computeMetrics()) {
      var d = 0.0;
      while (d < metric.length) {
        canvas.drawPath(metric.extractPath(d, d + dash), paint);
        d += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedPainter old) =>
      old.color != color ||
      old.radius != radius ||
      old.strokeWidth != strokeWidth;
}

/// One option of [SegmentedPills].
class PillSegment<T> {
  /// Creates a segment.
  const PillSegment(this.value, this.label);

  final T value;
  final String label;
}

/// Segmented control: 34 px pills in a 1px-outlined container; the
/// selected pill sits on surfaceContainerHigh.
class SegmentedPills<T> extends StatelessWidget {
  /// Creates the control.
  const SegmentedPills({
    super.key,
    required this.segments,
    required this.selected,
    required this.onChanged,
  });

  final List<PillSegment<T>> segments;
  final T selected;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = ipColors(context);
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        border: Border.all(color: c.outline),
        borderRadius: BorderRadius.circular(PvRadius.control + 3),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final s in segments)
            Semantics(
              selected: s.value == selected,
              button: true,
              child: Material(
                color: s.value == selected
                    ? c.surfaceContainerHigh
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(PvRadius.control),
                child: InkWell(
                  borderRadius: BorderRadius.circular(PvRadius.control),
                  onTap: () => onChanged(s.value),
                  child: Container(
                    height: 34,
                    padding: const EdgeInsets.symmetric(
                      horizontal: PvSpace.md + 2,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      s.label,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: s.value == selected
                            ? c.onSurface
                            : c.onSurfaceMuted,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// A command in a terminal-coloured box, mono 16, selectable.
class TerminalBlock extends StatelessWidget {
  /// Creates the block.
  const TerminalBlock({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(PvSpace.lg),
      decoration: BoxDecoration(
        color: ipColors(context).terminal,
        borderRadius: BorderRadius.circular(PvRadius.control),
      ),
      child: SelectableText(
        text,
        style: ipMono(context, size: 16, color: PvColors.dark.onSurface),
      ),
    );
  }
}

/// Inline engine error: errorContainer background, error border and text.
class ErrorBox extends StatelessWidget {
  /// Creates the box; [action] goes under the message.
  const ErrorBox({super.key, required this.message, this.action});

  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final c = ipColors(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(PvSpace.lg),
      decoration: BoxDecoration(
        color: c.errorContainer,
        border: Border.all(color: c.error),
        borderRadius: BorderRadius.circular(PvRadius.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.error_outline, size: 18, color: c.error),
              const SizedBox(width: PvSpace.sm),
              Expanded(
                child: SelectableText(
                  message,
                  style: TextStyle(color: c.onErrorContainer, fontSize: 14),
                ),
              ),
            ],
          ),
          if (action != null) ...[const SizedBox(height: PvSpace.md), action!],
        ],
      ),
    );
  }
}

/// Dashed empty-state placeholder with a title and an optional subtitle.
class EmptyHint extends StatelessWidget {
  /// Creates the placeholder.
  const EmptyHint({super.key, required this.title, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final c = ipColors(context);
    return SizedBox(
      width: double.infinity,
      child: DashedBox(
        padding: const EdgeInsets.symmetric(
          horizontal: PvSpace.xxl,
          vertical: PvSpace.page,
        ),
        child: Column(
          children: [
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(color: c.onSurfaceMuted, fontSize: 14),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: PvSpace.xs),
              Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: TextStyle(color: c.onSurfaceSubtle, fontSize: 13),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Section label ("RECENT", "EXPORT COMMAND") in labelMedium.
class SectionLabel extends StatelessWidget {
  /// Creates the label; [color] defaults to onSurfaceSubtle.
  const SectionLabel(this.text, {super.key, this.color});

  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.labelMedium?.copyWith(
        color: color ?? ipColors(context).onSurfaceSubtle,
        letterSpacing: 0.8,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

/// Decoration shared by the inspector text fields.
InputDecoration ipFieldDecoration(
  BuildContext context, {
  required String hint,
  String? label,
  Widget? suffix,
  double height = 48,
}) {
  final c = ipColors(context);
  OutlineInputBorder border(Color color, [double width = 1]) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(PvRadius.control),
        borderSide: BorderSide(color: color, width: width),
      );
  return InputDecoration(
    hintText: hint,
    labelText: label,
    hintStyle: TextStyle(color: c.onSurfaceSubtle),
    filled: true,
    fillColor: c.surfaceContainer,
    contentPadding: const EdgeInsets.symmetric(horizontal: PvSpace.lg),
    constraints: BoxConstraints.tightFor(height: height),
    enabledBorder: border(c.outline),
    border: border(c.outline),
    focusedBorder: border(c.primary, 1.5),
    suffixIcon: suffix,
  );
}
