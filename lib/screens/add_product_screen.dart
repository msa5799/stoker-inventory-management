import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/product.dart';
import '../services/firebase_service.dart';
import '../widgets/barcode_scanner_widget.dart';
import '../services/subscription_service.dart';
import '../screens/subscription_screen.dart';

class AddProductScreen extends StatefulWidget {
  final Map<String, dynamic>? product; // null for new product, existing for edit

  const AddProductScreen({super.key, this.product});

  @override
  State<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends State<AddProductScreen> {
  final _formKey = GlobalKey<FormState>();
  final SubscriptionService _subscriptionService = SubscriptionService();
  
  late TextEditingController _nameController;
  late TextEditingController _skuController;
  late TextEditingController _barcodeController;
  late TextEditingController _minStockController;
  late TextEditingController _descriptionController;
  late TextEditingController _purchasePriceController;
  late TextEditingController _salePriceController;
  
  String _selectedUnit = 'Adet';
  bool _isLoading = false;
  bool _isSkuManuallyEdited = false; // SKU'nun manuel olarak değiştirilip değiştirilmediğini takip eder

  final List<String> _units = ['Adet', 'Kg', 'Litre', 'Metre', 'Paket'];

  @override
  void initState() {
    super.initState();
    
    _nameController = TextEditingController(text: widget.product?['name']?.toString() ?? '');
    _skuController = TextEditingController(text: widget.product?['sku']?.toString() ?? '');
    _barcodeController = TextEditingController(text: widget.product?['barcode']?.toString() ?? '');
    _minStockController = TextEditingController(text: widget.product?['min_stock_level']?.toString() ?? '5');
    _descriptionController = TextEditingController(text: widget.product?['description']?.toString() ?? '');
    _purchasePriceController = TextEditingController(text: widget.product?['purchase_price']?.toString() ?? '');
    _salePriceController = TextEditingController(text: widget.product?['sale_price']?.toString() ?? '');
    
    if (widget.product != null) {
      _selectedUnit = widget.product!['unit']?.toString() ?? 'Adet';
      _isSkuManuallyEdited = true; // Mevcut ürün düzenleniyorsa SKU'yu otomatik değiştirme
    }

    // Ürün adı değiştiğinde SKU'yu otomatik oluştur
    _nameController.addListener(_onNameChanged);
  }

  @override
  void dispose() {
    _nameController.removeListener(_onNameChanged);
    _nameController.dispose();
    _skuController.dispose();
    _barcodeController.dispose();
    _minStockController.dispose();
    _descriptionController.dispose();
    _purchasePriceController.dispose();
    _salePriceController.dispose();
    super.dispose();
  }

  void _onNameChanged() {
    // Eğer SKU manuel olarak değiştirilmemişse otomatik oluştur
    if (!_isSkuManuallyEdited && _nameController.text.isNotEmpty) {
      final autoSku = _generateSku(_nameController.text);
      _skuController.text = autoSku;
    }
  }

  String _generateSku(String productName) {
    if (productName.isEmpty) return '';
    
    // Türkçe karakterleri İngilizce karşılıklarına çevir
    String sku = productName
        .toUpperCase()
        .replaceAll('Ç', 'C')
        .replaceAll('Ğ', 'G')
        .replaceAll('İ', 'I')
        .replaceAll('Ö', 'O')
        .replaceAll('Ş', 'S')
        .replaceAll('Ü', 'U')
        .replaceAll('ı', 'i');
    
    // Sadece harf ve rakamları al, boşlukları tire ile değiştir
    sku = sku.replaceAll(RegExp(r'[^A-Z0-9\s]'), '');
    sku = sku.replaceAll(RegExp(r'\s+'), '-');
    
    // İlk 3 kelimeyi al veya maksimum 15 karakter
    List<String> words = sku.split('-');
    if (words.length > 3) {
      sku = words.take(3).join('-');
    }
    
    if (sku.length > 15) {
      sku = sku.substring(0, 15);
    }
    
    // Sonuna rastgele 3 haneli sayı ekle
    final random = DateTime.now().millisecondsSinceEpoch % 1000;
    sku = '$sku-${random.toString().padLeft(3, '0')}';
    
    return sku;
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
          title: 'Barkod Tarayıcı',
          subtitle: 'Ürün barkodunu tarayın',
          onBarcodeDetected: (barcode) {
            print('Barkod algılandı: $barcode');
          },
          ),
        ),
      );

      if (result != null && result.isNotEmpty) {
        // Barkodun zaten kullanılıp kullanılmadığını kontrol et
        final existingProduct = await FirebaseService.getProductByBarcode(result);
        
        if (existingProduct != null && existingProduct['id'] != widget.product?['id']) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: Text('Barkod Zaten Mevcut'),
              content: Text('Bu barkod zaten "${existingProduct['name']}" ürünü tarafından kullanılıyor!'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Tamam'),
                ),
              ],
            ),
          );
          return;
        }

        setState(() {
          _barcodeController.text = result;
        });
      }
    } catch (e) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Hata'),
          content: Text('Barkod tarama hatası: $e'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Tamam'),
            ),
          ],
        ),
      );
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
            Icon(Icons.qr_code_scanner, size: 64, color: Colors.orange),
            SizedBox(height: 16),
            Text(
              'Barkod tarayıcı özelliği sadece premium kullanıcılar için mevcuttur.',
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
                    '🔍 Barkod Tarayıcı Özellikleri:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.amber.shade700,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text('• Hızlı barkod tarama'),
                  Text('• Otomatik ürün tanıma'),
                  Text('• Çoklu format desteği'),
                  Text('• Verimli stok girişi'),
                ],
              ),
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

  Future<void> _saveProduct() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Barkod eşsizlik kontrolü (barkod girildiyse)
      if (_barcodeController.text.trim().isNotEmpty) {
        final existingProduct = await FirebaseService.getProductByBarcode(_barcodeController.text.trim());
        
        // Eğer barkod başka bir ürün tarafından kullanılıyorsa hata ver
        if (existingProduct != null && existingProduct['id'] != widget.product?['id']) {
          setState(() {
            _isLoading = false;
          });
          
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: Row(
                children: [
                  Icon(Icons.warning, color: Colors.orange),
                  SizedBox(width: 8),
                  Text('Barkod Zaten Mevcut'),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Bu barkod zaten aşağıdaki ürün tarafından kullanılıyor:'),
                  SizedBox(height: 12),
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange.shade300),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '📦 ${existingProduct['name']}',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text('SKU: ${existingProduct['sku']}'),
                        Text('Barkod: ${existingProduct['barcode']}'),
                      ],
                    ),
                  ),
                  SizedBox(height: 12),
                  Text(
                    'Lütfen farklı bir barkod girin veya barkod alanını boş bırakın.',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Tamam'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    setState(() {
                      _barcodeController.clear();
                    });
                  },
                  child: Text('Barkodu Temizle'),
                ),
              ],
            ),
          );
          return;
        }
      }

      // SKU eşsizlik kontrolü - Firebase servisi zaten kontrol ediyor ama ekstra güvenlik için
      // Yeni ürün ekleme veya SKU değiştirilmişse kontrol et
      if (widget.product == null || _skuController.text.trim() != widget.product?['sku']) {
        print('🔍 SKU eşsizlik kontrolü yapılıyor: ${_skuController.text.trim()}');
        // Not: Firebase Service addProduct içinde zaten SKU kontrolü yapıyor
        // Burada ek kontrol yapmamıza gerek yok, Firebase servis bu işi hallediyor
      }

      // Fiyat değerlerini parse et
      double purchasePrice = 0.0;
      double salePrice = 0.0;
      
      if (_purchasePriceController.text.isNotEmpty) {
        purchasePrice = double.parse(_purchasePriceController.text);
      }
      
      if (_salePriceController.text.isNotEmpty) {
        salePrice = double.parse(_salePriceController.text);
      }

      final productData = {
        'name': _nameController.text.trim(),
        'sku': _skuController.text.trim(),
        'barcode': _barcodeController.text.trim().isEmpty ? null : _barcodeController.text.trim(),
        'current_stock': widget.product?['current_stock'] ?? 0, // Mevcut stok korunur
        'min_stock_level': int.parse(_minStockController.text),
        'unit': _selectedUnit,
        'description': _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
        'purchase_price': purchasePrice,
        'sale_price': salePrice,
      };

      Map<String, dynamic> result;
      
      if (widget.product == null) {
        // Yeni ürün ekleme
        result = await FirebaseService.addProduct(productData);
      } else {
        // Mevcut ürün güncelleme
        result = await FirebaseService.updateProduct(widget.product!['id'], productData);
      }

      if (result['success']) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.product == null ? 'Ürün başarıyla eklendi' : 'Ürün başarıyla güncellendi'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Bir hata oluştu'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Hata: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.product == null ? 'Ürün Ekle' : 'Ürün Düzenle'),
        actions: [
          if (_isLoading)
            Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
              ),
            )
          else
            TextButton(
              onPressed: _saveProduct,
              child: Text(
                'KAYDET',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Ürün Adı
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Ürün Adı *',
                  hintText: 'Örn: Samsung Galaxy S21',
                  prefixIcon: Icon(Icons.inventory),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Ürün adı gerekli';
                  }
                  if (value.trim().length < 2) {
                    return 'Ürün adı en az 2 karakter olmalı';
                  }
                  return null;
                },
                textCapitalization: TextCapitalization.words,
              ),
              
              SizedBox(height: 16),
              
              // SKU
              TextFormField(
                controller: _skuController,
                decoration: InputDecoration(
                  labelText: 'SKU (Stok Kodu) *',
                  hintText: 'Otomatik oluşturulur',
                  prefixIcon: Icon(Icons.tag),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  helperText: 'Ürün adından otomatik oluşturulur, değiştirebilirsiniz',
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'SKU gerekli';
                  }
                  if (value.trim().length < 3) {
                    return 'SKU en az 3 karakter olmalı';
                  }
                  return null;
                },
                onChanged: (value) {
                  _isSkuManuallyEdited = true;
                },
                textCapitalization: TextCapitalization.characters,
              ),
              
              SizedBox(height: 16),
              
              // Barkod
              TextFormField(
                controller: _barcodeController,
                decoration: InputDecoration(
                  labelText: 'Barkod',
                  hintText: 'Opsiyonel - Tarayıcı ile ekleyebilirsiniz',
                  prefixIcon: Icon(Icons.qr_code),
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(Icons.qr_code_scanner),
                        onPressed: _scanBarcode,
                        tooltip: 'Barkod Tara (Premium)',
                      ),
                      if (_barcodeController.text.isNotEmpty)
                        IconButton(
                          icon: Icon(Icons.clear),
                          onPressed: () {
                            setState(() {
                              _barcodeController.clear();
                            });
                          },
                        ),
                    ],
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  // Barkod opsiyonel olduğu için boş olabilir
                  if (value == null || value.trim().isEmpty) {
                    return null;
                  }
                  
                  // Barkod formatı kontrolü (basit)
                  if (value.trim().length < 8) {
                    return 'Barkod en az 8 haneli olmalı';
                  }
                  
                  return null;
                },
                onChanged: (value) {
                  setState(() {}); // Clear butonu için rebuild
                },
              ),
              
              SizedBox(height: 16),
              
              // Birim ve Min Stok
              Row(
                children: [
                  Expanded(
                    flex: 1,
                    child: DropdownButtonFormField<String>(
                      value: _selectedUnit,
                      decoration: InputDecoration(
                        labelText: 'Birim *',
                        prefixIcon: Icon(Icons.straighten),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                      ),
                      items: _units.map((unit) {
                        return DropdownMenuItem(
                          value: unit,
                          child: Text(unit),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedUnit = value!;
                        });
                      },
                    ),
                  ),
                  
                  SizedBox(width: 12),
                  
                  Expanded(
                    flex: 1,
                    child: TextFormField(
                      controller: _minStockController,
                      decoration: InputDecoration(
                        labelText: 'Min. Stok *',
                        hintText: '5',
                        prefixIcon: Icon(Icons.warning),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Min. stok gerekli';
                        }
                        final intValue = int.tryParse(value);
                        if (intValue == null || intValue < 0) {
                          return 'Geçerli sayı girin';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              
              SizedBox(height: 16),
              
              // Açıklama
              TextFormField(
                controller: _descriptionController,
                decoration: InputDecoration(
                  labelText: 'Açıklama',
                  hintText: 'Ürün hakkında ek bilgiler...',
                  prefixIcon: Icon(Icons.description),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                maxLines: 3,
                textCapitalization: TextCapitalization.sentences,
              ),
              
              SizedBox(height: 16),
              
              // Alış Fiyatı
              TextFormField(
                controller: _purchasePriceController,
                decoration: InputDecoration(
                  labelText: 'Alış Fiyatı *',
                  hintText: 'Örn: 100.00',
                  prefixIcon: Icon(Icons.attach_money),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Alış fiyatı gerekli';
                  }
                  final doubleValue = double.tryParse(value);
                  if (doubleValue == null || doubleValue < 0) {
                    return 'Geçerli sayı girin';
                  }
                  return null;
                },
              ),
              
              SizedBox(height: 16),
              
              // Satış Fiyatı
              TextFormField(
                controller: _salePriceController,
                decoration: InputDecoration(
                  labelText: 'Satış Fiyatı *',
                  hintText: 'Örn: 150.00',
                  prefixIcon: Icon(Icons.attach_money),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Satış fiyatı gerekli';
                  }
                  final doubleValue = double.tryParse(value);
                  if (doubleValue == null || doubleValue < 0) {
                    return 'Geçerli sayı girin';
                  }
                  return null;
                },
              ),
              
              SizedBox(height: 24),
              
              // Mevcut stok bilgisi (sadece düzenleme modunda)
              if (widget.product != null) ...[
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.info, color: Colors.blue),
                          SizedBox(width: 8),
                          Text(
                            'Mevcut Stok Bilgisi',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.blue.shade700,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      Text('Mevcut Stok: ${widget.product!['current_stock'] ?? 0} ${widget.product!['unit'] ?? ''}'),
                      SizedBox(height: 4),
                      Text(
                        'Stok miktarını değiştirmek için Satın Al veya Satış Yap işlemlerini kullanın.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.blue.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 24),
              ],
              
              // Kaydet Butonu
              ElevatedButton(
                onPressed: _isLoading ? null : _saveProduct,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: _isLoading
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          ),
                          SizedBox(width: 12),
                          Text('Kaydediliyor...'),
                        ],
                      )
                    : Text(
                        widget.product == null ? 'ÜRÜN EKLE' : 'DEĞİŞİKLİKLERİ KAYDET',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
} 