import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/product.dart';
import '../models/inventory_transaction.dart';
import '../services/inventory_service.dart';

class ReturnScreen extends StatefulWidget {
  final Map<String, dynamic> product;

  const ReturnScreen({Key? key, required this.product}) : super(key: key);

  @override
  _ReturnScreenState createState() => _ReturnScreenState();
}

class _ReturnScreenState extends State<ReturnScreen> {
  final _formKey = GlobalKey<FormState>();
  final _quantityController = TextEditingController();
  final _customerNameController = TextEditingController();
  final _notesController = TextEditingController();
  
  // Lot controllers for manual entry
  final Map<dynamic, TextEditingController> _lotControllers = {};
  
  late String returnType;
  List<Map<String, dynamic>> availableLots = [];
  Map<dynamic, int> selectedLotQuantities = {};
  bool useAutoFIFO = true;
  bool isLoading = false;
  double totalCost = 0.0;
  double totalReturnAmount = 0.0; // İade tutarı
  
  @override
  void initState() {
    super.initState();
    returnType = TransactionType.returnSale; // Default to sale return
    _loadAvailableLots();
    _quantityController.addListener(_calculateTotals);
  }

  Future<void> _loadAvailableLots() async {
    try {
      // Product ID'yi doğru şekilde al
      final productId = widget.product['id']?.toString() ?? '';
      print('🔍 [RETURN] Lot yükleme başlatılıyor - Ürün ID: $productId');
      print('🔍 [RETURN] Ürün adı: ${widget.product['name']}');
      print('🔍 [RETURN] İade türü: $returnType');
      print('🔍 [RETURN] Ürün verisi: ${widget.product}');
      
      if (productId.isEmpty) {
        print('❌ [RETURN] Ürün ID boş!');
        setState(() {
          availableLots = [];
        });
        return;
      }
      
      List<Map<String, dynamic>> lots;
      
      if (returnType == TransactionType.returnSale) {
        // Müşteri iadesi: satış lotlarını getir
        lots = await InventoryService().getSaleLots(productId);
        print('📦 [RETURN] Müşteri iadesi için ${lots.length} satış lotu yüklendi');
      } else {
        // Tedarikçi iadesi: stok lotlarını getir
        lots = await InventoryService().getAvailableLots(productId);
        print('📦 [RETURN] Tedarikçi iadesi için ${lots.length} stok lotu yüklendi');
      }
      
      if (lots.isNotEmpty) {
        print('✅ [RETURN] İlk lot örneği: ${lots.first}');
      } else {
        print('❌ [RETURN] Hiç lot bulunamadı - Ürün ID: $productId, İade türü: $returnType');
      }
      
      setState(() {
        availableLots = lots;
        // İade türü değiştiğinde manuel seçimleri temizle
        selectedLotQuantities.clear();
        _calculateTotals();
      });
    } catch (e) {
      print('❌ [RETURN] Lot yükleme hatası: $e');
      setState(() {
        availableLots = [];
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lot bilgileri yüklenirken hata: $e')),
      );
    }
  }

  void _calculateTotals() {
    final quantity = int.tryParse(_quantityController.text) ?? 0;
    
    setState(() {
      if (useAutoFIFO) {
        _calculateFIFOCost(quantity);
      } else {
        _calculateManualCost();
      }
    });
  }

  void _calculateFIFOCost(int requestedQuantity) {
    double cost = 0.0;
    double returnAmount = 0.0;
    int remaining = requestedQuantity;
    
    if (returnType == TransactionType.returnSale) {
      // Satış iadesi: Satış fiyatından hesapla
      final sortedLots = List<Map<String, dynamic>>.from(availableLots);
      sortedLots.sort((a, b) {
        final dateA = a['transaction_date'] as DateTime? ?? DateTime.now();
        final dateB = b['transaction_date'] as DateTime? ?? DateTime.now();
        return dateB.compareTo(dateA); // LIFO (en yeni önce)
      });
      
      for (final lot in sortedLots) {
        if (remaining <= 0) break;
        
        final availableQty = lot['quantity'] ?? 0;
        final salePrice = (lot['unit_price'] ?? 0.0).toDouble();
        final usedQty = remaining < availableQty ? remaining : availableQty;
        
        returnAmount += usedQty * salePrice;
        remaining -= usedQty as int;
      }
    } else {
      // Tedarikçi iadesi: Alış fiyatından hesapla
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
        return dateA.compareTo(dateB); // FIFO (en eski önce)
      });
      
      for (final lot in sortedLots) {
        if (remaining <= 0) break;
        
        final availableQty = lot['remaining_quantity'] ?? lot['remainingQuantity'] ?? 0;
        final purchasePrice = (lot['purchase_price'] ?? lot['purchasePrice'] ?? 0.0).toDouble();
        final usedQty = remaining < availableQty ? remaining : availableQty;
        
        cost += usedQty * purchasePrice;
        returnAmount += usedQty * purchasePrice;
        remaining -= usedQty as int;
      }
    }
    
    totalCost = cost;
    totalReturnAmount = returnAmount;
  }

  void _calculateManualCost() {
    double cost = 0.0;
    double returnAmount = 0.0;
    
    selectedLotQuantities.forEach((lotId, quantity) {
      final lot = availableLots.firstWhere(
        (l) => (l['id'] ?? l['lotId'] ?? l['sale_id']) == lotId,
        orElse: () => {},
      );
      if (lot.isNotEmpty) {
        if (returnType == TransactionType.returnSale) {
          // Satış iadesi: Satış fiyatından hesapla
          final salePrice = (lot['unit_price'] ?? 0.0).toDouble();
          returnAmount += quantity * salePrice;
        } else {
          // Tedarikçi iadesi: Alış fiyatından hesapla
          final purchasePrice = (lot['purchase_price'] ?? lot['purchasePrice'] ?? 0.0).toDouble();
          cost += quantity * purchasePrice;
          returnAmount += quantity * purchasePrice;
        }
      }
    });
    
    totalCost = cost;
    totalReturnAmount = returnAmount;
  }

  Future<void> _processReturn() async {
    if (!_formKey.currentState!.validate()) return;
    
    int quantity;
    double unitPrice;
    String? customerName;
    
    if (useAutoFIFO) {
      // Otomatik FIFO modunda: miktar alanından al
      quantity = int.parse(_quantityController.text);
      unitPrice = totalReturnAmount / quantity; // Ortalama birim fiyat
      
      // Satış iadesi için müşteri adını ilk lottan al
      if (returnType == TransactionType.returnSale && availableLots.isNotEmpty) {
        customerName = availableLots.first['customer_name'];
      }
    } else {
      // Manuel seçim modunda: seçilen lot miktarlarının toplamını al
      quantity = selectedLotQuantities.values.fold(0, (sum, qty) => sum + qty);
      
      if (quantity <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lütfen iade miktarlarını giriniz!')),
        );
        return;
      }
      
      unitPrice = totalReturnAmount / quantity; // Ortalama birim fiyat
      
      // Satış iadesi için müşteri adını seçilen lotlardan al (en yaygın olanı)
      if (returnType == TransactionType.returnSale) {
        final Map<String, int> customerCounts = {};
        selectedLotQuantities.forEach((lotId, qty) {
          final lot = availableLots.firstWhere(
            (l) => (l['sale_id'] ?? l['id']) == lotId,
            orElse: () => {},
          );
          if (lot.isNotEmpty) {
            final customer = lot['customer_name'] ?? 'Bilinmiyor';
            customerCounts[customer] = (customerCounts[customer] ?? 0) + qty;
          }
        });
        
        // En çok iade yapılan müşteriyi seç
        if (customerCounts.isNotEmpty) {
          customerName = customerCounts.entries
              .reduce((a, b) => a.value > b.value ? a : b)
              .key;
        }
      }
    }
    
    setState(() {
      isLoading = true;
    });
    
    try {
      await InventoryService().addReturn(
        productId: widget.product['id'].toString(),
        productName: widget.product['name'],
        quantity: quantity,
        unitPrice: unitPrice,
        returnType: returnType, // İade türünü service'e gönder
        customerName: customerName, // Lottan alınan müşteri adı
        notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        selectedLotQuantities: useAutoFIFO ? null : selectedLotQuantities, // Manuel seçim durumunda lot bilgileri
      );
      
      // Başarı mesajı
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green),
              SizedBox(width: 8),
              Text('İade Tamamlandı'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('✅ İade başarıyla kaydedildi'),
              SizedBox(height: 8),
              Text('📦 Miktar: $quantity ${widget.product['unit']}'),
              Text('💰 Ortalama Birim Fiyat: ₺${unitPrice.toStringAsFixed(2)}'),
              Text('💵 Toplam: ₺${totalReturnAmount.toStringAsFixed(2)}'),
              Text('🔄 Tür: ${returnType == TransactionType.returnSale ? "Satış İadesi" : "Alış İadesi"}'),
              if (customerName != null && returnType == TransactionType.returnSale)
                Text('👤 Müşteri: $customerName'),
              if (!useAutoFIFO && selectedLotQuantities.isNotEmpty)
                Text('📦 Lot Seçimi: Manuel (${selectedLotQuantities.length} lot)'),
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
          content: Text('İade hatası: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('🔄 İade İşlemi'),
        backgroundColor: Colors.amber,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Ürün bilgisi
            Card(
              margin: EdgeInsets.all(16),
              child: ListTile(
                leading: Icon(Icons.inventory, color: Colors.amber, size: 40),
                title: Text(
                  widget.product['name'],
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('SKU: ${widget.product['sku']}'),
                    Text('Mevcut Stok: ${widget.product['currentStock']} ${widget.product['unit']}'),
                  ],
                ),
              ),
            ),
            
            // İade türü seçimi
            Card(
              margin: EdgeInsets.all(16),
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '🔄 İade Türü',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 16),
                    
                    RadioListTile<String>(
                      title: Text('📤 Satış İadesi'),
                      subtitle: Text('Müşteriden gelen iade (stok artar)'),
                      value: TransactionType.returnSale,
                      groupValue: returnType,
                      onChanged: (value) {
                        setState(() {
                          returnType = value!;
                          // İade türü değiştiğinde lotları yeniden yükle
                          _loadAvailableLots();
                        });
                      },
                    ),
                    RadioListTile<String>(
                      title: Text('📥 Alış İadesi'),
                      subtitle: Text('Tedarikçiye yapılan iade (stok azalır)'),
                      value: TransactionType.returnPurchase,
                      groupValue: returnType,
                      onChanged: (value) {
                        setState(() {
                          returnType = value!;
                          // İade türü değiştiğinde lotları yeniden yükle
                          _loadAvailableLots();
                        });
                      },
                    ),
                  ],
                ),
              ),
            ),
            
            // Lot seçimi kartı - her zaman göster
            _buildLotSelectionCard(),
            
            // İade formu
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
                        '📝 İade Bilgileri',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 16),
                      
                      Row(
                        children: [
                          // Miktar alanı sadece otomatik FIFO modunda gösterilir
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
                                  return null;
                                },
                              ),
                            ),
                          ],
                          
                          // Manuel seçimde toplam miktar ve tutar göstergesi
                          if (!useAutoFIFO) ...[
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
                                      'Toplam İade:',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.blue.shade700,
                                      ),
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      '${selectedLotQuantities.values.fold(0, (sum, qty) => sum + qty)} ${widget.product['unit']}',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.blue.shade800,
                                      ),
                                    ),
                                    Text(
                                      '₺${totalReturnAmount.toStringAsFixed(2)}',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.green.shade700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      SizedBox(height: 16),
                      
                      TextFormField(
                        controller: _notesController,
                        decoration: InputDecoration(
                          labelText: 'İade Sebebi / Notlar (İsteğe Bağlı)',
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 3,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            
            // İade butonu
            Container(
              width: double.infinity,
              margin: EdgeInsets.all(16),
              child: ElevatedButton(
                onPressed: isLoading ? null : _processReturn,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 16),
                ),
                child: isLoading
                    ? CircularProgressIndicator(color: Colors.white)
                    : Text(
                        'İadeyi Tamamla',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
              ),
            ),
            
            SizedBox(height: 20),
            
            if (totalCost > 0) ...[
              Divider(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Toplam Maliyet:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '₺${totalCost.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ],
            
            // Toplam iade tutarı göster (her zaman)
            if (totalReturnAmount > 0) ...[
              Divider(),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade300),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Toplam İade Tutarı:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade700,
                          ),
                        ),
                        if (useAutoFIFO && _quantityController.text.isNotEmpty)
                          Text(
                            '${_quantityController.text} ${widget.product['unit']}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.blue.shade600,
                            ),
                          ),
                        if (!useAutoFIFO)
                          Text(
                            '${selectedLotQuantities.values.fold(0, (sum, qty) => sum + qty)} ${widget.product['unit']}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.blue.shade600,
                            ),
                          ),
                      ],
                    ),
                    Text(
                      '₺${totalReturnAmount.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade700,
                        fontSize: 18,
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

  Widget _buildLotSelectionCard() {
    return Card(
      margin: EdgeInsets.all(16),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '📦 İade Lot Seçimi',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              returnType == TransactionType.returnSale 
                  ? 'Müşteri iadesi için hangi satıştan iade yapılacağını seçin'
                  : 'Tedarikçi iadesi için hangi lot\'tan iade yapılacağını seçin',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
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
                        selectedLotQuantities.clear();
                        _calculateTotals();
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
                        _calculateTotals();
                      });
                    },
                  ),
                ),
              ],
            ),
            
            Divider(),
            
            // Mevcut lot'lar
            Text(
              returnType == TransactionType.returnSale ? 'Geçmiş Satışlar:' : 'Mevcut Stok Lotları:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            
            if (availableLots.isEmpty)
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
                            returnType == TransactionType.returnSale 
                                ? 'Bu ürün için satış kaydı bulunamadı'
                                : 'Bu ürün için stok lotu bulunamadı',
                            style: TextStyle(fontWeight: FontWeight.w500),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 12),
                    Text(
                      returnType == TransactionType.returnSale 
                          ? 'Müşteri iadesi yapabilmek için önce bu ürünü satmalısınız.'
                          : 'Tedarikçi iadesi yapabilmek için önce bu ürünü satın almanız gerekiyor.',
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                    ),
                  ],
                ),
              )
            else
              ...availableLots.map((lot) => _buildLotItem(lot)).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildLotItem(Map<String, dynamic> lot) {
    final isSaleLot = returnType == TransactionType.returnSale;
    
    if (isSaleLot) {
      // Satış lotu görünümü (yeşil)
      final saleId = lot['sale_id'] ?? lot['id'];
      final customerName = lot['customer_name'] ?? 'Bilinmiyor';
      final transactionDate = lot['transaction_date'] as DateTime;
      final unitPrice = (lot['unit_price'] ?? 0.0).toDouble();
      final totalAmount = (lot['total_amount'] ?? 0.0).toDouble();
      final availableQty = lot['available_quantity'] ?? lot['quantity'] ?? 0; // İade edilebilir miktar
      final originalQty = lot['original_quantity'] ?? lot['quantity'] ?? 0; // Orijinal miktar
      final returnedQty = lot['returned_quantity'] ?? 0; // İade edilen miktar
      
      return Card(
        margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        color: Colors.green.shade50,
        child: Column(
          children: [
            ListTile(
              leading: Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.sell, color: Colors.white),
              ),
              title: Text(
                'SATIŞ-${saleId.toString().substring(0, 8)}',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('👤 Müşteri: $customerName'),
                  Text('📅 ${DateFormat('dd/MM/yyyy HH:mm').format(transactionDate)}'),
                  Text('💰 Birim: ₺${unitPrice.toStringAsFixed(2)} | Toplam: ₺${totalAmount.toStringAsFixed(2)}'),
                  if (returnedQty > 0)
                    Text('🔄 İade durumu: ${availableQty}/${originalQty} kaldı (${returnedQty} iade)', 
                         style: TextStyle(color: Colors.orange)),
                ],
              ),
              trailing: useAutoFIFO 
                  ? Text('${availableQty} ${widget.product['unit']}', 
                         style: TextStyle(fontWeight: FontWeight.bold))
                  : Container(
                      width: 60,
                      child: TextFormField(
                        controller: _getLotController(saleId, availableQty),
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        decoration: InputDecoration(
                          hintText: '0',
                          helperText: 'Max: $availableQty',
                          helperStyle: TextStyle(fontSize: 10),
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        ),
                        onChanged: (value) {
                          final qty = int.tryParse(value) ?? 0;
                          if (qty > availableQty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Miktar ${availableQty} adetten fazla olamaz!')),
                            );
                            _lotControllers[saleId]?.text = availableQty.toString();
                            selectedLotQuantities[saleId] = availableQty;
                          } else if (qty <= 0) {
                            selectedLotQuantities.remove(saleId);
                          } else {
                            selectedLotQuantities[saleId] = qty;
                          }
                          _calculateManualCost();
                          setState(() {});
                        },
                        validator: (value) {
                          final qty = int.tryParse(value ?? '') ?? 0;
                          if (qty < 0) return 'Geçersiz miktar';
                          if (qty > availableQty) return 'Fazla miktar';
                          return null;
                        },
                      ),
                    ),
            ),
          ],
        ),
      );
    } else {
      // Stok lotu için bilgiler (önceki kod)
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
              Row(
                children: [
                  Text('İade Miktarı: '),
                  SizedBox(width: 8),
                  Container(
                    width: 80,
                    child: TextFormField(
                      controller: _getLotController(lotId, remainingQty),
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        hintText: '0',
                        helperText: 'Max: $remainingQty',
                        helperStyle: TextStyle(fontSize: 10),
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      ),
                      onChanged: (value) {
                        final quantity = int.tryParse(value) ?? 0;
                        if (quantity > remainingQty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Miktar ${remainingQty} adetten fazla olamaz!')),
                          );
                          _lotControllers[lotId]?.text = remainingQty.toString();
                          selectedLotQuantities[lotId] = remainingQty;
                        } else if (quantity <= 0) {
                          selectedLotQuantities.remove(lotId);
                        } else {
                          selectedLotQuantities[lotId] = quantity;
                        }
                        _calculateTotals();
                        setState(() {});
                      },
                    ),
                  ),
                  SizedBox(width: 8),
                  Text('/ $remainingQty max'),
                ],
              ),
            ],
          ],
        ),
      );
    }
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _customerNameController.dispose();
    _notesController.dispose();
    // Lot controller'larını ve listener'larını temizle
    _lotControllers.values.forEach((controller) {
      controller.removeListener(() {});
      controller.dispose();
    });
    _lotControllers.clear();
    super.dispose();
  }

  // Lot controller'ını getir veya oluştur
  TextEditingController _getLotController(dynamic lotId, int maxQuantity) {
    if (!_lotControllers.containsKey(lotId)) {
      final currentValue = selectedLotQuantities[lotId] ?? 0;
      _lotControllers[lotId] = TextEditingController(
        text: currentValue > 0 ? currentValue.toString() : ''
      );
      
      // Controller'a listener ekle
      _lotControllers[lotId]!.addListener(() {
        final text = _lotControllers[lotId]!.text;
        final qty = int.tryParse(text) ?? 0;
        
        // Değer değiştiyse ve geçerliyse güncelle
        if (qty <= maxQuantity) {
          if (qty > 0) {
            selectedLotQuantities[lotId] = qty;
          } else {
            selectedLotQuantities.remove(lotId);
          }
        }
      });
    }
    return _lotControllers[lotId]!;
  }
} 