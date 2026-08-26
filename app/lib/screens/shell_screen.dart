import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/nav_destination.dart';
import '../state/auth.dart';
import '../services/app_strings.dart';
import '../state/locale.dart';
import '../theme/app_colors.dart';
import '../widgets/language_selector_widget.dart';

/// Below this width the sidebar becomes a bottom navigation bar.
const kCompactBreakpoint = 900.0;

/// Lets a screen ask the shell to switch tabs by key.
class ShellNav extends InheritedWidget {
  final void Function(String key) navigateTo;

  const ShellNav({super.key, required this.navigateTo, required super.child});

  static ShellNav of(BuildContext context) {
    final nav = context.dependOnInheritedWidgetOfExactType<ShellNav>();
    assert(nav != null, 'ShellNav.of() called outside a ShellScreen');
    return nav!;
  }

  @override
  bool updateShouldNotify(ShellNav oldWidget) => navigateTo != oldWidget.navigateTo;
}

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

    return ShellNav(
      navigateTo: _navigateTo,
      child: Scaffold(
        backgroundColor: AppColors.bgPrimary,
        appBar: isCompact
            ? AppBar(
                backgroundColor: Colors.white,
                foregroundColor: AppColors.textPrimary,
                elevation: 0,
                shadowColor: Colors.transparent,
                surfaceTintColor: Colors.transparent,
                title: Text(current.label,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                        color: AppColors.textPrimary)),
                actions: [_SignOutButton(onTap: _signOut, compact: true)],
                bottom: PreferredSize(
                  preferredSize: const Size.fromHeight(1),
                  child: Container(height: 1, color: AppColors.border),
                ),
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
            Expanded(
              child: IndexedStack(
                index: _index,
                children: [
                  for (final d in widget.destinations) Builder(builder: d.builder),
                ],
              ),
            ),
          ],
        ),
        bottomNavigationBar: isCompact
            ? NavigationBar(
                backgroundColor: Colors.white,
                selectedIndex: _index,
                onDestinationSelected: (i) => setState(() => _index = i),
                destinations: [
                  for (final d in widget.destinations)
                    NavigationDestination(icon: Icon(d.icon), label: d.label),
                ],
              )
            : null,
      ),
    );
  }

  void _navigateTo(String key) {
    final i = widget.destinations.indexWhere((d) => d.key == key);
    if (i == -1) return;
    setState(() => _index = i);
  }

  void _signOut() => ref.read(authProvider.notifier).signOut();
}

// ─────────────────────────────────────────────────────────────────────────────
// Sidebar
// ─────────────────────────────────────────────────────────────────────────────

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
      width: 240,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(right: BorderSide(color: AppColors.border, width: 1)),
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Brand ────────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.primaryButton,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.health_and_safety_outlined,
                        color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('EpiWatch',
                            style: TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 15,
                                fontWeight: FontWeight.w700)),
                        Text(roleLabel,
                            style: const TextStyle(
                                color: AppColors.textMuted, fontSize: 11)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Container(height: 1, color: AppColors.border),
            const SizedBox(height: 8),
            // ── User pill ────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.bgTertiary,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 15,
                      backgroundColor: AppColors.primaryButton,
                      child: Text(
                        userName.isNotEmpty ? userName[0].toUpperCase() : 'D',
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 13),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(userName,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12.5)),
                          Text(roleCaption,
                              style: const TextStyle(
                                  color: AppColors.textMuted, fontSize: 11)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            // ── Nav group label ───────────────────────────────────────────────
            const _NavGroupLabel('MAIN'),
            // ── Nav items ────────────────────────────────────────────────────
            for (var i = 0; i < destinations.length; i++)
              _NavTile(
                destination: destinations[i],
                isActive: i == selectedIndex,
                onTap: () => onSelect(i),
              ),
            const Spacer(),
            Container(height: 1, color: AppColors.border),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: LanguageSelectorWidget(),
            ),
            _SignOutButton(onTap: onSignOut, compact: false),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _NavGroupLabel extends StatelessWidget {
  final String label;
  const _NavGroupLabel(this.label);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
        child: Text(label,
            style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
                color: AppColors.textMuted)),
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
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: isActive
                ? AppColors.primaryButton.withValues(alpha: 0.08)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Container(
                width: 3,
                height: 18,
                decoration: BoxDecoration(
                  color: isActive ? AppColors.primaryButton : Colors.transparent,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 10),
              Icon(
                destination.icon,
                size: 18,
                color: isActive ? AppColors.primaryButton : AppColors.textMuted,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Consumer(
                  builder: (context, ref, _) {
                    final lang = ref.watch(localeProvider);
                    final keyMap = {
                      'Dashboard': 'dashboard',
                      'Patient Records': 'patient_records',
                      'Submit Report': 'submit_report_nav',
                      'Lab Dashboard': 'lab_dashboard',
                      'Worklist': 'worklist',
                      'Culture & AST': 'culture_ast',
                      'Live Surveillance': 'live_surveillance',
                      'Disease Trends': 'disease_trends',
                      'Geographic Clusters': 'geographic_clusters',
                      'AMR Watch': 'amr_watch',
                      'Alerts': 'alerts',
                      'Applications': 'applications',
                    };
                    final translationKey = keyMap[destination.label] ?? destination.label;
                    final translatedLabel = AppStrings.get(translationKey, lang);

                    return Text(
                      translatedLabel,
                      style: TextStyle(
                        color: isActive ? AppColors.primaryButton : AppColors.textSecondary,
                        fontSize: 13,
                        fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SignOutButton extends ConsumerWidget {
  final VoidCallback onTap;
  final bool compact;

  const _SignOutButton({required this.onTap, required this.compact});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(localeProvider);
    final label = AppStrings.get('sign_out', lang);
    if (compact) {
      return IconButton(
        onPressed: onTap,
        icon: const Icon(Icons.logout),
        tooltip: label,
      );
    }
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            const Icon(Icons.logout, size: 16, color: AppColors.textMuted),
            const SizedBox(width: 10),
            Text(label,
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}
