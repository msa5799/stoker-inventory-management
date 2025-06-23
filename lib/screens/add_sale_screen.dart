import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/product.dart';
import '../services/inventory_service.dart';
import '../screens/advanced_sale_screen.dart';

class AddSaleScreen extends StatefulWidget {
  const AddSaleScreen({super.key});

  @override
  State<AddSaleScreen> createState() => _AddSaleScreenState();
}

class _AddSaleScreenState extends State<AddSaleScreen> {
  final _formKey = GlobalKey<FormState>();
  final InventoryService _inventoryService = InventoryService();
  
  late TextEditingController _customerNameController;
  late TextEditingController _notesController;
  
  List<Product> availableProducts = <Product>[];
  List<SaleItemData> saleItems = [];
  bool isLoading = false;
  bool isLoadingProducts = true;

  @override
  void initState() {
    super.initState();
    
    _customerNameController = TextEditingController();
    _notesController = TextEditingController();
    
    _loadProducts();
  }

  @override
  void dispose() {
    _customerNameController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadProducts() async {
    try {
      setState(() {
        availableProducts = <Product>[].where((p) => p.currentStock > 0).toList();
        isLoadingProducts = false;
      });
    } catch (e) {
      setState(() {
        isLoadingProducts = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ürünler yüklenirken hata: $e')),
      );
    }
  }

  void _addProduct() {
    if (availableProducts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Stokta ürün bulunamadı!')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AddProductDialog(
        availableProducts: availableProducts,
        alreadySelectedProducts: saleItems.map((item) => item.product.id!).toList(),
        onProductSelected: (product, quantity) {
          setState(() {
            saleItems.add(SaleItemData(
              product: product,
              quantity: quantity,
              unitPrice: product.sellPrice, // Varsayılan satış fiyatı
            ));
          });
        },
      ),
    );
  }

  void _removeProduct(int index) {
    setState(() {
      saleItems.removeAt(index);
    });
  }

  void _updateQuantity(int index, int newQuantity) {
    if (newQuantity <= 0) {
      _removeProduct(index);
      return;
    }
    
    final product = saleItems[index].product;
    if (newQuantity > product.currentStock) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Stokta sadece ${product.currentStock} adet var!')),
      );
      return;
    }

    setState(() {
      saleItems[index].quantity = newQuantity;
    });
  }

  void _updateUnitPrice(int index, double newPrice) {
    setState(() {
      saleItems[index].unitPrice = newPrice;
    });
  }

  double get totalAmount {
    return saleItems.fold(0, (sum, item) => sum + item.totalPrice);
  }

  Future<void> _saveSale() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (saleItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('En az bir ürün ekleyin!')),
      );
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      // Her ürün için ayrı satış işlemi yap
      for (final item in saleItems) {
        await _inventoryService.addSale(
          productId: item.product.id.toString(),
          productName: item.product.name,
          quantity: item.quantity,
          unitPrice: item.unitPrice,
          customerName: _customerNameController.text.trim().isEmpty 
              ? null 
              : _customerNameController.text.trim(),
          notes: _notesController.text.trim().isEmpty 
              ? null 
              : _notesController.text.trim(),
        );
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Satış başarıyla kaydedildi!')),
      );

      Navigator.pop(context, true);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Satış kaydedilirken hata: $e')),
      );
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoadingProducts) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Yeni Satış'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          if (isLoading)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            TextButton(
              onPressed: _saveSale,
              child: const Text(
                'Kaydet',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Müşteri Bilgileri
                    _buildSectionTitle('Müşteri Bilgileri'),
                    const SizedBox(height: 16),
                    
                    TextFormField(
                      controller: _customerNameController,
                      decoration: const InputDecoration(
                        labelText: 'Müşteri Adı *',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.person),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Müşteri adı gerekli';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),
                    
                    // Ürünler
                    Row(
                      children: [
                        Expanded(child: _buildSectionTitle('Ürünler')),
                        ElevatedButton.icon(
                          onPressed: _addProduct,
                          icon: const Icon(Icons.add),
                          label: const Text('Ürün Ekle'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    if (saleItems.isEmpty)
                      const Card(
                        child: Padding(
                          padding: EdgeInsets.all(32),
                          child: Center(
                            child: Column(
                              children: [
                                Icon(Icons.shopping_cart, size: 48, color: Colors.grey),
                                SizedBox(height: 8),
                                Text('Henüz ürün eklenmedi'),
                              ],
                            ),
                          ),
                        ),
                      )
                    else
                      ...saleItems.asMap().entries.map((entry) {
                        final index = entry.key;
                        final item = entry.value;
                        return SaleItemWidget(
                          key: ValueKey(item.product.id),
                          item: item,
                          onQuantityChanged: (newQuantity) => _updateQuantity(index, newQuantity),
                          onPriceChanged: (newPrice) => _updateUnitPrice(index, newPrice),
                          onRemove: () => _removeProduct(index),
                        );
                      }).toList(),
                    
                    const SizedBox(height: 24),
                    
                    // Notlar
                    _buildSectionTitle('Notlar'),
                    const SizedBox(height: 16),
                    
                    TextFormField(
                      controller: _notesController,
                      decoration: const InputDecoration(
                        labelText: 'Satış Notları',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.note),
                        hintText: 'İsteğe bağlı notlar...',
                      ),
                      maxLines: 2,
                    ),
                  ],
                ),
              ),
            ),
            
            // Toplam ve Kaydet
            if (saleItems.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  border: Border(top: BorderSide(color: Colors.grey[300]!)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Toplam: ₺${NumberFormat('#,##0.00').format(totalAmount)}',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '${saleItems.length} ürün, ${saleItems.fold(0, (sum, item) => sum + item.quantity)} adet',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                        ],
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

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: Colors.blue,
      ),
    );
  }
}

class SaleItemData {
  final Product product;
  int quantity;
  double unitPrice;

  SaleItemData({
    required this.product,
    required this.quantity,
    required this.unitPrice,
  });

  double get totalPrice => quantity * unitPrice;
}

class SaleItemWidget extends StatelessWidget {
  final SaleItemData item;
  final Function(int) onQuantityChanged;
  final Function(double) onPriceChanged;
  final VoidCallback onRemove;

  const SaleItemWidget({
    super.key,
    required this.item,
    required this.onQuantityChanged,
    required this.onPriceChanged,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    item.product.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: onRemove,
                ),
              ],
            ),
            Text(
              'Stok: ${item.product.currentStock} ${item.product.unit}',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                // Quantity
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Miktar', style: TextStyle(fontSize: 12)),
                      Row(
                        children: [
                          IconButton(
                            onPressed: () => onQuantityChanged(item.quantity - 1),
                            icon: const Icon(Icons.remove),
                            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                          ),
                          SizedBox(
                            width: 50,
                            child: Text(
                              item.quantity.toString(),
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          IconButton(
                            onPressed: () => onQuantityChanged(item.quantity + 1),
                            icon: const Icon(Icons.add),
                            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                
                // Unit Price
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Birim Fiyat', style: TextStyle(fontSize: 12)),
                      TextFormField(
                        initialValue: item.unitPrice.toString(),
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))],
                        decoration: const InputDecoration(
                          prefixText: '₺ ',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        onChanged: (value) {
                          final price = double.tryParse(value);
                          if (price != null && price > 0) {
                            onPriceChanged(price);
                          }
                        },
                      ),
                    ],
                  ),
                ),
                
                // Total
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text('Toplam', style: TextStyle(fontSize: 12)),
                      const SizedBox(height: 8),
                      Text(
                        '₺${NumberFormat('#,##0.00').format(item.totalPrice)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class AddProductDialog extends StatefulWidget {
  final List<Product> availableProducts;
  final List<int> alreadySelectedProducts;
  final Function(Product, int) onProductSelected;

  const AddProductDialog({
    super.key,
    required this.availableProducts,
    required this.alreadySelectedProducts,
    required this.onProductSelected,
  });

  @override
  State<AddProductDialog> createState() => _AddProductDialogState();
}

class _AddProductDialogState extends State<AddProductDialog> {
  Product? selectedProduct;
  int quantity = 1;

  List<Product> get filteredProducts {
    return widget.availableProducts
        .where((product) => !widget.alreadySelectedProducts.contains(product.id))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Ürün Ekle'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<Product>(
              value: selectedProduct,
              decoration: const InputDecoration(
                labelText: 'Ürün Seçin',
                border: OutlineInputBorder(),
              ),
              items: filteredProducts.map((product) {
                return DropdownMenuItem(
                  value: product,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        product.name,
                        style: const TextStyle(fontSize: 14),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'Stok: ${product.currentStock} • ₺${NumberFormat('#,##0').format(product.sellPrice)}',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (product) {
                setState(() {
                  selectedProduct = product;
                  quantity = 1;
                });
              },
            ),
            if (selectedProduct != null) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  const Text('Miktar: '),
                  IconButton(
                    onPressed: quantity > 1 ? () => setState(() => quantity--) : null,
                    icon: const Icon(Icons.remove),
                  ),
                  Text(quantity.toString(), style: const TextStyle(fontWeight: FontWeight.bold)),
                  IconButton(
                    onPressed: quantity < selectedProduct!.currentStock 
                        ? () => setState(() => quantity++) 
                        : null,
                    icon: const Icon(Icons.add),
                  ),
                  const Spacer(),
                  Flexible(
                    child: Text(
                      'Max: ${selectedProduct!.currentStock}',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('İptal'),
        ),
        ElevatedButton(
          onPressed: selectedProduct != null
              ? () {
                  widget.onProductSelected(selectedProduct!, quantity);
                  Navigator.pop(context);
                }
              : null,
          child: const Text('Ekle'),
        ),
      ],
    );
  }
} 