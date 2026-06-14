class Supervisor {
  final int id;
  final String username;
  final String email;
  final String district;

  Supervisor({
    required this.id,
    required this.username,
    required this.email,
    required this.district,
  });

  factory Supervisor.fromJson(Map<String, dynamic> json) {
    return Supervisor(
      id: json['id'] is int ? json['id'] : int.parse(json['id']?.toString() ?? '0'),
      username: json['username'] ?? '',
      email: json['email'] ?? '',
      district: json['district'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'email': email,
      'district': district,
    };
  }
}