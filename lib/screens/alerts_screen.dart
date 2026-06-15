import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../theme/app_colors.dart';
import '../widgets/card_widget.dart';
import '../widgets/top_bar.dart';
import '../widgets/tag_widget.dart';
import '../models/alert.dart';
import '../models/supervisor.dart';
import '../models/disease_rec.dart';
import 'alert_detail_screen.dart';

class AlertsScreen extends StatefulWidget {
  final Supervisor supervisor;

  const AlertsScreen({super.key, required this.supervisor});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  List<Alert> _alerts = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchAlerts();
  }

  Future<void> _fetchAlerts() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

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
            _isLoading = false;
          });
        } else {
          setState(() {
            _errorMessage = 'Failed to load alerts';
            _isLoading = false;
          });
        }
      } else {
        setState(() {
          _errorMessage = 'Server error: ${response.statusCode}';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Connection error. Please try again.';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const TopBar(title: 'Alerts'),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(
                        color: AppColors.warnPale,
                        border: Border.all(color: AppColors.warn.withOpacity(0.27)),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          const Text('📢', style: TextStyle(fontSize: 16)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'District Broadcast Active',
                                  style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.warn, fontSize: 13),
                                ),
                                Text(
                                  'Disease detections auto-notify all supervisors in ${widget.supervisor.district}.',
                                  style: const TextStyle(fontSize: 12, color: AppColors.sub),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    Expanded(
                      child: _buildAlertsContent(),
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

  Widget _buildAlertsContent() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(AppColors.forest),
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_errorMessage!, style: const TextStyle(color: AppColors.danger)),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _fetchAlerts,
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.forest),
              child: const Text('Retry', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
    }

    if (_alerts.isEmpty) {
      return RefreshIndicator(
        onRefresh: _fetchAlerts,
        color: AppColors.forest,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(height: MediaQuery.of(context).size.height * 0.2),
            const Center(
              child: Column(
                children: [
                  Text('🌾', style: TextStyle(fontSize: 48)),
                  SizedBox(height: 16),
                  Text(
                    'No alerts in your district yet',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: AppColors.text),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Pull down to refresh',
                    style: TextStyle(fontSize: 13, color: AppColors.sub),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchAlerts,
      color: AppColors.forest,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: _alerts.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final alert = _alerts[index];
          final rec = diseaseRecs[alert.disease] ?? diseaseRecs['Healthy']!;
          Color severityColor = alert.severity == 'High'
              ? AppColors.danger
              : alert.severity == 'Medium'
                  ? AppColors.warn
                  : AppColors.greenL;

          return CardWidget(
            onTap: () {
              setState(() {
                _alerts[index] = alert.copyWith(read: true);
              });
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => AlertDetailScreen(alert: _alerts[index]),
                ),
              );
            },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (!alert.read)
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: AppColors.accent,
                          shape: BoxShape.circle,
                        ),
                      ),
                    const Spacer(),
                    Text(alert.time, style: const TextStyle(fontSize: 14, color: AppColors.sub)),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: severityColor.withOpacity(0.09),
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: Center(child: Text(rec.icon, style: const TextStyle(fontSize: 20))),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            alert.disease,
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: AppColors.text),
                          ),
                          Text(
                            'Farmer: ${alert.farmer}',
                            style: const TextStyle(fontSize: 14, color: AppColors.sub),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: AppColors.bgDeep,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Text('📢', style: TextStyle(fontSize: 14)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'All ${widget.supervisor.district} supervisors notified',
                          style: const TextStyle(fontSize: 12, color: AppColors.sub),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}