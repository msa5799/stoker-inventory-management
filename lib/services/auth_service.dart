import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';
import 'email_service.dart';
import 'firebase_service.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final EmailService _emailService = EmailService();
  User? _currentUser;

  User? get currentUser => _currentUser;
  bool get isLoggedIn => _currentUser != null;
  bool get isGuest => _currentUser != null && _currentUser!.id == -1;

  // Password hashing
  String _hashPassword(String password) {
    final bytes = utf8.encode(password);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  // Email validation
  bool _isValidEmail(String email) {
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
  }

  // Generate verification code
  String _generateVerificationCode() {
    final random = Random();
    return (100000 + random.nextInt(900000)).toString();
  }

  // Register new user
  Future<Map<String, dynamic>> register({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    String? phone,
  }) async {
    try {
      // Validate input
      if (!_isValidEmail(email)) {
        return {'success': false, 'message': 'Geçersiz email adresi'};
      }

      if (password.length < 6) {
        return {'success': false, 'message': 'Şifre en az 6 karakter olmalı'};
      }

      if (firstName.trim().isEmpty || lastName.trim().isEmpty) {
        return {'success': false, 'message': 'Ad ve soyad gerekli'};
      }

      // Create user
      final user = User(
        email: email.toLowerCase().trim(),
        passwordHash: _hashPassword(password),
        firstName: firstName.trim(),
        lastName: lastName.trim(),
        phone: phone?.trim(),
        verificationCode: _generateVerificationCode(),
        createdAt: DateTime.now(),
      );

      final createdUser = user.copyWith(id: DateTime.now().millisecondsSinceEpoch);

      // Save to Firebase
      await FirebaseService.saveUser(createdUser);

      // Send verification email
      final emailSent = await _emailService.sendVerificationEmail(
        recipientEmail: createdUser.email,
        verificationCode: createdUser.verificationCode!,
        firstName: createdUser.firstName,
      );

      return {
        'success': true,
        'message': 'Kayıt başarılı! E-posta adresinize doğrulama kodu gönderildi.',
        'user': createdUser,
      };
    } catch (e) {
      return {'success': false, 'message': 'Kayıt sırasında hata: $e'};
    }
  }

  // Login user
  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    try {
      if (!_isValidEmail(email)) {
        return {'success': false, 'message': 'Geçersiz email adresi'};
      }

      // Get user from Firebase
      final userData = await FirebaseService.getUserByEmail(email);
      if (userData == null) {
        return {'success': false, 'message': 'Kullanıcı bulunamadı'};
      }

      final user = User.fromMap(userData);
      final hashedPassword = _hashPassword(password);
      
      if (user.passwordHash != hashedPassword) {
        return {'success': false, 'message': 'Hatalı şifre'};
      }

      // Update last login
      final updatedUser = user.copyWith(lastLoginAt: DateTime.now());
      await FirebaseService.updateUser(updatedUser);

      _currentUser = updatedUser;
      await _saveCurrentUser(updatedUser);

      return {
        'success': true,
        'message': 'Giriş başarılı',
        'user': updatedUser,
      };
    } catch (e) {
      return {'success': false, 'message': 'Giriş sırasında hata: $e'};
    }
  }

  // Verify email
  Future<Map<String, dynamic>> verifyEmail({
    required String email,
    required String code,
  }) async {
    try {
      final userData = await FirebaseService.getUserByEmail(email);
      if (userData == null) {
        return {'success': false, 'message': 'Kullanıcı bulunamadı'};
      }

      final user = User.fromMap(userData);
      if (user.verificationCode != code) {
        return {'success': false, 'message': 'Doğrulama kodu hatalı'};
      }

      final verifiedUser = user.copyWith(
        isEmailVerified: true,
        verificationCode: null,
      );

      await FirebaseService.updateUser(verifiedUser);
      _currentUser = verifiedUser;
      await _saveCurrentUser(verifiedUser);

      return {
        'success': true,
        'message': 'E-posta başarıyla doğrulandı',
        'user': verifiedUser,
      };
    } catch (e) {
      return {'success': false, 'message': 'Doğrulama sırasında hata: $e'};
    }
  }

  // Resend verification code
  Future<Map<String, dynamic>> resendVerificationCode(String email) async {
    try {
      final userData = await FirebaseService.getUserByEmail(email);
      if (userData == null) {
        return {'success': false, 'message': 'Kullanıcı bulunamadı'};
      }

      final user = User.fromMap(userData);
      if (user.isEmailVerified ?? false) {
        return {'success': false, 'message': 'E-posta zaten doğrulanmış'};
      }

      final newCode = _generateVerificationCode();
      final updatedUser = user.copyWith(verificationCode: newCode);

      await FirebaseService.updateUser(updatedUser);

      final emailSent = await _emailService.sendVerificationEmail(
        recipientEmail: user.email,
        verificationCode: newCode,
        firstName: user.firstName,
      );

      return {
        'success': emailSent,
        'message': emailSent 
          ? 'Doğrulama kodu tekrar gönderildi'
          : 'E-posta gönderilemedi, lütfen tekrar deneyin',
      };
    } catch (e) {
      return {'success': false, 'message': 'Kod gönderme sırasında hata: $e'};
    }
  }

  // Login as guest
  Future<Map<String, dynamic>> loginAsGuest() async {
    try {
      final guestUser = User(
        id: -1,
        email: 'guest@stoker.local',
        passwordHash: '',
        firstName: 'Misafir',
        lastName: 'Kullanıcı',
        isEmailVerified: true,
        createdAt: DateTime.now(),
        lastLoginAt: DateTime.now(),
      );

      _currentUser = guestUser;
      await _saveCurrentUser(guestUser);

      return {
        'success': true,
        'message': 'Misafir olarak giriş yapıldı',
        'user': guestUser,
      };
    } catch (e) {
      return {'success': false, 'message': 'Misafir girişi sırasında hata: $e'};
    }
  }

  // Logout
  Future<void> logout() async {
    _currentUser = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('current_user');
  }

  // Try auto login
  Future<bool> tryAutoLogin() async {
    try {
      // Önce Firebase Auth'da aktif oturum var mı kontrol et
      final firebaseUser = FirebaseService.currentUser;
      
      if (firebaseUser != null) {
        print('✅ Firebase\'da aktif oturum bulundu: ${firebaseUser.email}');
        
        // Firebase'da aktif oturum varsa, kullanıcı verilerini yükle
        try {
          // Organizasyon kullanıcısı mı kontrol et
          final orgDoc = await FirebaseService.getUserOrganization(firebaseUser.uid);
          if (orgDoc != null) {
            print('✅ Organizasyon kullanıcısı tespit edildi');
            // Organizasyon kullanıcısı için giriş başarılı
            return true;
          }
          
          // Internal user mı kontrol et
          final userData = await FirebaseService.getUserByEmail(firebaseUser.email!);
          if (userData != null) {
            _currentUser = User.fromMap(userData);
            await _saveCurrentUser(_currentUser!);
            print('✅ Internal user giriş başarılı');
            return true;
          }
          
          print('⚠️ Firebase kullanıcısı bulundu ama veri yüklenemedi');
        } catch (e) {
          print('❌ Kullanıcı verileri yüklenirken hata: $e');
        }
      }
      
      // Firebase'da aktif oturum yoksa SharedPreferences'ı kontrol et
      final prefs = await SharedPreferences.getInstance();
      final userJson = prefs.getString('current_user');
      if (userJson != null) {
        final userMap = jsonDecode(userJson);
        _currentUser = User.fromMap(userMap);
        print('✅ SharedPreferences\'tan kullanıcı yüklendi');
        return true;
      }
      
      print('❌ Hiçbir aktif oturum bulunamadı');
    } catch (e) {
      print('❌ Auto login error: $e');
    }
    return false;
  }

  // Save current user
  Future<void> _saveCurrentUser(User user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('current_user', jsonEncode(user.toMap()));
  }

  // Update current user
  Future<void> updateCurrentUser(User user) async {
    _currentUser = user;
    await _saveCurrentUser(user);
    await FirebaseService.updateUser(user);
  }

  // Change password
  Future<Map<String, dynamic>> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      if (_currentUser == null) {
        return {'success': false, 'message': 'Kullanıcı oturumu bulunamadı'};
      }

      if (newPassword.length < 6) {
        return {'success': false, 'message': 'Yeni şifre en az 6 karakter olmalı'};
      }

      final currentHashedPassword = _hashPassword(currentPassword);
      if (_currentUser!.passwordHash != currentHashedPassword) {
        return {'success': false, 'message': 'Mevcut şifre hatalı'};
      }

      final newHashedPassword = _hashPassword(newPassword);
      final updatedUser = _currentUser!.copyWith(passwordHash: newHashedPassword);

      await updateCurrentUser(updatedUser);

      return {'success': true, 'message': 'Şifre başarıyla değiştirildi'};
    } catch (e) {
      return {'success': false, 'message': 'Şifre değiştirme sırasında hata: $e'};
    }
  }

  // Forgot password
  Future<Map<String, dynamic>> forgotPassword({required String email}) async {
    try {
      if (!_isValidEmail(email)) {
        return {'success': false, 'message': 'Geçersiz email adresi'};
      }

      final userData = await FirebaseService.getUserByEmail(email);
      if (userData == null) {
        return {'success': false, 'message': 'Bu email adresi ile kayıtlı kullanıcı bulunamadı'};
      }

      final user = User.fromMap(userData);
      final resetCode = _generateVerificationCode();
      final updatedUser = user.copyWith(verificationCode: resetCode);

      await FirebaseService.updateUser(updatedUser);

      final emailSent = await _emailService.sendPasswordResetEmail(
        recipientEmail: user.email,
        resetCode: resetCode,
        firstName: user.firstName,
      );

      return {
        'success': emailSent,
        'message': emailSent 
          ? 'Şifre sıfırlama kodu e-posta adresinize gönderildi'
          : 'E-posta gönderilemedi, lütfen tekrar deneyin',
      };
    } catch (e) {
      return {'success': false, 'message': 'Şifre sıfırlama sırasında hata: $e'};
    }
  }

  // Reset password
  Future<Map<String, dynamic>> resetPassword({
    required String email,
    required String resetCode,
    required String newPassword,
  }) async {
    try {
      if (!_isValidEmail(email)) {
        return {'success': false, 'message': 'Geçersiz email adresi'};
      }

      if (newPassword.length < 6) {
        return {'success': false, 'message': 'Yeni şifre en az 6 karakter olmalı'};
      }

      final userData = await FirebaseService.getUserByEmail(email);
      if (userData == null) {
        return {'success': false, 'message': 'Kullanıcı bulunamadı'};
      }

      final user = User.fromMap(userData);
      if (user.verificationCode != resetCode) {
        return {'success': false, 'message': 'Sıfırlama kodu hatalı'};
      }

      final newHashedPassword = _hashPassword(newPassword);
      final updatedUser = user.copyWith(
        passwordHash: newHashedPassword,
        verificationCode: null,
      );

      await FirebaseService.updateUser(updatedUser);

      return {'success': true, 'message': 'Şifre başarıyla sıfırlandı'};
    } catch (e) {
      return {'success': false, 'message': 'Şifre sıfırlama sırasında hata: $e'};
    }
  }
} 