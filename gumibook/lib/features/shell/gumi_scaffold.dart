import 'package:flutter/material.dart';
import 'package:flutter_liquid_glass_plus/flutter_liquid_glass.dart';


import '../../core/design/gumi.dart';


/// App shell (P0-04.08..11): bottom navigation with liquid glass,
/// 5 destinations, prominent Add Trade action, compact/expanded
/// behavior on scroll (DESIGN.md §4).
///
/// ponytail: LGQuality.standard everywhere; premium is a measured
/// upgrade if device testing proves it is safe.
class GumiScaffold extends StatelessWidget {
  const GumiScaffold({
    super.key,
    required this.body,
    required this.currentIndex,
    required this.onDestinationSelected,
    required this.onAddTrade,
    this.appBar,
  });

  final Widget body;
  final int currentIndex;
  final ValueChanged<int> onDestinationSelected;
  final VoidCallback onAddTrade;
  final PreferredSizeWidget? appBar;

  static const _destinations = [
    LGBottomBarTab(label: 'Dashboard', icon: Icons.dashboard_outlined),
    LGBottomBarTab(label: 'Journal', icon: Icons.menu_book_outlined),
    LGBottomBarTab(label: 'Market', icon: Icons.candlestick_chart_outlined),
    LGBottomBarTab(label: 'Settings', icon: Icons.settings_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    final c = context.gumiColors;

    return Scaffold(
      appBar: appBar,
      backgroundColor: c.bgPrimary,
      // Top safe area only: the status bar overlaps the body on
      // notch/dynamic-island devices. Bottom is owned by LGBottomBar.
      // When an AppBar exists it already handles the top inset.
      body: appBar == null ? SafeArea(top: true, bottom: false, child: body) : body,
      bottomNavigationBar: LGBottomBar(
        quality: LGQuality.standard,
        tabs: _destinations,
        selectedIndex: currentIndex,
        onTabSelected: onDestinationSelected,
        extraButton: LGBottomBarExtraButton(
          icon: Icons.add,
          label: 'Add Trade',
          // ponytail: package measures the extra slot as barHeight, so a
          // bigger size overflows the row. 64 still dwarfs the 24dp icons.
          size: 64,
          onTap: onAddTrade,
        ),
        horizontalPadding: GumiSpacings.lg,
        verticalPadding: GumiSpacings.sm,
        barHeight: 64,
        barBorderRadius: GumiRadius.glass,
        selectedIconColor: c.accentSilver,
        unselectedIconColor: c.textMuted,
        selectedLabelColor: c.textPrimary,
        unselectedLabelColor: c.textMuted,
        indicatorColor: c.surfaceGlass,
        glassSettings: const LiquidGlassSettings(
          glassColor: Color(0x1AFFFFFF),
          blur: 12,
        ),
      ),
    );
  }
}
