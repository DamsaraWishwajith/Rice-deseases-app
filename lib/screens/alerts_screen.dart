import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../widgets/card_widget.dart';
import '../widgets/top_bar.dart';
import '../widgets/tag_widget.dart';
import '../models/alert.dart';
import '../models/supervisor.dart';
import '../models/disease_rec.dart';

final List<Alert> initialAlerts = [
  Alert(id: 1, farmer: "Kamal Perera", disease: "Blast", severity: "High", time: "2h ago", read: false),
  Alert(id: 2, farmer: "Nimal Silva", disease: "Sheath Blight", severity: "Medium", time: "1d ago", read: false),
  Alert(id: 3, farmer: "Sunil Fernando", disease: "Brown Spot", severity: "Low", time: "3d ago", read: true),
];

class AlertsScreen extends StatefulWidget {
  final Supervisor supervisor;

  const AlertsScreen({super.key, required this.supervisor});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  late List<Alert> _alerts;

  @override
  void initState() {
    super.initState();
    _alerts = List.from(initialAlerts);
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
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 100),
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
                      child: ListView.separated(
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
                            },
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    TagWidget(text: alert.severity, color: severityColor),
                                    if (!alert.read)
                                      Container(
                                        width: 8,
                                        height: 8,
                                        margin: const EdgeInsets.only(left: 8),
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
}