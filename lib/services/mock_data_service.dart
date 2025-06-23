import '../models/product.dart';
import '../models/sale.dart';
import '../models/sale_item.dart';
import 'auth_service.dart';

class MockDataService {
  static final MockDataService _instance = MockDataService._internal();
  factory MockDataService() => _instance;
  MockDataService._internal();

  final AuthService _authService = AuthService();

  // Initialize production system
  Future<void> initializeMockData() async {
    print('🚀 STOK YÖNETİM SİSTEMİ BAŞLATILIYOR...');
    print('📦 Production mode - Gerçek kullanıcılar kayıt olabilir');
    print('✅ Sistem başarıyla başlatıldı!');
  }
} 