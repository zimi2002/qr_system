class Student {
  final String username;
  final String name;
  final String batch;
  final String mentorName;
  final String qrToken;
  final String sts;
  final String inTime;
  final String lastScan;
  final String phone;

  Student({
    required this.username,
    required this.name,
    required this.batch,
    required this.mentorName,
    required this.qrToken,
    required this.sts,
    required this.inTime,
    required this.lastScan,
    required this.phone,
  });

  factory Student.fromJson(Map<String, dynamic> json) {
    return Student(
      username: json['username']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      batch: json['batch']?.toString() ?? '',
      mentorName: json['mentor']?.toString() ?? '',
      qrToken: json['qr_token']?.toString() ?? '',
      sts: json['sts']?.toString() ?? '',
      inTime: json['in_time']?.toString() ?? '',
      lastScan: json['last_scan']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
    );
  }
}
