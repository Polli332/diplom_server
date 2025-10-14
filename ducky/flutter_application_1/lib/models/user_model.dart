class UserModel {
  final int id;
  final String name;
  final String email;
  final String? photo;
  final String role;

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.photo,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as int? ?? 0,
      name: json['name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      photo: json['photo'] as String?,
      role: json['role'] as String? ?? 'applicant',
    );
  }

  factory UserModel.fromMap(Map<String, dynamic> map, String role) {
    return UserModel(
      id: map['id'] as int? ?? 0,
      name: map['name'] as String? ?? '',
      email: map['email'] as String? ?? '',
      photo: map['photo'] as String?,
      role: role,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'photo': photo,
        'role': role,
      };

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'email': email,
        'photo': photo,
        'role': role,
      };

  @override
  String toString() {
    return 'UserModel{id: $id, name: $name, email: $email, role: $role}';
  }
}