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

  List<ReportData> _reports = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadReports();
  }

  Future<void> _loadReports() async {
    setState(() => _isLoading = true);
    final response = await AssignmentService.fetchReports();
    if (!mounted) return;
    setState(() {
      _reports = response?.reports ?? [];
      _isLoading = false;
    });
  }

  List<ReportData> get _filteredReports {
    if (_selectedFilter == 1) {
      return _reports.where((report) => report.incidentId.isNotEmpty).toList();
    }
    if (_selectedFilter == 2) {
      return _reports
          .where((report) =>
              report.verificationStatus.toUpperCase() == 'PENDING' ||
              report.verificationStatus.toUpperCase() == 'UNDER_REVIEW')
          .toList();
    }
    return _reports;
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
                        itemCount: _filteredReports.length,
                        itemBuilder: (context, index) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: _buildReportCard(_filteredReports[index]),
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
  Widget _buildReportCard(ReportData report) {
    final status = report.verificationStatus.toUpperCase();
    final Color accent = switch (status) {
      'VERIFIED' => Colors.greenAccent,
      'REJECTED' => AppColors.error,
      _ => AppColors.primary,
    };

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _openReportDetails(report.reportId),
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
                          report.disasterType,
                          style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.onSurface),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${report.reportId} • ${report.reportedAt.toLocal()}',
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
                        report.district,
                        style: GoogleFonts.spaceGrotesk(fontSize: 11, color: AppColors.onSurfaceVariant),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(report.description ?? '-', style: GoogleFonts.inter(fontSize: 14, color: AppColors.onSurface)),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Status: $status',
                      style: GoogleFonts.spaceGrotesk(fontSize: 12, color: AppColors.outline),
                    ),
                    IconButton(
                      tooltip: 'View report',
                      onPressed: () => _openReportDetails(report.reportId),
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

  Future<void> _openReportDetails(String reportId) async {
    final details = await AssignmentService.fetchReportById(reportId);
    if (!mounted) return;
    if (details == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to load report details')),
      );
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Report ${details.reportId}',
                        style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Open in map',
                      icon: const Icon(Icons.map),
                      onPressed: () {
                        Navigator.pop(context);
                        Navigator.pushReplacementNamed(
                          context,
                          '/map',
                          arguments: {
                            'focusLat': details.location.latitude,
                            'focusLon': details.location.longitude,
                            'focusReportId': details.reportId,
                          },
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text('Type: ${details.disasterType}'),
                Text('Source: ${details.source}'),
                Text('District: ${details.district}'),
                Text('Verification: ${details.verificationStatus}'),
                Text('Incident: ${details.incidentId}'),
                Text('Created: ${details.reportedAt.toLocal()}'),
                Text('Coordinates: ${details.location.latitude}, ${details.location.longitude}'),
                if (details.contact != null && details.contact!.isNotEmpty) Text('Contact: ${details.contact}'),
                if (details.sosId != null && details.sosId!.isNotEmpty) Text('SOS: ${details.sosId}'),
                if (details.deviceId != null && details.deviceId!.isNotEmpty) Text('Device: ${details.deviceId}'),
                if (details.reviewedById != null && details.reviewedById!.isNotEmpty) Text('Reviewed By: ${details.reviewedById}'),
                if (details.reviewedAt != null) Text('Reviewed At: ${details.reviewedAt!.toLocal()}'),
                if (details.officerNotes != null && details.officerNotes!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text('Officer Notes', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
                  Text(details.officerNotes!),
                ],
                if (details.mediaUrls.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text('Media URLs (${details.mediaUrls.length})', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
                  ...details.mediaUrls.map((url) => Text(url)),
                ],
                const SizedBox(height: 8),
                Text('Description', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
                Text(details.description ?? '-'),
              ],
            ),
          ),
        );
      },
    );
  }
}

// End of reports screen
