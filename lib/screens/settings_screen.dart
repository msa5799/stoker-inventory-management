import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auto_backup_service.dart';
import '../services/notification_service.dart';
import '../services/firebase_service.dart';
import 'backup_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final AutoBackupService _autoBackupService = AutoBackupService();
  final NotificationService _notificationService = NotificationService();
  final FirebaseService _firebaseService = FirebaseService();
  
  bool _notificationsEnabled = true;
  bool _lowStockAlerts = true;
  bool _dailyReports = false;
  bool _autoBackup = false;
  String _currency = 'TRY';
  String _language = 'tr';
  String _backupFrequency = 'daily';
  DateTime? _lastBackupTime;
  DateTime? _nextBackupTime;
  TimeOfDay _notificationTime = const TimeOfDay(hour: 18, minute: 0); // Varsayılan 18:00
  
  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final backupStatus = await _autoBackupService.getBackupStatus();
    final notificationsEnabled = await _notificationService.areNotificationsEnabled();
    
    // Bildirim zamanını yükle
    final notificationHour = prefs.getInt('notification_hour') ?? 18;
    final notificationMinute = prefs.getInt('notification_minute') ?? 0;
    
    setState(() {
      _notificationsEnabled = notificationsEnabled;
      _lowStockAlerts = prefs.getBool('low_stock_alerts') ?? true;
      _dailyReports = prefs.getBool('daily_reports') ?? false;
      _autoBackup = backupStatus['enabled'] ?? false;
      _currency = prefs.getString('currency') ?? 'TRY';
      _language = prefs.getString('language') ?? 'tr';
      _backupFrequency = backupStatus['frequency'] ?? 'daily';
      _lastBackupTime = backupStatus['lastBackup'];
      _nextBackupTime = backupStatus['nextBackup'];
      _notificationTime = TimeOfDay(hour: notificationHour, minute: notificationMinute);
    });
  }

  Future<void> _saveSetting(String key, dynamic value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value is bool) {
      await prefs.setBool(key, value);
    } else if (value is String) {
      await prefs.setString(key, value);
    }
  }

  Future<void> _toggleAutoBackup(bool value) async {
    try {
      if (value) {
        await _autoBackupService.enableAutoBackup();
      } else {
        await _autoBackupService.disableAutoBackup();
      }
      
      setState(() {
        _autoBackup = value;
      });
      
      // Reload backup status
      await _loadSettings();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(value 
              ? 'Otomatik yedekleme etkinleştirildi' 
              : 'Otomatik yedekleme devre dışı bırakıldı'
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hata: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _toggleNotifications(bool value) async {
    try {
      if (value) {
        // İzin kontrolü
        final hasPermission = await _notificationService.hasPermission();
        if (!hasPermission) {
          final granted = await _notificationService.requestPermission();
          if (!granted) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Bildirim izni verilmedi'),
                  backgroundColor: Colors.orange,
                ),
              );
            }
            return;
          }
        }
      }
      
      await _notificationService.setNotificationsEnabled(value);
      
      setState(() {
        _notificationsEnabled = value;
      });
      
      // Bildirimler açıldığında günlük bildirimi zamanla
      if (value) {
        await _notificationService.scheduleDailyAnalyticsNotification(_notificationTime);
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(value 
              ? 'Bildirimler etkinleştirildi. Günlük rapor ${_notificationTime.format(context)} saatinde gelecek.' 
              : 'Bildirimler devre dışı bırakıldı'
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hata: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showBackupFrequencyDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Yedekleme Sıklığı'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<String>(
              title: const Text('Günlük'),
              subtitle: const Text('Her gün otomatik yedekleme'),
              value: 'daily',
              groupValue: _backupFrequency,
              onChanged: (value) async {
                await _autoBackupService.setBackupFrequency(value!);
                setState(() {
                  _backupFrequency = value;
                });
                Navigator.pop(context);
                await _loadSettings();
              },
            ),
            RadioListTile<String>(
              title: const Text('Haftalık'),
              subtitle: const Text('Her hafta otomatik yedekleme'),
              value: 'weekly',
              groupValue: _backupFrequency,
              onChanged: (value) async {
                await _autoBackupService.setBackupFrequency(value!);
                setState(() {
                  _backupFrequency = value;
                });
                Navigator.pop(context);
                await _loadSettings();
              },
            ),
            RadioListTile<String>(
              title: const Text('Aylık'),
              subtitle: const Text('Her ay otomatik yedekleme'),
              value: 'monthly',
              groupValue: _backupFrequency,
              onChanged: (value) async {
                await _autoBackupService.setBackupFrequency(value!);
                setState(() {
                  _backupFrequency = value;
                });
                Navigator.pop(context);
                await _loadSettings();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _forceBackupNow() async {
    if (!_autoBackup) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Önce otomatik yedeklemeyi etkinleştirin'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Text('Yedekleme yapılıyor...'),
            ],
          ),
        ),
      );

      await _autoBackupService.forceBackupNow();
      
      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        await _loadSettings(); // Reload status
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Yedekleme başarıyla tamamlandı'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Yedekleme hatası: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showClearDataDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.red),
            SizedBox(width: 8),
            Text('Veri Temizleme'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Hangi verileri silmek istiyorsunuz?',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            SizedBox(height: 16),
            Text(
              '⚠️ Bu işlem geri alınamaz!',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600),
            ),
            SizedBox(height: 8),
            Text(
              'Kullanıcı hesapları ve abonelik bilgileri korunacak.',
              style: TextStyle(color: Colors.green),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _showDataDeletionOptions();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Devam Et'),
          ),
        ],
      ),
    );
  }

  void _showDataDeletionOptions() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Silme Seçenekleri'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.delete_sweep, color: Colors.red),
              title: const Text('Tüm Envanter Verilerini Sil'),
              subtitle: const Text('Ürünler, satışlar, stok lotları, işlemler'),
              onTap: () {
                Navigator.pop(context);
                _confirmDeleteAllData();
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.inventory, color: Colors.orange),
              title: const Text('Sadece Ürünleri Sil'),
              subtitle: const Text('Tüm ürün kayıtları'),
              onTap: () {
                Navigator.pop(context);
                _confirmDeleteProducts();
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.receipt_long, color: Colors.orange),
              title: const Text('Sadece İşlemleri Sil'),
              subtitle: const Text('Satış, alış, iade kayıtları'),
              onTap: () {
                Navigator.pop(context);
                _confirmDeleteTransactions();
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.layers, color: Colors.orange),
              title: const Text('Sadece Stok Lotlarını Sil'),
              subtitle: const Text('Tüm stok lot kayıtları'),
              onTap: () {
                Navigator.pop(context);
                _confirmDeleteStockLots();
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteAllData() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.error, color: Colors.red),
            SizedBox(width: 8),
            Text('Son Uyarı!'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'TÜM ENVANTER VERİLERİNİZ SİLİNECEK:',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
            ),
            SizedBox(height: 8),
            Text('• Tüm ürünler'),
            Text('• Tüm satış kayıtları'),
            Text('• Tüm alış kayıtları'),
            Text('• Tüm iade kayıtları'),
            Text('• Tüm stok lotları'),
            Text('• Tüm analiz verileri'),
            SizedBox(height: 16),
            Text(
              'Bu işlem GERİ ALINAMAZ!',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteAllInventoryData();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('TÜM VERİLERİ SİL'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteProducts() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ürünleri Sil'),
        content: const Text('Tüm ürün kayıtları silinecek. Bu işlem geri alınamaz!'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteProducts();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            child: const Text('Ürünleri Sil'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteTransactions() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('İşlemleri Sil'),
        content: const Text('Tüm satış, alış ve iade kayıtları silinecek. Bu işlem geri alınamaz!'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteTransactions();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            child: const Text('İşlemleri Sil'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteStockLots() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Stok Lotlarını Sil'),
        content: const Text('Tüm stok lot kayıtları silinecek. Bu işlem geri alınamaz!'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteStockLots();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            child: const Text('Stok Lotlarını Sil'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteAllInventoryData() async {
    _showLoadingDialog('Tüm veriler siliniyor...');
    
    try {
      final result = await FirebaseService.deleteAllInventoryData();
      
      Navigator.pop(context); // Loading dialog'u kapat
      
      if (result['success']) {
        _showSuccessDialog(
          'Başarılı!',
          'Tüm envanter verileri başarıyla silindi.\n'
          'Silinen kayıt sayısı: ${result['deletedCount']}'
        );
      } else {
        _showErrorDialog('Hata!', result['message']);
      }
    } catch (e) {
      Navigator.pop(context); // Loading dialog'u kapat
      _showErrorDialog('Hata!', 'Veri silme sırasında hata oluştu: $e');
    }
  }

  Future<void> _deleteProducts() async {
    _showLoadingDialog('Ürünler siliniyor...');
    
    try {
      final result = await FirebaseService.deleteAllProducts();
      
      Navigator.pop(context); // Loading dialog'u kapat
      
      if (result['success']) {
        _showSuccessDialog('Başarılı!', result['message']);
      } else {
        _showErrorDialog('Hata!', result['message']);
      }
    } catch (e) {
      Navigator.pop(context); // Loading dialog'u kapat
      _showErrorDialog('Hata!', 'Ürün silme sırasında hata oluştu: $e');
    }
  }

  Future<void> _deleteTransactions() async {
    _showLoadingDialog('İşlemler siliniyor...');
    
    try {
      final result = await FirebaseService.deleteAllTransactions();
      
      Navigator.pop(context); // Loading dialog'u kapat
      
      if (result['success']) {
        _showSuccessDialog('Başarılı!', result['message']);
      } else {
        _showErrorDialog('Hata!', result['message']);
      }
    } catch (e) {
      Navigator.pop(context); // Loading dialog'u kapat
      _showErrorDialog('Hata!', 'İşlem silme sırasında hata oluştu: $e');
    }
  }

  Future<void> _deleteStockLots() async {
    _showLoadingDialog('Stok lotları siliniyor...');
    
    try {
      final result = await FirebaseService.deleteAllStockLots();
      
      Navigator.pop(context); // Loading dialog'u kapat
      
      if (result['success']) {
        _showSuccessDialog('Başarılı!', result['message']);
      } else {
        _showErrorDialog('Hata!', result['message']);
      }
    } catch (e) {
      Navigator.pop(context); // Loading dialog'u kapat
      _showErrorDialog('Hata!', 'Stok lotu silme sırasında hata oluştu: $e');
    }
  }

  void _showLoadingDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Row(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(width: 20),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
  }

  void _showSuccessDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.green),
            const SizedBox(width: 8),
            Text(title),
          ],
        ),
        content: Text(message),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Tamam'),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.error, color: Colors.red),
            const SizedBox(width: 8),
            Text(title),
          ],
        ),
        content: Text(message),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Tamam'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Uygulama Ayarları'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildNotificationSettings(),
          const SizedBox(height: 16),
          _buildGeneralSettings(),
          const SizedBox(height: 16),
          _buildDataSettings(),
          const SizedBox(height: 16),
          _buildAboutSection(),
        ],
      ),
    );
  }

  Widget _buildNotificationSettings() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Bildirimler',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            
            SwitchListTile(
              title: const Text('Bildirimleri Etkinleştir'),
              subtitle: const Text('Uygulama bildirimlerini al'),
              value: _notificationsEnabled,
              onChanged: _toggleNotifications,
            ),
            
            // Bildirim zamanı seçici - Bildirimler açıkken her zaman göster
            if (_notificationsEnabled) ...[
              const Divider(),
              ListTile(
                leading: const Icon(Icons.schedule),
                title: const Text('Günlük Bildirim Zamanı'),
                subtitle: Text('Her gün ${_notificationTime.format(context)} saatinde günlük rapor'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: _selectNotificationTime,
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.send),
                title: const Text('Test Bildirimi Gönder'),
                subtitle: const Text('Günlük rapor bildirimini şimdi test et'),
                trailing: const Icon(Icons.play_arrow),
                onTap: _sendTestNotification,
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.warning, color: Colors.orange),
                title: const Text('Düşük Stok Kontrolü'),
                subtitle: const Text('Düşük stokta olan ürünleri kontrol et'),
                trailing: const Icon(Icons.inventory),
                onTap: _checkLowStock,
              ),
            ],
            
            SwitchListTile(
              title: const Text('Düşük Stok Uyarıları'),
              subtitle: const Text('Stok azaldığında bildirim al'),
              value: _lowStockAlerts,
              onChanged: _notificationsEnabled ? (value) {
                setState(() {
                  _lowStockAlerts = value;
                });
                _saveSetting('low_stock_alerts', value);
              } : null,
            ),
            
            SwitchListTile(
              title: const Text('Günlük Raporlar'),
              subtitle: const Text('Günlük satış raporlarını al'),
              value: _dailyReports,
              onChanged: _notificationsEnabled ? (value) async {
                setState(() {
                  _dailyReports = value;
                });
                await _saveSetting('daily_reports', value);
                
                // Günlük raporlar açıldığında bildirim zamanla
                if (value) {
                  await _notificationService.scheduleDailyAnalyticsNotification(_notificationTime);
                } else {
                  await _notificationService.cancelDailyAnalyticsNotification();
                }
              } : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGeneralSettings() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Genel Ayarlar',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            
            ListTile(
              leading: const Icon(Icons.monetization_on_outlined),
              title: const Text('Para Birimi'),
              subtitle: Text(_getCurrencyName(_currency)),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () => _showCurrencyDialog(),
            ),
            
            const Divider(),
            
            ListTile(
              leading: const Icon(Icons.language_outlined),
              title: const Text('Dil'),
              subtitle: Text(_getLanguageName(_language)),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () => _showLanguageDialog(),
            ),
            
            const Divider(),
            
            // Otomatik Yedekleme Ana Switch
            SwitchListTile(
              title: const Text('Otomatik Yedekleme'),
              subtitle: Text(_autoBackup 
                ? 'Etkin - ${_autoBackupService.getFrequencyDisplayName(_backupFrequency)}'
                : 'Devre dışı'
              ),
              value: _autoBackup,
              onChanged: _toggleAutoBackup,
            ),
            
            // Otomatik yedekleme etkinse ek ayarları göster
            if (_autoBackup) ...[
              const Divider(),
              
              ListTile(
                leading: const Icon(Icons.schedule_outlined),
                title: const Text('Yedekleme Sıklığı'),
                subtitle: Text(_autoBackupService.getFrequencyDisplayName(_backupFrequency)),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: _showBackupFrequencyDialog,
              ),
              
              if (_lastBackupTime != null) ...[
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.history_outlined),
                  title: const Text('Son Yedekleme'),
                  subtitle: Text(_formatDateTime(_lastBackupTime!)),
                ),
              ],
              
              if (_nextBackupTime != null) ...[
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.schedule_send_outlined),
                  title: const Text('Sonraki Yedekleme'),
                  subtitle: Text(_formatDateTime(_nextBackupTime!)),
                ),
              ],
              
              const Divider(),
              
              ListTile(
                leading: const Icon(Icons.backup_outlined),
                title: const Text('Şimdi Yedekle'),
                subtitle: const Text('Manuel yedekleme başlat'),
                trailing: const Icon(Icons.play_arrow),
                onTap: _forceBackupNow,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDataSettings() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Veri Yönetimi',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            
            ListTile(
              leading: const Icon(Icons.backup_outlined),
              title: const Text('Manuel Yedekleme'),
              subtitle: const Text('Verilerinizi manuel olarak yedekleyin'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const BackupScreen()),
                );
              },
            ),
            
            const Divider(),
            
            ListTile(
              leading: const Icon(Icons.restore_outlined),
              title: const Text('Geri Yükleme'),
              subtitle: const Text('Yedekten geri yükle'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const BackupScreen()),
                );
              },
            ),
            
            const Divider(),
            
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('Verileri Temizle', style: TextStyle(color: Colors.red)),
              subtitle: const Text('Tüm verileri sil'),
              onTap: _showClearDataDialog,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAboutSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Hakkında',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('Uygulama Sürümü'),
              subtitle: const Text('v1.0.0'),
            ),
            
            const Divider(),
            
            ListTile(
              leading: const Icon(Icons.help_outline),
              title: const Text('Yardım & Destek'),
              subtitle: const Text('Kullanım kılavuzu ve destek'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Yardım sayfası yakında eklenecek')),
                );
              },
            ),
            
            const Divider(),
            
            ListTile(
              leading: const Icon(Icons.privacy_tip_outlined),
              title: const Text('Gizlilik Politikası'),
              subtitle: const Text('Veri kullanım politikamız'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Gizlilik politikası yakında eklenecek')),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showCurrencyDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Para Birimi Seçin'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<String>(
              title: const Text('Türk Lirası (₺)'),
              value: 'TRY',
              groupValue: _currency,
              onChanged: (value) {
                setState(() {
                  _currency = value!;
                });
                _saveSetting('currency', value!);
                Navigator.pop(context);
              },
            ),
            RadioListTile<String>(
              title: const Text('Amerikan Doları (\$)'),
              value: 'USD',
              groupValue: _currency,
              onChanged: (value) {
                setState(() {
                  _currency = value!;
                });
                _saveSetting('currency', value!);
                Navigator.pop(context);
              },
            ),
            RadioListTile<String>(
              title: const Text('Euro (€)'),
              value: 'EUR',
              groupValue: _currency,
              onChanged: (value) {
                setState(() {
                  _currency = value!;
                });
                _saveSetting('currency', value!);
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showLanguageDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Dil Seçin'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<String>(
              title: const Text('Türkçe'),
              value: 'tr',
              groupValue: _language,
              onChanged: (value) {
                setState(() {
                  _language = value!;
                });
                _saveSetting('language', value!);
                Navigator.pop(context);
              },
            ),
            RadioListTile<String>(
              title: const Text('English'),
              value: 'en',
              groupValue: _language,
              onChanged: (value) {
                setState(() {
                  _language = value!;
                });
                _saveSetting('language', value!);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('İngilizce dil desteği yakında eklenecek')),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  String _getCurrencyName(String currency) {
    switch (currency) {
      case 'TRY':
        return 'Türk Lirası (₺)';
      case 'USD':
        return 'Amerikan Doları (\$)';
      case 'EUR':
        return 'Euro (€)';
      default:
        return 'Türk Lirası (₺)';
    }
  }

  String _getLanguageName(String language) {
    switch (language) {
      case 'tr':
        return 'Türkçe';
      case 'en':
        return 'English';
      default:
        return 'Türkçe';
    }
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day.toString().padLeft(2, '0')}.'
           '${dateTime.month.toString().padLeft(2, '0')}.'
           '${dateTime.year} '
           '${dateTime.hour.toString().padLeft(2, '0')}:'
           '${dateTime.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _selectNotificationTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _notificationTime,
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: child!,
        );
      },
    );
    
    if (picked != null && picked != _notificationTime) {
      setState(() {
        _notificationTime = picked;
      });
      
      // Zamanı kaydet
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('notification_hour', picked.hour);
      await prefs.setInt('notification_minute', picked.minute);
      
      // Bildirim servisine zamanı güncelle
      await _notificationService.scheduleDailyAnalyticsNotification(_notificationTime);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Günlük bildirim zamanı ${picked.format(context)} olarak ayarlandı'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  Future<void> _sendTestNotification() async {
    try {
      await _notificationService.sendTestNotification();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Test bildirimi başarıyla gönderildi'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hata: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _checkLowStock() async {
    try {
      final result = await _notificationService.checkAndNotifyLowStock();
      
      if (mounted) {
        if (result['success']) {
          final lowStockCount = result['lowStockCount'] as int;
          final lowStockProducts = result['lowStockProducts'] as List;
          
          if (lowStockCount == 0) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('✅ Tüm ürünlerin stok seviyeleri normal'),
                backgroundColor: Colors.green,
              ),
            );
          } else {
            String message = '⚠️ ${lowStockCount} üründe düşük stok tespit edildi';
            if (lowStockCount <= 3) {
              final productNames = lowStockProducts.map((p) => p['name']).join(', ');
              message += ':\n$productNames';
            }
            
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(message),
                backgroundColor: Colors.orange,
                duration: const Duration(seconds: 4),
              ),
            );
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Hata: ${result['error']}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hata: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
} 