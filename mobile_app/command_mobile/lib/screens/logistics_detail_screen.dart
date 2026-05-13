import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/assignment.dart';
import '../services/assignment_service.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';

class LogisticsDetailScreen extends StatefulWidget {
  final String deploymentId;
  final String? requestId;

  const LogisticsDetailScreen({
    super.key,
    required this.deploymentId,
    this.requestId,
  });

  @override
  State<LogisticsDetailScreen> createState() => _LogisticsDetailScreenState();
}

class _LogisticsDetailScreenState extends State<LogisticsDetailScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _details;
  final _notesController = TextEditingController();
  String? _currentStatus;
  bool _isUpdating = false;

  @override
  void initState() {
    super.initState();
    _loadDetails();
  }

  Future<void> _loadDetails() async {
    if (widget.requestId == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final details = await AssignmentService.fetchResourceRequestDetails(widget.requestId!);
      if (mounted) {
        setState(() {
          _details = details;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading details: $e')),
        );
      }
    }
  }

  Future<void> _updateDeployment(String newStatus) async {
    setState(() => _isUpdating = true);
    try {
      final success = await AssignmentService.updateDeployment(
        deploymentId: widget.deploymentId,
        status: newStatus,
        deliveryNotes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
      );

      if (success && mounted) {
        setState(() => _currentStatus = newStatus);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Deployment updated successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLogistics = AuthService.currentUser?.role == 'LOGISTICS_STAFF';

    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final incident = _details?['incident'];
    final fieldOfficer = _details?['fieldOfficer'];
    final items = _details?['items'] as List?;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'LOGISTICS DEPLOYMENT',
          style: GoogleFonts.spaceGrotesk(
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
            fontSize: 16,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildStatusCard(isLogistics),
            const SizedBox(height: 24),
            if (items != null) _buildItemsCard(items),
            const SizedBox(height: 24),
            if (incident != null) _buildIncidentCard(incident, fieldOfficer),
            const SizedBox(height: 24),
            if (isLogistics) _buildActionSection(),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard(bool isLogistics) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'DEPLOYMENT ID',
                style: GoogleFonts.spaceGrotesk(
                  color: AppColors.onSurfaceVariant,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              Text(
                widget.deploymentId,
                style: GoogleFonts.spaceGrotesk(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            'DELIVERY NOTES',
            style: GoogleFonts.spaceGrotesk(
              color: AppColors.onSurfaceVariant,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          if (isLogistics)
            TextField(
              controller: _notesController,
              maxLines: 3,
              style: GoogleFonts.inter(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Add delivery notes...',
                hintStyle: GoogleFonts.inter(color: Colors.white30),
                filled: true,
                fillColor: Colors.black26,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
              ),
            )
          else
            Text(
              _notesController.text.isEmpty ? 'No notes added.' : _notesController.text,
              style: GoogleFonts.inter(color: Colors.white, fontSize: 14),
            ),
        ],
      ),
    );
  }

  Widget _buildItemsCard(List items) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'RESOURCE PLAN',
            style: GoogleFonts.spaceGrotesk(
              color: AppColors.onSurfaceVariant,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 16),
          ...items.map((item) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.inventory_2, color: AppColors.primary, size: 20),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item['resourceType']?.toString().replaceAll('_', ' ') ?? 'RESOURCE',
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          'Quantity: ${item['quantity']}',
                          style: GoogleFonts.inter(color: AppColors.onSurfaceVariant, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.secondary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      item['priority']?.toString() ?? 'NORMAL',
                      style: GoogleFonts.spaceGrotesk(
                        color: AppColors.secondary,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildIncidentCard(Map incident, Map? officer) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'INCIDENT & LOCATION',
            style: GoogleFonts.spaceGrotesk(
              color: AppColors.onSurfaceVariant,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            incident['title'] ?? 'Unknown Incident',
            style: GoogleFonts.inter(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.location_on, color: AppColors.error, size: 16),
              const SizedBox(width: 4),
              Text(
                incident['district'] ?? 'Unknown Location',
                style: GoogleFonts.inter(color: AppColors.onSurfaceVariant, fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (officer != null) ...[
            Text(
              'ASSIGNED FIELD OFFICER',
              style: GoogleFonts.spaceGrotesk(
                color: AppColors.onSurfaceVariant,
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppColors.primary.withValues(alpha: 0.2),
                  radius: 16,
                  child: const Icon(Icons.person, color: AppColors.primary, size: 16),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        officer['name'] ?? 'Officer',
                        style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      Text(
                        officer['email'] ?? '',
                        style: GoogleFonts.inter(color: AppColors.onSurfaceVariant, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.call, color: AppColors.primary, size: 20),
                  onPressed: () {},
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
          ElevatedButton.icon(
            onPressed: () => _openMap(incident['latitude'], incident['longitude']),
            icon: const Icon(Icons.map, size: 18),
            label: const Text('OPEN TACTICAL MAP'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary.withValues(alpha: 0.15),
              foregroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              side: const BorderSide(color: AppColors.primary, width: 0.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'UPDATE STATUS',
          style: GoogleFonts.spaceGrotesk(
            color: AppColors.onSurfaceVariant,
            fontSize: 12,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: _statusButton('READY', Colors.blueAccent)),
            const SizedBox(width: 12),
            Expanded(child: _statusButton('DEPLOYED', Colors.amberAccent)),
            const SizedBox(width: 12),
            Expanded(child: _statusButton('DELIVERED', Colors.greenAccent)),
          ],
        ),
      ],
    );
  }

  Widget _statusButton(String status, Color color) {
    final isActive = _currentStatus == status;
    return ElevatedButton(
      onPressed: _isUpdating ? null : () => _updateDeployment(status),
      style: ElevatedButton.styleFrom(
        backgroundColor: isActive ? color : color.withValues(alpha: 0.1),
        foregroundColor: isActive ? Colors.black : color,
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: color.withValues(alpha: 0.5)),
        ),
        elevation: isActive ? 4 : 0,
      ),
      child: Text(
        status,
        style: GoogleFonts.spaceGrotesk(
          fontWeight: FontWeight.bold,
          fontSize: 11,
        ),
      ),
    );
  }

  Future<void> _openMap(dynamic lat, dynamic lng) async {
    if (lat == null || lng == null) return;
    final url = 'https://www.google.com/maps/search/?api=1&query=$lat,$lng';
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url));
    }
  }
}
