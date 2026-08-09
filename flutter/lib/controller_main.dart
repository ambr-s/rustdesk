import 'package:flutter/material.dart';

import 'controller/controller_app.dart';

const _controllerOnly = bool.fromEnvironment('RUSTDESK_CONTROLLER_ONLY');

Future<void> main() async {
  if (!_controllerOnly) {
    throw StateError('RUSTDESK_CONTROLLER_ONLY must be true');
  }
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ControllerApp());
}
