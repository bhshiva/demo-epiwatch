import 'package:flutter/widgets.dart';

/// One sidebar entry. The shell renders whatever list it is given and never
/// branches on role itself, so adding a role means adding a list, not editing
/// the shell.
class NavDestination {
  final String key;
  final String label;
  final IconData icon;
  final WidgetBuilder builder;

  const NavDestination({
    required this.key,
    required this.label,
    required this.icon,
    required this.builder,
  });
}
