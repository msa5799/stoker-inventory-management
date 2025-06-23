import 'package:flutter/material.dart';
import 'dashboard_screen.dart';
import 'products_screen.dart';
import 'sales_screen.dart';
import 'analytics_screen.dart';
import 'backup_screen.dart';
import 'subscription_screen.dart';
import 'profile_screen.dart';
import 'settings_screen.dart';
import 'user_management_screen.dart';
import '../services/auth_service.dart';
import '../services/firebase_service.dart';
import '../services/notification_service.dart';
import 'auth/login_selection_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/sync_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  final AuthService _authService = AuthService();
  bool _isOrganizationUser = false;
  Map<String, dynamic>? _currentUserData;
  bool _isSyncing = false;
  String _syncStatus = 'Hazır';

  final List<Widget> _screens = [
    const DashboardScreen(),
    const ProductsScreen(),
    const SalesScreen(),
    const AnalyticsScreen(),
    const BackupScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _checkUserType();
    _loadDashboardData();
    _setupSyncListener();
  }

  Future<void> _checkUserType() async {
    try {
      final firebaseUser = FirebaseService.currentUser;
      if (firebaseUser == null) {
        setState(() {
          _isOrganizationUser = false;
        });
        return;
      }

      print('🔍 Kullanıcı tipi kontrol ediliyor...');
      print('🆔 Firebase User UID: ${firebaseUser.uid}');

      // Önce organizasyon kullanıcısı mı kontrol et
      final orgDoc = await FirebaseFirestore.instance
          .collection('organizations')
          .doc(firebaseUser.uid)
          .get();

      if (orgDoc.exists) {
        // Bu bir organizasyon yöneticisi
        print('✅ Organizasyon yöneticisi tespit edildi');
        setState(() {
          _isOrganizationUser = true;
        });
      } else {
        // Bu bir internal user olabilir
        print('🔍 Internal user kontrol ediliyor...');
        setState(() {
          _isOrganizationUser = false;
        });
      }
    } catch (e) {
      print('❌ Kullanıcı tipi kontrol edilirken hata: $e');
      setState(() {
        _isOrganizationUser = false;
      });
    }
  }

  Future<void> _loadDashboardData() async {
    // Dashboard data loading logic
    print("Dashboard data loaded");
  }

  void _setupSyncListener() {
    SyncService().onSyncStatusChanged = (isOnline, message) {
      if (mounted) {
        setState(() {
          _syncStatus = message;
          _isSyncing = message.contains('başlatılıyor') || message.contains('ediliyor');
        });
      }
    };
  }

  void _showUserMenu() {
    final user = _authService.currentUser;
    final isGuest = _authService.isGuest;
    final screenHeight = MediaQuery.of(context).size.height;
    final isSmallScreen = screenHeight < 700;
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      constraints: BoxConstraints(
        maxHeight: screenHeight * (isSmallScreen ? 0.9 : 0.85),
      ),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Container(
          constraints: BoxConstraints(
            maxHeight: screenHeight * (isSmallScreen ? 0.85 : 0.8),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle bar
                Container(
                  margin: EdgeInsets.only(
                    top: 8, 
                    bottom: isSmallScreen ? 12 : 16,
                  ),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                
                Container(
                  padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
                  decoration: BoxDecoration(
                    color: isGuest 
                        ? Colors.orange[50] 
                        : _isOrganizationUser
                            ? Colors.blue[50]
                            : Colors.green[50],
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                    ),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: isSmallScreen ? 20 : 24,
                        backgroundColor: isGuest 
                            ? Colors.orange 
                            : _isOrganizationUser
                                ? Colors.blue
                                : Colors.green,
                        child: Icon(
                          isGuest 
                              ? Icons.person_outline 
                              : _isOrganizationUser
                                  ? Icons.business
                                  : Icons.person, 
                          color: Colors.white,
                          size: isSmallScreen ? 20 : 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      if (user != null || FirebaseService.currentUser != null) ...[
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _isOrganizationUser 
                                    ? (FirebaseService.currentUserEmail ?? 'Kurumsal Kullanıcı')
                                    : (user?.fullName ?? 'Internal User'),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: isSmallScreen ? 14 : 16,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                _isOrganizationUser 
                                    ? 'Organizasyon Yöneticisi'
                                    : isGuest 
                                        ? 'Misafir Kullanıcı' 
                                        : 'Çalışan Kullanıcı',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: isSmallScreen ? 12 : 14,
                                ),
                              ),
                              if (isGuest) ...[
                                SizedBox(height: isSmallScreen ? 2 : 4),
                                Text(
                                  'Kayıt olarak tüm özellikleri kullanın!',
                                  style: TextStyle(
                                    color: Colors.orange[700],
                                    fontSize: isSmallScreen ? 10 : 12,
                                    fontStyle: FontStyle.italic,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ] else ...[
                        Expanded(
                          child: Text(
                            'Misafir Kullanıcı',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: isSmallScreen ? 14 : 16,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                
                // Organization user specific menu items
                if (_isOrganizationUser) ...[
                  ListTile(
                    dense: isSmallScreen,
                    leading: const Icon(Icons.people, color: Colors.indigo),
                    title: Text(
                      '👥 Kullanıcı Yönetimi',
                      style: TextStyle(fontSize: isSmallScreen ? 14 : 16),
                    ),
                    subtitle: Text(
                      'Çalışan hesapları oluştur ve yönet',
                      style: TextStyle(fontSize: isSmallScreen ? 12 : 14),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const UserManagementScreen()),
                      );
                    },
                  ),
                  const Divider(),
                ],
                
                if (isGuest) ...[
                  // Guest user upgrade options
                  ListTile(
                    dense: isSmallScreen,
                    leading: const Icon(Icons.person_add, color: Colors.green),
                    title: Text(
                      'Kayıt Ol',
                      style: TextStyle(fontSize: isSmallScreen ? 14 : 16),
                    ),
                    subtitle: Text(
                      'Hesap oluştur ve verilerini kaydet',
                      style: TextStyle(fontSize: isSmallScreen ? 12 : 14),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(builder: (context) => const LoginSelectionScreen()),
                        (route) => false,
                      );
                    },
                  ),
                  const Divider(),
                ] else ...[
                  // Regular user menu items
                  
                  // Premium Abonelik - SADECE organizasyon yöneticileri için
                  if (_isOrganizationUser) ...[
                    ListTile(
                      dense: isSmallScreen,
                      leading: const Icon(Icons.diamond, color: Colors.amber),
                      title: Text(
                        '💎 Premium Abonelik',
                        style: TextStyle(fontSize: isSmallScreen ? 14 : 16),
                      ),
                      subtitle: Text(
                        'Organizasyon premium yönetimi',
                        style: TextStyle(fontSize: isSmallScreen ? 12 : 14),
                      ),
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const SubscriptionScreen()),
                        );
                      },
                    ),
                    const Divider(),
                  ],
                  
                  ListTile(
                    dense: isSmallScreen,
                    leading: const Icon(Icons.account_circle),
                    title: Text(
                      _isOrganizationUser ? 'Organizasyon Ayarları' : 'Profil Ayarları',
                      style: TextStyle(fontSize: isSmallScreen ? 14 : 16),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const ProfileScreen()),
                      );
                    },
                  ),
                  if (!_isOrganizationUser) ...[
                    ListTile(
                      dense: isSmallScreen,
                      leading: const Icon(Icons.security),
                      title: Text(
                        'Şifre Değiştir',
                        style: TextStyle(fontSize: isSmallScreen ? 14 : 16),
                      ),
                      onTap: () {
                        Navigator.pop(context);
                        _showChangePasswordDialog();
                      },
                    ),
                  ],
                  ListTile(
                    dense: isSmallScreen,
                    leading: const Icon(Icons.settings),
                    title: Text(
                      'Uygulama Ayarları',
                      style: TextStyle(fontSize: isSmallScreen ? 14 : 16),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const SettingsScreen()),
                      );
                    },
                  ),
                ],
                
                ListTile(
                  dense: isSmallScreen,
                  leading: const Icon(Icons.backup),
                  title: Text(
                    'Yedekleme',
                    style: TextStyle(fontSize: isSmallScreen ? 14 : 16),
                  ),
                  subtitle: isGuest ? Text(
                    'Sınırlı erişim',
                    style: TextStyle(fontSize: isSmallScreen ? 12 : 14),
                  ) : null,
                  onTap: () {
                    Navigator.pop(context);
                    if (isGuest) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Yedekleme özelliği için kayıt olmanız gerekiyor'),
                          backgroundColor: Colors.orange,
                        ),
                      );
                    } else {
                      setState(() {
                        _currentIndex = 4; // Backup screen index
                      });
                    }
                  },
                ),
                const Divider(),
                ListTile(
                  dense: isSmallScreen,
                  leading: Icon(
                    isGuest ? Icons.exit_to_app : Icons.logout, 
                    color: Colors.red
                  ),
                  title: Text(
                    isGuest ? 'Çık' : 'Çıkış Yap',
                    style: TextStyle(
                      color: Colors.red,
                      fontSize: isSmallScreen ? 14 : 16,
                    ),
                  ),
                  onTap: () async {
                    Navigator.pop(context);
                    await _logout();
                  },
                ),
                SizedBox(height: isSmallScreen ? 12 : 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showChangePasswordDialog() {
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    bool obscureCurrentPassword = true;
    bool obscureNewPassword = true;
    bool obscureConfirmPassword = true;
    
    final screenHeight = MediaQuery.of(context).size.height;
    final isSmallScreen = screenHeight < 700;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(
            'Şifre Değiştir',
            style: TextStyle(fontSize: isSmallScreen ? 18 : 20),
          ),
          content: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: screenHeight * (isSmallScreen ? 0.5 : 0.6),
              maxWidth: MediaQuery.of(context).size.width * 0.9,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: currentPasswordController,
                    obscureText: obscureCurrentPassword,
                    style: TextStyle(fontSize: isSmallScreen ? 14 : 16),
                    decoration: InputDecoration(
                      labelText: 'Mevcut Şifre',
                      labelStyle: TextStyle(fontSize: isSmallScreen ? 14 : 16),
                      border: const OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: isSmallScreen ? 8 : 12,
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(
                          obscureCurrentPassword ? Icons.visibility : Icons.visibility_off,
                          size: isSmallScreen ? 20 : 24,
                        ),
                        onPressed: () => setState(() => obscureCurrentPassword = !obscureCurrentPassword),
                      ),
                    ),
                  ),
                  SizedBox(height: isSmallScreen ? 12 : 16),
                  TextFormField(
                    controller: newPasswordController,
                    obscureText: obscureNewPassword,
                    style: TextStyle(fontSize: isSmallScreen ? 14 : 16),
                    decoration: InputDecoration(
                      labelText: 'Yeni Şifre',
                      labelStyle: TextStyle(fontSize: isSmallScreen ? 14 : 16),
                      border: const OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: isSmallScreen ? 8 : 12,
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(
                          obscureNewPassword ? Icons.visibility : Icons.visibility_off,
                          size: isSmallScreen ? 20 : 24,
                        ),
                        onPressed: () => setState(() => obscureNewPassword = !obscureNewPassword),
                      ),
                    ),
                  ),
                  SizedBox(height: isSmallScreen ? 12 : 16),
                  TextFormField(
                    controller: confirmPasswordController,
                    obscureText: obscureConfirmPassword,
                    style: TextStyle(fontSize: isSmallScreen ? 14 : 16),
                    decoration: InputDecoration(
                      labelText: 'Yeni Şifre Tekrar',
                      labelStyle: TextStyle(fontSize: isSmallScreen ? 14 : 16),
                      border: const OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: isSmallScreen ? 8 : 12,
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(
                          obscureConfirmPassword ? Icons.visibility : Icons.visibility_off,
                          size: isSmallScreen ? 20 : 24,
                        ),
                        onPressed: () => setState(() => obscureConfirmPassword = !obscureConfirmPassword),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'İptal',
                style: TextStyle(fontSize: isSmallScreen ? 14 : 16),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                if (newPasswordController.text != confirmPasswordController.text) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Yeni şifreler eşleşmiyor')),
                  );
                  return;
                }

                final result = await _authService.changePassword(
                  currentPassword: currentPasswordController.text,
                  newPassword: newPasswordController.text,
                );

                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(result['message']),
                    backgroundColor: result['success'] ? Colors.green : Colors.red,
                  ),
                );
              },
              child: Text(
                'Değiştir',
                style: TextStyle(fontSize: isSmallScreen ? 14 : 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Çıkış Yap'),
        content: const Text('Çıkış yapmak istediğinizden emin misiniz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Çıkış Yap'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        // Firebase logout
        if (_isOrganizationUser) {
          await FirebaseService.logout();
        }
        // Local auth logout
        await _authService.logout();
        
        if (mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const LoginSelectionScreen()),
            (route) => false,
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Çıkış sırasında hata: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Stoker'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 1,
        actions: [
          // Sync durumu göstergesi
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: _isSyncing ? Colors.orange.shade100 : Colors.green.shade100,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _isSyncing ? Colors.orange : Colors.green,
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _isSyncing ? Icons.sync : Icons.cloud_done,
                  size: 16,
                  color: _isSyncing ? Colors.orange.shade700 : Colors.green.shade700,
                ),
                const SizedBox(width: 4),
                Text(
                  _isSyncing ? 'Senkronize ediliyor...' : 'Senkronize',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: _isSyncing ? Colors.orange.shade700 : Colors.green.shade700,
                  ),
                ),
              ],
            ),
          ),
          // Manuel senkronizasyon butonu
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isSyncing ? null : _performManualSync,
            tooltip: 'Manuel Senkronizasyon',
          ),
          // Premium butonu - SADECE organizasyon yöneticileri için
          if (!_authService.isGuest && _isOrganizationUser) ...[
            IconButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const SubscriptionScreen()),
                );
              },
              icon: const Icon(Icons.diamond, color: Colors.amber),
              tooltip: 'Premium Abonelik',
            ),
          ],
          IconButton(
            onPressed: _showUserMenu,
            icon: CircleAvatar(
              backgroundColor: _authService.isGuest ? Colors.orange : Colors.blue,
              radius: 16,
              child: Icon(
                _authService.isGuest ? Icons.person_outline : Icons.person,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        selectedItemColor: Theme.of(context).primaryColor,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: 'Panel',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.inventory),
            label: 'Ürünler',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.receipt_long),
            label: 'Satışlar',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.analytics),
            label: 'Analitik',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.backup),
            label: 'Yedekleme',
          ),
        ],
      ),
    );
  }

  Future<void> _performManualSync() async {
    try {
      setState(() {
        _isSyncing = true;
        _syncStatus = 'Manuel senkronizasyon başlatılıyor...';
      });

      await SyncService().forceSyncAll();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Tüm veriler Firebase ile senkronize edildi'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Senkronizasyon hatası: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
} 