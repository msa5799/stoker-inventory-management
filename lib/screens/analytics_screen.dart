import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/inventory_service.dart';
import '../services/firebase_service.dart';
import '../models/inventory_transaction.dart';
import '../models/product.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  final InventoryService _inventoryService = InventoryService();
  final ScrollController _scrollController = ScrollController();
  
  List<InventoryTransaction> _transactions = [];
  List<Map<String, dynamic>> _lowStockProducts = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  DateTime _selectedStartDate = DateTime.now().subtract(const Duration(days: 60));
  DateTime _selectedEndDate = DateTime.now();
  
  double _totalSales = 0;
  double _totalPurchases = 0;
  double _totalProfit = 0;
  int _transactionCount = 0;
  int _totalProducts = 0;
  
  // Server-side pagination parametreleri
  static const int _pageSize = 15;
  DocumentSnapshot? _lastDocument;
  bool _hasMoreData = true;
  
  @override
  void initState() {
    super.initState();
    _loadAnalytics();
    _scrollController.addListener(_onScroll);
  }
  
  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }
  
  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      // Sayfanın sonuna yaklaştığında server'dan daha fazla veri yükle
      _loadMoreTransactions();
    }
  }
  
  Future<void> _loadAnalytics() async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
      _transactions.clear();
      _lastDocument = null;
      _hasMoreData = true;
    });
    
    try {
      // Paralel olarak temel verileri yükle
      final futures = await Future.wait([
        FirebaseService.getProductsPaginated(limit: 100, useCache: false), // Cache kullanma
        FirebaseService.getLowStockProducts(),
        _inventoryService.getFinancialSummary(
          startDate: _selectedStartDate,
          endDate: _selectedEndDate,
        ), // Tarih filtresi ile finansal özet
      ]);
      
      final productsResult = futures[0] as Map<String, dynamic>;
      final allProducts = productsResult['products'] as List<Map<String, dynamic>>;
      final lowStockProducts = futures[1] as List<Map<String, dynamic>>;
      final financialSummary = futures[2] as Map<String, dynamic>;
      
      if (!mounted) return;
      
      setState(() {
        _totalProducts = allProducts.length;
        _totalSales = financialSummary['totalSales'] ?? 0.0;
        _totalPurchases = financialSummary['totalPurchases'] ?? 0.0;
        _totalProfit = financialSummary['totalProfit'] ?? 0.0;
        _transactionCount = financialSummary['totalTransactions'] ?? 0;
        _lowStockProducts = lowStockProducts;
      });
      
      // İlk işlem sayfasını yükle (cache kullanma)
      await _loadMoreTransactions(isInitial: true);
      
      if (!mounted) return;
      
      setState(() {
        _isLoading = false;
      });
      
      print('📊 Analytics yüklendi (Server-side):');
      print('   Net Kar: ₺${_totalProfit.toStringAsFixed(2)}');
      print('   İlk ${_transactions.length} işlem yüklendi');
      print('   Toplam ürün: ${_totalProducts}');
      
    } catch (e) {
      if (!mounted) return;
      
      setState(() {
        _isLoading = false;
      });
      print('❌ Analytics yükleme hatası: $e');
    }
  }
  
  Future<void> _loadMoreTransactions({bool isInitial = false}) async {
    if (!mounted || _isLoadingMore || (!_hasMoreData && !isInitial)) return;
    
    if (mounted) {
      setState(() {
        _isLoadingMore = true;
      });
    }
    
    try {
      // Server-side pagination ile işlemleri yükle (Cache kullanma!)
      final result = await FirebaseService.getTransactionsPaginated(
        limit: _pageSize,
        startAfter: isInitial ? null : _lastDocument, // İlk yüklemede null, sonrasında lastDocument
        useCache: false, // Cache kullanma - pagination bozuluyor
      );
      
      final transactionMaps = result['transactions'] as List<Map<String, dynamic>>;
      final hasMore = result['hasMore'] as bool;
      final lastDoc = result['lastDocument'] as DocumentSnapshot?;
      
      // Map'leri InventoryTransaction'a çevir ve tarih filtresi uygula
      final newTransactions = transactionMaps
          .map((map) => InventoryTransaction.fromMap(map))
          .where((transaction) {
        final transactionDate = transaction.transactionDate;
        return transactionDate.isAfter(_selectedStartDate.subtract(Duration(days: 1))) && 
               transactionDate.isBefore(_selectedEndDate.add(Duration(days: 1)));
      }).toList();
      
      if (!mounted) return;
      
      setState(() {
        if (isInitial) {
          _transactions = newTransactions;
        } else {
          // Duplicate check - aynı ID'ye sahip işlemleri ekleme
          final existingIds = _transactions.map((t) => t.id).toSet();
          final filteredNewTransactions = newTransactions.where((t) => !existingIds.contains(t.id)).toList();
          _transactions.addAll(filteredNewTransactions);
          print('📄 ${filteredNewTransactions.length} yeni işlem eklendi (${newTransactions.length - filteredNewTransactions.length} duplicate filtrelendi)');
        }
        _lastDocument = lastDoc;
        _hasMoreData = hasMore;
        _isLoadingMore = false;
      });
      
      print('📄 ${isInitial ? 'İlk' : 'Ek'} ${newTransactions.length} işlem yüklendi (hasMore: $hasMore)');
      print('📄 Toplam işlem sayısı: ${_transactions.length}');
      
    } catch (e) {
      if (!mounted) return;
      
      setState(() {
        _isLoadingMore = false;
      });
      print('❌ İşlem yükleme hatası: $e');
    }
  }
  
  Future<void> _selectDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(
        start: _selectedStartDate,
        end: _selectedEndDate,
      ),
    );
    
    if (picked != null) {
      setState(() {
        _selectedStartDate = picked.start;
        _selectedEndDate = picked.end;
      });
      _loadAnalytics();
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: AppBar(
        title: const Text('Analitik'),
        actions: [
          IconButton(
            icon: const Icon(Icons.date_range),
            onPressed: _selectDateRange,
            tooltip: 'Tarih Aralığı Seç',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadAnalytics,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                controller: _scrollController,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Date Range Card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.calendar_today,
                                color: Theme.of(context).colorScheme.primary,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Analiz Dönemi',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: Theme.of(context).colorScheme.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${DateFormat('dd/MM/yyyy').format(_selectedStartDate)} - ${DateFormat('dd/MM/yyyy').format(_selectedEndDate)}',
                            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${_selectedEndDate.difference(_selectedStartDate).inDays + 1} gün',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Summary Statistics
                    Text(
                      'Özet İstatistikler',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatCard(
                            'Toplam Satış',
                            '₺${NumberFormat('#,##0.00').format(_totalSales)}',
                            Icons.trending_up,
                            Colors.green,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildStatCard(
                            'Toplam Alış',
                            '₺${NumberFormat('#,##0.00').format(_totalPurchases)}',
                            Icons.shopping_cart,
                            Theme.of(context).colorScheme.secondary,
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 16),
                    
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatCard(
                            'Net Kar/Zarar',
                            '₺${NumberFormat('#,##0.00').format(_totalProfit)}',
                            _totalProfit >= 0 ? Icons.arrow_upward : Icons.arrow_downward,
                            _totalProfit >= 0 ? Colors.green : Theme.of(context).colorScheme.error,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildStatCard(
                            'İşlem Sayısı',
                            _transactions.length.toString(),
                            Icons.receipt_long,
                            Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 32),
                    
                    // Stock Status Section
                    Text(
                      'Stok Durumu',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    _buildStockStatusCard(),
                    
                    const SizedBox(height: 32),
                    
                    // Recent Transactions
                    Text(
                      'Son İşlemler',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: _transactions.isEmpty
                          ? Padding(
                              padding: const EdgeInsets.all(32),
                              child: Center(
                                child: Column(
                                  children: [
                                    Icon(
                                      Icons.analytics_outlined,
                                      size: 48,
                                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'Seçilen tarih aralığında işlem bulunamadı',
                                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : Column(
                              children: _transactions.map((transaction) {
                                // İşlem türüne göre görünümü belirle
                                IconData icon;
                                Color color;
                                String typeText;
                                
                                switch (transaction.transactionType.toLowerCase()) {
                                  case 'sale':
                                    icon = Icons.point_of_sale;
                                    color = Colors.green;
                                    typeText = 'Satış';
                                    break;
                                  case 'purchase':
                                    icon = Icons.shopping_cart;
                                    color = Theme.of(context).colorScheme.secondary;
                                    typeText = 'Alış';
                                    break;
                                  case 'return_sale':
                                    icon = Icons.keyboard_return;
                                    color = Colors.orange;
                                    typeText = 'Müşteri İadesi';
                                    break;
                                  case 'return_purchase':
                                    icon = Icons.undo;
                                    color = Colors.blue;
                                    typeText = 'Tedarikçi İadesi';
                                    break;
                                  case 'loss':
                                    icon = Icons.warning;
                                    color = Colors.red;
                                    typeText = 'Kayıp/Fire';
                                    break;
                                  default:
                                    icon = Icons.receipt;
                                    color = Colors.grey;
                                    typeText = 'Diğer';
                                }
                                
                                return ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: color.withOpacity(0.1),
                                    child: Icon(
                                      icon,
                                      color: color,
                                      size: 20,
                                    ),
                                  ),
                                  title: Text(
                                    transaction.productName,
                                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  subtitle: Text(
                                    '$typeText • ${DateFormat('dd/MM/yyyy HH:mm').format(transaction.transactionDate)}',
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                                    ),
                                  ),
                                  trailing: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        '${transaction.quantity} adet',
                                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                                        ),
                                      ),
                                      Text(
                                        '₺${NumberFormat('#,##0.00').format(transaction.totalAmount)}',
                                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                          fontWeight: FontWeight.w600,
                                          color: color,
                                        ),
                                      ),
                                      if (transaction.profitLoss != null && transaction.transactionType.toLowerCase() != 'purchase')
                                        Text(
                                          transaction.profitLoss! >= 0 
                                              ? 'Kar: ₺${NumberFormat('#,##0.00').format(transaction.profitLoss!)}'
                                              : 'Zarar: ₺${NumberFormat('#,##0.00').format(transaction.profitLoss!.abs())}',
                                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                            color: transaction.profitLoss! >= 0 
                                                ? Colors.green 
                                                : Theme.of(context).colorScheme.error,
                                          ),
                                        ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),
                    ),
                    
                    // Loading indicator ve pagination durumu
                    if (_isLoadingMore)
                      Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: Center(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Daha fazla işlem yükleniyor...',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    
                    if (!_hasMoreData && _transactions.isNotEmpty && !_isLoadingMore)
                      Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: Center(
                          child: Column(
                            children: [
                              Icon(
                                Icons.check_circle_outline,
                                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
                                size: 24,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Tüm işlemler yüklendi (${_transactions.length}/${_transactions.length})',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    
                    if (_hasMoreData && _transactions.isNotEmpty && !_isLoadingMore)
                      Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: Center(
                          child: Text(
                            'Daha fazla işlem var • Scroll edin',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                            ),
                          ),
                        ),
                      ),
                    
                    const SizedBox(height: 100), // Bottom padding
                  ],
                ),
              ),
            ),
    );
  }
  
  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 20,
                ),
              ),
              Spacer(),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            value,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStockStatusCard() {
    final hasLowStock = _lowStockProducts.isNotEmpty;
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: hasLowStock ? Border.all(color: Colors.orange.shade300, width: 1) : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: hasLowStock ? Colors.orange.withOpacity(0.1) : Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  hasLowStock ? Icons.warning : Icons.check_circle,
                  color: hasLowStock ? Colors.orange : Colors.green,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hasLowStock ? 'Düşük Stok Uyarısı' : 'Stok Durumu Normal',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: hasLowStock ? Colors.orange.shade700 : Colors.green.shade700,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      hasLowStock 
                          ? '${_lowStockProducts.length} üründe stok azaldı'
                          : 'Tüm ürünlerin stok seviyeleri yeterli',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: hasLowStock ? Colors.orange.shade600 : Colors.green.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '${_totalProducts} ürün',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ),
          
          if (hasLowStock) ...[
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 12),
            Text(
              'Düşük Stoklu Ürünler:',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: Colors.orange.shade700,
              ),
            ),
            const SizedBox(height: 8),
            ...(_lowStockProducts.take(5).map((product) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: Colors.orange,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${product['name']} (${product['currentStock'] ?? product['current_stock'] ?? 0} ${product['unit'] ?? 'adet'} kaldı, min: ${product['minStockLevel'] ?? product['min_stock_level'] ?? 0})',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.orange.shade600,
                      ),
                    ),
                  ),
                ],
              ),
            ))),
            
            if (_lowStockProducts.length > 5) ...[
              const SizedBox(height: 8),
              Text(
                '+ ${_lowStockProducts.length - 5} ürün daha',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.orange.shade600,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
} 