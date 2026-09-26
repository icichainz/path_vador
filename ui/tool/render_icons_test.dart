// Rasterises the launcher icons from HelmIconPainter (the Dart twin of
// assets/icon/path_vador.svg). Not part of the normal test run; invoke with
//
//   flutter test tool/render_icons_test.dart
//   dart run flutter_launcher_icons
//
// Writes:
//   assets/icon/icon_1024.png        full-bleed tile (Windows, generic)
//   assets/icon/icon_macos_1024.png  824px tile centred on a transparent
//                                    1024 canvas with a soft drop shadow,
//                                    matching the macOS icon grid.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_vador_ui/theme/helm_icon.dart';

const double _canvas = 1024;

Future<void> _write(String path, void Function(Canvas) draw) async {
  final recorder = ui.PictureRecorder();
  draw(Canvas(recorder, const Rect.fromLTWH(0, 0, _canvas, _canvas)));
  final image = await recorder.endRecording().toImage(
    _canvas.toInt(),
    _canvas.toInt(),
  );
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  File(path).writeAsBytesSync(bytes!.buffer.asUint8List());
}

void main() {
  test('render launcher icons', () async {
    const painter = HelmIconPainter();

    await _write('assets/icon/icon_1024.png', (canvas) {
      painter.paint(canvas, const Size.square(_canvas));
    });

    await _write('assets/icon/icon_macos_1024.png', (canvas) {
      const art = 824.0;
      const inset = (_canvas - art) / 2;
      final tile = HelmIconPainter.tileShape.scaleRRect(
        art / HelmIconPainter.artboard,
      );
      canvas.drawRRect(
        tile.shift(const Offset(inset, inset + 10)),
        Paint()
          ..color = const Color(0x59000000)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14),
      );
      canvas.save();
      canvas.translate(inset, inset);
      painter.paint(canvas, const Size.square(art));
      canvas.restore();
    });
  });
}

extension on RRect {
  RRect scaleRRect(double s) => RRect.fromLTRBR(
    left * s,
    top * s,
    right * s,
    bottom * s,
    Radius.circular(tlRadiusX * s),
  );
}
