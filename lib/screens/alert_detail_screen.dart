import 'package:flutter/material.dart';
import '../models/alert.dart';
import '../models/disease_rec.dart';
import '../theme/app_colors.dart';
import '../widgets/top_bar.dart';
import '../widgets/tag_widget.dart';
import '../widgets/card_widget.dart';
import '../widgets/button_widget.dart';
import 'chat_screen.dart';

class AlertDetailScreen extends StatelessWidget {
  final Alert alert;

  const AlertDetailScreen({super.key, required this.alert});

  @override
  Widget build(BuildContext context) {
    final rec = diseaseRecs[alert.disease] ?? diseaseRecs['Healthy']!;
    final severityColor = alert.severity == 'High'
        ? AppColors.danger
        : alert.severity == 'Medium'
            ? AppColors.warn
            : AppColors.greenL;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            TopBar(
              title: 'Alert Details',
              onBack: () => Navigator.pop(context),
            ),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Crop Photo Section
                    if (alert.image != null && alert.image!.isNotEmpty)
                      Container(
                        height: 220,
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 20),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.forest.withOpacity(0.08),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(24),
                          child: Image.network(
                            alert.image!,
                            fit: BoxFit.cover,
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return Container(
                                color: AppColors.bgDeep,
                                child: const Center(
                                  child: CircularProgressIndicator(
                                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.forest),
                                  ),
                                ),
                              );
                            },
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                color: AppColors.bgDeep,
                                child: const Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.broken_image_outlined, size: 48, color: AppColors.sub),
                                    SizedBox(height: 8),
                                    Text('Failed to load image', style: TextStyle(color: AppColors.sub, fontSize: 13)),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      )
                    else
                      Container(
                        height: 140,
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 20),
                        decoration: BoxDecoration(
                          color: severityColor.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: severityColor.withOpacity(0.15)),
                        ),
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(rec.icon, style: const TextStyle(fontSize: 44)),
                              const SizedBox(height: 8),
                              const Text('No crop image uploaded', style: TextStyle(color: AppColors.sub, fontSize: 13)),
                            ],
                          ),
                        ),
                      ),

                    // Title & Badges
                    Row(
                      children: [
                        TagWidget(text: alert.severity, color: severityColor),
                        const SizedBox(width: 8),
                        if (alert.district != null)
                          TagWidget(text: alert.district!, color: AppColors.forest),
                        const Spacer(),
                        Text(
                          alert.time,
                          style: const TextStyle(fontSize: 14, color: AppColors.sub, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      alert.disease,
                      style: const TextStyle(
                        fontFamily: 'DM Serif Display',
                        fontSize: 28,
                        color: AppColors.text,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Detected by ${alert.farmer}',
                      style: const TextStyle(fontSize: 15, color: AppColors.sub, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 24),

                    // Notes Section
                    const Text(
                      'Farmer Notes',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.text),
                    ),
                    const SizedBox(height: 8),
                    CardWidget(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        (alert.note != null && alert.note!.isNotEmpty)
                            ? alert.note!
                            : 'No notes provided by the farmer.',
                        style: const TextStyle(fontSize: 14, color: AppColors.text, height: 1.4),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Solutions Section
                    const Text(
                      'Recommended Solutions',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.text),
                    ),
                    const SizedBox(height: 8),
                    CardWidget(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(rec.icon, style: const TextStyle(fontSize: 20)),
                              const SizedBox(width: 8),
                              const Expanded(
                                child: Text(
                                  'Standard Treatment Protocol',
                                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.text),
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 24),
                          Text(
                            alert.solutions ?? 'Consult agricultural experts for solutions.',
                            style: const TextStyle(fontSize: 14, color: AppColors.text, height: 1.5),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),

                    // AI Chat Guidance Button
                    ButtonWidget(
                      text: '💬 Consult AI Assistant',
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ChatScreen(
                              diseaseName: alert.disease,
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
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
