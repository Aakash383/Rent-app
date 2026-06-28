import 'package:cloud_firestore/cloud_firestore.dart';

class RentItem {
  final String? docId;
  final String title;
  final String description;
  final List<String> imageUrls;          // multiple images
  final double pricePerHour;
  final double pricePerDay;
  final double latitude;
  final double longitude;
  final String renterContact;
  final String ownerUid;
  final DateTime? rentedUntil;
  final String? currentBookerUid;

  RentItem({
    this.docId,
    required this.title,
    required this.description,
    required this.imageUrls,
    required this.pricePerHour,
    required this.pricePerDay,
    required this.latitude,
    required this.longitude,
    required this.renterContact,
    required this.ownerUid,
    this.rentedUntil,
    this.currentBookerUid,
  });



  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'imageUrls': imageUrls,
      'pricePerHour': pricePerHour,
      'pricePerDay': pricePerDay,
      'latitude': latitude,
      'longitude': longitude,
      'renterContact': renterContact,
      'ownerUid': ownerUid,
      if (rentedUntil != null) 'rentedUntil': Timestamp.fromDate(rentedUntil!),
      'currentBookerUid': currentBookerUid,
    };
  }

  factory RentItem.fromMap(String docId, Map<String, dynamic> map) {
    final imageUrlsRaw = map['imageUrls'];
    List<String> imageUrls = [];
    if (imageUrlsRaw is List) {
      imageUrls = imageUrlsRaw.map((e) => e.toString()).toList();
    } else if (map['imageUrl'] != null) {
      // backward compatibility with old single image field
      imageUrls = [map['imageUrl'].toString()];
    }
    return RentItem(
      docId: docId,
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      imageUrls: imageUrls,
      pricePerHour: (map['pricePerHour'] ?? 0).toDouble(),
      pricePerDay: (map['pricePerDay'] ?? 0).toDouble(),
      latitude: (map['latitude'] ?? 0).toDouble(),
      longitude: (map['longitude'] ?? 0).toDouble(),
      renterContact: map['renterContact'] ?? '',
      ownerUid: map['ownerUid'] ?? '',
      rentedUntil: (map['rentedUntil'] as Timestamp?)?.toDate(),
      currentBookerUid: map['currentBookerUid'] as String?,
    );
  }
}