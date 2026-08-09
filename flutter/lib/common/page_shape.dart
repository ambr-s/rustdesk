import 'package:flutter/material.dart';

abstract class PageShape extends Widget {
  final String title = '';
  final Widget icon = const Icon(null);
  final List<Widget> appBarActions = const [];

  const PageShape({super.key});
}
