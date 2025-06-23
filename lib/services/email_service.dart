import 'dart:io';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import 'package:flutter/material.dart';

// E-posta yapılandırma sınıfı
class EmailConfig {
  static const String senderEmail = 'msakkaya.01@gmail.com';
  static const String senderPassword = 'iovyettkigsqgvuu'; // Gmail Uygulama Şifresi (yeni şifre, boşluklar kaldırıldı)
  static const String senderName = 'Stoker App';
  
  // Not: Üretim ortamında bu değerler environment variables'dan okunmalıdır
  // Örnek: String.fromEnvironment('EMAIL_PASSWORD', defaultValue: '');
}

class EmailService {
  static final EmailService _instance = EmailService._internal();
  factory EmailService() => _instance;
  EmailService._internal();

  // SMTP server configuration
  SmtpServer get _smtpServer {
    return SmtpServer(
      'smtp.gmail.com',
      port: 587,
      username: EmailConfig.senderEmail,
      password: EmailConfig.senderPassword,
      ignoreBadCertificate: false,
      ssl: false,
      allowInsecure: false,
    );
  }

  // E-posta doğrulama kodu gönder
  Future<bool> sendVerificationEmail({
    required String recipientEmail,
    required String verificationCode,
    required String firstName,
  }) async {
    try {
      print('📧 E-posta gönderimi başlıyor...');
      print('📧 Alıcı: $recipientEmail');
      print('📧 Kod: $verificationCode');
      print('📧 Gönderen: ${EmailConfig.senderEmail}');
      
      final message = Message()
        ..from = Address(EmailConfig.senderEmail, EmailConfig.senderName)
        ..recipients.add(recipientEmail)
        ..subject = 'Stoker - Email Verification'
        ..html = _getVerificationEmailTemplate(firstName, verificationCode);

      print('📧 SMTP sunucusuna bağlanıyor...');
      final sendReport = await send(message, _smtpServer);
      print('📧 E-posta başarıyla gönderildi: $recipientEmail');
      print('📧 Send Report: $sendReport');
      return true;
    } catch (e) {
      print('❌ E-posta gönderme hatası: $e');
      print('❌ Hata tipi: ${e.runtimeType}');
      
      if (e is MailerException) {
        print('❌ Mailer Exception details: ${e.message}');
        for (var problem in e.problems) {
          print('❌ Problem: ${problem.code} - ${problem.msg}');
        }
      }
      
      // Real email mode - return false if email fails
      return false;
    }
  }

  // Şifre sıfırlama kodu gönder
  Future<bool> sendPasswordResetEmail({
    required String recipientEmail,
    required String resetCode,
    required String firstName,
  }) async {
    try {
      print('🔐 Şifre sıfırlama e-postası gönderimi başlıyor...');
      print('🔐 Alıcı: $recipientEmail');
      print('🔐 Kod: $resetCode');
      print('🔐 Gönderen: ${EmailConfig.senderEmail}');
      
      final message = Message()
        ..from = Address(EmailConfig.senderEmail, EmailConfig.senderName)
        ..recipients.add(recipientEmail)
        ..subject = 'Stoker - Password Reset'
        ..html = _getPasswordResetEmailTemplate(firstName, resetCode);

      print('🔐 SMTP sunucusuna bağlanıyor...');
      final sendReport = await send(message, _smtpServer);
      print('🔐 Şifre sıfırlama e-postası başarıyla gönderildi: $recipientEmail');
      print('🔐 Send Report: $sendReport');
      return true;
    } catch (e) {
      print('❌ Şifre sıfırlama e-postası gönderme hatası: $e');
      print('❌ Hata tipi: ${e.runtimeType}');
      
      if (e is MailerException) {
        print('❌ Mailer Exception details: ${e.message}');
        for (var problem in e.problems) {
          print('❌ Problem: ${problem.code} - ${problem.msg}');
        }
      }
      
      // Real email mode - return false if email fails
      return false;
    }
  }

  // Hoş geldin e-postası gönder
  Future<bool> sendWelcomeEmail({
    required String recipientEmail,
    required String firstName,
  }) async {
    try {
      final message = Message()
        ..from = Address(EmailConfig.senderEmail, EmailConfig.senderName)
        ..recipients.add(recipientEmail)
        ..subject = 'Stoker\'a Hoş Geldiniz!'
        ..html = _getWelcomeEmailTemplate(firstName);

      await send(message, _smtpServer);
      print('Hoş geldin e-postası gönderildi: $recipientEmail');
      return true;
    } catch (e) {
      print('Hoş geldin e-postası gönderme hatası: $e');
      return false;
    }
  }

  // E-posta doğrulama şablonu
  String _getVerificationEmailTemplate(String firstName, String verificationCode) {
    return '''
    <!DOCTYPE html>
    <html>
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>E-posta Doğrulama</title>
        <style>
            /* Force colors for all email clients */
            * {
                -webkit-text-size-adjust: 100%;
                -ms-text-size-adjust: 100%;
            }
            
            body { 
                font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, Cantarell, sans-serif; 
                line-height: 1.6; 
                color: #FFFFFF !important; 
                background-color: #000000 !important;
                margin: 0 !important;
                padding: 0 !important;
            }
            
            /* Override any email client dark mode */
            .container { 
                max-width: 600px; 
                margin: 0 auto; 
                padding: 20px; 
                background-color: #000000 !important;
                color: #FFFFFF !important;
            }
            
            .header { 
                background: linear-gradient(135deg, #2196F3 0%, #1976D2 100%) !important; 
                color: #FFFFFF !important; 
                padding: 30px 20px; 
                text-align: center; 
                border-radius: 12px 12px 0 0; 
            }
            
            .content { 
                background: #1A1A1A !important; 
                color: #FFFFFF !important;
                padding: 40px 30px; 
                border-radius: 0 0 12px 12px; 
                border: 2px solid #333333 !important;
            }
            
            .content h3 {
                color: #FFFFFF !important;
                margin-top: 0;
            }
            
            .content p {
                color: #E8E8E8 !important;
            }
            
            .content strong {
                color: #FFFFFF !important;
            }
            
            .code-box { 
                background: #2A2A2A !important; 
                border: 3px solid #2196F3 !important; 
                border-radius: 12px; 
                padding: 25px; 
                text-align: center; 
                margin: 25px 0; 
                box-shadow: 0 4px 12px rgba(33, 150, 243, 0.5) !important;
            }
            
            .code { 
                font-size: 36px; 
                font-weight: bold; 
                color: #2196F3 !important; 
                letter-spacing: 8px; 
                font-family: 'Courier New', monospace;
                display: block;
                padding: 10px;
                background: #000000 !important;
                border-radius: 8px;
                border: 1px solid #2196F3 !important;
            }
            
            .footer { 
                text-align: center; 
                margin-top: 25px; 
                color: #999999 !important; 
                font-size: 12px; 
            }
            
            .logo { 
                font-size: 28px; 
                margin-bottom: 10px; 
                color: #FFFFFF !important;
            }
            
            ul { 
                color: #E0E0E0 !important; 
                padding-left: 20px;
            }
            
            li { 
                margin: 8px 0; 
                color: #E0E0E0 !important;
            }
            
            /* Media queries for different clients */
            @media only screen and (max-width: 600px) {
                .container {
                    padding: 10px !important;
                }
                .content {
                    padding: 20px 15px !important;
                }
                .code {
                    font-size: 28px !important;
                    letter-spacing: 4px !important;
                }
            }
            
            /* Force override for Outlook and other clients */
            [data-ogsc] body,
            [data-ogsc] .container,
            [data-ogsc] .content {
                background-color: #000000 !important;
                color: #FFFFFF !important;
            }
        </style>
    </head>
    <body>
        <div class="container">
            <div class="header">
                <div class="logo">📦 Stoker</div>
                <h2>E-posta Doğrulama</h2>
            </div>
            <div class="content">
                <h3>Merhaba $firstName,</h3>
                <p>Stoker'a hoş geldiniz! Hesabınızı etkinleştirmek için aşağıdaki doğrulama kodunu kullanın:</p>
                
                <div class="code-box">
                    <div class="code">$verificationCode</div>
                </div>
                
                <p><strong>Önemli:</strong></p>
                <ul>
                    <li>Bu kod 15 dakika geçerlidir</li>
                    <li>Kodu kimseyle paylaşmayın</li>
                    <li>Bu talebi siz yapmadıysanız bu e-postayı güvenle görmezden gelebilirsiniz</li>
                </ul>
                
                <p>İyi günler!<br>Stoker Ekibi</p>
            </div>
            <div class="footer">
                <p>Bu e-posta otomatik olarak gönderilmiştir. Lütfen yanıtlamayın.</p>
            </div>
        </div>
    </body>
    </html>
    ''';
  }

  // Şifre sıfırlama şablonu
  String _getPasswordResetEmailTemplate(String firstName, String resetCode) {
    return '''
    <!DOCTYPE html>
    <html>
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>Şifre Sıfırlama</title>
        <style>
            /* Force colors for all email clients */
            * {
                -webkit-text-size-adjust: 100%;
                -ms-text-size-adjust: 100%;
            }
            
            body { 
                font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, Cantarell, sans-serif; 
                line-height: 1.6; 
                color: #FFFFFF !important; 
                background-color: #000000 !important;
                margin: 0 !important;
                padding: 0 !important;
            }
            
            /* Override any email client dark mode */
            .container { 
                max-width: 600px; 
                margin: 0 auto; 
                padding: 20px; 
                background-color: #000000 !important;
                color: #FFFFFF !important;
            }
            
            .header { 
                background: linear-gradient(135deg, #FF9800 0%, #F57C00 100%) !important; 
                color: #FFFFFF !important; 
                padding: 30px 20px; 
                text-align: center; 
                border-radius: 12px 12px 0 0; 
            }
            
            .content { 
                background: #1A1A1A !important; 
                color: #FFFFFF !important;
                padding: 40px 30px; 
                border-radius: 0 0 12px 12px; 
                border: 2px solid #333333 !important;
            }
            
            .content h3 {
                color: #FFFFFF !important;
                margin-top: 0;
            }
            
            .content p {
                color: #E8E8E8 !important;
            }
            
            .content strong {
                color: #FFFFFF !important;
            }
            
            .code-box { 
                background: #2A2A2A !important; 
                border: 3px solid #FF9800 !important; 
                border-radius: 12px; 
                padding: 25px; 
                text-align: center; 
                margin: 25px 0; 
                box-shadow: 0 4px 12px rgba(255, 152, 0, 0.5) !important;
            }
            
            .code { 
                font-size: 36px; 
                font-weight: bold; 
                color: #FF9800 !important; 
                letter-spacing: 8px; 
                font-family: 'Courier New', monospace;
                display: block;
                padding: 10px;
                background: #000000 !important;
                border-radius: 8px;
                border: 1px solid #FF9800 !important;
            }
            
            .warning { 
                background: #2A2A2A !important; 
                border: 2px solid #FF9800 !important; 
                border-radius: 8px; 
                padding: 20px; 
                margin: 20px 0; 
                color: #FFFFFF !important;
            }
            
            .warning strong {
                color: #FF9800 !important;
            }
            
            .footer { 
                text-align: center; 
                margin-top: 25px; 
                color: #999999 !important; 
                font-size: 12px; 
            }
            
            .logo { 
                font-size: 28px; 
                margin-bottom: 10px; 
                color: #FFFFFF !important;
            }
            
            ul { 
                color: #E0E0E0 !important; 
                padding-left: 20px;
            }
            
            li { 
                margin: 8px 0; 
                color: #E0E0E0 !important;
            }
            
            /* Media queries for different clients */
            @media only screen and (max-width: 600px) {
                .container {
                    padding: 10px !important;
                }
                .content {
                    padding: 20px 15px !important;
                }
                .code {
                    font-size: 28px !important;
                    letter-spacing: 4px !important;
                }
            }
            
            /* Force override for Outlook and other clients */
            [data-ogsc] body,
            [data-ogsc] .container,
            [data-ogsc] .content {
                background-color: #000000 !important;
                color: #FFFFFF !important;
            }
        </style>
    </head>
    <body>
        <div class="container">
            <div class="header">
                <div class="logo">🔐 Stoker</div>
                <h2>Şifre Sıfırlama</h2>
            </div>
            <div class="content">
                <h3>Merhaba $firstName,</h3>
                <p>Hesabınız için şifre sıfırlama talebi aldık. Yeni şifrenizi belirlemek için aşağıdaki kodu kullanın:</p>
                
                <div class="code-box">
                    <div class="code">$resetCode</div>
                </div>
                
                <div class="warning">
                    <strong>⚠️ Güvenlik Uyarısı:</strong>
                    <ul style="margin: 10px 0;">
                        <li>Bu kod 15 dakika geçerlidir</li>
                        <li>Kodu kimseyle paylaşmayın</li>
                        <li>Bu talebi siz yapmadıysanız derhal bizimle iletişime geçin</li>
                        <li>Şifrenizi güvenli ve karmaşık seçin</li>
                    </ul>
                </div>
                
                <p>Hesabınızın güvenliği bizim için önemlidir.</p>
                
                <p>İyi günler!<br>Stoker Ekibi</p>
            </div>
            <div class="footer">
                <p>Bu e-posta otomatik olarak gönderilmiştir. Lütfen yanıtlamayın.</p>
            </div>
        </div>
    </body>
    </html>
    ''';
  }

  // Hoş geldin e-posta şablonu
  String _getWelcomeEmailTemplate(String firstName) {
    return '''
    <!DOCTYPE html>
    <html>
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>Stoker'a Hoş Geldiniz</title>
        <style>
            /* Force colors for all email clients */
            * {
                -webkit-text-size-adjust: 100%;
                -ms-text-size-adjust: 100%;
            }
            
            body { 
                font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, Cantarell, sans-serif; 
                line-height: 1.6; 
                color: #FFFFFF !important; 
                background-color: #000000 !important;
                margin: 0 !important;
                padding: 0 !important;
            }
            
            /* Override any email client dark mode */
            .container { 
                max-width: 600px; 
                margin: 0 auto; 
                padding: 20px; 
                background-color: #000000 !important;
                color: #FFFFFF !important;
            }
            
            .header { 
                background: linear-gradient(135deg, #4CAF50 0%, #2E7D32 100%) !important; 
                color: #FFFFFF !important; 
                padding: 30px 20px; 
                text-align: center; 
                border-radius: 12px 12px 0 0; 
            }
            
            .content { 
                background: #1A1A1A !important; 
                color: #FFFFFF !important;
                padding: 40px 30px; 
                border-radius: 0 0 12px 12px; 
                border: 2px solid #333333 !important;
            }
            
            .content h3 {
                color: #FFFFFF !important;
                margin-top: 0;
            }
            
            .content p {
                color: #E8E8E8 !important;
            }
            
            .content strong {
                color: #FFFFFF !important;
            }
            
            .feature-box { 
                background: #2A2A2A !important; 
                border: 2px solid #4CAF50 !important; 
                border-radius: 12px; 
                padding: 20px; 
                margin: 20px 0; 
                color: #FFFFFF !important;
            }
            
            .feature-title {
                color: #4CAF50 !important;
                font-weight: bold;
                margin-bottom: 10px;
            }
            
            .footer { 
                text-align: center; 
                margin-top: 25px; 
                color: #999999 !important; 
                font-size: 12px; 
            }
            
            .logo { 
                font-size: 28px; 
                margin-bottom: 10px; 
                color: #FFFFFF !important;
            }
            
            ul { 
                color: #E0E0E0 !important; 
                padding-left: 20px;
            }
            
            li { 
                margin: 8px 0; 
                color: #E0E0E0 !important;
            }
            
            /* Media queries for different clients */
            @media only screen and (max-width: 600px) {
                .container {
                    padding: 10px !important;
                }
                .content {
                    padding: 20px 15px !important;
                }
                .feature-box {
                    padding: 15px !important;
                }
            }
            
            /* Force override for Outlook and other clients */
            [data-ogsc] body,
            [data-ogsc] .container,
            [data-ogsc] .content {
                background-color: #000000 !important;
                color: #FFFFFF !important;
            }
        </style>
    </head>
    <body>
        <div class="container">
            <div class="header">
                <div class="logo">🎉 Stoker</div>
                <h2>Hoş Geldiniz!</h2>
            </div>
            <div class="content">
                <h3>Merhaba $firstName,</h3>
                <p>Stoker'a hoş geldiniz! Hesabınız başarıyla oluşturuldu ve artık profesyonel stok yönetim sistemimizi kullanmaya başlayabilirsiniz.</p>
                
                <div class="feature-box">
                    <div class="feature-title">🚀 Başlangıç İpuçları:</div>
                    <ul>
                        <li><strong>Ürün Ekle:</strong> İlk ürününüzü ekleyerek başlayın</li>
                        <li><strong>Stok Takibi:</strong> Stok hareketlerinizi kolayca takip edin</li>
                        <li><strong>Satış Kayıt:</strong> Satışlarınızı anında kaydedin</li>
                        <li><strong>Raporlar:</strong> Detaylı analizler ile işinizi büyütün</li>
                    </ul>
                </div>
                
                <div class="feature-box">
                    <div class="feature-title">💡 Ana Özellikler:</div>
                    <ul>
                        <li>Gelişmiş stok yönetimi</li>
                        <li>Otomatik stok uyarıları</li>
                        <li>Detaylı satış raporları</li>
                        <li>Çoklu kullanıcı desteği</li>
                        <li>Veri yedekleme sistemi</li>
                    </ul>
                </div>
                
                <p>Herhangi bir sorunuz olursa veya yardıma ihtiyacınız varsa, bizimle iletişime geçmekten çekinmeyin. Stoker ekibi olarak size en iyi deneyimi sunmak için buradayız.</p>
                
                <p>Başarılar dileriz!<br><strong>Stoker Ekibi</strong></p>
            </div>
            <div class="footer">
                <p>Bu e-posta Stoker tarafından otomatik olarak gönderilmiştir.</p>
                <p>© ${DateTime.now().year} Stoker - Profesyonel Stok Yönetim Sistemi</p>
            </div>
        </div>
    </body>
    </html>
    ''';
  }

  // Gmail SMTP ayarları (kullanıcı kendi bilgilerini girecek)
  Future<bool> sendBackupEmail({
    required String recipientEmail,
    required File backupFile,
    required String backupFileName,
    String? businessName,
  }) async {
    try {
      // Mevcut e-posta yapılandırmasını kullan
      final smtpServer = _smtpServer;
      
      // E-posta mesajını oluştur
      final message = Message()
        ..from = Address(EmailConfig.senderEmail, EmailConfig.senderName)
        ..recipients.add(recipientEmail)
        ..subject = 'Stok Yönetim Sistemi - Yedek Dosyası (${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year})'
        ..html = _buildEmailBody(backupFileName, businessName)
        ..attachments = [
          FileAttachment(backupFile)
            ..location = Location.attachment
            ..cid = backupFileName
        ];

      // E-postayı gönder
      final sendReport = await send(message, smtpServer);
      print('📧 Yedek dosyası e-posta ile gönderildi: $recipientEmail');
      print('📧 Send Report: $sendReport');
      return true;
      
    } catch (e) {
      print('❌ Yedek e-posta gönderme hatası: $e');
      return false;
    }
  }

  String _buildEmailBody(String fileName, String? businessName) {
    final now = DateTime.now();
    final dateStr = '${now.day}/${now.month}/${now.year} ${now.hour}:${now.minute.toString().padLeft(2, '0')}';
    
    return '''
    <!DOCTYPE html>
    <html>
    <head>
        <meta charset="UTF-8">
        <style>
            body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; }
            .container { max-width: 600px; margin: 0 auto; padding: 20px; }
            .header { background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; padding: 20px; border-radius: 10px 10px 0 0; text-align: center; }
            .content { background: #f9f9f9; padding: 20px; border-radius: 0 0 10px 10px; }
            .info-box { background: white; padding: 15px; border-radius: 8px; margin: 15px 0; border-left: 4px solid #667eea; }
            .footer { text-align: center; margin-top: 20px; color: #666; font-size: 12px; }
            .icon { font-size: 24px; margin-right: 10px; }
        </style>
    </head>
    <body>
        <div class="container">
            <div class="header">
                <h1><span class="icon">📦</span>Stok Yönetim Sistemi</h1>
                <p>Yedek Dosyası Gönderimi</p>
            </div>
            
            <div class="content">
                <h2>Merhaba!</h2>
                
                <p>Stok yönetim sisteminizin yedek dosyası başarıyla oluşturuldu ve bu e-postaya eklenmiştir.</p>
                
                <div class="info-box">
                    <h3>📋 Yedek Bilgileri</h3>
                    <p><strong>İşletme:</strong> ${businessName ?? 'Belirtilmemiş'}</p>
                    <p><strong>Dosya Adı:</strong> $fileName</p>
                    <p><strong>Oluşturulma Tarihi:</strong> $dateStr</p>
                    <p><strong>Dosya Türü:</strong> JSON Yedek Dosyası</p>
                </div>
                
                <div class="info-box">
                    <h3>⚠️ Önemli Notlar</h3>
                    <ul>
                        <li>Bu dosyayı güvenli bir yerde saklayın</li>
                        <li>Yedek dosyası tüm ürün, stok ve işlem verilerinizi içerir</li>
                        <li>Geri yükleme işlemi için uygulamadaki "Yedek Geri Yükle" özelliğini kullanın</li>
                        <li>Bu e-postayı yetkisiz kişilerle paylaşmayın</li>
                    </ul>
                </div>
                
                <div class="info-box">
                    <h3>🔄 Geri Yükleme</h3>
                    <p>Bu yedek dosyasını geri yüklemek için:</p>
                    <ol>
                        <li>Uygulamayı açın</li>
                        <li>Ayarlar > Yedekleme menüsüne gidin</li>
                        <li>"Yedek Geri Yükle" butonuna tıklayın</li>
                        <li>Bu dosyayı seçin</li>
                    </ol>
                </div>
            </div>
            
            <div class="footer">
                <p>Bu e-posta Stok Yönetim Sistemi tarafından otomatik olarak gönderilmiştir.</p>
                <p>© ${DateTime.now().year} Stok Yönetim Sistemi - Tüm hakları saklıdır.</p>
            </div>
        </div>
    </body>
    </html>
    ''';
  }

  // Basit onay dialog'u - kullanıcının kayıtlı e-postasına gönderim onayı
  static Future<bool> showBackupEmailConfirmation(BuildContext context, String userEmail) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.email, color: Colors.blue),
            SizedBox(width: 8),
            Text('E-posta ile Gönder'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.backup, size: 48, color: Colors.blue),
            SizedBox(height: 16),
            Text(
              'Yedek dosyasını e-posta ile göndermek istiyor musunuz?',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 16),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade300),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(Icons.person, color: Colors.blue.shade700, size: 16),
                      SizedBox(width: 8),
                      Text(
                        'Alıcı E-posta:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade700,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 4),
                  Text(
                    userEmail,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.blue.shade800,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 12),
            Text(
              'Yedek dosyası yukarıdaki e-posta adresine gönderilecektir.',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('İptal'),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: Icon(Icons.send),
            label: Text('Gönder'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  // Custom e-posta gönderme metodu (Subscription service için)
  Future<bool> sendCustomEmail({
    required String recipientEmail,
    required String subject,
    required String htmlContent,
  }) async {
    try {
      print('📧 Custom e-posta gönderimi başlıyor...');
      print('📧 Alıcı: $recipientEmail');
      print('📧 Konu: $subject');
      print('📧 Gönderen: ${EmailConfig.senderEmail}');
      
      final message = Message()
        ..from = Address(EmailConfig.senderEmail, EmailConfig.senderName)
        ..recipients.add(recipientEmail)
        ..subject = subject
        ..html = htmlContent;

      print('📧 SMTP sunucusuna bağlanıyor...');
      final sendReport = await send(message, _smtpServer);
      print('📧 Custom e-posta başarıyla gönderildi: $recipientEmail');
      print('📧 Send Report: $sendReport');
      return true;
    } catch (e) {
      print('❌ Custom e-posta gönderme hatası: $e');
      print('❌ Hata tipi: ${e.runtimeType}');
      
      if (e is MailerException) {
        print('❌ Mailer Exception details: ${e.message}');
        for (var problem in e.problems) {
          print('❌ Problem: ${problem.code} - ${problem.msg}');
        }
      }
      
      return false;
    }
  }
}
