import 'package:flutter_hbb/utils/multi_window_manager.dart';

/// Launch state shared by the host entrypoint and neutral shared libraries.
int? kWindowId;
WindowType? kWindowType;
late List<String> kBootArgs;
bool Function() isHostChatPageCurrentTab = () => false;
Future<void> Function() showHostCmWindow = () async {};
