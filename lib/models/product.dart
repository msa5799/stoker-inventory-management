class Product {
  final int? id;
  final String name;
  final String sku;
  final String? barcode;
  final int currentStock;
  final int minStockLevel;
  final String unit;
  final String? description;
  final double purchasePrice; // Varsayılan alış fiyatı
  final double salePrice; // Varsayılan satış fiyatı
  final DateTime createdAt;
  final DateTime? updatedAt;

  Product({
    this.id,
    required this.name,
    required this.sku,
    this.barcode,
    this.currentStock = 0, // Varsayılan olarak 0
    required this.minStockLevel,
    required this.unit,
    this.description,
    this.purchasePrice = 0.0, // Varsayılan alış fiyatı
    this.salePrice = 0.0, // Varsayılan satış fiyatı
    required this.createdAt,
    this.updatedAt,
  });

  // Getter'lar - geriye uyumluluk için
  double get buyPrice => purchasePrice;
  double get sellPrice => salePrice;

  factory Product.fromMap(Map<String, dynamic> map) {
    return Product(
      id: map['id'] is String ? int.tryParse(map['id']) : map['id']?.toInt(),
      name: map['name']?.toString() ?? '',
      sku: map['sku']?.toString() ?? '',
      barcode: map['barcode']?.toString(),
      currentStock: parseToInt(map['current_stock']),
      minStockLevel: parseToInt(map['min_stock_level']),
      unit: map['unit']?.toString() ?? '',
      description: map['description']?.toString(),
      purchasePrice: parseToDouble(map['purchase_price']),
      salePrice: parseToDouble(map['sale_price']),
      createdAt: parseDateTime(map['created_at']) ?? DateTime.now(),
      updatedAt: parseDateTime(map['updated_at']),
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

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'sku': sku,
      'barcode': barcode,
      'current_stock': currentStock,
      'min_stock_level': minStockLevel,
      'unit': unit,
      'description': description,
      'purchase_price': purchasePrice,
      'sale_price': salePrice,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  Product copyWith({
    int? id,
    String? name,
    String? sku,
    String? barcode,
    int? currentStock,
    int? minStockLevel,
    String? unit,
    String? description,
    double? purchasePrice,
    double? salePrice,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      sku: sku ?? this.sku,
      barcode: barcode ?? this.barcode,
      currentStock: currentStock ?? this.currentStock,
      minStockLevel: minStockLevel ?? this.minStockLevel,
      unit: unit ?? this.unit,
      description: description ?? this.description,
      purchasePrice: purchasePrice ?? this.purchasePrice,
      salePrice: salePrice ?? this.salePrice,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  bool get isLowStock => currentStock <= minStockLevel;
} 