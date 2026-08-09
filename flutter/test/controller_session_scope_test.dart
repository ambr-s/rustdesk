import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_hbb/controller/controller_bridge.dart';
import 'package:flutter_hbb/desktop/widgets/tabbar_widget.dart';
import 'package:get/get.dart';

void main() {
  tearDown(Get.reset);

  for (final kind in ControllerSessionKind.values) {
    testWidgets('controller $kind session registers and cleans up its tab',
        (tester) async {
      DesktopTabController? captured;
      String? capturedKey;
      final session = ControllerSession(
        id: 'session-${kind.name}',
        peerId: '123456789',
        kind: kind,
      );

      await tester.pumpWidget(MaterialApp(
        home: Builder(builder: (context) {
          return TextButton(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
              builder: (_) => ControllerSessionScope(
                session: session,
                builder: (controller, tabKey) {
                  captured = controller;
                  capturedKey = tabKey;
                  return const SizedBox();
                },
              ),
            )),
            child: const Text('open session'),
          );
        }),
      ));
      await tester.tap(find.text('open session'));
      await tester.pumpAndSettle();

      expect(Get.isRegistered<DesktopTabController>(), isTrue);
      expect(Get.find<DesktopTabController>(), same(captured));
      expect(captured!.state.value.tabs, hasLength(1));
      expect(captured!.state.value.selectedTabInfo.key, capturedKey);
      if (kind == ControllerSessionKind.terminal) {
        expect(captured!.tabType, DesktopTabType.terminal);
        await captured!.onCloseWindow!();
      } else {
        captured!.onRemoved!(0, capturedKey!);
      }
      await tester.pumpAndSettle();

      expect(find.text('open session'), findsOneWidget);
      expect(Get.isRegistered<DesktopTabController>(), isFalse);
    });
  }

  testWidgets('a second simultaneous controller session fails closed',
      (tester) async {
    var builtSessions = 0;
    Widget scope(String id) => ControllerSessionScope(
          session: ControllerSession(
              id: id, peerId: id, kind: ControllerSessionKind.desktop),
          builder: (_, __) {
            builtSessions++;
            return Text(id);
          },
        );

    await tester.pumpWidget(MaterialApp(
      home: Column(children: [scope('first'), scope('second')]),
    ));

    expect(builtSessions, 1);
    expect(
        find.text(
            'Close the active controller session before opening another.'),
        findsOneWidget);
  });
}
