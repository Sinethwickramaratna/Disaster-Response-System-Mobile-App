import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/assignment.dart';
import '../services/assignment_service.dart';
import '../services/auth_service.dart';
import '../components/app_drawer.dart';
import '../components/notification_button.dart';
import '../components/nav_bar.dart';

class ResourcesScreen extends StatefulWidget {
  const ResourcesScreen({super.key});

  @override
  State<ResourcesScreen> createState() => _ResourcesScreenState();
}

class _ResourcesScreenState extends State<ResourcesScreen> {
  int currentIndex = 3;

  final Color bgColor = const Color(0xFF10131A);
  final Color cardColor = const Color(0xFF191B23);
  final Color borderColor = const Color(0xFF2A2D35);
  final Color textSecondary = const Color(0xFF9CA3AF);
  final Color primaryBlue = const Color(0xFF3B82F6);

  List<Map<String, dynamic>> _activeUnits = _defaultUnits();
  List<ShelterData> _nearbyShelters = const [];
  List<AssignmentIncident> _assignedIncidents = const [];
  bool _isLoadingShelters = false;
  bool _isSubmittingRequest = false;
  String? _shelterMessage;

  @override
  void initState() {
    super.initState();
    _refreshResources();
    _refreshNearbyShelters();
    _refreshAssignedIncidents();
  }

  Future<void> _refreshResources() async {
    try {
      final response = await AssignmentService.fetchResources();
      if (!mounted || response == null || response.resources.isEmpty) {
        return;
      }

      setState(() {
        _activeUnits = response.resources.map(_unitFromResource).toList();
      });
    } catch (_) {
      // Keep the seeded cards when the API is unavailable.
    }
  }

  Future<void> _refreshNearbyShelters() async {
    final userZone = AuthService.currentUser?.zone;
    print('🔍 DEBUG: User zone string: "$userZone"');
    
    final zoneId = AssignmentService.getZoneIdByDistrict(userZone);
    print('🔍 DEBUG: Mapped to zoneId: $zoneId');
    
    if (zoneId == null) {
      print('⚠️ DEBUG: Could not map zone "$userZone" to zoneId');
      setState(() {
        _shelterMessage = 'Assigned zone "$userZone" could not be mapped to shelter zone';
      });
      return;
    }

    setState(() {
      _isLoadingShelters = true;
      _shelterMessage = null;
    });

    try {
      print('🔄 DEBUG: Starting shelter fetch for zone=$userZone (zoneId=$zoneId)');
      final shelters = await AssignmentService.fetchNearbyShelters(zoneId);
      if (!mounted) return;

      print('✅ DEBUG: Received ${shelters.length} shelters');
      shelters.forEach((shelter) {
        print('   - ${shelter.name}: ${shelter.occupancy}/${shelter.capacity} (${shelter.status})');
      });

      setState(() {
        _nearbyShelters = shelters;
        _shelterMessage = shelters.isEmpty ? 'No nearby shelters found' : null;
      });
    } catch (e, stackTrace) {
      print('❌ DEBUG: Error loading shelters: $e');
      print('❌ DEBUG: Stack trace: $stackTrace');
      if (!mounted) return;

      setState(() {
        _shelterMessage = 'Unable to load nearby shelters: ${e.toString()}';
      });
    } finally {
      if (!mounted) return;

      setState(() {
        _isLoadingShelters = false;
      });
    }
  }

  Future<void> _refreshAssignedIncidents() async {
    try {
      final incidents = await AssignmentService.fetchIncidents(status: 'ACTIVE');
      if (!mounted) return;

      setState(() {
        _assignedIncidents = incidents;
      });
    } catch (_) {
      // Keep form available with manual fallback when incidents fail.
    }
  }

  static List<Map<String, dynamic>> _defaultUnits() {
    return [
    {
      "id": "unit-1",
      "name": "SLN Rapid Rescue",
      "pax": 12,
      "location": "Grid 7A",
      "status": "Active Search",
      "type": "rescue"
    },
    {
      "id": "unit-2",
      "name": "Medical Corps B",
      "pax": 24,
      "location": "ETA 14m",
      "status": "In Transit",
      "type": "medical"
    }
  ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      drawer: const AppDrawer(currentRoute: '/resources'),
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
      body: Stack(
        children: [
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildSearchAndFilter(),
                  const SizedBox(height: 24),
                  _buildCapacityCards(),
                  const SizedBox(height: 24),
                  _buildActiveUnits(),
                ],
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: BottomNav(
              currentIndex: currentIndex,
              onTap: (index) {
                if (index == currentIndex) return;
                setState(() => currentIndex = index);
                _navigateTo(context, index);
              },
            ),
          ),
          Positioned(
            right: 16,
            bottom: 78,
            child: FloatingActionButton(
              heroTag: 'request-resources-fab',
              backgroundColor: primaryBlue,
              foregroundColor: Colors.white,
              elevation: 8,
              onPressed: _isSubmittingRequest ? null : _openResourceRequestSheet,
              child: _isSubmittingRequest
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Icon(Icons.add),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildSearchAndFilter() {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 48,
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: borderColor),
            ),
            child: Row(
              children: [
                const SizedBox(width: 12),
                Icon(Icons.search, color: textSecondary, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    style: GoogleFonts.inter(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Search units, zones...',
                      hintStyle: GoogleFonts.inter(color: textSecondary, fontSize: 14),
                      border: InputBorder.none,
                      isDense: true,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Container(
          height: 48,
          width: 48,
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: borderColor),
          ),
          child: IconButton(
            icon: Icon(Icons.filter_list, color: textSecondary),
            onPressed: () {},
          ),
        ),
      ],
    );
  }

  Widget _buildCapacityCards() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'CAPACITY OVERVIEW',
          style: GoogleFonts.inter(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 12),
        if (_isLoadingShelters && _nearbyShelters.isEmpty)
          _buildCapacityMessageCard('Loading nearby shelters...')
        else if (_nearbyShelters.isEmpty)
          _buildCapacityMessageCard(_shelterMessage ?? 'No nearby shelters found')
        else
          ..._nearbyShelters.map((shelter) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _buildShelterCard(shelter),
            );
          }),
      ],
    );
  }

  Widget _buildCapacityMessageCard(String message) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Text(
        message,
        style: GoogleFonts.inter(color: textSecondary, fontSize: 13),
      ),
    );
  }

  Widget _buildShelterCard(ShelterData shelter) {
    final max = shelter.capacity <= 0 ? 1 : shelter.capacity;
    final progress = (shelter.occupancy / max).clamp(0.0, 1.0);
    final normalizedStatus = shelter.status.toUpperCase();
    final isWarning = shelter.occupancy >= shelter.capacity ||
        normalizedStatus == 'FULL' ||
        normalizedStatus == 'UNAVAILABLE';
    final statusColor = isWarning
        ? Colors.redAccent
        : normalizedStatus == 'AVAILABLE'
            ? Colors.tealAccent
            : Colors.amberAccent;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isWarning ? const Color(0xFF3B1010) : cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isWarning ? Colors.redAccent.withValues(alpha: 0.5) : borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  shelter.name,
                  style: GoogleFonts.inter(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: statusColor.withValues(alpha: 0.5)),
                ),
                child: Text(
                  normalizedStatus,
                  style: GoogleFonts.inter(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.0),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Occupancy',
                style: GoogleFonts.inter(color: textSecondary, fontSize: 12),
              ),
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: '${shelter.occupancy} ',
                      style: GoogleFonts.inter(
                        color: isWarning ? Colors.redAccent : Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    TextSpan(
                      text: '/ ${shelter.capacity}',
                      style: GoogleFonts.inter(color: textSecondary, fontSize: 14),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: progress,
            backgroundColor: borderColor,
            color: isWarning ? Colors.redAccent : primaryBlue,
            minHeight: 6,
            borderRadius: BorderRadius.circular(3),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.near_me, color: textSecondary, size: 14),
              const SizedBox(width: 4),
              Text(
                shelter.distanceKm != null ? '${shelter.distanceKm} km' : 'Distance unavailable',
                style: GoogleFonts.inter(color: textSecondary, fontSize: 12),
              ),
              if (shelter.contactPerson != null && shelter.contactPerson!.trim().isNotEmpty) ...[
                const SizedBox(width: 12),
                Icon(Icons.person, color: textSecondary, size: 14),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    shelter.contactPerson!,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(color: textSecondary, fontSize: 12),
                  ),
                ),
              ],
            ],
          ),
          if (shelter.contactPhone != null && shelter.contactPhone!.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.call, color: textSecondary, size: 14),
                const SizedBox(width: 4),
                Text(
                  shelter.contactPhone!,
                  style: GoogleFonts.inter(color: textSecondary, fontSize: 12),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActiveUnits() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'ACTIVE UNITS',
              style: GoogleFonts.inter(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
                fontSize: 14,
              ),
            ),
            Row(
              children: [
                Text('Sort', style: GoogleFonts.inter(color: textSecondary, fontSize: 12)),
                const SizedBox(width: 4),
                Icon(Icons.sort, color: textSecondary, size: 16),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),
        ..._activeUnits.map((unit) {
          final isAlert = unit['status'] == 'Active Search';
          final badgeColor = isAlert ? Colors.redAccent : Colors.tealAccent;

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: primaryBlue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    unit['type'] == 'medical' ? Icons.local_hospital : Icons.security,
                    color: primaryBlue,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        unit['name'],
                        style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.group, color: textSecondary, size: 14),
                          const SizedBox(width: 4),
                          Text('${unit['pax']} Pax', style: GoogleFonts.inter(color: textSecondary, fontSize: 12)),
                          const SizedBox(width: 12),
                          Icon(Icons.location_on, color: textSecondary, size: 14),
                          const SizedBox(width: 4),
                          Text(unit['location'], style: GoogleFonts.inter(color: textSecondary, fontSize: 12)),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: badgeColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: badgeColor.withValues(alpha: 0.5)),
                  ),
                  child: Text(
                    unit['status'].toUpperCase(),
                    style: GoogleFonts.inter(color: badgeColor, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
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

  Map<String, dynamic> _unitFromResource(ResourceDeployment resource) {
    final dispatchedCount = _sumDispatchedItems(resource.itemsDispatched);
    final idFragment = resource.deploymentId.length > 8 ? resource.deploymentId.substring(0, 8) : resource.deploymentId;

    return {
      "id": resource.deploymentId,
      "name": 'Deployment ${idFragment.toUpperCase()}',
      "pax": dispatchedCount > 0 ? dispatchedCount : 1,
      "location": resource.incidentId != null ? 'Incident ${resource.incidentId}' : 'Assigned',
      "status": resource.status,
      "type": resource.status == 'READY' ? 'rescue' : 'medical'
    };
  }

  int _sumDispatchedItems(dynamic itemsDispatched) {
    if (itemsDispatched is Map) {
      return itemsDispatched.values.fold<int>(0, (total, value) {
        final count = int.tryParse(value.toString()) ?? 0;
        return total + count;
      });
    }

    if (itemsDispatched is Iterable) {
      return itemsDispatched.length;
    }

    return int.tryParse(itemsDispatched?.toString() ?? '') ?? 0;
  }

  Future<void> _openResourceRequestSheet() async {
    String? selectedIncidentId;
    for (final assignment in _assignedIncidents) {
      final incidentId = assignment.incidentId;
      if (incidentId != null && incidentId.trim().isNotEmpty) {
        selectedIncidentId = incidentId;
        break;
      }
    }
    String resourceType = 'AMBULANCE';
    String priority = 'MEDIUM';
    final quantityController = TextEditingController(text: '1');
    final notesController = TextEditingController();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final bottomInset = MediaQuery.of(context).viewInsets.bottom;
            return Padding(
              padding: EdgeInsets.only(bottom: bottomInset),
              child: Container(
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                  border: Border.all(color: borderColor),
                ),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: textSecondary.withValues(alpha: 0.4),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'REQUEST RESOURCES',
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.1,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildFieldLabel('Incident'),
                      const SizedBox(height: 6),
                      _buildIncidentDropdown(
                        selectedIncidentId: selectedIncidentId,
                        onChanged: (value) => setSheetState(() => selectedIncidentId = value),
                      ),
                      const SizedBox(height: 12),
                      _buildFieldLabel('Resource Type'),
                      const SizedBox(height: 6),
                      _buildDropdownField<String>(
                        value: resourceType,
                        items: const [
                          'AMBULANCE',
                          'RESCUE_TEAM',
                          'BOAT',
                          'MEDICAL_TEAM',
                          'FOOD_WATER',
                          'SHELTER',
                        ],
                        onChanged: (value) {
                          if (value == null) return;
                          setSheetState(() => resourceType = value);
                        },
                      ),
                      const SizedBox(height: 12),
                      _buildFieldLabel('Quantity'),
                      const SizedBox(height: 6),
                      TextField(
                        controller: quantityController,
                        keyboardType: TextInputType.number,
                        style: GoogleFonts.inter(color: Colors.white),
                        decoration: _inputDecoration('Enter quantity'),
                      ),
                      const SizedBox(height: 12),
                      _buildFieldLabel('Priority'),
                      const SizedBox(height: 6),
                      _buildDropdownField<String>(
                        value: priority,
                        items: const ['LOW', 'MEDIUM', 'HIGH', 'CRITICAL'],
                        onChanged: (value) {
                          if (value == null) return;
                          setSheetState(() => priority = value);
                        },
                      ),
                      const SizedBox(height: 12),
                      _buildFieldLabel('Notes (optional)'),
                      const SizedBox(height: 6),
                      TextField(
                        controller: notesController,
                        minLines: 2,
                        maxLines: 3,
                        style: GoogleFonts.inter(color: Colors.white),
                        decoration: _inputDecoration('Any additional details...'),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isSubmittingRequest
                              ? null
                              : () async {
                                  final messenger = ScaffoldMessenger.of(context);
                                  final incidentId = selectedIncidentId?.trim();
                                  final quantity = int.tryParse(quantityController.text.trim()) ?? 0;

                                  if (incidentId == null || incidentId.isEmpty) {
                                    messenger.showSnackBar(
                                      const SnackBar(content: Text('Please select an incident')),
                                    );
                                    return;
                                  }

                                  if (quantity <= 0) {
                                    messenger.showSnackBar(
                                      const SnackBar(content: Text('Quantity must be greater than zero')),
                                    );
                                    return;
                                  }

                                  setState(() => _isSubmittingRequest = true);
                                  try {
                                    final success = await AssignmentService.submitResourceRequest(
                                      incidentId: incidentId,
                                      resourceType: resourceType,
                                      quantity: quantity,
                                      priority: priority,
                                      notes: notesController.text.trim().isEmpty
                                          ? null
                                          : notesController.text.trim(),
                                    );

                                    if (!mounted) return;

                                    if (success) {
                                      Navigator.pop(ctx);
                                      ScaffoldMessenger.of(this.context).showSnackBar(
                                        const SnackBar(content: Text('Resource request submitted')),
                                      );
                                    } else {
                                      messenger.showSnackBar(
                                        const SnackBar(content: Text('Failed to submit request')),
                                      );
                                    }
                                  } catch (e) {
                                    if (!mounted) return;
                                    messenger.showSnackBar(
                                      SnackBar(content: Text('Request failed: $e')),
                                    );
                                  } finally {
                                    if (mounted) {
                                      setState(() => _isSubmittingRequest = false);
                                    }
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryBlue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: Text(
                            _isSubmittingRequest ? 'SUBMITTING...' : 'SUBMIT REQUEST',
                            style: GoogleFonts.inter(fontWeight: FontWeight.bold, letterSpacing: 0.6),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildFieldLabel(String label) {
    return Text(
      label,
      style: GoogleFonts.inter(
        color: textSecondary,
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _buildIncidentDropdown({
    required String? selectedIncidentId,
    required ValueChanged<String?> onChanged,
  }) {
    final incidentIds = _assignedIncidents
        .map((assignment) => assignment.incidentId)
        .whereType<String>()
        .where((id) => id.trim().isNotEmpty)
        .toList();

    if (incidentIds.isEmpty) {
      return TextField(
        style: GoogleFonts.inter(color: Colors.white),
        decoration: _inputDecoration('No assigned incidents. Enter incident id manually.'),
        onChanged: onChanged,
      );
    }

    final selected = incidentIds.contains(selectedIncidentId)
      ? selectedIncidentId!
      : incidentIds.first;

    return _buildDropdownField<String>(
      value: selected,
      items: incidentIds,
      onChanged: onChanged,
      labelBuilder: (id) {
        final match = _assignedIncidents.firstWhere(
          (incident) => incident.incidentId == id,
          orElse: () => AssignmentIncident(
            assignmentId: id,
            incidentId: id,
            role: '',
            status: '',
            assignedAt: DateTime.now(),
            incident: null,
          ),
        );

        final title = match.incident?.title;
        if (title == null || title.trim().isEmpty) {
          return id;
        }

        return '$title ($id)';
      },
    );
  }

  Widget _buildDropdownField<T>({
    required T value,
    required List<T> items,
    required ValueChanged<T?> onChanged,
    String Function(T)? labelBuilder,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isExpanded: true,
          dropdownColor: cardColor,
          style: GoogleFonts.inter(color: Colors.white),
          onChanged: onChanged,
          items: items
              .map(
                (item) => DropdownMenuItem<T>(
                  value: item,
                  child: Text(
                    labelBuilder != null ? labelBuilder(item) : item.toString(),
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
                  ),
                ),
              )
              .toList(),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.inter(color: textSecondary, fontSize: 13),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: borderColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: borderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: primaryBlue),
      ),
      filled: true,
      fillColor: bgColor,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    );
  }
}
