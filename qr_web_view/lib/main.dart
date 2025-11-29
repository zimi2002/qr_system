import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:qr_web_view/config/supabase_config.dart';
import 'package:qr_web_view/pages/student_page.dart';
import 'package:qr_web_view/pages/stats_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables from .env file
  await dotenv.load(fileName: ".env");

  // Initialize Supabase
  await Supabase.initialize(
    url: SupabaseConfig.supabaseUrl,
    anonKey: SupabaseConfig.supabaseAnonKey,
  );

  runApp(const MyApp());
}

final GoRouter _router = GoRouter(
  debugLogDiagnostics: true,
  initialLocation: Uri.base
      .toString(), // Use the full URL including query parameters
  routes: [
    GoRoute(
      path: '/stats',
      builder: (context, state) => const StatsPage(),
    ),
    GoRoute(
      path: '/',
      builder: (context, state) {
        // Get parameters from the current URL
        final qrToken = state.uri.queryParameters['qr_token'];

        // Debug information
        debugPrint('=============== Debug Info ===============');
        debugPrint('Full URL: ${Uri.base}');
        debugPrint('Query Parameters: ${state.uri.queryParameters}');
        debugPrint('QR Token: $qrToken');
        debugPrint('State URI: ${state.uri}');
        debugPrint('=========================================');

        if (qrToken != null && qrToken.isNotEmpty) {
          return StudentPage(qrToken: qrToken);
        }

        return Scaffold(
          body: LayoutBuilder(
            builder: (context, constraints) {
              // Determine which background to use based on screen width
              final isWeb = constraints.maxWidth > 600;
              final backgroundAsset = isWeb
                  ? 'assets/Oppam_web copy.jpg'
                  : 'assets/Oppam_phonr copy.jpg';

              // More precise positioning for the content area
              // These values are estimated based on typical layout designs
              final rightPosition =
                  constraints.maxWidth * 0.08; // 8% from right edge
              final topPosition = constraints.maxHeight * 0.18; // 18% from top
              final cardWidth =
                  constraints.maxWidth * 0.35; // 35% of screen width

              return Container(
                decoration: BoxDecoration(
                  image: DecorationImage(
                    image: AssetImage(backgroundAsset),
                    fit: BoxFit.cover,
                  ),
                ),
                child: Stack(
                  children: [
                    Positioned(
                      right: rightPosition,
                      top: topPosition,
                      width: cardWidth,
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'Please provide a valid QR token in the URL',
                          style: TextStyle(fontSize: 16, color: Colors.black),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    ),
  ],
);

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      routerConfig: _router,
      title: 'QR Student View',
      theme: ThemeData(
        scaffoldBackgroundColor: const Color(0xFF474C72),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF474C72),
          elevation: 0,
        ),
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
    );
  }
}
