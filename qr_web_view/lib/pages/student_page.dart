import 'package:flutter/material.dart';
import 'package:qr_web_view/services/api_services.dart';
import '../models/student_model.dart';
import '../widgets/student_card.dart';
import 'package:url_launcher/url_launcher.dart';

class StudentPage extends StatefulWidget {
  final String? qrToken;

  const StudentPage({super.key, this.qrToken});

  @override
  State<StudentPage> createState() => _StudentPageState();
}

class _StudentPageState extends State<StudentPage>
    with SingleTickerProviderStateMixin {
  Student? student;
  bool isLoading = true;
  String? error;

  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;

  // Replace with your actual Google Maps link
  static const String googleMapsUrl = "https://www.google.com/maps?q=Calicut+Trade+Centre+Kozhikode";

  @override
  void initState() {
    super.initState();
    _loadStudent();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(-1.5, 0),
      end: const Offset(0, 0),
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _loadStudent() async {
    debugPrint('🎯 QR Token received: ${widget.qrToken}');

    if (widget.qrToken == null || widget.qrToken!.isEmpty) {
      setState(() {
        error = 'No QR token provided in URL.';
        isLoading = false;
      });
      return;
    }

    // Fetch with cache - this will return cached data immediately if available
    // and fetch fresh data in background
    final cachedResult = await ApiService.fetchStudent(widget.qrToken!, useCache: true);

    // Update UI immediately with cached data if available
    if (cachedResult != null) {
      setState(() {
        student = cachedResult;
        isLoading = false;
      });
    } else {
      // No cache available, show loading
      setState(() {
        isLoading = true;
      });
    }

    // Always fetch fresh data in background to update cache and UI
    // This ensures we have the latest data even if cache was used
    final freshResult = await ApiService.fetchStudent(widget.qrToken!, useCache: false);

    // Only update if we got fresh data and widget is still mounted
    if (mounted && freshResult != null) {
      setState(() {
        student = freshResult;
        isLoading = false;
      });
    } else if (mounted && cachedResult == null) {
      // Only show error if we had no cached data
      setState(() {
        error = 'No student found for this QR token.';
        isLoading = false;
      });
    }
  }

  Future<void> _openGoogleMaps() async {
    final url = Uri.parse(googleMapsUrl);

    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open Google Maps')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final screenWidth = screenSize.width;

    // iPad Pro (12.9") has width of 1024, so threshold is higher
    final isDesktop = screenWidth >= 1280;

    final backgroundAsset = isDesktop
        ? 'assets/Oppam_web copy.jpg'
        : 'assets/Oppam_phonr copy.jpg';

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          isDesktop
              ? Container(
                  decoration: BoxDecoration(
                    image: DecorationImage(
                      image: AssetImage(backgroundAsset),
                      fit: BoxFit.cover,
                      alignment: Alignment.topCenter,
                    ),
                  ),
                  child: _buildDesktopLayout(screenSize),
                )
              : _buildMobileTabletLayout(screenSize, backgroundAsset),

          // Google Maps button for mobile/tablet (top-right)
          if (!isDesktop)
            Positioned(
              top: MediaQuery.of(context).padding.top + 16,
              right: 16,
              child: _buildMobileMapButton(),
            ),
        ],
      ),
    );
  }

  /// ✅ Rectangular Map Button for Mobile/Tablet
  Widget _buildMobileMapButton() {
    return GestureDetector(
      onTap: _openGoogleMaps,
      child: Container(
        width: 180,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.95),
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.map,
              color: Color(0xFF4285F4),
              size: 20,
            ),
            SizedBox(width: 8),
            Text(
              'Directions to Venue',
              style: TextStyle(
                color: Colors.black87,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// ✅ Rectangular Map Button for Desktop
  Widget _buildDesktopMapButton() {
    return GestureDetector(
      onTap: _openGoogleMaps,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          width: 260,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(
            color: const Color(0xFF4285F4),
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.25),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.map,
                color: Colors.white,
                size: 22,
              ),
              SizedBox(width: 10),
              Text(
                'Directions to Venue',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopLayout(Size screenSize) {
    return Stack(
      children: [
        Positioned(
          right: screenSize.width * 0.08,
          top: screenSize.height * 0.15,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: screenSize.width * 0.35,
                child: _buildContent(),
              ),
              const SizedBox(height: 20),
              _buildDesktopMapButton(),
            ],
          ),
        ),
      ],
    );
  }

  /// ✅ Improved Layout Logic for Small Screens (like iPhone SE)
  Widget _buildMobileTabletLayout(Size screenSize, String backgroundAsset) {
    final height = screenSize.height;

    // Dynamic card placement logic
    double contentHeight;
    double bottomPadding;

    if (height < 650) {
      // very small screens (iPhone SE, small Androids)
      contentHeight = height * 0.50; // push card lower
      bottomPadding = 20.0;
    } else if (height < 800) {
      // mid-size phones
      contentHeight = height * 0.65;
      bottomPadding = 30.0;
    } else {
      // large phones / tablets
      contentHeight = height * 0.70;
      bottomPadding = 50.0;
    }

    return SingleChildScrollView(
      child: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage(backgroundAsset),
            fit: BoxFit.cover,
            alignment: Alignment.topCenter,
          ),
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: height),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: screenSize.width * 0.04),
            child: Column(
              children: [
                SizedBox(height: contentHeight),
                _buildContent(),
                SizedBox(height: bottomPadding),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    return isLoading
        ? Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2.5,
              ),
              const SizedBox(height: 16),
              SlideTransition(
                position: _slideAnimation,
                child: const Text(
                  "Your QR is loading...",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          )
        : (student != null
            ? StudentCard(student: student!)
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.error_outline,
                    color: Colors.white,
                    size: 40,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    error ?? 'Error loading data',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ));
  }
}
