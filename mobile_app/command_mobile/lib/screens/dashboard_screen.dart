import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:command_mobile/components/app_drawer.dart';
import 'package:command_mobile/components/nav_bar.dart';
import 'package:command_mobile/models/assignment.dart';
import 'package:command_mobile/services/assignment_service.dart';
import 'package:command_mobile/services/socket_service.dart';
import 'package:command_mobile/services/notification_service.dart';
import 'package:command_mobile/components/notification_button.dart';
import 'dart:async';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int currentIndex = 0;

  // API Data
  AssignmentSummary? summaryData;
  List<AlertData> alertsData = [];
  List<AssignmentIncident> incidentsData = [];
  List<ReportData> reportsData = [];
  bool isLoading = true;
  String? errorMessage;
  bool _hasLoadedDashboard = false;
  bool _isLive = false;
  DateTime _nextRefreshAt = DateTime.now().add(const Duration(minutes: 5));
  Timer? _clockTimer;

  final Color bgColor = const Color(0xFF10131A);
  final Color cardColor = const Color(0xFF191B23);
  final Color borderColor = const Color(0xFF2A2D35);
  final Color textSecondary = const Color(0xFF9CA3AF);

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
    // Connect to socket and subscribe to realtime updates
    SocketService.instance.connect();
    _startLiveClock();
    _subscribeRealtime();
  }

  StreamSubscription? _assignmentSub;
  StreamSubscription? _alertSub;
  StreamSubscription? _reportSub;
  StreamSubscription? _notificationSub;

  void _subscribeRealtime() {
    _assignmentSub = SocketService.instance.onAssignmentUpdate.listen((data) {
      debugPrint('📡 Dashboard: Socket event received: ${data['event']}');
      debugPrint('📡 Dashboard: Payload: $data');
      if (mounted) _loadDashboardData();
    });

    _notificationSub = SocketService.instance.onNotification.listen((data) {
      if (!mounted) return;
    });

    _alertSub = SocketService.instance.onAlert.listen((data) {
      if (!mounted) return;
      _loadDashboardData();
    });
  }

  // Notifications are handled by NotificationService globally

  Future<void> _loadDashboardData() async {
    setState(() => isLoading = true);

    AssignmentSummary? summary;
    List<AlertData> alerts = [];
    List<AssignmentIncident> incidents = [];
    List<ReportData> reports = [];

    try {
      summary = await AssignmentService.fetchSummary();
    } catch (e) {
      print('[Dashboard] Warning: failed to fetch summary: $e');
    }

    try {
      alerts = await AssignmentService.fetchAlerts(scope: 'all');
    } catch (e) {
      print('[Dashboard] Warning: failed to fetch alerts: $e');
    }

    try {
      incidents = await AssignmentService.fetchIncidents();
    } catch (e) {
      print('[Dashboard] Warning: failed to fetch incidents: $e');
    }

    try {
      final reportsResp = await AssignmentService.fetchReports();
      reports = reportsResp?.reports ?? [];
    } catch (e, st) {
      print('[Dashboard] Warning: failed to fetch reports: $e');
      print(st);
    }

    setState(() {
      summaryData = summary;
      alertsData = alerts;
      incidentsData = incidents;
      reportsData = reports;
      isLoading = false;
      _hasLoadedDashboard = true;
      _nextRefreshAt = DateTime.now().add(const Duration(minutes: 5));
    });

    for (final assignment in incidents) {
      final incidentId = assignment.incidentId;
      if (incidentId != null && incidentId.trim().isNotEmpty) {
        SocketService.instance.joinIncident(incidentId);
      }
    }
  }

  void _startLiveClock() {
    _clockTimer?.cancel();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;

      final now = DateTime.now();
      final shouldRefresh = now.isAfter(_nextRefreshAt);

      setState(() {
        _isLive = SocketService.instance.connected || _hasLoadedDashboard;
      });

      if (shouldRefresh) {
        _nextRefreshAt = now.add(const Duration(minutes: 5));
        _loadDashboardData();
      }
    });
  }

  String _buildTMinusLabel() {
    final remaining = _nextRefreshAt.difference(DateTime.now());
    final safe = remaining.isNegative ? Duration.zero : remaining;

    final hours = safe.inHours.toString().padLeft(2, '0');
    final minutes = (safe.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (safe.inSeconds % 60).toString().padLeft(2, '0');

    return 'T-MINUS $hours:$minutes:$seconds';
  }

  // Sheet is now handled by NotificationButton component

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      drawer: const AppDrawer(currentRoute: '/dashboard'),
      appBar: AppBar(
        automaticallyImplyLeading: false,
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
            fontSize: 18,
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
          child: Container(
            height: 1,
            color: Colors.white.withValues(alpha: 0.1),
          ),
        ),
      ),
      bottomNavigationBar: BottomNav(
        currentIndex: currentIndex,
        onTap: (index) {
          if (index == currentIndex) return;
          setState(() => currentIndex = index);
          _navigateTo(context, index);
        },
      ),
      body: Stack(
        children: [
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 90), // Bottom padding for nav bar
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildPageHeader(),
                  const SizedBox(height: 16),
                  _buildMetricCards(),
                  const SizedBox(height: 20),
                  if (AuthService.currentUser?.role != 'LOGISTICS_STAFF') _buildLatestReports(),
                  if (AuthService.currentUser?.role != 'LOGISTICS_STAFF') const SizedBox(height: 20),
                  _buildTelemetryTable(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _assignmentSub?.cancel();
    _alertSub?.cancel();
    _reportSub?.cancel();
    _notificationSub?.cancel();
    _clockTimer?.cancel();
    super.dispose();
  }

  Widget _buildPageHeader() {
    final liveColor = _isLive ? Colors.greenAccent : Colors.orangeAccent;
    final liveLabel = isLoading && !_hasLoadedDashboard ? 'SYNCING' : 'LIVE';

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'OPERATIONS',
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: liveColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  liveLabel,
                  style: GoogleFonts.inter(
                    color: liveColor,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            )
          ],
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: cardColor,
            border: Border.all(color: borderColor),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            _buildTMinusLabel(),
            style: GoogleFonts.inter(
              color: liveColor,
              
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMetricCards() {
    if (isLoading) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: cardColor,
          border: Border.all(color: borderColor),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Column(
      children: [
        // Primary Critical Alerts Card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF3B1010), // Tint for critical
            border: Border.all(color: Colors.redAccent.withValues(alpha: 0.5)),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'CRITICAL ALERTS',
                    style: GoogleFonts.inter(color: Colors.redAccent, fontWeight: FontWeight.bold, letterSpacing: 1.2),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${summaryData?.criticalAlerts ?? 0}',
                    style: GoogleFonts.inter(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 48),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // Secondary Cards
        Row(
          children: [
            Expanded(
              child: _buildSmallCard(
                title: AuthService.currentUser?.role == 'LOGISTICS_STAFF' 
                    ? 'ACTIVE DEPLOYMENTS'
                    : 'ACTIVE INCIDENTS',
                value: '${summaryData?.activeIncidents ?? 0}',
                valueColor: Colors.white,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildSmallCard(
                title: 'READINESS SCORE',
                value: '${summaryData?.readinessScore ?? 0}%',
                valueColor: Colors.blueAccent,
              ),
            ),
          ],
        )
      ],
    );
  }

  Widget _buildSmallCard({required String title, required String value, required Color valueColor}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        border: Border.all(color: borderColor),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.inter(color: textSecondary, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.0),
          ),
          const SizedBox(height: 8),
          Text(value, style: GoogleFonts.inter(color: valueColor, fontSize: 24, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildLatestReports() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'LATEST REPORTS',
          style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1.5, fontSize: 14),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: cardColor,
            border: Border.all(color: borderColor),
            borderRadius: BorderRadius.circular(12),
          ),
          child: reportsData.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Center(
                    child: Text(
                      'No reports available',
                      style: GoogleFonts.inter(color: textSecondary),
                    ),
                  ),
                )
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                      child: Row(
                        children: [
                          Expanded(flex: 2, child: Text('DISTRICT', style: GoogleFonts.inter(color: textSecondary, fontSize: 11, fontWeight: FontWeight.bold))),
                          Expanded(flex: 3, child: Text('TYPE', style: GoogleFonts.inter(color: textSecondary, fontSize: 11, fontWeight: FontWeight.bold))),
                          Expanded(flex: 3, child: Text('STATUS', style: GoogleFonts.inter(color: textSecondary, fontSize: 11, fontWeight: FontWeight.bold))),
                        ],
                      ),
                    ),
                    const Divider(height: 1, color: Color(0xFF2A2D35)),
                    ...reportsData.take(5).map((report) {
                      final statusColor = _getReportStatusColor(report.status);
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: Text(
                                report.district,
                                style: GoogleFonts.inter(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
                              ),
                            ),
                            Expanded(
                              flex: 3,
                              child: Text(
                                report.disasterType,
                                style: GoogleFonts.inter(color: textSecondary, fontSize: 12),
                              ),
                            ),
                            Expanded(
                              flex: 3,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: statusColor.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: statusColor.withValues(alpha: 0.5)),
                                ),
                                child: Text(
                                  report.status,
                                  style: GoogleFonts.inter(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
        )
      ],
    );
  }

  Widget _buildNationalStatus() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'NATIONAL STATUS',
          style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1.5, fontSize: 14),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: cardColor,
            border: Border.all(color: borderColor),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    const Icon(Icons.map_outlined, color: Colors.blueAccent),
                    const SizedBox(width: 12),
                    Text('Geo-Visualization Active', style: GoogleFonts.inter(color: textSecondary)),
                  ],
                ),
              ),
              const Divider(height: 1, color: Color(0xFF2A2D35)),
              _buildDistrictRow('D-Alpha', 'CRITICAL', Colors.redAccent),
              _buildDistrictRow('D-Bravo', 'ELEVATED', Colors.orangeAccent),
              _buildDistrictRow('D-Charlie', 'NOMINAL', Colors.green),
              _buildDistrictRow('D-Delta', 'NOMINAL', Colors.green),
              const SizedBox(height: 8),
            ],
          ),
        )
      ],
    );
  }

  Widget _buildDistrictRow(String name, String status, Color statusColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(name, style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w500)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: statusColor.withValues(alpha: 0.5)),
            ),
            child: Text(
              status,
              style: GoogleFonts.inter(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.0),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildTelemetryTable() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'LATEST ALERTS',
          style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1.5, fontSize: 14),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: cardColor,
            border: Border.all(color: borderColor),
            borderRadius: BorderRadius.circular(12),
          ),
          child: alertsData.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Center(
                    child: Text(
                      'No active alerts',
                      style: GoogleFonts.inter(color: textSecondary),
                    ),
                  ),
                )
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                      child: Row(
                        children: [
                          Expanded(flex: 2, child: Text('SEVERITY', style: GoogleFonts.inter(color: textSecondary, fontSize: 11, fontWeight: FontWeight.bold))),
                          Expanded(flex: 4, child: Text('TITLE', style: GoogleFonts.inter(color: textSecondary, fontSize: 11, fontWeight: FontWeight.bold))),
                          Expanded(flex: 3, child: Text('DISTRICT', style: GoogleFonts.inter(color: textSecondary, fontSize: 11, fontWeight: FontWeight.bold))),
                        ],
                      ),
                    ),
                    const Divider(height: 1, color: Color(0xFF2A2D35)),
                    ...alertsData.take(5).map((alert) {
                      final severityColor = _getSeverityColor(alert.severity);
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: severityColor.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: severityColor.withValues(alpha: 0.5)),
                                ),
                                child: Text(
                                  alert.severity,
                                  style: GoogleFonts.inter(color: severityColor, fontSize: 10, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 4,
                              child: Text(
                                alert.title,
                                style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Expanded(
                              flex: 3,
                              child: Text(
                                alert.district,
                                style: GoogleFonts.inter(color: textSecondary, fontSize: 11),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
        ),
      ],
    );
  }

  Color _getSeverityColor(String severity) {
    switch (severity.toUpperCase()) {
      case 'CRITICAL':
        return Colors.redAccent;
      case 'HIGH':
        return Colors.orangeAccent;
      case 'MEDIUM':
        return Colors.yellowAccent;
      case 'LOW':
        return Colors.greenAccent;
      default:
        return Colors.blueAccent;
    }
  }

  Color _getReportStatusColor(String status) {
    final s = status.toUpperCase().replaceAll('-', '_').replaceAll(' ', '_');
    switch (s) {
      case 'VERIFIED':
      case 'ACTIVE':
      case 'ASSIGNED':
        return const Color(0xFF4D8EFF);
      case 'PENDING_REVIEW':
      case 'EN_ROUTE':
        return const Color(0xFFFFAB40);
      case 'AT_THE_INCIDENT':
      case 'ATTHEINCIDENT':
      case 'ON_SITE':
      case 'INSPECTING':
        return const Color(0xFF00C853);
      case 'REJECTED':
      case 'FALSEREPORT':
      case 'FALSE_REPORT':
        return Colors.redAccent;
      case 'DUPLICATE':
      case 'RESOLVED':
      case 'CLOSED':
      case 'RELEASED':
        return Colors.grey;
      case 'CONVERTED_TO_INCIDENT':
        return Colors.blueAccent;
      default:
        return Colors.white70;
    }
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
}
