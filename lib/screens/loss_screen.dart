import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/product.dart';
import '../models/inventory_transaction.dart';
import '../services/inventory_service.dart';

class LossScreen extends StatefulWidget {
  final Map<String, dynamic> product;

  const LossScreen({Key? key, required this.product}) : super(key: key);

  @override
  _LossScreenState createState() => _LossScreenState();
}

class _LossScreenState extends State<LossScreen> {
  final _formKey = GlobalKey<FormState>();
  final _quantityController = TextEditingController();
  final _notesController = TextEditingController();
  
  String lossReason = 'Bozulma';
  List<Map<String, dynamic>> availableLots = [];
  Map<dynamic, int> selectedLotQuantities = {}; // lotId: quantity (dynamic key)
  Map<dynamic, TextEditingController> lotControllers = {}; // lot ID'sine göre controller'lar
  bool isLoading = true;
  bool useAutoFIFO = true;
  
  double totalCost = 0.0;
  
  final List<String> lossReasons = [
    'Bozulma',
    'Kırılma',
    'Çalınma',
    'Kayıp',
    'Son Kullanma Tarihi',
    'Kalite Sorunu',
    'Diğer'
  ];

  @override
  void initState() {
    super.initState();
    _loadAvailableLots();
    _quantityController.addListener(_calculateTotals);
  }

  Future<void> _loadAvailableLots() async {
    try {
      // Product ID'yi doğru şekilde al
      final productId = widget.product['id']?.toString() ?? '';
      print('🔍 [LOSS] Lot yükleme başlatılıyor - Ürün ID: $productId');
      print('🔍 [LOSS] Ürün adı: ${widget.product['name']}');
      print('🔍 [LOSS] Ürün verisi: ${widget.product}');
      
      if (productId.isEmpty) {
        print('❌ [LOSS] Ürün ID boş!');
        setState(() {
          availableLots = [];
          isLoading = false;
        });
        return;
      }
      
      final lots = await InventoryService().getAvailableLots(productId);
      print('📦 [LOSS] Yüklenen lot sayısı: ${lots.length}');
      
      if (lots.isNotEmpty) {
        print('✅ [LOSS] İlk lot örneği: ${lots.first}');
      } else {
        print('❌ [LOSS] Hiç lot bulunamadı - Ürün ID: $productId');
        print('🔍 [LOSS] Firebase\'de lot kontrolü yapılıyor...');
      }
      
      setState(() {
        availableLots = lots;
        isLoading = false;
      });
    } catch (e) {
      print('❌ [LOSS] Lot yükleme hatası: $e');
      setState(() {
        availableLots = [];
        isLoading = false;
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

  Future<void> _processLoss() async {
    if (_formKey.currentState?.validate() != true) return;
    
    int quantity;
    
    if (useAutoFIFO) {
      // Otomatik FIFO modunda: miktar alanından al
      quantity = int.parse(_quantityController.text);
    } else {
      // Manuel seçim modunda: seçilen lot miktarlarının toplamını al
      quantity = selectedLotQuantities.values.fold(0, (sum, qty) => sum + qty);
      
      if (quantity <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lütfen kayıp/fire miktarlarını giriniz!')),
        );
        return;
      }
    }
    
    setState(() {
      isLoading = true;
    });
    
    try {
      await InventoryService().addLoss(unitPrice: 0.0, 
        productId: widget.product['id'].toString(),
        productName: widget.product['name'],
        quantity: quantity,
        notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
      );
      
      // Başarı mesajı
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green),
              SizedBox(width: 8),
              Text('Kayıp/Fire Kaydedildi'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('✅ Kayıp/Fire başarıyla kaydedildi'),
              SizedBox(height: 8),
              Text('📦 Miktar: $quantity ${widget.product['unit']}'),
              Text('🔍 Sebep: $lossReason'),
              Text('💸 Maliyet: ₺${totalCost.toStringAsFixed(2)}'),
              Text('🔄 Yöntem: ${useAutoFIFO ? "Otomatik FIFO" : "Manuel Seçim"}'),
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
          content: Text('Kayıp/Fire hatası: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        isLoading = false;
      });
    }
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
                      'Kayıp/Fire kaydedebilmek için önce bu ürünü satın almanız gerekiyor.',
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
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
                Text('Kayıp Miktarı: '),
                SizedBox(width: 8),
                Container(
                  width: 80,
                  child: TextFormField(
                    controller: _getLotController(lotId, remainingQty),
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    ),
                    onChanged: (value) {
                      final quantity = int.tryParse(value) ?? 0;
                      setState(() {
                        if (quantity > 0 && quantity <= remainingQty) {
                          selectedLotQuantities[lotId] = quantity;
                        } else {
                          selectedLotQuantities.remove(lotId);
                        }
                        _calculateTotals();
                      });
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('🗑️ Kayıp/Fire'),
        backgroundColor: Colors.red[300],
        foregroundColor: Colors.white,
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
                      leading: Icon(Icons.inventory, color: Colors.red[300], size: 40),
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
                  
                  // Kayıp/Fire formu
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
                              '📝 Kayıp/Fire Bilgileri',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            SizedBox(height: 16),
                            
                            // Miktar alanı sadece otomatik FIFO modunda gösterilir
                            if (useAutoFIFO) ...[
                              TextFormField(
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
                                  if (quantity > widget.product['currentStock']) {
                                    return 'Stokta yeterli ürün yok';
                                  }
                                  return null;
                                },
                              ),
                              SizedBox(height: 16),
                            ],
                            
                            // Manuel seçimde toplam miktar göstergesi
                            if (!useAutoFIFO) ...[
                              Container(
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
                                      'Toplam Seçilen Miktar:',
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
                                  ],
                                ),
                              ),
                              SizedBox(height: 16),
                            ],
                            
                            DropdownButtonFormField<String>(
                              value: lossReason,
                              decoration: InputDecoration(
                                labelText: 'Kayıp Sebebi',
                                border: OutlineInputBorder(),
                              ),
                              items: lossReasons.map((reason) {
                                return DropdownMenuItem(
                                  value: reason,
                                  child: Text(
                                    reason,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                );
                              }).toList(),
                              onChanged: (value) {
                                setState(() {
                                  lossReason = value!;
                                });
                              },
                            ),
                            SizedBox(height: 16),
                            
                            TextFormField(
                              controller: _notesController,
                              decoration: InputDecoration(
                                labelText: 'Detaylı Açıklama (İsteğe Bağlı)',
                                border: OutlineInputBorder(),
                              ),
                              maxLines: 3,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  
                  // Lot seçimi
                  _buildLotSelectionCard(),
                  
                  // Maliyet özeti
                  if (totalCost > 0)
                    Card(
                      margin: EdgeInsets.all(16),
                      color: Colors.red.shade50,
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '💸 Toplam Maliyet:',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              '₺${totalCost.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.red,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  
                  // Kayıp/Fire butonu
                  Container(
                    width: double.infinity,
                    margin: EdgeInsets.all(16),
                    child: ElevatedButton(
                      onPressed: availableLots.isEmpty ? null : _processLoss,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red[300],
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: Text(
                        'Kayıp/Fire Kaydını Tamamla',
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
    _notesController.dispose();
    // Lot controller'ları temizle
    lotControllers.values.forEach((controller) => controller.dispose());
    super.dispose();
  }

  // Lot controller'ını getir veya oluştur
  TextEditingController _getLotController(dynamic lotId, int maxQuantity) {
    if (!lotControllers.containsKey(lotId)) {
      lotControllers[lotId] = TextEditingController(
        text: selectedLotQuantities[lotId]?.toString() ?? '0'
      );
    }
    return lotControllers[lotId]!;
  }
} 