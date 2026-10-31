class CategoryDto {
  final String id;
  final String name;
  final String? iconUrl;
  final String? parentId;
  final bool isActive;

  CategoryDto({
    required this.id,
    required this.name,
    this.iconUrl,
    this.parentId,
    this.isActive = true,
  });

  Map<String, dynamic> toDatabaseMap() => {
    'id': id,
    'name': name,
    'icon_url': iconUrl,
    'parent_id': parentId,
    'is_active': isActive,
  };

  factory CategoryDto.fromDatabaseMap(Map<String, dynamic> map) => CategoryDto(
    id: map['id']?.toString() ?? '',
    name: map['name']?.toString() ?? '',
    iconUrl: map['icon_url']?.toString(),
    parentId: map['parent_id']?.toString(),
    isActive: map['is_active'] == true,
  );
}
