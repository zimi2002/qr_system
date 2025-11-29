import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_attendance_scanner/services/instant_attendance_service.dart';
import 'package:qr_attendance_scanner/screens/qr_success_screen.dart';
import 'package:qr_attendance_scanner/screens/qr_failure_screen.dart';
import 'package:qr_attendance_scanner/screens/qr_duplicate_screen.dart';

/// Ultra-fast QR scanner with instant responses
///
/// Optimizations:
/// - Highest detection speed settings
/// - Instant cache-based responses
/// - Minimal UI updates during scanning
/// - Optimized QR token extraction
/// - Reduced debounce delays
/// - Hardware-accelerated rendering
class InstantQRScannerScreen extends StatefulWidget {
  const InstantQRScannerScreen({super.key});

  @override
  State<InstantQRScannerScreen> createState() => _InstantQRScannerScreenState();
}

class _InstantQRScannerScreenState extends State<InstantQRScannerScreen>
    with SingleTickerProviderStateMixin {
  String? scannedData;
  bool isScanned = false;
  bool isProcessing = false;
  String _processingMessage = "Processing...";
  int _processingTime = 0;

  late AnimationController _animationController;
  late MobileScannerController _scannerController;
  Timer? _debounceTimer;
  Timer? _feedbackTimer;

  // Performance tracking
  final Stopwatch _scanStopwatch = Stopwatch();

  @override
  void initState() {
    super.initState();

    // Initialize instant attendance service
    InstantAttendanceService.initialize();

    // Faster animation for better perceived performance
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000), // Faster animation
    )..repeat();

    // Initialize scanner with safer configuration
    _initializeScanner();
  }

  /// Initialize scanner with proper error handling
  Future<void> _initializeScanner() async {
    try {
      _scannerController = MobileScannerController(
        detectionSpeed: DetectionSpeed.normal, // Use normal speed for stability
        facing: CameraFacing.back,
        returnImage: false, // Don't return images for better performance
        autoStart: false, // Manual start for better control
        formats: [BarcodeFormat.qrCode], // Only QR codes for faster processing
      );

      // Start the scanner manually after a brief delay
      await Future.delayed(Duration(milliseconds: 500));
      if (mounted) {
        await _scannerController.start();
      }
    } catch (e) {
      debugPrint('Error initializing scanner: $e');
      // Fallback to basic configuration
      _scannerController = MobileScannerController(
        facing: CameraFacing.back,
        autoStart: false,
      );

      if (mounted) {
        await _scannerController.start();
      }
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _scannerController.dispose();
    _debounceTimer?.cancel();
    _feedbackTimer?.cancel();
    super.dispose();
  }

  /// Ultra-fast QR token extraction with minimal string operations
  String _extractQRToken(String rawValue) {
    // Quick pattern matching for common QR token formats

    // Direct token check (fastest path)
    if (!rawValue.contains('{') && !rawValue.contains(':')) {
      return rawValue.trim(); // Likely a direct token
    }

    // JSON-like format check
    if (rawValue.startsWith('{')) {
      try {
        final data = jsonDecode(rawValue);
        if (data is Map && data['qr_token'] != null) {
          return data['qr_token'].toString();
        }
      } catch (_) {
        // Fast fallback to regex
        final match = RegExp(
          r'"qr_token"\s*:\s*"([^"]+)"',
        ).firstMatch(rawValue);
        if (match != null) return match.group(1)!;
      }
    }

    // Key-value format (qr_token: value)
    final kvMatch = RegExp(r'qr_token\s*:\s*([^\s,}]+)').firstMatch(rawValue);
    if (kvMatch != null) return kvMatch.group(1)!.trim();

    // Return original value if no token pattern found
    return rawValue.trim();
  }

  /// Instant QR detection with minimal debounce
  void _handleQRDetection(String rawValue) {
    // Immediate guard checks
    if (isScanned || isProcessing || rawValue.isEmpty) return;

    // Start performance tracking
    _scanStopwatch.reset();
    _scanStopwatch.start();

    // Very short debounce for rapid scanning
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 100), () {
      if (isScanned || isProcessing) return;

      // Haptic feedback for instant user confirmation
      HapticFeedback.lightImpact();

      setState(() {
        isScanned = true;
        isProcessing = true;
        scannedData = "Processing...";
      });

      final qrToken = _extractQRToken(rawValue);
      _processAttendanceInstant(qrToken);
    });
  }

  /// Process attendance using instant service
  Future<void> _processAttendanceInstant(String qrToken) async {
    _feedbackTimer = Timer(const Duration(milliseconds: 100), () {
      if (mounted && isProcessing) {
        setState(() {
          _processingMessage = "Checking cache...";
          _processingTime = _scanStopwatch.elapsedMilliseconds;
        });
      }
    });

    try {
      final result = await InstantAttendanceService.processAttendanceInstant(
        qrToken,
      );
      _feedbackTimer?.cancel();
      _scanStopwatch.stop();

      if (!mounted) return;

      final totalTime = _scanStopwatch.elapsedMilliseconds;

      // Show brief performance feedback for very fast responses
      if (totalTime < 200) {
        // Haptic feedback for instant success
        HapticFeedback.mediumImpact();
      }

      switch (result['status']) {
        case 'success':
          final student = result['student'];
          _navigateToSuccess(student, totalTime);
          break;

        case 'duplicate':
          final student = result['student'];
          _navigateToDuplicate(student, totalTime);
          break;

        case 'queued':
          _showQueuedFeedback(result, totalTime);
          break;

        case 'error':
        default:
          _navigateToError(result['error'] ?? 'Unknown error', totalTime);
          break;
      }
    } catch (e) {
      _feedbackTimer?.cancel();
      if (mounted) {
        _navigateToError(
          'Processing error: $e',
          _scanStopwatch.elapsedMilliseconds,
        );
      }
    }
  }

  /// Navigate to success screen with performance info
  void _navigateToSuccess(dynamic student, int totalTime) {
    final performanceInfo = totalTime < 100
        ? ' (⚡ ${totalTime}ms)'
        : ' (${totalTime}ms)';
    // Handle null student gracefully
    final displayText = student != null
        ? student.displayInfo + performanceInfo
        : 'Attendance recorded successfully$performanceInfo';
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => QRSuccessScreen(scannedData: displayText),
      ),
    ).then((_) => _resetScanning());
  }

  /// Navigate to duplicate screen with performance info
  void _navigateToDuplicate(dynamic student, int totalTime) {
    final performanceInfo = totalTime < 100
        ? ' (⚡ ${totalTime}ms)'
        : ' (${totalTime}ms)';
    // Handle null student gracefully
    final displayText = student != null
        ? '${student.name} (${student.username})$performanceInfo'
        : 'Duplicate scan detected$performanceInfo';
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => QRDuplicateScreen(
          scannedData: displayText,
          previousScanTime: 'Recent scan detected',
        ),
      ),
    ).then((_) => _resetScanning());
  }

  /// Show queued feedback for offline scenarios
  void _showQueuedFeedback(Map<String, dynamic> result, int totalTime) {
    // Show a brief snackbar and continue scanning
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result['offline'] == true
              ? 'Offline - QR queued for sync (${totalTime}ms)'
              : 'QR queued for processing (${totalTime}ms)',
        ),
        duration: Duration(milliseconds: 1500),
        backgroundColor: Colors.orange,
      ),
    );

    // Continue scanning after brief delay
    Future.delayed(Duration(milliseconds: 1500), _resetScanning);
  }

  /// Navigate to error screen
  void _navigateToError(String error, int totalTime) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            QRFailureScreen(errorMessage: '$error (${totalTime}ms)'),
      ),
    ).then((_) => _resetScanning());
  }

  /// Reset scanner for next scan
  void _resetScanning() {
    // Cancel timers
    _feedbackTimer?.cancel();
    _debounceTimer?.cancel();

    // Resume animation
    if (!_animationController.isAnimating) {
      _animationController.repeat();
    }

    setState(() {
      isScanned = false;
      isProcessing = false;
      scannedData = null;
      _processingMessage = "Processing...";
      _processingTime = 0;
    });

    // Restart scanner immediately
    _scannerController.start();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final frameSize = size.width * 0.7; // Slightly smaller for faster focus

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        alignment: Alignment.center,
        children: [
          // Ultra-fast scanner with optimized settings
          MobileScanner(
            fit: BoxFit.cover,
            controller: _scannerController,
            onDetect: (capture) {
              if (capture.barcodes.isNotEmpty) {
                final value = capture.barcodes.first.rawValue;
                if (value != null && value.isNotEmpty) {
                  _handleQRDetection(value);
                }
              }
            },
            errorBuilder: (context, error, child) {
              return Container(
                color: Colors.black,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.camera_alt, color: Colors.white, size: 48),
                      SizedBox(height: 16),
                      Text(
                        'Camera Error',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        error.errorDetails?.message ??
                            'Failed to initialize camera',
                        style: TextStyle(color: Colors.white70, fontSize: 14),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () async {
                          try {
                            await _scannerController.start();
                          } catch (e) {
                            debugPrint('Restart failed: $e');
                          }
                        },
                        child: Text('Retry'),
                      ),
                    ],
                  ),
                ),
              );
            },
            placeholderBuilder: (context, child) {
              return Container(
                color: Colors.black,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(color: Colors.white),
                      SizedBox(height: 16),
                      Text(
                        'Initializing camera...',
                        style: TextStyle(color: Colors.white, fontSize: 16),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),

          // Minimal animated scanning frame for performance
          if (!isProcessing)
            Positioned(
              top: size.height * 0.25,
              child: SizedBox(
                width: frameSize,
                height: frameSize,
                child: AnimatedBuilder(
                  animation: _animationController,
                  builder: (context, _) {
                    return CustomPaint(
                      painter: _MinimalBorderPainter(
                        progress: _animationController.value,
                        isActive: !isScanned,
                      ),
                    );
                  },
                ),
              ),
            ),

          // Processing overlay
          if (isProcessing)
            Positioned(
              top: size.height * 0.25,
              child: Container(
                width: frameSize,
                height: frameSize,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.green, width: 3),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 30,
                        height: 30,
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.green,
                          ),
                        ),
                      ),
                      SizedBox(height: 16),
                      Text(
                        _processingMessage,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (_processingTime > 0)
                        Text(
                          '${_processingTime}ms',
                          style: TextStyle(
                            color: Colors.green,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),

          // Minimal bottom instruction
          Positioned(
            bottom: 100,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.8),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white24, width: 1),
              ),
              child: Column(
                children: [
                  Text(
                    isProcessing
                        ? _processingMessage
                        : "Position QR code in frame",
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (scannedData != null && !isProcessing)
                    Text(
                      scannedData!,
                      style: TextStyle(
                        color: Colors.greenAccent,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                ],
              ),
            ),
          ),

          // Performance indicator (top right)
          Positioned(
            top: 60,
            right: 20,
            child: FutureBuilder<Map<String, dynamic>>(
              future: InstantAttendanceService.getServiceStats(),
              builder: (context, snapshot) {
                if (snapshot.hasData) {
                  final stats = snapshot.data!;
                  return Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Cache: ${stats['cached_students'] ?? 0} | ${stats['is_online'] == true ? '🟢' : '🔴'}',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  );
                }
                return SizedBox.shrink();
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Minimal border painter for maximum performance
class _MinimalBorderPainter extends CustomPainter {
  final double progress;
  final bool isActive;

  _MinimalBorderPainter({required this.progress, required this.isActive});

  @override
  void paint(Canvas canvas, Size size) {
    if (!isActive) return; // Don't paint when inactive

    final paint = Paint()
      ..color = Colors.white.withOpacity(0.6)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;

    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(20));

    // Just draw the border without complex animations for performance
    canvas.drawRRect(rrect, paint);

    // Simple corner highlights
    final highlightPaint = Paint()
      ..color = Colors.greenAccent.withOpacity(0.8)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    final cornerSize = 20.0;

    // Top-left corner
    canvas.drawPath(
      Path()
        ..moveTo(0, cornerSize)
        ..lineTo(0, 20)
        ..quadraticBezierTo(0, 0, 20, 0)
        ..lineTo(cornerSize, 0),
      highlightPaint,
    );

    // Top-right corner
    canvas.drawPath(
      Path()
        ..moveTo(size.width - cornerSize, 0)
        ..lineTo(size.width - 20, 0)
        ..quadraticBezierTo(size.width, 0, size.width, 20)
        ..lineTo(size.width, cornerSize),
      highlightPaint,
    );

    // Bottom-left corner
    canvas.drawPath(
      Path()
        ..moveTo(0, size.height - cornerSize)
        ..lineTo(0, size.height - 20)
        ..quadraticBezierTo(0, size.height, 20, size.height)
        ..lineTo(cornerSize, size.height),
      highlightPaint,
    );

    // Bottom-right corner
    canvas.drawPath(
      Path()
        ..moveTo(size.width - cornerSize, size.height)
        ..lineTo(size.width - 20, size.height)
        ..quadraticBezierTo(
          size.width,
          size.height,
          size.width,
          size.height - 20,
        )
        ..lineTo(size.width, size.height - cornerSize),
      highlightPaint,
    );
  }

  @override
  bool shouldRepaint(_MinimalBorderPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.isActive != isActive;
}
