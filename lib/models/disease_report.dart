class DiseaseReport {
  final int reportId;
  final int? farmerId;
  final String farmerName;
  final String diseaseName;
  final String diseaseImage;
  final String? customerNote;
  final String recommendSolutions;
  final String createdAt;

  DiseaseReport({
    required this.reportId,
    this.farmerId,
    required this.farmerName,
    required this.diseaseName,
    required this.diseaseImage,
    this.customerNote,
    required this.recommendSolutions,
    required this.createdAt,
  });

  factory DiseaseReport.fromJson(Map<String, dynamic> json) {
    return DiseaseReport(
      reportId: json['report_id'],
      farmerId: json['farmer_id'],
      farmerName: json['farmer_name'] ?? 'Unknown',
      diseaseName: json['disease_name'] ?? 'Unknown',
      diseaseImage: json['disease_image'] ?? '',
      customerNote: json['customer_note'],
      recommendSolutions: json['recommend_solutions'] ?? 'No solutions available',
      createdAt: json['created_at'] ?? '',
    );
  }
}
