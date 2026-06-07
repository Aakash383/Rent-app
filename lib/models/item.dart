class RentItem {
  final String? docId;
  final String title;
  final String description;
  final String imageUrl;
  final double pricePerHour;
  final double pricePerDay;
  final double latitude;
  final double longitude;
  final String renterContact;
  final String ownerUid;

  RentItem({
    this.docId,
    required this.title,
    required this.description,
    required this.imageUrl,
    required this.pricePerHour,
    required this.pricePerDay,
    required this.latitude,
    required this.longitude,
    required this.renterContact,
    required this.ownerUid,
  });

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'imageUrl': imageUrl,
      'pricePerHour': pricePerHour,
      'pricePerDay': pricePerDay,
      'latitude': latitude,
      'longitude': longitude,
      'renterContact': renterContact,
      'ownerUid': ownerUid,
    };
  }

  factory RentItem.fromMap(String docId, Map<String, dynamic> map) {
    return RentItem(
      docId: docId,
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      imageUrl: map['imageUrl'] ?? '',
      pricePerHour: (map['pricePerHour'] ?? 0).toDouble(),
      pricePerDay: (map['pricePerDay'] ?? 0).toDouble(),
      latitude: (map['latitude'] ?? 0).toDouble(),
      longitude: (map['longitude'] ?? 0).toDouble(),
      renterContact: map['renterContact'] ?? '',
      ownerUid: map['ownerUid'] ?? '',
    );
  }
}