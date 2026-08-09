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
  @override
  Future<void> initialize() async {
    await platformFFI.init(kAppTypeMain);
    await initGlobalFFI();
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
    switch (session.kind) {
      case ControllerSessionKind.desktop:
        return RemotePage(
          id: session.peerId,
          toolbarState: ToolbarState(),
          forceRelay: session.forceRelay,
        );
      case ControllerSessionKind.fileTransfer:
        return FileManagerPage(
          id: session.peerId,
          password: null,
          isSharedPassword: false,
          forceRelay: session.forceRelay,
          tabController: DesktopTabController(tabType: DesktopTabType.cm),
        );
      case ControllerSessionKind.terminal:
        return TerminalPage(
          id: session.peerId,
          password: null,
          tabController: DesktopTabController(tabType: DesktopTabType.cm),
          isSharedPassword: false,
          forceRelay: session.forceRelay,
          terminalId: session.peerId.hashCode,
          tabKey: session.peerId,
        );
    }
  }
}
