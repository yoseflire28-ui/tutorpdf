import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'firebase_options.dart';
import 'data/providers/settings_provider.dart';
import 'data/providers/document_provider.dart';
import 'data/providers/active_document_provider.dart';
import 'presentation/providers/chat_provider.dart';
import 'database/database_helper.dart';
import 'core/app_theme.dart';
import 'presentation/screens/main_shell.dart';
import 'screens/splash_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Set system UI overlay style for status bar visibility
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
      systemNavigationBarColor: Color(0xFF3D3D3F),
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  // Initialize Firebase with platform-specific options
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Configure Firebase App Check for security
  await FirebaseAppCheck.instance.activate(
    androidProvider: AndroidProvider.debug,
    appleProvider: AppleProvider.deviceCheck,
  );

  // Initialize local SQLite database (preserved for local features)
  if (!kIsWeb) {
    try {
      await DatabaseHelper.instance.database;
    } catch (e) {
      debugPrint('Database initialization error: $e');
    }
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => SettingsProvider(),
        ),
        ChangeNotifierProvider(
          create: (_) => DocumentProvider(),
        ),
        ChangeNotifierProvider(
          create: (_) => ActiveDocumentProvider(),
        ),
        ChangeNotifierProvider(
          create: (_) => ChatProvider(),
        ),
      ],
      child: const TutorPDFApp(),
    ),
  );
}

class TutorPDFApp extends StatelessWidget {
  const TutorPDFApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<SettingsProvider>(
      builder: (context, settingsProvider, child) {
        return MaterialApp(
          title: 'TutorPDF',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: settingsProvider.isDarkMode ? ThemeMode.dark : ThemeMode.light,
          routes: {
            '/home': (context) => const MainShell(),
          },
          home: kIsWeb
              ? const Scaffold(
                  body: Center(
                    child: Text(
                      'TutorPDF: Please run on an Android Emulator or Device.',
                      style: TextStyle(color: Color(0xFF3D3D3F), fontSize: 16),
                    ),
                  ),
                )
              : const SplashScreen(),
        );
      },
    );
  }
}
