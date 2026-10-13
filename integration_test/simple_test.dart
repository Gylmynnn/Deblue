import 'package:flutter_test/flutter_test.dart';
import 'package:desys/src/rust/api/simple.dart';
import 'package:desys/src/rust/frb_generated.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async => await RustLib.init());
  testWidgets('Can call rust function', (WidgetTester tester) async {
    final result = greet(name: 'Tom');
    expect(result, 'Hello, Tom!');
  });
}
