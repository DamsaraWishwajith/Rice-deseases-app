import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class InputField extends StatelessWidget {
  final String label;
  final String? icon;
  final String value;
  final ValueChanged<String> onChanged;
  final String? placeholder;
  final String? type; // text, email, password, tel
  final List<String>? options; // for dropdown
  final bool enabled;

  const InputField({
    super.key,
    required this.label,
    this.icon,
    required this.value,
    required this.onChanged,
    this.placeholder,
    this.type,
    this.options,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppColors.sub,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 5),
          Container(
            decoration: BoxDecoration(
              color: AppColors.white.withOpacity(0.8),
              border: Border.all(color: AppColors.border.withOpacity(0.9), width: 1.0),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(color: AppColors.forest.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 2)),
              ],
            ),
            child: options != null
                ? DropdownButtonFormField<String>(
                    value: value.isEmpty ? null : value,
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                    items: options!.map((opt) {
                      return DropdownMenuItem(value: opt, child: Text(opt));
                    }).toList(),
                    onChanged: enabled ? (val) => onChanged(val ?? '') : null,
                    style: const TextStyle(fontSize: 14, color: AppColors.text),
                  )
                : TextFormField(
                    initialValue: value,
                    onChanged: onChanged,
                    enabled: enabled,
                    obscureText: type == 'password',
                    style: const TextStyle(fontSize: 14, color: AppColors.text),
                    decoration: InputDecoration(
                      hintText: placeholder,
                      hintStyle: const TextStyle(color: AppColors.sub, fontSize: 14),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.only(
                        left: icon != null ? 40 : 14,
                        right: 14,
                        top: 12,
                        bottom: 12,
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}