import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/user.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';

class AppDrawer extends StatelessWidget {
  final String currentRoute;

  const AppDrawer({
    super.key,
    required this.currentRoute,
  });

  static const List<_DrawerDestination> _destinations = [
    _DrawerDestination(
      label: 'Dashboard',
      route: '/dashboard',
      icon: Icons.dashboard,
    ),
    _DrawerDestination(
      label: 'Reports',
      route: '/reports',
      icon: Icons.description,
    ),
    _DrawerDestination(
      label: 'Map',
      route: '/map',
      icon: Icons.map,
    ),
    _DrawerDestination(
      label: 'Resources',
      route: '/resources',
      icon: Icons.inventory_2,
    ),
    _DrawerDestination(
      label: 'Alerts',
      route: '/alerts',
      icon: Icons.warning,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final User? user = AuthService.currentUser;

    return Drawer(
      backgroundColor: AppColors.surfaceContainerLow,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(user),
            const Divider(height: 1, color: Colors.white10),
            const SizedBox(height: 8),
            ..._destinations.map(
              (destination) => _buildDestination(context, destination),
            ),
            const Spacer(),
            const Divider(height: 1, color: Colors.white10),
            Padding(
              padding: const EdgeInsets.all(12),
              child: OutlinedButton.icon(
                onPressed: () => _logout(context),
                icon: const Icon(Icons.logout, size: 18),
                label: const Text('LOGOUT'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.error,
                  side: BorderSide(
                    color: AppColors.error.withValues(alpha: 0.5),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                  textStyle: GoogleFonts.spaceGrotesk(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.8,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(User? user) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white10),
            ),
            child: const Icon(
              Icons.shield,
              color: AppColors.primary,
              size: 26,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            user?.name ?? 'COMMAND',
            style: GoogleFonts.inter(
              color: AppColors.primary,
              fontSize: 18,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            user?.email ?? user?.serviceId ?? 'ACTIVE SESSION',
            style: GoogleFonts.spaceGrotesk(
              color: AppColors.onSurface,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  user?.role ?? 'Role: —',
                  style: GoogleFonts.spaceGrotesk(
                    color: AppColors.onSurfaceVariant,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  user?.zone ?? 'Zone: —',
                  textAlign: TextAlign.end,
                  style: GoogleFonts.spaceGrotesk(
                    color: AppColors.onSurfaceVariant,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDestination(
    BuildContext context,
    _DrawerDestination destination,
  ) {
    final bool isSelected = currentRoute == destination.route;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      child: ListTile(
        selected: isSelected,
        selectedTileColor: AppColors.primaryContainer.withValues(alpha: 0.18),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        leading: Icon(
          destination.icon,
          color: isSelected ? AppColors.primary : AppColors.onSurfaceVariant,
        ),
        title: Text(
          destination.label.toUpperCase(),
          style: GoogleFonts.spaceGrotesk(
            color: isSelected ? AppColors.primary : AppColors.onSurface,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
        ),
        onTap: () {
          Navigator.pop(context);
          if (isSelected) return;
          Navigator.pushReplacementNamed(context, destination.route);
        },
      ),
    );
  }

  void _logout(BuildContext context) {
    AuthService.signOut();
    Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
  }
}

class _DrawerDestination {
  final String label;
  final String route;
  final IconData icon;

  const _DrawerDestination({
    required this.label,
    required this.route,
    required this.icon,
  });
}
