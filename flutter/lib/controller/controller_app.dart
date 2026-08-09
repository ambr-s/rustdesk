import 'package:flutter/material.dart';

import 'controller_bridge.dart';

class ControllerApp extends StatefulWidget {
  const ControllerApp({super.key, this.bridge});
  final ControllerBridge? bridge;

  @override
  State<ControllerApp> createState() => _ControllerAppState();
}

class _ControllerAppState extends State<ControllerApp> {
  late final ControllerBridge bridge =
      widget.bridge ?? RustDeskControllerBridge();
  final idController = TextEditingController();
  final idServer = TextEditingController();
  final relayServer = TextEditingController();
  final apiServer = TextEditingController();
  final key = TextEditingController();
  ControllerPeerCollections collections = const ControllerPeerCollections();
  String? startupError;
  String? peerError;
  String? actionError;
  final navigatorKey = GlobalKey<NavigatorState>();
  int _peerCollectionsGeneration = 0;
  int _serverConfigGeneration = 0;

  @override
  void initState() {
    super.initState();
    bridge.addPeerCollectionsListener(_refreshPeerCollections);
    _load();
  }

  Future<void> _refreshPeerCollections() async {
    final generation = ++_peerCollectionsGeneration;
    try {
      final updated = await bridge.peerCollections();
      if (mounted && generation == _peerCollectionsGeneration) {
        setState(() {
          collections = updated;
          peerError = null;
        });
      }
    } catch (e) {
      if (mounted && generation == _peerCollectionsGeneration) {
        setState(() => peerError = '$e');
      }
    }
  }

  Future<void> _load() async {
    final configGeneration = ++_serverConfigGeneration;
    try {
      await bridge.initialize();
    } catch (e) {
      if (mounted) setState(() => startupError = '$e');
      return;
    }

    final generation = ++_peerCollectionsGeneration;
    try {
      final loaded = await bridge.peerCollections();
      if (mounted && generation == _peerCollectionsGeneration) {
        setState(() {
          collections = loaded;
          peerError = null;
        });
      }
    } catch (e) {
      if (mounted && generation == _peerCollectionsGeneration) {
        setState(() => peerError = '$e');
      }
    }

    try {
      final config = await bridge.serverConfig();
      if (!mounted || configGeneration != _serverConfigGeneration) return;
      setState(() {
        idServer.text = config.id;
        relayServer.text = config.relay;
        apiServer.text = config.api;
        key.text = config.key;
        startupError = null;
      });
    } catch (e) {
      if (mounted && configGeneration == _serverConfigGeneration) {
        setState(() => startupError = '$e');
      }
    }
  }

  @override
  void dispose() {
    bridge.removePeerCollectionsListener(_refreshPeerCollections);
    idController.dispose();
    idServer.dispose();
    relayServer.dispose();
    apiServer.dispose();
    key.dispose();
    super.dispose();
  }

  Future<void> _connect(
      [ControllerSessionKind kind = ControllerSessionKind.desktop]) async {
    final id = idController.text.trim();
    if (id.isEmpty) {
      setState(() => actionError = 'Enter a remote ID.');
      return;
    }
    try {
      final session = await bridge.connect(id, kind: kind);
      final page = bridge.sessionPage(session);
      if (!mounted) return;
      setState(() => actionError = null);
      navigatorKey.currentState!
          .push(MaterialPageRoute<void>(builder: (_) => page));
    } catch (e) {
      if (mounted) setState(() => actionError = '$e');
    }
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
        navigatorKey: navigatorKey,
        title: 'RustDesk Controller',
        theme: ThemeData(colorSchemeSeed: Colors.blue, useMaterial3: true),
        home: Scaffold(
          appBar: AppBar(title: const Text('RustDesk Controller')),
          body: Row(children: [
            NavigationRail(
              selectedIndex: 0,
              labelType: NavigationRailLabelType.all,
              destinations: const [
                NavigationRailDestination(
                    icon: Icon(Icons.link), label: Text('Connect')),
                NavigationRailDestination(
                    icon: Icon(Icons.history), label: Text('Recent')),
                NavigationRailDestination(
                    icon: Icon(Icons.star), label: Text('Favourites')),
                NavigationRailDestination(
                    icon: Icon(Icons.contacts), label: Text('Address book')),
                NavigationRailDestination(
                    icon: Icon(Icons.dns), label: Text('Servers')),
              ],
              onDestinationSelected: (index) {
                if (index == 1) _showPeers('Recent', collections.recent);
                if (index == 2) {
                  _showPeers('Favourites', collections.favourites);
                }
                if (index == 3) {
                  _showPeers('Address book', collections.addressBook);
                }
                if (index == 4) {
                  _showSettings();
                }
              },
            ),
            const VerticalDivider(width: 1),
            Expanded(child: _connectPane()),
          ]),
        ),
      );

  List<String> get _visibleErrors => <String?>[
        startupError,
        peerError,
        actionError
      ].whereType<String>().toSet().toList(growable: false);

  Widget _connectPane() => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: ListView(padding: const EdgeInsets.all(32), children: [
            Text('Connect to a remote device',
                style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 20),
            TextField(
                controller: idController,
                autofocus: true,
                decoration: const InputDecoration(
                    labelText: 'Remote ID', hintText: 'Enter a remote ID'),
                onSubmitted: (_) => _connect()),
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 8, children: [
              FilledButton.icon(
                  onPressed: _connect,
                  icon: const Icon(Icons.desktop_windows),
                  label: const Text('Remote desktop')),
              OutlinedButton.icon(
                  onPressed: () => _connect(ControllerSessionKind.fileTransfer),
                  icon: const Icon(Icons.folder_copy),
                  label: const Text('File transfer')),
              OutlinedButton.icon(
                  onPressed: () => _connect(ControllerSessionKind.terminal),
                  icon: const Icon(Icons.terminal),
                  label: const Text('Remote terminal')),
            ]),
            ..._visibleErrors.map((message) => Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Text(message,
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.error)))),
            if (collections.all.isNotEmpty) ...[
              const Divider(height: 40),
              Text('Saved devices',
                  style: Theme.of(context).textTheme.titleLarge),
              ...collections.all.map((peer) => ListTile(
                  title: Text(peer.name.isEmpty ? peer.id : peer.name),
                  subtitle: Text(peer.id),
                  leading: Icon(peer.favorite ? Icons.star : Icons.devices),
                  onTap: () => setState(() {
                        idController.text = peer.id;
                      }))),
            ],
          ]),
        ),
      );

  void _showPeers(String title, List<ControllerPeer> items) => showDialog<void>(
      context: navigatorKey.currentContext!,
      builder: (dialogContext) => AlertDialog(
              title: Text(title),
              content: SizedBox(
                  width: 420,
                  child: items.isEmpty
                      ? const Text('No saved devices')
                      : ListView(
                          shrinkWrap: true,
                          children: items
                              .map((p) => ListTile(
                                  title: Text(p.name.isEmpty ? p.id : p.name),
                                  onTap: () {
                                    idController.text = p.id;
                                    Navigator.pop(dialogContext);
                                  }))
                              .toList())),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    child: const Text('Close'))
              ]));

  void _showSettings() {
    ++_serverConfigGeneration;
    final settingsError = ValueNotifier<String?>(null);
    showDialog<void>(
        context: navigatorKey.currentContext!,
        builder: (dialogContext) => AlertDialog(
            title: const Text('Self-host server settings'),
            content: SingleChildScrollView(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(
                  controller: idServer,
                  decoration: const InputDecoration(labelText: 'ID server')),
              TextField(
                  controller: relayServer,
                  decoration: const InputDecoration(labelText: 'Relay server')),
              TextField(
                  controller: apiServer,
                  decoration: const InputDecoration(labelText: 'API server')),
              TextField(
                  controller: key,
                  decoration: const InputDecoration(labelText: 'Public key'))
            ])),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel')),
              FilledButton(
                  onPressed: () async {
                    try {
                      await bridge.saveServerConfig(ControllerServerConfig(
                          id: idServer.text.trim(),
                          relay: relayServer.text.trim(),
                          api: apiServer.text.trim(),
                          key: key.text.trim()));
                      if (!dialogContext.mounted) return;
                      Navigator.pop(dialogContext);
                      ScaffoldMessenger.of(navigatorKey.currentContext!)
                          .showSnackBar(const SnackBar(
                              content: Text('Server settings saved')));
                    } catch (e) {
                      settingsError.value = '$e';
                    }
                  },
                  child: const Text('Save'))
            ],
            actionsAlignment: MainAxisAlignment.end,
            icon: ValueListenableBuilder<String?>(
                valueListenable: settingsError,
                builder: (_, value, __) => value == null
                    ? const SizedBox.shrink()
                    : Text(value,
                        style: TextStyle(
                            color: Theme.of(dialogContext)
                                .colorScheme
                                .error))))).whenComplete(settingsError.dispose);
  }
}
