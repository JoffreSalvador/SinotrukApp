class Profile {
  final String id;
  final String name;
  final String username;
  final String role;
  final bool isActive;

  const Profile({
    required this.id,
    required this.name,
    required this.username,
    required this.role,
    this.isActive = true,
  });

  bool get isAdmin => role == 'admin';
  bool get isDriver => role == 'driver';

  factory Profile.fromMap(Map<String, dynamic> map) => Profile(
        id: map['id'] as String,
        name: (map['name'] ?? '') as String,
        username: (map['username'] ?? '') as String,
        role: (map['role'] ?? 'driver') as String,
        isActive: map['is_active'] == null || map['is_active'] == 1 ||
            map['is_active'] == true,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'username': username,
        'role': role,
        'is_active': isActive,
      };
}
