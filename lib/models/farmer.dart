import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

class Farmer {
  final int id;
  final String name;
  final String phone;
  final String location;
  final String district;
  final String area;
  final String variety;
  final int scans;
  final String disease;
  final String lastScan;

  Farmer({
    required this.id,
    required this.name,
    required this.phone,
    required this.location,
    required this.district,
    required this.area,
    required this.variety,
    required this.scans,
    required this.disease,
    required this.lastScan,
  });

  Farmer copyWith({
    int? id,
    String? name,
    String? phone,
    String? location,
    String? district,
    String? area,
    String? variety,
    int? scans,
    String? disease,
    String? lastScan,
  }) {
    return Farmer(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      location: location ?? this.location,
      district: district ?? this.district,
      area: area ?? this.area,
      variety: variety ?? this.variety,
      scans: scans ?? this.scans,
      disease: disease ?? this.disease,
      lastScan: lastScan ?? this.lastScan,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'phone': phone,
    'location': location,
    'district': district,
    'area': area,
    'variety': variety,
    'scans': scans,
    'disease': disease,
    'lastScan': lastScan,
  };

  factory Farmer.fromJson(Map<String, dynamic> json) {
    // Helper to format Laravel's ISO dates (e.g. 2026-04-17T08:10:41.000000Z) to "Apr 17"
    String formatDate(String? iso) {
      if (iso == null || iso.isEmpty) return 'No scans';
      try {
        final date = DateTime.parse(iso);
        final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
        return '${months[date.month - 1]} ${date.day}';
      } catch (_) {
        return iso.split('T').first;
      }
    }

    try {
      return Farmer(
        id: json['id'] is int ? json['id'] : int.parse(json['id']?.toString() ?? '0'),
        name: json['name']?.toString() ?? 'Unknown',
        phone: json['phone']?.toString() ?? '',
        location: json['location']?.toString() ?? json['district']?.toString() ?? '',
        district: json['district']?.toString() ?? '',
        area: json['area']?.toString() ?? '0',
        variety: json['variety']?.toString() ?? '',
        scans: json['scans'] is int ? json['scans'] : int.tryParse(json['scans']?.toString() ?? '0') ?? 0,
        disease: json['disease']?.toString() ?? 'None',
        lastScan: json['last_scan'] != null 
            ? formatDate(json['last_scan']?.toString()) 
            : json['created_at'] != null 
                ? formatDate(json['created_at']?.toString())
                : 'No scans',
      );
    } catch (e) {
      debugPrint("Error parsing Farmer: $e");
      return Farmer(id: 0, name: 'Error Loading', phone: '', location: '', district: '', area: '', variety: '', scans: 0, disease: 'Unknown', lastScan: '');
    }
  }
}