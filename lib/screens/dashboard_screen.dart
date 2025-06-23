import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/firebase_service.dart';
import '../services/inventory_service.dart';
import '../services/subscription_service.dart';
import '../services/notification_service.dart';
import '../models/product.dart';
import '../models/inventory_transaction.dart';
import '../models/subscription.dart';
import 'add_product_screen.dart';
import 'products_screen.dart';
import 'backup_screen.dart';
import 'subscription_screen.dart';
import 'profile_screen.dart';
import 'settings_screen.dart';
import 'help_screen.dart';
import 'auth/login_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final InventoryService _inventoryService = InventoryService();
  final SubscriptionService _subscriptionService = SubscriptionService();
  final NotificationService _notificationService = NotificationService();
  
  double _totalSales = 0;
  double _totalPurchases = 0;
  double _totalProfit = 0;
  int _totalProducts = 0;
  int _salesCount = 0;
  List<Map<String, dynamic>> _lowStockProducts = [];
  Subscription? _subscription;
  bool _notificationsEnabled = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    try {
      if (!mounted) return;
      
      setState(() {
        _isLoading = true;
      });

      // Firebase'den verileri paralel olarak yükle
      final futures = await Future.wait([
        FirebaseService.getProducts(),
        _inventoryService.getFinancialSummary(),
        FirebaseService.getTotalProductCount(),
        FirebaseService.getLowStockProducts(),
        _subscriptionService.getUserSubscription(),
        _notificationService.areNotificationsEnabled(),
      ]);

      final products = futures[0] as List<Map<String, dynamic>>;
      final financialSummary = futures[1] as Map<String, dynamic>;
      final totalProductCount = futures[2] as int;
      final lowStockProducts = futures[3] as List<Map<String, dynamic>>;
      final subscription = futures[4] as Subscription?;
      final notificationsEnabled = futures[5] as bool;
      
      final totalSalesAmount = financialSummary['totalSales'] ?? 0.0;
      final totalPurchases = financialSummary['totalPurchases'] ?? 0.0;
      final totalReturns = financialSummary['totalReturns'] ?? 0.0;
      final totalLosses = financialSummary['totalLosses'] ?? 0.0;
      final totalProfit = financialSummary['totalProfit'] ?? 0.0;
      final salesCount = financialSummary['salesCount'] ?? 0;
      final returnsCount = financialSummary['returnsCount'] ?? 0;
      final lossesCount = financialSummary['lossesCount'] ?? 0;
      
      print('📊 Finansal özet yüklendi:');
      print('   Satışlar: $salesCount işlem, ₺${totalSalesAmount.toStringAsFixed(2)}');
      print('   Alımlar: ${financialSummary['purchasesCount'] ?? 0} işlem, ₺${totalPurchases.toStringAsFixed(2)}');
      print('   İadeler: $returnsCount işlem, ₺${totalReturns.toStringAsFixed(2)}');
      print('   Kayıplar: $lossesCount işlem, ₺${totalLosses.toStringAsFixed(2)}');
      print('   Net Kar: ₺${totalProfit.toStringAsFixed(2)}');
      
      if (!mounted) return;
      
      setState(() {
        _totalSales = totalSalesAmount;
        _totalPurchases = totalPurchases;
        _totalProfit = totalProfit;
        _totalProducts = totalProductCount;
        _salesCount = salesCount;
        _lowStockProducts = lowStockProducts;
        _subscription = subscription;
        _notificationsEnabled = notificationsEnabled;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      
      setState(() {
        _isLoading = false;
      });
      print('Dashboard yüklenirken hata: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Dashboard yüklenirken hata: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showUserMenu() {
    final user = FirebaseService.currentUser;
    
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
            
            if (user != null) ...[
              CircleAvatar(
                radius: 30,
                backgroundColor: Theme.of(context).colorScheme.primary,
                child: Text(
                  user.email?.substring(0, 1).toUpperCase() ?? 'U',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onPrimary,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                user.email ?? 'Kullanıcı',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              Text(
                'Firebase Kullanıcısı',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                ),
              ),
              const SizedBox(height: 24),
            ],
            
            ListTile(
              leading: Icon(Icons.person, color: Theme.of(context).colorScheme.primary),
              title: const Text('Profil'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ProfileScreen()),
                );
              },
            ),
            ListTile(
              leading: Icon(Icons.backup, color: Theme.of(context).colorScheme.secondary),
              title: const Text('Yedekle'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const BackupScreen()),
                );
              },
            ),
            ListTile(
              leading: Icon(Icons.settings, color: Theme.of(context).colorScheme.tertiary),
              title: const Text('Ayarlar'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const SettingsScreen()),
                );
              },
            ),
            
            ListTile(
              leading: Icon(Icons.help, color: Theme.of(context).colorScheme.secondary),
              title: const Text('Yardım'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const HelpScreen()),
                );
              },
            ),
            
            ListTile(
              leading: Icon(Icons.logout, color: Theme.of(context).colorScheme.error),
              title: const Text('Çıkış Yap'),
              onTap: () async {
                Navigator.pop(context);
                await FirebaseService.logout();
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

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    String? subtitle,
    VoidCallback? onTap,
  }) {
    return Card(
      elevation: 4,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: LinearGradient(
              colors: [color.withOpacity(0.1), color.withOpacity(0.05)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isSmallCard = constraints.maxWidth < 150;
              
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Icon(
                        icon, 
                        color: color, 
                        size: isSmallCard ? 24 : 32,
                      ),
                      if (onTap != null)
                        Icon(
                          Icons.arrow_forward_ios, 
                          color: color, 
                          size: isSmallCard ? 12 : 16,
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          value,
                          style: TextStyle(
                            fontSize: isSmallCard ? 16 : 20,
                            fontWeight: FontWeight.bold,
                            color: color,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: isSmallCard ? 11 : 13,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (subtitle != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            subtitle,
                            style: TextStyle(
                              fontSize: isSmallCard ? 10 : 11,
                              color: Colors.grey[500],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildQuickActionCard({
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isSmallCard = constraints.maxWidth < 100;
              
              return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: EdgeInsets.all(isSmallCard ? 8 : 12),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      icon, 
                      color: color, 
                      size: isSmallCard ? 24 : 28,
                    ),
                  ),
                  SizedBox(height: isSmallCard ? 6 : 8),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: isSmallCard ? 11 : 13,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Theme.of(context).colorScheme.background,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenHeight < 700;
    final isNarrowScreen = screenWidth < 400;

    return RefreshIndicator(
      onRefresh: _loadDashboardData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // İstatistikler
            Text(
              'Genel Durum',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: isSmallScreen ? 18 : 22,
              ),
            ),
            SizedBox(height: isSmallScreen ? 12 : 16),
            
            // Responsive grid for stats
            LayoutBuilder(
              builder: (context, constraints) {
                final crossAxisCount = constraints.maxWidth > 600 ? 4 : 2;
                final childAspectRatio = isSmallScreen ? 1.4 : 1.2;
                
                return GridView.count(
                  crossAxisCount: crossAxisCount,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: isSmallScreen ? 8 : 16,
                  mainAxisSpacing: isSmallScreen ? 8 : 16,
                  childAspectRatio: childAspectRatio,
                  children: [
                    _buildStatCard(
                      title: 'Toplam Satış',
                      value: '₺${NumberFormat('#,##0.00', 'tr_TR').format(_totalSales)}',
                      icon: Icons.trending_up,
                      color: Colors.green,
                      subtitle: '$_salesCount işlem',
                    ),
                    _buildStatCard(
                      title: 'Toplam Alış',
                      value: '₺${NumberFormat('#,##0.00', 'tr_TR').format(_totalPurchases)}',
                      icon: Icons.shopping_cart,
                      color: Colors.blue,
                    ),
                    _buildStatCard(
                      title: 'Net Kar',
                      value: '₺${NumberFormat('#,##0.00', 'tr_TR').format(_totalProfit)}',
                      icon: _totalProfit >= 0 ? Icons.trending_up : Icons.trending_down,
                      color: _totalProfit >= 0 ? Colors.green : Colors.red,
                    ),
                    _buildStatCard(
                      title: 'Toplam Ürün',
                      value: _totalProducts.toString(),
                      icon: Icons.inventory,
                      color: Colors.purple,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const ProductsScreen()),
                        );
                      },
                    ),
                  ],
                );
              },
            ),
            
            SizedBox(height: isSmallScreen ? 20 : 32),
            
            // Hızlı İşlemler
            Text(
              'Hızlı İşlemler',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: isSmallScreen ? 18 : 22,
              ),
            ),
            SizedBox(height: isSmallScreen ? 12 : 16),
            
            // Responsive grid for quick actions
            LayoutBuilder(
              builder: (context, constraints) {
                final crossAxisCount = constraints.maxWidth > 600 ? 6 : 3;
                final childAspectRatio = isSmallScreen ? 1.1 : 1.0;
                
                return GridView.count(
                  crossAxisCount: crossAxisCount,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: isSmallScreen ? 8 : 12,
                  mainAxisSpacing: isSmallScreen ? 8 : 12,
                  childAspectRatio: childAspectRatio,
                  children: [
                    _buildQuickActionCard(
                      title: 'Ürün Ekle',
                      icon: Icons.add_box,
                      color: Colors.blue,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const AddProductScreen()),
                        ).then((_) => _loadDashboardData());
                      },
                    ),
                    _buildQuickActionCard(
                      title: 'Ürünler',
                      icon: Icons.inventory_2,
                      color: Colors.green,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const ProductsScreen()),
                        ).then((_) => _loadDashboardData());
                      },
                    ),
                    _buildQuickActionCard(
                      title: 'Yedekle',
                      icon: Icons.backup,
                      color: Colors.orange,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const BackupScreen()),
                        );
                      },
                    ),
                  ],
                );
              },
            ),
            
            SizedBox(height: isSmallScreen ? 20 : 32),
            
            // Düşük Stoklu Ürünler
            if (_lowStockProducts.isNotEmpty) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'Düşük Stoklu Ürünler',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: isSmallScreen ? 18 : 22,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _lowStockProducts.length.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: isSmallScreen ? 12 : 16),
              
              Container(
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _lowStockProducts.length > (isSmallScreen ? 3 : 5) 
                      ? (isSmallScreen ? 3 : 5) 
                      : _lowStockProducts.length,
                  separatorBuilder: (context, index) => Divider(
                    color: Colors.red.shade200,
                    height: 1,
                  ),
                  itemBuilder: (context, index) {
                    final product = _lowStockProducts[index];
                    final currentStock = product['current_stock'] ?? 0;
                    final minStock = product['min_stock_level'] ?? 0;
                    
                    return ListTile(
                      dense: isSmallScreen,
                      leading: CircleAvatar(
                        backgroundColor: Colors.red,
                        radius: isSmallScreen ? 16 : 20,
                        child: Icon(
                          currentStock <= 0 ? Icons.error : Icons.warning,
                          color: Colors.white,
                          size: isSmallScreen ? 16 : 20,
                        ),
                      ),
                      title: Text(
                        product['name'] ?? '',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: isSmallScreen ? 14 : 16,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        'Stok: $currentStock ${product['unit'] ?? ''} (Min: $minStock)',
                        style: TextStyle(fontSize: isSmallScreen ? 12 : 14),
                      ),
                      trailing: Icon(
                        Icons.arrow_forward_ios,
                        color: Colors.red,
                        size: isSmallScreen ? 14 : 16,
                      ),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const ProductsScreen()),
                        ).then((_) => _loadDashboardData());
                      },
                    );
                  },
                ),
              ),
              
              if (_lowStockProducts.length > (isSmallScreen ? 3 : 5)) ...[
                SizedBox(height: isSmallScreen ? 6 : 8),
                Center(
                  child: TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const ProductsScreen()),
                      ).then((_) => _loadDashboardData());
                    },
                    child: Text(
                      '${_lowStockProducts.length - (isSmallScreen ? 3 : 5)} ürün daha göster',
                      style: TextStyle(fontSize: isSmallScreen ? 12 : 14),
                    ),
                  ),
                ),
              ],
            ],
            
            // Bottom padding to prevent overflow
            SizedBox(height: isSmallScreen ? 80 : 100),
          ],
        ),
      ),
    );
  }
} 