import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/product.dart';
import '../models/inventory_transaction.dart';
import '../services/inventory_service.dart';

class AdvancedSaleScreen extends StatefulWidget {
  final Map<String, dynamic> product;

  const AdvancedSaleScreen({Key? key, required this.product}) : super(key: key);

  @override
  _AdvancedSaleScreenState createState() => _AdvancedSaleScreenState();
}

class _AdvancedSaleScreenState extends State<AdvancedSaleScreen> {
  final _formKey = GlobalKey<FormState>();
  final _quantityController = TextEditingController();
  final _unitPriceController = TextEditingController();
  final _customerNameController = TextEditingController();
  final _notesController = TextEditingController();
  final _discountController = TextEditingController(text: '0');
  
  List<Map<String, dynamic>> availableLots = [];
  Map<dynamic, int> selectedLotQuantities = {}; // lotId: quantity
  Map<dynamic, TextEditingController> _lotControllers = {}; // lotId: controller
  bool isLoading = true;
  bool useAutoFIFO = true;
  
  double totalCost = 0.0;
  double totalSaleAmount = 0.0;
  double discountAmount = 0.0;
  double finalAmount = 0.0;
  
  double profitLoss = 0.0;
  
  @override
  void initState() {
    super.initState();
    
    // Unit price'ı ürünün varsayılan satış fiyatı ile başlat
    final defaultPrice = widget.product['sale_price']?.toString() ?? '';
    if (defaultPrice.isNotEmpty && double.tryParse(defaultPrice) != null) {
      _unitPriceController.text = defaultPrice;
    }
    
    _loadAvailableLots();
    _quantityController.addListener(_calculateTotals);
    _unitPriceController.addListener(_calculateTotals);
    _discountController.addListener(_calculateTotals);
  }

  Future<void> _loadAvailableLots() async {
    try {
      // Product ID'yi doğru şekilde al
      final productId = widget.product['id']?.toString() ?? '';
      print('🔍 Lot yükleme başlatılıyor - Ürün ID: $productId');
      print('🔍 Ürün verisi: ${widget.product}');
      
      if (productId.isEmpty) {
        print('❌ Ürün ID boş!');
        setState(() {
          availableLots = [];
          isLoading = false;
        });
        return;
      }
      
      final lots = await InventoryService().getAvailableLots(productId);
      print('📦 Yüklenen lot sayısı: ${lots.length}');
      
      if (lots.isNotEmpty) {
        print('✅ İlk lot örneği: ${lots.first}');
      } else {
        print('❌ Hiç lot bulunamadı - Ürün ID: $productId');
        // Firebase'de bu ürün için lot var mı kontrol et
        print('🔍 Firebase\'de lot kontrolü yapılıyor...');
      }
      
      setState(() {
        availableLots = lots;
        isLoading = false;
        // Lot değiştiğinde controller'ları ve seçimleri temizle
        _clearLotSelections();
      });
    } catch (e) {
      print('❌ Lot yükleme hatası: $e');
      setState(() {
        availableLots = [];
        isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lot bilgileri yüklenirken hata: $e')),
      );
    }
  }

  void _clearLotSelections() {
    // Sadece seçimleri temizle, controller'ları korunnmasın çünkü yeniden oluşturulacak
    selectedLotQuantities.clear();
    _calculateTotals();
  }

  void _clearAllLotData() {
    // Tüm lot verilerini temizle (mod değişikliğinde kullan)
    _lotControllers.values.forEach((controller) => controller.dispose());
    _lotControllers.clear();
    selectedLotQuantities.clear();
    _calculateTotals();
  }

  void _calculateTotals() {
    int quantity;
    
    if (useAutoFIFO) {
      // Otomatik FIFO modunda miktar giriş alanından al
      quantity = int.tryParse(_quantityController.text) ?? 0;
    } else {
      // Manuel seçimde seçilen lot miktarlarının toplamını al
      quantity = selectedLotQuantities.values.fold(0, (sum, qty) => sum + qty);
    }
    
    final unitPrice = double.tryParse(_unitPriceController.text) ?? 0.0;
    final discountPercent = double.tryParse(_discountController.text) ?? 0.0;
    
    setState(() {
      // Brüt satış tutarı
      totalSaleAmount = quantity * unitPrice;
      
      // İskonto tutarı
      discountAmount = totalSaleAmount * (discountPercent / 100);
      
      // Net satış tutarı (iskonto sonrası)
      finalAmount = totalSaleAmount - discountAmount;
      
      if (useAutoFIFO) {
        _calculateFIFOCost(quantity);
      } else {
        _calculateManualCost();
      }
      
      profitLoss = totalSaleAmount - totalCost;
    });
  }

  void _calculateFIFOCost(int requestedQuantity) {
    double cost = 0.0;
    int remaining = requestedQuantity;
    
    // FIFO sıralaması: En eski lot'lardan başla
    final sortedLots = List<Map<String, dynamic>>.from(availableLots);
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
    
    totalCost = cost;
  }

  void _calculateManualCost() {
    double cost = 0.0;
    
    selectedLotQuantities.forEach((lotId, quantity) {
      final lot = availableLots.firstWhere(
        (l) => (l['id'] ?? l['lotId']) == lotId,
        orElse: () => {},
      );
      if (lot.isNotEmpty) {
        final price = (lot['purchase_price'] ?? lot['purchasePrice'] ?? 0.0).toDouble();
        cost += quantity * price;
      }
    });
    
    totalCost = cost;
  }

  Widget _buildLotSelectionCard() {
    return Card(
      margin: EdgeInsets.all(16),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '📦 Stok Lot Seçimi',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            
            // FIFO veya Manuel seçim
            Row(
              children: [
                Expanded(
                  child: RadioListTile<bool>(
                    title: Text('🤖 Otomatik FIFO'),
                    subtitle: Text('İlk giren ilk çıkar'),
                    value: true,
                    groupValue: useAutoFIFO,
                    onChanged: (value) {
                      setState(() {
                        useAutoFIFO = value!;
                        _clearAllLotData();
                        print('🔄 FIFO moduna geçildi, lot seçimleri temizlendi');
                      });
                    },
                  ),
                ),
                Expanded(
                  child: RadioListTile<bool>(
                    title: Text('✋ Manuel Seçim'),
                    subtitle: Text('Lot\'ları kendim seçerim'),
                    value: false,
                    groupValue: useAutoFIFO,
                    onChanged: (value) {
                      setState(() {
                        useAutoFIFO = value!;
                        _clearAllLotData();
                        print('🔄 Manuel seçim moduna geçildi, lot seçimleri temizlendi');
                      });
                    },
                  ),
                ),
              ],
            ),
            
            Divider(),
            
            // Mevcut lot'lar
            if (availableLots.isNotEmpty) ...[
              Text(
                'Mevcut Stok Lot\'ları:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              
              ...availableLots.map((lot) => _buildLotItem(lot)).toList(),
            ] else ...[
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade300),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info, color: Colors.blue),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Bu ürün için henüz stok lotu bulunmuyor',
                            style: TextStyle(fontWeight: FontWeight.w500),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 12),
                    Text(
                      'Satış yapabilmek için önce bu ürünü satın almanız gerekiyor. Satın alma işlemi yaparak stok lotu oluşturabilirsiniz.',
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                    ),
                    SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          Navigator.pushNamed(context, '/purchase', arguments: widget.product);
                        },
                        icon: Icon(Icons.shopping_cart),
                        label: Text('Satın Alma Yap'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLotItem(Map<String, dynamic> lot) {
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
    
    // Her lot için persistent controller oluştur veya mevcut olanı kullan
    if (!_lotControllers.containsKey(lotId)) {
      _lotControllers[lotId] = TextEditingController(
        text: selectedLotQuantities[lotId]?.toString() ?? ''
      );
    }
    
    final lotController = _lotControllers[lotId]!;
    
    return Container(
      margin: EdgeInsets.only(bottom: 8),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
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
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Tedarikçi: ${supplierName ?? "Bilinmiyor"}',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                    Text(
                      'Tarih: ${DateFormat('dd.MM.yyyy').format(purchaseDate)}',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '$remainingQty ${widget.product['unit'] ?? 'adet'}',
                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
                  ),
                  Text(
                    '₺${purchasePrice.toStringAsFixed(2)}',
                    style: TextStyle(fontSize: 12, color: Colors.blue),
                  ),
                ],
              ),
            ],
          ),
          
          // Manuel seçim modunda quantity input
          if (!useAutoFIFO) ...[
            SizedBox(height: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Satılacak Miktar:',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade700,
                  ),
                ),
                SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        key: ValueKey('lot_input_$lotId'), // Her lot için unique key
                        controller: lotController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                          hintText: '0',
                          isDense: true,
                        ),
                        onChanged: (value) {
                          print('🔄 Lot değişikliği - LotId: $lotId, Value: "$value"');
                          
                          if (value.isEmpty) {
                            setState(() {
                              selectedLotQuantities.remove(lotId);
                              _calculateTotals();
                            });
                            return;
                          }
                          
                          final quantity = int.tryParse(value);
                          print('🔄 Parsed quantity: $quantity, Max: $remainingQty');
                          
                          if (quantity != null) {
                            setState(() {
                              if (quantity > 0 && quantity <= remainingQty) {
                                selectedLotQuantities[lotId] = quantity;
                                print('✅ Lot quantity set: $lotId = $quantity');
                              } else if (quantity > remainingQty) {
                                // Maksimum miktarı aşıyorsa uyarı ver ama değeri güncelleme
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Maksimum miktar: $remainingQty'),
                                    duration: Duration(seconds: 1),
                                  ),
                                );
                                // Controller'ı geri eski değere döndür
                                lotController.text = selectedLotQuantities[lotId]?.toString() ?? '';
                                lotController.selection = TextSelection.fromPosition(
                                  TextPosition(offset: lotController.text.length),
                                );
                                return;
                              } else if (quantity <= 0) {
                                selectedLotQuantities.remove(lotId);
                                print('🗑️ Lot quantity removed: $lotId');
                              }
                              print('📊 Current selected quantities: $selectedLotQuantities');
                              _calculateTotals();
                            });
                          }
                        },
                        onTap: () {
                          // Tıklandığında tüm metni seç
                          lotController.selection = TextSelection(
                            baseOffset: 0,
                            extentOffset: lotController.text.length,
                          );
                        },
                      ),
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      flex: 1,
                      child: Text(
                        '/ $remainingQty max',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSummaryCard() {
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
                  '₺${totalSaleAmount.toStringAsFixed(2)}',
                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
                ),
              ],
            ),
            
            if (discountAmount > 0) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('İskonto:'),
                  Text(
                    '-₺${discountAmount.toStringAsFixed(2)}',
                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange),
                  ),
                ],
              ),
              Divider(color: Colors.grey.shade400),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Net Satış Tutarı:', style: TextStyle(fontWeight: FontWeight.bold)),
                  Text(
                    '₺${finalAmount.toStringAsFixed(2)}',
                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 16),
                  ),
                ],
              ),
            ] else ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Net Satış Tutarı:', style: TextStyle(fontWeight: FontWeight.bold)),
                  Text(
                    '₺${totalSaleAmount.toStringAsFixed(2)}',
                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 16),
                  ),
                ],
              ),
            ],
            
            SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Maliyet:'),
                Text(
                  '₺${totalCost.toStringAsFixed(2)}',
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
                  '₺${(finalAmount - totalCost).toStringAsFixed(2)}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: (finalAmount - totalCost) >= 0 ? Colors.green : Colors.red,
                  ),
                ),
              ],
            ),
            if ((finalAmount - totalCost) != 0 && totalCost > 0) ...[
              SizedBox(height: 4),
              Text(
                'Kar Marjı: %${(((finalAmount - totalCost) / totalCost) * 100).toStringAsFixed(1)}',
                style: TextStyle(
                  fontSize: 12,
                  color: (finalAmount - totalCost) >= 0 ? Colors.green : Colors.red,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _processSale() async {
    if (_formKey.currentState?.validate() != true) return;
    
    int quantity;
    
    if (useAutoFIFO) {
      // Otomatik FIFO modunda miktar giriş alanından al
      quantity = int.parse(_quantityController.text);
    } else {
      // Manuel seçimde seçilen lot miktarlarının toplamını al
      quantity = selectedLotQuantities.values.fold(0, (sum, qty) => sum + qty);
      
      if (quantity <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lütfen lot seçimi yapınız!')),
        );
        return;
      }
    }
    
    final unitPrice = double.parse(_unitPriceController.text);
    final discountPercent = double.tryParse(_discountController.text) ?? 0.0;
    
    try {
      await InventoryService().addSale(
        productId: widget.product['id']?.toString() ?? '',
        productName: widget.product['name'],
        quantity: quantity,
        unitPrice: unitPrice,
        customerName: _customerNameController.text.trim().isEmpty 
            ? null 
            : _customerNameController.text.trim(),
        notes: _notesController.text.trim().isEmpty 
            ? null 
            : _notesController.text.trim(),
      );
      
      // Calculate cost manually since addSale doesn't return it
      final totalCost = quantity * (widget.product['purchasePrice'] ?? unitPrice * 0.7);
      
      // Başarı mesajı
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green),
              SizedBox(width: 8),
              Text('Satış Tamamlandı'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('✅ Satış başarıyla kaydedildi'),
              SizedBox(height: 8),
              Text('💰 Brüt Tutar: ₺${totalSaleAmount.toStringAsFixed(2)}'),
              if (discountAmount > 0) ...[
                Text('🏷️ İskonto (%${discountPercent.toStringAsFixed(1)}): -₺${discountAmount.toStringAsFixed(2)}'),
                Text('💵 Net Tutar: ₺${finalAmount.toStringAsFixed(2)}', 
                     style: TextStyle(fontWeight: FontWeight.bold)),
              ],
              Text('🏷️ Maliyet: ₺${totalCost.toStringAsFixed(2)}'),
              Text(
                '📈 Kar/Zarar: ₺${(finalAmount - totalCost).toStringAsFixed(2)}',
                style: TextStyle(
                  color: (finalAmount - totalCost) >= 0 ? Colors.green : Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Dialog'u kapat
                Navigator.of(context).pop(true); // Ana sayfaya dön ve refresh et
              },
              child: Text('Tamam'),
            ),
          ],
        ),
      );
      
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Satış hatası: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Satış'),
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Ürün bilgisi
                  Card(
                    margin: EdgeInsets.all(16),
                    child: ListTile(
                      leading: Icon(Icons.inventory, color: Colors.blue, size: 40),
                      title: Text(
                        widget.product['name'],
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('SKU: ${widget.product['sku']}'),
                          Text('Mevcut Stok: ${widget.product['current_stock'] ?? widget.product['currentStock'] ?? 0} ${widget.product['unit'] ?? 'adet'}'),
                        ],
                      ),
                    ),
                  ),
                  
                  // Satış formu
                  Card(
                    margin: EdgeInsets.all(16),
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '📝 Satış Bilgileri',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            SizedBox(height: 16),
                            
                            Row(
                              children: [
                                // Miktar alanı - sadece otomatik FIFO modunda göster
                                if (useAutoFIFO) ...[
                                  Expanded(
                                    child: TextFormField(
                                      controller: _quantityController,
                                      decoration: InputDecoration(
                                        labelText: 'Miktar',
                                        suffixText: widget.product['unit'],
                                        border: OutlineInputBorder(),
                                      ),
                                      keyboardType: TextInputType.number,
                                      validator: (value) {
                                        if (value == null || value.isEmpty) {
                                          return 'Miktar giriniz';
                                        }
                                        final quantity = int.tryParse(value);
                                        if (quantity == null || quantity <= 0) {
                                          return 'Geçerli miktar giriniz';
                                        }
                                        final currentStock = widget.product['current_stock'] ?? widget.product['currentStock'] ?? 0;
                                        if (quantity > currentStock) {
                                          return 'Stokta yeterli ürün yok';
                                        }
                                        return null;
                                      },
                                    ),
                                  ),
                                  SizedBox(width: 16),
                                ] else ...[
                                  // Manuel seçimde toplam miktar göstergesi
                                  Expanded(
                                    child: Container(
                                      padding: EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: Colors.blue.shade50,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: Colors.blue.shade300),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Toplam Miktar:',
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.blue.shade700,
                                            ),
                                          ),
                                          SizedBox(height: 4),
                                          Text(
                                            '${selectedLotQuantities.values.fold(0, (sum, qty) => sum + qty)} ${widget.product['unit'] ?? 'adet'}',
                                            style: TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.blue.shade800,
                                            ),
                                          ),
                                          // Debug bilgisi
                                          if (selectedLotQuantities.isNotEmpty) ...[
                                            SizedBox(height: 4),
                                            Text(
                                              'Debug: ${selectedLotQuantities.length} lot seçili',
                                              style: TextStyle(
                                                fontSize: 10,
                                                color: Colors.grey.shade600,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: 16),
                                ],
                                Expanded(
                                  child: TextFormField(
                                    controller: _unitPriceController,
                                    decoration: InputDecoration(
                                      labelText: 'Birim Fiyat',
                                      prefixText: '₺',
                                      border: OutlineInputBorder(),
                                    ),
                                    keyboardType: TextInputType.numberWithOptions(decimal: true),
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return 'Fiyat giriniz';
                                      }
                                      final price = double.tryParse(value);
                                      if (price == null || price <= 0) {
                                        return 'Geçerli fiyat giriniz';
                                      }
                                      return null;
                                    },
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 16),
                            
                            // İskonto alanı
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _discountController,
                                    decoration: InputDecoration(
                                      labelText: 'İskonto (%)',
                                      suffixText: '%',
                                      border: OutlineInputBorder(),
                                      prefixIcon: Icon(Icons.percent),
                                    ),
                                    keyboardType: TextInputType.numberWithOptions(decimal: true),
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return null; // İsteğe bağlı
                                      }
                                      final discount = double.tryParse(value);
                                      if (discount == null || discount < 0 || discount > 100) {
                                        return '0-100 arası değer giriniz';
                                      }
                                      return null;
                                    },
                                  ),
                                ),
                                SizedBox(width: 16),
                                Expanded(
                                  child: Container(
                                    padding: EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: Colors.orange.shade50,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: Colors.orange.shade300),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'İskonto Tutarı:',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.orange.shade700,
                                          ),
                                        ),
                                        Text(
                                          '₺${discountAmount.toStringAsFixed(2)}',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.orange.shade800,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 16),
                            
                            TextFormField(
                              controller: _customerNameController,
                              decoration: InputDecoration(
                                labelText: 'Müşteri Adı (İsteğe Bağlı)',
                                border: OutlineInputBorder(),
                              ),
                            ),
                            SizedBox(height: 16),
                            
                            TextFormField(
                              controller: _notesController,
                              decoration: InputDecoration(
                                labelText: 'Notlar (İsteğe Bağlı)',
                                border: OutlineInputBorder(),
                              ),
                              maxLines: 2,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  
                  // Lot seçimi
                  _buildLotSelectionCard(),
                  
                  // Özet
                  _buildSummaryCard(),
                  
                  // Satış butonu
                  Container(
                    width: double.infinity,
                    margin: EdgeInsets.all(16),
                    child: ElevatedButton(
                      onPressed: _processSale,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: Text(
                        'Satışı Tamamla',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  
                  SizedBox(height: 20),
                ],
              ),
            ),
    );
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _unitPriceController.dispose();
    _customerNameController.dispose();
    _notesController.dispose();
    _discountController.dispose();
    // Lot controller'larını dispose et
    _lotControllers.values.forEach((controller) => controller.dispose());
    _lotControllers.clear();
    super.dispose();
  }
} 