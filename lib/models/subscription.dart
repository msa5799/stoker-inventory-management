import 'package:cloud_firestore/cloud_firestore.dart';

class Subscription {
  final String? id;
  final String organizationId;
  final bool isPremium;
  final DateTime? premiumActivatedAt;
  final DateTime? premiumExpiresAt;
  final String? currentActivationCode;
  final DateTime? lastCodeRequestAt;
  final int totalActivations;
  final DateTime createdAt;
  final DateTime? updatedAt;

  Subscription({
    this.id,
    required this.organizationId,
    this.isPremium = false,
    this.premiumActivatedAt,
    this.premiumExpiresAt,
    this.currentActivationCode,
    this.lastCodeRequestAt,
    this.totalActivations = 0,
    required this.createdAt,
    this.updatedAt,
  });

  // Ücretsiz deneme süresi (30 gün)
  bool get isInFreeTrial {
    final now = DateTime.now();
    final thirtyDaysAfterCreation = createdAt.add(const Duration(days: 30));
    return now.isBefore(thirtyDaysAfterCreation) && !isPremium;
  }

  // Premium süresi dolmuş mu?
  bool get isPremiumExpired {
    if (!isPremium || premiumExpiresAt == null) return false;
    return DateTime.now().isAfter(premiumExpiresAt!);
  }

  // Aktif kullanıcı mı? (Free trial veya geçerli premium)
  bool get isActive {
    return isInFreeTrial || (isPremium && !isPremiumExpired);
  }

  // Paid user mı? (En az bir kez aktivasyon kodu girmiş)
  bool get isPaidUser {
    return totalActivations > 0;
  }

  // Premium süresinin kalan gün sayısı
  int get remainingDays {
    if (!isPremium || premiumExpiresAt == null) return 0;
    final now = DateTime.now();
    final difference = premiumExpiresAt!.difference(now);
    return difference.inDays > 0 ? difference.inDays : 0;
  }

  // Ücretsiz deneme süresinin kalan gün sayısı
  int get freeTrialRemainingDays {
    if (isPremium) return 0;
    final now = DateTime.now();
    final thirtyDaysAfterCreation = createdAt.add(const Duration(days: 30));
    final difference = thirtyDaysAfterCreation.difference(now);
    return difference.inDays > 0 ? difference.inDays : 0;
  }

  // Aktivasyon kodu talep edebilir mi? (Premium bitimine 1 günden az kaldığında veya premium değilse)
  bool get canRequestActivationCode {
    if (!isPremium) return true; // Premium değilse talep edebilir
    if (premiumExpiresAt == null) return true;
    
    final now = DateTime.now();
    final oneDayBeforeExpiry = premiumExpiresAt!.subtract(const Duration(days: 1));
    
    // Şu an premium bitimine 1 günden az varsa talep edebilir
    return now.isAfter(oneDayBeforeExpiry);
  }

  // Premium bitimine kaç saat kaldığını döner (son 24 saat için)
  int get remainingHoursToExpiry {
    if (!isPremium || premiumExpiresAt == null) return 0;
    final now = DateTime.now();
    final difference = premiumExpiresAt!.difference(now);
    return difference.inHours > 0 ? difference.inHours : 0;
  }

  // Firebase Firestore için Map'e dönüştür
  Map<String, dynamic> toFirebaseMap() {
    return {
      'organizationId': organizationId,
      'isPremium': isPremium,
      'premiumActivatedAt': premiumActivatedAt != null ? Timestamp.fromDate(premiumActivatedAt!) : null,
      'premiumExpiresAt': premiumExpiresAt != null ? Timestamp.fromDate(premiumExpiresAt!) : null,
      'currentActivationCode': currentActivationCode,
      'lastCodeRequestAt': lastCodeRequestAt != null ? Timestamp.fromDate(lastCodeRequestAt!) : null,
      'totalActivations': totalActivations,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
    };
  }

  // Firebase Firestore'dan oluştur
  factory Subscription.fromFirebaseMap(Map<String, dynamic> map, String organizationId) {
    return Subscription(
      organizationId: organizationId,
      isPremium: map['isPremium'] ?? false,
      premiumActivatedAt: map['premiumActivatedAt'] != null 
          ? (map['premiumActivatedAt'] as Timestamp).toDate()
          : null,
      premiumExpiresAt: map['premiumExpiresAt'] != null 
          ? (map['premiumExpiresAt'] as Timestamp).toDate()
          : null,
      currentActivationCode: map['currentActivationCode'],
      lastCodeRequestAt: map['lastCodeRequestAt'] != null 
          ? (map['lastCodeRequestAt'] as Timestamp).toDate()
          : null,
      totalActivations: map['totalActivations'] ?? 0,
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      updatedAt: map['updatedAt'] != null 
          ? (map['updatedAt'] as Timestamp).toDate()
          : null,
    );
  }

  // Eski SQLite sistemi için (geriye uyumluluk)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'organization_id': organizationId,
      'is_premium': isPremium ? 1 : 0,
      'premium_activated_at': premiumActivatedAt?.toIso8601String(),
      'premium_expires_at': premiumExpiresAt?.toIso8601String(),
      'current_activation_code': currentActivationCode,
      'last_code_request_at': lastCodeRequestAt?.toIso8601String(),
      'total_activations': totalActivations,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  // Eski SQLite sistemi için (geriye uyumluluk)
  factory Subscription.fromMap(Map<String, dynamic> map) {
    return Subscription(
      id: map['id']?.toString(),
      organizationId: map['organization_id']?.toString() ?? map['user_id']?.toString() ?? '',
      isPremium: (map['is_premium'] ?? 0) == 1,
      premiumActivatedAt: map['premium_activated_at'] != null 
          ? DateTime.parse(map['premium_activated_at']) 
          : null,
      premiumExpiresAt: map['premium_expires_at'] != null 
          ? DateTime.parse(map['premium_expires_at']) 
          : null,
      currentActivationCode: map['current_activation_code'],
      lastCodeRequestAt: map['last_code_request_at'] != null 
          ? DateTime.parse(map['last_code_request_at']) 
          : null,
      totalActivations: map['total_activations']?.toInt() ?? 0,
      createdAt: DateTime.parse(map['created_at']),
      updatedAt: map['updated_at'] != null 
          ? DateTime.parse(map['updated_at']) 
          : null,
    );
  }

  Subscription copyWith({
    String? id,
    String? organizationId,
    bool? isPremium,
    DateTime? premiumActivatedAt,
    DateTime? premiumExpiresAt,
    String? currentActivationCode,
    DateTime? lastCodeRequestAt,
    int? totalActivations,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Subscription(
      id: id ?? this.id,
      organizationId: organizationId ?? this.organizationId,
      isPremium: isPremium ?? this.isPremium,
      premiumActivatedAt: premiumActivatedAt ?? this.premiumActivatedAt,
      premiumExpiresAt: premiumExpiresAt ?? this.premiumExpiresAt,
      currentActivationCode: currentActivationCode ?? this.currentActivationCode,
      lastCodeRequestAt: lastCodeRequestAt ?? this.lastCodeRequestAt,
      totalActivations: totalActivations ?? this.totalActivations,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
} 