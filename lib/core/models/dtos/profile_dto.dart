class ProfileDto {
  final String id;
  final String fullName;
  final String email;
  final String role;

  ProfileDto({
    required this.id,
    required this.fullName,
    required this.email,
    required this.role,
  });

  Map<String, dynamic> toDatabaseMap() => {
    'id': id,
    'full_name': fullName,
    'email': email,
    'role': role,
  };

  factory ProfileDto.fromDatabaseMap(Map<String, dynamic> map) => ProfileDto(
    id: map['id']?.toString() ?? '',
    fullName: map['full_name']?.toString() ?? '',
    email: map['email']?.toString() ?? '',
    role: map['role']?.toString() ?? '',
  );
}
