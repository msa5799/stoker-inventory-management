class User {
  final int? id;
  final String email;
  final String passwordHash;
  final String firstName;
  final String lastName;
  final String? phone;
  final bool isEmailVerified;
  final String? verificationCode;
  final DateTime createdAt;
  final DateTime? lastLoginAt;

  User({
    this.id,
    required this.email,
    required this.passwordHash,
    required this.firstName,
    required this.lastName,
    this.phone,
    this.isEmailVerified = false,
    this.verificationCode,
    required this.createdAt,
    this.lastLoginAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'email': email,
      'password_hash': passwordHash,
      'first_name': firstName,
      'last_name': lastName,
      'phone': phone,
      'is_email_verified': isEmailVerified ? 1 : 0,
      'verification_code': verificationCode,
      'created_at': createdAt.toIso8601String(),
      'last_login_at': lastLoginAt?.toIso8601String(),
    };
  }

  factory User.fromMap(Map<String, dynamic> map) {
    return User(
      id: map['id']?.toInt(),
      email: map['email'] ?? '',
      passwordHash: map['password_hash'] ?? '',
      firstName: map['first_name'] ?? '',
      lastName: map['last_name'] ?? '',
      phone: map['phone'],
      isEmailVerified: (map['is_email_verified'] ?? 0) == 1,
      verificationCode: map['verification_code'],
      createdAt: DateTime.parse(map['created_at']),
      lastLoginAt: map['last_login_at'] != null 
          ? DateTime.parse(map['last_login_at']) 
          : null,
    );
  }

  String get fullName => '$firstName $lastName';

  User copyWith({
    int? id,
    String? email,
    String? passwordHash,
    String? firstName,
    String? lastName,
    String? phone,
    bool? isEmailVerified,
    String? verificationCode,
    DateTime? createdAt,
    DateTime? lastLoginAt,
  }) {
    return User(
      id: id ?? this.id,
      email: email ?? this.email,
      passwordHash: passwordHash ?? this.passwordHash,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      phone: phone ?? this.phone,
      isEmailVerified: isEmailVerified ?? this.isEmailVerified,
      verificationCode: verificationCode ?? this.verificationCode,
      createdAt: createdAt ?? this.createdAt,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
    );
  }
} 