import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/assignment.dart';
import '../services/assignment_service.dart';
import '../theme/app_theme.dart';
import '../components/app_drawer.dart';
import '../components/notification_button.dart';
import "../components/nav_bar.dart";

class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  int _currentNavIndex = 4;
  int _criticalCount = 0;
  List<_AlertCardConfig> _alertCards = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _refreshAlerts();
  }

  Future<void> _refreshAlerts() async {
    try {
      final alerts = await AssignmentService.fetchAlerts(scope: 'all');
      if (!mounted) return;

      setState(() {
        _alertCards = alerts.map(_alertCardFromData).toList();
        _criticalCount = alerts
            .where((alert) => alert.severity.toUpperCase() == 'CRITICAL')
            .length;
        _errorMessage = null;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _alertCards = [];
        _criticalCount = 0;
        _errorMessage = 'Failed to load alerts';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      drawer: const AppDrawer(currentRoute: '/alerts'),
      appBar: AppBar(
        backgroundColor: Colors.black.withValues(alpha: 0.8),
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu, color: Color(0xFF4D8EFF)),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        centerTitle: true,
        title: Text(
          'COMMAND',
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w900,
            letterSpacing: 4,
            color: const Color(0xFF4D8EFF),
          ),
        ),
        actions: [
          const NotificationButton(),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: Colors.white.withValues(alpha: 0.1)),
        ),
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildPageHeader(),
                const SizedBox(height: 16),
                if (_isLoading)
                  const Center(child: CircularProgressIndicator())
                else if (_errorMessage != null)
                  _buildStateMessage(_errorMessage!)
                else if (_alertCards.isEmpty)
                  _buildStateMessage('No active alerts')
                else
                  ..._alertCards
                      .map(
                        (card) => Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: _buildAlertCard(
                            severity: card.severity,
                            icon: card.icon,
                            title: card.title,
                            description: card.description,
                            timestamp: card.timestamp,
                            metaItems: card.metaItems,
                          ),
                        ),
                      )
                      ,
                const SizedBox(height: 24),
              ],
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: BottomNav(
              currentIndex: _currentNavIndex,
              onTap: (index) {
                if (index == _currentNavIndex) return;
                setState(() => _currentNavIndex = index);
                _navigateTo(context, index);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStateMessage(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0B1326),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: GoogleFonts.inter(color: AppColors.onSurfaceVariant),
      ),
    );
  }

  void _navigateTo(BuildContext context, int index) {
    const routes = {
      0: '/dashboard',
      1: '/reports',
      2: '/map',
      3: '/resources',
      4: '/alerts',
    };
    final route = routes[index];
    if (route != null) {
      Navigator.pushReplacementNamed(context, route);
    }
  }

  // ═══════════════════════════════════════
  //  PAGE HEADER
  // ═══════════════════════════════════════
  Widget _buildPageHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Active Alerts',
          style: GoogleFonts.inter(
            fontSize: 24,
            fontWeight: FontWeight.w600,
            color: AppColors.onSurface,
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFF0B1326),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Pulsing red dot
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.4, end: 1.0),
                duration: const Duration(milliseconds: 1000),
                builder: (context, value, child) {
                  return Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.error.withValues(alpha: value),
                    ),
                  );
                },
              ),
              const SizedBox(width: 8),
              Text(
                '$_criticalCount CRITICAL',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.7,
                  color: AppColors.error,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════
  //  ALERT CARD (Critical / High)
  // ═══════════════════════════════════════
  Widget _buildAlertCard({
    required AlertSeverity severity,
    required IconData icon,
    required String title,
    required String description,
    required String timestamp,
    required List<_AlertMeta> metaItems,
  }) {
    final bool isCritical = severity == AlertSeverity.critical;
    final Color accentColor =
        isCritical ? AppColors.error : const Color(0xFFDF7412); // tertiary-container
    final List<BoxShadow> glow = [
      BoxShadow(
        color: isCritical
            ? const Color(0x33EF4444) // red glow
            : const Color(0x33F59E0B), // amber glow
        blurRadius: 15,
      ),
    ];

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: const Color(0xFF0B1326),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        boxShadow: glow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Top accent border
          Container(height: 2, color: accentColor),

          Stack(
            children: [
              // Corner decoration (critical only)
              if (isCritical)
                Positioned(
                  top: -32,
                  right: -32,
                  child: Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),

              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Header row: icon + badge + timestamp ──
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(icon, color: accentColor, size: 20),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: accentColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(2),
                              ),
                              child: Text(
                                isCritical ? 'CRITICAL' : 'HIGH',
                                style: GoogleFonts.spaceGrotesk(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.2,
                                  color: accentColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                        Text(
                          timestamp,
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // ── Title ──
                    Text(
                      title,
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        height: 1.3,
                        color: AppColors.onSurface,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // ── Description ──
                    Text(
                      description,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        height: 1.5,
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ── Footer: meta + view details ──
                    Container(
                      padding: const EdgeInsets.only(top: 12),
                      decoration: const BoxDecoration(
                        border: Border(
                          top: BorderSide(
                            color: Colors.white10,
                          ),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Meta items
                          Row(
                            children: metaItems
                                .map(
                                  (m) => Padding(
                                    padding: const EdgeInsets.only(right: 16),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(m.icon,
                                            size: 14,
                                            color: AppColors.onSurfaceVariant),
                                        const SizedBox(width: 4),
                                        Text(
                                          m.label,
                                          style: GoogleFonts.spaceGrotesk(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                            color: AppColors.onSurfaceVariant,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                          // View Details link
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'VIEW DETAILS',
                                style: GoogleFonts.spaceGrotesk(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.2,
                                  color: accentColor,
                                ),
                              ),
                              const SizedBox(width: 2),
                              Icon(Icons.chevron_right,
                                  size: 14, color: accentColor),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

}

// ─── Enums & helpers ───

enum AlertSeverity { critical, high, routine }

class _AlertMeta {
  final IconData icon;
  final String label;
  const _AlertMeta({required this.icon, required this.label});
}

class _AlertCardConfig {
  final AlertSeverity severity;
  final IconData icon;
  final String title;
  final String description;
  final String timestamp;
  final List<_AlertMeta> metaItems;

  const _AlertCardConfig({
    required this.severity,
    required this.icon,
    required this.title,
    required this.description,
    required this.timestamp,
    required this.metaItems,
  });
}

_AlertCardConfig _alertCardFromData(AlertData alert) {
  final severity = alert.severity.toUpperCase() == 'CRITICAL'
      ? AlertSeverity.critical
      : AlertSeverity.high;
  final icon = _iconForAlertType(alert.type);
  final timestamp = alert.createdAt.toUtc().toIso8601String().split('.').first.replaceFirst('T', ' ');

  return _AlertCardConfig(
    severity: severity,
    icon: icon,
    title: alert.title,
    description: alert.description ?? 'No description provided',
    timestamp: '${timestamp}Z',
    metaItems: [
      _AlertMeta(icon: Icons.location_on, label: alert.district),
      if (alert.source != null && alert.source!.isNotEmpty)
        _AlertMeta(icon: Icons.info_outline, label: alert.source!),
    ],
  );
}

IconData _iconForAlertType(String type) {
  switch (type.toUpperCase()) {
    case 'FLOOD_WARNING':
      return Icons.water;
    case 'POWER_OUTAGE':
      return Icons.electrical_services;
    case 'LOGISTICS_DISRUPTION':
      return Icons.local_shipping;
    default:
      return Icons.warning;
  }
}
