import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/firebase_service.dart';
import '../models/product.dart';
import '../widgets/barcode_scanner_widget.dart';
import '../services/subscription_service.dart';
import '../screens/subscription_screen.dart';
import 'add_product_screen.dart';
import 'purchase_screen.dart';
import 'advanced_sale_screen.dart';
import 'return_screen.dart';
import 'loss_screen.dart';
import 'auth/login_screen.dart';

class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  final SubscriptionService _subscriptionService = SubscriptionService();
  List<Map<String, dynamic>> products = [];
  bool isLoading = true;
  String searchQuery = '';
  String sortBy = 'name';
  bool sortAscending = true;

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    try {
      setState(() {
        isLoading = true;
      });
      
      final loadedProducts = await FirebaseService.getProducts();
      setState(() {
        products = loadedProducts;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ürünler yüklenirken hata: $e')),
      );
    }
  }

  List<Map<String, dynamic>> get filteredAndSortedProducts {
    List<Map<String, dynamic>> filtered = products.where((product) {
      final name = product['name']?.toString() ?? '';
      final sku = product['sku']?.toString() ?? '';
      final barcode = product['barcode']?.toString() ?? '';
      
      final matchesSearch = name.toLowerCase().contains(searchQuery.toLowerCase()) ||
          sku.toLowerCase().contains(searchQuery.toLowerCase()) ||
          barcode.toLowerCase().contains(searchQuery.toLowerCase());
      
      return matchesSearch;
    }).toList();
    
    // Sorting
    filtered.sort((a, b) {
      int comparison = 0;
      switch (sortBy) {
        case 'name':
          comparison = (a['name']?.toString() ?? '').compareTo(b['name']?.toString() ?? '');
          break;
        case 'sku':
          comparison = (a['sku']?.toString() ?? '').compareTo(b['sku']?.toString() ?? '');
          break;
        case 'stock':
          comparison = (a['current_stock'] ?? 0).compareTo(b['current_stock'] ?? 0);
          break;
        case 'minStock':
          comparison = (a['min_stock_level'] ?? 0).compareTo(b['min_stock_level'] ?? 0);
          break;
      }
      return sortAscending ? comparison : -comparison;
    });
    
    return filtered;
  }

  Set<String> get availableCategories {
    Set<String> categorySet = {'Tümü'};
    // Kategori kaldırıldığı için sadece 'Tümü' döndürüyoruz
    return categorySet;
  }

  Future<void> _navigateToAddProduct([Map<String, dynamic>? product]) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddProductScreen(product: product),
      ),
    );
    
    if (result == true) {
      _loadProducts();
    }
  }

  Future<void> _navigateToPurchase(Map<String, dynamic> product) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PurchaseScreen(product: product),
      ),
    );
    
    if (result == true) {
      _loadProducts();
    }
  }

  Future<void> _navigateToAdvancedSale(Map<String, dynamic> product) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AdvancedSaleScreen(product: product),
      ),
    );
    
    if (result == true) {
      _loadProducts();
    }
  }

  Future<void> _navigateToReturn(Map<String, dynamic> product) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ReturnScreen(product: product),
      ),
    );
    
    if (result == true) {
      _loadProducts();
    }
  }

  Future<void> _navigateToLoss(Map<String, dynamic> product) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LossScreen(product: product),
      ),
    );
    
    if (result == true) {
      _loadProducts();
    }
  }

  Future<void> _searchByBarcode() async {
    // Premium kontrolü
    final isUserPremium = await _subscriptionService.isUserPremium();
    if (!isUserPremium) {
      _showPremiumRequired();
      return;
    }

    try {
      final barcode = await Navigator.push<String>(
        context,
        MaterialPageRoute(
      builder: (context) => BarcodeScannerWidget(
            title: 'Barkod ile Ürün Ara',
            subtitle: 'Aranacak ürünün barkodunu tarayın',
        onBarcodeDetected: (String detectedBarcode) {
              // Sadece callback çalıştır, pop işlemi widget içinde zaten yapılıyor
        },
          ),
      ),
    );

    if (barcode != null && barcode.isNotEmpty) {
      setState(() {
        searchQuery = barcode;
      });
        
        // Kullanıcıya arama sonucu hakkında bilgi ver
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Barkod ile arama: $barcode'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Barkod okuma hatası: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showPremiumRequired() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Premium Özellik'),
        content: Text('Barkod okuma özelliği premium kullanıcılar için geçerlidir.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => SubscriptionScreen()),
              );
            },
            child: Text('Premium Ol'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteProduct(Map<String, dynamic> product) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Ürün Sil'),
        content: Text('${product['name']} ürününü silmek istediğinizden emin misiniz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('Sil'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final result = await FirebaseService.deleteProduct(product['id']);
        if (result['success']) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Ürün başarıyla silindi')),
          );
          _loadProducts();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Ürün silinirken hata: ${result['message']}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ürün silinirken hata: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Çıkış Yap'),
        content: Text('Çıkış yapmak istediğinizden emin misiniz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Çıkış Yap'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await FirebaseService.logout();
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => LoginScreen()),
        (route) => false,
      );
    }
  }

  Color _getStockColor(Map<String, dynamic> product) {
    final currentStock = product['current_stock'] ?? 0;
    final minStock = product['min_stock_level'] ?? 0;
    
    if (currentStock <= 0) {
      return Colors.red;
    } else if (currentStock <= minStock) {
      return Colors.orange;
    } else {
      return Colors.green;
    }
  }

  IconData _getStockIcon(Map<String, dynamic> product) {
    final currentStock = product['current_stock'] ?? 0;
    final minStock = product['min_stock_level'] ?? 0;
    
    if (currentStock <= 0) {
      return Icons.error;
    } else if (currentStock <= minStock) {
      return Icons.warning;
    } else {
      return Icons.check_circle;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Ürünler (${filteredAndSortedProducts.length})'),
        actions: [
          IconButton(
            icon: Icon(Icons.qr_code_scanner),
            onPressed: _searchByBarcode,
            tooltip: 'Barkod ile Ara',
          ),
          PopupMenuButton<String>(
            icon: Icon(Icons.sort),
            onSelected: (value) {
              setState(() {
                if (sortBy == value) {
                  sortAscending = !sortAscending;
                } else {
                  sortBy = value;
                  sortAscending = true;
                }
              });
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'name',
                child: Row(
                  children: [
                    Icon(Icons.sort_by_alpha),
                    SizedBox(width: 8),
                    Text('İsme Göre'),
                    if (sortBy == 'name') ...[
                      Spacer(),
                      Icon(sortAscending ? Icons.arrow_upward : Icons.arrow_downward),
                    ],
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'sku',
                child: Row(
                  children: [
                    Icon(Icons.tag),
                    SizedBox(width: 8),
                    Text('SKU\'ya Göre'),
                    if (sortBy == 'sku') ...[
                      Spacer(),
                      Icon(sortAscending ? Icons.arrow_upward : Icons.arrow_downward),
                    ],
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'stock',
                child: Row(
                  children: [
                    Icon(Icons.inventory),
                    SizedBox(width: 8),
                    Text('Stok Miktarına Göre'),
                    if (sortBy == 'stock') ...[
                      Spacer(),
                      Icon(sortAscending ? Icons.arrow_upward : Icons.arrow_downward),
                    ],
                  ],
                ),
              ),
            ],
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'logout') {
                _logout();
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Çıkış Yap', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Arama çubuğu
          Padding(
            padding: EdgeInsets.all(16),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Ürün ara (isim, SKU, barkod)...',
                prefixIcon: Icon(Icons.search),
                suffixIcon: searchQuery.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear),
                        onPressed: () {
                          setState(() {
                            searchQuery = '';
                          });
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onChanged: (value) {
                setState(() {
                  searchQuery = value;
                });
              },
            ),
          ),
          
          // Ürün listesi
          Expanded(
            child: isLoading
                ? Center(child: CircularProgressIndicator())
                : filteredAndSortedProducts.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.inventory_2_outlined,
                              size: 64,
                              color: Colors.grey,
                            ),
                            SizedBox(height: 16),
                            Text(
                              searchQuery.isEmpty
                                  ? 'Henüz ürün eklenmemiş'
                                  : 'Arama kriterine uygun ürün bulunamadı',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.grey[600],
                              ),
                            ),
                            SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: () => _navigateToAddProduct(),
                              icon: Icon(Icons.add),
                              label: Text('İlk Ürünü Ekle'),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadProducts,
                        child: ListView.builder(
                          itemCount: filteredAndSortedProducts.length,
                          itemBuilder: (context, index) {
                            final product = filteredAndSortedProducts[index];
                            return _buildProductCard(product);
                          },
                        ),
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _navigateToAddProduct(),
        child: Icon(Icons.add),
      ),
    );
  }

  Widget _buildProductCard(Map<String, dynamic> product) {
    final currentStock = product['current_stock'] ?? 0;
    final minStock = product['min_stock_level'] ?? 0;
    final stockColor = _getStockColor(product);
    final stockIcon = _getStockIcon(product);
    
    return Card(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: stockColor.withOpacity(0.2),
          child: Icon(stockIcon, color: stockColor),
        ),
        title: Text(
          product['name'] ?? '',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('SKU: ${product['sku'] ?? ''}'),
            if (product['barcode'] != null && product['barcode'].toString().isNotEmpty)
              Text('Barkod: ${product['barcode']}'),
            Row(
              children: [
                Icon(Icons.inventory, size: 16, color: stockColor),
                SizedBox(width: 4),
                Text(
                  'Stok: $currentStock ${product['unit'] ?? ''}',
                  style: TextStyle(
                    color: stockColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (currentStock <= minStock) ...[
                  SizedBox(width: 8),
                  Icon(Icons.warning, size: 16, color: Colors.orange),
                  Text(
                    ' (Min: $minStock)',
                    style: TextStyle(color: Colors.orange),
                  ),
                ],
              ],
            ),
          ],
        ),
        children: [
          Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (product['description'] != null && product['description'].toString().isNotEmpty) ...[
                  Text(
                    'Açıklama:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(product['description']),
                  SizedBox(height: 16),
                ],
                
                // İşlem butonları
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildActionButton(
                      icon: Icons.add_shopping_cart,
                      label: 'Satın Al',
                      color: Colors.green,
                      onPressed: () => _navigateToPurchase(product),
                    ),
                    _buildActionButton(
                      icon: Icons.sell,
                      label: 'Sat',
                      color: Colors.blue,
                      onPressed: () => _navigateToAdvancedSale(product),
                    ),
                    _buildActionButton(
                      icon: Icons.edit,
                      label: 'Düzenle',
                      color: Colors.orange,
                      onPressed: () => _navigateToAddProduct(product),
                    ),
                    _buildActionButton(
                      icon: Icons.more_horiz,
                      label: 'Diğer',
                      color: Colors.purple,
                      onPressed: () => _showOtherOptionsMenu(product),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          onPressed: onPressed,
          icon: Icon(icon),
          style: IconButton.styleFrom(
            backgroundColor: color.withOpacity(0.1),
            foregroundColor: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: color,
          ),
        ),
      ],
    );
  }

  void _showOtherOptionsMenu(Map<String, dynamic> product) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            
            Text(
              'Diğer İşlemler',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              product['name'] ?? '',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 24),
            
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.keyboard_return, color: Colors.orange),
              ),
              title: const Text('İade İşlemi'),
              subtitle: const Text('Satış veya alış iadesi kaydet'),
              onTap: () {
                Navigator.pop(context);
                _navigateToReturn(product);
              },
            ),
            
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.report_problem, color: Colors.red),
              ),
              title: const Text('Kayıp/Fire'),
              subtitle: const Text('Ürün kaybını veya fire işlemini kaydet'),
              onTap: () {
                Navigator.pop(context);
                _navigateToLoss(product);
              },
            ),
            
            Divider(),
            
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.delete_forever, color: Colors.red),
              ),
              title: const Text('Ürünü Sil'),
              subtitle: const Text('Ürünü kalıcı olarak sil'),
              onTap: () {
                Navigator.pop(context);
                _deleteProduct(product);
              },
            ),
            
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
} 