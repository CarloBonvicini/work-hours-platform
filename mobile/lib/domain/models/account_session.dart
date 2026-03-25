class AccountUser {
  const AccountUser({
    required this.id,
    required this.email,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String email;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory AccountUser.fromJson(Map<String, dynamic> json) {
    return AccountUser(
      id: json['id'] as String,
      email: json['email'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String).toLocal(),
      updatedAt: DateTime.parse(json['updatedAt'] as String).toLocal(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'createdAt': createdAt.toUtc().toIso8601String(),
      'updatedAt': updatedAt.toUtc().toIso8601String(),
    };
  }
}

class AccountSession {
  const AccountSession({
    required this.token,
    required this.user,
    this.recoveryCode,
  });

  final String token;
  final AccountUser user;
  final String? recoveryCode;

  factory AccountSession.fromJson(Map<String, dynamic> json) {
    return AccountSession(
      token: json['token'] as String,
      user: AccountUser.fromJson(json['user'] as Map<String, dynamic>),
      recoveryCode: json['recoveryCode'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'token': token,
      'user': user.toJson(),
      if (recoveryCode != null && recoveryCode!.trim().isNotEmpty)
        'recoveryCode': recoveryCode,
    };
  }
}
