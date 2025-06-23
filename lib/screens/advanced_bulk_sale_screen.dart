import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/product.dart';
import '../models/inventory_transaction.dart';
import '../services/inventory_service.dart';
import '../services/firebase_service.dart';
import '../services/subscription_service.dart';
import '../widgets/barcode_scanner_widget.dart';

class AdvancedBulkSaleScreen extends StatefulWidget {
  const AdvancedBulkSaleScreen({Key? key}) : super(key: key);

  @override
  _AdvancedBulkSaleScreenState createState() => _AdvancedBulkSaleScreenState();
}

class SaleItem {
  final Map<String, dynamic> product;
  int quantity;
  double unitPrice;
  double discount;
  String customerName;
  String notes;
  List<Map<String, dynamic>> availableLots;
  Map<int, int> selectedLotQuantities; // lotId: quantity
  bool useAutoFIFO;
  double totalCost;

  SaleItem({
    required this.product,
    this.quantity = 1,
    double? unitPrice,
    this.discount = 0.0,
    this.customerName = '',
    this.notes = '',
    List<Map<String, dynamic>>? availableLots,
    Map<int, int>? selectedLotQuantities,
    this.useAutoFIFO = true,
    this.totalCost = 0.0,
  }) : unitPrice = unitPrice ?? (product['sale_price']?.toDouble() ?? 0.0),
       availableLots = availableLots ?? [],
       selectedLotQuantities = selectedLotQuantities ?? {};

  double get subtotal => quantity * unitPrice;
  double get discountAmount => subtotal * (discount / 100);
  double get total => subtotal - discountAmount;
  double get profitLoss => total - totalCost;

  SaleItem copyWith({
    Map<String, dynamic>? product,
    int? quantity,
    double? unitPrice,
    double? discount,
    String? customerName,
    String? notes,
    List<Map<String, dynamic>>? availableLots,
    Map<int, int>? selectedLotQuantities,
    bool? useAutoFIFO,
    double? totalCost,
  }) {
    return SaleItem(
      product: product ?? this.product,
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice ?? this.unitPrice,
      discount: discount ?? this.discount,
      customerName: customerName ?? this.customerName,
      notes: notes ?? this.notes,
      availableLots: availableLots ?? this.availableLots,
      selectedLotQuantities: selectedLotQuantities ?? this.selectedLotQuantities,
      useAutoFIFO: useAutoFIFO ?? this.useAutoFIFO,
      totalCost: totalCost ?? this.totalCost,
    );
  }
}

class _AdvancedBulkSaleScreenState extends State<AdvancedBulkSaleScreen> {
  final _formKey = GlobalKey<FormState>();
  final _globalCustomerController = TextEditingController();
  final _globalNotesController = TextEditingController();
  final _globalDiscountController = TextEditingController(text: '0');
  final _barcodeController = TextEditingController();
  
  final SubscriptionService _subscriptionService = SubscriptionService();
  
  List<SaleItem> _saleItems = [];
  List<Map<String, dynamic>> _availableProducts = [];
  Map<String, List<Map<String, dynamic>>> _productLots = {};
  
  bool _isLoading = false;
  bool _isLoadingProducts = true;
  
  double _globalDiscount = 0.0;
  double _totalAmount = 0.0;
  double _totalCost = 0.0;
  double _totalDiscount = 0.0;
  double _finalAmount = 0.0;
  double _totalProfitLoss = 0.0;

  @override
  void initState() {
    super.initState();
    _loadProducts();
    _globalDiscountController.addListener(_calculateTotals);
  }

  @override
  void dispose() {
    _globalCustomerController.dispose();
    _globalNotesController.dispose();
    _globalDiscountController.dispose();
    _barcodeController.dispose();
    super.dispose();
  }

  Future<void> _loadProducts() async {
    try {
      setState(() {
        _isLoadingProducts = true;
      });

      final products = await FirebaseService.getProducts();
      
      setState(() {
        _availableProducts = products;
        _isLoadingProducts = false;
      });
    } catch (e) {
      print('Ürünler yüklenirken hata: $e');
      setState(() {
        _isLoadingProducts = false;
      });
    }
  }

  Future<void> _loadProductLots(SaleItem item) async {
    try {
      final productId = item.product['id']?.toString() ?? '';
      final lots = await InventoryService().getAvailableLots(productId);
      
      final index = _saleItems.indexWhere((s) => s.product['id'] == item.product['id']);
      if (index != -1) {
        setState(() {
          _saleItems[index] = _saleItems[index].copyWith(availableLots: lots);
        });
        _calculateItemCost(index);
      }
    } catch (e) {
      print('Lot bilgileri yüklenirken hata: $e');
    }
  }

  void _showPremiumRequired() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.star, color: Colors.amber),
            SizedBox(width: 8),
            Text('Premium Özellik'),
          ],
        ),
        content: Text(
          'Barkod tarama özelliği Premium üyelerin kullanabileceği bir özelliktir. Premium üyelik satın alarak bu özelliği kullanabilirsiniz.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Tamam'),
          ),
        ],
      ),
    );
  }

  Future<void> _scanBarcode() async {
    // Premium kontrolü
    final isUserPremium = await _subscriptionService.isUserPremium();
    if (!isUserPremium) {
      _showPremiumRequired();
      return;
    }

    try {
      final result = await Navigator.push<String>(
        context,
        MaterialPageRoute(
          builder: (context) => BarcodeScannerWidget(
            title: 'Barkod Tarayıcı - Toplu Satış',
            subtitle: 'Satış yapılacak ürünün barkodunu tarayın',
            onBarcodeDetected: (barcode) {
              print('Barkod algılandı: $barcode');
            },
          ),
        ),
      );

      if (result != null && result.isNotEmpty) {
        await _addProductByBarcode(result);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Barkod tarama hatası: $e')),
      );
    }
  }

  Future<void> _addProductByBarcode(String barcode) async {
    try {
      final product = await FirebaseService.getProductByBarcode(barcode);
      
      if (product != null) {
        _addProduct(product);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${product['name']} listeye eklendi'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Bu barkoda ait ürün bulunamadı: $barcode'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ürün arama hatası: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _addProduct(Map<String, dynamic> product) {
    // Aynı ürün zaten var mı kontrol et
    final existingIndex = _saleItems.indexWhere(
      (item) => item.product['id'] == product['id']
    );
    
    if (existingIndex >= 0) {
      // Varsa miktarını artır
      setState(() {
        _saleItems[existingIndex] = _saleItems[existingIndex].copyWith(
          quantity: _saleItems[existingIndex].quantity + 1
        );
      });
    } else {
      // Yoksa yeni ekle
      final saleItem = SaleItem(product: product);
      setState(() {
        _saleItems.add(saleItem);
      });
      _loadProductLots(saleItem);
    }
    _calculateTotals();
  }

  void _removeProduct(int index) {
    setState(() {
      _saleItems.removeAt(index);
    });
    _calculateTotals();
  }

  void _updateSaleItem(int index, SaleItem updatedItem) {
    setState(() {
      _saleItems[index] = updatedItem;
    });
    _calculateItemCost(index);
    _calculateTotals();
  }

  void _calculateItemCost(int index) {
    final item = _saleItems[index];
    double cost = 0.0;

    if (item.useAutoFIFO) {
      cost = _calculateFIFOCost(item.availableLots, item.quantity);
    } else {
      cost = _calculateManualCost(item.availableLots, item.selectedLotQuantities);
    }

    setState(() {
      _saleItems[index] = _saleItems[index].copyWith(totalCost: cost);
    });
  }

  double _calculateFIFOCost(List<Map<String, dynamic>> lots, int requestedQuantity) {
    double cost = 0.0;
    int remaining = requestedQuantity;
    
    // FIFO sıralaması: En eski lot'lardan başla
    final sortedLots = List<Map<String, dynamic>>.from(lots);
    sortedLots.sort((a, b) {
      final dateA = a['purchase_date'] is DateTime 
          ? a['purchase_date'] 
          : a['purchaseDate'] is DateTime 
              ? a['purchaseDate']
              : DateTime.now();
      final dateB = b['purchase_date'] is DateTime 
          ? b['purchase_date'] 
          : b['purchaseDate'] is DateTime 
              ? b['purchaseDate']
              : DateTime.now();
      return dateA.compareTo(dateB);
    });
    
    for (final lot in sortedLots) {
      if (remaining <= 0) break;
      
      final availableQty = lot['remaining_quantity'] ?? lot['remainingQuantity'] ?? 0;
      final price = (lot['purchase_price'] ?? lot['purchasePrice'] ?? 0.0).toDouble();
      final usedQty = remaining < availableQty ? remaining : availableQty;
      
      cost += usedQty * price;
      remaining -= usedQty as int;
    }
    
    return cost;
  }

  double _calculateManualCost(List<Map<String, dynamic>> lots, Map<int, int> selectedQuantities) {
    double cost = 0.0;
    
    selectedQuantities.forEach((lotId, quantity) {
      final lot = lots.firstWhere(
        (l) => (l['id'] ?? l['lotId']) == lotId,
        orElse: () => {},
      );
      if (lot.isNotEmpty) {
        final price = (lot['purchase_price'] ?? lot['purchasePrice'] ?? 0.0).toDouble();
        cost += quantity * price;
      }
    });
    
    return cost;
  }

  void _calculateTotals() {
    double totalAmount = 0.0;
    double totalCost = 0.0;
    
    for (final item in _saleItems) {
      totalAmount += item.total; // Bu zaten iskonto uygulanmış tutar
      totalCost += item.totalCost;
    }
    
    setState(() {
      _totalAmount = totalAmount;
      _totalCost = totalCost;
      _totalDiscount = 0.0; // Artık kullanmıyoruz
      _finalAmount = totalAmount; // Net tutar zaten hesaplanmış
      _totalProfitLoss = totalAmount - totalCost;
    });
  }

  void _applyGlobalDiscountToAllItems() {
    final globalDiscountPercent = double.tryParse(_globalDiscountController.text) ?? 0.0;
    
    setState(() {
      for (int i = 0; i < _saleItems.length; i++) {
        _saleItems[i] = _saleItems[i].copyWith(discount: globalDiscountPercent);
      }
    });
    _calculateTotals();
  }

  Future<void> _processBulkSale() async {
    if (_saleItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Satış listesi boş! Lütfen ürün ekleyin.')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      int successCount = 0;
      int failCount = 0;
      List<String> errors = [];

      for (int i = 0; i < _saleItems.length; i++) {
        final item = _saleItems[i];
        
        // Manuel seçimde lot kontrolü
        if (!item.useAutoFIFO) {
          final totalSelectedQty = item.selectedLotQuantities.values.fold(0, (sum, qty) => sum + qty);
          if (totalSelectedQty != item.quantity) {
            errors.add('${item.product['name']}: Seçilen lot miktarları toplam satış miktarına eşit olmalı!');
            failCount++;
            continue;
          }
        }

        try {
          await InventoryService().addSale(
            productId: item.product['id']?.toString() ?? '',
            productName: item.product['name'],
            quantity: item.quantity,
            unitPrice: item.unitPrice,
            customerName: _globalCustomerController.text.trim().isNotEmpty 
                ? _globalCustomerController.text.trim() 
                : null,
            notes: item.notes.isNotEmpty 
                ? item.notes 
                : _globalNotesController.text.trim().isNotEmpty 
                    ? _globalNotesController.text.trim() 
                    : null,
          );
          successCount++;
        } catch (e) {
          errors.add('${item.product['name']}: $e');
          failCount++;
        }
      }

      setState(() {
        _isLoading = false;
      });

      // Sonuç dialogu
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Row(
            children: [
              Icon(
                successCount > 0 ? Icons.check_circle : Icons.error,
                color: successCount > 0 ? Colors.green : Colors.red,
              ),
              SizedBox(width: 8),
              Text('Toplu Satış Sonucu'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('✅ Başarılı: $successCount satış'),
              if (failCount > 0) ...[
                Text('❌ Başarısız: $failCount satış'),
                SizedBox(height: 8),
                Text('Hatalar:', style: TextStyle(fontWeight: FontWeight.bold)),
                ...errors.map((error) => Text('• $error', style: TextStyle(fontSize: 12))),
              ],
              SizedBox(height: 16),
              if (successCount > 0) ...[
                Text('💰 Toplam Tutar: ₺${_finalAmount.toStringAsFixed(2)}', 
                     style: TextStyle(fontWeight: FontWeight.bold)),
                Text('🏷️ Toplam Maliyet: ₺${_totalCost.toStringAsFixed(2)}'),
                Text(
                  '📈 Kar/Zarar: ₺${_totalProfitLoss.toStringAsFixed(2)}',
                  style: TextStyle(
                    color: _totalProfitLoss >= 0 ? Colors.green : Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Dialog'u kapat
                if (successCount > 0) {
                  // Başarılı satışlar varsa formu temizle
                  setState(() {
                    _saleItems.clear();
                    _globalCustomerController.clear();
                    _globalNotesController.clear();
                    _globalDiscountController.text = '0';
                  });
                  _calculateTotals();
                  Navigator.of(context).pop(true); // Ana sayfaya dön ve refresh et
                }
              },
              child: Text('Tamam'),
            ),
          ],
        ),
      );

    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Toplu satış hatası: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildBarcodeInput() {
    return Card(
      margin: EdgeInsets.all(16),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '📱 Barkod ile Ürün Ekle',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _barcodeController,
                    decoration: InputDecoration(
                      labelText: 'Barkod',
                      hintText: 'Barkod girin veya tarayın',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.qr_code),
                    ),
                    onFieldSubmitted: (value) {
                      if (value.isNotEmpty) {
                        _addProductByBarcode(value);
                        _barcodeController.clear();
                      }
                    },
                  ),
                ),
                SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: _scanBarcode,
                  icon: Icon(Icons.qr_code_scanner),
                  label: Text('Tara'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            Text(
              'Barkod tarama Premium özelliğidir',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductSelector() {
    return Card(
      margin: EdgeInsets.all(16),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '🛍️ Manuel Ürün Seçimi',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            Container(
              height: 200,
              child: ListView.builder(
                itemCount: _availableProducts.length,
                itemBuilder: (context, index) {
                  final product = _availableProducts[index];
                  final currentStock = product['current_stock'] ?? product['currentStock'] ?? 0;
                  
                  return Card(
                    margin: EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: Icon(Icons.inventory_2, color: Colors.blue),
                      title: Text(product['name']),
                      subtitle: Text('Stok: $currentStock ${product['unit'] ?? 'adet'}'),
                      trailing: IconButton(
                        icon: Icon(Icons.add_circle, color: Colors.green),
                        onPressed: currentStock > 0 
                            ? () => _addProduct(product)
                            : null,
                      ),
                      enabled: currentStock > 0,
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSaleItemCard(SaleItem item, int index) {
    return Card(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Ürün bilgisi ve kaldır butonu
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.product['name'],
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'SKU: ${item.product['sku']} • Stok: ${item.product['current_stock'] ?? item.product['currentStock'] ?? 0} ${item.product['unit'] ?? 'adet'}',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.delete, color: Colors.red),
                  onPressed: () => _removeProduct(index),
                ),
              ],
            ),
            SizedBox(height: 16),
            
            // Miktar ve fiyat
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    initialValue: item.quantity.toString(),
                    decoration: InputDecoration(
                      labelText: 'Miktar',
                      suffixText: item.product['unit'],
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (value) {
                      final quantity = int.tryParse(value) ?? 1;
                      _updateSaleItem(index, item.copyWith(quantity: quantity));
                    },
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    initialValue: item.unitPrice.toStringAsFixed(2),
                    decoration: InputDecoration(
                      labelText: 'Birim Fiyat',
                      prefixText: '₺',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.numberWithOptions(decimal: true),
                    onChanged: (value) {
                      final price = double.tryParse(value) ?? 0.0;
                      _updateSaleItem(index, item.copyWith(unitPrice: price));
                    },
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            
            // İskonto
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    initialValue: item.discount.toStringAsFixed(1),
                    decoration: InputDecoration(
                      labelText: 'İskonto (%)',
                      suffixText: '%',
                      border: OutlineInputBorder(),
                      hintText: 'Ürün bazlı iskonto',
                    ),
                    keyboardType: TextInputType.numberWithOptions(decimal: true),
                    onChanged: (value) {
                      final discount = double.tryParse(value) ?? 0.0;
                      _updateSaleItem(index, item.copyWith(discount: discount));
                    },
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green.shade300),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Net Tutar:',
                          style: TextStyle(fontSize: 12, color: Colors.green.shade700),
                        ),
                        Text(
                          '₺${item.total.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade800,
                          ),
                        ),
                        if (item.discount > 0)
                          Text(
                            'İskonto: ₺${item.discountAmount.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.orange.shade700,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            
            // Lot seçimi
            _buildLotSelection(item, index),
            
            SizedBox(height: 16),
            
            // Sadece notlar (müşteri kaldırıldı)
            TextFormField(
              initialValue: item.notes,
              decoration: InputDecoration(
                labelText: 'Ürün Notları (İsteğe Bağlı)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.note_alt),
              ),
              maxLines: 2,
              onChanged: (value) {
                _updateSaleItem(index, item.copyWith(notes: value));
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLotSelection(SaleItem item, int index) {
    if (item.availableLots.isEmpty) {
      return Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.orange.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.orange.shade300),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Icon(Icons.warning, color: Colors.orange),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Bu ürün için stok lotu bulunmuyor',
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            Text(
              'Satış yapabilmek için önce bu ürünü satın almanız gerekiyor.',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '📦 Lot Seçimi',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 8),
        
        // FIFO veya Manuel seçim
        Row(
          children: [
            Expanded(
              child: RadioListTile<bool>(
                contentPadding: EdgeInsets.zero,
                title: Text('🤖 Otomatik FIFO', style: TextStyle(fontSize: 14)),
                subtitle: Text('İlk giren ilk çıkar', style: TextStyle(fontSize: 12)),
                value: true,
                groupValue: item.useAutoFIFO,
                onChanged: (value) {
                  final updatedItem = item.copyWith(
                    useAutoFIFO: value!,
                    selectedLotQuantities: {},
                  );
                  _updateSaleItem(index, updatedItem);
                },
              ),
            ),
            Expanded(
              child: RadioListTile<bool>(
                contentPadding: EdgeInsets.zero,
                title: Text('✋ Manuel', style: TextStyle(fontSize: 14)),
                subtitle: Text('Kendim seçerim', style: TextStyle(fontSize: 12)),
                value: false,
                groupValue: item.useAutoFIFO,
                onChanged: (value) {
                  final updatedItem = item.copyWith(useAutoFIFO: value!);
                  _updateSaleItem(index, updatedItem);
                },
              ),
            ),
          ],
        ),
        
        SizedBox(height: 8),
        
        // Lot listesi
        Container(
          height: 150,
          child: ListView.builder(
            itemCount: item.availableLots.length,
            itemBuilder: (context, lotIndex) {
              return _buildLotItem(item, index, item.availableLots[lotIndex]);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildLotItem(SaleItem item, int itemIndex, Map<String, dynamic> lot) {
    final lotId = lot['id'] ?? lot['lotId'];
    final batchNumber = lot['batch_number'] ?? lot['batchNumber'];
    final remainingQty = lot['remaining_quantity'] ?? lot['remainingQuantity'] ?? 0;
    final purchasePrice = (lot['purchase_price'] ?? lot['purchasePrice'] ?? 0.0).toDouble();
    final purchaseDate = lot['purchase_date'] is DateTime 
        ? lot['purchase_date'] 
        : lot['purchaseDate'] is DateTime 
            ? lot['purchaseDate']
            : DateTime.now();
    final supplierName = lot['supplier_name'] ?? lot['supplierName'];
    
    return Container(
      margin: EdgeInsets.only(bottom: 4),
      padding: EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      batchNumber ?? 'LOT-$lotId',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                    Text(
                      'Tedarikçi: ${supplierName ?? "Bilinmiyor"}',
                      style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                    ),
                    Text(
                      'Tarih: ${DateFormat('dd.MM.yyyy').format(purchaseDate)}',
                      style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '$remainingQty ${item.product['unit'] ?? 'adet'}',
                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 12),
                  ),
                  Text(
                    '₺${purchasePrice.toStringAsFixed(2)}',
                    style: TextStyle(fontSize: 10, color: Colors.blue),
                  ),
                ],
              ),
            ],
          ),
          
          // Manuel seçim modunda quantity input
          if (!item.useAutoFIFO) ...[
            SizedBox(height: 4),
            Row(
              children: [
                Text('Miktar: ', style: TextStyle(fontSize: 12)),
                SizedBox(width: 8),
                Container(
                  width: 60,
                  height: 30,
                  child: TextFormField(
                    initialValue: item.selectedLotQuantities[lotId]?.toString() ?? '0',
                    keyboardType: TextInputType.number,
                    style: TextStyle(fontSize: 12),
                    decoration: InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      isDense: true,
                    ),
                    onChanged: (value) {
                      final quantity = int.tryParse(value) ?? 0;
                      final newSelectedQuantities = Map<int, int>.from(item.selectedLotQuantities);
                      
                      if (quantity > 0 && quantity <= remainingQty) {
                        newSelectedQuantities[lotId] = quantity;
                      } else {
                        newSelectedQuantities.remove(lotId);
                      }
                      
                      final updatedItem = item.copyWith(selectedLotQuantities: newSelectedQuantities);
                      _updateSaleItem(itemIndex, updatedItem);
                    },
                  ),
                ),
                SizedBox(width: 4),
                Text('/ $remainingQty', style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildGlobalSettingsCard() {
    return Card(
      margin: EdgeInsets.all(16),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '⚙️ Genel Ayarlar',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            
            // Müşteri adı
            TextFormField(
              controller: _globalCustomerController,
              decoration: InputDecoration(
                labelText: 'Müşteri Adı',
                hintText: 'Tüm satışlar için geçerli',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person),
              ),
            ),
            
            SizedBox(height: 16),
            
            // İskonto ve uygula butonu
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: _globalDiscountController,
                    decoration: InputDecoration(
                      labelText: 'Genel İskonto (%)',
                      hintText: 'Tüm ürünlere uygulanır',
                      suffixText: '%',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.percent),
                    ),
                    keyboardType: TextInputType.numberWithOptions(decimal: true),
                    onChanged: (value) => _calculateTotals(),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  flex: 1,
                  child: ElevatedButton.icon(
                    onPressed: _saleItems.isNotEmpty ? _applyGlobalDiscountToAllItems : null,
                    icon: Icon(Icons.sync, size: 18),
                    label: Text('Uygula', style: TextStyle(fontSize: 12)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
              ],
            ),
            
            SizedBox(height: 16),
            
            // Genel notlar
            TextFormField(
              controller: _globalNotesController,
              decoration: InputDecoration(
                labelText: 'Genel Notlar',
                hintText: 'Tüm satışlar için geçerli notlar',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.note),
              ),
              maxLines: 2,
            ),
            
            SizedBox(height: 16),
            
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade300),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ℹ️ İskonto Sistemi',
                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue.shade700),
                  ),
                  SizedBox(height: 4),
                  Text(
                    '• "Uygula" butonuna basarak genel iskonto oranını tüm ürünlere uygulayın\n'
                    '• Daha sonra istediğiniz ürünün iskonto oranını ayrı ayrı değiştirebilirsiniz\n'
                    '• Her ürünün kendi iskonto oranı bağımsız olarak hesaplanır',
                    style: TextStyle(fontSize: 12, color: Colors.blue.shade700),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard() {
    // Ürün bazlı iskonto toplamını hesapla
    double totalItemDiscounts = 0.0;
    double totalBeforeDiscounts = 0.0;
    
    for (final item in _saleItems) {
      totalBeforeDiscounts += item.subtotal;
      totalItemDiscounts += item.discountAmount;
    }
    
    return Card(
      margin: EdgeInsets.all(16),
      color: Colors.blue.shade50,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '💰 Satış Özeti',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Brüt Satış Tutarı:'),
                Text(
                  '₺${totalBeforeDiscounts.toStringAsFixed(2)}',
                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
                ),
              ],
            ),
            
            if (totalItemDiscounts > 0) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Ürün İskontları:'),
                  Text(
                    '-₺${totalItemDiscounts.toStringAsFixed(2)}',
                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange),
                  ),
                ],
              ),
              Divider(color: Colors.grey.shade400),
            ],
            
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Net Satış Tutarı:', style: TextStyle(fontWeight: FontWeight.bold)),
                Text(
                  '₺${_totalAmount.toStringAsFixed(2)}',
                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 16),
                ),
              ],
            ),
            
            SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Toplam Maliyet:'),
                Text(
                  '₺${_totalCost.toStringAsFixed(2)}',
                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange),
                ),
              ],
            ),
            Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Kar/Zarar:', style: TextStyle(fontWeight: FontWeight.bold)),
                Text(
                  '₺${_totalProfitLoss.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: _totalProfitLoss >= 0 ? Colors.green : Colors.red,
                  ),
                ),
              ],
            ),
            if (_totalProfitLoss != 0 && _totalCost > 0) ...[
              SizedBox(height: 4),
              Text(
                'Kar Marjı: %${((_totalProfitLoss / _totalCost) * 100).toStringAsFixed(1)}',
                style: TextStyle(
                  fontSize: 12,
                  color: _totalProfitLoss >= 0 ? Colors.green : Colors.red,
                ),
              ),
            ],
            
            SizedBox(height: 12),
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 16, color: Colors.grey.shade600),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${_saleItems.length} ürün • Toplam ${_saleItems.fold<int>(0, (sum, item) => sum + item.quantity)} adet',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('🛒 Gelişmiş Toplu Satış'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        actions: [
          if (_saleItems.isNotEmpty)
            IconButton(
              icon: Icon(Icons.clear_all),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: Text('Listeyi Temizle'),
                    content: Text('Tüm ürünleri listeden kaldırmak istediğinizden emin misiniz?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text('İptal'),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.pop(context);
                          setState(() {
                            _saleItems.clear();
                          });
                          _calculateTotals();
                        },
                        child: Text('Temizle'),
                      ),
                    ],
                  ),
                );
              },
              tooltip: 'Listeyi Temizle',
            ),
        ],
      ),
      body: _isLoadingProducts
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Barkod giriş alanı
                  _buildBarcodeInput(),
                  
                  // Ürün seçici
                  _buildProductSelector(),
                  
                  // Genel ayarlar
                  _buildGlobalSettingsCard(),
                  
                  // Seçilen ürünler
                  if (_saleItems.isNotEmpty) ...[
                    Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(
                        '📋 Satış Listesi (${_saleItems.length} ürün)',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                    
                    ...List.generate(
                      _saleItems.length, 
                      (index) => _buildSaleItemCard(_saleItems[index], index),
                    ),
                    
                    // Özet
                    _buildSummaryCard(),
                    
                    // Satış butonu
                    Container(
                      width: double.infinity,
                      margin: EdgeInsets.all(16),
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _processBulkSale,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: _isLoading
                            ? Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                      strokeWidth: 2,
                                    ),
                                  ),
                                  SizedBox(width: 12),
                                  Text('Satışlar İşleniyor...'),
                                ],
                              )
                            : Text(
                                'Toplu Satışı Tamamla (${_saleItems.length} Ürün)',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                      ),
                    ),
                  ] else ...[
                    Container(
                      margin: EdgeInsets.all(32),
                      padding: EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            Icons.shopping_cart_outlined,
                            size: 64,
                            color: Colors.grey.shade400,
                          ),
                          SizedBox(height: 16),
                          Text(
                            'Satış listesi boş',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Barkod okutarak veya manuel seçim yaparak ürün ekleyin',
                            style: TextStyle(color: Colors.grey.shade600),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ],
                  
                  SizedBox(height: 20),
                ],
              ),
            ),
    );
  }
} 