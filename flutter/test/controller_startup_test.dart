import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_hbb/controller/controller_app.dart';
import 'package:flutter_hbb/controller/controller_bridge.dart';

class FakeControllerBridge implements ControllerBridge {
  var initializeCalls = 0;
  Object? initializeError;
  Object? saveError;
  final peersToReturn = const [
    ControllerPeer('123 456 789', name: 'Lab', favorite: true),
  ];
  final connections = <ControllerSession>[];
  final sessionPages = <ControllerSession>[];
  final savedConfigs = <ControllerServerConfig>[];

  @override
  Future<void> initialize() async {
    initializeCalls++;
    if (initializeError != null) throw initializeError!;
  }

  @override
  Future<ControllerPeerCollections> peerCollections() async =>
      ControllerPeerCollections(recent: peersToReturn);

  @override
  Future<List<ControllerPeer>> peers() async => peersToReturn;

  @override
  Future<ControllerServerConfig> serverConfig() async =>
      const ControllerServerConfig(id: '', relay: '', api: '', key: '');

  @override
  Future<ControllerSession> connect(String id,
      {ControllerSessionKind kind = ControllerSessionKind.desktop}) async {
    final session =
        ControllerSession(id: 'test:$id:${kind.name}', peerId: id, kind: kind);
    connections.add(session);
    return session;
  }

  @override
  Future<void> saveServerConfig(ControllerServerConfig config) async {
    if (saveError != null) throw saveError!;
    savedConfigs.add(config);
  }

  @override
  Widget sessionPage(ControllerSession session) {
    sessionPages.add(session);
    return Scaffold(
        body: Center(
            child: Column(children: [
      Text('session:${session.peerId}:${session.kind.name}',
          key: ValueKey<String>(session.id)),
      Builder(
          builder: (context) => TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Return to controller')))
    ])));
  }
}

void main() {
  testWidgets('startup uses the injected outgoing bridge', (tester) async {
    final bridge = FakeControllerBridge();
    await tester.pumpWidget(ControllerApp(bridge: bridge));
    await tester.pump();

    expect(bridge.initializeCalls, 1);
    expect(find.text('Connect to a remote device'), findsOneWidget);
    expect(find.text('Lab'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, '123 456 789');
    await tester.tap(find.text('Remote desktop'));
    await tester.pumpAndSettle();

    expect(bridge.connections, hasLength(1));
    expect(bridge.connections.single.peerId, '123 456 789');
    expect(bridge.connections.single.kind, ControllerSessionKind.desktop);
    expect(bridge.sessionPages.single.id, 'test:123 456 789:desktop');
  });

  testWidgets('startup can route file transfer and terminal sessions',
      (tester) async {
    final bridge = FakeControllerBridge();
    await tester.pumpWidget(ControllerApp(bridge: bridge));
    await tester.pump();
    await tester.enterText(find.byType(TextField).first, '987 654 321');

    await tester.tap(find.text('File transfer'));
    await tester.pumpAndSettle();
    expect(bridge.connections.single.kind, ControllerSessionKind.fileTransfer);
    await tester.tap(find.text('Return to controller'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, '987 654 321');
    await tester.tap(find.text('Remote terminal'));
    await tester.pumpAndSettle();
    expect(bridge.connections.last.kind, ControllerSessionKind.terminal);
  });

  testWidgets('manual ID edits replace a previously selected peer',
      (tester) async {
    final bridge = FakeControllerBridge();
    await tester.pumpWidget(ControllerApp(bridge: bridge));
    await tester.pump();

    await tester.tap(find.text('Lab'));
    await tester.enterText(find.byType(TextField).first, '999 888 777');
    await tester.tap(find.text('Remote desktop'));
    await tester.pumpAndSettle();

    expect(bridge.connections.single.peerId, '999 888 777');
  });

  testWidgets('initialization failures are shown in the controller',
      (tester) async {
    final bridge = FakeControllerBridge()
      ..initializeError = StateError('load failed');
    await tester.pumpWidget(ControllerApp(bridge: bridge));
    await tester.pump();

    expect(find.textContaining('load failed'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('failed server saves remain open and report the error',
      (tester) async {
    final bridge = FakeControllerBridge()
      ..saveError = StateError('invalid API server');
    await tester.pumpWidget(ControllerApp(bridge: bridge));
    await tester.pump();

    await tester.tap(find.text('Servers'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Self-host server settings'), findsOneWidget);
    expect(find.textContaining('invalid API server'), findsOneWidget);
    expect(find.text('Server settings saved'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('saved peer views open inside the controller navigator',
      (tester) async {
    final bridge = FakeControllerBridge();
    await tester.pumpWidget(ControllerApp(bridge: bridge));
    await tester.pump();

    await tester.tap(find.text('Recent'));
    await tester.pumpAndSettle();

    expect(find.text('Recent'), findsNWidgets(2));
    expect(find.text('Lab'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
