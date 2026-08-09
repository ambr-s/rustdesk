import 'dart:async';
import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_hbb/controller/controller_app.dart';
import 'package:flutter_hbb/controller/controller_bridge.dart';

class FakeControllerBridge implements ControllerBridge {
  var initializeCalls = 0;
  Object? initializeError;
  Object? saveError;
  List<ControllerPeer> peersToReturn = const [
    ControllerPeer('123 456 789', name: 'Lab', favorite: true),
  ];
  final peerListeners = <VoidCallback>[];
  final peerCollectionGates = Queue<Completer<ControllerPeerCollections>>();
  final connections = <ControllerSession>[];
  final sessionPages = <ControllerSession>[];
  final savedConfigs = <ControllerServerConfig>[];
  Completer<ControllerServerConfig>? serverConfigGate;
  int serverConfigCalls = 0;

  @override
  Future<void> initialize() async {
    initializeCalls++;
    if (initializeError != null) throw initializeError!;
  }

  @override
  void addPeerCollectionsListener(VoidCallback listener) {
    peerListeners.add(listener);
  }

  @override
  void removePeerCollectionsListener(VoidCallback listener) {
    peerListeners.remove(listener);
  }

  void notifyPeerCollectionsChanged() {
    for (final listener in List<VoidCallback>.of(peerListeners)) {
      listener();
    }
  }

  @override
  Future<ControllerPeerCollections> peerCollections() async {
    if (peerCollectionGates.isNotEmpty) {
      return await peerCollectionGates.removeFirst().future;
    }
    return ControllerPeerCollections(recent: peersToReturn);
  }

  @override
  Future<List<ControllerPeer>> peers() async => peersToReturn;

  @override
  Future<ControllerServerConfig> serverConfig() async {
    serverConfigCalls++;
    final gate = serverConfigGate;
    if (gate != null) return await gate.future;
    return const ControllerServerConfig(id: '', relay: '', api: '', key: '');
  }

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

  testWidgets('late native peer events refresh controller collections',
      (tester) async {
    final bridge = FakeControllerBridge()..peersToReturn = const [];
    await tester.pumpWidget(ControllerApp(bridge: bridge));
    await tester.pump();

    expect(find.text('Lab'), findsNothing);
    bridge.peersToReturn = const [
      ControllerPeer('123 456 789', name: 'Lab'),
    ];
    bridge.notifyPeerCollectionsChanged();
    await tester.pump();

    expect(find.text('Lab'), findsOneWidget);
  });

  testWidgets('startup snapshot cannot overwrite a newer native peer event',
      (tester) async {
    final bridge = FakeControllerBridge()
      ..peersToReturn = const [ControllerPeer('old', name: 'Old')]
      ..serverConfigGate = Completer<ControllerServerConfig>();
    await tester.pumpWidget(ControllerApp(bridge: bridge));
    await tester.pump();

    bridge.peersToReturn = const [ControllerPeer('new', name: 'New')];
    bridge.notifyPeerCollectionsChanged();
    await tester.pump();

    bridge.serverConfigGate!.complete(
      const ControllerServerConfig(id: '', relay: '', api: '', key: ''),
    );
    await tester.pump();

    expect(find.text('New'), findsOneWidget);
    expect(find.text('Old'), findsNothing);
  });

  testWidgets('stale native refresh errors cannot replace newer results',
      (tester) async {
    final bridge = FakeControllerBridge();
    await tester.pumpWidget(ControllerApp(bridge: bridge));
    await tester.pump();
    final stale = Completer<ControllerPeerCollections>();
    final current = Completer<ControllerPeerCollections>();
    bridge.peerCollectionGates.addAll([stale, current]);

    bridge.notifyPeerCollectionsChanged();
    bridge.notifyPeerCollectionsChanged();
    current.complete(const ControllerPeerCollections(
      recent: [ControllerPeer('new', name: 'New')],
    ));
    await tester.pump();
    stale.completeError(StateError('stale refresh failure'));
    await tester.pump();

    expect(find.text('New'), findsOneWidget);
    expect(find.textContaining('stale refresh failure'), findsNothing);
  });

  testWidgets('stale startup peer errors cannot replace a newer native refresh',
      (tester) async {
    final stale = Completer<ControllerPeerCollections>();
    final bridge = FakeControllerBridge()..peerCollectionGates.add(stale);
    await tester.pumpWidget(ControllerApp(bridge: bridge));
    await tester.pump();

    bridge.peersToReturn = const [ControllerPeer('new', name: 'New')];
    bridge.notifyPeerCollectionsChanged();
    await tester.pump();
    stale.completeError(StateError('stale startup peer failure'));
    await tester.pump();

    expect(find.text('New'), findsOneWidget);
    expect(find.textContaining('stale startup peer failure'), findsNothing);
  });

  testWidgets('startup preserves server config errors across peer refreshes',
      (tester) async {
    final bridge = FakeControllerBridge()
      ..peersToReturn = const [ControllerPeer('old', name: 'Old')]
      ..serverConfigGate = Completer<ControllerServerConfig>();
    await tester.pumpWidget(ControllerApp(bridge: bridge));
    await tester.pump();

    bridge.peersToReturn = const [ControllerPeer('new', name: 'New')];
    bridge.notifyPeerCollectionsChanged();
    await tester.pump();
    bridge.serverConfigGate!.completeError(StateError('server config failure'));
    await tester.pump();

    expect(find.text('New'), findsOneWidget);
    expect(find.textContaining('server config failure'), findsOneWidget);
  });

  testWidgets('startup still loads server config after a peer snapshot failure',
      (tester) async {
    final peerLoad = Completer<ControllerPeerCollections>();
    final bridge = FakeControllerBridge()..peerCollectionGates.add(peerLoad);
    await tester.pumpWidget(ControllerApp(bridge: bridge));
    await tester.pump();

    peerLoad.completeError(StateError('peer snapshot failure'));
    await tester.pump();

    expect(bridge.serverConfigCalls, 1);
    expect(find.textContaining('peer snapshot failure'), findsOneWidget);
  });

  testWidgets('peer refresh recovery clears only the peer error',
      (tester) async {
    final bridge = FakeControllerBridge();
    await tester.pumpWidget(ControllerApp(bridge: bridge));
    await tester.pump();
    final failure = Completer<ControllerPeerCollections>();
    bridge.peerCollectionGates.add(failure);

    bridge.notifyPeerCollectionsChanged();
    failure.completeError(StateError('peer refresh failure'));
    await tester.pump();
    expect(find.textContaining('peer refresh failure'), findsOneWidget);

    bridge.peersToReturn = const [ControllerPeer('new', name: 'New')];
    bridge.notifyPeerCollectionsChanged();
    await tester.pump();

    expect(find.text('New'), findsOneWidget);
    expect(find.textContaining('peer refresh failure'), findsNothing);
  });

  testWidgets('peer and server errors remain independently visible',
      (tester) async {
    final bridge = FakeControllerBridge()
      ..serverConfigGate = Completer<ControllerServerConfig>();
    await tester.pumpWidget(ControllerApp(bridge: bridge));
    await tester.pump();
    final peerFailure = Completer<ControllerPeerCollections>();
    bridge.peerCollectionGates.add(peerFailure);

    bridge.notifyPeerCollectionsChanged();
    peerFailure.completeError(StateError('peer refresh failure'));
    await tester.pump();
    bridge.serverConfigGate!.completeError(StateError('server config failure'));
    await tester.pump();

    expect(find.textContaining('peer refresh failure'), findsOneWidget);
    expect(find.textContaining('server config failure'), findsOneWidget);
  });

  testWidgets('late startup config cannot overwrite settings being edited',
      (tester) async {
    final configLoad = Completer<ControllerServerConfig>();
    final bridge = FakeControllerBridge()..serverConfigGate = configLoad;
    await tester.pumpWidget(ControllerApp(bridge: bridge));
    await tester.pump();

    await tester.tap(find.text('Servers'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.widgetWithText(TextField, 'ID server'), 'user-id');

    configLoad.complete(const ControllerServerConfig(
        id: 'stale-id', relay: 'stale-relay', api: '', key: ''));
    await tester.pump();

    expect(find.text('user-id'), findsOneWidget);
    expect(find.text('stale-id'), findsNothing);
  });
}
