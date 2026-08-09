import 'dart:async';

import 'package:flutter/foundation.dart';

/// The typed boundary between the outgoing controller and the incoming host.
///
/// Host-only UI types remain behind dynamic accessors because this neutral
/// library must not import desktop host widgets into the controller closure.
abstract interface class IncomingHostModel extends ChangeNotifier {
  dynamic get serverId;
  dynamic get serverPasswd;
  dynamic get clients;
  dynamic get tabController;
  dynamic get controller;
  dynamic get cmHiddenTimer;
  bool get isStart;
  bool get mediaOk;
  bool get inputOk;
  bool get audioOk;
  bool get fileOk;
  bool get clipboardOk;
  bool get allowNumericOneTimePassword;
  int get connectStatus;
  String get verificationMethod;
  String get approveMode;
  bool get hideCm;
  set hideCm(bool value);

  Future<void> startService();
  Future<void> stopService();
  Future<void> closeAll();
  Future<void> fetchID();
  Future<void> checkAndroidPermission();
  Future<void> updateClientState([String? json]);
  Future<void> updatePasswordModel();
  Future<void> setApproveMode(String mode);
  Future<void> switchAllowNumericOneTimePassword();
  Future<void> toggleService();
  Future<void> toggleAudio();
  Future<void> toggleClipboard();
  Future<void> toggleFile();
  Future<void> toggleInput();
  void androidUpdatekeepScreenOn();
  void changeStatue(String name, bool value);
  void handleVoiceCall(covariant dynamic client, bool accept);
  void sendLoginResponse(covariant dynamic client, bool response);
  void jumpTo(int id);

  void addConnection(Map<String, dynamic> event);
  void onClientRemove(Map<String, dynamic> event);
  void setShowElevation(bool show);
  void updateVoiceCallState(Map<String, dynamic> event);
}

typedef IncomingHostModelFactory = IncomingHostModel Function(Object parent);

IncomingHostModelFactory? _factory;

void registerIncomingHostModelFactory(IncomingHostModelFactory factory) {
  _factory = factory;
}

IncomingHostModel? createIncomingHostModel(Object parent) =>
    _factory?.call(parent);

@visibleForTesting
void clearIncomingHostModelFactory() {
  _factory = null;
}
