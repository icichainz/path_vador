import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_vador_ui/inspector/widgets.dart';

void main() {
  const style = TextStyle(fontSize: 12);
  const long =
      '~/AndroidStudioProjects/realtime_translator_full/design/tenant-console';

  test('fit returns the text unchanged when it fits', () {
    expect(
      MiddleEllipsisText.fit('~/dev', style, 400, TextScaler.noScaling),
      '~/dev',
    );
  });

  test('fit keeps both ends and favours the tail', () {
    final shown = MiddleEllipsisText.fit(
      long,
      style,
      200,
      TextScaler.noScaling,
    );
    expect(shown, contains('…'));
    expect(shown.startsWith('~/'), isTrue);
    expect(shown.endsWith('console'), isTrue);
    expect(shown.length, lessThan(long.length));
  });

  testWidgets('a long path stays on one line with a tooltip', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 200,
            child: MiddleEllipsisText(long, style: style),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.byTooltip(long), findsOneWidget);
    expect(tester.getSize(find.byType(Text)).height, lessThan(24));
  });
}
