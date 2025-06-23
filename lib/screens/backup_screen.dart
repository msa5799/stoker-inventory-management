import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import '../services/backup_service.dart';
import '../services/email_service.dart';
import '../services/auth_service.dart';
import '../services/subscription_service.dart';
import '../models/backup_data.dart';
import '../screens/subscription_screen.dart';
import 'auth/login_screen.dart';

class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key});

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  final BackupService _backupService = BackupService();
  final AuthService _authService = AuthService();
  final SubscriptionService _subscriptionService = SubscriptionService();
  final TextEditingController _fileNameController = TextEditingController();
  
  bool _isLoading = false;
  List<FileSystemEntity> _availableBackups = [];
  BackupData? _selectedBackupData;

  @override
  void initState() {
    super.initState();
    _loadAvailableBackups();
    // Otomatik dosya adı öneri
    _fileNameController.text = 'Yedek_${DateFormat('dd_MM_yyyy_HH_mm').format(DateTime.now())}';
  }

  @override
  void dispose() {
    _fileNameController.dispose();
    super.dispose();
  }

  Future<void> _loadAvailableBackups() async {
    final backups = await _backupService.getAvailableBackups();
    setState(() {
      _availableBackups = backups;
    });
  }

  Future<void> _createBackup() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final fileName = _fileNameController.text.trim().isEmpty
          ? null
          : _fileNameController.text.trim();

      final result = await _backupService.createBackup(
        customFileName: fileName,
      );

      if (result['success']) {
        _showMessage('Yedek başarıyla oluşturuldu!');
        _generateNewFileName(); // Yeni dosya adı öner
        await _loadAvailableBackups();
        
        // Show share option
        _showShareDialog(result['filePath'], result['fileName']);
      } else {
        _showMessage(result['message'], isError: true);
      }
    } catch (e) {
      _showMessage('Yedekleme hatası: $e', isError: true);
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _generateNewFileName() {
    _fileNameController.text = 'Yedek_${DateFormat('dd_MM_yyyy_HH_mm').format(DateTime.now())}';
  }

  Future<void> _shareBackup(String filePath) async {
    try {
      final result = await _backupService.shareBackup(filePath);
      if (!result['success']) {
        _showMessage(result['message'], isError: true);
      }
    } catch (e) {
      _showMessage('Paylaşım hatası: $e', isError: true);
    }
  }

  Future<void> _restoreFromFile() async {
    // Paid user kontrolü
    final isPaidUser = await _subscriptionService.isPaidUser();
    if (!isPaidUser) {
      _showPremiumRequired();
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final result = await _backupService.restoreFromFile();

      if (result['success'] && result['requiresConfirmation']) {
        final backupData = result['backupData'] as BackupData;
        setState(() {
          _selectedBackupData = backupData;
        });
        _showRestoreConfirmation(backupData);
      } else if (!result['success']) {
        _showMessage(result['message'], isError: true);
      }
    } catch (e) {
      _showMessage('Geri yükleme hatası: $e', isError: true);
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showPremiumRequired() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.diamond, color: Colors.amber),
            SizedBox(width: 8),
            Text('Premium Gerekli'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.backup, size: 64, color: Colors.orange),
            SizedBox(height: 16),
            Text(
              'Yedek veri yükleme özelliği sadece premium kullanıcılar için mevcuttur.',
              style: TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 12),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.shade300),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '💎 Premium Avantajları:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.amber.shade700,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text('• Yedek veri yükleme'),
                  Text('• Sınırsız kullanım'),
                  Text('• Öncelikli destek'),
                ],
              ),
            ),
            SizedBox(height: 16),
            Text(
              'Bu özellik, yeni hesap açılmasını ve ücretsiz deneme süresinin istismar edilmesini önlemek için premium kullanıcılara özeldir.',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                fontStyle: FontStyle.italic,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('İptal'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => SubscriptionScreen()),
              );
            },
            icon: Icon(Icons.diamond),
            label: Text('Premium Al'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber,
              foregroundColor: Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _applyRestore(BackupData backupData, bool replaceExisting) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final result = await _backupService.applyRestore(
        backupData,
        replaceExisting: replaceExisting,
      );

      if (result['success']) {
        String message = 'Geri yükleme tamamlandı!\n';
        message += 'Ürünler: ${result['restoredProducts']}\n';
        
        if (result['backupType'] == 'new') {
          message += 'İşlemler: ${result['restoredTransactions']}';
        } else {
          message += 'Satışlar: ${result['restoredSales']} (Eski sistem)';
        }
        
        _showMessage(message);
        await _loadAvailableBackups();
      } else {
        _showMessage(result['message'], isError: true);
      }
    } catch (e) {
      _showMessage('Geri yükleme hatası: $e', isError: true);
    } finally {
      setState(() {
        _isLoading = false;
        _selectedBackupData = null;
      });
    }
  }

  Future<void> _deleteBackup(String filePath) async {
    final confirmed = await _showDeleteConfirmation();
    if (!confirmed) return;

    final success = await _backupService.deleteBackup(filePath);
    if (success) {
      _showMessage('Yedek dosyası silindi');
      await _loadAvailableBackups();
    } else {
      _showMessage('Dosya silinirken hata oluştu', isError: true);
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        duration: Duration(seconds: isError ? 4 : 3),
      ),
    );
  }

  void _showShareDialog(String filePath, String fileName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Yedek Oluşturuldu'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Yedek dosyası başarıyla oluşturuldu.'),
            const SizedBox(height: 16),
            Text(
              'Dosya: $fileName',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Tamam'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _shareBackup(filePath);
            },
            icon: const Icon(Icons.share),
            label: const Text('Paylaş'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _sendBackupViaEmail(filePath);
            },
            icon: const Icon(Icons.email),
            label: const Text('E-posta Gönder'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
          ),
        ],
      ),
    );
  }

  Future<void> _sendBackupViaEmail(String filePath) async {
    final currentUser = AuthService().currentUser;
    if (currentUser == null) {
      _showMessage('Kullanıcı bilgisi bulunamadı', isError: true);
      return;
    }

    final confirmed = await EmailService.showBackupEmailConfirmation(context, currentUser.email);
    
    if (!confirmed) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final result = await _backupService.sendExistingBackupEmail(
        filePath: filePath,
        businessName: 'Stok Yönetim Sistemi',
      );

      if (result['success']) {
        _showMessage('✅ Yedek dosyası e-posta ile gönderildi!\nAlıcı: ${result['recipientEmail']}');
      } else {
        _showMessage(result['message'], isError: true);
      }
    } catch (e) {
      _showMessage('E-posta gönderimi hatası: $e', isError: true);
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _createAndSendBackupViaEmail() async {
    final currentUser = AuthService().currentUser;
    if (currentUser == null) {
      _showMessage('Kullanıcı bilgisi bulunamadı', isError: true);
      return;
    }

    final confirmed = await EmailService.showBackupEmailConfirmation(context, currentUser.email);
    
    if (!confirmed) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final fileName = _fileNameController.text.trim().isEmpty
          ? null
          : _fileNameController.text.trim();

      final result = await _backupService.createAndSendBackupEmail(
        businessName: 'Stok Yönetim Sistemi',
        customFileName: fileName,
      );

      if (result['success']) {
        _showMessage('✅ Yedek oluşturuldu ve e-posta ile gönderildi!\nDosya: ${result['fileName']}\nAlıcı: ${result['recipientEmail']}');
        _generateNewFileName(); // Yeni dosya adı öner
        await _loadAvailableBackups();
      } else {
        _showMessage(result['message'], isError: true);
        
        // If email failed but local backup exists, show option to share
        if (result.containsKey('localBackupPath')) {
          _showMessage('Yerel yedek oluşturuldu, ancak e-posta gönderilemedi. Paylaşım seçeneklerini kontrol edin.');
        }
      }
    } catch (e) {
      _showMessage('E-posta ile yedekleme hatası: $e', isError: true);
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showRestoreConfirmation(BackupData backupData) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Yedek Geri Yükleme'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Yedek Türü: ${backupData.isNewSystemBackup ? "Yeni Sistem" : "Eski Sistem"}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: backupData.isNewSystemBackup ? Colors.green : Colors.orange,
              ),
            ),
            const SizedBox(height: 12),
            const Text('Yedek dosyası bilgileri:'),
            const SizedBox(height: 12),
            _buildInfoRow('Dosya Adı', backupData.businessName),
            _buildInfoRow('Kullanıcı', backupData.userEmail),
            _buildInfoRow('Versiyon', backupData.version),
            _buildInfoRow('Tarih', DateFormat('dd/MM/yyyy HH:mm').format(backupData.createdAt)),
            _buildInfoRow('Ürün Sayısı', backupData.totalProducts.toString()),
            
            // Farklı veri türlerine göre bilgi göster
            if (backupData.isNewSystemBackup) ...[
              _buildInfoRow('İşlem Sayısı', backupData.totalInventoryTransactions.toString()),
              _buildInfoRow('Toplam Satış', '₺${backupData.totalInventorySalesAmount.toStringAsFixed(2)}'),
            ] else ...[
              _buildInfoRow('Satış Sayısı', backupData.totalSales.toString()),
              _buildInfoRow('Toplam Satış', '₺${backupData.totalSalesAmount.toStringAsFixed(2)}'),
            ],
            
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: backupData.isNewSystemBackup ? Colors.green.shade50 : Colors.orange.shade50,
                border: Border.all(
                  color: backupData.isNewSystemBackup ? Colors.green : Colors.orange,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                backupData.isNewSystemBackup
                    ? '✓ Bu yedek yeni envanter sistemi ile uyumludur'
                    : '⚠️ Bu eski sistem yedeği. Veriler uyumlu hale getirilecek.',
                style: TextStyle(
                  fontSize: 12,
                  color: backupData.isNewSystemBackup ? Colors.green.shade700 : Colors.orange.shade700,
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Mevcut veriler ile birleştirmek istiyor musunuz?',
              style: TextStyle(fontWeight: FontWeight.bold),
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
              _applyRestore(backupData, true);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Değiştir'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _applyRestore(backupData, false);
            },
            child: const Text('Birleştir'),
          ),
        ],
      ),
    );
  }

  Future<bool> _showDeleteConfirmation() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Yedek Silme'),
        content: const Text('Bu yedek dosyasını silmek istediğinizden emin misiniz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  String _formatFileDate(DateTime date) {
    return DateFormat('dd/MM/yyyy HH:mm').format(date);
  }

  String _getFileName(String path) {
    return path.split('/').last;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: AppBar(
        title: const Text('Yedekleme'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Create Backup Section
                  Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  Icons.backup,
                                  color: Theme.of(context).colorScheme.primary,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'Yeni Yedek Oluştur',
                                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: Theme.of(context).colorScheme.onSurface,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          TextField(
                            controller: _fileNameController,
                            decoration: InputDecoration(
                              labelText: 'Dosya Adı (Opsiyonel)',
                              hintText: 'Örn: Yedek_2024_04_01_12_00',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              filled: true,
                              fillColor: Theme.of(context).colorScheme.background,
                            ),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: _createBackup,
                            icon: const Icon(Icons.save),
                            label: const Text('Yedek Oluştur'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Theme.of(context).colorScheme.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton.icon(
                            onPressed: _createAndSendBackupViaEmail,
                            icon: const Icon(Icons.email),
                            label: const Text('Oluştur ve E-posta Gönder'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Restore Section
                  Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.green.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(
                                  Icons.restore,
                                  color: Colors.green,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'Yedek Geri Yükle',
                                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: Theme.of(context).colorScheme.onSurface,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          ElevatedButton.icon(
                            onPressed: _restoreFromFile,
                            icon: const Icon(Icons.file_upload),
                            label: const Text('Dosyadan Geri Yükle'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Available Backups Section
                  Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.orange.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(
                                  Icons.folder,
                                  color: Colors.orange,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'Mevcut Yedekler',
                                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: Theme.of(context).colorScheme.onSurface,
                                ),
                              ),
                              const Spacer(),
                              IconButton(
                                onPressed: _loadAvailableBackups,
                                icon: Icon(
                                  Icons.refresh,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                                style: IconButton.styleFrom(
                                  backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          if (_availableBackups.isEmpty)
                            Container(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.folder_off,
                                    size: 48,
                                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    'Henüz yedek dosyası bulunamadı',
                                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            )
                          else
                            Column(
                              children: _availableBackups.asMap().entries.map((entry) {
                                final index = entry.key;
                                final backup = entry.value;
                                final fileName = _getFileName(backup.path);
                                final fileStat = backup.statSync();
                                
                                return Container(
                                  margin: EdgeInsets.only(
                                    bottom: index < _availableBackups.length - 1 ? 12 : 0,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).colorScheme.background,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
                                    ),
                                  ),
                                  child: ListTile(
                                    contentPadding: const EdgeInsets.all(16),
                                    leading: Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Theme.of(context).colorScheme.secondary.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Icon(
                                        Icons.description,
                                        color: Theme.of(context).colorScheme.secondary,
                                      ),
                                    ),
                                    title: Text(
                                      fileName,
                                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    subtitle: Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Boyut: ${(fileStat.size / 1024).toStringAsFixed(1)} KB',
                                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                                            ),
                                          ),
                                          Text(
                                            'Tarih: ${_formatFileDate(fileStat.modified)}',
                                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    trailing: PopupMenuButton(
                                      icon: Icon(
                                        Icons.more_vert,
                                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                                      ),
                                      itemBuilder: (context) => [
                                        const PopupMenuItem(
                                          value: 'share',
                                          child: Row(
                                            children: [
                                              Icon(Icons.share),
                                              SizedBox(width: 8),
                                              Text('Paylaş'),
                                            ],
                                          ),
                                        ),
                                        const PopupMenuItem(
                                          value: 'email',
                                          child: Row(
                                            children: [
                                              Icon(Icons.email, color: Colors.green),
                                              SizedBox(width: 8),
                                              Text('E-posta Gönder'),
                                            ],
                                          ),
                                        ),
                                        const PopupMenuItem(
                                          value: 'restore',
                                          child: Row(
                                            children: [
                                              Icon(Icons.restore),
                                              SizedBox(width: 8),
                                              Text('Geri Yükle'),
                                            ],
                                          ),
                                        ),
                                        const PopupMenuItem(
                                          value: 'delete',
                                          child: Row(
                                            children: [
                                              Icon(Icons.delete, color: Colors.red),
                                              SizedBox(width: 8),
                                              Text('Sil', style: TextStyle(color: Colors.red)),
                                            ],
                                          ),
                                        ),
                                      ],
                                      onSelected: (value) async {
                                        switch (value) {
                                          case 'share':
                                            await _shareBackup(backup.path);
                                            break;
                                          case 'email':
                                            await _sendBackupViaEmail(backup.path);
                                            break;
                                          case 'restore':
                                            // Paid user kontrolü
                                            final isPaidUser = await _subscriptionService.isPaidUser();
                                            if (!isPaidUser) {
                                              _showPremiumRequired();
                                              return;
                                            }
                                            
                                            final result = await _backupService.restoreFromPath(backup.path);
                                            if (result['success'] && result['requiresConfirmation']) {
                                              final backupData = result['backupData'] as BackupData;
                                              _showRestoreConfirmation(backupData);
                                            }
                                            break;
                                          case 'delete':
                                            await _deleteBackup(backup.path);
                                            break;
                                        }
                                      },
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
} 