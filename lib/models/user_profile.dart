class UserProfile {
  final String uid;
  final String fullName;
  final String email;
  final bool isEmailVerified;
  final String phoneNumber;
  final bool isPhoneVerified;
  final String role; // 'user' | 'admin'
  final DateTime createdAt;
  final DateTime lastActiveAt;
  final bool isOnline;
  final String password;

  UserProfile({
    required this.uid,
    required this.fullName,
    required this.email,
    required this.isEmailVerified,
    required this.phoneNumber,
    required this.isPhoneVerified,
    this.role = 'user',
    required this.createdAt,
    required this.lastActiveAt,
    this.isOnline = true,
    this.password = '',
  });

  bool get isFullyVerified => isEmailVerified && isPhoneVerified;

  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'fullName': fullName,
      'email': email,
      'isEmailVerified': isEmailVerified,
      'phoneNumber': phoneNumber,
      'isPhoneVerified': isPhoneVerified,
      'role': role,
      'createdAt': createdAt.toIso8601String(),
      'lastActiveAt': lastActiveAt.toIso8601String(),
      'isOnline': isOnline,
      'password': password,
    };
  }

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      uid: json['uid'] as String? ?? '',
      fullName: json['fullName'] as String? ?? 'User',
      email: json['email'] as String? ?? '',
      isEmailVerified: json['isEmailVerified'] as bool? ?? false,
      phoneNumber: json['phoneNumber'] as String? ?? '',
      isPhoneVerified: json['isPhoneVerified'] as bool? ?? false,
      role: json['role'] as String? ?? 'user',
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now()
          : DateTime.now(),
      lastActiveAt: json['lastActiveAt'] != null
          ? DateTime.tryParse(json['lastActiveAt'] as String) ?? DateTime.now()
          : DateTime.now(),
      isOnline: json['isOnline'] as bool? ?? false,
      password: json['password'] as String? ?? '',
    );
  }

  UserProfile copyWith({
    String? uid,
    String? fullName,
    String? email,
    bool? isEmailVerified,
    String? phoneNumber,
    bool? isPhoneVerified,
    String? role,
    DateTime? createdAt,
    DateTime? lastActiveAt,
    bool? isOnline,
    String? password,
  }) {
    return UserProfile(
      uid: uid ?? this.uid,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      isEmailVerified: isEmailVerified ?? this.isEmailVerified,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      isPhoneVerified: isPhoneVerified ?? this.isPhoneVerified,
      role: role ?? this.role,
      createdAt: createdAt ?? this.createdAt,
      lastActiveAt: lastActiveAt ?? this.lastActiveAt,
      isOnline: isOnline ?? this.isOnline,
      password: password ?? this.password,
    );
  }
}

