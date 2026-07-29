import 'package:flutter_test/flutter_test.dart';
import 'package:nucleus_frontend/main.dart';

void main() {
  testWidgets('App loads smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const NucleusApp());
    expect(find.text('Nucleus'), findsAny);
  });
}
