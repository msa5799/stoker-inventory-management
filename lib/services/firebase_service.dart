import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';

class FirebaseService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Firestore instance getter for other services
  static FirebaseFirestore get firestore => _firestore;
  
  // Firebase offline persistence'ı etkinleştir
  static bool _persistenceEnabled = false;
  
  /// Firebase offline persistence'ı etkinleştir
  static Future<void> enableOfflinePersistence() async {
    if (!_persistenceEnabled) {
      try {
        await _firestore.enablePersistence(
          const PersistenceSettings(synchronizeTabs: true),
        );
        _persistenceEnabled = true;
        print('✅ Firebase offline persistence etkinleştirildi');
      } catch (e) {
        print('⚠️ Firebase offline persistence zaten etkin veya hata: $e');
      }
    }
  }
  
  /// Firebase bağlantı durumunu kontrol et
  static Future<bool> checkConnection() async {
    try {
      await _firestore.collection('test').limit(1).get();
      return true;
    } catch (e) {
      print('❌ Firebase bağlantı hatası: $e');
      return false;
    }
  }
  
  // Current user organizasyon ID'si
  static String? get currentOrganizationId {
    final user = _auth.currentUser;
    if (user == null) return null;
    
    // Organizasyon yöneticisi için UID'si organizasyon ID'sidir
    // Internal user için organizationId field'ından alınmalı
    // Bu sync bir getter olduğu için async işlem yapamayız
    // Bu nedenle bu metod sadece organizasyon yöneticileri için çalışır
    // Internal user'lar için ayrı bir metod kullanmalıyız
    return user.uid;
  }
  
  // Current user bilgisi
  static User? get currentUser => _auth.currentUser;
  
  // Current user email (güvenli)
  static String? get currentUserEmail => _auth.currentUser?.email;
  
  // Current user UID (güvenli)
  static String? get currentUserUid => _auth.currentUser?.uid;
  
  // Kurumsal kullanıcı kayıt
  static Future<Map<String, dynamic>> registerOrganization({
    required String email,
    required String password,
    required String organizationName,
  }) async {
    try {
      print('🔥 Firebase kayıt başlatılıyor...');
      print('📧 Email: $email');
      print('🏢 Organizasyon: $organizationName');
      
      // Firebase Auth ile kayıt
      final UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      print('✅ Firebase Auth kayıt başarılı: ${result.user?.uid}');

      // Firestore'a organizasyon kaydı
      final orgData = {
        'name': organizationName,
        'email': email,
        'createdAt': FieldValue.serverTimestamp(),
        'isActive': true,
        'subscription': 'free',
        'userCount': 0,
      };
      
      print('📝 Firestore\'a organizasyon kaydediliyor...');
      await _firestore.collection('organizations').doc(result.user!.uid).set(orgData);
      print('✅ Firestore kayıt başarılı');

      return {
        'success': true,
        'user': result.user,
        'userType': 'organization',
        'message': 'Organizasyon başarıyla oluşturuldu'
      };
    } catch (e) {
      print('❌ Firebase kayıt hatası: $e');
      print('❌ Hata tipi: ${e.runtimeType}');
      if (e is FirebaseException) {
        print('❌ Firebase kod: ${e.code}');
        print('❌ Firebase mesaj: ${e.message}');
      }
      return {
        'success': false,
        'message': _getErrorMessage(e.toString())
      };
    }
  }

  // Email doğrulamalı organizasyon kayıt (Email servisi ile)
  static Future<Map<String, dynamic>> createOrganizationWithEmailVerification({
    required String email,
    required String password,
    required String organizationName,
    String? phone,
    String? address,
  }) async {
    try {
      print('🔥 Email doğrulamalı organizasyon kayıt başlatılıyor...');
      print('📧 Email: $email');
      print('🏢 Organizasyon: $organizationName');
      
      // Verification code generate et
      final verificationCode = generateVerificationCode();
      print('🔐 Doğrulama kodu: $verificationCode');

      // Firebase Auth ile kayıt
      final UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      print('✅ Firebase Auth kayıt başarılı: ${result.user?.uid}');

      // Firestore'a organizasyon kaydı (email doğrulanmamış olarak)
      final orgData = {
        'name': organizationName,
        'email': email,
        'phone': phone ?? '',
        'address': address ?? '',
        'createdAt': FieldValue.serverTimestamp(),
        'isActive': false, // Email doğrulanana kadar aktif değil
        'isEmailVerified': false,
        'verificationCode': verificationCode,
        'subscription': 'free',
        'userCount': 0,
      };
      
      print('📝 Firestore\'a organizasyon kaydediliyor...');
      await _firestore.collection('organizations').doc(result.user!.uid).set(orgData);
      print('✅ Firestore kayıt başarılı');

      // Firebase Auth'da email doğrulanmamış olarak işaretle
      await result.user!.sendEmailVerification();

      return {
        'success': true,
        'user': result.user,
        'userType': 'organization',
        'verificationCode': verificationCode,
        'message': 'Organizasyon oluşturuldu. Email doğrulaması gerekli.'
      };
    } catch (e) {
      print('❌ Email doğrulamalı Firebase kayıt hatası: $e');
      print('❌ Hata tipi: ${e.runtimeType}');
      if (e is FirebaseException) {
        print('❌ Firebase kod: ${e.code}');
        print('❌ Firebase mesaj: ${e.message}');
      }
      return {
        'success': false,
        'message': _getErrorMessage(e.toString())
      };
    }
  }

  // Email doğrulama (Organizasyon için)
  static Future<Map<String, dynamic>> verifyOrganizationEmail({
    required String email,
    required String verificationCode,
  }) async {
    try {
      print('🔐 Organizasyon email doğrulaması başlatılıyor...');
      print('📧 Email: $email');
      print('🔐 Kod: $verificationCode');

      // Firestore'da organizasyonu bul
      final orgQuery = await _firestore
          .collection('organizations')
          .where('email', isEqualTo: email)
          .where('verificationCode', isEqualTo: verificationCode)
          .limit(1)
          .get();

      if (orgQuery.docs.isEmpty) {
        return {
          'success': false,
          'message': 'Doğrulama kodu hatalı veya süresi dolmuş'
        };
      }

      final orgDoc = orgQuery.docs.first;
      
      // Organizasyonu aktif hale getir
      await orgDoc.reference.update({
        'isActive': true,
        'isEmailVerified': true,
        'verificationCode': FieldValue.delete(),
        'verifiedAt': FieldValue.serverTimestamp(),
      });

      print('✅ Organizasyon email doğrulaması başarılı');

      return {
        'success': true,
        'message': 'Email başarıyla doğrulandı. Organizasyonunuz aktif edildi.'
      };
    } catch (e) {
      print('❌ Organizasyon email doğrulama hatası: $e');
      return {
        'success': false,
        'message': 'Email doğrulama sırasında hata oluştu'
      };
    }
  }

  // Verification code generator
  static String generateVerificationCode() {
    final random = DateTime.now().millisecondsSinceEpoch;
    return (100000 + (random % 900000)).toString();
  }

  // Kurumsal kullanıcı giriş
  static Future<Map<String, dynamic>> organizationLogin({
    required String email,
    required String password,
  }) async {
    try {
      print('🔐 Organizasyon girişi başlatılıyor...');
      print('📧 Email: $email');
      
      final UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      print('✅ Firebase Auth giriş başarılı: ${result.user?.uid}');

      // Organizasyon bilgilerini al
      final orgDoc = await _firestore
          .collection('organizations')
          .doc(result.user!.uid)
          .get();

      print('📄 Organizasyon dokümanı kontrol ediliyor...');
      print('📄 Doküman var mı: ${orgDoc.exists}');
      
      if (orgDoc.exists) {
        final orgData = orgDoc.data();
        print('📄 Organizasyon verisi: $orgData');
        
        if (orgData != null && orgData['isActive'] == true) {
          print('✅ Organizasyon aktif, giriş başarılı');
          return {
            'success': true,
            'user': result.user,
            'orgData': orgData,
            'userType': 'organization',
            'message': 'Giriş başarılı'
          };
        } else {
          print('❌ Organizasyon aktif değil veya veri null');
          return {
            'success': false,
            'message': 'Organizasyon aktif değil'
          };
        }
      }

      print('❌ Organizasyon dokümanı bulunamadı');
      return {
        'success': false,
        'message': 'Organizasyon bulunamadı'
      };
    } catch (e) {
      print('❌ Organizasyon giriş hatası: $e');
      return {
        'success': false,
        'message': _getErrorMessage(e.toString())
      };
    }
  }

  // İç kullanıcı oluştur (Yeni Firebase Auth sistemi)
  static Future<Map<String, dynamic>> createInternalUser({
    required String organizationId,
    required String username,
    required String password,
    required String displayName,
    required String role,
  }) async {
    try {
      print('🔥 İç kullanıcı oluşturuluyor...');
      print('📧 Username: $username');
      print('👤 Display Name: $displayName');
      print('🏢 Organization ID: $organizationId');

      // Önce organizasyonun var olduğunu kontrol et
      final orgDoc = await _firestore
          .collection('organizations')
          .doc(organizationId)
          .get();

      if (!orgDoc.exists) {
        return {
          'success': false,
          'message': 'Organizasyon bulunamadı'
        };
      }

      // Aynı organizasyonda aynı username var mı kontrol et
      final existingUserQuery = await _firestore
          .collection('organizations')
          .doc(organizationId)
          .collection('internal_users')
          .where('username', isEqualTo: username)
          .get();

      if (existingUserQuery.docs.isNotEmpty) {
        return {
          'success': false,
          'message': 'Bu kullanıcı adı zaten kullanılıyor'
        };
      }

      // Geçici email oluştur (internal user için)
      final tempEmail = '${username}_${organizationId}@internal.stoker.app';
      
      print('📧 Geçici email: $tempEmail');

      // Firebase Auth'da kullanıcı oluştur
      final UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: tempEmail,
        password: password,
      );

      print('✅ Firebase Auth kullanıcı oluşturuldu: ${userCredential.user?.uid}');

      // Firestore'da internal user bilgilerini kaydet
      await _firestore
          .collection('organizations')
          .doc(organizationId)
          .collection('internal_users')
          .doc(userCredential.user!.uid)
          .set({
        'username': username,
        'fullName': displayName,
        'role': role,
        'organizationId': organizationId,
        'isActive': true,
        'createdAt': FieldValue.serverTimestamp(),
        'lastLogin': null,
        'phone': '',
        'permissions': _getDefaultPermissions(role),
      });

      print('✅ Firestore internal user kaydı oluşturuldu');

      return {
        'success': true,
        'userId': userCredential.user!.uid,
        'message': 'Kullanıcı başarıyla oluşturuldu'
      };
    } catch (e) {
      print('❌ İç kullanıcı oluşturulurken hata: $e');
      return {
        'success': false,
        'message': _getErrorMessage(e.toString())
      };
    }
  }

  // Rol bazlı varsayılan izinler
  static Map<String, bool> _getDefaultPermissions(String role) {
    switch (role) {
      case 'manager':
        return {
          'canAddProduct': true,
          'canEditProduct': true,
          'canDeleteProduct': true,
          'canViewReports': true,
          'canManageUsers': false, // Sadece organizasyon sahibi
        };
      case 'employee':
      default:
        return {
          'canAddProduct': true,
          'canEditProduct': false,
          'canDeleteProduct': false,
          'canViewReports': false,
          'canManageUsers': false,
        };
    }
  }

  // İç kullanıcı giriş (Organizasyon kodu olmadan - Yeni sistem)
  static Future<Map<String, dynamic>> internalUserLoginWithoutOrgCode({
    required String username,
    required String password,
  }) async {
    try {
      print('🔐 İç kullanıcı girişi başlatılıyor (org kodu yok)...');
      print('👤 Username: $username');

      // Tüm organizasyonları tarayıp kullanıcıyı bul
      final orgsSnapshot = await _firestore.collection('organizations').get();
      
      Map<String, dynamic>? foundUser;
      String? foundOrgId;
      String? foundUserId;
      
      for (var orgDoc in orgsSnapshot.docs) {
        final orgId = orgDoc.id;
        print('🔍 Organizasyon taranıyor: $orgId');
        
        // Bu organizasyonda kullanıcıyı ara
        final userQuery = await _firestore
            .collection('organizations')
            .doc(orgId)
            .collection('internal_users')
            .where('username', isEqualTo: username)
            .where('isActive', isEqualTo: true)
            .get();

        if (userQuery.docs.isNotEmpty) {
          foundUser = userQuery.docs.first.data();
          foundOrgId = orgId;
          foundUserId = userQuery.docs.first.id;
          print('✅ Kullanıcı bulundu! Org: $orgId, User: $foundUserId');
          break;
        }
      }

      if (foundUser == null || foundOrgId == null || foundUserId == null) {
        return {
          'success': false,
          'message': 'Kullanıcı bulunamadı veya aktif değil'
        };
      }

      // Geçici email ile Firebase Auth giriş yap
      final tempEmail = '${username}_${foundOrgId}@internal.stoker.app';
      
      final UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: tempEmail,
        password: password,
      );

      print('✅ Firebase Auth giriş başarılı: ${userCredential.user?.uid}');

      // Son giriş zamanını güncelle
      await _firestore
          .collection('organizations')
          .doc(foundOrgId)
          .collection('internal_users')
          .doc(foundUserId)
          .update({
        'lastLogin': FieldValue.serverTimestamp(),
      });

      // Organizasyon bilgilerini al
      final orgDoc = await _firestore
          .collection('organizations')
          .doc(foundOrgId)
          .get();

      return {
        'success': true,
        'userId': foundUserId,
        'userData': foundUser,
        'orgData': orgDoc.data(),
        'organizationId': foundOrgId,
        'userType': 'internal',
        'message': 'Giriş başarılı'
      };
    } catch (e) {
      print('❌ İç kullanıcı girişi hatası: $e');
      return {
        'success': false,
        'message': _getErrorMessage(e.toString())
      };
    }
  }

  // İç kullanıcı giriş (Yeni sistem)
  static Future<Map<String, dynamic>> internalUserLogin({
    required String username,
    required String password,
    String? organizationId,
  }) async {
    // Eğer organizationId verilmemişse, hata döndür
    if (organizationId == null || organizationId.trim().isEmpty) {
      return {
        'success': false,
        'message': 'Organizasyon kodu gerekli'
      };
    }
    
    try {
      print('🔐 İç kullanıcı girişi başlatılıyor...');
      print('👤 Username: $username');
      print('🏢 Organization ID: $organizationId');

      // Önce geçici email ile Firebase Auth giriş yapmayı dene
      final tempEmail = '${username}_${organizationId}@internal.stoker.app';
      
      print('📧 Geçici email ile giriş deneniyor: $tempEmail');
      
      final UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: tempEmail,
        password: password,
      );

      print('✅ Firebase Auth giriş başarılı: ${userCredential.user?.uid}');

      // Şimdi kullanıcı bilgilerini al (artık authenticated olduğumuz için erişebiliriz)
      final userDoc = await _firestore
          .collection('organizations')
          .doc(organizationId)
          .collection('internal_users')
          .doc(userCredential.user!.uid)
          .get();

      if (!userDoc.exists) {
        // Kullanıcı dokümanı bulunamadı, çıkış yap
        await _auth.signOut();
        return {
          'success': false,
          'message': 'Kullanıcı bilgileri bulunamadı'
        };
      }

      final userData = userDoc.data()!;
      
      // Kullanıcı aktif mi kontrol et
      if (userData['isActive'] != true) {
        await _auth.signOut();
        return {
          'success': false,
          'message': 'Kullanıcı hesabı devre dışı'
        };
      }

      // Son giriş zamanını güncelle
      await _firestore
          .collection('organizations')
          .doc(organizationId)
          .collection('internal_users')
          .doc(userCredential.user!.uid)
          .update({
        'lastLogin': FieldValue.serverTimestamp(),
      });

      // Organizasyon bilgilerini al
      final orgDoc = await _firestore
          .collection('organizations')
          .doc(organizationId)
          .get();

      return {
        'success': true,
        'userId': userCredential.user!.uid,
        'userData': userData,
        'orgData': orgDoc.data(),
        'organizationId': organizationId,
        'userType': 'internal',
        'message': 'Giriş başarılı'
      };
    } catch (e) {
      print('❌ İç kullanıcı girişi hatası: $e');
      
      // Firebase Auth hatalarını kontrol et
      if (e.toString().contains('user-not-found') || e.toString().contains('wrong-password')) {
        return {
          'success': false,
          'message': 'Kullanıcı adı, şifre veya organizasyon kodu hatalı'
        };
      }
      
      return {
        'success': false,
        'message': _getErrorMessage(e.toString())
      };
    }
  }

  // Organizasyona ait kullanıcıları getir (Index hatası düzeltildi)
  static Future<List<Map<String, dynamic>>> getInternalUsers(String organizationId) async {
    try {
      print('📋 İç kullanıcılar yükleniyor: $organizationId');
      
      final snapshot = await _firestore
          .collection('organizations')
          .doc(organizationId)
          .collection('internal_users')
          .get(); // orderBy kaldırıldı - index hatası önlendi

      final users = snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();

      // Client-side sorting (createdAt varsa)
      users.sort((a, b) {
        final aTime = a['createdAt'] as Timestamp?;
        final bTime = b['createdAt'] as Timestamp?;
        
        if (aTime == null && bTime == null) return 0;
        if (aTime == null) return 1;
        if (bTime == null) return -1;
        
        return bTime.compareTo(aTime); // Yeniden eskiye
      });

      print('✅ ${users.length} kullanıcı yüklendi');
      return users;
    } catch (e) {
      print('❌ Kullanıcılar yüklenirken hata: $e');
      throw Exception('Kullanıcılar yüklenirken hata: $e');
    }
  }

  // Kullanıcı durumunu değiştir (Yeni sistem)
  static Future<Map<String, dynamic>> toggleUserStatus(String userId, bool isActive) async {
    try {
      // Önce kullanıcının hangi organizasyona ait olduğunu bul
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        return {
          'success': false,
          'message': 'Oturum açmanız gerekli'
        };
      }

      // Organizasyon ID'sini al (current user'ın UID'si)
      final organizationId = currentUser.uid;

      await _firestore
          .collection('organizations')
          .doc(organizationId)
          .collection('internal_users')
          .doc(userId)
          .update({
        'isActive': isActive,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      return {
        'success': true,
        'message': 'Kullanıcı durumu güncellendi'
      };
    } catch (e) {
      return {
        'success': false,
        'message': _getErrorMessage(e.toString())
      };
    }
  }

  // Kullanıcı şifresini güncelle
  static Future<Map<String, dynamic>> updateUserPassword({
    required String userId,
    required String newPassword,
  }) async {
    try {
      final hashedPassword = _hashPassword(newPassword);
      
      await _firestore.collection('internalUsers').doc(userId).update({
        'passwordHash': hashedPassword,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      return {
        'success': true,
        'message': 'Şifre başarıyla güncellendi'
      };
    } catch (e) {
      return {
        'success': false,
        'message': _getErrorMessage(e.toString())
      };
    }
  }

  // Şifre hashleme
  static String _hashPassword(String password) {
    final bytes = utf8.encode(password);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  // Hata mesajlarını Türkçeleştir
  static String _getErrorMessage(String errorCode) {
    print('🔍 Hata kodu analiz ediliyor: $errorCode');
    
    if (errorCode.contains('user-not-found')) {
      return 'Kullanıcı bulunamadı';
    } else if (errorCode.contains('wrong-password')) {
      return 'Geçersiz şifre';
    } else if (errorCode.contains('email-already-in-use')) {
      return 'Bu e-posta adresi zaten kullanılıyor';
    } else if (errorCode.contains('weak-password')) {
      return 'Şifre çok zayıf (en az 6 karakter)';
    } else if (errorCode.contains('invalid-email')) {
      return 'Geçersiz e-posta adresi';
    } else if (errorCode.contains('network-request-failed')) {
      return 'İnternet bağlantısı hatası';
    } else if (errorCode.contains('permission-denied')) {
      return 'Erişim izni reddedildi. Lütfen tekrar deneyin.';
    } else if (errorCode.contains('unavailable')) {
      return 'Firebase servisi şu anda kullanılamıyor. Lütfen tekrar deneyin.';
    } else {
      return 'Detaylı hata: $errorCode';
    }
  }

  // Logout
  static Future<void> logout() async {
    await _auth.signOut();
  }

  // Session kontrol
  static bool get isLoggedIn => _auth.currentUser != null;

  // Auth state değişikliklerini dinle
  static Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Internal user'ın organizasyon ID'sini al
  static Future<String?> getCurrentUserOrganizationId() async {
    final user = _auth.currentUser;
    if (user == null) return null;
    
    try {
      // Önce organizasyon yöneticisi mi kontrol et
      final orgDoc = await _firestore
          .collection('organizations')
          .doc(user.uid)
          .get();
      
      if (orgDoc.exists) {
        // Organizasyon yöneticisi - UID'si organizasyon ID'si
        return user.uid;
      }
      
      // Internal user olabilir - tüm organizasyonlarda ara
      final orgsSnapshot = await _firestore.collection('organizations').get();
      
      for (var orgDoc in orgsSnapshot.docs) {
        final internalUserDoc = await _firestore
            .collection('organizations')
            .doc(orgDoc.id)
            .collection('internal_users')
            .doc(user.uid)
            .get();
        
        if (internalUserDoc.exists) {
          // Internal user bulundu - organizasyon ID'sini döndür
          return orgDoc.id;
        }
      }
      
      return null;
    } catch (e) {
      print('❌ Organizasyon ID alınırken hata: $e');
      return null;
    }
  }

  // ==================== PRODUCT OPERATIONS ====================
  
  // Ürün ekle
  static Future<Map<String, dynamic>> addProduct(Map<String, dynamic> productData) async {
    try {
      final organizationId = await getCurrentUserOrganizationId();
      if (organizationId == null) {
        return {'success': false, 'message': 'Organizasyon bulunamadı'};
      }

      // Barkod kontrolü
      if (productData['barcode'] != null && productData['barcode'].toString().isNotEmpty) {
        final existingProduct = await getProductByBarcode(productData['barcode']);
        if (existingProduct != null) {
          return {'success': false, 'message': 'Bu barkod zaten kullanılıyor'};
        }
      }

      // SKU kontrolü
      final existingSku = await _firestore
          .collection('organizations')
          .doc(organizationId)
          .collection('products')
          .where('sku', isEqualTo: productData['sku'])
          .get();

      if (existingSku.docs.isNotEmpty) {
        return {'success': false, 'message': 'Bu SKU zaten kullanılıyor'};
      }

      productData['createdAt'] = FieldValue.serverTimestamp();
      productData['updatedAt'] = FieldValue.serverTimestamp();

      final docRef = await _firestore
          .collection('organizations')
          .doc(organizationId)
          .collection('products')
          .add(productData);

      return {'success': true, 'productId': docRef.id, 'message': 'Ürün başarıyla eklendi'};
    } catch (e) {
      print('❌ Ürün ekleme hatası: $e');
      return {'success': false, 'message': _getErrorMessage(e.toString())};
    }
  }

  // Tüm ürünleri getir
  static Future<List<Map<String, dynamic>>> getProducts() async {
    try {
      final organizationId = await getCurrentUserOrganizationId();
      if (organizationId == null) return [];

      final snapshot = await _firestore
          .collection('organizations')
          .doc(organizationId)
          .collection('products')
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    } catch (e) {
      print('❌ Ürünler yüklenirken hata: $e');
      return [];
    }
  }

  // Ürün getir (ID ile)
  static Future<Map<String, dynamic>?> getProduct(String productId) async {
    try {
      final organizationId = await getCurrentUserOrganizationId();
      if (organizationId == null) return null;

      final doc = await _firestore
          .collection('organizations')
          .doc(organizationId)
          .collection('products')
          .doc(productId)
          .get();

      if (doc.exists) {
        final data = doc.data()!;
        data['id'] = doc.id;
        return data;
      }
      return null;
    } catch (e) {
      print('❌ Ürün yüklenirken hata: $e');
      return null;
    }
  }

  // Barkod ile ürün getir
  static Future<Map<String, dynamic>?> getProductByBarcode(String barcode) async {
    try {
      final organizationId = await getCurrentUserOrganizationId();
      if (organizationId == null) return null;

      final snapshot = await _firestore
          .collection('organizations')
          .doc(organizationId)
          .collection('products')
          .where('barcode', isEqualTo: barcode)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        final data = snapshot.docs.first.data();
        data['id'] = snapshot.docs.first.id;
        return data;
      }
      return null;
    } catch (e) {
      print('❌ Barkod ile ürün arama hatası: $e');
      return null;
    }
  }

  // Ürün güncelle
  static Future<Map<String, dynamic>> updateProduct(String productId, Map<String, dynamic> productData) async {
    try {
      final organizationId = await getCurrentUserOrganizationId();
      if (organizationId == null) {
        return {'success': false, 'message': 'Organizasyon bulunamadı'};
      }

      productData['updatedAt'] = FieldValue.serverTimestamp();

      await _firestore
          .collection('organizations')
          .doc(organizationId)
          .collection('products')
          .doc(productId)
          .update(productData);

      return {'success': true, 'message': 'Ürün başarıyla güncellendi'};
    } catch (e) {
      print('❌ Ürün güncelleme hatası: $e');
      return {'success': false, 'message': _getErrorMessage(e.toString())};
    }
  }

  // Ürün sil
  static Future<Map<String, dynamic>> deleteProduct(String productId) async {
    try {
      final organizationId = await getCurrentUserOrganizationId();
      if (organizationId == null) {
        return {'success': false, 'message': 'Organizasyon bulunamadı'};
      }

      await _firestore
          .collection('organizations')
          .doc(organizationId)
          .collection('products')
          .doc(productId)
          .delete();

      return {'success': true, 'message': 'Ürün başarıyla silindi'};
    } catch (e) {
      print('❌ Ürün silme hatası: $e');
      return {'success': false, 'message': _getErrorMessage(e.toString())};
    }
  }

  // Ürün stok güncelle
  static Future<Map<String, dynamic>> updateProductStock(String productId, int newStock) async {
    try {
      final organizationId = await getCurrentUserOrganizationId();
      if (organizationId == null) {
        return {'success': false, 'message': 'Organizasyon bulunamadı'};
      }

      await _firestore
          .collection('organizations')
          .doc(organizationId)
          .collection('products')
          .doc(productId)
          .update({
        'current_stock': newStock,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      return {'success': true, 'message': 'Stok başarıyla güncellendi'};
    } catch (e) {
      print('❌ Stok güncelleme hatası: $e');
      return {'success': false, 'message': _getErrorMessage(e.toString())};
    }
  }

  // Düşük stoklu ürünleri getir
  static Future<List<Map<String, dynamic>>> getLowStockProducts() async {
    try {
      final organizationId = await getCurrentUserOrganizationId();
      if (organizationId == null) return [];

      final snapshot = await _firestore
          .collection('organizations')
          .doc(organizationId)
          .collection('products')
          .get();

      final lowStockProducts = <Map<String, dynamic>>[];
      
      for (var doc in snapshot.docs) {
        final data = doc.data();
        data['id'] = doc.id;
        
        final currentStock = data['current_stock'] ?? 0;
        final minStock = data['min_stock_level'] ?? 0;
        
        if (currentStock <= minStock) {
          lowStockProducts.add(data);
        }
      }

      return lowStockProducts;
    } catch (e) {
      print('❌ Düşük stoklu ürünler yüklenirken hata: $e');
      return [];
    }
  }

  // ==================== INVENTORY TRANSACTION OPERATIONS ====================
  
  // Envanter işlemi ekle
  static Future<Map<String, dynamic>> addInventoryTransaction(Map<String, dynamic> transactionData) async {
    try {
      final organizationId = await getCurrentUserOrganizationId();
      if (organizationId == null) {
        return {'success': false, 'message': 'Organizasyon bulunamadı'};
      }

      // Verileri güvenli hale getir
      final safeData = Map<String, dynamic>.from(transactionData);
      
      // product_id'yi string olarak kaydet (Firestore için)
      if (safeData['product_id'] is int) {
        safeData['product_id'] = safeData['product_id'].toString();
      }
      
      safeData['createdAt'] = FieldValue.serverTimestamp();

      final docRef = await _firestore
          .collection('organizations')
          .doc(organizationId)
          .collection('inventory_transactions')
          .add(safeData);

      return {'success': true, 'transactionId': docRef.id, 'message': 'İşlem başarıyla eklendi'};
    } catch (e) {
      print('❌ Envanter işlemi ekleme hatası: $e');
      return {'success': false, 'message': _getErrorMessage(e.toString())};
    }
  }

  // **TÜM ENVANTEr İŞLEMLERİNİ GETİR**
  static Future<List<Map<String, dynamic>>> getInventoryTransactions({
    List<String>? transactionTypes,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final organizationId = await getCurrentUserOrganizationId();
      if (organizationId == null) return [];

      Query query = _firestore
          .collection('organizations')
          .doc(organizationId)
          .collection('inventory_transactions')
          .orderBy('transaction_date', descending: true);

      // Transaction type filtresi
      if (transactionTypes != null && transactionTypes.isNotEmpty) {
        query = query.where('transaction_type', whereIn: transactionTypes);
      }

      // Tarih filtreleri
      if (startDate != null) {
        query = query.where('transaction_date', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate));
      }

      if (endDate != null) {
        query = query.where('transaction_date', isLessThanOrEqualTo: Timestamp.fromDate(endDate));
      }

      final snapshot = await query.get();
      
      final List<Map<String, dynamic>> transactions = [];
      
      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        transactions.add(data);
      }

      print('📊 ${transactions.length} envanter işlemi yüklendi (filtre: ${transactionTypes ?? "tümü"})');
      return transactions;
    } catch (e) {
      print('❌ Envanter işlemleri yüklenirken hata: $e');
      return [];
    }
  }

  // Satış işlemlerini getir
  static Future<List<Map<String, dynamic>>> getSalesTransactions({int limit = 100}) async {
    return getInventoryTransactions(transactionTypes: ['SALE']);
  }

  // Satın alma işlemlerini getir
  static Future<List<Map<String, dynamic>>> getPurchaseTransactions({int limit = 100}) async {
    return getInventoryTransactions(transactionTypes: ['PURCHASE']);
  }

  // ==================== STOCK LOT OPERATIONS ====================
  
  // Stok lot'u ekle
  static Future<Map<String, dynamic>> addStockLot(Map<String, dynamic> lotData) async {
    try {
      final organizationId = await getCurrentUserOrganizationId();
      if (organizationId == null) {
        return {'success': false, 'message': 'Organizasyon bulunamadı'};
      }

      // Verileri güvenli hale getir
      final safeData = Map<String, dynamic>.from(lotData);
      
      // product_id'yi string olarak kaydet (Firestore için)
      if (safeData['product_id'] is int) {
        safeData['product_id'] = safeData['product_id'].toString();
      }

      safeData['createdAt'] = FieldValue.serverTimestamp();

      final docRef = await _firestore
          .collection('organizations')
          .doc(organizationId)
          .collection('stock_lots')
          .add(safeData);

      return {'success': true, 'lotId': docRef.id, 'message': 'Lot başarıyla eklendi'};
    } catch (e) {
      print('❌ Stok lot ekleme hatası: $e');
      return {'success': false, 'message': _getErrorMessage(e.toString())};
    }
  }

  // Ürüne ait stok lot'larını getir
  static Future<List<Map<String, dynamic>>> getStockLots(String productId) async {
    try {
      print('🔍 Firebase getStockLots başlatılıyor - Product ID: $productId');
      
      final organizationId = await getCurrentUserOrganizationId();
      if (organizationId == null) {
        print('❌ Organizasyon ID bulunamadı');
        return [];
      }
      
      print('🏢 Organizasyon ID: $organizationId');

      // Önce tüm stock_lots koleksiyonunu kontrol et
      final allLotsSnapshot = await _firestore
          .collection('organizations')
          .doc(organizationId)
          .collection('stock_lots')
          .get();
      
      print('📊 Toplam lot sayısı (tüm ürünler): ${allLotsSnapshot.docs.length}');
      
      if (allLotsSnapshot.docs.isNotEmpty) {
        print('📋 İlk lot örneği: ${allLotsSnapshot.docs.first.data()}');
      }

      // Şimdi belirli ürün için sorgula
      final snapshot = await _firestore
          .collection('organizations')
          .doc(organizationId)
          .collection('stock_lots')
          .where('product_id', isEqualTo: productId)
          .get();

      print('📊 Bu ürün için bulunan lot sayısı (tümü): ${snapshot.docs.length}');

      // Sadece remaining_quantity > 0 olanları filtrele
      final availableLots = snapshot.docs.where((doc) {
        final data = doc.data();
        final remainingQty = data['remaining_quantity'] ?? 0;
        return remainingQty > 0;
      }).toList();

      print('📦 Mevcut lot sayısı (remaining_quantity > 0): ${availableLots.length}');

      final lots = availableLots.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        
        // Firestore Timestamp'i DateTime'a çevir
        if (data['purchase_date'] is Timestamp) {
          data['purchase_date'] = (data['purchase_date'] as Timestamp).toDate();
        }
        
        print('📦 Lot verisi: $data');
        return data;
      }).toList();

      // Tarihe göre sırala (FIFO için)
      lots.sort((a, b) {
        final dateA = a['purchase_date'] as DateTime? ?? DateTime.now();
        final dateB = b['purchase_date'] as DateTime? ?? DateTime.now();
        return dateA.compareTo(dateB);
      });

      print('✅ Toplam ${lots.length} lot döndürülüyor');
      return lots;
    } catch (e) {
      print('❌ Stok lotları yüklenirken hata: $e');
      print('❌ Hata detayı: ${e.toString()}');
      return [];
    }
  }

  // Stok lot güncelle
  static Future<Map<String, dynamic>> updateStockLot(String lotId, int newRemainingQuantity) async {
    try {
      final organizationId = await getCurrentUserOrganizationId();
      if (organizationId == null) {
        return {'success': false, 'message': 'Organizasyon bulunamadı'};
      }

      await _firestore
          .collection('organizations')
          .doc(organizationId)
          .collection('stock_lots')
          .doc(lotId)
          .update({
        'remaining_quantity': newRemainingQuantity,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      return {'success': true, 'message': 'Lot başarıyla güncellendi'};
    } catch (e) {
      print('❌ Stok lot güncelleme hatası: $e');
      return {'success': false, 'message': _getErrorMessage(e.toString())};
    }
  }

  // ==================== ANALYTICS OPERATIONS ====================
  
  // Toplam satış tutarı
  static Future<double> getTotalSalesAmount() async {
    try {
      final organizationId = await getCurrentUserOrganizationId();
      if (organizationId == null) return 0.0;

      final snapshot = await _firestore
          .collection('organizations')
          .doc(organizationId)
          .collection('inventory_transactions')
          .where('transaction_type', isEqualTo: 'SALE')
          .get();

      double total = 0.0;
      for (var doc in snapshot.docs) {
        final data = doc.data();
        total += (data['total_amount'] ?? 0.0).toDouble();
      }

      return total;
    } catch (e) {
      print('❌ Toplam satış tutarı hesaplanırken hata: $e');
      return 0.0;
    }
  }

  // Toplam ürün sayısı
  static Future<int> getTotalProductCount() async {
    try {
      final organizationId = await getCurrentUserOrganizationId();
      if (organizationId == null) return 0;

      final snapshot = await _firestore
          .collection('organizations')
          .doc(organizationId)
          .collection('products')
          .get();

      return snapshot.docs.length;
    } catch (e) {
      print('❌ Toplam ürün sayısı hesaplanırken hata: $e');
      return 0;
    }
  }

  // Bugünkü satışlar
  static Future<double> getTodaysSales() async {
    try {
      final organizationId = await getCurrentUserOrganizationId();
      if (organizationId == null) return 0.0;

      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      final snapshot = await _firestore
          .collection('organizations')
          .doc(organizationId)
          .collection('inventory_transactions')
          .where('transaction_type', isEqualTo: 'SALE')
          .where('transaction_date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('transaction_date', isLessThan: Timestamp.fromDate(endOfDay))
          .get();

      double total = 0.0;
      for (var doc in snapshot.docs) {
        final data = doc.data();
        total += (data['total_amount'] ?? 0.0).toDouble();
      }

      return total;
    } catch (e) {
      print('❌ Bugünkü satışlar hesaplanırken hata: $e');
      return 0.0;
    }
  }

  // Haftalık satışlar
  static Future<List<Map<String, dynamic>>> getWeeklySales() async {
    try {
      final organizationId = await getCurrentUserOrganizationId();
      if (organizationId == null) return [];

      final now = DateTime.now();
      final weekAgo = now.subtract(const Duration(days: 7));

      final snapshot = await _firestore
          .collection('organizations')
          .doc(organizationId)
          .collection('inventory_transactions')
          .where('transaction_type', isEqualTo: 'SALE')
          .where('transaction_date', isGreaterThanOrEqualTo: Timestamp.fromDate(weekAgo))
          .orderBy('transaction_date', descending: true)
          .get();

      // Günlük gruplandırma
      final Map<String, double> dailySales = {};
      
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final transactionDate = (data['transaction_date'] as Timestamp).toDate();
        final dateKey = '${transactionDate.year}-${transactionDate.month.toString().padLeft(2, '0')}-${transactionDate.day.toString().padLeft(2, '0')}';
        
        dailySales[dateKey] = (dailySales[dateKey] ?? 0.0) + (data['total_amount'] ?? 0.0).toDouble();
      }

      return dailySales.entries.map((entry) => {
        'date': entry.key,
        'total': entry.value,
      }).toList();
    } catch (e) {
      print('❌ Haftalık satışlar hesaplanırken hata: $e');
      return [];
    }
  }

  // Ürün analizi
  static Future<Map<String, dynamic>> getProductAnalytics(String productId, {
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final organizationId = await getCurrentUserOrganizationId();
      if (organizationId == null) return {};

      Query query = _firestore
          .collection('organizations')
          .doc(organizationId)
          .collection('inventory_transactions')
          .where('product_id', isEqualTo: productId);

      if (startDate != null) {
        query = query.where('transaction_date', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate));
      }

      if (endDate != null) {
        query = query.where('transaction_date', isLessThanOrEqualTo: Timestamp.fromDate(endDate));
      }

      final snapshot = await query.get();

      double totalSales = 0.0;
      double totalPurchases = 0.0;
      double totalProfit = 0.0;
      int saleCount = 0;
      int purchaseCount = 0;

      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final transactionType = data['transaction_type'];
        final totalAmount = (data['total_amount'] ?? 0.0).toDouble();
        final profitLoss = (data['profit_loss'] ?? 0.0).toDouble();

        if (transactionType == 'SALE') {
          totalSales += totalAmount;
          saleCount++;
        } else if (transactionType == 'PURCHASE') {
          totalPurchases += totalAmount;
          purchaseCount++;
        }

        totalProfit += profitLoss;
      }

      return {
        'totalSales': totalSales,
        'totalPurchases': totalPurchases,
        'totalProfit': totalProfit,
        'saleCount': saleCount,
        'purchaseCount': purchaseCount,
      };
    } catch (e) {
      print('❌ Ürün analizi hesaplanırken hata: $e');
      return {};
    }
  }

  // ==================== DATA MIGRATION OPERATIONS ====================
  
  // Tüm verileri temizle (migration için)
  static Future<Map<String, dynamic>> clearAllData() async {
    try {
      final organizationId = await getCurrentUserOrganizationId();
      if (organizationId == null) {
        return {'success': false, 'message': 'Organizasyon bulunamadı'};
      }

      final batch = _firestore.batch();

      // Products silme
      final productsSnapshot = await _firestore
          .collection('organizations')
          .doc(organizationId)
          .collection('products')
          .get();

      for (var doc in productsSnapshot.docs) {
        batch.delete(doc.reference);
      }

      // Inventory transactions silme
      final transactionsSnapshot = await _firestore
          .collection('organizations')
          .doc(organizationId)
          .collection('inventory_transactions')
          .get();

      for (var doc in transactionsSnapshot.docs) {
        batch.delete(doc.reference);
      }

      // Stock lots silme
      final lotsSnapshot = await _firestore
          .collection('organizations')
          .doc(organizationId)
          .collection('stock_lots')
          .get();

      for (var doc in lotsSnapshot.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();

      return {'success': true, 'message': 'Tüm veriler başarıyla temizlendi'};
    } catch (e) {
      print('❌ Veri temizleme hatası: $e');
      return {'success': false, 'message': _getErrorMessage(e.toString())};
    }
  }

  // User management methods for AuthService
  static Future<void> saveUser(dynamic user) async {
    try {
      final userMap = user.toMap();
      await _firestore.collection('users').doc(user.id.toString()).set(userMap);
    } catch (e) {
      print('Error saving user: $e');
      throw e;
    }
  }

  static Future<Map<String, dynamic>?> getUserByEmail(String email) async {
    try {
      final querySnapshot = await _firestore
          .collection('users')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();
      
      if (querySnapshot.docs.isNotEmpty) {
        return querySnapshot.docs.first.data();
      }
      return null;
    } catch (e) {
      print('Error getting user by email: $e');
      throw e;
    }
  }

  static Future<void> updateUser(dynamic user) async {
    try {
      final userMap = user.toMap();
      await _firestore.collection('users').doc(user.id.toString()).update(userMap);
    } catch (e) {
      print('Error updating user: $e');
      throw e;
    }
  }

  // Kullanıcının organizasyon bilgisini getir
  static Future<Map<String, dynamic>?> getUserOrganization(String userId) async {
    try {
      final orgDoc = await _firestore
          .collection('organizations')
          .doc(userId)
          .get();
      
      if (orgDoc.exists) {
        return orgDoc.data();
      }
      return null;
    } catch (e) {
      print('Error getting user organization: $e');
      return null;
    }
  }

  // **SERVER-SIDE PAGINATION**
  static DocumentSnapshot? _lastDocument;
  static final Map<String, List<Map<String, dynamic>>> _cache = {};
  static final Map<String, DateTime> _cacheTimestamps = {};
  static const Duration _cacheTimeout = Duration(minutes: 5);
  
  // Cache kontrolü
  static bool _isCacheValid(String key) {
    if (!_cache.containsKey(key) || !_cacheTimestamps.containsKey(key)) {
      return false;
    }
    
    final cacheTime = _cacheTimestamps[key]!;
    final now = DateTime.now();
    return now.difference(cacheTime) < _cacheTimeout;
  }
  
  // Cache'e veri kaydet
  static void _saveToCache(String key, List<Map<String, dynamic>> data) {
    _cache[key] = data;
    _cacheTimestamps[key] = DateTime.now();
    print('💾 Cache kaydedildi: $key (${data.length} öğe)');
  }
  
  // Cache'den veri al
  static List<Map<String, dynamic>>? _getFromCache(String key) {
    if (_isCacheValid(key)) {
      print('⚡ Cache\'den okundu: $key (${_cache[key]!.length} oge)');
      return _cache[key];
    }
    return null;
  }
  
  // Cache temizle
  static void clearCache() {
    _cache.clear();
    _cacheTimestamps.clear();
    print('🗑️ Cache temizlendi');
  }
  
  // Sayfalı işlem getirme (server-side pagination)
  static Future<Map<String, dynamic>> getTransactionsPaginated({
    List<String>? transactionTypes,
    int limit = 20,
    DocumentSnapshot? startAfter,
    bool useCache = true,
  }) async {
    try {
      print('📄 Sayfalı işlemler getiriliyor (limit: $limit)');
      
      // Cache key oluştur
      final cacheKey = 'transactions_${transactionTypes?.join('_') ?? 'all'}_$limit';
      
      // Cache kontrolü (sadece ilk sayfa için)
      if (useCache && startAfter == null) {
        final cachedData = _getFromCache(cacheKey);
        if (cachedData != null) {
          return {
            'transactions': cachedData,
            'hasMore': cachedData.length >= limit, // Tam limit ise daha fazla olabilir
            'lastDocument': null, // Cache'den gelirse lastDocument yok
          };
        }
      }
      
      final orgId = await getCurrentUserOrganizationId();
      if (orgId == null) {
        return {
          'transactions': <Map<String, dynamic>>[],
          'hasMore': false,
          'lastDocument': null,
        };
      }
      
      var query = _firestore
          .collection('organizations')
          .doc(orgId)
          .collection('inventory_transactions')
          .orderBy('transaction_date', descending: true);
      
      // İşlem türü filtresi
      if (transactionTypes != null && transactionTypes.isNotEmpty) {
        query = query.where('transaction_type', whereIn: transactionTypes);
      }
      
      // Pagination
      if (startAfter != null) {
        query = query.startAfterDocument(startAfter);
      }
      
      query = query.limit(limit + 1); // +1 ile hasMore kontrolü
      
      final querySnapshot = await query.get();
      final docs = querySnapshot.docs;
      
      // hasMore kontrolü
      final hasMore = docs.length > limit;
      final transactions = hasMore ? docs.take(limit).toList() : docs;
      
      final List<Map<String, dynamic>> result = transactions.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        
        // Timestamp'ları DateTime'a çevir
        if (data['transaction_date'] is Timestamp) {
          data['transaction_date'] = (data['transaction_date'] as Timestamp).toDate();
        }
        if (data['created_at'] is Timestamp) {
          data['created_at'] = (data['created_at'] as Timestamp).toDate();
        }
        if (data['createdAt'] is Timestamp) {
          data['createdAt'] = (data['createdAt'] as Timestamp).toDate();
        }
        
        return data;
      }).toList();
      
      // İlk sayfa için cache'e kaydet
      if (startAfter == null && useCache) {
        _saveToCache(cacheKey, result);
      }
      
      print('📊 ${result.length} işlem yüklendi (hasMore: $hasMore)');
      
      return {
        'transactions': result,
        'hasMore': hasMore,
        'lastDocument': transactions.isNotEmpty ? transactions.last : null,
      };
      
    } catch (e) {
      print('❌ Sayfalı işlem getirme hatası: $e');
      return {
        'transactions': <Map<String, dynamic>>[],
        'hasMore': false,
        'lastDocument': null,
      };
    }
  }
  
  // Ürünleri sayfalı getir
  static Future<Map<String, dynamic>> getProductsPaginated({
    int limit = 20,
    DocumentSnapshot? startAfter,
    String? searchQuery,
    bool useCache = true,
  }) async {
    try {
      print('📦 Sayfalı ürünler getiriliyor (limit: $limit)');
      
      // Cache key oluştur
      final cacheKey = 'products_${searchQuery ?? 'all'}_$limit';
      
      // Cache kontrolü (sadece ilk sayfa ve arama yoksa)
      if (useCache && startAfter == null && searchQuery == null) {
        final cachedData = _getFromCache(cacheKey);
        if (cachedData != null) {
          return {
            'products': cachedData,
            'hasMore': true,
            'lastDocument': null,
          };
        }
      }
      
      final orgId = await getCurrentUserOrganizationId();
      if (orgId == null) {
        return {
          'products': <Map<String, dynamic>>[],
          'hasMore': false,
          'lastDocument': null,
        };
      }
      
      var query = _firestore
          .collection('organizations')
          .doc(orgId)
          .collection('products')
          .orderBy('name');
      
      // Arama filtresi (basit text search)
      if (searchQuery != null && searchQuery.isNotEmpty) {
        query = query
            .where('name', isGreaterThanOrEqualTo: searchQuery)
            .where('name', isLessThan: searchQuery + '\uf8ff');
      }
      
      // Pagination
      if (startAfter != null) {
        query = query.startAfterDocument(startAfter);
      }
      
      query = query.limit(limit + 1);
      
      final querySnapshot = await query.get();
      final docs = querySnapshot.docs;
      
      final hasMore = docs.length > limit;
      final products = hasMore ? docs.take(limit).toList() : docs;
      
      final List<Map<String, dynamic>> result = products.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        
        // Timestamp'ları DateTime'a çevir
        if (data['createdAt'] is Timestamp) {
          data['createdAt'] = (data['createdAt'] as Timestamp).toDate();
        }
        if (data['updatedAt'] is Timestamp) {
          data['updatedAt'] = (data['updatedAt'] as Timestamp).toDate();
        }
        if (data['created_at'] is Timestamp) {
          data['created_at'] = (data['created_at'] as Timestamp).toDate();
        }
        if (data['updated_at'] is Timestamp) {
          data['updated_at'] = (data['updated_at'] as Timestamp).toDate();
        }
        
        return data;
      }).toList();
      
      // İlk sayfa için cache'e kaydet (arama yoksa)
      if (startAfter == null && useCache && searchQuery == null) {
        _saveToCache(cacheKey, result);
      }
      
      print('📦 ${result.length} ürün yüklendi (hasMore: $hasMore)');
      
      return {
        'products': result,
        'hasMore': hasMore,
        'lastDocument': products.isNotEmpty ? products.last : null,
      };
      
    } catch (e) {
      print('❌ Sayfalı ürün getirme hatası: $e');
      return {
        'products': <Map<String, dynamic>>[],
        'hasMore': false,
        'lastDocument': null,
      };
    }
  }

  // ==================== DATA CLEANUP OPERATIONS ====================
  
  // Tüm envanter verilerini sil (kullanıcılar hariç)
  static Future<Map<String, dynamic>> deleteAllInventoryData() async {
    try {
      final organizationId = await getCurrentUserOrganizationId();
      if (organizationId == null) {
        return {'success': false, 'message': 'Organizasyon bulunamadı'};
      }

      print('🗑️ Tüm envanter verileri siliniyor...');
      
      int deletedCount = 0;
      
      // 1. Products koleksiyonunu sil
      print('📦 Ürünler siliniyor...');
      final productsSnapshot = await _firestore
          .collection('organizations')
          .doc(organizationId)
          .collection('products')
          .get();
      
      final productsBatch = _firestore.batch();
      for (var doc in productsSnapshot.docs) {
        productsBatch.delete(doc.reference);
        deletedCount++;
      }
      await productsBatch.commit();
      print('✅ ${productsSnapshot.docs.length} ürün silindi');
      
      // 2. Inventory transactions koleksiyonunu sil
      print('📋 Envanter işlemleri siliniyor...');
      final transactionsSnapshot = await _firestore
          .collection('organizations')
          .doc(organizationId)
          .collection('inventory_transactions')
          .get();
      
      final transactionsBatch = _firestore.batch();
      for (var doc in transactionsSnapshot.docs) {
        transactionsBatch.delete(doc.reference);
        deletedCount++;
      }
      await transactionsBatch.commit();
      print('✅ ${transactionsSnapshot.docs.length} envanter işlemi silindi');
      
      // 3. Stock lots koleksiyonunu sil
      print('📦 Stok lotları siliniyor...');
      final lotsSnapshot = await _firestore
          .collection('organizations')
          .doc(organizationId)
          .collection('stock_lots')
          .get();
      
      final lotsBatch = _firestore.batch();
      for (var doc in lotsSnapshot.docs) {
        lotsBatch.delete(doc.reference);
        deletedCount++;
      }
      await lotsBatch.commit();
      print('✅ ${lotsSnapshot.docs.length} stok lotu silindi');
      
      // 4. Analytics verilerini sil (varsa)
      print('📊 Analiz verileri kontrol ediliyor...');
      try {
        final analyticsSnapshot = await _firestore
            .collection('organizations')
            .doc(organizationId)
            .collection('analytics')
            .get();
        
        if (analyticsSnapshot.docs.isNotEmpty) {
          final analyticsBatch = _firestore.batch();
          for (var doc in analyticsSnapshot.docs) {
            analyticsBatch.delete(doc.reference);
            deletedCount++;
          }
          await analyticsBatch.commit();
          print('✅ ${analyticsSnapshot.docs.length} analiz verisi silindi');
        }
      } catch (e) {
        print('ℹ️ Analytics koleksiyonu bulunamadı veya boş');
      }
      
      // 5. Backup verilerini sil (varsa)
      print('💾 Yedek verileri kontrol ediliyor...');
      try {
        final backupsSnapshot = await _firestore
            .collection('organizations')
            .doc(organizationId)
            .collection('backups')
            .get();
        
        if (backupsSnapshot.docs.isNotEmpty) {
          final backupsBatch = _firestore.batch();
          for (var doc in backupsSnapshot.docs) {
            backupsBatch.delete(doc.reference);
            deletedCount++;
          }
          await backupsBatch.commit();
          print('✅ ${backupsSnapshot.docs.length} yedek verisi silindi');
        }
      } catch (e) {
        print('ℹ️ Backups koleksiyonu bulunamadı veya boş');
      }
      
      print('🎉 Temizlik tamamlandı! Toplam ${deletedCount} kayıt silindi');
      print('👥 Kullanıcı verileri korundu');
      
      return {
        'success': true, 
        'message': 'Tüm envanter verileri başarıyla silindi',
        'deletedCount': deletedCount
      };
      
    } catch (e) {
      print('❌ Veri silme hatası: $e');
      return {
        'success': false, 
        'message': 'Veri silme başarısız: ${_getErrorMessage(e.toString())}'
      };
    }
  }
  
  // Sadece ürünleri sil
  static Future<Map<String, dynamic>> deleteAllProducts() async {
    try {
      final organizationId = await getCurrentUserOrganizationId();
      if (organizationId == null) {
        return {'success': false, 'message': 'Organizasyon bulunamadı'};
      }

      print('📦 Tüm ürünler siliniyor...');
      
      final snapshot = await _firestore
          .collection('organizations')
          .doc(organizationId)
          .collection('products')
          .get();
      
      final batch = _firestore.batch();
      for (var doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
      
      print('✅ ${snapshot.docs.length} ürün silindi');
      return {
        'success': true, 
        'message': '${snapshot.docs.length} ürün başarıyla silindi'
      };
      
    } catch (e) {
      print('❌ Ürün silme hatası: $e');
      return {
        'success': false, 
        'message': 'Ürün silme başarısız: ${_getErrorMessage(e.toString())}'
      };
    }
  }
  
  // Sadece envanter işlemlerini sil
  static Future<Map<String, dynamic>> deleteAllTransactions() async {
    try {
      final organizationId = await getCurrentUserOrganizationId();
      if (organizationId == null) {
        return {'success': false, 'message': 'Organizasyon bulunamadı'};
      }

      print('📋 Tüm envanter işlemleri siliniyor...');
      
      final snapshot = await _firestore
          .collection('organizations')
          .doc(organizationId)
          .collection('inventory_transactions')
          .get();
      
      final batch = _firestore.batch();
      for (var doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
      
      print('✅ ${snapshot.docs.length} envanter işlemi silindi');
      return {
        'success': true, 
        'message': '${snapshot.docs.length} envanter işlemi başarıyla silindi'
      };
      
    } catch (e) {
      print('❌ İşlem silme hatası: $e');
      return {
        'success': false, 
        'message': 'İşlem silme başarısız: ${_getErrorMessage(e.toString())}'
      };
    }
  }
  
  // Sadece stok lotlarını sil
  static Future<Map<String, dynamic>> deleteAllStockLots() async {
    try {
      final organizationId = await getCurrentUserOrganizationId();
      if (organizationId == null) {
        return {'success': false, 'message': 'Organizasyon bulunamadı'};
      }

      print('📦 Tüm stok lotları siliniyor...');
      
      final snapshot = await _firestore
          .collection('organizations')
          .doc(organizationId)
          .collection('stock_lots')
          .get();
      
      final batch = _firestore.batch();
      for (var doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
      
      print('✅ ${snapshot.docs.length} stok lotu silindi');
      return {
        'success': true, 
        'message': '${snapshot.docs.length} stok lotu başarıyla silindi'
      };
      
    } catch (e) {
      print('❌ Stok lotu silme hatası: $e');
      return {
        'success': false, 
        'message': 'Stok lotu silme başarısız: ${_getErrorMessage(e.toString())}'
      };
    }
  }

  // Hesap silme (Organizasyon)
  static Future<Map<String, dynamic>> deleteOrganizationAccount({
    required String password,
  }) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        return {'success': false, 'message': 'Kullanıcı oturumu bulunamadı'};
      }

      print('🗑️ Organizasyon hesabı silme işlemi başlatılıyor...');
      print('👤 User UID: ${currentUser.uid}');

      // Şifre doğrulaması için yeniden giriş yap
      final credential = EmailAuthProvider.credential(
        email: currentUser.email!,
        password: password,
      );

      await currentUser.reauthenticateWithCredential(credential);
      print('✅ Şifre doğrulaması başarılı');

      // Organizasyon verilerini al
      final orgDoc = await _firestore
          .collection('organizations')
          .doc(currentUser.uid)
          .get();

      if (!orgDoc.exists) {
        return {'success': false, 'message': 'Organizasyon bulunamadı'};
      }

      // Tüm alt koleksiyonları sil
      await _deleteOrganizationData(currentUser.uid);

      // Organizasyon dokümanını sil
      await _firestore
          .collection('organizations')
          .doc(currentUser.uid)
          .delete();

      print('✅ Firestore verileri silindi');

      // Firebase Auth hesabını sil
      await currentUser.delete();
      print('✅ Firebase Auth hesabı silindi');

      return {
        'success': true,
        'message': 'Hesabınız başarıyla silindi'
      };
    } catch (e) {
      print('❌ Hesap silme hatası: $e');
      if (e is FirebaseAuthException) {
        if (e.code == 'wrong-password') {
          return {'success': false, 'message': 'Şifre hatalı'};
        } else if (e.code == 'requires-recent-login') {
          return {'success': false, 'message': 'Güvenlik nedeniyle tekrar giriş yapın'};
        }
      }
      return {
        'success': false,
        'message': 'Hesap silme sırasında hata: ${e.toString()}'
      };
    }
  }

  // Hesap silme (Internal User)
  static Future<Map<String, dynamic>> deleteInternalUserAccount({
    required String password,
  }) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        return {'success': false, 'message': 'Kullanıcı oturumu bulunamadı'};
      }

      print('🗑️ Internal user hesabı silme işlemi başlatılıyor...');
      print('👤 User UID: ${currentUser.uid}');

      // Organizasyon ID'sini al
      final organizationId = await getCurrentUserOrganizationId();
      if (organizationId == null) {
        return {'success': false, 'message': 'Organizasyon bilgisi bulunamadı'};
      }

      // Şifre doğrulaması için yeniden giriş yap
      final credential = EmailAuthProvider.credential(
        email: currentUser.email!,
        password: password,
      );

      await currentUser.reauthenticateWithCredential(credential);
      print('✅ Şifre doğrulaması başarılı');

      // Internal user dokümanını sil
      await _firestore
          .collection('organizations')
          .doc(organizationId)
          .collection('internal_users')
          .doc(currentUser.uid)
          .delete();

      print('✅ Firestore internal user verileri silindi');

      // Firebase Auth hesabını sil
      await currentUser.delete();
      print('✅ Firebase Auth hesabı silindi');

      return {
        'success': true,
        'message': 'Hesabınız başarıyla silindi'
      };
    } catch (e) {
      print('❌ Internal user hesap silme hatası: $e');
      if (e is FirebaseAuthException) {
        if (e.code == 'wrong-password') {
          return {'success': false, 'message': 'Şifre hatalı'};
        } else if (e.code == 'requires-recent-login') {
          return {'success': false, 'message': 'Güvenlik nedeniyle tekrar giriş yapın'};
        }
      }
      return {
        'success': false,
        'message': 'Hesap silme sırasında hata: ${e.toString()}'
      };
    }
  }

  // Organizasyon verilerini sil (yardımcı metod)
  static Future<void> _deleteOrganizationData(String organizationId) async {
    try {
      print('🗑️ Organizasyon verileri siliniyor...');

      // Internal users
      final internalUsersQuery = await _firestore
          .collection('organizations')
          .doc(organizationId)
          .collection('internal_users')
          .get();

      for (var doc in internalUsersQuery.docs) {
        await doc.reference.delete();
      }
      print('✅ Internal users silindi');

      // Products
      final productsQuery = await _firestore
          .collection('organizations')
          .doc(organizationId)
          .collection('products')
          .get();

      for (var doc in productsQuery.docs) {
        await doc.reference.delete();
      }
      print('✅ Products silindi');

      // Sales
      final salesQuery = await _firestore
          .collection('organizations')
          .doc(organizationId)
          .collection('sales')
          .get();

      for (var doc in salesQuery.docs) {
        await doc.reference.delete();
      }
      print('✅ Sales silindi');

      // Transactions
      final transactionsQuery = await _firestore
          .collection('organizations')
          .doc(organizationId)
          .collection('transactions')
          .get();

      for (var doc in transactionsQuery.docs) {
        await doc.reference.delete();
      }
      print('✅ Transactions silindi');

      // Backups
      final backupsQuery = await _firestore
          .collection('organizations')
          .doc(organizationId)
          .collection('backups')
          .get();

      for (var doc in backupsQuery.docs) {
        await doc.reference.delete();
      }
      print('✅ Backups silindi');

      print('✅ Tüm organizasyon verileri silindi');
    } catch (e) {
      print('❌ Organizasyon verileri silme hatası: $e');
      // Hata olsa bile devam et
    }
  }

  // Auth getter
  static FirebaseAuth get auth => _auth;

  // Doğrulanmamış hesapları temizleme fonksiyonu
  static Future<void> cleanupUnverifiedAccounts() async {
    try {
      print('🧹 Doğrulanmamış hesapları temizleniyor...');
      
      // 24 saat önceki timestamp
      final cutoffTime = Timestamp.fromDate(
        DateTime.now().subtract(const Duration(hours: 24))
      );

      // Doğrulanmamış organizasyonları bul
      final unverifiedOrgs = await _firestore
          .collection('organizations')
          .where('isEmailVerified', isEqualTo: false)
          .where('createdAt', isLessThan: cutoffTime)
          .get();

      print('🧹 ${unverifiedOrgs.docs.length} doğrulanmamış organizasyon bulundu');

      // Her bir doğrulanmamış organizasyonu sil
      for (final doc in unverifiedOrgs.docs) {
        try {
          await deleteOrganizationAccount(doc.id);
          print('🗑️ Doğrulanmamış organizasyon silindi: ${doc.id}');
        } catch (e) {
          print('❌ Organizasyon silme hatası ${doc.id}: $e');
        }
      }

      print('✅ Doğrulanmamış hesap temizliği tamamlandı');
    } catch (e) {
      print('❌ Hesap temizleme hatası: $e');
    }
  }

  // Belirli bir organizasyonu temizleme
  static Future<void> cleanupSpecificUnverifiedOrganization(String email) async {
    try {
      print('🧹 Belirli doğrulanmamış organizasyon temizleniyor: $email');
      
      final orgQuery = await _firestore
          .collection('organizations')
          .where('email', isEqualTo: email)
          .where('isEmailVerified', isEqualTo: false)
          .limit(1)
          .get();

      if (orgQuery.docs.isNotEmpty) {
        final orgDoc = orgQuery.docs.first;
        await deleteOrganizationAccount(orgDoc.id);
        print('🗑️ Doğrulanmamış organizasyon temizlendi: ${orgDoc.id}');
      }
    } catch (e) {
      print('❌ Belirli organizasyon temizleme hatası: $e');
    }
  }
}
