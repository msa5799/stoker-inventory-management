import 'package:flutter/foundation.dart';
import '../services/firebase_service.dart';
import '../services/sync_service.dart';
import '../models/inventory_transaction.dart';
import '../models/product.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class InventoryService {
  static final InventoryService _instance = InventoryService._internal();
  factory InventoryService() => _instance;
  InventoryService._internal();

  // **ATOMIC TRANSACTION WRAPPER**
  Future<T> executeAtomicOperation<T>(
    Future<T> Function(WriteBatch batch, FirebaseFirestore firestore) operation,
  ) async {
    final firestore = FirebaseFirestore.instance;
    final batch = firestore.batch();
    
    try {
      print('🔄 Atomik işlem başlatılıyor...');
      
      // İşlemi batch içinde çalıştır
      final result = await operation(batch, firestore);
      
      // Tüm değişiklikleri tek seferde commit et
      await batch.commit();
      
      print('✅ Atomik işlem başarıyla tamamlandı');
      return result;
      
    } catch (e) {
      print('❌ Atomik işlem başarısız, rollback yapılıyor: $e');
      // Batch otomatik rollback yapar, ek bir şey yapmaya gerek yok
      rethrow;
    }
  }
  
  // **TRANSACTION İLE STOK KONTROLÜ VE GÜNCELLEME**
  Future<bool> checkAndUpdateStockAtomic({
    required String productId,
    required int quantityChange, // Pozitif: artış, Negatif: azalış
    required String operationType,
  }) async {
    final firestore = FirebaseFirestore.instance;
    
    return await firestore.runTransaction<bool>((transaction) async {
      // Önce mevcut stok durumunu oku
      final productRef = firestore.collection('products').doc(productId);
      final productDoc = await transaction.get(productRef);
      
      if (!productDoc.exists) {
        throw Exception('Ürün bulunamadı: $productId');
      }
      
      final currentStock = productDoc.data()!['current_stock'] as int? ?? 0;
      final newStock = currentStock + quantityChange;
      
      // Stok kontrolü
      if (newStock < 0) {
        throw Exception('Yetersiz stok! Mevcut: $currentStock, Talep edilen: ${quantityChange.abs()}');
      }
      
      // Stok güncelle
      transaction.update(productRef, {
        'current_stock': newStock,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      print('📦 Stok güncellendi: $currentStock → $newStock ($operationType)');
      return true;
    });
  }

  // **1. SATIN ALMA İŞLEMİ**
  Future<void> addPurchase({
    required String productId,
    required String productName,
    required int quantity,
    required double unitPrice,
    String? supplierName,
    String? batchNumber,
    String? notes,
    DateTime? transactionDate,
  }) async {
    final now = DateTime.now();
    final transDate = transactionDate ?? now;
    
    // Batch numarası yoksa otomatik oluştur
    final batch = batchNumber ?? 'LOT-${transDate.millisecondsSinceEpoch}';
    
    try {
      print('🛒 Satın alma işlemi başlatılıyor: $quantity adet $productName');
      
      // 1. Envanter işlemi kaydet
      final transactionData = {
        'product_id': productId,
        'product_name': productName,
        'transaction_type': 'PURCHASE',
        'quantity': quantity,
        'unit_price': unitPrice,
        'total_amount': quantity * unitPrice,
        'batch_number': batch,
        'supplier_name': supplierName,
        'notes': notes,
        'transaction_date': transDate,
        'profit_loss': 0.0, // Satın alma için kar/zarar yok
      };

      final transactionResult = await FirebaseService.addInventoryTransaction(transactionData);
      if (!transactionResult['success']) {
        throw Exception(transactionResult['message']);
      }

      // 2. Stok lot'u oluştur (FIFO için)
      final lotData = {
        'product_id': productId,
        'batch_number': batch,
        'purchase_price': unitPrice,
        'original_quantity': quantity,
        'remaining_quantity': quantity,
        'purchase_date': transDate,
        'supplier_name': supplierName,
      };

      final lotResult = await FirebaseService.addStockLot(lotData);
      if (!lotResult['success']) {
        throw Exception(lotResult['message']);
      }

      // 3. Ürün stokunu güncelle
      final product = await FirebaseService.getProduct(productId);
      if (product != null) {
        final currentStock = product['current_stock'] ?? 0;
        final newStock = currentStock + quantity;
        
        await FirebaseService.updateProductStock(productId, newStock);
      }

      // 4. Senkronizasyonu tetikle

      print('✅ Satın alma işlemi tamamlandı: $quantity adet $productName');
    } catch (e) {
      print('❌ Satın alma işlemi hatası: $e');
      throw Exception('Satın alma işlemi başarısız: $e');
    }
  }

  // **2. SATIŞ İŞLEMİ** - Atomik (Tek Transaction)
  Future<void> addSale({
    required String productId,
    required String productName,
    required int quantity,
    required double unitPrice,
    String? customerName,
    String? notes,
    DateTime? transactionDate,
  }) async {
    final now = DateTime.now();
    final transDate = transactionDate ?? now;
    final firestore = FirebaseFirestore.instance;
    
    try {
      print('🛒 Satış işlemi başlatılıyor: $quantity adet $productName');
      print('🔄 Atomik işlem başlatılıyor...');
      
      // Organizasyon ID'sini al
      final organizationId = await FirebaseService.getCurrentUserOrganizationId();
      if (organizationId == null) {
        throw Exception('Organizasyon bulunamadı');
      }
      
      // Tek transaction ile tüm işlemleri yap
      await firestore.runTransaction<void>((transaction) async {
        // 1. Ürün kontrolü ve stok güncelleme (organizasyon yapısı ile)
        final productRef = firestore
            .collection('organizations')
            .doc(organizationId)
            .collection('products')
            .doc(productId);
            
        final productDoc = await transaction.get(productRef);
        
        if (!productDoc.exists) {
          throw Exception('Ürün bulunamadı: $productId');
        }
        
        final currentStock = productDoc.data()!['current_stock'] as int? ?? 0;
        final newStock = currentStock - quantity;
        
        // Stok kontrolü
        if (newStock < 0) {
          throw Exception('Yetersiz stok! Mevcut: $currentStock, Talep edilen: $quantity');
        }
        
        // Stok güncelle
        transaction.update(productRef, {
          'current_stock': newStock,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        
        print('📦 Stok güncellendi: $currentStock → $newStock (SATIŞ)');
      });
      
      // 3. Lot bilgilerini transaction dışında al
      final lots = await FirebaseService.getStockLots(productId);
      final costBreakdown = _calculateCostForSale(lots, quantity);
      final totalCost = costBreakdown['totalCost']!;
      final totalAmount = quantity * unitPrice;
      final profitLoss = totalAmount - totalCost;
      
      // 4. Diğer kayıtları batch ile yap
      await executeAtomicOperation<void>((batch, firestore) async {
        // İşlem kaydı oluştur (organizasyon yapısı ile)
        final transactionRef = firestore
            .collection('organizations')
            .doc(organizationId)
            .collection('inventory_transactions')
            .doc();
            
        batch.set(transactionRef, {
          'id': transactionRef.id,
          'product_id': productId,
          'product_name': productName,
          'transaction_type': 'SALE',
          'quantity': quantity,
          'unit_price': unitPrice,
          'total_amount': totalAmount,
          'transaction_date': Timestamp.fromDate(transDate),
          'customer_name': customerName,
          'notes': notes,
          'profit_loss': profitLoss,
          'cost_breakdown': costBreakdown,
          'created_at': FieldValue.serverTimestamp(),
          'organization_id': organizationId,
        });
        
        // Lot güncellemeleri (FIFO mantığı)
        await _updateLotsForSale(batch, firestore, lots, quantity);
        
        print('💰 Satış özeti: ₺$totalAmount (Maliyet: ₺$totalCost, Kar: ₺$profitLoss)');
        
        return;
      });
      
      print('✅ Satış işlemi başarıyla kaydedildi');
      
    } catch (e) {
      print('❌ Satış işlemi başarısız: $e');
      rethrow;
    }
  }
  
  // Lot güncellemelerini batch içinde yap
  Future<void> _updateLotsForSale(
    WriteBatch batch,
    FirebaseFirestore firestore,
    List<Map<String, dynamic>> lots,
    int quantity,
  ) async {
    int remainingQuantity = quantity;
    
    // Organizasyon ID'sini al
    final organizationId = await FirebaseService.getCurrentUserOrganizationId();
    if (organizationId == null) {
      throw Exception('Organizasyon bulunamadı');
    }
    
    for (final lot in lots) {
      if (remainingQuantity <= 0) break;
      
      final lotId = lot['id'];
      final availableQty = lot['remaining_quantity'] as int;
      final useFromThisLot = remainingQuantity > availableQty ? availableQty : remainingQuantity;
      
      if (useFromThisLot > 0) {
        final newRemainingQty = availableQty - useFromThisLot;
        
        // Lot güncelle (organizasyon yapısı ile)
        final lotRef = firestore
            .collection('organizations')
            .doc(organizationId)
            .collection('stock_lots')
            .doc(lotId);
            
        batch.update(lotRef, {
          'remaining_quantity': newRemainingQty,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        
        remainingQuantity -= useFromThisLot;
        print('📦 Lot güncellendi: $lotId ($availableQty → $newRemainingQty)');
      }
    }
  }

  // **3. STOK DÜZELTME**
  Future<void> adjustStock({
    required String productId,
    required String productName,
    required int adjustmentQuantity, // Pozitif: artış, Negatif: azalış
    required String reason,
    DateTime? transactionDate,
  }) async {
    final now = DateTime.now();
    final transDate = transactionDate ?? now;
    
    try {
      print('⚖️ Stok düzeltme başlatılıyor: $productName ($adjustmentQuantity)');
      
      final product = await FirebaseService.getProduct(productId);
      if (product == null) {
        throw Exception('Ürün bulunamadı');
      }

      final currentStock = product['current_stock'] ?? 0;
      final newStock = currentStock + adjustmentQuantity;

      if (newStock < 0) {
        throw Exception('Stok negatif olamaz! Mevcut: $currentStock, Düzeltme: $adjustmentQuantity');
      }

      // Envanter işlemi kaydet
      final transactionData = {
        'product_id': productId,
        'product_name': productName,
        'transaction_type': adjustmentQuantity > 0 ? 'ADJUSTMENT_IN' : 'ADJUSTMENT_OUT',
        'quantity': adjustmentQuantity.abs(),
        'unit_price': 0.0,
        'total_amount': 0.0,
        'notes': 'Stok düzeltme: $reason',
        'transaction_date': transDate,
        'profit_loss': 0.0,
      };

      final transactionResult = await FirebaseService.addInventoryTransaction(transactionData);
      if (!transactionResult['success']) {
        throw Exception(transactionResult['message']);
      }

      // Stok artışı için lot oluştur
      if (adjustmentQuantity > 0) {
        final lotData = {
          'product_id': productId,
          'batch_number': 'ADJ-${transDate.millisecondsSinceEpoch}',
          'purchase_price': 0.0, // Düzeltme için maliyet yok
          'original_quantity': adjustmentQuantity,
          'remaining_quantity': adjustmentQuantity,
          'purchase_date': transDate,
          'supplier_name': 'Stok Düzeltme',
        };

        await FirebaseService.addStockLot(lotData);
      }

      // Ürün stokunu güncelle
      await FirebaseService.updateProductStock(productId, newStock);

      // 4. Senkronizasyonu tetikle

      print('✅ Stok düzeltme tamamlandı: $productName ($adjustmentQuantity)');
    } catch (e) {
      print('❌ Stok düzeltme hatası: $e');
      throw Exception('Stok düzeltme başarısız: $e');
    }
  }

  // **4. İŞLEM GEÇMİŞİ**
  Future<List<InventoryTransaction>> getTransactionHistory({
    String? productId,
    String? transactionType,
    DateTime? startDate,
    DateTime? endDate,
    int limit = 100,
  }) async {
    try {
      // Yeni method'u kullan - sadece transaction type filtresi
      List<String>? typeFilter;
      if (transactionType != null) {
        typeFilter = [transactionType];
      }
      
      final transactionMaps = await FirebaseService.getInventoryTransactions(
        transactionTypes: typeFilter,
        startDate: startDate,
        endDate: endDate,
      );

      // Product ID filtresi uygula (client-side)
      List<Map<String, dynamic>> filteredTransactions = transactionMaps;
      if (productId != null) {
        filteredTransactions = transactionMaps.where((data) {
          return data['product_id'] == productId;
        }).toList();
      }
      
      // Limit uygula
      if (filteredTransactions.length > limit) {
        filteredTransactions = filteredTransactions.take(limit).toList();
      }

      // Firebase verilerini InventoryTransaction modeline dönüştür
      return filteredTransactions.map((data) {
        return InventoryTransaction.fromMap(data);
      }).toList();
    } catch (e) {
      print('❌ İşlem geçmişi yüklenirken hata: $e');
      return [];
    }
  }

  // **5. ÜRÜN STOK BİLGİSİ**
  Future<Map<String, dynamic>> getProductStockInfo(String productId) async {
    try {
      final product = await FirebaseService.getProduct(productId);
      if (product == null) {
        return {'error': 'Ürün bulunamadı'};
      }

      final lots = await FirebaseService.getStockLots(productId);
      
      double totalValue = 0.0;
      double averageCost = 0.0;
      int totalQuantity = 0;

      for (var lot in lots) {
        final qty = lot['remaining_quantity'] ?? 0;
        final price = (lot['purchase_price'] ?? 0.0).toDouble();
        totalValue += qty * price;
        totalQuantity += qty as int;
      }

      if (totalQuantity > 0) {
        averageCost = totalValue / totalQuantity;
      }

      return {
        'product': product,
        'current_stock': product['current_stock'] ?? 0,
        'total_value': totalValue,
        'average_cost': averageCost,
        'lots': lots,
        'lot_count': lots.length,
      };
    } catch (e) {
      print('❌ Ürün stok bilgisi yüklenirken hata: $e');
      return {'error': e.toString()};
    }
  }

  // **6. ÜRÜN ANALİZİ**
  Future<Map<String, dynamic>> getProductAnalytics(String productId, {
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      return await FirebaseService.getProductAnalytics(
        productId,
        startDate: startDate,
        endDate: endDate,
      );
    } catch (e) {
      print('❌ Ürün analizi hesaplanırken hata: $e');
      return {};
    }
  }

  // **7. SATIŞ LİSTESİ**
  Future<List<InventoryTransaction>> getSales({
    DateTime? startDate,
    DateTime? endDate,
    int limit = 100,
  }) async {
    try {
      final transactions = await FirebaseService.getSalesTransactions(limit: limit);
      
      return transactions.map((data) {
        return InventoryTransaction.fromMap(data);
      }).toList();
    } catch (e) {
      print('❌ Satış listesi yüklenirken hata: $e');
      return [];
    }
  }

  // **8. SATIN ALMA LİSTESİ**
  Future<List<InventoryTransaction>> getPurchases({
    DateTime? startDate,
    DateTime? endDate,
    int limit = 100,
  }) async {
    try {
      final transactions = await FirebaseService.getPurchaseTransactions(limit: limit);
      
      return transactions.map((data) {
        return InventoryTransaction.fromMap(data);
      }).toList();
    } catch (e) {
      print('❌ Satın alma listesi yüklenirken hata: $e');
      return [];
    }
  }

  // **9. SATIŞ LOTLARINI GETİR (MÜŞTERİ İADESİ İÇİN)**
  Future<List<Map<String, dynamic>>> getSaleLots(String productId) async {
    try {
      print('🔍 [SALE_LOTS] Satış lotları yükleniyor - Product ID: $productId');
      
      if (productId.isEmpty) {
        print('❌ [SALE_LOTS] Product ID boş!');
        return [];
      }
      
      // Satış işlemlerini getir
      final salesTransactions = await FirebaseService.getSalesTransactions(limit: 1000);
      
      // Sadece bu ürünün satışlarını filtrele
      final productSales = salesTransactions.where((sale) {
        return sale['product_id'] == productId && sale['transaction_type'] == 'SALE';
      }).toList();
      
      print('📦 [SALE_LOTS] ${productSales.length} satış işlemi bulundu');
      
      // Satış işlemlerini lot formatına çevir (iade yapılabilir hale getir)
      final saleLots = productSales.map((sale) {
        final saleData = Map<String, dynamic>.from(sale);
        
        // Satış ID'sini lot ID olarak kullan
        saleData['sale_id'] = sale['id'] ?? sale['transaction_id'];
        saleData['lot_type'] = 'SALE'; // Satış lotu olduğunu belirt
        
        // İade miktarını dikkate al
        final originalQuantity = saleData['quantity'] ?? 0;
        final returnedQuantity = saleData['returned_quantity'] ?? 0;
        final availableForReturn = originalQuantity - returnedQuantity;
        
        // Eğer tamamen iade edilmişse bu lot'u gösterme
        if (availableForReturn <= 0) {
          return null;
        }
        
        // Mevcut iade edilebilir miktarı ayarla
        saleData['available_quantity'] = availableForReturn;
        saleData['original_quantity'] = originalQuantity;
        saleData['returned_quantity'] = returnedQuantity;
        
        // Firestore Timestamp'i DateTime'a çevir
        if (saleData['transaction_date'] is Timestamp) {
          saleData['transaction_date'] = (saleData['transaction_date'] as Timestamp).toDate();
        }
        
        print('📦 [SALE_LOTS] Satış lot verisi: ${availableForReturn}/${originalQuantity} mevcut (${returnedQuantity} iade)');
        return saleData;
      }).where((saleData) => saleData != null).cast<Map<String, dynamic>>().toList();
      
      // En son satışlardan başla (LIFO - Last In First Out for returns)
      saleLots.sort((a, b) {
        final dateA = a['transaction_date'] as DateTime? ?? DateTime.now();
        final dateB = b['transaction_date'] as DateTime? ?? DateTime.now();
        return dateB.compareTo(dateA); // Ters sıralama (en yeni önce)
      });
      
      print('✅ [SALE_LOTS] ${saleLots.length} iade edilebilir satış lotu döndürülüyor');
      return saleLots;
    } catch (e) {
      print('❌ [SALE_LOTS] Satış lotları yüklenirken hata: $e');
      return [];
    }
  }

  // **10. MEVCUT STOK LOTLARINI GETİR (TEDARİKÇİ İADESİ İÇİN)**
  Future<List<Map<String, dynamic>>> getAvailableLots(String productId) async {
    try {
      print('🔍 InventoryService.getAvailableLots çağrıldı - Product ID: $productId');
      
      if (productId.isEmpty) {
        print('❌ Product ID boş!');
        return [];
      }
      
      final lots = await FirebaseService.getStockLots(productId);
      print('📦 InventoryService: ${lots.length} stok lotu döndürüldü');
      
      return lots;
    } catch (e) {
      print('❌ InventoryService.getAvailableLots hatası: $e');
      return [];
    }
  }

  // **7. İADE İŞLEMİ**
  Future<void> addReturn({
    required String productId,
    required String productName,
    required int quantity,
    required double unitPrice,
    required String returnType, // 'return_sale' veya 'return_purchase'
    String? customerName,
    String? reason,
    String? notes,
    DateTime? transactionDate,
    Map<dynamic, int>? selectedLotQuantities, // Seçilen lot'lar ve miktarları
  }) async {
    final now = DateTime.now();
    final transDate = transactionDate ?? now;
    
    try {
      print('🔄 İade işlemi başlatılıyor: $quantity adet $productName (Tür: $returnType)');
      
      // Kar/zarar hesapla
      double profitLoss = 0.0;
      
      if (returnType == 'return_sale') {
        // Satış iadesi: Kar kaybı (negatif profit)
        // İade edilen fiyat kadar kar kaybı
        profitLoss = -(quantity * unitPrice);
        
        // Seçilen satış lotlarını işle (manuel seçim yapıldıysa)
        if (selectedLotQuantities != null && selectedLotQuantities.isNotEmpty) {
          print('📦 Manuel seçilen satış lotları işleniyor...');
          for (var entry in selectedLotQuantities.entries) {
            final saleId = entry.key.toString();
            final returnedQty = entry.value;
            
            print('🔄 Satış ID: $saleId için $returnedQty adet iade ediliyor');
            
            // Satış işlemini güncelle - iade edilen miktarı takip et
            await _updateSaleTransactionReturn(saleId, returnedQty as int);
          }
        } else {
          // Otomatik FIFO modunda: Satış lotlarını LIFO sırasıyla işle
          print('🤖 Otomatik FIFO modunda satış lotları işleniyor...');
          final saleLots = await getSaleLots(productId);
          int remainingQuantity = quantity;
          
          // En son satışlardan başla (LIFO)
          for (final lot in saleLots) {
            if (remainingQuantity <= 0) break;
            
            final saleId = lot['sale_id'] ?? lot['id'];
            final availableQty = lot['available_quantity'] ?? lot['quantity'] ?? 0;
            final useFromThisLot = remainingQuantity > availableQty ? availableQty : remainingQuantity;
            
            if (useFromThisLot > 0) {
              print('🔄 Otomatik: Satış ID: $saleId için $useFromThisLot adet iade ediliyor');
              await _updateSaleTransactionReturn(saleId.toString(), useFromThisLot as int);
              remainingQuantity -= useFromThisLot as int;
            }
          }
          
          if (remainingQuantity > 0) {
            print('⚠️ Uyarı: $remainingQuantity adet için yeterli satış lotu bulunamadı');
          }
        }
        
      } else {
        // Alış iadesi: Maliyet azalması (pozitif profit)
        // İade edilen maliyet kadar kar artışı
        profitLoss = quantity * unitPrice;
      }
      
      // İade işlemini Firebase'e kaydet
      await FirebaseService.addInventoryTransaction({
        'product_id': productId,
        'product_name': productName,
        'transaction_type': returnType, // 'return_sale' veya 'return_purchase'
        'quantity': quantity,
        'unit_price': unitPrice,
        'total_amount': quantity * unitPrice,
        'customer_name': customerName,
        'reason': reason,
        'notes': notes,
        'transaction_date': transDate,
        'profit_loss': profitLoss, // Kar/zarar etkisi
        'selected_lots': selectedLotQuantities, // Seçilen lot bilgileri
        'created_at': now,
      });
      
      // Ürün stokunu güncelle (iade türüne göre)
      final product = await FirebaseService.getProduct(productId);
      if (product != null) {
        final currentStock = product['current_stock'] ?? 0;
        int newStock;
        
        if (returnType == 'return_sale') {
          // Satış iadesi: stok artar (müşteriden gelen ürün)
          newStock = currentStock + quantity;
          print('📈 Satış iadesi: Stok artırılıyor ($currentStock + $quantity = $newStock)');
          print('💰 Kar etkisi: ₺${profitLoss.toStringAsFixed(2)} (satış iadesi kaybı)');
          
          // Satış iadesi için yeni lot oluştur (iade edilen ürünler için)
          final lotData = {
            'product_id': productId,
            'batch_number': 'RETURN-${transDate.millisecondsSinceEpoch}',
            'purchase_price': unitPrice, // İade fiyatı olarak kabul ediyoruz
            'original_quantity': quantity,
            'remaining_quantity': quantity,
            'purchase_date': transDate,
            'supplier_name': 'İade - ${customerName ?? "Müşteri"}',
          };
          await FirebaseService.addStockLot(lotData);
          
        } else {
          // Alış iadesi: stok azalır (tedarikçiye gönderilen ürün)
          newStock = currentStock - quantity;
          print('📉 Alış iadesi: Stok azaltılıyor ($currentStock - $quantity = $newStock)');
          print('💰 Kar etkisi: ₺${profitLoss.toStringAsFixed(2)} (maliyet iadesi)');
          
          // Alış iadesi için FIFO mantığıyla lot stoklarını azalt
          await _reduceLotStocks(productId, quantity);
        }
        
        await FirebaseService.updateProductStock(productId, newStock);
      }
      
      print('✅ İade işlemi başarıyla kaydedildi');
    } catch (e) {
      print('❌ İade işlemi hatası: $e');
      throw e;
    }
  }

  // **YARDIMCI FONKSİYON: SATIŞ İŞLEMİNİ İADE İLE GÜNCELLE**
  Future<void> _updateSaleTransactionReturn(String saleId, int returnedQuantity) async {
    try {
      final organizationId = await FirebaseService.getCurrentUserOrganizationId();
      if (organizationId == null) return;

      print('🔄 Satış işlemi güncelleniyor: $saleId, iade miktarı: $returnedQuantity');
      
      // Satış işlemini getir
      final saleDoc = await FirebaseService.firestore
          .collection('organizations')
          .doc(organizationId)
          .collection('inventory_transactions')
          .doc(saleId)
          .get();
      
      if (saleDoc.exists) {
        final saleData = saleDoc.data()!;
        final currentReturnedQty = saleData['returned_quantity'] ?? 0;
        final newReturnedQty = currentReturnedQty + returnedQuantity;
        
        // Satış işleminin iade miktarını güncelle
        await FirebaseService.firestore
            .collection('organizations')
            .doc(organizationId)
            .collection('inventory_transactions')
            .doc(saleId)
            .update({
          'returned_quantity': newReturnedQty,
          'last_return_date': FieldValue.serverTimestamp(),
        });
        
        print('✅ Satış işlemi güncellendi: $saleId -> iade miktarı: $newReturnedQty');
      }
    } catch (e) {
      print('❌ Satış işlemi güncellenirken hata: $e');
    }
  }

  // **8. FIRE/KAYIP İŞLEMİ**
  Future<void> addLoss({
    required String productId,
    required String productName,
    required int quantity,
    required double unitPrice,
    String? reason,
    String? notes,
    DateTime? transactionDate,
  }) async {
    final now = DateTime.now();
    final transDate = transactionDate ?? now;
    
    try {
      print('🗑️ Kayıp/Fire işlemi başlatılıyor: $quantity adet $productName');
      
      // Kayıp/Fire kar etkisi: Maliyet kaybı (negatif profit)
      final profitLoss = -(quantity * unitPrice);
      print('💸 Kayıp kar etkisi: ₺${profitLoss.toStringAsFixed(2)} (maliyet kaybı)');
      
      // Fire işlemini Firebase'e kaydet
      await FirebaseService.addInventoryTransaction({
        'product_id': productId,
        'product_name': productName,
        'transaction_type': 'loss',
        'quantity': quantity,
        'unit_price': unitPrice,
        'total_amount': quantity * unitPrice,
        'profit_loss': profitLoss, // Kar/zarar etkisi
        'reason': reason,
        'notes': notes,
        'transaction_date': transDate,
        'created_at': now,
      });
      
      // FIFO mantığıyla lot stoklarını azalt
      await _reduceLotStocks(productId, quantity);
      
      // Ürün stokunu azalt
      final product = await FirebaseService.getProduct(productId);
      if (product != null) {
        final currentStock = product['current_stock'] ?? 0;
        final newStock = currentStock - quantity;
        await FirebaseService.updateProductStock(productId, newStock);
        print('📉 Kayıp/Fire: Stok azaltılıyor ($currentStock - $quantity = $newStock)');
      }
      
      print('✅ Fire işlemi başarıyla kaydedildi');
    } catch (e) {
      print('❌ Fire işlemi hatası: $e');
      throw e;
    }
  }

  // **YARDIMCI FONKSİYON: LOT STOKLARINI AZALT (FIFO)**
  Future<void> _reduceLotStocks(String productId, int quantity) async {
    try {
      final lots = await FirebaseService.getStockLots(productId);
      int remainingQuantity = quantity;
      
      print('🔍 FIFO ile lot azaltma: $quantity adet, ${lots.length} lot mevcut');
      
      for (var lot in lots) {
        if (remainingQuantity <= 0) break;
        
        final lotId = lot['id'];
        final lotRemainingQty = lot['remaining_quantity'] ?? 0;
        
        if (lotRemainingQty > 0) {
          final useFromThisLot = remainingQuantity > lotRemainingQty 
              ? lotRemainingQty 
              : remainingQuantity;
          
          final newRemainingQty = lotRemainingQty - useFromThisLot;
          await FirebaseService.updateStockLot(lotId, newRemainingQty);
          
          remainingQuantity -= useFromThisLot as int;
          print('📦 Lot $lotId: $lotRemainingQty -> $newRemainingQty (kullanılan: $useFromThisLot)');
        }
      }
      
      if (remainingQuantity > 0) {
        print('⚠️ Uyarı: $remainingQuantity adet için yeterli lot bulunamadı');
      }
      
    } catch (e) {
      print('❌ Lot stokları azaltılırken hata: $e');
      throw e;
    }
  }

  // **İADE İŞLEMLERİNİ GETİR**
  Future<List<InventoryTransaction>> getReturns() async {
    final returnMaps = await FirebaseService.getInventoryTransactions(
      transactionTypes: ['return_sale', 'return_purchase']
    );
    
    // Map'leri InventoryTransaction'a çevir
    return returnMaps.map((map) => InventoryTransaction.fromMap(map)).toList();
  }

  // **TÜM KAR/ZARAR ETKİSİ OLAN İŞLEMLERİ GETİR**
  Future<double> getTotalProfitLoss() async {
    try {
      final allTransactionMaps = await FirebaseService.getInventoryTransactions();
      
      double totalProfitLoss = 0.0;
      
      for (var transactionMap in allTransactionMaps) {
        final profitLoss = transactionMap['profit_loss'] as double?;
        if (profitLoss != null) {
          totalProfitLoss += profitLoss;
        }
      }
      
      print('💰 Toplam kar/zarar hesaplandı: ₺${totalProfitLoss.toStringAsFixed(2)}');
      return totalProfitLoss;
    } catch (e) {
      print('❌ Kar/zarar hesaplama hatası: $e');
      return 0.0;
    }
  }

  // **İSTATİSTİK ÖZET**
  Future<Map<String, dynamic>> getFinancialSummary({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      // Tarih filtreli işlemleri getir
      final salesMaps = await FirebaseService.getInventoryTransactions(
        transactionTypes: ['SALE'],
        startDate: startDate,
        endDate: endDate,
      );
      final purchasesMaps = await FirebaseService.getInventoryTransactions(
        transactionTypes: ['PURCHASE'],
        startDate: startDate,
        endDate: endDate,
      );
      final returnsMaps = await FirebaseService.getInventoryTransactions(
        transactionTypes: ['return_sale', 'return_purchase'],
        startDate: startDate,
        endDate: endDate,
      );
      final lossMaps = await FirebaseService.getInventoryTransactions(
        transactionTypes: ['loss'],
        startDate: startDate,
        endDate: endDate,
      );
      
      double totalSalesAmount = 0.0;
      double totalPurchasesAmount = 0.0;
      double totalReturnsAmount = 0.0;
      double totalLossesAmount = 0.0;
      double totalProfit = 0.0;
      
      // Satış tutarları ve karı
      for (var saleMap in salesMaps) {
        final totalAmount = (saleMap['total_amount'] ?? 0.0).toDouble();
        final profitLoss = (saleMap['profit_loss'] ?? 0.0).toDouble();
        
        totalSalesAmount += totalAmount;
        totalProfit += profitLoss;
      }
      
      // Alış tutarları
      for (var purchaseMap in purchasesMaps) {
        final totalAmount = (purchaseMap['total_amount'] ?? 0.0).toDouble();
        totalPurchasesAmount += totalAmount;
      }
      
      // İade tutarları ve kar etkisi
      for (var returnMap in returnsMaps) {
        final totalAmount = (returnMap['total_amount'] ?? 0.0).toDouble();
        final profitLoss = (returnMap['profit_loss'] ?? 0.0).toDouble();
        
        totalReturnsAmount += totalAmount;
        totalProfit += profitLoss;
      }
      
      // Kayıp tutarları ve kar etkisi
      for (var lossMap in lossMaps) {
        final totalAmount = (lossMap['total_amount'] ?? 0.0).toDouble();
        final profitLoss = (lossMap['profit_loss'] ?? 0.0).toDouble();
        
        totalLossesAmount += totalAmount;
        totalProfit += profitLoss;
      }
      
      // Toplam işlem sayısını hesapla
      final totalTransactions = salesMaps.length + purchasesMaps.length + returnsMaps.length + lossMaps.length;
      
      final dateInfo = startDate != null && endDate != null 
          ? ' (${startDate.day}/${startDate.month}/${startDate.year} - ${endDate.day}/${endDate.month}/${endDate.year})'
          : '';
      
      print('📊 Finansal özet yüklendi$dateInfo:');
      print('   Satışlar: ${salesMaps.length} işlem, ₺${totalSalesAmount.toStringAsFixed(2)}');
      print('   Alımlar: ${purchasesMaps.length} işlem, ₺${totalPurchasesAmount.toStringAsFixed(2)}');
      print('   İadeler: ${returnsMaps.length} işlem, ₺${totalReturnsAmount.toStringAsFixed(2)}');
      print('   Kayıplar: ${lossMaps.length} işlem, ₺${totalLossesAmount.toStringAsFixed(2)}');
      print('   Net Kar: ₺${totalProfit.toStringAsFixed(2)}');
      print('   Toplam İşlem: $totalTransactions');
      
      return {
        'totalSales': totalSalesAmount,
        'totalPurchases': totalPurchasesAmount,
        'totalReturns': totalReturnsAmount,
        'totalLosses': totalLossesAmount,
        'totalProfit': totalProfit,
        'salesCount': salesMaps.length,
        'purchasesCount': purchasesMaps.length,
        'returnsCount': returnsMaps.length,
        'lossesCount': lossMaps.length,
        'totalTransactions': totalTransactions,
      };
    } catch (e) {
      print('❌ Finansal özet hesaplama hatası: $e');
      return {
        'totalSales': 0.0,
        'totalPurchases': 0.0,
        'totalReturns': 0.0,
        'totalLosses': 0.0,
        'totalProfit': 0.0,
        'salesCount': 0,
        'purchasesCount': 0,
        'returnsCount': 0,
        'lossesCount': 0,
        'totalTransactions': 0,
      };
    }
  }

  // FIFO mantığı ile maliyet hesaplama
  Map<String, double> _calculateCostForSale(List<Map<String, dynamic>> lots, int quantity) {
    int remainingQuantity = quantity;
    double totalCost = 0.0;
    Map<String, int> lotUsage = {};
    
    for (final lot in lots) {
      if (remainingQuantity <= 0) break;
      
      final lotId = lot['id'];
      final availableQty = lot['remaining_quantity'] as int;
      final lotPrice = (lot['purchase_price'] ?? 0.0).toDouble();
      
      if (availableQty > 0) {
        final useFromThisLot = remainingQuantity > availableQty ? availableQty : remainingQuantity;
        
        lotUsage[lotId] = useFromThisLot;
        totalCost += useFromThisLot * lotPrice;
        remainingQuantity -= useFromThisLot;
        
        print('💰 Lot kullanımı: $lotId → $useFromThisLot adet × ₺$lotPrice = ₺${useFromThisLot * lotPrice}');
      }
    }
    
    if (remainingQuantity > 0) {
      throw Exception('FIFO hesaplaması hatası: Yeterli lot bulunamadı (Eksik: $remainingQuantity adet)');
    }
    
    return {
      'totalCost': totalCost,
      'averageCost': quantity > 0 ? totalCost / quantity : 0.0,
    };
  }
} 