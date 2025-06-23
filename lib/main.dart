import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'screens/home_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/login_selection_screen.dart';
import 'services/auth_service.dart';
import 'services/auto_backup_service.dart';
import 'services/notification_service.dart';
import 'services/sync_service.dart';
import 'services/firebase_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  // Enable Firebase offline persistence
  await FirebaseService.enableOfflinePersistence();
  
  // Initialize Turkish locale
  await initializeDateFormatting('tr_TR', null);
  
  // Initialize timezone
  tz.initializeTimeZones();
  tz.setLocalLocation(tz.getLocation('Europe/Istanbul'));
  
  // Initialize notification service
  await NotificationService().initialize();
  
  // Initialize sync service
  await SyncService().initialize();
  
  // Cleanup unverified accounts (older than 24 hours)
  FirebaseService.cleanupUnverifiedAccounts().catchError((e) {
    print('⚠️ Doğrulanmamış hesap temizliği sırasında hata: $e');
  });
  
  // Set system UI overlay style for light theme
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );
  
  print('🚀 STOKER SİSTEMİ BAŞLATILIYOR...');
  print('🔥 Firebase başlatıldı');
  print('💾 Offline persistence etkinleştirildi');
  print('🔄 Senkronizasyon servisi başlatıldı');
  print('📦 Profesyonel Stok Yönetim Sistemi');
  print('🔔 Bildirim sistemi başlatıldı');
  print('⏰ Timezone ayarlandı (Europe/Istanbul)');
  print('🧹 Doğrulanmamış hesap temizliği başlatıldı');
  print('✅ Sistem başarıyla başlatıldı!');
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Stoker - Stok Yönetim Sistemi',
      debugShowCheckedModeBanner: false,
      theme: _buildProfessionalLightTheme(),
      home: const AppInitializer(),
    );
  }

  ThemeData _buildProfessionalLightTheme() {
    // Professional Light Color Palette
    const primaryColor = Color(0xFF2196F3); // Professional Blue
    const secondaryColor = Color(0xFF607D8B); // Blue Grey
    const accentColor = Color(0xFFFF9800); // Orange for highlights
    const backgroundColor = Color(0xFFFAFAFA); // Very light grey background
    const surfaceColor = Colors.white; // Pure white for cards
    const onPrimaryColor = Colors.white;
    const onSurfaceColor = Color(0xFF212121); // Dark grey text
    const onBackgroundColor = Color(0xFF424242); // Medium grey text
    const errorColor = Color(0xFFD32F2F); // Red
    const successColor = Color(0xFF388E3C); // Green
    const warningColor = Color(0xFFFF9800); // Orange
    
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      fontFamily: 'SF Pro Display', // Professional font family
      colorScheme: const ColorScheme.light(
        primary: primaryColor,
        secondary: secondaryColor,
        tertiary: accentColor,
        surface: surfaceColor,
        background: backgroundColor,
        error: errorColor,
        onPrimary: onPrimaryColor,
        onSecondary: Colors.white,
        onSurface: onSurfaceColor,
        onBackground: onBackgroundColor,
      ),
      
      // App Bar Theme
      appBarTheme: AppBarTheme(
        backgroundColor: surfaceColor,
        foregroundColor: onSurfaceColor,
        elevation: 1,
        centerTitle: false,
        shadowColor: Colors.black.withOpacity(0.1),
        titleTextStyle: const TextStyle(
          color: onSurfaceColor,
          fontSize: 20,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.15,
          fontFamily: 'SF Pro Display',
        ),
        iconTheme: const IconThemeData(color: onSurfaceColor),
        actionsIconTheme: const IconThemeData(color: onSurfaceColor),
      ),
      
      // Card Theme
      cardTheme: CardTheme(
        color: surfaceColor,
        elevation: 2,
        shadowColor: Colors.black.withOpacity(0.08),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.symmetric(vertical: 4),
      ),
      
      // Elevated Button Theme
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: onPrimaryColor,
          elevation: 2,
          shadowColor: primaryColor.withOpacity(0.3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
            fontFamily: 'SF Pro Display',
          ),
        ),
      ),
      
      // Text Button Theme
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.25,
            fontFamily: 'SF Pro Display',
          ),
        ),
      ),
      
      // Outlined Button Theme
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryColor,
          side: const BorderSide(color: primaryColor, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
            fontFamily: 'SF Pro Display',
          ),
        ),
      ),
      
      // Input Decoration Theme
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFF5F5F5),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: primaryColor, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: errorColor, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        labelStyle: const TextStyle(
          color: Color(0xFF757575),
          fontSize: 14,
          fontWeight: FontWeight.w500,
          fontFamily: 'SF Pro Display',
        ),
        hintStyle: const TextStyle(
          color: Color(0xFF9E9E9E),
          fontSize: 14,
          fontFamily: 'SF Pro Display',
        ),
      ),
      
      // Bottom Navigation Bar Theme
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: surfaceColor,
        selectedItemColor: primaryColor,
        unselectedItemColor: Color(0xFF757575),
        type: BottomNavigationBarType.fixed,
        elevation: 8,
        selectedLabelStyle: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          fontFamily: 'SF Pro Display',
        ),
        unselectedLabelStyle: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          fontFamily: 'SF Pro Display',
        ),
      ),
      
      // Text Theme
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.w300,
          letterSpacing: -0.5,
          color: onSurfaceColor,
          fontFamily: 'SF Pro Display',
        ),
        displayMedium: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w400,
          letterSpacing: 0,
          color: onSurfaceColor,
          fontFamily: 'SF Pro Display',
        ),
        displaySmall: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.15,
          color: onSurfaceColor,
          fontFamily: 'SF Pro Display',
        ),
        headlineLarge: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.15,
          color: onSurfaceColor,
          fontFamily: 'SF Pro Display',
        ),
        headlineMedium: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.15,
          color: onSurfaceColor,
          fontFamily: 'SF Pro Display',
        ),
        headlineSmall: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.15,
          color: onSurfaceColor,
          fontFamily: 'SF Pro Display',
        ),
        titleLarge: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.15,
          color: onSurfaceColor,
          fontFamily: 'SF Pro Display',
        ),
        titleMedium: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.1,
          color: onSurfaceColor,
          fontFamily: 'SF Pro Display',
        ),
        titleSmall: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.1,
          color: onSurfaceColor,
          fontFamily: 'SF Pro Display',
        ),
        bodyLarge: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          letterSpacing: 0.15,
          color: onSurfaceColor,
          fontFamily: 'SF Pro Display',
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          letterSpacing: 0.25,
          color: onBackgroundColor,
          fontFamily: 'SF Pro Display',
        ),
        bodySmall: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w400,
          letterSpacing: 0.4,
          color: Color(0xFF757575),
          fontFamily: 'SF Pro Display',
        ),
        labelLarge: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.1,
          color: onSurfaceColor,
          fontFamily: 'SF Pro Display',
        ),
        labelMedium: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
          color: onSurfaceColor,
          fontFamily: 'SF Pro Display',
        ),
        labelSmall: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
          color: onSurfaceColor,
          fontFamily: 'SF Pro Display',
        ),
      ),
      
      // Icon Theme
      iconTheme: const IconThemeData(
        color: onSurfaceColor,
        size: 24,
      ),
      
      // Divider Theme
      dividerTheme: const DividerThemeData(
        color: Color(0xFFE0E0E0),
        thickness: 1,
        space: 1,
      ),
      
      // Chip Theme
      chipTheme: ChipThemeData(
        backgroundColor: const Color(0xFFF5F5F5),
        selectedColor: primaryColor.withOpacity(0.12),
        disabledColor: const Color(0xFFE0E0E0),
        labelStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: onSurfaceColor,
          fontFamily: 'SF Pro Display',
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }
}

class AppInitializer extends StatefulWidget {
  const AppInitializer({super.key});

  @override
  State<AppInitializer> createState() => _AppInitializerState();
}

class _AppInitializerState extends State<AppInitializer> {
  bool _isInitialized = false;
  final AuthService _authService = AuthService();
  final AutoBackupService _autoBackupService = AutoBackupService();

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    try {
      // Extended welcome screen delay
      await Future.delayed(const Duration(seconds: 3));
      
      // Initialize auto backup service
      await _autoBackupService.initialize();
      
      setState(() {
        _isInitialized = true;
      });
    } catch (e) {
      print('Uygulama başlatılırken hata: $e');
      setState(() {
        _isInitialized = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return Scaffold(
        backgroundColor: Theme.of(context).colorScheme.background,
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Theme.of(context).colorScheme.primary.withOpacity(0.03),
                Theme.of(context).colorScheme.background,
              ],
            ),
          ),
          child: SafeArea(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo
                  Image.asset(
                    'assets/stock_new.png',
                    width: 100,
                    height: 100,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return Icon(
                        Icons.inventory_2_rounded,
                        size: 80,
                        color: Theme.of(context).colorScheme.primary,
                      );
                    },
                  ),
                  
                  const SizedBox(height: 32),
                  
                  // App Title
                  Text(
                    'Stoker',
                    style: Theme.of(context).textTheme.displayMedium?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                    ),
                  ),
                  
                  const SizedBox(height: 8),
                  
                  // Subtitle
                  Text(
                    'Profesyonel Stok Yönetimi',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                      fontWeight: FontWeight.w400,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  
                  const SizedBox(height: 48),
                  
                  // Loading Animation
                  SizedBox(
                    width: 32,
                    height: 32,
                    child: CircularProgressIndicator(
                      color: Theme.of(context).colorScheme.primary,
                      strokeWidth: 2.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    // Firebase Auth state'ini dinle
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          // Auth state yüklenirken loading göster
          return Scaffold(
            backgroundColor: Theme.of(context).colorScheme.background,
            body: const Center(child: CircularProgressIndicator()),
          );
        }
        
        final firebaseUser = snapshot.data;
        
        if (firebaseUser != null) {
          print('✅ Firebase Auth: Kullanıcı oturumu açık - ${firebaseUser.email}');
          // Kullanıcı giriş yapmış, HomeScreen'e yönlendir
          return const HomeScreen();
        } else {
          print('❌ Firebase Auth: Kullanıcı oturumu kapalı');
          // Kullanıcı giriş yapmamış, Login ekranına yönlendir
          return const LoginSelectionScreen();
        }
      },
    );
  }
}
