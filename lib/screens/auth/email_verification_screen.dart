import 'package:flutter/material.dart';
import 'dart:async';
import '../../services/auth_service.dart';
import '../../services/firebase_service.dart';
import '../../services/email_service.dart';
import '../home_screen.dart';
import 'login_screen.dart';

class EmailVerificationScreen extends StatefulWidget {
  final String email;
  final bool fromLogin;
  final bool isOrganization;

  const EmailVerificationScreen({
    super.key,
    required this.email,
    this.fromLogin = false,
    this.isOrganization = false,
  });

  @override
  State<EmailVerificationScreen> createState() => _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  final AuthService _authService = AuthService();
  final EmailService _emailService = EmailService();
  final TextEditingController _codeController = TextEditingController();
  
  bool _isLoading = false;
  bool _canResend = false;
  int _resendCountdown = 60;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startResendTimer();
  }

  @override
  void dispose() {
    _codeController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  void _startResendTimer() {
    setState(() {
      _canResend = false;
      _resendCountdown = 60;
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _resendCountdown--;
      });

      if (_resendCountdown <= 0) {
        setState(() {
          _canResend = true;
        });
        timer.cancel();
      }
    });
  }

  Future<void> _verifyEmail() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) {
      _showMessage('Doğrulama kodunu girin', isError: true);
      return;
    }

    if (code.length != 6) {
      _showMessage('Doğrulama kodu 6 haneli olmalı', isError: true);
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      Map<String, dynamic> result;
      
      if (widget.isOrganization) {
        // Organizasyon email doğrulaması
        result = await FirebaseService.verifyOrganizationEmail(
          email: widget.email,
          verificationCode: code,
        );
      } else {
        // Bireysel kullanıcı email doğrulaması
        result = await _authService.verifyEmail(
          email: widget.email,
          code: code,
        );
      }

      if (result['success']) {
        _showMessage('Email başarıyla doğrulandı!');
        
        // Navigate to home screen
        await Future.delayed(const Duration(seconds: 1));
        
        if (mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const HomeScreen()),
            (route) => false,
          );
        }
      } else {
        _showMessage(result['message'], isError: true);
      }
    } catch (e) {
      _showMessage('Doğrulama sırasında hata: $e', isError: true);
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _resendCode() async {
    if (!_canResend) return;

    setState(() {
      _isLoading = true;
    });

    try {
      Map<String, dynamic> result;
      
      if (widget.isOrganization) {
        // Organizasyon için yeni kod gönder
        result = await _resendOrganizationCode();
      } else {
        // Bireysel kullanıcı için kod gönder
        result = await _authService.resendVerificationCode(widget.email);
      }

      if (result['success']) {
        _showMessage('Doğrulama kodu tekrar gönderildi');
        _startResendTimer();
      } else {
        _showMessage(result['message'], isError: true);
      }
    } catch (e) {
      _showMessage('Kod gönderme sırasında hata: $e', isError: true);
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<Map<String, dynamic>> _resendOrganizationCode() async {
    try {
      // Yeni verification code oluştur
      final newCode = FirebaseService.generateVerificationCode();
      
      // Firestore'da güncelle
      final orgQuery = await FirebaseService.firestore
          .collection('organizations')
          .where('email', isEqualTo: widget.email)
          .limit(1)
          .get();

      if (orgQuery.docs.isEmpty) {
        return {'success': false, 'message': 'Organizasyon bulunamadı'};
      }

      await orgQuery.docs.first.reference.update({
        'verificationCode': newCode,
      });

      // Email gönder
      final emailSent = await _emailService.sendVerificationEmail(
        recipientEmail: widget.email,
        verificationCode: newCode,
        firstName: 'Organizasyon',
      );

      return {
        'success': emailSent,
        'message': emailSent 
          ? 'Doğrulama kodu tekrar gönderildi'
          : 'Email gönderilemedi, lütfen tekrar deneyin',
      };
    } catch (e) {
      return {'success': false, 'message': 'Kod gönderme sırasında hata: $e'};
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        duration: Duration(seconds: isError ? 4 : 2),
      ),
    );
  }

  void _goToLogin() async {
    // Çıkış onayı göster
    final shouldExit = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.orange),
            SizedBox(width: 8),
            Text('Email Doğrulama'),
          ],
        ),
        content: const Text(
          'Email doğrulamasını tamamlamadan çıkmak istediğinizden emin misiniz?\n\nDoğrulanmamış hesabınız silinecektir.',
          style: TextStyle(fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Çıkış Yap'),
          ),
        ],
      ),
    );

    if (shouldExit == true) {
      try {
        if (widget.isOrganization) {
          // Doğrulanmamış organizasyon hesabını temizle
          await _cleanupUnverifiedOrganization();
        } else {
          // Doğrulanmamış bireysel kullanıcı hesabını temizle
          await _cleanupUnverifiedUser();
        }

        if (mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const LoginScreen()),
            (route) => false,
          );
        }
      } catch (e) {
        print('❌ Hesap temizleme hatası: $e');
        if (mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const LoginScreen()),
            (route) => false,
          );
        }
      }
    }
  }

  Future<void> _cleanupUnverifiedOrganization() async {
    try {
      // Doğrulanmamış organizasyon verilerini sil
      final orgQuery = await FirebaseService.firestore
          .collection('organizations')
          .where('email', isEqualTo: widget.email)
          .where('emailVerified', isEqualTo: false)
          .limit(1)
          .get();

      if (orgQuery.docs.isNotEmpty) {
        final orgDoc = orgQuery.docs.first;
        final orgId = orgDoc.id;
        
        // Organizasyon ve alt verilerini sil
        await FirebaseService.deleteOrganizationAccount(orgId);
        print('🗑️ Doğrulanmamış organizasyon temizlendi: $orgId');
      }

      // Firebase Auth hesabını da sil
      final currentUser = FirebaseService.auth.currentUser;
      if (currentUser != null && currentUser.email == widget.email && !currentUser.emailVerified) {
        await currentUser.delete();
        print('🗑️ Doğrulanmamış Firebase Auth hesabı silindi: ${widget.email}');
      }
    } catch (e) {
      print('❌ Organizasyon temizleme hatası: $e');
    }
  }

  Future<void> _cleanupUnverifiedUser() async {
    try {
      // Firebase Auth hesabını sil
      final currentUser = FirebaseService.auth.currentUser;
      if (currentUser != null && currentUser.email == widget.email && !currentUser.emailVerified) {
        await currentUser.delete();
        print('🗑️ Doğrulanmamış kullanıcı hesabı silindi: ${widget.email}');
      }
    } catch (e) {
      print('❌ Kullanıcı temizleme hatası: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        _goToLogin();
        return false; // Prevent default back action
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Email Doğrulama'),
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
          automaticallyImplyLeading: false,
          actions: [
            TextButton(
              onPressed: _goToLogin,
              child: const Text(
                'Çıkış',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 40),
                
                // Email Icon
                const Icon(
                  Icons.mark_email_unread,
                  size: 80,
                  color: Colors.blue,
                ),
                const SizedBox(height: 24),
                
                // Title
                Text(
                  widget.isOrganization ? 'Organizasyon Email Doğrulaması' : 'Email Doğrulaması',
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                  textAlign: TextAlign.center,
                ),
                
                const SizedBox(height: 16),
                
                // Description
                Text(
                  '${widget.email} adresine gönderilen 6 haneli doğrulama kodunu girin.',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                  ),
                  textAlign: TextAlign.center,
                ),
                
                const SizedBox(height: 32),
                
                // Code Input
                TextFormField(
                  controller: _codeController,
                  enabled: !_isLoading,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 8,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Doğrulama Kodu',
                    hintText: '000000',
                    border: OutlineInputBorder(),
                    counterText: '',
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // Verify Button
                ElevatedButton(
                  onPressed: _isLoading ? null : _verifyEmail,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text(
                          'Doğrula',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                ),
                
                const SizedBox(height: 24),
                
                // Resend Button
                TextButton(
                  onPressed: _canResend && !_isLoading ? _resendCode : null,
                  child: Text(
                    _canResend 
                        ? 'Kodu Tekrar Gönder'
                        : 'Tekrar gönder ($_resendCountdown saniye)',
                    style: TextStyle(
                      color: _canResend ? Colors.blue : Colors.grey,
                      fontSize: 16,
                    ),
                  ),
                ),
                
                const SizedBox(height: 32),
                
                // Info Box
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue.shade700),
                      const SizedBox(height: 8),
                      Text(
                        'Email gelmediyse spam klasörünüzü kontrol edin. Kod 15 dakika geçerlidir.',
                        style: TextStyle(
                          color: Colors.blue.shade700,
                          fontSize: 14,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 40),
                
                // Back to Login
                TextButton(
                  onPressed: _isLoading ? null : _goToLogin,
                  child: const Text(
                    'Giriş sayfasına dön',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
} 