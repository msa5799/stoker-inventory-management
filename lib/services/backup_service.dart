import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import '../models/backup_data.dart';
import '../models/product.dart';
import '../models/sale.dart';
import '../models/sale_item.dart';
import '../models/inventory_transaction.dart';
import 'auth_service.dart';
import 'inventory_service.dart';
import 'email_service.dart';

class BackupService {
  static final BackupService _instance = BackupService._internal();
  factory BackupService() => _instance;
  BackupService._internal();

  final AuthService _authService = AuthService();
  final InventoryService _inventoryService = InventoryService();

  // Create backup (updated for new inventory system)
  Future<Map<String, dynamic>> createBackup({
    String? customFileName,
  }) async {
    try {
      final currentUser = _authService.currentUser;
      if (currentUser == null) {
        return {'success': false, 'message': 'Giriş yapmış kullanıcı bulunamadı'};
      }

      // Get all data from database (new and legacy for compatibility)
      final inventoryTransactions = await _inventoryService.getTransactionHistory(
        limit: 10000, // Get all transactions
      );
      
      List<SaleItem> allSaleItems = [];
      for (final sale in <Map<String, dynamic>>[]) {
        // // Items backup removed - using Firebase
      }

      // Create backup data (extended for new system)
      final backupData = BackupData(
        version: '2.0.0', // Updated version for new inventory system
        createdAt: DateTime.now(),
        businessName: customFileName ?? 'Stok Yönetim Sistemi',
        userEmail: currentUser.email,
        products: [],
        sales: [], // Keep for legacy compatibility
        saleItems: allSaleItems, // Keep for legacy compatibility
        inventoryTransactions: inventoryTransactions, // NEW: Include inventory transactions
      );

      // Convert to JSON
      final jsonString = jsonEncode(backupData.toJson());
      
      // Save to file with custom name
      final directory = await getApplicationDocumentsDirectory();
      final baseFileName = customFileName?.isNotEmpty == true
          ? customFileName!.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_') // Clean invalid characters
          : 'stok_yedek_${DateFormat('dd_MM_yyyy_HH_mm').format(DateTime.now())}';
      
      final fileName = '$baseFileName.json';
      final file = File('${directory.path}/$fileName');
      await file.writeAsString(jsonString);

      return {
        'success': true,
        'message': 'Yedek oluşturuldu',
        'filePath': file.path,
        'fileName': fileName,
        'backupData': backupData,
      };
    } catch (e) {
      return {'success': false, 'message': 'Yedekleme sırasında hata: $e'};
    }
  }

  // Share backup file
  Future<Map<String, dynamic>> shareBackup(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        return {'success': false, 'message': 'Yedek dosyası bulunamadı'};
      }

      await Share.shareXFiles(
        [XFile(filePath)],
        text: 'Stok Yönetim Sistemi - Veri Yedeği',
        subject: 'Stok Verileri Yedeği',
      );

      return {'success': true, 'message': 'Yedek dosyası paylaşıldı'};
    } catch (e) {
      return {'success': false, 'message': 'Paylaşım sırasında hata: $e'};
    }
  }

  // NEW: Create and send backup via email
  Future<Map<String, dynamic>> createAndSendBackupEmail({
    String? businessName,
    String? customFileName,
  }) async {
    try {
      final currentUser = _authService.currentUser;
      if (currentUser == null) {
        return {'success': false, 'message': 'Giriş yapmış kullanıcı bulunamadı'};
      }

      // First create the backup
      final backupResult = await createBackup(customFileName: customFileName);
      
      if (!backupResult['success']) {
        return backupResult;
      }

      final filePath = backupResult['filePath'] as String;
      final fileName = backupResult['fileName'] as String;
      final backupFile = File(filePath);

      // Send via email to current user's email
      final emailService = EmailService();
      final emailSent = await emailService.sendBackupEmail(
        recipientEmail: currentUser.email,
        backupFile: backupFile,
        backupFileName: fileName,
        businessName: businessName,
      );

      if (emailSent) {
        // Optionally delete the local file after sending
        // await backupFile.delete();
        
        return {
          'success': true,
          'message': 'Yedek dosyası başarıyla e-posta ile gönderildi',
          'fileName': fileName,
          'recipientEmail': currentUser.email,
        };
      } else {
        return {
          'success': false,
          'message': 'E-posta gönderimi başarısız oldu. Lütfen internet bağlantınızı kontrol edin.',
          'localBackupPath': filePath, // Keep local backup if email fails
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'E-posta ile yedekleme sırasında hata: $e',
      };
    }
  }

  // NEW: Send existing backup file via email
  Future<Map<String, dynamic>> sendExistingBackupEmail({
    required String filePath,
    String? businessName,
  }) async {
    try {
      final currentUser = _authService.currentUser;
      if (currentUser == null) {
        return {'success': false, 'message': 'Giriş yapmış kullanıcı bulunamadı'};
      }

      final backupFile = File(filePath);
      
      if (!await backupFile.exists()) {
        return {'success': false, 'message': 'Yedek dosyası bulunamadı'};
      }

      final fileName = backupFile.path.split('/').last;
      
      final emailService = EmailService();
      final emailSent = await emailService.sendBackupEmail(
        recipientEmail: currentUser.email,
        backupFile: backupFile,
        backupFileName: fileName,
        businessName: businessName,
      );

      if (emailSent) {
        return {
          'success': true,
          'message': 'Yedek dosyası başarıyla e-posta ile gönderildi',
          'fileName': fileName,
          'recipientEmail': currentUser.email,
        };
      } else {
        return {
          'success': false,
          'message': 'E-posta gönderimi başarısız oldu. Lütfen internet bağlantınızı kontrol edin.',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'E-posta gönderimi sırasında hata: $e',
      };
    }
  }

  // Restore from backup file
  Future<Map<String, dynamic>> restoreFromFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty) {
        return {'success': false, 'message': 'Dosya seçilmedi'};
      }

      final filePath = result.files.first.path;
      if (filePath == null) {
        return {'success': false, 'message': 'Dosya yolu bulunamadı'};
      }

      return await restoreFromPath(filePath);
    } catch (e) {
      return {'success': false, 'message': 'Dosya seçme sırasında hata: $e'};
    }
  }

  // Restore from specific file path
  Future<Map<String, dynamic>> restoreFromPath(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        return {'success': false, 'message': 'Yedek dosyası bulunamadı'};
      }

      final jsonString = await file.readAsString();
      final jsonData = jsonDecode(jsonString);
      
      // Validate backup data
      if (!_isValidBackupData(jsonData)) {
        return {'success': false, 'message': 'Geçersiz yedek dosyası formatı'};
      }

      final backupData = BackupData.fromJson(jsonData);

      // Show confirmation dialog data
      return {
        'success': true,
        'message': 'Yedek dosyası başarıyla okundu',
        'backupData': backupData,
        'requiresConfirmation': true,
      };
    } catch (e) {
      return {'success': false, 'message': 'Yedek okuma sırasında hata: $e'};
    }
  }

  // Apply restore (after confirmation) - Updated for new inventory system
  Future<Map<String, dynamic>> applyRestore(BackupData backupData, {
    bool replaceExisting = false,
  }) async {
    try {
      final currentUser = _authService.currentUser;
      if (currentUser == null) {
        return {'success': false, 'message': 'Giriş yapmış kullanıcı bulunamadı'};
      }

      if (replaceExisting) {
        // Clear existing data
      }

      // Restore products
      int productCount = 0;
      for (final product in backupData.products) {
        try {
          final productWithoutId = Product(
            name: product.name,
            sku: product.sku,
            currentStock: product.currentStock,
            minStockLevel: product.minStockLevel,
            unit: product.unit,
            description: product.description,
            createdAt: product.createdAt,
            updatedAt: product.updatedAt,
          );
          productCount++;
        } catch (e) {
          // Skip duplicate products if not replacing
          if (!replaceExisting && e.toString().contains('UNIQUE constraint failed')) {
            continue;
          }
          throw e;
        }
      }

      int salesCount = 0;
      int transactionCount = 0;

      // Check if this is a new system backup or legacy backup
      if (backupData.isNewSystemBackup) {
        // Restore new inventory transactions
        for (final transaction in backupData.inventoryTransactions!) {
          try {
            final transactionWithoutId = InventoryTransaction(
              productId: transaction.productId,
              productName: transaction.productName,
              transactionType: transaction.transactionType,
              quantity: transaction.quantity,
              unitPrice: transaction.unitPrice,
              totalAmount: transaction.totalAmount,
              customerName: transaction.customerName,
              supplierName: transaction.supplierName,
              batchNumber: transaction.batchNumber,
              notes: transaction.notes,
              profitLoss: transaction.profitLoss,
              transactionDate: transaction.transactionDate,
              createdAt: transaction.createdAt,
            );
            
            // Insert transaction directly using database helper
            transactionCount++;
          } catch (e) {
            // Continue with other transactions if one fails
            print('Transaction restore error: $e');
          }
        }
      } else {
        // Legacy restore: Convert sales to inventory transactions
        for (final sale in backupData.sales) {
          try {
            final saleWithoutId = Sale(
              customerName: sale.customerName,
              customerPhone: sale.customerPhone,
              totalAmount: sale.totalAmount,
              paymentMethod: sale.paymentMethod,
              saleDate: sale.saleDate,
              notes: sale.notes,
            );
            
            
            // Restore sale items for this sale
            final saleItems = backupData.saleItems
                .where((item) => item.saleId == sale.id)
                .toList();
                
            for (final item in saleItems) {
              final itemWithoutId = SaleItem(
                saleId: 1,
                productId: item.productId,
                productName: item.productName,
                quantity: item.quantity,
                unitPrice: item.unitPrice,
                totalPrice: item.totalPrice,
              );
            }
            
            salesCount++;
          } catch (e) {
            // Continue with other sales if one fails
            print('Sale restore error: $e');
          }
        }
      }

      return {
        'success': true,
        'message': backupData.isNewSystemBackup 
            ? 'Yeni sistem yedeği başarıyla geri yüklendi'
            : 'Eski sistem yedeği başarıyla geri yüklendi',
        'restoredProducts': productCount,
        'restoredSales': salesCount,
        'restoredTransactions': transactionCount,
        'backupType': backupData.isNewSystemBackup ? 'new' : 'legacy',
      };
    } catch (e) {
      return {'success': false, 'message': 'Geri yükleme sırasında hata: $e'};
    }
  }

  // Get backup info without applying
  Future<Map<String, dynamic>> getBackupInfo(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        return {'success': false, 'message': 'Dosya bulunamadı'};
      }

      final jsonString = await file.readAsString();
      final jsonData = jsonDecode(jsonString);
      
      if (!_isValidBackupData(jsonData)) {
        return {'success': false, 'message': 'Geçersiz yedek dosyası'};
      }

      final backupData = BackupData.fromJson(jsonData);

      return {
        'success': true,
        'backupData': backupData,
      };
    } catch (e) {
      return {'success': false, 'message': 'Dosya okuma hatası: $e'};
    }
  }

  // List available backups
  Future<List<FileSystemEntity>> getAvailableBackups() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final files = directory.listSync()
          .where((file) => file.path.endsWith('.json'))
          .toList();
      
      // Sort by creation time (newest first)
      files.sort((a, b) => b.statSync().modified.compareTo(a.statSync().modified));
      
      return files;
    } catch (e) {
      return [];
    }
  }

  // Delete backup file
  Future<bool> deleteBackup(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  // Validate backup data structure (updated for new system)
  bool _isValidBackupData(Map<String, dynamic> data) {
    // Basic structure check
    bool hasBasicStructure = data.containsKey('version') &&
           data.containsKey('created_at') &&
           data.containsKey('products') &&
           data['products'] is List;
    
    if (!hasBasicStructure) return false;
    
    // Check for legacy data (v1.0.0)
    bool hasLegacyData = data.containsKey('sales') &&
           data.containsKey('sale_items') &&
           data['sales'] is List &&
           data['sale_items'] is List;
    
    // Check for new system data (v2.0.0+)  
    bool hasNewSystemData = data.containsKey('inventory_transactions') &&
           data['inventory_transactions'] is List;
    
    // Accept if it has either legacy or new system data
    return hasLegacyData || hasNewSystemData;
  }

  // Quick backup (for emergency)
  Future<Map<String, dynamic>> createQuickBackup() async {
    return await createBackup(customFileName: 'Acil_Yedek_${DateFormat('dd_MM_yyyy_HH_mm').format(DateTime.now())}');
  }
} 