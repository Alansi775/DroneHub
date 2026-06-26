class UserModel {
  final String id;
  final String name;
  final String email;
  final String? avatar;
  final String role;
  final String? phone;
  final String? addressLine1;
  final String? addressLine2;
  final String? city;
  final String? state;
  final String? country;
  final String? postalCode;

  const UserModel({
    required this.id,
    required this.name,
    required this.email,
    this.avatar,
    required this.role,
    this.phone,
    this.addressLine1,
    this.addressLine2,
    this.city,
    this.state,
    this.country,
    this.postalCode,
  });

  bool get isAdmin => role == 'admin';

  bool get hasCompleteAddress =>
      addressLine1 != null && city != null && country != null;

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
        id: json['id'],
        name: json['name'],
        email: json['email'],
        avatar: json['avatar'],
        role: json['role'] ?? 'customer',
        phone: json['phone'],
        addressLine1: json['address_line1'],
        addressLine2: json['address_line2'],
        city: json['city'],
        state: json['state'],
        country: json['country'],
        postalCode: json['postal_code'],
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'avatar': avatar,
        'role': role,
        'phone': phone,
        'address_line1': addressLine1,
        'address_line2': addressLine2,
        'city': city,
        'state': state,
        'country': country,
        'postal_code': postalCode,
      };

  UserModel copyWith({
    String? name,
    String? phone,
    String? addressLine1,
    String? addressLine2,
    String? city,
    String? state,
    String? country,
    String? postalCode,
  }) =>
      UserModel(
        id: id,
        name: name ?? this.name,
        email: email,
        avatar: avatar,
        role: role,
        phone: phone ?? this.phone,
        addressLine1: addressLine1 ?? this.addressLine1,
        addressLine2: addressLine2 ?? this.addressLine2,
        city: city ?? this.city,
        state: state ?? this.state,
        country: country ?? this.country,
        postalCode: postalCode ?? this.postalCode,
      );
}
