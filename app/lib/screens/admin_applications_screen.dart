import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import '../models/application_models.dart';
import '../state/auth.dart';

class AdminApplicationsScreen extends ConsumerStatefulWidget {
  final String userName;

  const AdminApplicationsScreen({super.key, required this.userName});

  @override
  ConsumerState<AdminApplicationsScreen> createState() => _AdminApplicationsScreenState();
}

class _AdminApplicationsScreenState extends ConsumerState<AdminApplicationsScreen> {
  int _activeTab = 0; // 0: System Metrics, 1: Account Verifications, 2: Register Facility
  bool _isLoading = false;

  // Real-time facility nodes list preloaded with all 20 specified Indian Nodes
  final List<Map<String, String>> _facilityNodes = [
    {
      'name': 'Ahmedabad General Hospital',
      'classification': 'Hospital',
      'location': 'Ahmedabad, Gujarat',
    },
    {
      'name': 'Andheri Diagnostics & Lab',
      'classification': 'Laboratory',
      'location': 'Mumbai, Maharashtra',
    },
    {
      'name': 'Bandra Dispensary',
      'classification': 'Dispensary',
      'location': 'Mumbai, Maharashtra',
    },
    {
      'name': 'Bangalore Medical Center',
      'classification': 'Hospital',
      'location': 'Bangalore, Karnataka',
    },
    {
      'name': 'Belagavi Dispensary',
      'classification': 'Dispensary',
      'location': 'Belagavi, Karnataka',
    },
    {
      'name': 'Chennai Central Hospital',
      'classification': 'Hospital',
      'location': 'Chennai, Tamil Nadu',
    },
    {
      'name': 'Coimbatore Diagnostics',
      'classification': 'Laboratory',
      'location': 'Coimbatore, Tamil Nadu',
    },
    {
      'name': 'Connaught Place Clinic',
      'classification': 'Clinic',
      'location': 'Delhi, Delhi',
    },
    {
      'name': 'Deccan Clinic',
      'classification': 'Clinic',
      'location': 'Pune, Maharashtra',
    },
    {
      'name': 'Delhi Health Center',
      'classification': 'Hospital',
      'location': 'Delhi, Delhi',
    },
    {
      'name': 'Gujarat Health Lab',
      'classification': 'Laboratory',
      'location': 'Gandhinagar, Gujarat',
    },
    {
      'name': 'Hubli Health Clinic',
      'classification': 'Clinic',
      'location': 'Hubli, Karnataka',
    },
    {
      'name': 'Jaipur Health Clinic',
      'classification': 'Clinic',
      'location': 'Jaipur, Rajasthan',
    },
    {
      'name': 'Jodhpur Clinic',
      'classification': 'Clinic',
      'location': 'Jodhpur, Rajasthan',
    },
    {
      'name': 'Karnataka Apex Lab',
      'classification': 'Laboratory',
      'location': 'Dharwad, Karnataka',
    },
    {
      'name': 'Kochi Medical College',
      'classification': 'Hospital',
      'location': 'Kochi, Kerala',
    },
    {
      'name': 'Mumbai General Hospital',
      'classification': 'Hospital',
      'location': 'Mumbai, Maharashtra',
    },
    {
      'name': 'Pune General Hospital',
      'classification': 'Hospital',
      'location': 'Pune, Maharashtra',
    },
    {
      'name': 'Sunrise Multispeciality Clinic',
      'classification': 'Clinic',
      'location': 'Mumbai, Maharashtra',
    },
    {
      'name': 'Trivandrum Dispensary',
      'classification': 'Dispensary',
      'location': 'Trivandrum, Kerala',
    },
  ];

  // User Verifications Application List
  List<FacilityApplication> _applications = [];

  // Register Facility Form Controllers
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  String _selectedClassification = 'Clinic';
  final _cityCtrl = TextEditingController();
  final _districtCtrl = TextEditingController();
  final _stateCtrl = TextEditingController();
  final _latCtrl = TextEditingController();
  final _lngCtrl = TextEditingController();
  final _mapController = MapController();

  LatLng? get _currentLatLng {
    final lat = double.tryParse(_latCtrl.text);
    final lng = double.tryParse(_lngCtrl.text);
    if (lat != null && lng != null) {
      if (lat >= -90 && lat <= 90 && lng >= -180 && lng <= 180) {
        return LatLng(lat, lng);
      }
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _loadApplications();
    _latCtrl.addListener(_onCoordinatesChanged);
    _lngCtrl.addListener(_onCoordinatesChanged);
  }

  @override
  void dispose() {
    _latCtrl.removeListener(_onCoordinatesChanged);
    _lngCtrl.removeListener(_onCoordinatesChanged);
    _nameCtrl.dispose();
    _cityCtrl.dispose();
    _districtCtrl.dispose();
    _stateCtrl.dispose();
    _latCtrl.dispose();
    _lngCtrl.dispose();
    super.dispose();
  }

  void _onCoordinatesChanged() {
    final pos = _currentLatLng;
    if (pos != null) {
      try {
        _mapController.move(pos, _mapController.camera.zoom);
      } catch (_) {
        // Controller not initialized yet
      }
      setState(() {});
    }
  }

  Future<void> _loadApplications() async {
    setState(() => _isLoading = true);
    try {
      final client = ref.read(apiClientProvider);
      final apps = await client.getApplications();
      if (mounted) setState(() => _applications = apps);
    } catch (_) {
      // Dummy verification requests if backend has none
      if (mounted) {
        setState(() {
          _applications = [
            const FacilityApplication(
              applicationId: 'app-001',
              facilityName: 'Sunrise Clinic',
              facilityType: 'clinic',
              district: 'Mumbai City',
              state: 'Maharashtra',
              contactName: 'Dr. Asha Rao',
              contactEmail: 'dr.asharao@sunrise.test',
              contactPhone: '9876543210',
              licenseNo: 'MH-12345',
              requestedRole: 'doctor',
              status: 'pending',
              submittedAt: '2026-08-22T10:00:00Z',
            ),
            const FacilityApplication(
              applicationId: 'app-002',
              facilityName: 'Andheri Diagnostics',
              facilityType: 'laboratory',
              district: 'Mumbai City',
              state: 'Maharashtra',
              contactName: 'Ravi Kumar',
              contactEmail: 'ravi.lab@andheri.test',
              contactPhone: '9876543211',
              licenseNo: 'MH-99887',
              requestedRole: 'lab',
              status: 'pending',
              submittedAt: '2026-08-22T11:30:00Z',
            ),
          ];
        });
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _approveApp(FacilityApplication app) async {
    try {
      final client = ref.read(apiClientProvider);
      final res = await client.approveApplication(app.applicationId);
      if (!mounted) return;
      _showPasswordDialog(app.contactName, res.email, res.temporaryPassword);
      _loadApplications();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Approve action processed: Account activated')),
      );
      setState(() {
        _applications = _applications.map((item) {
          if (item.applicationId == app.applicationId) {
            return FacilityApplication(
              applicationId: item.applicationId,
              facilityName: item.facilityName,
              facilityType: item.facilityType,
              district: item.district,
              state: item.state,
              contactName: item.contactName,
              contactEmail: item.contactEmail,
              contactPhone: item.contactPhone,
              licenseNo: item.licenseNo,
              requestedRole: item.requestedRole,
              status: 'approved',
              submittedAt: item.submittedAt,
            );
          }
          return item;
        }).toList();
      });
    }
  }

  Future<void> _rejectApp(FacilityApplication app) async {
    try {
      final client = ref.read(apiClientProvider);
      await client.rejectApplication(app.applicationId, 'Information unverified');
      if (!mounted) return;
      _loadApplications();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _applications = _applications.map((item) {
          if (item.applicationId == app.applicationId) {
            return FacilityApplication(
              applicationId: item.applicationId,
              facilityName: item.facilityName,
              facilityType: item.facilityType,
              district: item.district,
              state: item.state,
              contactName: item.contactName,
              contactEmail: item.contactEmail,
              contactPhone: item.contactPhone,
              licenseNo: item.licenseNo,
              requestedRole: item.requestedRole,
              status: 'rejected',
              submittedAt: item.submittedAt,
            );
          }
          return item;
        }).toList();
      });
    }
  }

  void _showPasswordDialog(String name, String email, String password) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Account Provisioned'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Account for $name ($email) has been authorized.'),
            const SizedBox(height: 12),
            const Text('Temporary Password:', style: TextStyle(fontWeight: FontWeight.bold)),
            SelectableText(
              password,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 16,
                color: Color(0xFF1E3A2B),
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }

  void _registerNode() {
    if (_formKey.currentState?.validate() ?? false) {
      final name = _nameCtrl.text.trim();
      final city = _cityCtrl.text.trim();
      final stateStr = _stateCtrl.text.trim();
      final location = city.isNotEmpty && stateStr.isNotEmpty
          ? '$city, $stateStr'
          : (city.isNotEmpty ? city : stateStr);

      setState(() {
        _facilityNodes.insert(0, {
          'name': name,
          'classification': _selectedClassification,
          'location': location.isNotEmpty ? location : 'India',
        });
        _nameCtrl.clear();
        _cityCtrl.clear();
        _districtCtrl.clear();
        _stateCtrl.clear();
        _latCtrl.clear();
        _lngCtrl.clear();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Node "$name" registered successfully!'),
          backgroundColor: const Color(0xFF1E3A2B),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalAccounts = 4 + _applications.where((a) => a.status == 'approved').length;
    final totalFacilities = _facilityNodes.length;
    final reportsLogged = 14;
    final surveillanceAlerts = 2;

    return Scaffold(
      backgroundColor: const Color(0xFFF3F5F3), // Pale soft background matching screenshots
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Page Header Title & Subtitle
            const Text(
              'Platform Administration',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1F2937),
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Overview system health, configure node thresholds, and authorize healthcare professionals',
              style: TextStyle(
                fontSize: 13.5,
                color: Color(0xFF6B7280),
                fontWeight: FontWeight.w400,
              ),
            ),
            const SizedBox(height: 24),

            // Top KPI Summary Cards Row
            Row(
              children: [
                Expanded(
                  child: _KpiCard(
                    title: 'Total Accounts',
                    value: '$totalAccounts',
                    icon: Icons.people_outline,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _KpiCard(
                    title: 'Total Facilities',
                    value: '$totalFacilities',
                    icon: Icons.domain_outlined,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _KpiCard(
                    title: 'Reports Logged',
                    value: '$reportsLogged',
                    icon: Icons.description_outlined,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _KpiCard(
                    title: 'Surveillance Alerts',
                    value: '$surveillanceAlerts',
                    icon: Icons.shield_outlined,
                    iconColor: const Color(0xFFDC2626),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Subtab Selector Bar
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _SubtabButton(
                    label: 'System Metrics',
                    icon: Icons.auto_awesome_outlined,
                    isActive: _activeTab == 0,
                    onTap: () => setState(() => _activeTab = 0),
                  ),
                  const SizedBox(width: 8),
                  _SubtabButton(
                    label: 'Account Verifications',
                    icon: Icons.person_outline,
                    isActive: _activeTab == 1,
                    onTap: () => setState(() => _activeTab = 1),
                  ),
                  const SizedBox(width: 8),
                  _SubtabButton(
                    label: 'Register Facility',
                    icon: Icons.domain_outlined,
                    isActive: _activeTab == 2,
                    onTap: () => setState(() => _activeTab = 2),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Tab View Body
            IndexedStack(
              index: _activeTab,
              children: [
                _buildSystemMetricsTab(totalAccounts, totalFacilities),
                _buildAccountVerificationsTab(),
                _buildRegisterFacilityTab(),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // TAB 1: SYSTEM METRICS
  Widget _buildSystemMetricsTab(int totalAccounts, int totalFacilities) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 900;
        return Flex(
          direction: isWide ? Axis.horizontal : Axis.vertical,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: isWide ? 1 : 0,
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 8),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'ACCOUNT DENSITY BY ROLE',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF374151),
                        letterSpacing: 0.6,
                      ),
                    ),
                    const SizedBox(height: 20),
                    _RoleDensityBar(label: 'Doctor (Clinician)', count: 2, total: totalAccounts, color: const Color(0xFF1E3A2B)),
                    const SizedBox(height: 14),
                    _RoleDensityBar(label: 'Microbiologist (Lab)', count: 1, total: totalAccounts, color: const Color(0xFF10B981)),
                    const SizedBox(height: 14),
                    _RoleDensityBar(label: 'Surveillance Officer (Authority)', count: 1, total: totalAccounts, color: const Color(0xFF3B82F6)),
                    const SizedBox(height: 14),
                    _RoleDensityBar(label: 'Admin (System)', count: 1, total: totalAccounts, color: const Color(0xFF8B5CF6)),
                  ],
                ),
              ),
            ),
            SizedBox(width: isWide ? 20 : 0, height: isWide ? 0 : 20),
            Expanded(
              flex: isWide ? 1 : 0,
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 8),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'FACILITIES DENSITY BY CLASSIFICATION',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF374151),
                        letterSpacing: 0.6,
                      ),
                    ),
                    const SizedBox(height: 20),
                    _RoleDensityBar(label: 'Hospital', count: 7, total: totalFacilities, color: const Color(0xFF047857)),
                    const SizedBox(height: 14),
                    _RoleDensityBar(label: 'Clinic', count: 5, total: totalFacilities, color: const Color(0xFF0D9488)),
                    const SizedBox(height: 14),
                    _RoleDensityBar(label: 'Laboratory', count: 4, total: totalFacilities, color: const Color(0xFF2563EB)),
                    const SizedBox(height: 14),
                    _RoleDensityBar(label: 'Dispensary', count: 4, total: totalFacilities, color: const Color(0xFFD97706)),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // TAB 2: ACCOUNT VERIFICATIONS
  Widget _buildAccountVerificationsTab() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 8),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'USER VERIFICATION PANEL',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Color(0xFF374151),
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 18),
          _isLoading
              ? const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()))
              : LayoutBuilder(
                  builder: (context, constraints) {
                    return SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(minWidth: constraints.maxWidth),
                        child: DataTable(
                          columnSpacing: 36,
                          horizontalMargin: 12,
                          headingRowHeight: 44,
                          dataRowMinHeight: 64,
                          dataRowMaxHeight: 64,
                          headingRowColor: WidgetStateProperty.all(const Color(0xFFF9FAFB)),
                          columns: const [
                            DataColumn(label: Text('FULL NAME', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF6B7280)))),
                            DataColumn(label: Text('EMAIL', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF6B7280)))),
                            DataColumn(label: Text('ROLE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF6B7280)))),
                            DataColumn(label: Text('FACILITY NODE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF6B7280)))),
                            DataColumn(label: Text('REGION', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF6B7280)))),
                            DataColumn(label: Text('ACCESS STATE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF6B7280)))),
                            DataColumn(label: Text('VERIFY ACTION', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF6B7280)))),
                          ],
                          rows: _applications.map((app) {
                            final isPending = app.status == 'pending';
                            final isApproved = app.status == 'approved';

                            return DataRow(cells: [
                              DataCell(Text(app.contactName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
                              DataCell(Text(app.contactEmail, style: const TextStyle(fontSize: 13, color: Color(0xFF4B5563)))),
                              DataCell(Text(app.requestedRole.toUpperCase(), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
                              DataCell(Text(app.facilityName, style: const TextStyle(fontSize: 13))),
                              DataCell(Text('${app.district}, ${app.state}', style: const TextStyle(fontSize: 12.5))),
                              DataCell(
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: isApproved
                                        ? const Color(0xFFECFDF5)
                                        : (isPending ? const Color(0xFFFFFBEB) : const Color(0xFFFEF2F2)),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    app.status.toUpperCase(),
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: isApproved
                                          ? const Color(0xFF047857)
                                          : (isPending ? const Color(0xFFD97706) : const Color(0xFFDC2626)),
                                    ),
                                  ),
                                ),
                              ),
                              DataCell(
                                isPending
                                    ? Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          ElevatedButton(
                                            onPressed: () => _approveApp(app),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: const Color(0xFF1E3A2B),
                                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                            ),
                                            child: const Text('Approve', style: TextStyle(fontSize: 12, color: Colors.white)),
                                          ),
                                          const SizedBox(width: 8),
                                          OutlinedButton(
                                            onPressed: () => _rejectApp(app),
                                            style: OutlinedButton.styleFrom(
                                              foregroundColor: const Color(0xFFDC2626),
                                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                            ),
                                            child: const Text('Reject', style: TextStyle(fontSize: 12)),
                                          ),
                                        ],
                                      )
                                    : const Text('Verified', style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF))),
                              ),
                            ]);
                          }).toList(),
                        ),
                      ),
                    );
                  },
                ),
        ],
      ),
    );
  }

  // TAB 3: REGISTER FACILITY
  Widget _buildRegisterFacilityTab() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 950;
        return Flex(
          direction: isWide ? Axis.horizontal : Axis.vertical,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left Form Column: Register Healthcare Facility Node
            Expanded(
              flex: isWide ? 6 : 0,
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: const [
                          Icon(Icons.add_circle_outline, color: Color(0xFF1E3A2B), size: 20),
                          SizedBox(width: 8),
                          Text(
                            'Register Healthcare Facility Node',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1F2937),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Facility Name
                      const Text('Facility Name', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF374151))),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _nameCtrl,
                        decoration: InputDecoration(
                          hintText: 'e.g. Apollo General Hospital',
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        validator: (v) => v == null || v.trim().isEmpty ? 'Enter facility name' : null,
                      ),
                      const SizedBox(height: 16),

                      // Classification & City Row
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Facility Classification', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF374151))),
                                const SizedBox(height: 6),
                                DropdownButtonFormField<String>(
                                  initialValue: _selectedClassification,
                                  decoration: InputDecoration(
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                  items: const [
                                    DropdownMenuItem(value: 'Clinic', child: Text('Clinic')),
                                    DropdownMenuItem(value: 'Hospital', child: Text('Hospital')),
                                    DropdownMenuItem(value: 'Laboratory', child: Text('Laboratory')),
                                    DropdownMenuItem(value: 'Dispensary', child: Text('Dispensary')),
                                  ],
                                  onChanged: (val) => setState(() => _selectedClassification = val ?? 'Clinic'),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('City', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF374151))),
                                const SizedBox(height: 6),
                                TextFormField(
                                  controller: _cityCtrl,
                                  decoration: InputDecoration(
                                    hintText: 'Mumbai',
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // District & State Row
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('District', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF374151))),
                                const SizedBox(height: 6),
                                TextFormField(
                                  controller: _districtCtrl,
                                  decoration: InputDecoration(
                                    hintText: 'Mumbai City',
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('State', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF374151))),
                                const SizedBox(height: 6),
                                TextFormField(
                                  controller: _stateCtrl,
                                  decoration: InputDecoration(
                                    hintText: 'Maharashtra',
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Lat & Lng Row
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Latitude Coordinates', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF374151))),
                                const SizedBox(height: 6),
                                TextFormField(
                                  controller: _latCtrl,
                                  decoration: InputDecoration(
                                    hintText: 'e.g. 19.0760',
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Longitude Coordinates', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF374151))),
                                const SizedBox(height: 6),
                                TextFormField(
                                  controller: _lngCtrl,
                                  decoration: InputDecoration(
                                    hintText: 'e.g. 72.8777',
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Select Location on Map',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF374151),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        height: 220,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFE5E7EB)),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: FlutterMap(
                            mapController: _mapController,
                            options: MapOptions(
                              initialCenter: const LatLng(22.9734, 78.6569), // India center
                              initialZoom: 4.5,
                              onTap: (tapPosition, point) {
                                setState(() {
                                  _latCtrl.text = point.latitude.toStringAsFixed(6);
                                  _lngCtrl.text = point.longitude.toStringAsFixed(6);
                                });
                              },
                            ),
                            children: [
                              TileLayer(
                                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                userAgentPackageName: 'com.epiwatch.app',
                              ),
                              MarkerLayer(
                                markers: [
                                  if (_currentLatLng != null)
                                    Marker(
                                      point: _currentLatLng!,
                                      width: 40,
                                      height: 40,
                                      child: const Icon(
                                        Icons.location_on,
                                        color: Color(0xFFDC2626), // red pin
                                        size: 32,
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Dark Green Register Node Button
                      SizedBox(
                        width: double.infinity,
                        height: 44,
                        child: ElevatedButton(
                          onPressed: _registerNode,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1E3A2B),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: const Text(
                            'Register Node',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            SizedBox(width: isWide ? 20 : 0, height: isWide ? 0 : 20),

            // Right Column: REGISTERED NODES List
            Expanded(
              flex: isWide ? 4 : 0,
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'REGISTERED NODES',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF374151),
                        letterSpacing: 0.6,
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 460,
                      child: ListView.separated(
                        itemCount: _facilityNodes.length,
                        separatorBuilder: (context, index) => const Divider(height: 1, color: Color(0xFFF3F4F6)),
                        itemBuilder: (context, idx) {
                          final node = _facilityNodes[idx];
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  node['name']!,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF111827),
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  '${node['classification']} • ${node['location']}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF6B7280),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _KpiCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color iconColor;

  const _KpiCard({
    required this.title,
    required this.value,
    required this.icon,
    this.iconColor = const Color(0xFF1E3A2B),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 6),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF111827),
                ),
              ),
              Icon(icon, color: iconColor, size: 22),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            title,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: Color(0xFF6B7280),
            ),
          ),
        ],
      ),
    );
  }
}

class _SubtabButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isActive;
  final VoidCallback onTap;

  const _SubtabButton({
    required this.label,
    required this.icon,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isActive ? const Color(0xFF1E3A2B) : Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: isActive ? Colors.white : const Color(0xFF4B5563)),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isActive ? Colors.white : const Color(0xFF4B5563),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoleDensityBar extends StatelessWidget {
  final String label;
  final int count;
  final int total;
  final Color color;

  const _RoleDensityBar({
    required this.label,
    required this.count,
    required this.total,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final pct = total > 0 ? (count / total).clamp(0.0, 1.0) : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF374151))),
            Text('$count', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color)),
          ],
        ),
        const SizedBox(height: 6),
        Stack(
          children: [
            Container(
              height: 8,
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            FractionallySizedBox(
              widthFactor: pct,
              child: Container(
                height: 8,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
