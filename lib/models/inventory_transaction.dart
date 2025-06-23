class InventoryTransaction {
  final int? id;
  final int productId;
  final String productName;
  final String transactionType; // 'purchase', 'sale', 'return', 'loss', 'adjustment'
  final int quantity;
  final double unitPrice; // Bu işlemdeki birim fiyat
  final double totalAmount; // Toplam tutar
  final String? batchNumber; // Lot/batch numarası
  final DateTime transactionDate;
  final String? customerName; // Satış/iade için müşteri adı
  final String? supplierName; // Satın alma için tedarikçi adı
  final String? notes; // Notlar
  final String? referenceId; // İade için orijinal satış ID'si
  final double? profitLoss; // Satışlarda kar/zarar
  final DateTime createdAt;

  InventoryTransaction({
    this.id,
    required this.productId,
    required this.productName,
    required this.transactionType,
    required this.quantity,
    required this.unitPrice,
    required this.totalAmount,
    this.batchNumber,
    required this.transactionDate,
    this.customerName,
    this.supplierName,
    this.notes,
    this.referenceId,
    this.profitLoss,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'product_id': productId,
      'product_name': productName,
      'transaction_type': transactionType,
      'quantity': quantity,
      'unit_price': unitPrice,
      'total_amount': totalAmount,
      'batch_number': batchNumber,
      'transaction_date': transactionDate.toIso8601String(),
      'customer_name': customerName,
      'supplier_name': supplierName,
      'notes': notes,
      'reference_id': referenceId,
      'profit_loss': profitLoss,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory InventoryTransaction.fromMap(Map<String, dynamic> map) {
    return InventoryTransaction(
      id: map['id'] is String ? int.tryParse(map['id']) : map['id']?.toInt(),
      productId: parseToInt(map['product_id']),
      productName: map['product_name']?.toString() ?? '',
      transactionType: map['transaction_type']?.toString() ?? '',
      quantity: parseToInt(map['quantity']),
      unitPrice: parseToDouble(map['unit_price']),
      totalAmount: parseToDouble(map['total_amount']),
      batchNumber: map['batch_number']?.toString(),
      transactionDate: parseDateTime(map['transaction_date']) ?? DateTime.now(),
      customerName: map['customer_name']?.toString(),
      supplierName: map['supplier_name']?.toString(),
      notes: map['notes']?.toString(),
      referenceId: map['reference_id']?.toString(),
      profitLoss: parseToDouble(map['profit_loss']),
      createdAt: parseDateTime(map['created_at']) ?? DateTime.now(),
    );
  }

  // Helper methods for safe parsing
  static int parseToInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? 0;
    if (value is double) return value.toInt();
    return 0;
  }

  static double parseToDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  static DateTime? parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String) {
      try {
        return DateTime.parse(value);
      } catch (e) {
        print('DateTime parsing error: $e');
        return null;
      }
    }
    // Handle Firestore Timestamp
    if (value.toString().contains('Timestamp')) {
      try {
        return value.toDate();
      } catch (e) {
        print('Timestamp parsing error: $e');
        return null;
      }
    }
    return null;
  }

  InventoryTransaction copyWith({
    int? id,
    int? productId,
    String? productName,
    String? transactionType,
    int? quantity,
    double? unitPrice,
    double? totalAmount,
    String? batchNumber,
    DateTime? transactionDate,
    String? customerName,
    String? supplierName,
    String? notes,
    String? referenceId,
    double? profitLoss,
    DateTime? createdAt,
  }) {
    return InventoryTransaction(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      transactionType: transactionType ?? this.transactionType,
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice ?? this.unitPrice,
      totalAmount: totalAmount ?? this.totalAmount,
      batchNumber: batchNumber ?? this.batchNumber,
      transactionDate: transactionDate ?? this.transactionDate,
      customerName: customerName ?? this.customerName,
      supplierName: supplierName ?? this.supplierName,
      notes: notes ?? this.notes,
      referenceId: referenceId ?? this.referenceId,
      profitLoss: profitLoss ?? this.profitLoss,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

// Stok lot modeli - Hangi alıştan kaç adet kaldığını takip eder
class StockLot {
  final int? id;
  final int productId;
  final String? batchNumber;
  final double purchasePrice; // Bu lot'un alış fiyatı
  final int originalQuantity; // Başlangıç adedi
  final int remainingQuantity; // Kalan adet
  final DateTime purchaseDate;
  final String? supplierName;
  final DateTime createdAt;

  StockLot({
    this.id,
    required this.productId,
    this.batchNumber,
    required this.purchasePrice,
    required this.originalQuantity,
    required this.remainingQuantity,
    required this.purchaseDate,
    this.supplierName,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'product_id': productId,
      'batch_number': batchNumber,
      'purchase_price': purchasePrice,
      'original_quantity': originalQuantity,
      'remaining_quantity': remainingQuantity,
      'purchase_date': purchaseDate.toIso8601String(),
      'supplier_name': supplierName,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory StockLot.fromMap(Map<String, dynamic> map) {
    return StockLot(
      id: map['id'] is String ? int.tryParse(map['id']) : map['id']?.toInt(),
      productId: InventoryTransaction.parseToInt(map['product_id']),
      batchNumber: map['batch_number']?.toString(),
      purchasePrice: InventoryTransaction.parseToDouble(map['purchase_price']),
      originalQuantity: InventoryTransaction.parseToInt(map['original_quantity']),
      remainingQuantity: InventoryTransaction.parseToInt(map['remaining_quantity']),
      purchaseDate: InventoryTransaction.parseDateTime(map['purchase_date']) ?? DateTime.now(),
      supplierName: map['supplier_name']?.toString(),
      createdAt: InventoryTransaction.parseDateTime(map['created_at']) ?? DateTime.now(),
    );
  }

  StockLot copyWith({
    int? id,
    int? productId,
    String? batchNumber,
    double? purchasePrice,
    int? originalQuantity,
    int? remainingQuantity,
    DateTime? purchaseDate,
    String? supplierName,
    DateTime? createdAt,
  }) {
    return StockLot(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      batchNumber: batchNumber ?? this.batchNumber,
      purchasePrice: purchasePrice ?? this.purchasePrice,
      originalQuantity: originalQuantity ?? this.originalQuantity,
      remainingQuantity: remainingQuantity ?? this.remainingQuantity,
      purchaseDate: purchaseDate ?? this.purchaseDate,
      supplierName: supplierName ?? this.supplierName,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

// İşlem türleri
class TransactionType {
  static const String purchase = 'purchase';
  static const String sale = 'sale';
  static const String returnSale = 'return_sale';
  static const String returnPurchase = 'return_purchase';
  static const String loss = 'loss';
  static const String adjustment = 'adjustment';
  
  static List<String> get allTypes => [
    purchase,
    sale,
    returnSale,
    returnPurchase,
    loss,
    adjustment,
  ];
  
  static String getDisplayName(String type) {
    switch (type) {
      case purchase:
        return 'Satın Alma';
      case sale:
        return 'Satış';
      case returnSale:
        return 'Satış İadesi';
      case returnPurchase:
        return 'Alış İadesi';
      case loss:
        return 'Kayıp/Atık';
      case adjustment:
        return 'Stok Düzeltme';
      default:
        return type;
    }
  }
} 