import 'package:flutter/material.dart';
import 'package:flutter_hbb/common.dart';
import 'package:flutter_hbb/consts.dart';
import 'package:flutter_hbb/desktop/pages/file_manager_page.dart';
import 'package:flutter_hbb/desktop/pages/remote_page.dart';
import 'package:flutter_hbb/desktop/pages/terminal_page.dart';
import 'package:flutter_hbb/desktop/widgets/remote_toolbar.dart';
import 'package:flutter_hbb/desktop/widgets/tabbar_widget.dart';
import 'package:flutter_hbb/models/platform_model.dart';
import 'package:flutter_hbb/models/peer_model.dart';
import 'package:get/get.dart';

abstract interface class ControllerBridge {
  void addPeerCollectionsListener(VoidCallback listener);
  void removePeerCollectionsListener(VoidCallback listener);
  Future<void> initialize();
  Future<ControllerPeerCollections> peerCollections();
  Future<List<ControllerPeer>> peers();
  Future<ControllerServerConfig> serverConfig();
  Future<ControllerSession> connect(String id, {ControllerSessionKind kind});
  Future<void> saveServerConfig(ControllerServerConfig config);
  Widget sessionPage(ControllerSession session);
}

@immutable
class ControllerPeer {
  const ControllerPeer(
    this.id, {
    this.name = '',
    this.group = '',
    this.favorite = false,
    this.source = ControllerPeerSource.recent,
  });

  final String id;
  final String name;
  final String group;
  final bool favorite;
  final ControllerPeerSource source;
}

enum ControllerPeerSource { recent, favorite, addressBook }

@immutable
class ControllerPeerCollections {
  const ControllerPeerCollections({
    this.recent = const [],
    this.favourites = const [],
    this.addressBook = const [],
  });

  final List<ControllerPeer> recent;
  final List<ControllerPeer> favourites;
  final List<ControllerPeer> addressBook;

  List<ControllerPeer> get all => [
        ...recent,
        ...favourites,
        ...addressBook,
      ];
}

enum ControllerSessionKind { desktop, fileTransfer, terminal }

@immutable
class ControllerSession {
  const ControllerSession({
    required this.id,
    required this.peerId,
    required this.kind,
    this.forceRelay = false,
  });

  final String id;
  final String peerId;
  final ControllerSessionKind kind;
  final bool forceRelay;
}

@immutable
class ControllerTarget {
  const ControllerTarget(this.id, {required this.forceRelay});

  final String id;
  final bool forceRelay;
}

Future<ControllerTarget> prepareControllerTarget(
  String id,
  Future<String> Function(String id) handleRelayId,
) async {
  final compactId = id.replaceAll(' ', '');
  final handledId = await handleRelayId(compactId);
  return ControllerTarget(
    handledId,
    forceRelay: handledId != compactId,
  );
}

@immutable
class ControllerServerConfig {
  const ControllerServerConfig({
    required this.id,
    required this.relay,
    required this.api,
    required this.key,
  });

  final String id;
  final String relay;
  final String api;
  final String key;
}

/// Production outgoing bridge. Session pages own and start their session FFI.
class RustDeskControllerBridge implements ControllerBridge {
  static int _nextAddressBookListenerId = 0;
  final _addressBookListenerKey =
      'controller-peer-collections-${_nextAddressBookListenerId++}';
  final _peerCollectionsListeners = <VoidCallback>[];
  bool _peerModelListenersAttached = false;

  void _notifyPeerCollectionsListeners() {
    for (final listener in List<VoidCallback>.of(_peerCollectionsListeners)) {
      listener();
    }
  }

  @override
  void addPeerCollectionsListener(VoidCallback listener) {
    _peerCollectionsListeners.add(listener);
  }

  @override
  void removePeerCollectionsListener(VoidCallback listener) {
    _peerCollectionsListeners.remove(listener);
    if (_peerCollectionsListeners.isEmpty && _peerModelListenersAttached) {
      gFFI.recentPeersModel.removeListener(_notifyPeerCollectionsListeners);
      gFFI.favoritePeersModel.removeListener(_notifyPeerCollectionsListeners);
      gFFI.abModel.removePeerUpdateListener(_addressBookListenerKey);
      _peerModelListenersAttached = false;
    }
  }

  @override
  Future<void> initialize() async {
    await platformFFI.init(kAppTypeMain);
    await initGlobalFFI();
    if (_peerCollectionsListeners.isNotEmpty && !_peerModelListenersAttached) {
      gFFI.recentPeersModel.addListener(_notifyPeerCollectionsListeners);
      gFFI.favoritePeersModel.addListener(_notifyPeerCollectionsListeners);
      gFFI.abModel.addPeerUpdateListener(
        _addressBookListenerKey,
        _notifyPeerCollectionsListeners,
      );
      _peerModelListenersAttached = true;
    }
    await Future.wait([
      bind.mainLoadRecentPeers(),
      bind.mainLoadFavPeers(),
      gFFI.abModel.pullAb(force: null, quiet: true),
    ]);
  }

  @override
  Future<ControllerPeerCollections> peerCollections() async {
    final favorites = gFFI.favoritePeersModel.peers.map((p) => p.id).toSet();

    List<ControllerPeer> convert(
      Iterable<Peer> peers,
      ControllerPeerSource source,
    ) {
      return peers
          .map((peer) => ControllerPeer(
                peer.id,
                name: peer.alias,
                favorite: favorites.contains(peer.id),
                source: source,
              ))
          .toList(growable: false);
    }

    return ControllerPeerCollections(
      recent: convert(gFFI.recentPeersModel.peers, ControllerPeerSource.recent),
      favourites: convert(
        gFFI.favoritePeersModel.peers,
        ControllerPeerSource.favorite,
      ),
      addressBook: convert(
        gFFI.abModel.allPeers(),
        ControllerPeerSource.addressBook,
      ),
    );
  }

  @override
  Future<List<ControllerPeer>> peers() async => (await peerCollections()).all;

  @override
  Future<ControllerServerConfig> serverConfig() async => ControllerServerConfig(
        id: await bind.mainGetOption(key: 'custom-rendezvous-server'),
        relay: await bind.mainGetOption(key: 'relay-server'),
        api: await bind.mainGetOption(key: 'api-server'),
        key: await bind.mainGetOption(key: 'key'),
      );

  @override
  Future<ControllerSession> connect(
    String id, {
    ControllerSessionKind kind = ControllerSessionKind.desktop,
  }) async {
    final target = await prepareControllerTarget(
      id,
      (candidate) => bind.mainHandleRelayId(id: candidate),
    );
    return ControllerSession(
      id: target.id,
      peerId: target.id,
      kind: kind,
      forceRelay: target.forceRelay,
    );
  }

  @override
  Future<void> saveServerConfig(ControllerServerConfig config) async {
    final errors = List.generate(4, (_) => ''.obs);
    final saved = await setServerConfig(
      null,
      errors,
      ServerConfig(
        idServer: config.id,
        relayServer: config.relay,
        apiServer: config.api,
        key: config.key,
      ),
    );
    if (!saved) {
      final message = errors.map((error) => error.value).firstWhere(
            (error) => error.isNotEmpty,
            orElse: () => 'Invalid server configuration',
          );
      throw FormatException(message);
    }
  }

  @override
  Widget sessionPage(ControllerSession session) {
    return ControllerSessionScope(
      session: session,
      builder: (tabController, tabKey) {
        switch (session.kind) {
          case ControllerSessionKind.desktop:
            return RemotePage(
              id: session.peerId,
              toolbarState: ToolbarState(),
              forceRelay: session.forceRelay,
              tabController: tabController,
            );
          case ControllerSessionKind.fileTransfer:
            return FileManagerPage(
              id: session.peerId,
              password: null,
              isSharedPassword: false,
              forceRelay: session.forceRelay,
              tabController: tabController,
            );
          case ControllerSessionKind.terminal:
            return TerminalPage(
              id: session.peerId,
              password: null,
              tabController: tabController,
              isSharedPassword: false,
              forceRelay: session.forceRelay,
              terminalId: session.peerId.hashCode,
              tabKey: tabKey,
            );
        }
      },
    );
  }
}

typedef ControllerSessionPageBuilder = Widget Function(
  DesktopTabController controller,
  String tabKey,
);

class ControllerSessionScope extends StatefulWidget {
  const ControllerSessionScope({
    super.key,
    required this.session,
    required this.builder,
  });

  final ControllerSession session;
  final ControllerSessionPageBuilder builder;

  @override
  State<ControllerSessionScope> createState() => _ControllerSessionScopeState();
}

class _ControllerSessionScopeState extends State<ControllerSessionScope> {
  late final DesktopTabController tabController;
  late final String tabKey;
  late final Widget page;
  bool _closing = false;
  bool _registrationConflict = false;

  @override
  void initState() {
    super.initState();
    if (Get.isRegistered<DesktopTabController>()) {
      _registrationConflict = true;
      return;
    }
    tabController = DesktopTabController(
        tabType: switch (widget.session.kind) {
      ControllerSessionKind.desktop => DesktopTabType.remoteScreen,
      ControllerSessionKind.fileTransfer => DesktopTabType.fileTransfer,
      ControllerSessionKind.terminal => DesktopTabType.terminal,
    });
    tabKey = widget.session.kind == ControllerSessionKind.terminal
        ? '${widget.session.peerId}_${widget.session.peerId.hashCode}'
        : widget.session.peerId;
    Get.put<DesktopTabController>(tabController);
    page = widget.builder(tabController, tabKey);
    tabController.onRemoved = (_, __) => _closeRoute();
    if (widget.session.kind == ControllerSessionKind.terminal) {
      tabController.onCloseWindow = () async => _closeRoute();
    }
    tabController.state.value.tabs.add(TabInfo(
      key: tabKey,
      label: widget.session.peerId,
      page: page,
    ));
    tabController.state.value.scrollController.itemCount = 1;
    tabController.state.value.selected = 0;
    tabController.state.refresh();
  }

  void _closeRoute() {
    if (_closing || !mounted) return;
    _closing = true;
    Navigator.of(context).maybePop();
  }

  @override
  void dispose() {
    if (_registrationConflict) {
      super.dispose();
      return;
    }
    tabController.onRemoved = null;
    tabController.onCloseWindow = null;
    if (Get.isRegistered<DesktopTabController>() &&
        identical(Get.find<DesktopTabController>(), tabController)) {
      Get.delete<DesktopTabController>(force: true);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _registrationConflict
      ? const Center(
          child: Text(
            'Close the active controller session before opening another.',
          ),
        )
      : page;
}
