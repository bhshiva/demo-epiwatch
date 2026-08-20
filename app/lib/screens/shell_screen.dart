import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/nav_destination.dart';
import '../state/auth.dart';
import '../theme/app_colors.dart';

/// Below this width the sidebar becomes a bottom navigation bar. Phones and
/// narrow windows get the same destinations, laid out for the form factor.
const kCompactBreakpoint = 900.0;

class ShellScreen extends ConsumerStatefulWidget {
  final String roleLabel;
  final String roleCaption;
  final String userName;
  final List<NavDestination> destinations;

  const ShellScreen({
    super.key,
    required this.roleLabel,
    required this.roleCaption,
    required this.userName,
    required this.destinations,
  });

  @override
  ConsumerState<ShellScreen> createState() => _ShellScreenState();
}

class _ShellScreenState extends ConsumerState<ShellScreen> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.sizeOf(context).width < kCompactBreakpoint;
    final current = widget.destinations[_index];

    return Scaffold(
      appBar: isCompact
          ? AppBar(
              backgroundColor: AppColors.primaryButton,
              foregroundColor: Colors.white,
              title: Text(current.label),
              actions: [_SignOutButton(onTap: _signOut, compact: true)],
            )
          : null,
      body: Row(
        children: [
          if (!isCompact)
            _Sidebar(
              roleLabel: widget.roleLabel,
              roleCaption: widget.roleCaption,
              userName: widget.userName,
              destinations: widget.destinations,
              selectedIndex: _index,
              onSelect: (i) => setState(() => _index = i),
              onSignOut: _signOut,
            ),
          Expanded(child: current.builder(context)),
        ],
      ),
      bottomNavigationBar: isCompact
          ? NavigationBar(
              selectedIndex: _index,
              onDestinationSelected: (i) => setState(() => _index = i),
              destinations: [
                for (final d in widget.destinations)
                  NavigationDestination(icon: Icon(d.icon), label: d.label),
              ],
            )
          : null,
    );
  }

  void _signOut() => ref.read(authProvider.notifier).signOut();
}

class _Sidebar extends StatelessWidget {
  final String roleLabel;
  final String roleCaption;
  final String userName;
  final List<NavDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final VoidCallback onSignOut;

  const _Sidebar({
    required this.roleLabel,
    required this.roleCaption,
    required this.userName,
    required this.destinations,
    required this.selectedIndex,
    required this.onSelect,
    required this.onSignOut,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 260,
      color: AppColors.primaryButton,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.health_and_safety_outlined,
                          color: Colors.white, size: 24),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text('EpiWatch',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 19,
                                fontWeight: FontWeight.w700)),
                      ),
                      const SizedBox(width: 8),
                      _RoleBadge(label: roleLabel),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    '$roleCaption: $userName',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
            const Divider(color: Colors.white24, height: 1),
            const SizedBox(height: 10),
            for (var i = 0; i < destinations.length; i++)
              _NavTile(
                destination: destinations[i],
                isActive: i == selectedIndex,
                onTap: () => onSelect(i),
              ),
            const Spacer(),
            const Divider(color: Colors.white24, height: 1),
            _SignOutButton(onTap: onSignOut, compact: false),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _RoleBadge extends StatelessWidget {
  final String label;
  const _RoleBadge({required this.label});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: AppColors.accentMint,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(label,
            style: const TextStyle(
                color: Color(0xFF06301F),
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.6)),
      );
}

class _NavTile extends StatelessWidget {
  final NavDestination destination;
  final bool isActive;
  final VoidCallback onTap;

  const _NavTile({
    required this.destination,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = isActive ? Colors.white : Colors.white70;
    return Material(
      color:
          isActive ? Colors.white.withValues(alpha: 0.12) : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Row(
            children: [
              Icon(destination.icon, size: 19, color: color),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  destination.label,
                  style: TextStyle(
                    color: color,
                    fontSize: 13.5,
                    fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SignOutButton extends StatelessWidget {
  final VoidCallback onTap;
  final bool compact;

  const _SignOutButton({required this.onTap, required this.compact});

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return IconButton(
        onPressed: onTap,
        icon: const Icon(Icons.logout),
        tooltip: 'Sign out',
      );
    }
    return TextButton.icon(
      onPressed: onTap,
      icon: const Icon(Icons.logout, size: 17, color: Colors.white70),
      label: const Text('Sign out',
          style: TextStyle(color: Colors.white70, fontSize: 13)),
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        alignment: Alignment.centerLeft,
      ),
    );
  }
}
