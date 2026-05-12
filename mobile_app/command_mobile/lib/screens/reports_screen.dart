import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../components/app_drawer.dart';
import '../components/notification_button.dart';
import '../components/nav_bar.dart';
import '../services/assignment_service.dart';
import '../models/assignment.dart';

/// Field Reports (Incoming Reports) screen.
///
/// Faithfully reproduces the HTML/Tailwind mobile design:
///  • TopAppBar with menu / COMMAND title / notifications
///  • Sticky header with "Field Reports" title and tactical filter tabs
///  • Scrollable list of report cards (SOS, Public, J1 Internal)
///  • BottomNav bar (Reports tab active)
class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  int _selectedFilter = 0; // 0 = All
  int _currentNavIndex = 1; // Reports tab

  // Tactical filter labels (kept minimal for officer workflow)
  final List<String> _filterLabels = ['ALL', 'ASSIGNED', 'PRIORITY'];

  List<AssignmentIncident> _incidents = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadReports();
  }

  Future<void> _loadReports() async {
    setState(() => _isLoading = true);
    final response = await AssignmentService.fetchIncidents();
    if (!mounted) return;
    setState(() {
      _incidents = response;
      _isLoading = false;
    });
  }

  List<AssignmentIncident> get _filteredIncidents {
    if (_selectedFilter == 1) {
      return _incidents.where((assignment) => assignment.incidentId?.isNotEmpty == true).toList();
    }
    if (_selectedFilter == 2) {
      return _incidents
          .where((assignment) =>
              assignment.status.toUpperCase() == 'PENDING' ||
              assignment.status.toUpperCase() == 'UNDER_REVIEW')
          .toList();
    }
    return _incidents;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      drawer: const AppDrawer(currentRoute: '/reports'),
      // ─── Top App Bar ───
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
        currentIndex: _currentNavIndex,
        onTap: (index) {
          if (index == _currentNavIndex) return;
          setState(() => _currentNavIndex = index);
          _navigateTo(context, index);
        },
      ),
      body: Stack(
        children: [
          // ─── Scrollable content ───
          Column(
            children: [
              // ─── Sticky header: title + filter tabs ───
              Container(
                color: AppColors.background,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Field Reports',
                      style: GoogleFonts.inter(
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                        color: AppColors.onSurface,
                      ),
                    ),
                    const SizedBox(height: 12),
                    // ── Tactical filter tabs ──
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainer,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: AppColors.outlineVariant),
                      ),
                      child: Row(
                        children: List.generate(_filterLabels.length, (i) {
                          final bool isActive = _selectedFilter == i;
                          return Expanded(
                            child: GestureDetector(
                              onTap: () =>
                                  setState(() => _selectedFilter = i),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 8),
                                decoration: BoxDecoration(
                                  color: isActive
                                      ? AppColors.primary.withValues(alpha: 0.2)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(2),
                                  border: isActive
                                      ? Border.all(
                                          color: AppColors.primary
                                              .withValues(alpha: 0.3))
                                      : null,
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  _filterLabels[i],
                                  style: GoogleFonts.spaceGrotesk(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 1.2,
                                    color: isActive
                                        ? AppColors.primary
                                        : AppColors.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                  ],
                ),
              ),

              // ─── Report cards list ───
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                        itemCount: _filteredIncidents.length,
                        itemBuilder: (context, index) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: _buildReportCard(_filteredIncidents[index]),
                          );
                        },
                      ),
              ),
            ],
          ),

        ],
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
  //  REPORT CARD
  // ═══════════════════════════════════════
  Widget _buildReportCard(AssignmentIncident assignment) {
    final incident = assignment.incident;
    final status = assignment.status.toUpperCase();
    final Color accent = switch (status) {
      'ACTIVE' => Colors.greenAccent,
      'REJECTED' => AppColors.error,
      _ => AppColors.primary,
    };

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _openIncidentDetails(assignment),
        borderRadius: BorderRadius.circular(4),
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: AppColors.surfaceContainer,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: AppColors.outlineVariant),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(height: 2, color: accent),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          incident?.title ?? 'ASSIGNED INCIDENT',
                          style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.onSurface),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${assignment.incidentId ?? "N/A"} • ${assignment.assignedAt.toLocal().toString().split(' ')[0]}',
                          style: GoogleFonts.spaceGrotesk(fontSize: 11, color: AppColors.outline),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: AppColors.outlineVariant),
                      ),
                      child: Text(
                        incident?.division?.district ?? incident?.division?.divisionName ?? 'TACTICAL',
                        style: GoogleFonts.spaceGrotesk(fontSize: 11, color: AppColors.onSurfaceVariant),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  incident?.description ?? 'No incident description provided.',
                  style: GoogleFonts.inter(fontSize: 14, color: AppColors.onSurface),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Status: $status',
                      style: GoogleFonts.spaceGrotesk(fontSize: 12, color: AppColors.outline),
                    ),
                    IconButton(
                      tooltip: 'View incident',
                      onPressed: () => _openIncidentDetails(assignment),
                      icon: const Icon(Icons.open_in_new, color: Color(0xFF4D8EFF)),
                    ),
                  ],
                ),
              ],
            ),
          ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openIncidentDetails(AssignmentIncident assignment) async {
    final details = assignment.incident;
    if (details == null || !mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to load incident details')),
      );
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return DraggableScrollableSheet(
          initialChildSize: 0.8,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          builder: (_, scrollController) => Container(
            decoration: const BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              border: Border(top: BorderSide(color: AppColors.outlineVariant, width: 1)),
            ),
            child: Column(
              children: [
                // ─── Header Handle ───
                Center(
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 12),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.outlineVariant,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                    children: [
                      // ─── Top Identity Section ───
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'INCIDENT #${assignment.incidentId}',
                                  style: GoogleFonts.spaceGrotesk(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 1.5,
                                    color: AppColors.primary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  details.title,
                                  style: GoogleFonts.inter(
                                    fontSize: 28,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.onSurface,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          _buildStatusBadge(details.status),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // ─── Primary Action Buttons ───
                      Row(
                        children: [
                          Expanded(
                            child: _buildTacticalButton(
                                label: 'ASSIGNMENT',
                              icon: Icons.check_circle_outline,
                              onTap: () {
                                Navigator.pop(context);
                              },
                              isPrimary: true,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildTacticalButton(
                              label: 'LOCATE ON MAP',
                              icon: Icons.map_outlined,
                              onTap: () {
                                Navigator.pop(context);
                                Navigator.pushReplacementNamed(
                                  context,
                                  '/map',
                                  arguments: {
                                    'focusLat': details.latitude,
                                    'focusLon': details.longitude,
                                    'focusReportId': assignment.incidentId,
                                  },
                                );
                              },
                              isPrimary: false,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),

                      // ─── Section: Location Details ───
                      _buildSectionTitle('LOCATION & AREA'),
                      _buildInfoCard(
                        icon: Icons.location_on,
                        title: details.division?.district ?? details.division?.divisionName ?? 'Assigned area',
                        subtitle: 'District Jurisdiction',
                        trailing: Text(
                          '${details.latitude?.toStringAsFixed(4) ?? '-'}, ${details.longitude?.toStringAsFixed(4) ?? '-'}',
                          style: GoogleFonts.spaceGrotesk(fontSize: 11, color: AppColors.outline),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // ─── Section: Assignment Information ───
                      _buildSectionTitle('ASSIGNMENT INFO'),
                      _buildInfoCard(
                        icon: Icons.badge_outlined,
                        title: assignment.role,
                        subtitle: 'Assignment status: ${assignment.status}',
                        trailing: Text(
                          assignment.assignedAt.toLocal().toString().split(' ')[0],
                          style: GoogleFonts.inter(fontSize: 11, color: AppColors.outline),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // ─── Section: Incident Content ───
                      _buildSectionTitle('SITUATION DESCRIPTION'),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.outlineVariant),
                        ),
                        child: Text(
                          details.description ?? 'No tactical description provided for this incident.',
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            height: 1.6,
                            color: AppColors.onSurface.withValues(alpha: 0.9),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // ─── Section: Metadata ───
                      _buildSectionTitle('SYSTEM LOGS'),
                      _buildLogItem('Created at', details.createdAt.toLocal().toString()),
                      _buildLogItem('Incident ID', assignment.incidentId ?? 'N/A'),
                      _buildLogItem('Public visibility', details.publicVisibility ? 'Yes' : 'No'),
                      _buildLogItem('Severity', details.severity),
                      if (details.closedAt != null) _buildLogItem('Closed at', details.closedAt!.toLocal().toString()),
                      
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatusBadge(String status) {
    final bool isVerified = status.toUpperCase() == 'VERIFIED';
    final bool isRejected = status.toUpperCase() == 'REJECTED';
    
    final Color color = isVerified ? Colors.greenAccent : (isRejected ? AppColors.error : AppColors.tertiary);
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(
            status.toUpperCase(),
            style: GoogleFonts.spaceGrotesk(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.0,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: GoogleFonts.spaceGrotesk(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.5,
          color: AppColors.outline,
        ),
      ),
    );
  }

  Widget _buildInfoCard({required IconData icon, required String title, required String subtitle, Widget? trailing}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.onSurface),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(fontSize: 12, color: AppColors.outline),
                ),
              ],
            ),
          ),
          if (trailing != null) trailing,
        ],
      ),
    );
  }

  Widget _buildLogItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(fontSize: 13, color: AppColors.outline),
          ),
          Text(
            value,
            style: GoogleFonts.spaceGrotesk(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  Widget _buildTacticalButton({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
    required bool isPrimary,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: isPrimary ? AppColors.primaryContainer : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: isPrimary ? null : Border.all(color: AppColors.outlineVariant),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: isPrimary ? AppColors.onPrimaryContainer : AppColors.primary,
              ),
              const SizedBox(width: 10),
              Text(
                label,
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                  color: isPrimary ? AppColors.onPrimaryContainer : AppColors.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// End of reports screen
