import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/assignment.dart';
import '../services/assignment_service.dart';
import '../services/socket_service.dart';
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
  StreamSubscription? _alertSub;

  @override
  void initState() {
    super.initState();
    _refreshAlerts();
    _alertSub = SocketService.instance.onAlert.listen((_) {
      if (mounted) _refreshAlerts();
    });
  }

  @override
  void dispose() {
    _alertSub?.cancel();
    super.dispose();
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
      bottomNavigationBar: BottomNav(
        currentIndex: _currentNavIndex,
        onTap: (index) {
          if (index == _currentNavIndex) return;
          setState(() => _currentNavIndex = index);
          _navigateTo(context, index);
        },
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
                            config: card,
                          ),
                        ),
                      )
                      ,
                const SizedBox(height: 24),
              ],
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
  void _showAlertDetails(_AlertCardConfig config) {
    final bool isCritical = config.severity == AlertSeverity.critical;
    final Color accentColor = isCritical ? AppColors.error : const Color(0xFFDF7412);

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: accentColor.withValues(alpha: 0.2)),
            boxShadow: [
              BoxShadow(
                color: accentColor.withValues(alpha: 0.1),
                blurRadius: 30,
                spreadRadius: -10,
              ),
            ],
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top header with icon
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.05),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                  ),
                  child: Icon(
                    isCritical ? Icons.warning_amber_rounded : Icons.info_outline,
                    color: accentColor,
                    size: 48,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: accentColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: accentColor.withValues(alpha: 0.3)),
                            ),
                            child: Text(
                              config.rawSeverity,
                              style: GoogleFonts.spaceGrotesk(
                                color: accentColor,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.0,
                              ),
                            ),
                          ),
                          Text(
                            config.status,
                            style: GoogleFonts.spaceGrotesk(
                              color: config.status == 'ACTIVE' ? Colors.greenAccent : Colors.grey,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        config.title,
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 22,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Alert ID: ${config.id}',
                        style: GoogleFonts.spaceGrotesk(
                          color: AppColors.onSurfaceVariant.withValues(alpha: 0.5),
                          fontSize: 10,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.outlineVariant),
                        ),
                        child: Text(
                          config.description,
                          style: GoogleFonts.inter(
                            color: AppColors.onSurfaceVariant,
                            fontSize: 15,
                            height: 1.6,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      _buildDetailRow(Icons.category_outlined, 'Category', config.type, accentColor),
                      _buildDetailRow(Icons.public, 'Protocol', config.isPublic ? 'PUBLIC BROADCAST' : 'INTERNAL TACTICAL', accentColor),
                      ...config.metaItems.map((meta) => _buildDetailRow(meta.icon, 'Location', meta.label, accentColor)),
                      const SizedBox(height: 12),
                      const Divider(color: Colors.white10),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'TIMESTAMP',
                            style: GoogleFonts.spaceGrotesk(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: AppColors.onSurfaceVariant.withValues(alpha: 0.5),
                            ),
                          ),
                          Text(
                            config.timestamp,
                            style: GoogleFonts.spaceGrotesk(
                              color: AppColors.onSurfaceVariant,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: accentColor,
                            foregroundColor: isCritical ? Colors.black : Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: Text(
                            'ACKNOWLEDGE',
                            style: GoogleFonts.spaceGrotesk(
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value, Color accent) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: accent),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: GoogleFonts.inter(fontSize: 13),
                children: [
                  TextSpan(text: '$label: ', style: const TextStyle(color: Colors.white54)),
                  TextSpan(text: value, style: const TextStyle(color: Colors.white)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlertCard({required _AlertCardConfig config}) {
    final bool isCritical = config.severity == AlertSeverity.critical;
    final Color accentColor =
        isCritical ? AppColors.error : const Color(0xFFDF7412);
    final List<BoxShadow> glow = [
      BoxShadow(
        color: isCritical
            ? const Color(0x33EF4444)
            : const Color(0x33F59E0B),
        blurRadius: 15,
      ),
    ];

    return InkWell(
      onTap: () => _showAlertDetails(config),
      borderRadius: BorderRadius.circular(4),
      child: Container(
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
            Container(height: 2, color: accentColor),
            Stack(
              children: [
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
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(config.icon, color: accentColor, size: 20),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: accentColor.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(2),
                                ),
                                child: Text(
                                  config.rawSeverity,
                                  style: GoogleFonts.spaceGrotesk(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.2,
                                    color: accentColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          Text(
                            config.status,
                            style: GoogleFonts.spaceGrotesk(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: config.status == 'ACTIVE' ? Colors.greenAccent : Colors.grey,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        config.title,
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          height: 1.3,
                          color: AppColors.onSurface,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        config.description,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                          height: 1.5,
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.only(top: 12),
                        decoration: const BoxDecoration(
                          border: Border(top: BorderSide(color: Colors.white10)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                config.timestamp,
                                style: GoogleFonts.spaceGrotesk(
                                  fontSize: 11,
                                  color: AppColors.onSurfaceVariant,
                                ),
                              ),
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'DETAILS',
                                  style: GoogleFonts.spaceGrotesk(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 1.2,
                                    color: accentColor,
                                  ),
                                ),
                                const SizedBox(width: 2),
                                Icon(Icons.chevron_right, size: 14, color: accentColor),
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
  final String id;
  final AlertSeverity severity;
  final String rawSeverity;
  final IconData icon;
  final String title;
  final String description;
  final String timestamp;
  final String status;
  final String type;
  final bool isPublic;
  final List<_AlertMeta> metaItems;

  const _AlertCardConfig({
    required this.id,
    required this.severity,
    required this.rawSeverity,
    required this.icon,
    required this.title,
    required this.description,
    required this.timestamp,
    required this.status,
    required this.type,
    required this.isPublic,
    required this.metaItems,
  });
}

_AlertCardConfig _alertCardFromData(AlertData alert) {
  final rawSeverity = alert.severity.toUpperCase();
  final severity = rawSeverity == 'CRITICAL'
      ? AlertSeverity.critical
      : (rawSeverity == 'HIGH' ? AlertSeverity.high : AlertSeverity.routine);
  final icon = _iconForAlertType(alert.type);
  final timestamp = alert.createdAt.toUtc().toIso8601String().split('.').first.replaceFirst('T', ' ');

  return _AlertCardConfig(
    id: alert.id,
    severity: severity,
    rawSeverity: rawSeverity,
    icon: icon,
    title: alert.title,
    description: alert.description ?? 'No description provided',
    timestamp: '${timestamp}Z',
    status: alert.isActive ? 'ACTIVE' : 'INACTIVE',
    type: alert.type,
    isPublic: alert.isPublic,
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
