class KycDocumentDto {
  final String id;
  final String sellerStoreId;
  final String documentType;
  final String documentUrl;
  final String status;

  KycDocumentDto({
    required this.id,
    required this.sellerStoreId,
    required this.documentType,
    required this.documentUrl,
    this.status = 'Pending',
  });

  Map<String, dynamic> toDatabaseMap() => {
    'id': id,
    'seller_store_id': sellerStoreId,
    'document_type': documentType,
    'document_url': documentUrl,
    'status': status,
  };

  factory KycDocumentDto.fromDatabaseMap(Map<String, dynamic> map) => KycDocumentDto(
    id: map['id']?.toString() ?? '',
    sellerStoreId: map['seller_store_id']?.toString() ?? '',
    documentType: map['document_type']?.toString() ?? '',
    documentUrl: map['document_url']?.toString() ?? '',
    status: map['status']?.toString() ?? 'Pending',
  );
}
