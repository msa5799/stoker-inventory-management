import 'dart:async';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'backup_service.dart';
import 'email_service.dart';
import 'auth_service.dart';

class AutoBackupService {
  static final AutoBackupService _instance = AutoBackupService._internal();
  factory AutoBackupService() => _instance;
  AutoBackupService._internal();

  final BackupService _backupService = BackupService();
  final EmailService _emailService = EmailService();
  final AuthService _authService = AuthService();
  
  Timer? _backupTimer;
  bool _isEnabled = false;
  
  // Auto backup intervals
  static const Duration dailyInterval = Duration(days: 1);
  static const Duration weeklyInterval = Duration(days: 7);
  static const Duration monthlyInterval = Duration(days: 30);

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    _isEnabled = prefs.getBool('auto_backup') ?? false;
    
    if (_isEnabled) {
      await _scheduleNextBackup();
    }
  }

  Future<void> enableAutoBackup() async {
    _isEnabled = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('auto_backup', true);
    await _scheduleNextBackup();
    print('✅ Otomatik yedekleme etkinleştirildi');
  }

  Future<void> disableAutoBackup() async {
    _isEnabled = false;
    _backupTimer?.cancel();
    _backupTimer = null;
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('auto_backup', false);
    await prefs.remove('last_auto_backup');
    await prefs.remove('next_backup_time');
    
    print('❌ Otomatik yedekleme devre dışı bırakıldı');
  }

  Future<void> _scheduleNextBackup() async {
    if (!_isEnabled) return;

    final prefs = await SharedPreferences.getInstance();
    final frequency = prefs.getString('backup_frequency') ?? 'daily';
    
    Duration interval;
    switch (frequency) {
      case 'weekly':
        interval = weeklyInterval;
        break;
      case 'monthly':
        interval = monthlyInterval;
        break;
      default:
        interval = dailyInterval;
    }

    // Son yedekleme zamanını kontrol et
    final lastBackupStr = prefs.getString('last_auto_backup');
    DateTime nextBackupTime;
    
    if (lastBackupStr != null) {
      final lastBackup = DateTime.parse(lastBackupStr);
      nextBackupTime = lastBackup.add(interval);
    } else {
      // İlk yedekleme için 1 saat sonra planla
      nextBackupTime = DateTime.now().add(const Duration(hours: 1));
    }

    // Eğer zaman geçmişse, hemen yedekleme yap
    if (nextBackupTime.isBefore(DateTime.now())) {
      await _performAutoBackup();
      return;
    }

    // Timer'ı ayarla
    final timeUntilBackup = nextBackupTime.difference(DateTime.now());
    _backupTimer?.cancel();
    _backupTimer = Timer(timeUntilBackup, _performAutoBackup);

    await prefs.setString('next_backup_time', nextBackupTime.toIso8601String());
    
    print('📅 Sonraki otomatik yedekleme: ${_formatDateTime(nextBackupTime)}');
  }

  Future<void> _performAutoBackup() async {
    if (!_isEnabled) return;

    try {
      print('🔄 Otomatik yedekleme başlatılıyor...');
      
      // Yedek oluştur
      final result = await _backupService.createBackup();
      
      if (result['success']) {
        final backupFile = result['file'] as File;
        
        // Son yedekleme zamanını kaydet
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('last_auto_backup', DateTime.now().toIso8601String());
        
        // E-posta ile gönder (eğer kullanıcı giriş yapmışsa)
        final user = _authService.currentUser;
        if (user != null) {
          final emailSent = await _emailService.sendBackupEmail(
            recipientEmail: user.email,
            backupFile: backupFile,
            backupFileName: backupFile.path.split('/').last,
            businessName: '${user.firstName} ${user.lastName}',
          );
          
          if (emailSent) {
            print('✅ Otomatik yedekleme tamamlandı ve e-posta gönderildi');
          } else {
            print('⚠️ Otomatik yedekleme tamamlandı ancak e-posta gönderilemedi');
          }
        } else {
          print('✅ Otomatik yedekleme tamamlandı (kullanıcı giriş yapmamış)');
        }
        
        // Sonraki yedeklemeyi planla
        await _scheduleNextBackup();
        
      } else {
        print('❌ Otomatik yedekleme başarısız: ${result['message']}');
        // Hata durumunda 1 saat sonra tekrar dene
        _backupTimer = Timer(const Duration(hours: 1), _performAutoBackup);
      }
    } catch (e) {
      print('❌ Otomatik yedekleme hatası: $e');
      // Hata durumunda 1 saat sonra tekrar dene
      _backupTimer = Timer(const Duration(hours: 1), _performAutoBackup);
    }
  }

  Future<void> setBackupFrequency(String frequency) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('backup_frequency', frequency);
    
    if (_isEnabled) {
      await _scheduleNextBackup();
    }
  }

  Future<String> getBackupFrequency() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('backup_frequency') ?? 'daily';
  }

  Future<DateTime?> getLastBackupTime() async {
    final prefs = await SharedPreferences.getInstance();
    final lastBackupStr = prefs.getString('last_auto_backup');
    if (lastBackupStr != null) {
      return DateTime.parse(lastBackupStr);
    }
    return null;
  }

  Future<DateTime?> getNextBackupTime() async {
    final prefs = await SharedPreferences.getInstance();
    final nextBackupStr = prefs.getString('next_backup_time');
    if (nextBackupStr != null) {
      return DateTime.parse(nextBackupStr);
    }
    return null;
  }

  Future<Map<String, dynamic>> getBackupStatus() async {
    final lastBackup = await getLastBackupTime();
    final nextBackup = await getNextBackupTime();
    final frequency = await getBackupFrequency();
    
    return {
      'enabled': _isEnabled,
      'frequency': frequency,
      'lastBackup': lastBackup,
      'nextBackup': nextBackup,
      'isRunning': _backupTimer?.isActive ?? false,
    };
  }

  Future<void> forceBackupNow() async {
    if (!_isEnabled) {
      throw Exception('Otomatik yedekleme etkin değil');
    }
    
    _backupTimer?.cancel();
    await _performAutoBackup();
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day.toString().padLeft(2, '0')}.'
           '${dateTime.month.toString().padLeft(2, '0')}.'
           '${dateTime.year} '
           '${dateTime.hour.toString().padLeft(2, '0')}:'
           '${dateTime.minute.toString().padLeft(2, '0')}';
  }

  String getFrequencyDisplayName(String frequency) {
    switch (frequency) {
      case 'daily':
        return 'Günlük';
      case 'weekly':
        return 'Haftalık';
      case 'monthly':
        return 'Aylık';
      default:
        return 'Günlük';
    }
  }

  void dispose() {
    _backupTimer?.cancel();
    _backupTimer = null;
  }
} 