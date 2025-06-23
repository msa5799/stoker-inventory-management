import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/firebase_service.dart';
import 'auth/login_selection_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  
  final _companyNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  
  bool _isLoading = true;
  bool _isEditing = false;
  bool _isSaving = false;
  
  // User data
  User? _firebaseUser;
  Map<String, dynamic>? _organizationData;
  Map<String, dynamic>? _internalUserData;
  bool _isOrganizationUser = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  @override
  void dispose() {
    _companyNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    try {
      setState(() {
        _isLoading = true;
      });

      _firebaseUser = FirebaseAuth.instance.currentUser;
      
      if (_firebaseUser == null) {
        print('❌ Firebase kullanıcısı null - giriş yapılmamış');
        // Kullanıcı giriş yapmamış
        if (mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const LoginSelectionScreen()),
            (route) => false,
          );
        }
        return;
      }

      print('🔍 Kullanıcı bilgileri yükleniyor...');
      print('📧 Firebase User Email: ${_firebaseUser!.email}');
      print('🆔 Firebase User UID: ${_firebaseUser!.uid}');

      // Önce organizasyon kullanıcısı mı kontrol et
      print('🔍 Organizasyon dokümanı kontrol ediliyor...');
      final orgDoc = await FirebaseFirestore.instance
          .collection('organizations')
          .doc(_firebaseUser!.uid)
          .get();

      print('📄 Organizasyon dokümanı var mı: ${orgDoc.exists}');

      if (orgDoc.exists) {
        // Organizasyon kullanıcısı
        print('✅ Organizasyon kullanıcısı tespit edildi');
        _isOrganizationUser = true;
        _organizationData = orgDoc.data();
        
        print('📄 Organizasyon verisi: $_organizationData');
        
        _companyNameController.text = _organizationData?['name'] ?? '';
        _emailController.text = _firebaseUser!.email ?? '';
        _phoneController.text = _organizationData?['phone'] ?? '';
        _addressController.text = _organizationData?['address'] ?? '';
        
        print('✅ Organizasyon kullanıcısı yüklendi: ${_organizationData?['name']}');
        print('📝 Form alanları dolduruldu');
      } else {
        // Internal user - organizasyon ID'sini al
        print('🔍 Internal user tespit edildi, organizasyon ID\'si alınıyor...');
        final organizationId = await FirebaseService.getCurrentUserOrganizationId();
        
        print('🏢 Alınan organizasyon ID: $organizationId');
        
        if (organizationId != null) {
          print('🔍 Internal user ve organizasyon verisi yükleniyor...');
          
          // Internal user verilerini al
          final internalUserDoc = await FirebaseFirestore.instance
              .collection('organizations')
              .doc(organizationId)
              .collection('internal_users')
              .doc(_firebaseUser!.uid)
              .get();
          
          print('👤 Internal user dokümanı var mı: ${internalUserDoc.exists}');
          if (internalUserDoc.exists) {
            print('👤 Internal user verisi: ${internalUserDoc.data()}');
          }
          
          // Organizasyon verilerini al
          final orgDataDoc = await FirebaseFirestore.instance
              .collection('organizations')
              .doc(organizationId)
              .get();
          
          print('🏢 Organizasyon dokümanı var mı: ${orgDataDoc.exists}');
          if (orgDataDoc.exists) {
            print('🏢 Organizasyon verisi: ${orgDataDoc.data()}');
          }
          
          if (internalUserDoc.exists && orgDataDoc.exists) {
            _isOrganizationUser = false;
            _internalUserData = internalUserDoc.data();
            _organizationData = orgDataDoc.data();
            
            print('📝 Form alanları dolduruluyor...');
            _companyNameController.text = _organizationData?['name'] ?? '';
            _emailController.text = _internalUserData?['username'] ?? '';
            _phoneController.text = _internalUserData?['phone'] ?? '';
            _addressController.text = _internalUserData?['fullName'] ?? '';
            
            print('✅ İç kullanıcı yüklendi: ${_internalUserData?['fullName']}');
            print('✅ Organizasyon verisi yüklendi: ${_organizationData?['name']}');
            print('📝 Form alanları dolduruldu:');
            print('  - Şirket: ${_companyNameController.text}');
            print('  - Email: ${_emailController.text}');
            print('  - Telefon: ${_phoneController.text}');
            print('  - Ad Soyad: ${_addressController.text}');
          } else {
            print('❌ Internal user veya organizasyon verisi bulunamadı');
            print('❌ Internal user exists: ${internalUserDoc.exists}');
            print('❌ Organization exists: ${orgDataDoc.exists}');
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Kullanıcı bilgileri bulunamadı'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          }
        } else {
          print('❌ Organizasyon ID bulunamadı');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Organizasyon bilgileri bulunamadı'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      }
    } catch (e) {
      print('❌ Kullanıcı bilgileri yüklenirken hata: $e');
      print('❌ Hata stack trace: ${StackTrace.current}');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hata: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
      print('🏁 _loadUserData tamamlandı. Loading: $_isLoading');
    }
  }

  Future<void> _saveProfile() async {
    if (_formKey.currentState?.validate() != true) return;

    setState(() {
      _isSaving = true;
    });

    try {
      if (_isOrganizationUser) {
        // Organizasyon bilgilerini güncelle
        await FirebaseFirestore.instance
            .collection('organizations')
            .doc(_firebaseUser!.uid)
            .update({
          'name': _companyNameController.text.trim(),
          'phone': _phoneController.text.trim(),
          'address': _addressController.text.trim(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        
        print('✅ Organizasyon bilgileri güncellendi');
      } else {
        // İç kullanıcı bilgilerini güncelle
        final organizationId = await FirebaseService.getCurrentUserOrganizationId();
        
        if (organizationId != null) {
          await FirebaseFirestore.instance
              .collection('organizations')
              .doc(organizationId)
              .collection('internal_users')
              .doc(_firebaseUser!.uid)
              .update({
            'fullName': _addressController.text.trim(),
            'phone': _phoneController.text.trim(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
          
          print('✅ İç kullanıcı bilgileri güncellendi');
        } else {
          throw Exception('Organizasyon ID bulunamadı');
        }
      }

      setState(() {
        _isEditing = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profil başarıyla güncellendi'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('❌ Profil güncellenirken hata: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hata: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Çıkış Yap'),
        content: const Text('Hesabınızdan çıkış yapmak istediğinizden emin misiniz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await FirebaseService.logout();
              if (mounted) {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginSelectionScreen()),
                  (route) => false,
                );
              }
            },
            child: const Text('Çıkış Yap'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text(_isOrganizationUser ? 'Organizasyon Ayarları' : 'Profil Ayarları')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_firebaseUser == null) {
      return Scaffold(
        appBar: AppBar(title: Text(_isOrganizationUser ? 'Organizasyon Ayarları' : 'Profil Ayarları')),
        body: const Center(child: Text('Kullanıcı bilgisi bulunamadı')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_isOrganizationUser ? 'Organizasyon Ayarları' : 'Profil Ayarları'),
        actions: [
          if (!_isEditing)
            IconButton(
              onPressed: () {
                setState(() {
                  _isEditing = true;
                });
              },
              icon: const Icon(Icons.edit_outlined),
            ),
          if (_isEditing)
            IconButton(
              onPressed: _isSaving ? null : _saveProfile,
              icon: _isSaving 
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // Profile Avatar
              Container(
                margin: const EdgeInsets.only(bottom: 32),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 60,
                      backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
                      child: Icon(
                        _isOrganizationUser ? Icons.business : Icons.person,
                        size: 60,
                        color: Theme.of(context).primaryColor,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _isOrganizationUser 
                          ? (_organizationData?['name'] ?? 'Organizasyon')
                          : (_internalUserData?['fullName'] ?? 'Kullanıcı'),
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      _firebaseUser!.email ?? '',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: _isOrganizationUser ? Colors.blue.shade100 : Colors.green.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _isOrganizationUser ? 'Organizasyon Yöneticisi' : 'İç Kullanıcı',
                        style: TextStyle(
                          color: _isOrganizationUser ? Colors.blue.shade700 : Colors.green.shade700,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Profile Form
              _buildProfileCard(),
              
              const SizedBox(height: 24),
              
              // Account Actions
              _buildAccountActionsCard(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _isOrganizationUser ? 'Organizasyon Bilgileri' : 'Kullanıcı Bilgileri',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 20),
            
            // Organizasyon Kodu (sadece organizasyon kullanıcıları için)
            if (_isOrganizationUser) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.key, color: Colors.blue.shade700, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Organizasyon Kodu',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Colors.blue.shade700,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue.shade300),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              _firebaseUser!.uid,
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () async {
                              // Organizasyon kodunu panoya kopyala
                              await Clipboard.setData(ClipboardData(text: _firebaseUser!.uid));
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Organizasyon kodu panoya kopyalandı'),
                                    duration: Duration(seconds: 2),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                              }
                            },
                            icon: const Icon(Icons.copy, size: 18),
                            tooltip: 'Kopyala',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Bu kodu çalışanlarınızla paylaşın. Çalışanlar bu kod ile sisteme giriş yapabilir.',
                      style: TextStyle(
                        color: Colors.blue.shade600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],
            
            if (_isOrganizationUser) ...[
              TextFormField(
                controller: _companyNameController,
                enabled: _isEditing,
                decoration: const InputDecoration(
                  labelText: 'Şirket Adı',
                  prefixIcon: Icon(Icons.business),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Şirket adı gerekli';
                  }
                  return null;
                },
              ),
            ] else ...[
              TextFormField(
                controller: _addressController, // fullName için kullanıyoruz
                enabled: _isEditing,
                decoration: const InputDecoration(
                  labelText: 'Ad Soyad',
                  prefixIcon: Icon(Icons.person),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Ad soyad gerekli';
                  }
                  return null;
                },
              ),
            ],
            
            const SizedBox(height: 16),
            
            TextFormField(
              controller: _emailController,
              enabled: false, // Email değiştirilemez
              decoration: const InputDecoration(
                labelText: 'E-posta',
                prefixIcon: Icon(Icons.email),
              ),
            ),
            
            const SizedBox(height: 16),
            
            TextFormField(
              controller: _phoneController,
              enabled: _isEditing,
              decoration: const InputDecoration(
                labelText: 'Telefon',
                prefixIcon: Icon(Icons.phone),
              ),
              keyboardType: TextInputType.phone,
            ),
            
            if (_isOrganizationUser) ...[
              const SizedBox(height: 16),
              TextFormField(
                controller: _addressController,
                enabled: _isEditing,
                decoration: const InputDecoration(
                  labelText: 'Adres',
                  prefixIcon: Icon(Icons.location_on),
                ),
                maxLines: 2,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAccountActionsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Hesap İşlemleri',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('Çıkış Yap'),
              subtitle: const Text('Hesabınızdan güvenli çıkış yapın'),
              onTap: _showLogoutDialog,
            ),
            
            const Divider(),
            
            ListTile(
              leading: const Icon(Icons.delete_forever, color: Colors.red),
              title: const Text('Hesabı Sil'),
              subtitle: const Text('Hesabınızı kalıcı olarak silin'),
              onTap: _showDeleteAccountDialog,
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteAccountDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.red),
            SizedBox(width: 8),
            Text('Hesap Silme'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Hesabınızı silmek istediğinizden emin misiniz?',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            const Text('Bu işlem geri alınamaz ve aşağıdaki veriler kalıcı olarak silinir:'),
            const SizedBox(height: 8),
            Text(
              _isOrganizationUser 
                ? '• Organizasyon bilgileri\n• Tüm ürün verileri\n• Satış geçmişi\n• Çalışan hesapları\n• Tüm raporlar ve yedekler'
                : '• Kullanıcı bilgileri\n• Hesap geçmişi',
              style: TextStyle(color: Colors.grey[700]),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _showPasswordConfirmationDialog();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Hesabı Sil'),
          ),
        ],
      ),
    );
  }

  void _showPasswordConfirmationDialog() {
    final passwordController = TextEditingController();
    bool isLoading = false;
    bool obscurePassword = true;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Şifre Doğrulaması'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Hesabınızı silmek için şifrenizi girin:'),
              const SizedBox(height: 16),
              TextFormField(
                controller: passwordController,
                obscureText: obscurePassword,
                enabled: !isLoading,
                decoration: InputDecoration(
                  labelText: 'Şifre',
                  prefixIcon: const Icon(Icons.lock),
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(obscurePassword ? Icons.visibility : Icons.visibility_off),
                    onPressed: () {
                      setState(() {
                        obscurePassword = !obscurePassword;
                      });
                    },
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: isLoading ? null : () {
                passwordController.dispose();
                Navigator.pop(context);
              },
              child: const Text('İptal'),
            ),
            ElevatedButton(
              onPressed: isLoading ? null : () async {
                if (passwordController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Şifre gerekli'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                setState(() {
                  isLoading = true;
                });

                bool navigationHandled = false;

                try {
                  Map<String, dynamic> result;
                  
                  if (_isOrganizationUser) {
                    result = await FirebaseService.deleteOrganizationAccount(
                      password: passwordController.text,
                    );
                  } else {
                    result = await FirebaseService.deleteInternalUserAccount(
                      password: passwordController.text,
                    );
                  }

                  if (result['success']) {
                    // Başarılı silme - önce dialog'u kapat, sonra login sayfasına yönlendir
                    navigationHandled = true;
                    passwordController.dispose();
                    Navigator.pop(context); // Dialog'u kapat
                    
                    if (mounted) {
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(builder: (context) => const LoginSelectionScreen()),
                        (route) => false,
                      );
                      
                      // Başarı mesajını yeni sayfada göster
                      Future.delayed(const Duration(milliseconds: 100), () {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(result['message'] ?? 'Hesabınız başarıyla silindi'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      });
                    }
                  } else {
                    // Hata mesajı göster
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(result['message']),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Hata: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                } finally {
                  if (!navigationHandled) {
                    setState(() {
                      isLoading = false;
                    });
                    passwordController.dispose();
                    if (mounted) {
                      Navigator.pop(context);
                    }
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text('Hesabı Sil'),
            ),
          ],
        ),
      ),
    );
  }
} 