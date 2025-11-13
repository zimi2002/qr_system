import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../models/student_model.dart';

class StudentCard extends StatelessWidget {
  final Student student;

  const StudentCard({super.key, required this.student});

  @override
  Widget build(BuildContext context) {
    final qrData = {
      "username": student.username,
      "name": student.name,
      "batch": student.batch,
      "mentor": student.mentorName,
      "qr_token": student.qrToken,
      "sts": student.sts,
      "in_time": student.inTime,
      "last_scan": student.lastScan,
      "phone": student.phone,
    };

    return LayoutBuilder(
      builder: (context, constraints) {
        // Responsive sizing based on screen width
        final isMobile = constraints.maxWidth < 600;
        final cardMaxWidth = isMobile ? 300.0 : 340.0;
        final cardMaxHeight = isMobile ? 450.0 : 560.0;
        final nameFontSize = isMobile ? 20.0 : 24.0;
        final padding = isMobile ? 16.0 : 28.0;
        final qrSize = isMobile ? 180.0 : 220.0;

        return SingleChildScrollView(
          child: Center(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: cardMaxWidth,
                maxHeight: cardMaxHeight,
              ),
              child: Card(
                color: Colors.white,
                elevation: 12,
                shadowColor: Colors.black.withOpacity(0.2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    vertical: padding,
                    horizontal: padding * 0.75,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Student Name
                      Text(
                        student.name,
                        style: TextStyle(
                          fontSize: nameFontSize,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF1A1A1A),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),

                      // Student Details
                      _buildInfoRow(
                        Icons.person_outline,
                        "Username",
                        student.username,
                      ),
                      const SizedBox(height: 8),
                      _buildInfoRow(
                        Icons.school_outlined,
                        "Batch",
                        student.batch,
                      ),
                      const SizedBox(height: 8),
                      _buildInfoRow(
                        Icons.supervisor_account_outlined,
                        "Mentor",
                        student.mentorName,
                      ),

                      const SizedBox(height: 16),

                      // Divider
                      Container(height: 1, color: Colors.grey.withOpacity(0.2)),

                      const SizedBox(height: 16),

                      // QR Code
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.grey.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: QrImageView(
                          data: qrData.toString(),
                          version: QrVersions.auto,
                          size: qrSize,
                          backgroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 18, color: const Color(0xFF666666)),
        const SizedBox(width: 8),
        Text(
          "$label: ",
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF666666),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 14, color: Color(0xFF1A1A1A)),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
