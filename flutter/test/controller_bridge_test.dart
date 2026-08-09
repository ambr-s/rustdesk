import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_hbb/controller/controller_bridge.dart';

void main() {
  test('controller target removes spaces and preserves relay forcing',
      () async {
    final target = await prepareControllerTarget(
      '123 456 789/r',
      (id) async {
        expect(id, '123456789/r');
        return '123456789';
      },
    );

    expect(target.id, '123456789');
    expect(target.forceRelay, isTrue);
  });

  test('ordinary controller target does not force relay', () async {
    final target = await prepareControllerTarget(
      '123 456 789',
      (id) async => id,
    );

    expect(target.id, '123456789');
    expect(target.forceRelay, isFalse);
  });
}
