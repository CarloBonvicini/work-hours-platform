class UserProfile {
  const UserProfile({
    required this.id,
    required this.fullName,
    required this.dailyTargetMinutes,
  });

  final String id;
  final String fullName;
  final int dailyTargetMinutes;

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String,
      fullName: json['fullName'] as String,
      dailyTargetMinutes: json['dailyTargetMinutes'] as int,
    );
  }
}
