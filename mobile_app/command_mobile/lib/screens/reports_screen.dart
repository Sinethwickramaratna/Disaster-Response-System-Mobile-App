import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../components/app_drawer.dart';
import '../components/notification_button.dart';
import '../components/nav_bar.dart';
import '../services/assignment_service.dart';
import '../services/notification_service.dart';
import '../services/socket_service.dart';
import '../models/assignment.dart';

/// Field Reports (Incoming Reports) screen.
class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  int _selectedFilter = 0; // 0 = All
  int _currentNavIndex = 1; // Reports tab

  final List<String> _filterLabels = ['ALL', 'ASSIGNED', 'PRIORITY'];

  List<AssignmentIncident> _incidents = [];
  bool _isLoading = false;
  StreamSubscription? _socketSub;

  @override
  void initState() {
    super.initState();
    _loadReports();

    _socketSub = SocketService.instance.onAssignmentUpdate.listen((_) {
      if (mounted) _loadReports(ignoreCache: true);
    });
  }

  @override
  void dispose() {
    _socketSub?.cancel();
    super.dispose();
  }

  Future<void> _loadReports({bool ignoreCache = false}) async {
    setState(() => _isLoading = true);
    final response = await AssignmentService.fetchIncidents(ignoreCache: ignoreCache);
    if (!mounted) return;
    setState(() {
      _incidents = response;
      _isLoading = false;
    });

    // Handle deep-linking from notifications
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      if (args != null && args.containsKey('incidentId')) {
        final incidentId = args['incidentId'];
        final match = _incidents.where((i) => i.incidentId == incidentId).toList();
        if (match.isNotEmpty) {
          _openIncidentDetails(match.first);
        }
      }
    });
  }

  List<AssignmentIncident> get _filteredIncidents {
    if (_selectedFilter == 1) {
      return _incidents.where((assignment) => assignment.incidentId?.isNotEmpty == true).toList();
    }
    if (_selectedFilter == 2) {
      return _incidents
          .where((assignment) =>
              assignment.status.toUpperCase() == 'ACTIVE' ||
              assignment.status.toUpperCase() == 'INSPECTING')
          .toList();
    }
    return _incidents;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      drawer: const AppDrawer(currentRoute: '/reports'),
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
      body: Column(
        children: [
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
                          onTap: () => setState(() => _selectedFilter = i),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: isActive
                                  ? AppColors.primary.withValues(alpha: 0.2)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(2),
                              border: isActive
                                  ? Border.all(color: AppColors.primary.withValues(alpha: 0.3))
                                  : null,
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              _filterLabels[i],
                              style: GoogleFonts.spaceGrotesk(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.2,
                                color: isActive ? AppColors.primary : AppColors.onSurfaceVariant,
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

  Widget _buildReportCard(AssignmentIncident assignment) {
    final incident = assignment.incident;
    final status = assignment.status;
    final Color accent = switch (status) {
      'ACTIVE' => Colors.greenAccent,
      'FALSEREPORT' => AppColors.error,
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
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                incident?.title ?? 'ASSIGNED INCIDENT',
                                style: GoogleFonts.inter(
                                    fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.onSurface),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '${assignment.shortIncidentId} • ${assignment.assignedAt.toLocal().toString().split(' ')[0]}',
                                style: GoogleFonts.spaceGrotesk(fontSize: 11, color: AppColors.outline),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
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
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      incident?.description ?? 'No incident description provided.',
                      style: GoogleFonts.inter(fontSize: 14, color: AppColors.onSurface),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildStatusBadge(status),
                        const Icon(Icons.open_in_new, color: Color(0xFF4D8EFF), size: 20),
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
      builder: (_) => IncidentDetailsSheet(
        assignment: assignment,
        onUpdate: _loadReports,
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  INCIDENT DETAILS SHEET
// ══════════════════════════════════════════════════════════════════════════════

class IncidentDetailsSheet extends StatefulWidget {
  final AssignmentIncident assignment;
  final VoidCallback onUpdate;

  const IncidentDetailsSheet({
    super.key,
    required this.assignment,
    required this.onUpdate,
  });

  @override
  State<IncidentDetailsSheet> createState() => _IncidentDetailsSheetState();
}

class _IncidentDetailsSheetState extends State<IncidentDetailsSheet> {
  bool _isEditing = false;
  bool _isSaving = false;

  late TextEditingController _descriptionController;
  late TextEditingController _affectedPeopleController;
  late TacticalIncidentStatus _selectedStatus;
  late TacticalIncidentSeverity _selectedSeverity;
  late IncidentData _localIncident;

  @override
  void initState() {
    super.initState();
    final details = widget.assignment.incident!;
    _descriptionController = TextEditingController(text: details.description);
    _affectedPeopleController =
        TextEditingController(text: (details.affectedPopulation ?? 0).toString());
    _selectedStatus = details.status;
    _selectedSeverity = details.severity;
    _localIncident = details;
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _affectedPeopleController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    setState(() => _isSaving = true);
    try {
      final success = await AssignmentService.updateIncident(
        incidentId: widget.assignment.incidentId!,
        description: _descriptionController.text,
        affectedPeople: int.tryParse(_affectedPeopleController.text),
        status: _selectedStatus.dbValue,
        severity: _selectedSeverity.name,
      );

      if (success) {
        widget.onUpdate();
        if (mounted) {
          setState(() {
            _isEditing = false;
            // Update local incident state to reflect changes immediately
            _localIncident = _localIncident.copyWith(
              description: _descriptionController.text,
              affectedPopulation: int.tryParse(_affectedPeopleController.text),
              status: _selectedStatus,
              severity: _selectedSeverity,
            );
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Tactical data updated successfully')),
          );
        }
      } else {
        throw Exception('Update failed');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating incident: $e')),
        );
        // Add failure notification to history
        NotificationService.instance.addNotification({
          'title': 'Update Failed',
          'message': 'Failed to update situation for incident ${widget.assignment.shortIncidentId}: $e',
          'type': 'error',
          'createdAt': DateTime.now().toIso8601String(),
        });
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final details = _localIncident;
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
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
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'INCIDENT #${widget.assignment.shortIncidentId}',
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
                      _buildStatusBadge(_isEditing ? _selectedStatus : details.status),
                    ],
                  ),
                  const SizedBox(height: 24),
                  if (_isEditing) _buildEditForm() else _buildViewContent(details),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildViewContent(IncidentData details) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: _buildTacticalButton(
                label: 'UPDATE SITUATION',
                icon: Icons.edit_note,
                onTap: () => setState(() => _isEditing = true),
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
                      'focusReportId': widget.assignment.incidentId,
                    },
                  );
                },
                isPrimary: false,
              ),
            ),
          ],
        ),
        const SizedBox(height: 32),
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
        _buildSectionTitle('SITUATION DESCRIPTION'),
        Container(
          width: double.infinity,
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
        _buildSectionTitle('FIELD DATA'),
        _buildInfoCard(
          icon: Icons.people_outline,
          title: '${details.affectedPopulation ?? 0}',
          subtitle: 'Estimated affected people',
        ),
        const SizedBox(height: 24),
        _buildSectionTitle('SYSTEM LOGS'),
        _buildLogItem('Created at', details.createdAt.toLocal().toString()),
        _buildLogItem('Incident ID', widget.assignment.shortIncidentId),
        _buildLogItem('Severity', details.severity.name),
      ],
    );
  }

  Widget _buildEditForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('SITUATION UPDATE'),
        TextField(
          controller: _descriptionController,
          maxLines: 4,
          style: GoogleFonts.inter(color: AppColors.onSurface),
          decoration: InputDecoration(
            hintText: 'Enter current situation description...',
            hintStyle: GoogleFonts.inter(color: AppColors.outline),
            filled: true,
            fillColor: AppColors.surfaceContainerLow,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.outlineVariant),
            ),
          ),
        ),
        const SizedBox(height: 20),
        _buildSectionTitle('AFFECTED PEOPLE'),
        TextField(
          controller: _affectedPeopleController,
          keyboardType: TextInputType.number,
          style: GoogleFonts.inter(color: AppColors.onSurface),
          decoration: InputDecoration(
            hintText: 'Count...',
            prefixIcon: const Icon(Icons.people, size: 20),
            filled: true,
            fillColor: AppColors.surfaceContainerLow,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.outlineVariant),
            ),
          ),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionTitle('STATUS'),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.outlineVariant),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<TacticalIncidentStatus>(
                        value: _selectedStatus,
                        isExpanded: true,
                        dropdownColor: AppColors.surface,
                        items: TacticalIncidentStatus.values
                            .map((s) => DropdownMenuItem(
                                  value: s,
                                  child: Text(s.label,
                                      style: GoogleFonts.inter(color: AppColors.onSurface, fontSize: 13)),
                                ))
                            .toList(),
                        onChanged: (v) => setState(() => _selectedStatus = v ?? _selectedStatus),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionTitle('SEVERITY'),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.outlineVariant),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<TacticalIncidentSeverity>(
                        value: _selectedSeverity,
                        isExpanded: true,
                        dropdownColor: AppColors.surface,
                        items: TacticalIncidentSeverity.values
                            .map((s) => DropdownMenuItem(
                                  value: s,
                                  child: Text(s.name,
                                      style: GoogleFonts.inter(color: AppColors.onSurface, fontSize: 13)),
                                ))
                            .toList(),
                        onChanged: (v) => setState(() => _selectedSeverity = v ?? _selectedSeverity),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 32),
        Row(
          children: [
            Expanded(
              child: _buildTacticalButton(
                label: 'CANCEL',
                icon: Icons.close,
                onTap: () => setState(() => _isEditing = false),
                isPrimary: false,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildTacticalButton(
                label: _isSaving ? 'SAVING...' : 'SAVE UPDATES',
                icon: _isSaving ? Icons.sync : Icons.save,
                onTap: _isSaving ? () {} : _handleSave,
                isPrimary: true,
              ),
            ),
          ],
        ),
      ],
    );
  }


  MainAxisSize get minAxisSize => MainAxisSize.min;

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
            style: GoogleFonts.spaceGrotesk(
                fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.onSurfaceVariant),
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

// ══════════════════════════════════════════════════════════════════════════════
//  SHARED UTILITIES
// ══════════════════════════════════════════════════════════════════════════════

Widget _buildStatusBadge(dynamic status) {
  final String statusStr = status is TacticalIncidentStatus 
      ? status.name 
      : (status?.toString() ?? 'UNKNOWN');
  
  final color = _getStatusColor(statusStr);
  
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(4),
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
          statusStr.toUpperCase().replaceAll('_', ' '),
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

Color _getStatusColor(String status) {
  final s = status.toUpperCase().replaceAll('-', '_').replaceAll(' ', '_');
  switch (s) {
    case 'ACTIVE':
    case 'ASSIGNED':
    case 'VERIFIED':
      return const Color(0xFF4D8EFF);
    case 'EN_ROUTE':
    case 'PENDING_REVIEW':
      return const Color(0xFFFFAB40);
    case 'AT_THE_INCIDENT':
    case 'ATTHEINCIDENT':
    case 'ON_SITE':
    case 'INSPECTING':
      return const Color(0xFF00C853);
    case 'FALSEREPORT':
    case 'FALSE_REPORT':
    case 'REJECTED':
      return const Color(0xFFFF5252);
    case 'RESOLVED':
    case 'CLOSED':
    case 'RELEASED':
    case 'DUPLICATE':
      return Colors.grey;
    default:
      return const Color(0xFFADC6FF);
  }
}
