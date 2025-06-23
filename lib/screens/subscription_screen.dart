import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/subscription.dart';
import '../services/subscription_service.dart';

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({Key? key}) : super(key: key);

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  final SubscriptionService _subscriptionService = SubscriptionService();
  final TextEditingController _activationCodeController = TextEditingController();
  
  Subscription? _subscription;
  bool _isLoading = true;
  bool _isRequestingCode = false;
  bool _isActivating = false;

  @override
  void initState() {
    super.initState();
    _loadSubscription();
  }

  Future<void> _loadSubscription() async {
    setState(() => _isLoading = true);
    
    try {
      if (_subscriptionService.isLoggedIn) {
        print('🔍 Abonelik bilgileri yükleniyor...');
        final subscription = await _subscriptionService.getUserSubscription();
        setState(() {
          _subscription = subscription;
          _isLoading = false;
        });
        print('✅ Abonelik bilgileri yüklendi: ${subscription != null}');
      } else {
        print('❌ Kullanıcı giriş yapmamış');
        setState(() {
          _subscription = null;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('❌ Abonelik bilgileri yüklenirken hata: $e');
      setState(() => _isLoading = false);
      _showErrorDialog('Abonelik bilgileri yüklenirken hata: $e');
    }
  }

  Future<void> _requestActivationCode() async {
    setState(() => _isRequestingCode = true);
    
    try {
      print('🔑 Aktivasyon kodu talebi başlatılıyor...');
      final result = await _subscriptionService.requestActivationCode();
      
      if (result['success']) {
        _showSuccessDialog(
          'Kod Talebi Gönderildi',
          result['message'] ?? 'Aktivasyon kodu talebi başarıyla gönderildi.',
        );
        await _loadSubscription(); // Subscription bilgilerini güncelle
      } else {
        _showErrorDialog(result['message'] ?? 'Kod talebi gönderilemedi');
      }
    } catch (e) {
      print('❌ Kod talebi sırasında hata: $e');
      _showErrorDialog('Kod talebi sırasında hata: $e');
    } finally {
      setState(() => _isRequestingCode = false);
    }
  }

  Future<void> _activatePremium() async {
    final code = _activationCodeController.text.trim();
    if (code.isEmpty) {
      _showErrorDialog('Lütfen aktivasyon kodunu girin');
      return;
    }

    setState(() => _isActivating = true);
    
    try {
      print('🔓 Premium aktivasyon başlatılıyor...');
      final result = await _subscriptionService.activatePremium(code);
      
      if (result['success']) {
        _activationCodeController.clear();
        _showSuccessDialog(
          'Aktivasyon Başarılı!',
          result['message'] ?? 'Premium aboneliğiniz aktive edildi.',
        );
        await _loadSubscription(); // Subscription bilgilerini güncelle
      } else {
        _showErrorDialog(result['message'] ?? 'Aktivasyon başarısız');
      }
    } catch (e) {
      print('❌ Aktivasyon sırasında hata: $e');
      _showErrorDialog('Aktivasyon sırasında hata: $e');
    } finally {
      setState(() => _isActivating = false);
    }
  }

  void _showSuccessDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.green),
            const SizedBox(width: 8),
            Text(title),
          ],
        ),
        content: Text(message),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Tamam'),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.error, color: Colors.red),
            SizedBox(width: 8),
            Text('Hata'),
          ],
        ),
        content: Text(message),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Tamam'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('💎 Premium Abonelik'),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : !_subscriptionService.isLoggedIn
              ? _buildGuestMessage()
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildStatusCard(),
                      const SizedBox(height: 20),
                      if (_subscription != null) ...[
                        _buildSubscriptionInfo(),
                        const SizedBox(height: 20),
                      ],
                      _buildActivationSection(),
                      const SizedBox(height: 20),
                      _buildHowItWorks(),
                    ],
                  ),
                ),
    );
  }

  Widget _buildStatusCard() {
    final isActive = _subscription?.isActive ?? false;
    final isPremium = _subscription?.isPremium ?? false;
    final isInTrial = _subscription?.isInFreeTrial ?? false;
    final canRequestCode = _subscription?.canRequestActivationCode ?? true;
    final remainingHours = _subscription?.remainingHoursToExpiry ?? 0;
    
    Color cardColor;
    IconData statusIcon;
    String statusText;
    String subText;
    
    if (isPremium && !_subscription!.isPremiumExpired) {
      cardColor = Colors.green;
      statusIcon = Icons.verified;
      statusText = 'Premium Aktif';
      subText = '${_subscription!.remainingDays} gün kaldı';
    } else if (isInTrial) {
      cardColor = Colors.blue;
      statusIcon = Icons.schedule;
      statusText = 'Ücretsiz Deneme';
      subText = '${_subscription!.freeTrialRemainingDays} gün kaldı';
    } else {
      cardColor = Colors.orange;
      statusIcon = Icons.warning;
      statusText = 'Premium Gerekli';
      subText = 'Tüm özelliklere erişim için premium gerekli';
    }

    return Card(
      color: cardColor.withOpacity(0.1),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Icon(statusIcon, size: 48, color: cardColor),
            const SizedBox(height: 12),
            Text(
              statusText,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: cardColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subText,
              style: TextStyle(
                fontSize: 16,
                color: cardColor.withOpacity(0.8),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubscriptionInfo() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.info, color: Colors.blue),
                const SizedBox(width: 8),
                const Text(
                  'Abonelik Bilgileri',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildInfoRow('Kayıt Tarihi', 
                '${_subscription!.createdAt.day}/${_subscription!.createdAt.month}/${_subscription!.createdAt.year}'),
            _buildInfoRow('Toplam Aktivasyon', '${_subscription!.totalActivations}'),
            if (_subscription!.isPremium) ...[
              _buildInfoRow('Premium Başlangıç', 
                  _subscription!.premiumActivatedAt != null 
                      ? '${_subscription!.premiumActivatedAt!.day}/${_subscription!.premiumActivatedAt!.month}/${_subscription!.premiumActivatedAt!.year}'
                      : 'Bilinmiyor'),
              _buildInfoRow('Premium Bitiş', 
                  _subscription!.premiumExpiresAt != null 
                      ? '${_subscription!.premiumExpiresAt!.day}/${_subscription!.premiumExpiresAt!.month}/${_subscription!.premiumExpiresAt!.year}'
                      : 'Bilinmiyor'),
            ],
            if (_subscription!.lastCodeRequestAt != null)
              _buildInfoRow('Son Kod Talebi', 
                  '${_subscription!.lastCodeRequestAt!.day}/${_subscription!.lastCodeRequestAt!.month}/${_subscription!.lastCodeRequestAt!.year}'),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
          Text(value, style: const TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildActivationSection() {
    // Premium bitimine 1 günden az varsa kod talep edilemez
    final canRequestCode = _subscription?.canRequestActivationCode ?? true;
    final remainingHours = _subscription?.remainingHoursToExpiry ?? 0;
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.key, color: Colors.amber),
                const SizedBox(width: 8),
                const Text(
                  'Premium Aktivasyon',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Kod Talep Butonu
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: (_isRequestingCode || !canRequestCode) ? null : _requestActivationCode,
                icon: _isRequestingCode 
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(Icons.email, color: canRequestCode ? null : Colors.grey),
                label: Text(
                  _isRequestingCode 
                      ? 'Gönderiliyor...' 
                      : 'Aktivasyon Kodu Talep Et'
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: canRequestCode ? Colors.blue : Colors.grey.shade300,
                  foregroundColor: canRequestCode ? Colors.white : Colors.grey.shade600,
                  padding: const EdgeInsets.all(16),
                ),
              ),
            ),
            
            // Info yazısı
            if (!canRequestCode && _subscription?.isPremium == true) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info, color: Colors.blue.shade700, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Üyeliğin yenilenmesi için ${_subscription!.remainingDays} gün ${_subscription!.remainingHoursToExpiry % 24} saat kalmıştır. 1 gün kala yenilenebilir.',
                        style: TextStyle(
                          color: Colors.blue.shade700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 16),
            
            // Aktivasyon Kodu Girme
            const Text(
              'Aktivasyon Kodu Girin:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _activationCodeController,
              decoration: const InputDecoration(
                hintText: 'STOK-XXXX-XXXX-XXXX',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.vpn_key),
              ),
              textCapitalization: TextCapitalization.characters,
              inputFormatters: [
                UpperCaseTextFormatter(),
              ],
            ),
            const SizedBox(height: 12),
            
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isActivating ? null : _activatePremium,
                icon: _isActivating 
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.verified),
                label: Text(_isActivating ? 'Aktive Ediliyor...' : 'Premium Aktive Et'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.all(16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHowItWorks() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.help, color: Colors.green),
                const SizedBox(width: 8),
                const Text(
                  'Nasıl Çalışır?',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildStep(1, 'Aktivasyon Kodu Talep Et', 
                'Yukarıdaki butona tıklayın. Sistem size özel bir kod üretir.'),
            _buildStep(2, 'Ödeme Yapın', 
                'Aylık abonelik ücreti için bizimle iletişime geçin.'),
            _buildStep(3, 'Kodu Alın', 
                'Ödeme sonrası size aktivasyon kodunu göndeririz.'),
            _buildStep(4, 'Aktive Edin', 
                'Aldığınız kodu yukarıdaki alana girin ve premium aktive edin.'),
            
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.contact_phone, color: Colors.green.shade700),
                      const SizedBox(width: 8),
                      Text(
                        'İletişim Bilgileri',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Email: msakkaya.02@gmail.com',
                    style: TextStyle(color: Colors.green.shade600),
                  ),
                  Text(
                    'Ödeme ve aktivasyon için yukarıdaki email adresinden iletişime geçebilirsiniz.',
                    style: TextStyle(
                      color: Colors.green.shade600,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep(int number, String title, String description) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: Colors.green,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                '$number',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGuestMessage() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.person_outline,
            size: 80,
            color: Colors.amber.shade600,
          ),
          const SizedBox(height: 24),
          Text(
            'Premium Özellikler',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.amber.shade700,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Premium aktivasyon kodu talep etmek için organizasyon hesabı ile giriş yapmanız gerekiyor.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: Colors.amber.shade600,
            ),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.amber.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.amber.shade200),
            ),
            child: Column(
              children: [
                Text(
                  '🎯 Premium ile neler kazanırsınız?',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.amber.shade700,
                  ),
                ),
                const SizedBox(height: 12),
                _buildFeatureRow(Icons.cloud_upload, 'Otomatik yedekleme'),
                _buildFeatureRow(Icons.analytics, 'Gelişmiş raporlar'),
                _buildFeatureRow(Icons.support, 'Öncelikli destek'),
                _buildFeatureRow(Icons.security, 'Gelişmiş güvenlik'),
              ],
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                // Navigate to login/register screen
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Lütfen organizasyon hesabı ile giriş yapın'),
                    backgroundColor: Colors.orange,
                  ),
                );
              },
              icon: const Icon(Icons.login),
              label: const Text('Giriş Yap'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.all(16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.amber.shade700),
          const SizedBox(width: 8),
          Text(text, style: TextStyle(color: Colors.amber.shade700)),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _activationCodeController.dispose();
    super.dispose();
  }
}

// Text formatter to convert to uppercase
class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return TextEditingValue(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
} 