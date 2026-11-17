class UserModel {
  final String id;
  final String email;
  final String fullName;
  final String? phone;

  UserModel({
    required this.id,
    required this.email,
    required this.fullName,
    this.phone,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      fullName: json['fullName']?.toString() ?? '',
      phone: json['phone']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'fullName': fullName,
      'phone': phone,
    };
  }
}

class OrganizationModel {
  final String organizationId;
  final String name;

  OrganizationModel({
    required this.organizationId,
    required this.name,
  });

  factory OrganizationModel.fromJson(Map<String, dynamic> json) {
    return OrganizationModel(
      organizationId: json['organizationId']?.toString() ?? json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Minhas Finanças',
    );
  }
}

