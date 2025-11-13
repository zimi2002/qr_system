class Student {
  final String username;
  final String name;
  final String batch;
  final String mentor;
  final String sts;
  final String inTime;
  final String lastScan;
  final String qrToken;

  Student({
    required this.username,
    required this.name,
    required this.batch,
    required this.mentor,
    required this.sts,
    required this.inTime,
    required this.lastScan,
    required this.qrToken,
  });

  factory Student.fromJson(Map<String, dynamic> json) {
    // Helper function to convert ISO date to readable string
    String formatDateTime(dynamic value) {
      if (value == null || value == '') return '';
      try {
        if (value is String) {
          // If it's already a string, check if it's ISO format
          if (value.contains('T')) {
            final dateTime = DateTime.parse(value);
            return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}:${dateTime.second.toString().padLeft(2, '0')}';
          }
          return value;
        }
        return value.toString();
      } catch (e) {
        return value.toString();
      }
    }

    return Student(
      // Handle both uppercase and lowercase field names from API
      username: json['Username'] ?? json['username'] ?? '',
      name: json['Name'] ?? json['name'] ?? '',
      batch: json['Batch'] ?? json['batch'] ?? '',
      mentor: json['Mentor Name'] ?? json['mentor'] ?? '',
      sts: (json['sts'] ?? '').toString().trim(), // Ensure it's a clean string
      inTime: formatDateTime(json['in_time'] ?? ''),
      lastScan: formatDateTime(json['last_scan'] ?? ''),
      qrToken: json['qr_token'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'username': username,
      'name': name,
      'batch': batch,
      'mentor': mentor,
      'sts': sts,
      'in_time': inTime,
      'last_scan': lastScan,
      'qr_token': qrToken,
    };
  }

  bool get hasLastScan => lastScan.isNotEmpty;
  bool get isActive => sts.toLowerCase() == 'active';

  String get displayInfo =>
      'Name: $name\nUsername: $username\nBatch: $batch\nMentor: $mentor\nTime: $inTime';
}
