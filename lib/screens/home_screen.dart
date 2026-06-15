import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../main.dart';
import 'alerts_screen.dart';
import 'alert_detail_screen.dart';
import 'farmers_screen.dart';
import 'more_screen.dart';
import 'scan_screen.dart';
import '../theme/app_colors.dart';
import '../widgets/card_widget.dart';
import '../widgets/tag_widget.dart';
import '../models/supervisor.dart';
import '../models/farmer.dart';
import '../models/alert.dart';
import '../models/disease_rec.dart';
import '../services/disease_service.dart';
import '../models/disease_report.dart';



class HomeScreen extends StatefulWidget {
  final Supervisor supervisor;

  const HomeScreen({super.key, required this.supervisor});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  late PageController _pageController;
  List<Farmer> _farmers = [];
  bool _isLoadingFarmers = true;
  String _farmersError = '';
  int _scanCount = 0;
  bool _isLoadingReports = true;
  List<Alert> _alerts = [];
  bool _isLoadingAlerts = true;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _selectedIndex);
    _fetchFarmers();
    _fetchReportsCount();
    _fetchAlerts();
    // Pre-initialize AI model for faster first scan
    DiseaseService().initModel();
    _setupFirebaseMessaging();
  }

  Future<void> _setupFirebaseMessaging() async {
    try {
      final messaging = FirebaseMessaging.instance;
      
      if (widget.supervisor.district.isNotEmpty) {
        final topic = 'district_${widget.supervisor.district.replaceAll(' ', '_')}';
        await messaging.subscribeToTopic(topic);
        print('FCM: Subscribed to district topic: $topic');
      }

      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        if (message.notification != null) {
          final notification = message.notification!;
          
          // Trigger a native system notification banner at the top of the screen
          flutterLocalNotificationsPlugin.show(
            notification.hashCode,
            notification.title,
            notification.body,
            NotificationDetails(
              android: AndroidNotificationDetails(
                channel.id,
                channel.name,
                channelDescription: channel.description,
                icon: '@mipmap/ic_launcher',
                importance: Importance.max,
                priority: Priority.high,
              ),
            ),
          );

          // Refresh the alerts and counts dynamically
          _fetchAlerts();
          _fetchReportsCount();
        }
      });
    } catch (e) {
      print('FCM setup error: $e');
    }
  }

  Future<void> _fetchFarmers() async {
    setState(() {
      _isLoadingFarmers = true;
      _farmersError = '';
    });

    try {
      final response = await http
          .get(
            Uri.parse('http://192.168.8.184:8000/api/farmers'),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final dynamic decoded = jsonDecode(response.body);
        List<dynamic> data;
        if (decoded is List) {
          data = decoded;
        } else if (decoded is Map && decoded['data'] is List) {
          data = decoded['data'];
        } else if (decoded is Map && decoded['farmers'] is List) {
          data = decoded['farmers'];
        } else {
          data = [];
        }

        if (!mounted) return;
        setState(() {
          _farmers = data
              .map((f) => Farmer.fromJson(f))
              .where((f) =>
                  f.district.toLowerCase() ==
                  widget.supervisor.district.toLowerCase())
              .toList();
          _isLoadingFarmers = false;
        });
      } else {
        if (!mounted) return;
        setState(() {
          _farmersError =
              'Failed to load farmers (Status: ${response.statusCode})';
          _isLoadingFarmers = false;
        });
      }
    } catch (e) {
      String msg = 'Connection error. Is server running?';
      if (e.toString().contains('TimeoutException')) {
        msg = 'Connection timed out. Check your IP/Network.';
      }
      if (!mounted) return;
      setState(() {
        _farmersError = msg;
        _isLoadingFarmers = false;
      });
    }
  }

  Future<void> _fetchReportsCount() async {
    if (!mounted) return;
    setState(() => _isLoadingReports = true);

    try {
      // Use a slightly longer timeout locally than the service, or just trust the service
      // But we'll add a safety catch to ensure _isLoadingReports is ALWAYS false eventually.
      final List<DiseaseReport> reports = await DiseaseService()
          .getSupervisorReports(widget.supervisor.id)
          .timeout(const Duration(seconds: 12), onTimeout: () => []);

      if (!mounted) return;
      setState(() {
        _scanCount = reports.length;
        _isLoadingReports = false;
      });
    } catch (e) {
      debugPrint('HomeScreen stats fetch error: $e');
      if (!mounted) return;
      setState(() {
        _isLoadingReports = false;
        // Optionally keep _scanCount at previous value or 0
      });
    }
  }

  Future<void> _fetchAlerts() async {
    if (!mounted) return;
    setState(() => _isLoadingAlerts = true);

    try {
      final response = await http.post(
        Uri.parse('http://192.168.8.184:8000/api/get-district-alerts'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'supervisor_id': widget.supervisor.id,
        }),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> result = jsonDecode(response.body);
        if (result['success'] == true) {
          final List<dynamic> alertData = result['data'];
          if (!mounted) return;
          setState(() {
            _alerts = alertData.map((json) => Alert(
              id: json['id'],
              farmer: json['farmer'],
              disease: json['disease'],
              severity: json['severity'],
              time: json['time'],
              read: json['read'] ?? false,
              image: json['image'],
              note: json['note'],
              solutions: json['solutions'],
              district: json['district'],
            )).toList();
            _isLoadingAlerts = false;
          });
        }
      } else {
        if (!mounted) return;
        setState(() => _isLoadingAlerts = false);
      }
    } catch (e) {
      debugPrint('HomeScreen alerts fetch error: $e');
      if (!mounted) return;
      setState(() => _isLoadingAlerts = false);
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final unreadCount = _alerts.where((a) => !a.read).length;
    final name = widget.supervisor.username
        .replaceAll('_', ' ')
        .split(' ')
        .map((e) => e.isNotEmpty
            ? e[0].toUpperCase() + e.substring(1).toLowerCase()
            : e)
        .join(' ');

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: PageView(
        controller: _pageController,
        onPageChanged: (index) {
          setState(() => _selectedIndex = index);
        },
        physics: const NeverScrollableScrollPhysics(),
        children: [
          _buildHomeContent(name, unreadCount),
          FarmersScreen(
              farmers: _farmers,
              supervisor: widget.supervisor,
              onRefresh: _fetchFarmers),
          ScanScreen(farmers: _farmers, supervisor: widget.supervisor),
          AlertsScreen(supervisor: widget.supervisor),
          MoreScreen(farmers: _farmers, supervisor: widget.supervisor),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildHomeContent(String name, int unreadCount) {
    return Column(
      children: [
        _buildHeader(name, unreadCount),
        Expanded(
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 100, top: 20),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: _buildQuickScanCard(),
                  ),
                  const SizedBox(height: 28),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: _buildRecentAlerts(),
                  ),
                  const SizedBox(height: 28),
                  _buildFarmersSection(),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(String name, int unreadCount) {
    final topPadding = MediaQuery.of(context).padding.top;
    return Container(
      padding: EdgeInsets.fromLTRB(20, topPadding + 15, 20, 25),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.forest, AppColors.green],
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.forest.withOpacity(0.15),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Good morning 👋',
                      style: TextStyle(
                          color: Colors.white70,
                          fontSize: 16,
                          letterSpacing: 0.3),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      name,
                      style: const TextStyle(
                        fontFamily: 'DM Serif Display',
                        color: Colors.white,
                        fontSize: 32,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '📍  ${widget.supervisor.district} District',
                      style: const TextStyle(
                          color: Colors.white60,
                          fontSize: 16,
                          letterSpacing: 0.2),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () => _pageController.jumpToPage(3),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Stack(
                    children: [
                      const Center(
                          child: Text('🔔', style: TextStyle(fontSize: 22))),
                      if (unreadCount > 0)
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: AppColors.accent,
                              shape: BoxShape.circle,
                              border:
                                  Border.all(color: AppColors.forest, width: 2),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 25),
          Row(
            children: [
              _buildStatCard(
                  '👤',
                  _isLoadingFarmers ? '...' : _farmers.length.toString(),
                  'Farmers',
                  onTap: () => _pageController.jumpToPage(1)),
              const SizedBox(width: 12),
              _buildStatCard('🔬',
                  _isLoadingReports ? '...' : _scanCount.toString(), 'Scans',
                  onTap: () => _pageController.jumpToPage(2)),
              const SizedBox(width: 12),
              _buildStatCard(
                  '⚠️',
                  _isLoadingAlerts ? '...' : _alerts.length.toString(),
                  'Alerts',
                  color: AppColors.accent,
                  onTap: () => _pageController.jumpToPage(3)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String icon, String value, String label,
      {Color? color, VoidCallback? onTap}) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.12),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
          ),
          child: Column(
            children: [
              Text(icon, style: TextStyle(fontSize: 22, color: color)),
              const SizedBox(height: 8),
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.6),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickScanCard() {
    return GestureDetector(
      onTap: () => _pageController.jumpToPage(2),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.accent, const Color(0xFFF5C040)],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: AppColors.accent.withOpacity(0.35),
              blurRadius: 32,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'QUICK ACTION',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Scan Rice Leaf',
                    style: TextStyle(
                      fontFamily: 'DM Serif Display',
                      color: Colors.white,
                      fontSize: 24,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Detect disease instantly →',
                    style: TextStyle(color: Colors.white70, fontSize: 16),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.only(left: 12),
              child: const Text('🌿', style: TextStyle(fontSize: 64)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentAlerts() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Recent Alerts',
              style: TextStyle(
                fontFamily: 'DM Serif Display',
                fontSize: 22,
                color: AppColors.text,
              ),
            ),
            GestureDetector(
              onTap: () => _pageController.jumpToPage(3),
              child: const Text(
                'See all',
                style: TextStyle(
                    color: AppColors.green,
                    fontSize: 13,
                    fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_isLoadingAlerts)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(20.0),
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.forest),
              ),
            ),
          )
        else if (_alerts.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Center(
              child: Text(
                'No alerts in your district yet.',
                style: TextStyle(color: AppColors.sub, fontSize: 14),
              ),
            ),
          )
        else
          ..._alerts.take(2).map((alert) => _buildAlertCard(alert)),
      ],
    );
  }

  Widget _buildAlertCard(Alert alert) {
    final rec = diseaseRecs[alert.disease] ?? diseaseRecs['Healthy']!;
    Color severityColor = alert.severity == 'High'
        ? AppColors.danger
        : alert.severity == 'Medium'
            ? AppColors.warn
            : AppColors.greenL;

    return CardWidget(
      onTap: () {
        setState(() {
          final idx = _alerts.indexWhere((a) => a.id == alert.id);
          if (idx != -1) {
            _alerts[idx] = alert.copyWith(read: true);
          }
        });
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AlertDetailScreen(alert: alert.copyWith(read: true)),
          ),
        );
      },
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: severityColor.withOpacity(0.09),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
                child: Text(rec.icon, style: const TextStyle(fontSize: 20))),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${alert.disease} detected',
                  style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                      color: AppColors.text),
                ),
                const SizedBox(height: 2),
                Text(
                  '${alert.farmer} · ${alert.time}',
                  style: const TextStyle(fontSize: 14, color: AppColors.sub),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFarmersSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'My Farmers',
                style: TextStyle(
                  fontFamily: 'DM Serif Display',
                  fontSize: 22,
                  color: AppColors.text,
                ),
              ),
              GestureDetector(
                onTap: () => _pageController.jumpToPage(1),
                child: const Text(
                  'See all',
                  style: TextStyle(
                      color: AppColors.green,
                      fontSize: 13,
                      fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_isLoadingFarmers)
            const Center(
                child: Padding(
              padding: EdgeInsets.all(20.0),
              child: CircularProgressIndicator(),
            ))
          else if (_farmersError.isNotEmpty)
            Center(
                child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Text(_farmersError,
                  style: const TextStyle(color: AppColors.danger)),
            ))
          else if (_farmers.isEmpty)
            const Center(
                child: Padding(
              padding: EdgeInsets.all(20.0),
              child: Text('No farmers added yet.',
                  style: TextStyle(color: AppColors.sub)),
            ))
          else
            SizedBox(
              height: 145,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _farmers.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final farmer = _farmers[index];
                  final rec =
                      diseaseRecs[farmer.disease] ?? diseaseRecs['Healthy']!;
                  return Container(
                    width: 128,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: AppColors.border.withOpacity(0.6), width: 0.8),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.forest.withOpacity(0.04),
                          blurRadius: 24,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: AppColors.greenPale,
                            borderRadius: BorderRadius.circular(11),
                          ),
                          child: const Center(
                              child:
                                  Text('👤', style: TextStyle(fontSize: 16))),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          farmer.name.split(' ').first,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                              color: AppColors.text),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          farmer.variety,
                          style: const TextStyle(
                              fontSize: 13, color: AppColors.sub),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                        const SizedBox(height: 8),
                        TagWidget(text: farmer.disease, color: rec.color),
                      ],
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBottomNav() {
    final tabs = [
      {'id': 0, 'label': 'Home', 'icon': '🏠'},
      {'id': 1, 'label': 'Farmers', 'icon': '👤'},
      {'id': 2, 'label': 'Scan', 'icon': '🔬', 'big': true},
      {'id': 3, 'label': 'Alerts', 'icon': '🔔'},
      {'id': 4, 'label': 'More', 'icon': '⋯'},
    ];

    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        border: Border(
            top:
                BorderSide(color: AppColors.border.withOpacity(0.5), width: 1)),
        boxShadow: [
          BoxShadow(
            color: AppColors.forest.withOpacity(0.06),
            blurRadius: 24,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: tabs.map((tab) {
          final isSelected = _selectedIndex == tab['id'];
          final isBig = tab['big'] == true;

          return Expanded(
            child: GestureDetector(
              onTap: () {
                _pageController.jumpToPage(tab['id'] as int);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isBig)
                      Transform.translate(
                        offset: const Offset(0, -22),
                        child: Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: AppColors.forest,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.forest.withOpacity(0.45),
                                blurRadius: 18,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Center(
                              child:
                                  Text('🔬', style: TextStyle(fontSize: 22))),
                        ),
                      )
                    else
                      Opacity(
                        opacity: isSelected ? 1.0 : 0.38,
                        child: Text(tab['icon'] as String,
                            style: const TextStyle(fontSize: 21)),
                      ),
                    if (!isBig) ...[
                      const SizedBox(height: 3),
                      Text(
                        tab['label'] as String,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight:
                              isSelected ? FontWeight.w700 : FontWeight.w400,
                          color: isSelected ? AppColors.green : AppColors.sub,
                        ),
                      ),
                    ],
                    if (isSelected && !isBig)
                      Container(
                        width: 18,
                        height: 3,
                        margin: const EdgeInsets.only(top: 4),
                        decoration: BoxDecoration(
                          color: AppColors.green,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
