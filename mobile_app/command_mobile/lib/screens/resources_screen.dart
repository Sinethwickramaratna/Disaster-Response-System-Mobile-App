import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/assignment.dart';
import '../services/assignment_service.dart';
import '../services/auth_service.dart';
import '../services/socket_service.dart';
import '../services/notification_service.dart';
import '../components/app_drawer.dart';
import '../components/notification_button.dart';
import '../components/nav_bar.dart';
import 'logistics_detail_screen.dart';

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

  List<ResourceDeployment> _assignedResources = const [];
  List<ResourceRequestData> _resourceRequests = const [];
  List<ShelterData> _nearbyShelters = const [];
  List<AssignmentIncident> _assignedIncidents = const [];
  bool _isLoadingResources = false;
  bool _isLoadingRequests = false;
  bool _isLoadingShelters = false;
  bool _isSubmittingRequest = false;
  String? _requestsMessage;
  String? _shelterMessage;
  StreamSubscription? _socketSub;

  @override
  void initState() {
    super.initState();
    _refreshResources(ignoreCache: true);
    _refreshResourceRequests(ignoreCache: true);
    _refreshNearbyShelters();
    _refreshAssignedIncidents(ignoreCache: true);

    // Ensure socket is connected for real-time updates
    SocketService.instance.connect();

    _socketSub = SocketService.instance.onAssignmentUpdate.listen((data) {
      if (!mounted) return;
      
      final event = data['event'];
      final requestId = data['requestId']?.toString() ?? data['request_id']?.toString();
          final deploymentId = data['deploymentId']?.toString() ?? data['deployment_id']?.toString();
      
          debugPrint('📥 [ResourcesScreen] Socket Event: $event, RequestID: $requestId, DeploymentID: $deploymentId');

      // Optimistic local update for deletion
      if (event == 'resourceRequest:deleted' && requestId != null) {
        setState(() {
          // Convert to growable list if it's fixed-length to avoid Unsupported operation error
          final currentRequests = List<ResourceRequestData>.from(_resourceRequests);
          currentRequests.removeWhere((r) => r.requestId.toLowerCase() == requestId.toLowerCase());
          _resourceRequests = currentRequests;
        });
      }

          if ((event == 'resource:statusUpdated' || event == 'resource:updated' || event == 'resource:removed') && deploymentId != null) {
            _refreshResources(ignoreCache: true);
          }
      
      // Always trigger a full refresh to ensure data consistency with the server
      // Small delay to allow DB operations to complete
      Future.delayed(const Duration(milliseconds: 600), () {
        if (mounted) {
          _refreshResources(ignoreCache: true);
          _refreshResourceRequests(ignoreCache: true);
          _refreshAssignedIncidents(ignoreCache: true);
        }
      });
    });
  }

  Future<void> _refreshResources({bool ignoreCache = false}) async {
    if (!mounted) return;
    setState(() {
      _isLoadingResources = true;
    });
    try {
      final response = await AssignmentService.fetchResources(ignoreCache: ignoreCache);
      if (!mounted) {
        return;
      }

      setState(() {
        _assignedResources = response?.resources ?? const [];
      });
    } catch (_) {
      // Keep existing cards when the API is unavailable.
    } finally {
      if (mounted) {
        setState(() => _isLoadingResources = false);
      }
    }
  }

  Future<void> _refreshResourceRequests({bool ignoreCache = false}) async {
    if (!mounted) return;
    setState(() {
      _isLoadingRequests = true;
      _requestsMessage = null;
    });

    try {
      final requests = await AssignmentService.fetchMyResourceRequests(ignoreCache: ignoreCache);
      if (!mounted) return;

      setState(() {
        _resourceRequests = requests;
        if (requests.isEmpty) {
          _requestsMessage = 'No resource requests submitted yet';
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _requestsMessage = 'Unable to load requested resources';
      });
    } finally {
      if (mounted) {
        setState(() => _isLoadingRequests = false);
      }
    }
  }

  Future<void> _refreshNearbyShelters() async {
    final assignedDistrict = AuthService.currentUser?.zone ?? '';
    print('🔍 DEBUG: Assigned district string: "$assignedDistrict"');
    
    if (DateTime.now().millisecondsSinceEpoch < 0 && assignedDistrict.trim().isEmpty) {
      print('⚠️ DEBUG: Could not determine assigned district');
      setState(() {
        _shelterMessage = 'Assigned district could not be determined';
      });
      return;
    }

    setState(() {
      _isLoadingShelters = true;
      _shelterMessage = null;
    });

    try {
      print('🔄 DEBUG: Starting shelter fetch for district=$assignedDistrict');
      final shelters = await AssignmentService.fetchNearbyShelters();
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

  @override
  void dispose() {
    _socketSub?.cancel();
    super.dispose();
  }

  Future<void> _refreshAssignedIncidents({bool ignoreCache = false}) async {
    try {
      final incidents = await AssignmentService.fetchIncidents(ignoreCache: ignoreCache);
      if (!mounted) return;

      setState(() {
        _assignedIncidents = incidents;
      });
    } catch (_) {
      // Keep form available with manual fallback when incidents fail.
    }
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
      bottomNavigationBar: BottomNav(
        currentIndex: currentIndex,
        onTap: (index) {
          if (index == currentIndex) return;
          setState(() => currentIndex = index);
          _navigateTo(context, index);
        },
      ),
      floatingActionButton: AuthService.currentUser?.role == 'FIELD_OFFICER'
          ? FloatingActionButton(
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
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      body: Stack(
        children: [
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(0, 16, 0, 90),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _buildSearchAndFilter(),
                  ),
                  const SizedBox(height: 24),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _buildCapacityCards(),
                  ),
                  const SizedBox(height: 24),
                    _buildRequestedResources(),
                    const SizedBox(height: 24),
                    _buildAssignedResources(),
                  ],
                  if (AuthService.currentUser?.role == 'LOGISTICS_STAFF') ...[
                    _buildAssignedResources(),
                  ],
                ],
              ),
            ),
          ),
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
                      hintText: 'Search requests, incidents...',
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
      width: double.infinity,
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

  Widget _buildRequestedResources() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'REQUESTED RESOURCES',
            style: GoogleFonts.inter(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 12),
          if (_isLoadingRequests && _resourceRequests.isEmpty)
            _buildCapacityMessageCard('Loading requested resources...')
          else if (_resourceRequests.isEmpty)
            _buildCapacityMessageCard(_requestsMessage ?? 'No resource requests submitted yet')
          else
            ..._resourceRequests.map((request) {
              final status = request.status.toUpperCase();
              final statusColor = switch (status) {
                'APPROVED' => Colors.tealAccent,
                'FULFILLED' => Colors.greenAccent,
                'REJECTED' => Colors.redAccent,
                'IGNORED' => Colors.orangeAccent,
                _ => Colors.amberAccent,
              };
              final createdAt = request.createdAt.toLocal().toString().split('.').first;
              final reviewedAt = request.reviewedAt?.toLocal().toString().split('.').first;
              final itemLabel = request.items.isEmpty
                  ? 'No item details'
                  : request.items
                      .map((item) => '${item.resourceType} x${item.quantity} (${item.priority})')
                      .join(', ');

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: borderColor),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Requested Resource ${request.requestId}',
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: statusColor.withValues(alpha: 0.5)),
                          ),
                          child: Text(
                            status,
                            style: GoogleFonts.inter(
                              color: statusColor,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.6,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Incident: ${request.incidentId}',
                      style: GoogleFonts.inter(color: textSecondary, fontSize: 12),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Requested: $createdAt',
                      style: GoogleFonts.inter(color: textSecondary, fontSize: 12),
                    ),
                    if (reviewedAt != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Reviewed: $reviewedAt',
                        style: GoogleFonts.inter(color: textSecondary, fontSize: 12),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Text(
                      itemLabel,
                      style: GoogleFonts.inter(color: Colors.white, fontSize: 12),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildAssignedResources() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ASSIGNED RESOURCES',
            style: GoogleFonts.inter(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 12),
          if (_isLoadingResources && _assignedResources.isEmpty)
            _buildCapacityMessageCard('Loading assigned resources...')
          else if (_assignedResources.isEmpty)
            _buildCapacityMessageCard('No assigned resources available')
          else
            ..._assignedResources.map((resource) {
              final status = resource.status.toUpperCase();
              final badgeColor = switch (status) {
                'READY' => Colors.tealAccent,
                'DEPLOYED' => Colors.amberAccent,
                'DELIVERED' => Colors.greenAccent,
                _ => Colors.blueAccent,
              };
              final dispatchedCount = _sumDispatchedItems(resource.itemsDispatched);
              final titleText = (status == 'DEPLOYED' || status == 'DELIVERED')
                  ? 'Assigned Resource ${resource.deploymentId}'
                  : 'Deployment ${resource.deploymentId}';

              return GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => LogisticsDetailScreen(
                        deploymentId: resource.deploymentId,
                        requestId: resource.requestId,
                      ),
                    ),
                  ).then((_) => _refreshResources(ignoreCache: true));
                },
                child: Container(
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
                        child: Icon(Icons.inventory_2, color: primaryBlue),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              titleText,
                              style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Incident: ${resource.incidentId ?? 'N/A'}',
                              style: GoogleFonts.inter(color: textSecondary, fontSize: 12),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Items: $dispatchedCount',
                              style: GoogleFonts.inter(color: textSecondary, fontSize: 12),
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
                          status,
                          style: GoogleFonts.inter(color: badgeColor, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
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
                                      await _refreshResourceRequests(ignoreCache: true);
                                      ScaffoldMessenger.of(this.context).hideCurrentSnackBar();
                                      ScaffoldMessenger.of(this.context).showSnackBar(
                                        const SnackBar(content: Text('Resource request submitted')),
                                      );
                                    } else {
                                      messenger.hideCurrentSnackBar();
                                      messenger.showSnackBar(
                                        const SnackBar(content: Text('Failed to submit request')),
                                      );
                                      // Add failure notification to history
                                      NotificationService.instance.addNotification({
                                        'title': 'Submission Failed',
                                        'message': 'Failed to submit resource request ($resourceType x $quantity) for incident $incidentId',
                                        'type': 'error',
                                        'createdAt': DateTime.now().toIso8601String(),
                                      });
                                    }
                                  } catch (e) {
                                    if (!mounted) return;
                                    messenger.hideCurrentSnackBar();
                                    messenger.showSnackBar(
                                      SnackBar(content: Text('Request failed: $e')),
                                    );
                                    // Add failure notification to history
                                    NotificationService.instance.addNotification({
                                      'title': 'Request Error',
                                      'message': 'Error submitting resource request: $e',
                                      'type': 'error',
                                      'createdAt': DateTime.now().toIso8601String(),
                                    });
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
        .toSet() // Ensure uniqueness to prevent Dropdown duplicates error
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
