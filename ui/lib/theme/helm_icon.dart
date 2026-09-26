import 'package:flutter/widgets.dart';

/// Paints the path_vador helm, reproducing `assets/icon/path_vador.svg`
/// (a 512-unit artboard) at any size. Used for the in-app logo and to
/// rasterise the launcher icons (`tool/render_icons_test.dart`).
///
/// With [clipToTile] the cape is clipped to the rounded tile, so nothing
/// spills past the corner radius; the SVG itself does not clip.
class HelmIconPainter extends CustomPainter {
  const HelmIconPainter({this.clipToTile = true});

  final bool clipToTile;

  static const double artboard = 512;

  static const _tile = Color(0xFF120F0D);
  static const _tileStroke = Color(0xFF2E2520);
  static const _cape = Color(0xFF0B0908);
  static const _dome = Color(0xFF1F1915);
  static const _domeStroke = Color(0xFF3A2F28);
  static const _brow = Color(0xFFF2A36E);
  static const _lens = Color(0xFF070605);
  static const _grille = Color(0xFF7AD7C7);

  /// The rounded tile every other shape sits on.
  static final RRect tileShape = RRect.fromRectAndRadius(
    const Rect.fromLTWH(0, 0, artboard, artboard),
    const Radius.circular(112),
  );

  @override
  void paint(Canvas canvas, Size size) {
    final side = size.shortestSide;
    canvas.save();
    canvas.translate((size.width - side) / 2, (size.height - side) / 2);
    canvas.scale(side / artboard);
    if (clipToTile) canvas.clipRRect(tileShape);

    Paint fill(Color c) => Paint()
      ..color = c
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;
    Paint stroke(
      Color c,
      double w, {
      StrokeCap cap = StrokeCap.butt,
      StrokeJoin join = StrokeJoin.miter,
    }) => Paint()
      ..color = c
      ..style = PaintingStyle.stroke
      ..strokeWidth = w
      ..strokeCap = cap
      ..strokeJoin = join
      ..isAntiAlias = true;

    // Tile and its inner hairline.
    canvas.drawRRect(tileShape, fill(_tile));
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(6, 6, 500, 500),
        const Radius.circular(106),
      ),
      stroke(_tileStroke, 4),
    );

    // Cape.
    canvas.drawPath(
      Path()
        ..moveTo(20, 512)
        ..lineTo(110, 352)
        ..lineTo(402, 352)
        ..lineTo(492, 512)
        ..close(),
      fill(_cape),
    );

    // Dome.
    final dome = Path()
      ..moveTo(100, 340)
      ..cubicTo(100, 174, 164, 96, 256, 96)
      ..cubicTo(348, 96, 412, 174, 412, 340)
      ..lineTo(412, 372)
      ..lineTo(100, 372)
      ..close();
    canvas.drawPath(dome, fill(_dome));
    canvas.drawPath(dome, stroke(_domeStroke, 6, join: StrokeJoin.round));

    // Ridge.
    canvas.drawLine(
      const Offset(256, 100),
      const Offset(256, 200),
      stroke(_tileStroke, 4, cap: StrokeCap.round),
    );

    // Brow.
    canvas.drawPath(
      Path()
        ..moveTo(130, 252)
        ..lineTo(256, 206)
        ..lineTo(382, 252),
      stroke(_brow, 16, cap: StrokeCap.round, join: StrokeJoin.round),
    );

    // Lenses.
    canvas.drawPath(
      Path()
        ..moveTo(146, 270)
        ..lineTo(236, 244)
        ..lineTo(236, 290)
        ..lineTo(168, 304)
        ..close(),
      fill(_lens),
    );
    canvas.drawPath(
      Path()
        ..moveTo(366, 270)
        ..lineTo(276, 244)
        ..lineTo(276, 290)
        ..lineTo(344, 304)
        ..close(),
      fill(_lens),
    );

    // Grille.
    final grille = stroke(_grille, 9, cap: StrokeCap.round);
    for (final x in const [222.0, 246.0, 270.0]) {
      canvas.drawLine(Offset(x, 354), Offset(x + 18, 314), grille);
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(HelmIconPainter oldDelegate) =>
      oldDelegate.clipToTile != clipToTile;
}

/// The app icon as a widget, [size] logical pixels square.
class HelmIcon extends StatelessWidget {
  const HelmIcon({super.key, this.size = 24});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: const CustomPaint(painter: HelmIconPainter()),
    );
  }
}
