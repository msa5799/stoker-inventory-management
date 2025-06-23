import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/inventory_service.dart';
import '../services/auth_service.dart';
import '../models/inventory_transaction.dart';
import 'auth/login_screen.dart';
import 'add_sale_screen.dart';
import 'advanced_bulk_sale_screen.dart';

class SalesScreen extends StatefulWidget {
  const SalesScreen({super.key});

  @override
  State<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends State<SalesScreen> {
  final InventoryService _inventoryService = InventoryService();
  final AuthService _authService = AuthService();
  List<InventoryTransaction> sales = [];
  bool isLoading = true;
  String searchQuery = '';
  String sortBy = 'date';
  bool sortAscending = false;

  @override
  void initState() {
    super.initState();
    _loadSales();
  }

  Future<void> _loadSales() async {
    setState(() {
      isLoading = true;
    });

    try {
      final loadedSales = await _inventoryService.getSales();
      setState(() {
        sales = loadedSales;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Satışlar yüklenirken hata: $e')),
      );
    }
  }

  List<InventoryTransaction> get filteredAndSortedSales {
    List<InventoryTransaction> filtered = sales.where((sale) {
      final matchesSearch = sale.productName.toLowerCase().contains(searchQuery.toLowerCase()) ||
          (sale.customerName != null && sale.customerName!.toLowerCase().contains(searchQuery.toLowerCase()));
      return matchesSearch;
    }).toList();
    
    // Sorting
    filtered.sort((a, b) {
      int comparison = 0;
      switch (sortBy) {
        case 'date':
          comparison = a.transactionDate.compareTo(b.transactionDate);
          break;
        case 'product':
          comparison = a.productName.compareTo(b.productName);
          break;
        case 'customer':
          final aCustomer = a.customerName ?? '';
          final bCustomer = b.customerName ?? '';
          comparison = aCustomer.compareTo(bCustomer);
          break;
        case 'amount':
          comparison = a.totalAmount.compareTo(b.totalAmount);
          break;
      }
      return sortAscending ? comparison : -comparison;
    });
    
    return filtered;
  }

  void _showUserMenu() {
    final user = _authService.currentUser;
    
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            
            // User info
            if (user != null) ...[
              CircleAvatar(
                radius: 30,
                backgroundColor: Colors.blue,
                child: Text(
                  user.firstName[0].toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '${user.firstName} ${user.lastName}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                user.email,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 24),
            ],
            
            // Menu items
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('Çıkış Yap'),
              onTap: () async {
                Navigator.pop(context);
                await _authService.logout();
                if (mounted) {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (context) => const LoginScreen()),
                    (route) => false,
                  );
                }
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Future<void> _navigateToAddSale() async {
    // Kullanıcıya seçim sunalım: Basit satış mı, Gelişmiş toplu satış mı?
    final choice = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            
            Text(
              '🛒 Satış Türü Seçin',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Hangi satış türünü tercih edersiniz?',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            
            // Basit Satış
            Card(
              elevation: 2,
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.blue,
                  child: const Icon(Icons.shopping_cart, color: Colors.white),
                ),
                title: const Text(
                  'Tekli Satış',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: const Text('Tek ürün için hızlı satış'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () => Navigator.pop(context, 'simple'),
              ),
            ),
            
            const SizedBox(height: 12),
            
            // Gelişmiş Toplu Satış
            Card(
              elevation: 2,
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.green,
                  child: const Icon(Icons.shopping_cart_checkout, color: Colors.white),
                ),
                title: const Text(
                  'Gelişmiş Toplu Satış',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: const Text('Çoklu ürün, iskonto, detaylı ayarlar'),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.orange,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'YENİ',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                onTap: () => Navigator.pop(context, 'advanced'),
              ),
            ),
            
            const SizedBox(height: 24),
          ],
        ),
      ),
    );

    if (choice == null) return;

    bool result = false;
    
    if (choice == 'simple') {
      result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const AddSaleScreen(),
        ),
      ) ?? false;
    } else if (choice == 'advanced') {
      result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const AdvancedBulkSaleScreen(),
        ),
      ) ?? false;
    }
    
    if (result) {
      _loadSales();
    }
  }

  void _showSaleDetails(InventoryTransaction sale) async {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Satış Detayları',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            _DetailRow('Ürün', sale.productName),
            _DetailRow('Müşteri', sale.customerName ?? 'Belirtilmemiş'),
            _DetailRow('Miktar', '${sale.quantity} adet'),
            _DetailRow('Birim Fiyat', '₺${NumberFormat('#,##0.00').format(sale.unitPrice)}'),
            _DetailRow('Tarih', DateFormat('dd/MM/yyyy HH:mm').format(sale.transactionDate)),
            _DetailRow('Toplam Tutar', '₺${NumberFormat('#,##0.00').format(sale.totalAmount)}'),
            if (sale.profitLoss != null)
              _DetailRow('Kar/Zarar', '₺${NumberFormat('#,##0.00').format(sale.profitLoss!)}'),
            if (sale.notes != null && sale.notes!.isNotEmpty)
              _DetailRow('Notlar', sale.notes!),
            
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  void _sortTable(String column) {
    setState(() {
      if (sortBy == column) {
        sortAscending = !sortAscending;
      } else {
        sortBy = column;
        sortAscending = true;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        backgroundColor: Theme.of(context).colorScheme.background,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: AppBar(
        title: const Text('Satışlar'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _navigateToAddSale,
            tooltip: 'Satış Ekle',
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Ürün adı veya müşteri ile ara...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Theme.of(context).colorScheme.background,
              ),
              onChanged: (value) {
                setState(() {
                  searchQuery = value;
                });
              },
            ),
          ),
          
          // Professional Card List
          Expanded(
            child: filteredAndSortedSales.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.point_of_sale,
                          size: 64,
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          searchQuery.isEmpty ? 'Henüz satış kaydı bulunmuyor' : 'Arama sonucu bulunamadı',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          searchQuery.isEmpty 
                              ? 'İlk satışınızı kaydetmek için + butonuna tıklayın'
                              : 'Farklı anahtar kelimeler deneyin',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: filteredAndSortedSales.length,
                    itemBuilder: (context, index) {
                      final sale = filteredAndSortedSales[index];
                      final isProfit = sale.profitLoss != null && sale.profitLoss! > 0;
                      final isLoss = sale.profitLoss != null && sale.profitLoss! < 0;
                      
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
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
                        child: InkWell(
                          onTap: () => _showSaleDetails(sale),
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Header Row
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Sale Info
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            sale.productName,
                                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                              fontWeight: FontWeight.w600,
                                              color: Theme.of(context).colorScheme.onSurface,
                                            ),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            sale.customerName ?? 'Müşteri belirtilmemiş',
                                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    // Amount
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          '₺${NumberFormat('#,##0.00').format(sale.totalAmount)}',
                                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                            fontWeight: FontWeight.w700,
                                            color: Colors.green,
                                          ),
                                        ),
                                        Text(
                                          '${sale.quantity} adet',
                                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                
                                const SizedBox(height: 12),
                                
                                // Info Row
                                Row(
                                  children: [
                                    // Date
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Theme.of(context).colorScheme.secondary.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.calendar_today,
                                            size: 14,
                                            color: Theme.of(context).colorScheme.secondary,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            DateFormat('dd/MM/yy').format(sale.transactionDate),
                                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                              fontWeight: FontWeight.w600,
                                              color: Theme.of(context).colorScheme.secondary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    
                                    const Spacer(),
                                    
                                    // Profit/Loss Badge
                                    if (sale.profitLoss != null)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: isProfit 
                                              ? Colors.green.withOpacity(0.1)
                                              : isLoss 
                                                  ? Theme.of(context).colorScheme.error.withOpacity(0.1)
                                                  : Colors.grey.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              isProfit 
                                                  ? Icons.trending_up 
                                                  : isLoss 
                                                      ? Icons.trending_down 
                                                      : Icons.trending_flat,
                                              size: 14,
                                              color: isProfit 
                                                  ? Colors.green
                                                  : isLoss 
                                                      ? Theme.of(context).colorScheme.error
                                                      : Colors.grey,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              '₺${NumberFormat('#,##0.00').format(sale.profitLoss!.abs())}',
                                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                                fontWeight: FontWeight.w600,
                                                color: isProfit 
                                                    ? Colors.green
                                                    : isLoss 
                                                        ? Theme.of(context).colorScheme.error
                                                        : Colors.grey,
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
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
} 