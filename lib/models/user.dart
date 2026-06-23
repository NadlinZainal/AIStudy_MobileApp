class User {
  final String id;
  final String email;
  final String name;
  final String username;
  final String? profileImageUrl;
  final int dailyCheckInStreak;
  final DateTime? lastCheckIn;

  User({
    required this.id,
    required this.email,
    required this.name,
    required this.username,
    this.profileImageUrl,
    this.dailyCheckInStreak = 0,
    this.lastCheckIn,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'email': email,
      'name': name,
      'username': username,
      'profileImageUrl': profileImageUrl,
      'dailyCheckInStreak': dailyCheckInStreak,
      'lastCheckIn': lastCheckIn?.toIso8601String(),
    };
  }

  factory User.fromMap(Map<String, dynamic> map) {
    DateTime? parseLastCheckIn(dynamic value) {
      if (value == null) return null;
      if (value is DateTime) return value;
      if (value is String) return DateTime.tryParse(value);
      try {
        return value.toDate();
      } catch (_) {
        return null;
      }
    }

    return User(
      id: map['id'],
      email: map['email'],
      name: map['name'],
      username: map['username'] ?? '',
      profileImageUrl: map['profileImageUrl'],
      dailyCheckInStreak: map['dailyCheckInStreak']?.toInt() ?? 0,
      lastCheckIn: parseLastCheckIn(map['lastCheckIn']),
    );
  }
}
