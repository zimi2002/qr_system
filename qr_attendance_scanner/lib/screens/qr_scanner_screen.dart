import 'dart:math';
import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_attendance_scanner/services/attendance_service.dart';
import 'package:qr_attendance_scanner/screens/qr_success_screen.dart';
import 'package:qr_attendance_scanner/screens/qr_failure_screen.dart';
import 'package:qr_attendance_scanner/screens/qr_duplicate_screen.dart';

class QRScannerScreen extends StatefulWidget {
  const QRScannerScreen({super.key});

  @override
  State<QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen>
    with SingleTickerProviderStateMixin {
  String? scannedData;
  bool isScanned = false;
  bool isProcessing = false;
  late AnimationController _animationController;
  late MobileScannerController _scannerController;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();

    // Initialize scanner controller once with optimized settings
    _scannerController = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates, // Faster detection with no duplicates
      facing: CameraFacing.back,
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    _scannerController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  /// Extract QR token from raw value with optimized parsing
  String _extractQRToken(String rawValue) {
    // Quick check if it's likely JSON (starts with { or contains qr_token:)
    if (rawValue.startsWith('{') || rawValue.contains('qr_token')) {
      try {
        // Try to parse as JSON
        final data = jsonDecode(rawValue);
        if (data is Map<String, dynamic> && data.containsKey('qr_token')) {
          return data['qr_token'];
        }
      } catch (e) {
        // If JSON parsing fails, fall back to regex
        final match = RegExp(r'qr_token[:\s]+([^,}\s]+)').firstMatch(rawValue);
        if (match != null) {
          return match.group(1)?.trim() ?? rawValue;
        }
      }
    }

    // Return original value if no qr_token found
    return rawValue;
  }

  /// Debounced QR detection handler
  void _handleQRDetection(String rawValue) {
    // Cancel any existing timer
    _debounceTimer?.cancel();

    // Set a new timer for debouncing (300ms delay)
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      if (isScanned || isProcessing) return;

      setState(() => isScanned = true);

      final qrToken = _extractQRToken(rawValue);
      print('Extracted QR Token: $qrToken');
      _processAttendance(qrToken);
    });
  }

  /// Process attendance using the service
  Future<void> _processAttendance(String qrToken) async {
    if (isProcessing) return;

    setState(() {
      isProcessing = true;
      scannedData = qrToken;
    });

    try {
      final result = await AttendanceService.processAttendance(qrToken);

      if (!mounted) return;

      print('=== NAVIGATION DECISION ===');
      print('Result status: ${result['status']}');
      print('=========================');

      switch (result['status']) {
        case 'success':
          final student = result['student'];
          print('>>> NAVIGATING TO SUCCESS SCREEN <<<');
          print('Student: ${student.name}');
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => QRSuccessScreen(scannedData: student.displayInfo),
            ),
          ).then((_) => _resetScanning());
          break;

        case 'duplicate':
          final student = result['student'];
          print('>>> NAVIGATING TO DUPLICATE SCREEN <<<');
          print('Student: ${student.name}');
          print('Previous scan time: ${result['previous_scan_time']}');
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => QRDuplicateScreen(
                scannedData: '${student.name} (${student.username})',
                previousScanTime: result['previous_scan_time'] ?? '',
              ),
            ),
          ).then((_) => _resetScanning());
          break;

        case 'error':
        default:
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => QRFailureScreen(
                errorMessage: result['error'] ?? 'Unknown error occurred',
              ),
            ),
          ).then((_) => _resetScanning());
          break;
      }
    } catch (e) {
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                QRFailureScreen(errorMessage: 'Unexpected error: $e'),
          ),
        ).then((_) => _resetScanning());
      }
    }
  }

  void _resetScanning() {
    setState(() {
      isScanned = false;
      isProcessing = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final frameSize = size.width * 0.75;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        alignment: Alignment.center,
        children: [
          // Camera Scanner
          MobileScanner(
            fit: BoxFit.cover,
            controller: _scannerController,
            onDetect: (capture) {
              final barcode = capture.barcodes.first;
              final value = barcode.rawValue ?? '';
              _handleQRDetection(value);
            },
          ),

          // Animated scanning frame
          Positioned(
            top: size.height * 0.2,
            child: SizedBox(
              width: frameSize,
              height: frameSize,
              child: AnimatedBuilder(
                animation: _animationController,
                builder: (context, _) {
                  return CustomPaint(
                    painter: _AnimatedBorderPainter(
                      progress: _animationController.value,
                    ),
                  );
                },
              ),
            ),
          ),

          // Bottom instruction panel
          Positioned(
            bottom: 80,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white24),
              ),
              child: Column(
                children: [
                  Text(
                    isProcessing
                        ? "Processing attendance..."
                        : "Align the QR code within the square",
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.95),
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (scannedData != null && !isProcessing)
                    Text(
                      "Scanned: $scannedData",
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.greenAccent,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  if (isProcessing)
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Colors.greenAccent,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AnimatedBorderPainter extends CustomPainter {
  final double progress;

  _AnimatedBorderPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final basePaint = Paint()
      ..color = Colors.white.withOpacity(0.3)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    final glowPaint = Paint()
      ..shader = SweepGradient(
        startAngle: 0,
        endAngle: 2 * pi,
        colors: [
          Colors.transparent,
          Colors.greenAccent.withOpacity(0.9),
          Colors.transparent,
        ],
        stops: [
          progress - 0.05,
          progress,
          progress + 0.05,
        ].map((e) => e.clamp(0.0, 1.0)).toList(),
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(20));

    canvas.drawRRect(rrect, basePaint);
    canvas.drawArc(rect, 0, 2 * pi, false, glowPaint);
  }

  @override
  bool shouldRepaint(_AnimatedBorderPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
