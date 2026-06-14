class Alert {
  final int id;
  final String farmer;
  final String disease;
  final String severity;
  final String time;
  bool read;

  Alert({
    required this.id,
    required this.farmer,
    required this.disease,
    required this.severity,
    required this.time,
    this.read = false,
  });

  Alert copyWith({bool? read}) {
    return Alert(
      id: id,
      farmer: farmer,
      disease: disease,
      severity: severity,
      time: time,
      read: read ?? this.read,
    );
  }
}