# E-posta Servisi Yapılandırması

Bu dokümanda Stok Yönetim Uygulamasında kullanılan e-posta servisi hakkında bilgiler bulabilirsiniz.

## Genel Bakış

Uygulama, kullanıcı kaydı, e-posta doğrulama ve şifre sıfırlama işlemleri için Gmail SMTP servisi kullanmaktadır.

## Yapılandırma

### E-posta Kimlik Bilgileri

Şu anda yapılandırılmış e-posta hesabı:
- **E-posta:** msakkaya.01@gmail.com
- **Uygulama Şifresi:** fqup veyl dzgp iihl
- **Gönderen Adı:** Stok Yönetim Sistemi

### Güvenlik Notları

⚠️ **ÖNEMLİ:** Gmail uygulama şifresi kullanılmaktadır. Bu şifre normal Gmail şifrenizden farklıdır.

Gmail uygulama şifresi nasıl alınır:
1. Gmail hesabınızda 2FA (İki faktörlü kimlik doğrulama) aktif olmalı
2. Google Hesap Ayarları > Güvenlik > 2FA > Uygulama şifreleri
3. "Posta" kategorisinde yeni bir uygulama şifresi oluşturun
4. 16 haneli şifreyi kopyalayın (boşluklar dahil)

## E-posta Türleri

### 1. E-posta Doğrulama
- **Ne zaman gönderilir:** Kullanıcı kaydı sırasında
- **İçerik:** 6 haneli doğrulama kodu
- **Geçerlilik:** 15 dakika
- **Görsel:** Mavi tema, profesyonel tasarım

### 2. Şifre Sıfırlama
- **Ne zaman gönderilir:** Şifremi unuttum seçeneği kullanıldığında
- **İçerik:** 6 haneli sıfırlama kodu
- **Geçerlilik:** 15 dakika
- **Görsel:** Turuncu tema, güvenlik uyarıları

### 3. Hoş Geldin E-postası
- **Ne zaman gönderilir:** E-posta doğrulandıktan sonra
- **İçerik:** Uygulamanın özellikleri ve kullanım ipuçları
- **Görsel:** Yeşil tema, bilgilendirici içerik

## Teknik Detaylar

### SMTP Ayarları
- **Server:** Gmail SMTP (smtp.gmail.com)
- **Port:** 587 (TLS)
- **Güvenlik:** TLS/SSL
- **Kimlik Doğrulama:** OAuth2 (mailer paketi otomatik halleder)

### Kullanılan Paketler
```yaml
dependencies:
  mailer: ^6.0.1
```

### Dosya Yapısı
```
lib/services/
├── email_service.dart      # Ana e-posta servisi
└── auth_service.dart       # E-posta servisi entegrasyonu
```

## Kod Örnekleri

### E-posta Gönderme
```dart
final emailService = EmailService();

// Doğrulama kodu gönder
bool sent = await emailService.sendVerificationEmail(
  recipientEmail: 'user@example.com',
  verificationCode: '123456',
  firstName: 'John',
);
```

### Hata Yönetimi
E-posta gönderimi başarısız olursa:
- Kullanıcıya bilgi verilir
- Hata loglanır
- Uygulama çökertilmez

## Sık Karşılaşılan Sorunlar

### 1. E-posta Gönderilmiyor
- Gmail hesabında 2FA aktif mi?
- Uygulama şifresi doğru mu?
- İnternet bağlantısı var mı?

### 2. E-posta Spam'e Düşüyor
- Gmail IP'si genelde güvenilirdir
- Kullanıcılara spam klasörünü kontrol etmelerini söyleyin

### 3. Hız Limiti
- Gmail SMTP'nin günlük limitleri vardır
- Çok fazla e-posta göndermeyin

## Üretim Ortamı İçin Öneriler

### 1. Environment Variables
```dart
// Güvenli konfigürasyon
class EmailConfig {
  static const String senderEmail = String.fromEnvironment('EMAIL_ADDRESS');
  static const String senderPassword = String.fromEnvironment('EMAIL_PASSWORD');
}
```

### 2. Professional E-posta Servisi
- SendGrid
- AWS SES
- Mailgun
- Postmark

### 3. Monitoring
- E-posta gönderim logları
- Başarı/başarısızlık oranları
- Kullanıcı şikayetleri

## Test Etme

### Manuel Test
1. Yeni kullanıcı kaydı oluşturun
2. E-posta doğrulama kodunu kontrol edin
3. Şifre sıfırlama işlemini deneyin

### Debug Modunda
Konsol çıktılarını kontrol edin:
```
E-posta doğrulama kodu gönderildi: user@example.com
Şifre sıfırlama kodu gönderildi: user@example.com
```

## Lisans ve Kullanım

Bu e-posta servisi sadece Stok Yönetim Uygulaması için tasarlanmıştır. Kişisel kullanım içindir.

---

**Son güncelleme:** 2024
**Versiyon:** 1.0
**Geliştirici:** Stok Yönetim Ekibi 