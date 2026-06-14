import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class DiseaseRec {
  final String icon;
  final Color color;
  final List<String> ferts;
  final String note;

  DiseaseRec({
    required this.icon,
    required this.color,
    required this.ferts,
    required this.note,
  });
}

final Map<String, DiseaseRec> diseaseRecs = {
  "Bacterialblight": DiseaseRec(
    icon: "🦠",
    color: AppColors.danger,
    ferts: ["Copper hydroxide 77 WP — 2 g/L", "Streptomycin sulfate — 0.2 g/L"],
    note: "Drain field immediately to lower humidity. Avoid excess nitrogen fertilizers.",
  ),
  "Sheath_blight": DiseaseRec(
    icon: "🌿",
    color: AppColors.warn,
    ferts: ["Validamycin 3L — 2 mL/L", "Hexaconazole 5 EC — 2 mL/L"],
    note: "Reduce plant density. Apply at tillering stage. Remove infected straw.",
  ),
  "Brownspot": DiseaseRec(
    icon: "🟤",
    color: const Color(0xFFA0522D),
    ferts: ["Iprodione 50 WP — 2 g/L", "Mancozeb 75 WP — 2.5 g/L"],
    note: "Improve soil potassium level. Apply at early infection stage.",
  ),
  "Others": DiseaseRec(
    icon: "❓",
    color: AppColors.warn,
    ferts: ["Consult agronomist", "Send samples to lab"],
    note: "Unidentified or multiple minor issues detected. Monitor closely.",
  ),
  "Healthy": DiseaseRec(
    icon: "✅",
    color: AppColors.greenL,
    ferts: ["Continue current fertilizer schedule", "Monitor weekly for early signs"],
    note: "Leaf looks healthy. Keep up good field management practices.",
  ),
};