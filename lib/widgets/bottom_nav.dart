import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class BottomNav extends StatelessWidget {
  final String currentPage;
  final Function(String) onPageChanged;

  const BottomNav({
    super.key,
    required this.currentPage,
    required this.onPageChanged,
  });

  @override
  Widget build(BuildContext context) {
    final tabs = [
      {'id': 'home', 'label': 'Home', 'icon': '🏠'},
      {'id': 'farmers', 'label': 'Farmers', 'icon': '👤'},
      {'id': 'scan', 'label': 'Scan', 'icon': '🔬', 'big': true},
      {'id': 'alerts', 'label': 'Alerts', 'icon': '🔔'},
      {'id': 'more', 'label': 'More', 'icon': '⋯'},
    ];

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.white,
        border: Border(top: BorderSide(color: AppColors.border, width: 1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: tabs.map((tab) {
          final isSelected = currentPage == tab['id'];
          final isBig = tab['big'] == true;

          return Expanded(
            child: GestureDetector(
              onTap: () => onPageChanged(tab['id'] as String),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
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
                            child: Text('🔬', style: TextStyle(fontSize: 22)),
                          ),
                        ),
                      )
                    else
                      Opacity(
                        opacity: isSelected ? 1.0 : 0.38,
                        child: Text(tab['icon'] as String, style: const TextStyle(fontSize: 21)),
                      ),
                    if (!isBig) ...[
                      const SizedBox(height: 3),
                      Text(
                        tab['label'] as String,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
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