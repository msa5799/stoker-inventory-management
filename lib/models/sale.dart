import 'sale_item.dart';

class Sale {
  final int? id;
  final String customerName;
  final String? customerPhone;
  final double totalAmount;
  final String paymentMethod;
  final DateTime saleDate;
  final String? notes;
  final List<SaleItem> items;

  Sale({
    this.id,
    required this.customerName,
    this.customerPhone,
    required this.totalAmount,
    required this.paymentMethod,
    required this.saleDate,
    this.notes,
    this.items = const [],
  });

  factory Sale.fromMap(Map<String, dynamic> map) {
    return Sale(
      id: map['id'],
      customerName: map['customer_name'],
      customerPhone: map['customer_phone'],
      totalAmount: map['total_amount'],
      paymentMethod: map['payment_method'],
      saleDate: DateTime.parse(map['sale_date']),
      notes: map['notes'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'customer_name': customerName,
      'customer_phone': customerPhone,
      'total_amount': totalAmount,
      'payment_method': paymentMethod,
      'sale_date': saleDate.toIso8601String(),
      'notes': notes,
    };
  }

  Sale copyWith({
    int? id,
    String? customerName,
    String? customerPhone,
    double? totalAmount,
    String? paymentMethod,
    DateTime? saleDate,
    String? notes,
    List<SaleItem>? items,
  }) {
    return Sale(
      id: id ?? this.id,
      customerName: customerName ?? this.customerName,
      customerPhone: customerPhone ?? this.customerPhone,
      totalAmount: totalAmount ?? this.totalAmount,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      saleDate: saleDate ?? this.saleDate,
      notes: notes ?? this.notes,
      items: items ?? this.items,
    );
  }
} 