import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_hbb/models/incoming_host_model.dart';

class FakeIncomingHostModel extends ChangeNotifier
    implements IncomingHostModel {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  tearDown(clearIncomingHostModelFactory);

  test('factory registration creates the registered model', () {
    final model = FakeIncomingHostModel();
    registerIncomingHostModelFactory((_) => model);
    expect(createIncomingHostModel(Object()), same(model));
  });

  test('unregistered factory fails closed', () {
    clearIncomingHostModelFactory();
    expect(createIncomingHostModel(Object()), isNull);
  });
}
