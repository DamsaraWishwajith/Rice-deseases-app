import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_messaging/firebase_messaging.dart';
import '../theme/app_colors.dart';
import '../widgets/card_widget.dart';
import '../widgets/top_bar.dart';
import '../widgets/button_widget.dart';
import '../models/farmer.dart';
import '../models/supervisor.dart';
import '../models/disease_rec.dart';
import 'login_screen.dart';
import '../models/disease_report.dart';
import '../services/disease_service.dart';
import '../services/gemini_service.dart';

class MoreScreen extends StatefulWidget {
  final List<Farmer> farmers;
  final Supervisor supervisor;

  const MoreScreen({super.key, required this.farmers, required this.supervisor});

  @override
  State<MoreScreen> createState() => _MoreScreenState();
}

class _MoreScreenState extends State<MoreScreen> {
  String _subPage = 'menu';
  bool _generating = false;
  List<DiseaseReport> _reports = [];
  bool _isLoadingReports = false;

  List<Map<String, dynamic>> analytics = [];

  late TextEditingController _apiKeyController;
  late TextEditingController _usernameController;
  late String _selectedDistrict;
  bool _notifyAlerts = true;
  bool _offlineMode = false;
  bool _highQualityImage = true;

  final List<String> districts = [
    'Anuradhapura',
    'Polonnaruwa',
    'Kurunegala',
    'Hambantota',
    'Ampara',
    'Gampaha',
    'Colombo',
    'Kandy',
  ];

  @override
  void initState() {
    super.initState();
    _apiKeyController = TextEditingController();
    _usernameController = TextEditingController(text: widget.supervisor.username);
    _selectedDistrict = widget.supervisor.district.isNotEmpty ? widget.supervisor.district : 'Anuradhapura';
    _loadSettings();
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _apiKeyController.text = prefs.getString('gemini_api_key') ?? GeminiService.defaultKey;
      _notifyAlerts = prefs.getBool('settings_notify_alerts') ?? true;
      _offlineMode = prefs.getBool('settings_offline_mode') ?? false;
      _highQualityImage = prefs.getBool('settings_high_quality') ?? true;
    });
  }

  Future<void> _saveSetting(String key, dynamic value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value is bool) {
      await prefs.setBool(key, value);
    } else if (value is String) {
      await prefs.setString(key, value);
    }
  }

  Future<void> _saveProfileChanges() async {
    final username = _usernameController.text.trim();
    if (username.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Username cannot be empty')),
      );
      return;
    }

    try {
      final response = await http.put(
        Uri.parse('http://192.168.8.184:8000/api/update-profile/${widget.supervisor.id}'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': username,
          'district': _selectedDistrict,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        final updatedSupervisor = Supervisor.fromJson(data['user'] ?? data);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('supervisor', jsonEncode(updatedSupervisor.toJson()));
        
        // Handle topic change
        if (widget.supervisor.district != updatedSupervisor.district) {
          final messaging = FirebaseMessaging.instance;
          if (widget.supervisor.district.isNotEmpty) {
            await messaging.unsubscribeFromTopic('district_${widget.supervisor.district.replaceAll(' ', '_')}');
          }
          if (updatedSupervisor.district.isNotEmpty) {
            await messaging.subscribeToTopic('district_${updatedSupervisor.district.replaceAll(' ', '_')}');
          }
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Profile updated successfully on the server! Restart the app to apply changes fully.'),
              backgroundColor: AppColors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(data['message'] ?? 'Failed to update profile on server.'),
              backgroundColor: AppColors.danger,
            ),
          );
        }
      }
    } catch (e) {
      final updatedSupervisor = Supervisor(
        id: widget.supervisor.id,
        username: username,
        email: widget.supervisor.email,
        district: _selectedDistrict,
      );
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('supervisor', jsonEncode(updatedSupervisor.toJson()));
      
      // Handle topic change locally
      if (widget.supervisor.district != updatedSupervisor.district) {
        try {
          final messaging = FirebaseMessaging.instance;
          if (widget.supervisor.district.isNotEmpty) {
            await messaging.unsubscribeFromTopic('district_${widget.supervisor.district.replaceAll(' ', '_')}');
          }
          if (updatedSupervisor.district.isNotEmpty) {
            await messaging.subscribeToTopic('district_${updatedSupervisor.district.replaceAll(' ', '_')}');
          }
        } catch (_) {}
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Saved locally (Server offline). Restart the app to apply changes fully.'),
            backgroundColor: AppColors.warn,
          ),
        );
      }
    }
  }

  Future<void> _handleLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout', style: TextStyle(fontFamily: 'DM Serif Display')),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Logout', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('supervisor');
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      }
    }
  }

  Future<void> _handleResetAllScanData() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset All Scan Data', style: TextStyle(fontFamily: 'DM Serif Display')),
        content: const Text('Warning: This will delete all scan reports from the database. This action is irreversible. Are you sure?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Reset', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() {
        _reports.clear();
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All scan report records cleared successfully.')),
        );
      }
    }
  }

  final Map<String, Color> diseaseColors = {
    'Blast': const Color(0xFFF97316),
    'Sheath Blight': AppColors.warn,
    'Brown Spot': const Color(0xFFA0522D),
    'Tungro': const Color(0xFF8B5CF6),
    'Healthy': AppColors.greenL,
    'Bacterial Blight': AppColors.danger,
    'Bacterialblight': AppColors.danger,
    'Sheath_blight': AppColors.warn,
    'Brownspot': const Color(0xFFA0522D),
    'Others': AppColors.sub,
  };

  @override
  Widget build(BuildContext context) {
    if (_subPage == 'analytics') return _buildAnalyticsScreen();
    if (_subPage == 'reports') return _buildReportsScreen();
    if (_subPage == 'settings') return _buildSettingsScreen();
    if (_subPage == 'help') return _buildHelpScreen();
    return _buildMenuScreen();
  }

  Widget _buildMenuScreen() {
    final items = [
      {'icon': '📊', 'label': 'Analytics', 'desc': 'Disease trends & district stats', 'page': 'analytics'},
      {'icon': '📄', 'label': 'Reports', 'desc': 'Download farmer PDF reports', 'page': 'reports'},
      {'icon': '⚙️', 'label': 'Settings', 'desc': 'App preferences & API keys', 'page': 'settings'},
      {'icon': '❓', 'label': 'Help', 'desc': 'User guide & support info', 'page': 'help'},
      {'icon': '🚪', 'label': 'Logout', 'desc': 'Sign out of your account', 'page': 'logout'},
    ];

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const TopBar(title: 'More'),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 100),
                child: ListView.separated(
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return CardWidget(
                      onTap: () async {
                        if (item['page'] == 'logout') {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Logout', style: TextStyle(fontFamily: 'DM Serif Display')),
                              content: const Text('Are you sure you want to sign out?'),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                                TextButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  child: const Text('Logout', style: TextStyle(color: AppColors.danger)),
                                ),
                              ],
                            ),
                          );

                          if (confirm == true) {
                            final prefs = await SharedPreferences.getInstance();
                            await prefs.remove('supervisor');
                            if (mounted) {
                              Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
                                MaterialPageRoute(builder: (_) => const LoginScreen()),
                                (route) => false,
                              );
                            }
                          }
                        } else {
                          setState(() => _subPage = item['page'] as String);
                          if (item['page'] == 'reports' || item['page'] == 'analytics') {
                            _fetchReports();
                          }
                        }
                      },
                      child: Row(
                        children: [
                          Container(
                            width: 46,
                            height: 46,
                            decoration: BoxDecoration(
                              color: AppColors.greenPale,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Center(child: Text(item['icon'] as String, style: const TextStyle(fontSize: 22))),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(item['label'] as String, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                                const SizedBox(height: 2),
                                Text(item['desc'] as String, style: const TextStyle(fontSize: 12, color: AppColors.sub)),
                              ],
                            ),
                          ),
                          const Text('›', style: TextStyle(fontSize: 22, color: AppColors.sub)),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnalyticsScreen() {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            TopBar(title: 'Analytics', onBack: () => setState(() => _subPage = 'menu')),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 100),
                child: Column(
                  children: [
                    Text(
                      'Disease distribution · ${widget.supervisor.district} District',
                      style: const TextStyle(fontSize: 13, color: AppColors.sub),
                    ),
                    const SizedBox(height: 18),
                    CardWidget(
                      child: Column(
                        children: [
                          const Text(
                            'Disease Breakdown',
                            style: TextStyle(fontFamily: 'DM Serif Display', fontSize: 18, color: AppColors.text),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'All farmers · All scans',
                            style: TextStyle(fontSize: 12, color: AppColors.sub),
                          ),
                          const SizedBox(height: 18),
                          if (_isLoadingReports && analytics.isEmpty)
                            const Center(child: Padding(
                              padding: EdgeInsets.all(20.0),
                              child: CircularProgressIndicator(),
                            ))
                          else if (analytics.isEmpty)
                            const Center(child: Padding(
                              padding: EdgeInsets.all(20.0),
                              child: Text('No data recorded yet', style: TextStyle(color: AppColors.sub)),
                            ))
                          else ...[
                            _buildPieChart(),
                            const SizedBox(height: 16),
                            Wrap(
                              spacing: 16,
                              runSpacing: 8,
                              alignment: WrapAlignment.center,
                              children: analytics.map((d) {
                                return Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 10,
                                      height: 10,
                                      decoration: BoxDecoration(
                                        color: d['color'] as Color,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      '${d['name']} ${d['value']}%',
                                      style: const TextStyle(fontSize: 12, color: AppColors.sub),
                                    ),
                                  ],
                                );
                              }).toList(),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'By Disease Type',
                        style: TextStyle(fontFamily: 'DM Serif Display', fontSize: 18, color: AppColors.text),
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (analytics.isEmpty && !_isLoadingReports)
                      CardWidget(child: Center(child: Text('Add scans to see disease breakdown', style: TextStyle(color: AppColors.sub))))
                    else
                      ...analytics.map((d) => _buildDiseaseTile(d)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPieChart() {
    final total = analytics.fold(0, (sum, item) => sum + (item['value'] as int));
    var startAngle = -pi / 2;
    final size = 180.0;
    final center = Offset(size / 2, size / 2);

    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _PieChartPainter(analytics, total.toDouble(), startAngle),
      ),
    );
  }

  Widget _buildDiseaseTile(Map<String, dynamic> d) {
    final rec = diseaseRecs[d['name']];
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: CardWidget(
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: d['color'] as Color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    d['name'] as String,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: AppColors.text),
                  ),
                ),
                Text(
                  '${d['value']}%',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: d['color'] as Color),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              height: 8,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(6),
              ),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: (d['value'] as int) / 100,
                child: Container(
                  decoration: BoxDecoration(
                    color: d['color'] as Color,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ),
            ),
            if (d['name'] != 'Healthy' && rec != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  children: [
                    const Text('💊 ', style: TextStyle(fontSize: 14)),
                    Expanded(
                      child: Text(
                        rec.ferts[0],
                        style: const TextStyle(fontSize: 12, color: AppColors.sub, fontWeight: FontWeight.w500),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _fetchReports() async {
    setState(() => _isLoadingReports = true);
    final results = await DiseaseService().getSupervisorReports(widget.supervisor.id);
    if (mounted) {
      setState(() {
        _reports = results;
        _isLoadingReports = false;
        _calculateAnalytics();
      });
    }
  }

  void _calculateAnalytics() {
    if (_reports.isEmpty) {
      setState(() => analytics = []);
      return;
    }

    final Map<String, int> counts = {};
    for (var report in _reports) {
      // Canonical Normalization: Ensure 'Bacterialblight' and 'Bacterial Blight' are merged
      String name = report.diseaseName.replaceAll('_', ' ').toLowerCase();
      // Remove extra spaces if any
      name = name.replaceAll(RegExp(r'\s+'), ' ').trim();
      
      // Map common variants to canonical names
      if (name == 'bacterialblight') name = 'bacterial blight';
      if (name == 'brownspot') name = 'brown spot';
      if (name == 'sheathblight') name = 'sheath blight';
      
      // Capitalize each word for display
      name = name.split(' ').map((word) {
        if (word.isEmpty) return word;
        return word[0].toUpperCase() + word.substring(1);
      }).join(' ');
      
      counts[name] = (counts[name] ?? 0) + 1;
    }

    final total = _reports.length;
    final List<Map<String, dynamic>> newAnalytics = [];

    counts.forEach((name, count) {
      newAnalytics.add({
        'name': name,
        'value': ((count / total) * 100).round(),
        'color': diseaseColors[name] ?? _getFallbackColor(name),
      });
    });

    // Sort by value descending
    newAnalytics.sort((a, b) => (b['value'] as int).compareTo(a['value'] as int));

    setState(() {
      analytics = newAnalytics;
    });
  }

  Color _getFallbackColor(String name) {
    if (diseaseColors.containsKey(name)) return diseaseColors[name]!;
    return _generateColor(name);
  }

  Color _generateColor(String name) {
    final List<Color> extraPalette = [
      const Color(0xFF0EA5E9), // Sky Blue
      const Color(0xFFD946EF), // Fuchsia
      const Color(0xFF14B8A6), // Teal
      const Color(0xFF6366F1), // Indigo
      const Color(0xFFF43F5E), // Rose
    ];
    return extraPalette[name.hashCode.abs() % extraPalette.length];
  }

  Widget _buildReportsScreen() {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            TopBar(title: 'Reports', onBack: () => setState(() => _subPage = 'menu')),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 100),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CardWidget(
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: AppColors.greenPale,
                                  borderRadius: BorderRadius.circular(15),
                                ),
                                child: const Center(child: Text('📄', style: TextStyle(fontSize: 22))),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Full District Report',
                                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                                    ),
                                    Text(
                                      '${_reports.length} records · ${widget.supervisor.district}',
                                      style: const TextStyle(fontSize: 12, color: AppColors.sub),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          ButtonWidget(
                            variant: 'green',
                            icon: '⬇️',
                            text: _generating ? 'Generating PDF...' : 'Download PDF Report',
                            onPressed: () async {
                              if (_reports.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('No reports to download')),
                                );
                                return;
                              }
                              setState(() => _generating = true);
                              await DiseaseService().generatePdfReport(
                                _reports, 
                                widget.supervisor.district, 
                                widget.supervisor.username
                              );
                              if (mounted) {
                                setState(() => _generating = false);
                              }
                            },
                            disabled: _generating || _isLoadingReports,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Scan History',
                      style: TextStyle(fontFamily: 'DM Serif Display', fontSize: 20, color: AppColors.text),
                    ),
                    const SizedBox(height: 12),
                    if (_isLoadingReports)
                      const Center(child: Padding(
                        padding: EdgeInsets.all(40.0),
                        child: CircularProgressIndicator(),
                      ))
                    else if (_reports.isEmpty)
                      CardWidget(
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32.0),
                            child: Column(
                              children: [
                                const Text('📭', style: TextStyle(fontSize: 40)),
                                const SizedBox(height: 12),
                                const Text('No scan reports found for your account.', style: TextStyle(color: AppColors.sub)),
                              ],
                            ),
                          ),
                        ),
                      )
                    else
                      CardWidget(
                        padding: EdgeInsets.zero,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            headingRowColor: MaterialStateProperty.all(AppColors.bg),
                            columnSpacing: 20,
                            dataRowHeight: 80,
                            columns: const [
                              DataColumn(label: Text('ID', style: TextStyle(fontWeight: FontWeight.w700))),
                              DataColumn(label: Text('Photo', style: TextStyle(fontWeight: FontWeight.w700))),
                              DataColumn(label: Text('Farmer', style: TextStyle(fontWeight: FontWeight.w700))),
                              DataColumn(label: Text('Disease', style: TextStyle(fontWeight: FontWeight.w700))),
                              DataColumn(label: Text('Date', style: TextStyle(fontWeight: FontWeight.w700))),
                              DataColumn(label: Text('Note', style: TextStyle(fontWeight: FontWeight.w700))),
                              DataColumn(label: Text('Solutions', style: TextStyle(fontWeight: FontWeight.w700))),
                            ],
                            rows: _reports.map((report) {
                              return DataRow(cells: [
                                DataCell(Text('#${report.reportId}')),
                                DataCell(
                                  Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.network(
                                        report.diseaseImage,
                                        width: 50,
                                        height: 50,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => Container(
                                          width: 50,
                                          height: 50,
                                          color: AppColors.border,
                                          child: const Icon(Icons.broken_image, size: 20, color: AppColors.sub),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                DataCell(
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(report.farmerName, style: const TextStyle(fontWeight: FontWeight.w600)),
                                      Text('ID: ${report.farmerId ?? 'N/A'}', style: const TextStyle(fontSize: 11, color: AppColors.sub)),
                                    ],
                                  ),
                                ),
                                DataCell(Text(report.diseaseName)),
                                DataCell(Text(report.createdAt.split('T').first)),
                                DataCell(
                                  SizedBox(
                                    width: 120,
                                    child: Text(
                                      report.customerNote ?? '-',
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  ),
                                ),
                                DataCell(
                                  GestureDetector(
                                    onTap: () {
                                      showModalBottomSheet(
                                        context: context,
                                        isScrollControlled: true,
                                        shape: const RoundedRectangleBorder(
                                          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                                        ),
                                        builder: (_) => DraggableScrollableSheet(
                                          initialChildSize: 0.5,
                                          minChildSize: 0.3,
                                          maxChildSize: 0.85,
                                          expand: false,
                                          builder: (_, scrollController) => Padding(
                                            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                                            child: ListView(
                                              controller: scrollController,
                                              children: [
                                                Center(
                                                  child: Container(
                                                    width: 40,
                                                    height: 4,
                                                    margin: const EdgeInsets.only(bottom: 16),
                                                    decoration: BoxDecoration(
                                                      color: AppColors.border,
                                                      borderRadius: BorderRadius.circular(4),
                                                    ),
                                                  ),
                                                ),
                                                Text(
                                                  '💊 Solutions for ${report.diseaseName}',
                                                  style: const TextStyle(
                                                    fontFamily: 'DM Serif Display',
                                                    fontSize: 18,
                                                    color: AppColors.text,
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  'Farmer: ${report.farmerName}  ·  ${report.createdAt.split('T').first}',
                                                  style: const TextStyle(fontSize: 12, color: AppColors.sub),
                                                ),
                                                const SizedBox(height: 16),
                                                ...report.recommendSolutions
                                                    .split('\n')
                                                    .where((s) => s.trim().isNotEmpty)
                                                    .map((s) => Padding(
                                                          padding: const EdgeInsets.only(bottom: 10),
                                                          child: Row(
                                                            crossAxisAlignment: CrossAxisAlignment.start,
                                                            children: [
                                                              Container(
                                                                margin: const EdgeInsets.only(top: 6),
                                                                width: 8,
                                                                height: 8,
                                                                decoration: const BoxDecoration(
                                                                  color: AppColors.greenL,
                                                                  shape: BoxShape.circle,
                                                                ),
                                                              ),
                                                              const SizedBox(width: 10),
                                                              Expanded(
                                                                child: Text(
                                                                  s.replaceAll('•', '').trim(),
                                                                  style: const TextStyle(fontSize: 14, height: 1.5),
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        )),
                                              ],
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 8),
                                      child: SizedBox(
                                        width: 220,
                                        child: Text(
                                          report.recommendSolutions,
                                          style: const TextStyle(fontSize: 11, height: 1.4),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ]);
                            }).toList(),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsScreen() {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            TopBar(title: 'Settings', onBack: () => setState(() => _subPage = 'menu')),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 100),
                children: [
                  CardWidget(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Supervisor Profile',
                          style: TextStyle(fontFamily: 'DM Serif Display', fontSize: 20, color: AppColors.text),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'USERNAME',
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11, color: AppColors.sub),
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _usernameController,
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: const Color(0xFFEFE6D9),
                            prefixIcon: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF2EBE1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.person, color: Color(0xFF5D4037), size: 20),
                              ),
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'DISTRICT',
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11, color: AppColors.sub),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFE6D9),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          child: Row(
                            children: [
                              Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF2EBE1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.location_on, color: Colors.pink, size: 20),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: _selectedDistrict,
                                    items: districts.map((String value) {
                                      return DropdownMenuItem<String>(
                                        value: value,
                                        child: Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                                      );
                                    }).toList(),
                                    onChanged: (String? newValue) {
                                      if (newValue != null) {
                                        setState(() {
                                          _selectedDistrict = newValue;
                                        });
                                      }
                                    },
                                    icon: const Icon(Icons.arrow_drop_down, color: Colors.black54),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          child: TextButton(
                            onPressed: _saveProfileChanges,
                            style: TextButton.styleFrom(
                              backgroundColor: const Color(0xFF2E5A36), // Dark green
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                            child: const Text(
                              'Save Changes',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileRow(String label, String value, String icon) {
    return Row(
      children: [
        Text(icon, style: const TextStyle(fontSize: 18)),
        const SizedBox(width: 12),
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        const Spacer(),
        Text(value, style: const TextStyle(color: AppColors.sub, fontSize: 14)),
      ],
    );
  }

  Widget _buildSwitchRow(String title, String subtitle, bool val, ValueChanged<bool> onChanged) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              const SizedBox(height: 2),
              Text(subtitle, style: const TextStyle(fontSize: 11, color: AppColors.sub)),
            ],
          ),
        ),
        Switch(
          value: val,
          onChanged: onChanged,
          activeColor: AppColors.greenL,
          activeTrackColor: AppColors.greenPale,
        ),
      ],
    );
  }

  Widget _buildHelpScreen() {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            TopBar(title: 'Help & Support', onBack: () => setState(() => _subPage = 'menu')),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 100),
                children: [
                  CardWidget(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'About Rice Guard',
                          style: TextStyle(
                            fontFamily: 'DM Serif Display', 
                            fontSize: 18, 
                            color: AppColors.text, 
                            fontWeight: FontWeight.bold
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Rice Guard is an advanced AI-powered assistant built for agricultural supervisors. Our goal is to protect your yield by providing instant, accurate detection of devastating rice diseases such as Blast, Sheath Blight, and Brown Spot directly from your smartphone.',
                          style: TextStyle(fontSize: 13, color: AppColors.sub, height: 1.5),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  CardWidget(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'How to Setup',
                          style: TextStyle(
                            fontFamily: 'DM Serif Display', 
                            fontSize: 18, 
                            color: AppColors.text, 
                            fontWeight: FontWeight.bold
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildNumberedStep('1', 'Create your supervisor account and select your designated district.'),
                        const SizedBox(height: 14),
                        _buildNumberedStep('2', 'Grant camera permissions when prompted so the app can analyze leaves.'),
                        const SizedBox(height: 14),
                        _buildNumberedStep('3', 'Start adding the farmers you supervise in the \'Farmers\' tab.'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  CardWidget(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'How to Use the App',
                          style: TextStyle(
                            fontFamily: 'DM Serif Display', 
                            fontSize: 18, 
                            color: AppColors.text, 
                            fontWeight: FontWeight.bold
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Home',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.text),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'View a quick summary of recent scans and district status.',
                          style: TextStyle(fontSize: 13, color: AppColors.sub, height: 1.4),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Farmers',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.text),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Manage your list of farmers. Tap any farmer to view their detailed profile, past scans, and farm area.',
                          style: TextStyle(fontSize: 13, color: AppColors.sub, height: 1.4),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Scan',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.text),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Tap the central microscope button to take a photo of an affected rice leaf. The AI will analyze it and provide an immediate diagnosis and treatment plan.',
                          style: TextStyle(fontSize: 13, color: AppColors.sub, height: 1.4),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNumberedStep(String number, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: const BoxDecoration(
            color: Color(0xFFE6F4EA), // Light green circle
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              number,
              style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF137333), fontSize: 13),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 13, color: AppColors.sub, height: 1.4),
          ),
        ),
      ],
    );
  }
}

class _PieChartPainter extends CustomPainter {
  final List<Map<String, dynamic>> data;
  final double total;
  double startAngle;

  _PieChartPainter(this.data, this.total, this.startAngle);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    for (var item in data) {
      final sweepAngle = (item['value'] as int) / total * 2 * pi;
      
      // Draw slice
      final paint = Paint()
        ..color = item['color'] as Color
        ..style = PaintingStyle.fill;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        true,
        paint,
      );

      // Draw white divider
      final borderPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        true,
        borderPaint,
      );

      startAngle += sweepAngle;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}