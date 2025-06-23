import 'product.dart';
import 'sale.dart';
import 'sale_item.dart';
import 'inventory_transaction.dart';

class BackupData {
  final String version;
  final DateTime createdAt;
  final String businessName;
  final String userEmail;
  final List<Product> products;
  final List<Sale> sales;
  final List<SaleItem> saleItems;
  final List<InventoryTransaction>? inventoryTransactions;

  BackupData({
    required this.version,
    required this.createdAt,
    required this.businessName,
    required this.userEmail,
    required this.products,
    required this.sales,
    required this.saleItems,
    this.inventoryTransactions,
  });

  Map<String, dynamic> toJson() {
    return {
      'version': version,
      'created_at': createdAt.toIso8601String(),
      'business_name': businessName,
      'user_email': userEmail,
      'products': products.map((p) => p.toMap()).toList(),
      'sales': sales.map((s) => s.toMap()).toList(),
      'sale_items': saleItems.map((si) => si.toMap()).toList(),
      'inventory_transactions': inventoryTransactions?.map((it) => it.toMap()).toList() ?? [],
    };
  }

  factory BackupData.fromJson(Map<String, dynamic> json) {
    return BackupData(
      version: json['version'] ?? '1.0.0',
      createdAt: DateTime.parse(json['created_at']),
      businessName: json['business_name'] ?? '',
      userEmail: json['user_email'] ?? '',
      products: (json['products'] as List)
          .map((p) => Product.fromMap(p))
          .toList(),
      sales: (json['sales'] as List)
          .map((s) => Sale.fromMap(s))
          .toList(),
      saleItems: (json['sale_items'] as List)
          .map((si) => SaleItem.fromMap(si))
          .toList(),
      inventoryTransactions: json['inventory_transactions'] != null
          ? (json['inventory_transactions'] as List)
              .map((it) => InventoryTransaction.fromMap(it))
              .toList()
          : null,
    );
  }

  int get totalProducts => products.length;
  int get totalSales => sales.length;
  double get totalSalesAmount => sales.fold(0, (sum, sale) => sum + sale.totalAmount);

  int get totalInventoryTransactions => inventoryTransactions?.length ?? 0;
  double get totalInventorySalesAmount {
    if (inventoryTransactions == null) return 0;
    return inventoryTransactions!
        .where((t) => t.transactionType == TransactionType.sale)
        .fold(0, (sum, t) => sum + t.totalAmount);
  }

  bool get isNewSystemBackup => inventoryTransactions != null && inventoryTransactions!.isNotEmpty;
  bool get isLegacyBackup => inventoryTransactions == null || inventoryTransactions!.isEmpty;
} 