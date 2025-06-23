import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class HelpScreen extends StatefulWidget {
  const HelpScreen({super.key});

  @override
  State<HelpScreen> createState() => _HelpScreenState();
}

class _HelpScreenState extends State<HelpScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Yardım & Destek'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'SSS', icon: Icon(Icons.help_outline)),
            Tab(text: 'Kılavuz', icon: Icon(Icons.book_outlined)),
            Tab(text: 'İletişim', icon: Icon(Icons.contact_support_outlined)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildFAQTab(),
          _buildGuideTab(),
          _buildContactTab(),
        ],
      ),
    );
  }

  Widget _buildFAQTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildFAQItem(
          'Nasıl ürün eklerim?',
          'Dashboard\'dan "Ürün Ekle" butonuna tıklayın veya Ürünler sayfasından "+" butonunu kullanın. Ürün bilgilerini doldurup kaydedin.',
        ),
        _buildFAQItem(
          'Stok nasıl güncellenir?',
          'Ürünler sayfasından ürünü seçin ve "Alış" butonuna tıklayın. Alış miktarını girin, sistem otomatik olarak stoğu güncelleyecektir.',
        ),
        _buildFAQItem(
          'Satış nasıl yapılır?',
          'Ürünler sayfasından ürünü seçin ve "Satış" butonuna tıklayın. Satış miktarını ve fiyatını girin. İndirim uygulamak isterseniz indirim yüzdesini belirtin.',
        ),
        _buildFAQItem(
          'Yedek nasıl alınır?',
          'Yedekleme sayfasına gidin ve "Yedek Oluştur" butonuna tıklayın. Yedek dosyasını paylaşabilir veya e-posta ile gönderebilirsiniz.',
        ),
        _buildFAQItem(
          'İade işlemi nasıl yapılır?',
          'Ürünler sayfasından ürünü seçin ve "İade" butonuna tıklayın. İade türünü (satış iadesi/alış iadesi) seçin ve gerekli bilgileri girin.',
        ),
        _buildFAQItem(
          'Kayıp/Fire işlemi nedir?',
          'Bozulan, kırılan veya çalınan ürünler için kullanılır. Ürünler sayfasından "Kayıp/Fire" butonuna tıklayın ve kayıp nedenini belirtin.',
        ),
        _buildFAQItem(
          'Raporları nasıl görüntülerim?',
          'Analiz & Raporlar sayfasından satış trendlerini, kar/zarar durumunu ve performans metriklerini görüntüleyebilirsiniz.',
        ),
        _buildFAQItem(
          'Düşük stok uyarısı nasıl çalışır?',
          'Her ürün için minimum stok seviyesi belirleyebilirsiniz. Stok bu seviyenin altına düştüğünde dashboard\'da uyarı görüntülenir.',
        ),
      ],
    );
  }

  Widget _buildGuideTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildGuideSection(
          'Başlangıç',
          [
            'Uygulamaya kayıt olun ve e-posta doğrulaması yapın',
            'İlk ürününüzü ekleyin',
            'Stok seviyelerini belirleyin',
            'İlk alış işleminizi gerçekleştirin',
          ],
        ),
        _buildGuideSection(
          'Ürün Yönetimi',
          [
            'Ürün eklerken SKU otomatik oluşturulur',
            'Ürün kategorilerini kullanarak düzenli tutun',
            'Minimum stok seviyelerini belirleyin',
            'Ürün fiyatlarını güncel tutun',
          ],
        ),
        _buildGuideSection(
          'Stok Takibi',
          [
            'Alış işlemleri ile stok artırın',
            'Satış işlemleri ile stok azaltın',
            'FIFO (İlk Giren İlk Çıkar) sistemi kullanılır',
            'Stok hareketlerini takip edin',
          ],
        ),
        _buildGuideSection(
          'Satış İşlemleri',
          [
            'Satış yaparken lot seçimi yapabilirsiniz',
            'İndirim uygulayabilirsiniz',
            'Kar/zarar otomatik hesaplanır',
            'Satış geçmişini görüntüleyebilirsiniz',
          ],
        ),
        _buildGuideSection(
          'Raporlama',
          [
            'Günlük, haftalık, aylık raporlar alın',
            'Satış trendlerini analiz edin',
            'Kar/zarar durumunu takip edin',
            'En çok satan ürünleri belirleyin',
          ],
        ),
        _buildGuideSection(
          'Yedekleme',
          [
            'Düzenli yedek alın',
            'Yedekleri güvenli yerde saklayın',
            'E-posta ile yedek gönderebilirsiniz',
            'Gerektiğinde geri yükleme yapın',
          ],
        ),
      ],
    );
  }

  Widget _buildContactTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Destek Ekibi',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Herhangi bir sorunuz veya öneriniz varsa bizimle iletişime geçebilirsiniz. '
                  'Destek ekibimiz size en kısa sürede yardımcı olmaya hazır.',
                ),
                const SizedBox(height: 20),
                
                ListTile(
                  leading: const Icon(Icons.email_outlined),
                  title: const Text('E-posta'),
                  subtitle: const Text('destek@stokapp.com'),
                  onTap: () => _launchEmail('destek@stokapp.com'),
                ),
                
                ListTile(
                  leading: const Icon(Icons.phone_outlined),
                  title: const Text('Telefon'),
                  subtitle: const Text('+90 (212) 555 0123'),
                  onTap: () => _launchPhone('+902125550123'),
                ),
                
                ListTile(
                  leading: const Icon(Icons.web_outlined),
                  title: const Text('Web Sitesi'),
                  subtitle: const Text('www.stokapp.com'),
                  onTap: () => _launchURL('https://www.stokapp.com'),
                ),
              ],
            ),
          ),
        ),
        
        const SizedBox(height: 16),
        
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Çalışma Saatleri',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),
                
                const Row(
                  children: [
                    Icon(Icons.access_time_outlined),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Pazartesi - Cuma: 09:00 - 18:00'),
                          Text('Cumartesi: 10:00 - 16:00'),
                          Text('Pazar: Kapalı'),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        
        const SizedBox(height: 16),
        
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Geri Bildirim',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Uygulamayı nasıl bulduğunuzu öğrenmek isteriz. '
                  'Önerileriniz ve geri bildirimleriniz bizim için çok değerli.',
                ),
                const SizedBox(height: 16),
                
                ElevatedButton.icon(
                  onPressed: () => _launchEmail('geribildirm@stokapp.com'),
                  icon: const Icon(Icons.feedback_outlined),
                  label: const Text('Geri Bildirim Gönder'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFAQItem(String question, String answer) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ExpansionTile(
        title: Text(
          question,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(answer),
          ),
        ],
      ),
    );
  }

  Widget _buildGuideSection(String title, List<String> items) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            ...items.map((item) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 6),
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: Theme.of(context).primaryColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Text(item)),
                ],
              ),
            )),
          ],
        ),
      ),
    );
  }

  Future<void> _launchEmail(String email) async {
    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: email,
      query: 'subject=Stok Yönetim Uygulaması Destek',
    );
    
    if (await canLaunchUrl(emailUri)) {
      await launchUrl(emailUri);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('E-posta uygulaması açılamadı')),
        );
      }
    }
  }

  Future<void> _launchPhone(String phone) async {
    final Uri phoneUri = Uri(scheme: 'tel', path: phone);
    
    if (await canLaunchUrl(phoneUri)) {
      await launchUrl(phoneUri);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Telefon uygulaması açılamadı')),
        );
      }
    }
  }

  Future<void> _launchURL(String url) async {
    final Uri uri = Uri.parse(url);
    
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Web sitesi açılamadı')),
        );
      }
    }
  }
} 