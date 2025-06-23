import 'dart:math';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/subscription.dart';
import '../models/user.dart';
import 'email_service.dart';
import 'firebase_service.dart';

class SubscriptionService {
  static final SubscriptionService _instance = SubscriptionService._internal();
  factory SubscriptionService() => _instance;
  SubscriptionService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final firebase_auth.FirebaseAuth _auth = firebase_auth.FirebaseAuth.instance;
  final EmailService _emailService = EmailService();

  // Admin email - size aktivasyon kodları gönderilecek
  static const String adminEmail = 'msakkaya.02@gmail.com';

  // Current user bilgisi (Firebase tabanlı)
  firebase_auth.User? get currentUser => _auth.currentUser;
  bool get isLoggedIn => _auth.currentUser != null;

  // Kullanıcının abonelik bilgilerini getir (Firebase'den)
  Future<Subscription?> getUserSubscription() async {
    try {
      final user = currentUser;
      if (user == null) return null;

      // Organizasyon ID'sini al
      final organizationId = await FirebaseService.getCurrentUserOrganizationId();
      if (organizationId == null) return null;

      print('🔍 Abonelik bilgisi alınıyor - Org ID: $organizationId');

      final subscriptionDoc = await _firestore
          .collection('organizations')
          .doc(organizationId)
          .collection('subscriptions')
          .doc('current')
          .get();

      if (subscriptionDoc.exists) {
        final data = subscriptionDoc.data()!;
        print('✅ Abonelik bilgisi bulundu: $data');
        return Subscription.fromFirebaseMap(data, organizationId);
      } else {
        print('ℹ️ Abonelik bilgisi bulunamadı, yeni oluşturulacak');
        return null;
      }
    } catch (e) {
      print('❌ Abonelik bilgisi alınırken hata: $e');
      return null;
    }
  }

  // Yeni kullanıcı için abonelik oluştur (Firebase'de)
  Future<Subscription> createSubscriptionForUser() async {
    try {
      final user = currentUser;
      if (user == null) throw Exception('Kullanıcı giriş yapmamış');

      final organizationId = await FirebaseService.getCurrentUserOrganizationId();
      if (organizationId == null) throw Exception('Organizasyon ID bulunamadı');

      print('📝 Yeni abonelik oluşturuluyor - Org ID: $organizationId');

      final now = DateTime.now();
      final subscriptionData = {
        'organizationId': organizationId,
        'isPremium': false,
        'premiumActivatedAt': null,
        'premiumExpiresAt': null,
        'currentActivationCode': null,
        'lastCodeRequestAt': null,
        'totalActivations': 0,
        'createdAt': Timestamp.fromDate(now),
        'updatedAt': Timestamp.fromDate(now),
      };

      await _firestore
          .collection('organizations')
          .doc(organizationId)
          .collection('subscriptions')
          .doc('current')
          .set(subscriptionData);

      print('✅ Yeni abonelik oluşturuldu');
      return Subscription.fromFirebaseMap(subscriptionData, organizationId);
    } catch (e) {
      print('❌ Abonelik oluşturulurken hata: $e');
      throw Exception('Abonelik oluşturulamadı: $e');
    }
  }

  // Rastgele aktivasyon kodu üret
  String _generateActivationCode() {
    final random = Random();
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString().substring(8);
    final randomPart = (random.nextInt(9000) + 1000).toString();
    final code = 'STOK-$timestamp-$randomPart';
    
    // Checksum ekle
    final bytes = utf8.encode(code);
    final digest = sha256.convert(bytes);
    final checksum = digest.toString().substring(0, 4).toUpperCase();
    
    return '$code-$checksum';
  }

  // Aktivasyon kodu talep et (Firebase tabanlı)
  Future<Map<String, dynamic>> requestActivationCode() async {
    try {
      final user = currentUser;
      if (user == null) {
        return {'success': false, 'message': 'Kullanıcı girişi yapılmamış'};
      }

      print('🔑 Aktivasyon kodu talebi başlatılıyor...');

      // Kullanıcının abonelik bilgilerini getir
      Subscription? subscription = await getUserSubscription();
      
      if (subscription == null) {
        // İlk kez abonelik oluştur
        subscription = await createSubscriptionForUser();
      }

      // Premium bitimine 1 günden az kaldıysa kod talep edilemez
      if (!subscription.canRequestActivationCode) {
        final remainingHours = subscription.remainingHoursToExpiry;
        return {
          'success': false, 
          'message': 'Premium sürenizin bitmesine ${remainingHours} saat kaldı. Yeni aktivasyon kodu premium sürenizin son 24 saatinde talep edilemez.'
        };
      }

      // Son kod talebinden bu yana 24 saat geçmiş mi kontrol et
      if (subscription.lastCodeRequestAt != null) {
        final hoursSinceLastRequest = DateTime.now()
            .difference(subscription.lastCodeRequestAt!)
            .inHours;
        
        if (hoursSinceLastRequest < 24) {
          return {
            'success': false, 
            'message': 'Kod talebi için 24 saat beklemeniz gerekiyor. Kalan süre: ${24 - hoursSinceLastRequest} saat'
          };
        }
      }

      // Yeni aktivasyon kodu üret
      final activationCode = _generateActivationCode();
      
      print('🔑 Aktivasyon kodu üretildi: $activationCode');

      // Subscription'ı güncelle (Firebase'de)
      final organizationId = await FirebaseService.getCurrentUserOrganizationId();
      if (organizationId == null) throw Exception('Organizasyon ID bulunamadı');

      final now = DateTime.now();
      await _firestore
          .collection('organizations')
          .doc(organizationId)
          .collection('subscriptions')
          .doc('current')
          .update({
        'currentActivationCode': activationCode,
        'lastCodeRequestAt': Timestamp.fromDate(now),
        'updatedAt': Timestamp.fromDate(now),
      });

      print('✅ Abonelik güncellendi');

      // Organizasyon bilgilerini al
      final orgDoc = await _firestore
          .collection('organizations')
          .doc(organizationId)
          .get();

      if (!orgDoc.exists) {
        throw Exception('Organizasyon bilgisi bulunamadı');
      }

      final orgData = orgDoc.data()!;

      // Size (admin) email gönder
      final emailSent = await _sendActivationCodeToAdmin(
        organizationData: orgData,
        organizationId: organizationId,
        activationCode: activationCode,
        subscription: subscription,
      );

      if (!emailSent) {
        return {
          'success': false,
          'message': 'Aktivasyon kodu oluşturuldu ancak email gönderilemedi. Lütfen tekrar deneyin.'
        };
      }

      return {
        'success': true,
        'message': 'Aktivasyon kodu talebi gönderildi! Ödeme yaptıktan sonra kodu size ileteceğiz.',
        'code': activationCode, // Debug için - production'da kaldırın
      };

    } catch (e) {
      print('❌ Aktivasyon kodu talebi hatası: $e');
      return {'success': false, 'message': 'Hata: $e'};
    }
  }

  // Aktivasyon kodunu doğrula ve premium aktive et (Firebase tabanlı)
  Future<Map<String, dynamic>> activatePremium(String inputCode) async {
    try {
      final user = currentUser;
      if (user == null) {
        return {'success': false, 'message': 'Kullanıcı girişi yapılmamış'};
      }

      print('🔓 Premium aktivasyon başlatılıyor...');

      final subscription = await getUserSubscription();
      if (subscription == null) {
        return {'success': false, 'message': 'Abonelik bilgisi bulunamadı'};
      }

      // Kod doğrulaması
      if (subscription.currentActivationCode != inputCode.trim().toUpperCase()) {
        return {'success': false, 'message': 'Geçersiz aktivasyon kodu'};
      }

      // Premium süresini hesapla (30 gün)
      final now = DateTime.now();
      final expiryDate = now.add(const Duration(days: 30));

      // Subscription'ı güncelle (Firebase'de)
      final organizationId = await FirebaseService.getCurrentUserOrganizationId();
      if (organizationId == null) throw Exception('Organizasyon ID bulunamadı');

      await _firestore
          .collection('organizations')
          .doc(organizationId)
          .collection('subscriptions')
          .doc('current')
          .update({
        'isPremium': true,
        'premiumActivatedAt': Timestamp.fromDate(now),
        'premiumExpiresAt': Timestamp.fromDate(expiryDate),
        'totalActivations': subscription.totalActivations + 1,
        'currentActivationCode': null, // Kod kullanıldı, temizle
        'updatedAt': Timestamp.fromDate(now),
      });

      print('✅ Premium aktivasyon tamamlandı');

      return {
        'success': true,
        'message': 'Premium aktivasyonu başarılı! 30 günlük premium erişiminiz başladı.',
      };

    } catch (e) {
      print('❌ Premium aktivasyon hatası: $e');
      return {'success': false, 'message': 'Aktivasyon hatası: $e'};
    }
  }

  // Admin'e (size) aktivasyon kodu email'i gönder (Firebase tabanlı)
  Future<bool> _sendActivationCodeToAdmin({
    required Map<String, dynamic> organizationData,
    required String organizationId,
    required String activationCode,
    required Subscription subscription,
  }) async {
    try {
      final emailContent = _getActivationCodeAdminEmailTemplate(
        organizationData: organizationData,
        organizationId: organizationId,
        activationCode: activationCode,
        subscription: subscription,
      );

      // Email service'inizin send metodunu kullan
      return await _emailService.sendCustomEmail(
        recipientEmail: adminEmail,
        subject: '🔑 Stoker - Yeni Aktivasyon Kodu Talebi',
        htmlContent: emailContent,
      );

    } catch (e) {
      print('❌ Admin email gönderme hatası: $e');
      return false;
    }
  }

  // Admin email template'i (Firebase tabanlı)
  String _getActivationCodeAdminEmailTemplate({
    required Map<String, dynamic> organizationData,
    required String organizationId,
    required String activationCode,
    required Subscription subscription,
  }) {
    final orgName = organizationData['name'] ?? 'Bilinmeyen Organizasyon';
    final orgEmail = organizationData['email'] ?? 'Bilinmeyen Email';
    final orgPhone = organizationData['phone'] ?? 'Belirtilmemiş';
    final createdAt = organizationData['createdAt'] as Timestamp?;
    final createdDate = createdAt?.toDate() ?? DateTime.now();

    return '''
    <!DOCTYPE html>
    <html>
    <head>
        <meta charset="UTF-8">
        <title>Stoker - Aktivasyon Kodu Talebi</title>
        <style>
            body { 
                font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, Cantarell, sans-serif; 
                line-height: 1.6; 
                color: #333;
                background-color: #f5f5f5;
                margin: 0;
                padding: 20px;
            }
            .container { 
                max-width: 600px; 
                margin: 0 auto; 
                background: white;
                border-radius: 12px;
                overflow: hidden;
                box-shadow: 0 4px 12px rgba(0,0,0,0.1);
            }
            .header { 
                background: linear-gradient(135deg, #2196F3 0%, #1976D2 100%); 
                color: white; 
                padding: 30px 20px; 
                text-align: center; 
            }
            .content { 
                padding: 30px; 
            }
            .user-info {
                background: #f8f9fa;
                border-radius: 8px;
                padding: 20px;
                margin: 20px 0;
            }
            .activation-code {
                background: #e3f2fd;
                border: 2px solid #2196F3;
                border-radius: 8px;
                padding: 20px;
                text-align: center;
                margin: 20px 0;
            }
            .code {
                font-size: 24px;
                font-weight: bold;
                color: #1976D2;
                font-family: 'Courier New', monospace;
                letter-spacing: 2px;
            }
            .stats {
                display: grid;
                grid-template-columns: 1fr 1fr;
                gap: 15px;
                margin: 20px 0;
            }
            .stat-box {
                background: #f8f9fa;
                padding: 15px;
                border-radius: 8px;
                text-align: center;
            }
            .warning {
                background: #fff3cd;
                border: 1px solid #ffeaa7;
                border-radius: 8px;
                padding: 15px;
                margin: 20px 0;
                color: #856404;
            }
        </style>
    </head>
    <body>
        <div class="container">
            <div class="header">
                <h2>🔑 Yeni Aktivasyon Kodu Talebi</h2>
                <p>Stoker Premium Aktivasyon</p>
            </div>
            
            <div class="content">
                <div class="user-info">
                    <h3>🏢 Organizasyon Bilgileri</h3>
                    <p><strong>Organizasyon Adı:</strong> $orgName</p>
                    <p><strong>Email:</strong> $orgEmail</p>
                    <p><strong>Telefon:</strong> $orgPhone</p>
                    <p><strong>Organizasyon ID:</strong> $organizationId</p>
                    <p><strong>Kayıt Tarihi:</strong> ${createdDate.day}/${createdDate.month}/${createdDate.year}</p>
                </div>

                <div class="activation-code">
                    <h3>🎫 Aktivasyon Kodu</h3>
                    <div class="code">$activationCode</div>
                    <p style="color: #666; font-size: 14px; margin-top: 10px;">
                        Bu kodu organizasyona ödeme alındıktan sonra iletin
                    </p>
                </div>

                <div class="stats">
                    <div class="stat-box">
                        <h4>📊 Toplam Aktivasyon</h4>
                        <p style="font-size: 24px; margin: 0; color: #2196F3;">${subscription.totalActivations}</p>
                    </div>
                    <div class="stat-box">
                        <h4>📅 Durum</h4>
                        <p style="font-size: 16px; margin: 0; color: ${subscription.isActive ? '#4CAF50' : '#FF5722'};">
                            ${subscription.isActive ? 'Aktif' : 'Pasif'}
                        </p>
                    </div>
                </div>

                ${subscription.totalActivations == 0 ? '''
                <div class="warning">
                    <strong>⚠️ İlk Aktivasyon</strong><br>
                    Bu organizasyonun ilk aktivasyon kodu talebi. Ödeme alındıktan sonra yukarıdaki kodu iletin.
                </div>
                ''' : ''}

                <div style="margin-top: 30px; padding-top: 20px; border-top: 1px solid #eee; color: #666; font-size: 12px;">
                    <p>Bu email otomatik olarak oluşturulmuştur.</p>
                    <p>Talep Tarihi: ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year} ${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')}</p>
                </div>
            </div>
        </div>
    </body>
    </html>
    ''';
  }

  // Kullanıcının premium durumunu kontrol et
  Future<bool> isUserPremium() async {
    final subscription = await getUserSubscription();
    return subscription?.isActive ?? false;
  }

  // Kullanıcının paid user olup olmadığını kontrol et (yedek yükleme için)
  Future<bool> isPaidUser() async {
    final subscription = await getUserSubscription();
    return subscription?.isPaidUser ?? false;
  }

  // Premium süresini uzat (manuel kullanım için)
  Future<Map<String, dynamic>> extendPremium(int days) async {
    try {
      final user = currentUser;
      if (user == null) {
        return {'success': false, 'message': 'Oturum açmanız gerekli'};
      }

      final organizationId = await FirebaseService.getCurrentUserOrganizationId();
      if (organizationId == null) {
        return {'success': false, 'message': 'Organizasyon ID bulunamadı'};
      }

      final subscription = await getUserSubscription();
      if (subscription == null) {
        return {'success': false, 'message': 'Abonelik bulunamadı'};
      }

      final now = DateTime.now();
      final currentExpiry = subscription.premiumExpiresAt ?? now;
      final newExpiry = currentExpiry.isAfter(now) 
          ? currentExpiry.add(Duration(days: days))
          : now.add(Duration(days: days));

      await _firestore
          .collection('organizations')
          .doc(organizationId)
          .collection('subscriptions')
          .doc('current')
          .update({
        'isPremium': true,
        'premiumExpiresAt': Timestamp.fromDate(newExpiry),
        'updatedAt': Timestamp.fromDate(now),
      });

      return {
        'success': true,
        'message': 'Premium süre $days gün uzatıldı',
      };

    } catch (e) {
      return {'success': false, 'message': 'Hata: $e'};
    }
  }
} 