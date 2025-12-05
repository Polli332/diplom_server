class UserModel {
  final int id;
  final String name;
  final String email;
  final String? photo;
  final String role;
  final int? serviceId;

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.photo,
    this.serviceId,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id'].toString()) ?? 0,
      name: json['name']?.toString() ?? 'Пользователь',
      email: json['email']?.toString() ?? '',
      photo: json['photo']?.toString(),
      role: json['role']?.toString() ?? 'applicant',
      serviceId: json['serviceId'] is int ? json['serviceId'] : 
                json['serviceId'] != null ? int.tryParse(json['serviceId'].toString()) : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'email': email,
    'photo': photo,
    'role': role,
    'serviceId': serviceId,
  };

  @override
  String toString() {
    return 'UserModel{id: $id, name: $name, email: $email, role: $role}';
  }
}