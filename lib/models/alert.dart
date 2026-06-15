class Alert {
  final int id;
  final String farmer;
  final String disease;
  final String severity;
  final String time;
  bool read;
  final String? image;
  final String? note;
  final String? solutions;
  final String? district;

  Alert({
    required this.id,
    required this.farmer,
    required this.disease,
    required this.severity,
    required this.time,
    this.read = false,
    this.image,
    this.note,
    this.solutions,
    this.district,
  });

  Alert copyWith({
    bool? read,
    String? image,
    String? note,
    String? solutions,
    String? district,
  }) {
    return Alert(
      id: id,
      farmer: farmer,
      disease: disease,
      severity: severity,
      time: time,
      read: read ?? this.read,
      image: image ?? this.image,
      note: note ?? this.note,
      solutions: solutions ?? this.solutions,
      district: district ?? this.district,
    );
  }
}