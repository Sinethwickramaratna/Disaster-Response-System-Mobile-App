import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../components/app_drawer.dart';
import '../components/notification_button.dart';
import '../components/nav_bar.dart';
import '../services/incident_service.dart';
import '../services/assignment_service.dart';
import '../services/auth_service.dart';
import '../models/incident.dart';
import '../models/assignment.dart';

/// Tactical Map screen.
///
/// Faithfully reproduces the HTML/Tailwind mobile design:
///  • Full-screen tactical satellite map with grid overlay
///  • Floating map controls (zoom, location, layers) on top-right
///  • Floating legend panel ("MATRIX") on top-left
///  • Simulated map markers (Critical, Shelter, Elevated)
///  • Bottom sheet with "Active AO Summary", bento stats, priority incident card
///  • BottomNav bar (Map tab active)
class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  int _currentNavIndex = 2; // Map tab
  final MapController _mapController = MapController();
  // Default to Sri Lanka geographic center; updated when shelters load
  final LatLng _center = const LatLng(7.8731, 80.7718);
  List<Incident> _incidents = [];
  List<ShelterData> _shelters = [];
  List<ReportData> _reports = [];
  StreamSubscription<Incident>? _updatesSub;
  bool _showShelters = true;
  bool _showReports = true;
  bool _showIncidents = true;
  String _baseLayer = 'osm';
  // Track current center and zoom to avoid depending on MapController internals
  late LatLng _mapCenter;
  double _currentZoom = 13.0;

  @override
  void dispose() {
    _mapController.dispose();
    _updatesSub?.cancel();
    super.dispose();
  }

  void _showLayersMenu() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(builder: (context, setStState) {
          return Container(
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Layers', style: TextStyle(fontWeight: FontWeight.bold)),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ListTile(
                  title: const Text('Base layer: OpenStreetMap'),
                  leading: Radio<String>(
                    value: 'osm',
                    groupValue: _baseLayer,
                    onChanged: (v) {
                      if (v == null) return;
                      setState(() => _baseLayer = v);
                      setStState(() {});
                    },
                  ),
                ),
                ListTile(
                  title: const Text('Base layer: Satellite'),
                  leading: Radio<String>(
                    value: 'sat',
                    groupValue: _baseLayer,
                    onChanged: (v) {
                      if (v == null) return;
                      setState(() => _baseLayer = v);
                      setStState(() {});
                    },
                  ),
                ),
                SwitchListTile(
                  title: const Text('Show incidents'),
                  value: _showIncidents,
                  onChanged: (v) {
                    setState(() => _showIncidents = v);
                    setStState(() {});
                  },
                ),
                SwitchListTile(
                  title: const Text('Show shelters'),
                  value: _showShelters,
                  onChanged: (v) {
                    setState(() => _showShelters = v);
                    setStState(() {});
                  },
                ),
                SwitchListTile(
                  title: const Text('Show reports'),
                  value: _showReports,
                  onChanged: (v) {
                    setState(() => _showReports = v);
                    setStState(() {});
                  },
                ),
                const SizedBox(height: 8),
              ],
            ),
          );
        });
      },
    );
  }

  @override
  void initState() {
    super.initState();
    _loadIncidents();
    _updatesSub = IncidentService.updates.listen((inc) {
      final idx = _incidents.indexWhere((i) => i.id == inc.id);
      if (idx != -1) {
        setState(() => _incidents[idx] = inc);
      }
    });
    _mapCenter = _center;
    _loadSheltersAndReports();
  }

  Future<void> _loadIncidents() async {
    final zone = AuthService.currentUser?.zone;
    final list = await IncidentService.getIncidentsForZone(zone);
    if (!mounted) return;
    setState(() => _incidents = list);
  }

  Future<void> _loadSheltersAndReports() async {
    try {
      final zoneStr = AuthService.currentUser?.zone;
      final zoneId = AssignmentService.getZoneIdByDistrict(zoneStr);
      if (zoneId != null) {
        try {
          final shelters = await AssignmentService.fetchNearbyShelters(zoneId);
          if (!mounted) return;
          setState(() => _shelters = shelters);

          // If we have at least one shelter with coordinates, center map there
          ShelterData? firstWithCoords;
          for (final shelter in shelters) {
            if (shelter.latitude != null && shelter.longitude != null) {
              firstWithCoords = shelter;
              break;
            }
          }

          if (firstWithCoords != null && firstWithCoords.latitude != null && firstWithCoords.longitude != null) {
            final newCenter = LatLng(firstWithCoords.latitude!, firstWithCoords.longitude!);
            _mapCenter = newCenter;
            _mapController.move(newCenter, _currentZoom);
          }
        } catch (e) {
          print('[Map] Warning: failed to fetch shelters: $e');
        }
      }
    } catch (e) {
      print('[Map] Error mapping zone to shelters: $e');
    }

    try {
      final reportsResp = await AssignmentService.fetchReports();
      if (reportsResp != null && mounted) {
        setState(() => _reports = reportsResp.reports);
      }
    } catch (e) {
      print('[Map] Warning: failed to fetch reports: $e');
    }
  }

  void _zoomIn() {
    _currentZoom = (_currentZoom + 1).clamp(3.0, 18.0);
    _mapController.move(_mapCenter, _currentZoom);
  }

  void _zoomOut() {
    _currentZoom = (_currentZoom - 1).clamp(3.0, 18.0);
    _mapController.move(_mapCenter, _currentZoom);
  }

  void _resetZoom() {
    _currentZoom = 13.0;
    _mapController.move(_center, _currentZoom);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceDim,
      drawer: const AppDrawer(currentRoute: '/map'),
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
      body: Stack(
        children: [
          // ═══════════════════════════════════════
          //  TACTICAL MAP BACKGROUND & MARKERS
          // ═══════════════════════════════════════
          Positioned.fill(
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _center,
                initialZoom: _currentZoom,
                minZoom: 3.0,
                maxZoom: 18.0,
                onPositionChanged: (pos, _) {
                  _mapCenter = pos.center;
                  _currentZoom = pos.zoom ?? _currentZoom;
                },
              ),
              children: [
                TileLayer(
                  urlTemplate: _baseLayer == 'osm'
                      ? 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png'
                      : 'https://services.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
                  subdomains: _baseLayer == 'osm' ? const ['a', 'b', 'c'] : const ['server'],
                  userAgentPackageName: 'command_mobile',
                ),

                if (_showIncidents)
                  MarkerLayer(
                    markers: _incidents.map((inc) {
                      return Marker(
                        point: LatLng(inc.latitude, inc.longitude),
                        width: 72,
                        height: 72,
                        child: GestureDetector(
                          onTap: () => _showIncidentSheet(inc),
                          child: _buildMapMarker(
                            icon: Icons.report,
                            bgColor: inc.priority == 'HIGH' ? AppColors.error : AppColors.primary,
                            fgColor: AppColors.onSurface,
                            label: inc.id,
                            labelColor: AppColors.onSurface,
                            glowColor: inc.priority == 'HIGH' ? const Color(0x33EF4444) : const Color(0x333B82F6),
                          ),
                        ),
                      );
                    }).toList(),
                  ),

                if (_showShelters)
                  MarkerLayer(
                    markers: _shelters
                        .where((s) => s.latitude != null && s.longitude != null)
                        .map((s) {
                      final lat = s.latitude!;
                      final lon = s.longitude!;
                      return Marker(
                        point: LatLng(lat, lon),
                        width: 44,
                        height: 44,
                        child: GestureDetector(
                          onTap: () => _showShelterSheet(s),
                          child: _buildMapMarkerIconOnly(
                            icon: Icons.home_work,
                            bgColor: AppColors.secondary,
                            fgColor: AppColors.onSurface,
                            glowColor: const Color(0x3333CC99),
                          ),
                        ),
                      );
                    }).toList(),
                  ),

                if (_showReports)
                  MarkerLayer(
                    markers: _reports.map((r) {
                      final lat = r.location.latitude;
                      final lon = r.location.longitude;
                      return Marker(
                        point: LatLng(lat, lon),
                        width: 44,
                        height: 44,
                        child: GestureDetector(
                          onTap: () => showModalBottomSheet(
                            context: context,
                            builder: (_) => Container(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(r.title, style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 8),
                                  Text('Type: ${r.disasterType} • Severity: ${r.severity}'),
                                  const SizedBox(height: 8),
                                  Text(r.description ?? ''),
                                ],
                              ),
                            ),
                          ),
                          child: _buildMapMarkerIconOnly(
                            icon: Icons.report,
                            bgColor: AppColors.tertiaryContainer,
                            fgColor: AppColors.onSurface,
                            glowColor: const Color(0x333B82F6),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
              ],
            ),
          ),

          // Grid overlay (fixed over the map)
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _GridPainter(),
              ),
            ),
          ),

          // ═══════════════════════════════════════
          //  MAP CONTROLS (Top Right)
          // ═══════════════════════════════════════
          Positioned(
            top: 12,
            right: 16,
            child: IgnorePointer(
              ignoring: false,
              child: Material(
                type: MaterialType.transparency,
                child: Column(
                  children: [
                    _buildMapControlButton(
                      Icons.add,
                      tooltip: 'Zoom in',
                      onTap: _zoomIn,
                    ),
                    const SizedBox(height: 8),
                    _buildMapControlButton(
                      Icons.remove,
                      tooltip: 'Zoom out',
                      onTap: _zoomOut,
                    ),
                    const SizedBox(height: 16),
                    _buildMapControlButton(
                      Icons.my_location,
                      tooltip: 'Reset location',
                      onTap: _resetZoom,
                    ),
                    const SizedBox(height: 16),
                    _buildMapControlButton(
                      Icons.layers,
                      key: const Key('map-layers-button'),
                      tooltip: 'Layers',
                      onTap: _showLayersMenu,
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ═══════════════════════════════════════
          //  MAP LEGEND (Top Left)
          // ═══════════════════════════════════════
          Positioned(
            top: 12,
            left: 16,
            child: _buildLegendPanel(),
          ),

          // ═══════════════════════════════════════
          //  BOTTOM NAV
          // ═══════════════════════════════════════
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
  //  MAP CONTROL BUTTON (glass panel)
  // ═══════════════════════════════════════
  Widget _buildMapControlButton(
    IconData icon, {
    Key? key,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: const Color(0xFF0B1326).withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: IconButton(
            key: key,
            tooltip: tooltip,
            onPressed: onTap,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 40, height: 40),
            icon: Icon(
              icon,
              color: AppColors.onSurface,
              size: 20,
            ),
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════
  //  LEGEND PANEL ("MATRIX")
  // ═══════════════════════════════════════
  Widget _buildLegendPanel() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          width: 160,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF0B1326).withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'MATRIX',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                  color: AppColors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 10),
              _buildLegendItem(
                color: AppColors.error,
                label: 'CRITICAL',
                hasGlow: true,
                glowColor: const Color(0x33EF4444),
              ),
              const SizedBox(height: 8),
              _buildLegendItem(
                color: AppColors.tertiaryContainer,
                label: 'ELEVATED',
                hasGlow: true,
                glowColor: const Color(0x33DF7412),
              ),
              const SizedBox(height: 8),
              _buildLegendItem(
                color: AppColors.primary,
                label: 'ACTIVE',
                hasGlow: true,
                glowColor: const Color(0x333B82F6),
              ),
              const SizedBox(height: 8),
              _buildLegendItemIcon(
                icon: Icons.home_work,
                iconColor: AppColors.secondary,
                label: 'SHELTER',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLegendItem({
    required Color color,
    required String label,
    bool hasGlow = false,
    Color? glowColor,
  }) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: hasGlow && glowColor != null
                ? [BoxShadow(color: glowColor, blurRadius: 10)]
                : null,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: GoogleFonts.spaceGrotesk(
            fontSize: 10,
            fontWeight: FontWeight.w500,
            color: AppColors.onSurface,
          ),
        ),
      ],
    );
  }

  Widget _buildLegendItemIcon({
    required IconData icon,
    required Color iconColor,
    required String label,
  }) {
    return Row(
      children: [
        Icon(icon, size: 14, color: iconColor),
        const SizedBox(width: 8),
        Text(
          label,
          style: GoogleFonts.spaceGrotesk(
            fontSize: 10,
            fontWeight: FontWeight.w500,
            color: AppColors.onSurface,
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════
  //  MAP MARKER (with label)
  // ═══════════════════════════════════════
  void _showIncidentSheet(Incident inc) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.4,
          minChildSize: 0.2,
          maxChildSize: 0.9,
          builder: (_, controller) {
            return Container(
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerHighest,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              padding: const EdgeInsets.all(12),
              child: ListView(
                controller: controller,
                children: [
                  Text(inc.id, style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.onSurface)),
                  const SizedBox(height: 8),
                  Text('${inc.type} • ${inc.zone}', style: GoogleFonts.spaceGrotesk(color: AppColors.onSurfaceVariant)),
                  const SizedBox(height: 12),
                  Text(inc.description, style: GoogleFonts.inter(color: AppColors.onSurface)),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    children: [
                      ElevatedButton(
                        key: const Key('incident-on-the-way-button'),
                        onPressed: () async {
                          final messenger = ScaffoldMessenger.of(context);
                          await IncidentService.updateIncidentStatus(inc.id, IncidentStatus.onTheWay);
                          if (!mounted) return;
                          Navigator.pop(context);
                          messenger.showSnackBar(const SnackBar(content: Text('Status updated: On the way')));
                        },
                        child: const Text('ON THE WAY'),
                      ),
                      ElevatedButton(
                        key: const Key('incident-reached-button'),
                        onPressed: () async {
                          final messenger = ScaffoldMessenger.of(context);
                          await IncidentService.updateIncidentStatus(inc.id, IncidentStatus.reached);
                          if (!mounted) return;
                          Navigator.pop(context);
                          messenger.showSnackBar(const SnackBar(content: Text('Status updated: Reached')));
                        },
                        child: const Text('REACHED'),
                      ),
                      ElevatedButton(
                        key: const Key('incident-verify-button'),
                        onPressed: () async {
                          final messenger = ScaffoldMessenger.of(context);
                          await IncidentService.updateIncidentStatus(inc.id, IncidentStatus.verified);
                          if (!mounted) return;
                          Navigator.pop(context);
                          messenger.showSnackBar(const SnackBar(content: Text('Marked verified')));
                        },
                        child: const Text('VERIFY'),
                      ),
                      ElevatedButton(
                        key: const Key('request-resources-button'),
                        onPressed: () async {
                          final messenger = ScaffoldMessenger.of(context);
                          final res = await showDialog<String?>(context: context, builder: (dctx) {
                            final ctrl = TextEditingController();
                            return AlertDialog(
                              title: const Text('Request Resources'),
                              content: TextField(
                                key: const Key('request-resources-input'),
                                controller: ctrl,
                                decoration: const InputDecoration(hintText: 'e.g. Ambulance, Medical Team'),
                              ),
                              actions: [
                                TextButton(
                                  key: const Key('request-resources-cancel-button'),
                                  onPressed: () => Navigator.pop(dctx),
                                  child: const Text('Cancel'),
                                ),
                                TextButton(
                                  key: const Key('request-resources-send-button'),
                                  onPressed: () {
                                    final text = ctrl.text;
                                    Navigator.pop(dctx, text);
                                  },
                                  child: const Text('Send'),
                                ),
                              ],
                            );
                          });
                          if (res != null && res.trim().isNotEmpty) {
                            final list = res.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
                            await IncidentService.requestResources(inc.id, list);
                            if (!mounted) return;
                            Navigator.pop(context);
                            messenger.showSnackBar(const SnackBar(content: Text('Resource request sent')));
                          }
                        },
                        child: const Text('REQUEST RESOURCES'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    key: const Key('add-observation-button'),
                    onPressed: () async {
                      final messenger = ScaffoldMessenger.of(context);
                      final note = await showDialog<String?>(context: context, builder: (dctx) {
                        final ctrl = TextEditingController();
                        return AlertDialog(
                          title: const Text('Add Observation'),
                          content: TextField(
                            key: const Key('add-observation-input'),
                            controller: ctrl,
                            decoration: const InputDecoration(hintText: 'Short note'),
                          ), 
                          actions: [
                            TextButton(
                              key: const Key('add-observation-cancel-button'),
                              onPressed: () => Navigator.pop(dctx),
                              child: const Text('Cancel'),
                            ),
                            TextButton(
                              key: const Key('add-observation-save-button'),
                              onPressed: () {
                                final text = ctrl.text;
                                Navigator.pop(dctx, text);
                              },
                              child: const Text('Save'),
                            ),
                          ],
                        );
                      });
                      if (note != null && note.trim().isNotEmpty) {
                        await IncidentService.addObservation(inc.id, note.trim());
                        if (!mounted) return;
                        Navigator.pop(context);
                        messenger.showSnackBar(const SnackBar(content: Text('Observation added')));
                      }
                    },
                    child: const Text('ADD OBSERVATION'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showShelterSheet(ShelterData shelter) {
    final occupancyPercent = shelter.capacity > 0
        ? ((shelter.occupancy / shelter.capacity) * 100).clamp(0, 100).toDouble()
        : 0.0;

    final occupancyColor = occupancyPercent >= 90
        ? AppColors.error
        : occupancyPercent >= 70
            ? AppColors.tertiaryContainer
            : AppColors.secondary;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerHighest,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.secondary.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.home_work, color: AppColors.secondary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    shelter.name,
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.onSurface,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: occupancyColor.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    shelter.status,
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: occupancyColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Occupancy',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                minHeight: 10,
                value: occupancyPercent / 100,
                backgroundColor: Colors.white12,
                valueColor: AlwaysStoppedAnimation<Color>(occupancyColor),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${shelter.occupancy}/${shelter.capacity} (${occupancyPercent.toStringAsFixed(0)}%)',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.onSurface,
              ),
            ),
            const SizedBox(height: 14),
            if (shelter.distanceKm != null)
              Text(
                'Distance: ${shelter.distanceKm!.toStringAsFixed(1)} km',
                style: GoogleFonts.inter(fontSize: 13, color: AppColors.onSurfaceVariant),
              ),
            if (shelter.contactPerson != null && shelter.contactPerson!.isNotEmpty)
              Text(
                'Contact: ${shelter.contactPerson}',
                style: GoogleFonts.inter(fontSize: 13, color: AppColors.onSurfaceVariant),
              ),
            if (shelter.contactPhone != null && shelter.contactPhone!.isNotEmpty)
              Text(
                'Phone: ${shelter.contactPhone}',
                style: GoogleFonts.inter(fontSize: 13, color: AppColors.onSurfaceVariant),
              ),
            const SizedBox(height: 6),
          ],
        ),
      ),
    );
  }
  Widget _buildMapMarker({
    required IconData icon,
    required Color bgColor,
    required Color fgColor,
    required String label,
    required Color labelColor,
    required Color glowColor,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: bgColor,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
            boxShadow: [BoxShadow(color: glowColor, blurRadius: 15)],
          ),
          child: Icon(icon, size: 16, color: fgColor),
        ),
        const SizedBox(height: 4),
        // Glass label
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFF0B1326).withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(4),
                border:
                    Border.all(color: Colors.white.withValues(alpha: 0.1)),
              ),
              child: Text(
                label,
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: labelColor,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════
  //  MAP MARKER (icon only, no label)
  // ═══════════════════════════════════════
  Widget _buildMapMarkerIconOnly({
    required IconData icon,
    required Color bgColor,
    required Color fgColor,
    required Color glowColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: bgColor,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
        boxShadow: [BoxShadow(color: glowColor, blurRadius: 15)],
      ),
      child: Icon(icon, size: 16, color: fgColor),
    );
  }

  // ═══════════════════════════════════════
  //  BOTTOM SHEET — Active AO Summary
  // ═══════════════════════════════════════
  Widget _buildBottomSheet() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHighest.withValues(alpha: 0.95),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        border: const Border(
          top: BorderSide(color: Colors.white10),
        ),
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle
              Container(
                margin: const EdgeInsets.symmetric(vertical: 8),
                width: 48,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Header: title + LIVE badge ──
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'ACTIVE AO SUMMARY',
                          style: GoogleFonts.inter(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.3,
                            color: AppColors.onSurface,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color:
                                AppColors.primary.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                                color: AppColors.primary
                                    .withValues(alpha: 0.3)),
                          ),
                          child: Text(
                            'LIVE',
                            style: GoogleFonts.spaceGrotesk(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.8,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // ── Bento Stats Grid ──
                    Row(
                      children: [
                        Expanded(child: _buildStatCard(
                          label: 'PERSONNEL',
                          value: '2,450',
                          valueColor: AppColors.primary,
                          delta: '+120',
                          deltaColor: AppColors.secondary,
                          glowColor: const Color(0x333B82F6),
                        )),
                        const SizedBox(width: 4),
                        Expanded(child: _buildStatCard(
                          label: 'INCIDENTS',
                          value: '47',
                          valueColor: AppColors.error,
                          delta: '+3',
                          deltaColor: AppColors.error,
                          glowColor: const Color(0x33EF4444),
                        )),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // ── Priority Incident Card ──
                    _buildPriorityIncidentCard(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════
  //  STAT CARD (bento grid item)
  // ═══════════════════════════════════════
  Widget _buildStatCard({
    required String label,
    required String value,
    required Color valueColor,
    required String delta,
    required Color deltaColor,
    required Color glowColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.spaceGrotesk(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
              color: AppColors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: GoogleFonts.inter(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: valueColor,
                  shadows: [
                    Shadow(color: glowColor, blurRadius: 15),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                delta,
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: deltaColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════
  //  PRIORITY INCIDENT CARD
  // ═══════════════════════════════════════
  Widget _buildPriorityIncidentCard() {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.surfaceDim,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Top accent border (error red)
          Container(height: 2, color: AppColors.error),

          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header: icon + zone | timestamp
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.flood,
                            size: 18, color: AppColors.error),
                        const SizedBox(width: 8),
                        Text(
                          'ZONE-ALPHA',
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0.7,
                            color: AppColors.onSurface,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      'T-MINUS 12M',
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: AppColors.error,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Description
                Text(
                  'Severe flooding reported. Immediate evacuation protocols initiated.',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    height: 1.5,
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),

                // Action row: Dispatch + Eye
                Row(
                  children: [
                    // Dispatch button
                    Expanded(
                      child: Material(
                        color: AppColors.error.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                        child: InkWell(
                          key: const Key('priority-dispatch-button'),
                          borderRadius: BorderRadius.circular(4),
                          onTap: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Dispatching unit to ZONE-ALPHA...')),
                            );
                          },
                          child: Container(
                            padding:
                                const EdgeInsets.symmetric(vertical: 8),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                  color:
                                      AppColors.error.withValues(alpha: 0.5)),
                            ),
                            child: Text(
                              'DISPATCH',
                              style: GoogleFonts.spaceGrotesk(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.5,
                                color: AppColors.error,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Visibility button
                    GestureDetector(
                      key: const Key('priority-visibility-button'),
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Toggling incident visibility...')),
                        );
                      },
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                              color: Colors.white.withValues(alpha: 0.1)),
                        ),
                        child: const Icon(
                          Icons.visibility,
                          size: 14,
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════
//  GRID PAINTER (subtle tactical overlay)
// ═══════════════════════════════════════
class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.03)
      ..strokeWidth = 1;

    const double gridSize = 40;

    // Vertical lines
    for (double x = 0; x <= size.width; x += gridSize) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }

    // Horizontal lines
    for (double y = 0; y <= size.height; y += gridSize) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
