import 'package:flutter/material.dart';
import '../services/firebase_service.dart';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  List<Map<String, dynamic>> _users = [];
  bool _isLoading = true;
  String? _organizationId;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    try {
      print('🔍 Kullanıcılar yükleniyor...');
      _organizationId = await FirebaseService.getCurrentUserOrganizationId();
      print('🏢 Organization ID: $_organizationId');
      
      if (_organizationId != null) {
        print('📋 Firebase\'den kullanıcılar getiriliyor...');
        final users = await FirebaseService.getInternalUsers(_organizationId!);
        print('✅ ${users.length} kullanıcı bulundu');
        print('👥 Kullanıcı listesi: $users');
        
        setState(() {
          _users = users;
          _isLoading = false;
        });
      } else {
        print('❌ Organization ID null!');
        setState(() {
          _isLoading = false;
        });
        _showErrorDialog('Organizasyon ID bulunamadı');
      }
    } catch (e) {
      print('❌ Kullanıcılar yüklenirken hata: $e');
      setState(() {
        _isLoading = false;
      });
      _showErrorDialog('Kullanıcılar yüklenirken hata: $e');
    }
  }

  void _showAddUserDialog() {
    showDialog(
      context: context,
      builder: (context) => AddUserDialog(
        organizationId: _organizationId!,
        onUserAdded: _loadUsers,
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
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Tamam'),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleUserStatus(String userId, bool currentStatus) async {
    try {
      final result = await FirebaseService.toggleUserStatus(userId, !currentStatus);
      if (result['success']) {
        _loadUsers();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message'])),
        );
      } else {
        _showErrorDialog(result['message']);
      }
    } catch (e) {
      _showErrorDialog('İşlem sırasında hata: $e');
    }
  }

  void _showUserDetails(Map<String, dynamic> user) {
    showDialog(
      context: context,
      builder: (context) => UserDetailsDialog(
        user: user,
        onPasswordUpdate: _loadUsers,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kullanıcı Yönetimi'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: _showAddUserDialog,
            icon: const Icon(Icons.person_add),
            tooltip: 'Yeni Kullanıcı Ekle',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // İstatistik kartları
                Container(
                  padding: const EdgeInsets.all(16),
                  color: Colors.indigo.shade50,
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          'Toplam Kullanıcı',
                          _users.length.toString(),
                          Icons.people,
                          Colors.blue,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildStatCard(
                          'Aktif Kullanıcı',
                          _users.where((u) => u['isActive'] == true).length.toString(),
                          Icons.person_outline,
                          Colors.green,
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Kullanıcı listesi
                Expanded(
                  child: _users.isEmpty
                      ? const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.people_outline, size: 64, color: Colors.grey),
                              SizedBox(height: 16),
                              Text(
                                'Henüz kullanıcı eklenmemiş',
                                style: TextStyle(fontSize: 18, color: Colors.grey),
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Yeni kullanıcı eklemek için + butonuna basın',
                                style: TextStyle(color: Colors.grey),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _users.length,
                          itemBuilder: (context, index) {
                            final user = _users[index];
                            return _buildUserCard(user);
                          },
                        ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddUserDialog,
        backgroundColor: Colors.indigo,
        child: const Icon(Icons.person_add, color: Colors.white),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserCard(Map<String, dynamic> user) {
    final isActive = user['isActive'] ?? false;
    final lastLogin = user['lastLogin'];
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isActive ? Colors.green : Colors.grey,
          child: Icon(
            Icons.person,
            color: Colors.white,
          ),
        ),
        title: Text(
          user['displayName'] ?? 'İsimsiz',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('@${user['username']}'),
            Text(
              'Rol: ${user['role'] == 'employee' ? 'Çalışan' : user['role']}',
              style: const TextStyle(fontSize: 12),
            ),
            if (lastLogin != null)
              Text(
                'Son Giriş: ${_formatDate(lastLogin)}',
                style: const TextStyle(fontSize: 10, color: Colors.grey),
              ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Chip(
              label: Text(
                isActive ? 'Aktif' : 'Pasif',
                style: TextStyle(
                  color: isActive ? Colors.green : Colors.red,
                  fontSize: 12,
                ),
              ),
              backgroundColor: isActive ? Colors.green.shade50 : Colors.red.shade50,
            ),
            PopupMenuButton(
              itemBuilder: (context) => [
                PopupMenuItem(
                  child: Text(isActive ? 'Pasifleştir' : 'Aktifleştir'),
                  onTap: () => _toggleUserStatus(user['id'], isActive),
                ),
                PopupMenuItem(
                  child: const Text('Detaylar'),
                  onTap: () => _showUserDetails(user),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return 'Hiç';
    // Firebase Timestamp formatını handle et
    return 'Yakın zamanda'; // Basit gösterim için
  }
}

class AddUserDialog extends StatefulWidget {
  final String organizationId;
  final VoidCallback onUserAdded;

  const AddUserDialog({
    super.key,
    required this.organizationId,
    required this.onUserAdded,
  });

  @override
  State<AddUserDialog> createState() => _AddUserDialogState();
}

class _AddUserDialogState extends State<AddUserDialog> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _displayNameController = TextEditingController();
  
  bool _isLoading = false;
  bool _obscurePassword = true;
  String _selectedRole = 'employee';

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _displayNameController.dispose();
    super.dispose();
  }

  Future<void> _createUser() async {
    if (_formKey.currentState?.validate() != true) return;
    
    setState(() {
      _isLoading = true;
    });

    try {
      final result = await FirebaseService.createInternalUser(
        organizationId: widget.organizationId,
        username: _usernameController.text.trim(),
        password: _passwordController.text,
        displayName: _displayNameController.text.trim(),
        role: _selectedRole,
      );

      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        if (result['success'] == true) {
          Navigator.pop(context);
          widget.onUserAdded();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? 'Kullanıcı oluşturuldu'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          _showErrorDialog(result['message'] ?? 'Kullanıcı oluşturulamadı');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        _showErrorDialog('Bir hata oluştu: $e');
      }
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hata'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Tamam'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Yeni Kullanıcı Ekle'),
      content: SizedBox(
        width: MediaQuery.of(context).size.width * 0.8,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _displayNameController,
                enabled: !_isLoading,
                decoration: const InputDecoration(
                  labelText: 'Ad Soyad',
                  prefixIcon: Icon(Icons.person),
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Ad soyad gerekli';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              
              TextFormField(
                controller: _usernameController,
                enabled: !_isLoading,
                decoration: const InputDecoration(
                  labelText: 'Kullanıcı Adı',
                  prefixIcon: Icon(Icons.alternate_email),
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Kullanıcı adı gerekli';
                  }
                  if (value.trim().length < 3) {
                    return 'En az 3 karakter olmalı';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              
              TextFormField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                enabled: !_isLoading,
                decoration: InputDecoration(
                  labelText: 'Şifre',
                  prefixIcon: const Icon(Icons.lock),
                  suffixIcon: IconButton(
                    icon: Icon(_obscurePassword ? Icons.visibility : Icons.visibility_off),
                    onPressed: _isLoading ? null : () {
                      setState(() {
                        _obscurePassword = !_obscurePassword;
                      });
                    },
                  ),
                  border: const OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Şifre gerekli';
                  }
                  if (value.length < 4) {
                    return 'En az 4 karakter olmalı';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              
              DropdownButtonFormField<String>(
                value: _selectedRole,
                decoration: const InputDecoration(
                  labelText: 'Rol',
                  prefixIcon: Icon(Icons.badge),
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'employee', child: Text('Çalışan')),
                  DropdownMenuItem(value: 'manager', child: Text('Yönetici')),
                ],
                onChanged: _isLoading ? null : (value) {
                  setState(() {
                    _selectedRole = value ?? 'employee';
                  });
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text('İptal'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _createUser,
          child: _isLoading
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Oluştur'),
        ),
      ],
    );
  }
}

class UserDetailsDialog extends StatelessWidget {
  final Map<String, dynamic> user;
  final VoidCallback onPasswordUpdate;

  const UserDetailsDialog({
    super.key,
    required this.user,
    required this.onPasswordUpdate,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(user['displayName'] ?? 'Kullanıcı Detayları'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDetailRow('Kullanıcı Adı', '@${user['username']}'),
          _buildDetailRow('Rol', user['role'] == 'employee' ? 'Çalışan' : 'Yönetici'),
          _buildDetailRow('Durum', user['isActive'] ? 'Aktif' : 'Pasif'),
          _buildDetailRow('Oluşturma', 'Yakın zamanda'),
          if (user['lastLogin'] != null)
            _buildDetailRow('Son Giriş', 'Yakın zamanda'),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Kapat'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(context);
            _showPasswordUpdateDialog(context);
          },
          child: const Text('Şifre Değiştir'),
        ),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  void _showPasswordUpdateDialog(BuildContext context) {
    final passwordController = TextEditingController();
    bool isLoading = false;
    bool obscurePassword = true;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Şifre Değiştir'),
          content: TextFormField(
            controller: passwordController,
            obscureText: obscurePassword,
            enabled: !isLoading,
            decoration: InputDecoration(
              labelText: 'Yeni Şifre',
              prefixIcon: const Icon(Icons.lock),
              suffixIcon: IconButton(
                icon: Icon(obscurePassword ? Icons.visibility : Icons.visibility_off),
                onPressed: isLoading ? null : () {
                  setState(() {
                    obscurePassword = !obscurePassword;
                  });
                },
              ),
              border: const OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: isLoading ? null : () => Navigator.pop(dialogContext),
              child: const Text('İptal'),
            ),
            ElevatedButton(
              onPressed: isLoading ? null : () async {
                if (passwordController.text.trim().length < 4) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Şifre en az 4 karakter olmalı'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                setState(() {
                  isLoading = true;
                });

                try {
                  final result = await FirebaseService.updateUserPassword(
                    userId: user['id'],
                    newPassword: passwordController.text.trim(),
                  );

                  if (dialogContext.mounted) {
                    Navigator.pop(dialogContext);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(result['message'] ?? 'Şifre güncellendi'),
                        backgroundColor: result['success'] ? Colors.green : Colors.red,
                      ),
                    );
                    if (result['success']) {
                      onPasswordUpdate();
                    }
                  }
                } catch (e) {
                  if (dialogContext.mounted) {
                    setState(() {
                      isLoading = false;
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Hata: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              child: isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Güncelle'),
            ),
          ],
        ),
      ),
    );
  }
} 