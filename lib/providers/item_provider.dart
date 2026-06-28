import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:geolocator/geolocator.dart';
import '../models/item.dart';
import 'dart:io';

class ItemProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  List<RentItem> _allItems = [];
  List<RentItem> get allItems => _allItems;

  Set<String> _favoriteIds = {};
  Set<String> get favoriteIds => _favoriteIds;

  // Current user location (updated when needed)
  double? _userLat;
  double? _userLng;
  double? get userLat => _userLat;
  double? get userLng => _userLng;

  double _maxRangeKm = 10.0;
  double get maxRangeKm => _maxRangeKm;

  String _searchQuery = '';
  String get searchQuery => _searchQuery;

  final Map<String, bool> _paidItems = {};

  ItemProvider() {
    _loadItems();
    _loadAverageRatings();
    _loadFavorites();
    _getCurrentLocation(); // fetch location on creation
  }

  // --- Location ---
  Future<void> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission != LocationPermission.whileInUse &&
            permission != LocationPermission.always) {
          return;
        }
      }
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      _userLat = position.latitude;
      _userLng = position.longitude;
      notifyListeners();
    } catch (e) {
      debugPrint('Location error: $e');
    }
  }

  Future<void> refreshLocation() => _getCurrentLocation();

  // --- Distance calculation ---
  double? getDistanceInKm(double lat, double lng) {
    if (_userLat == null || _userLng == null) return null;
    return _haversine(_userLat!, _userLng!, lat, lng);
  }

  double _haversine(double lat1, double lon1, double lat2, double lon2) {
    const R = 6371; // km
    double dLat = _toRadians(lat2 - lat1);
    double dLon = _toRadians(lon2 - lon1);
    double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) *
            cos(_toRadians(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);
    double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c;
  }

  double _toRadians(double degree) => degree * pi / 180;

  // In ItemProvider class

  Future<bool> isPhoneVerified() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;
    final doc = await _firestore.collection('users').doc(user.uid).get();
    return doc.data()?['phoneVerified'] == true;
  }

  Future<void> setPhoneVerified(String phone) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    await _firestore.collection('users').doc(user.uid).set({
      'phone': phone,
      'phoneVerified': true,
    }, SetOptions(merge: true));
  }

  // --- Items from Firestore ---
  // Inside ItemProvider class

  Map<String, double> _averageRatings = {};
  Map<String, double> get averageRatings => _averageRatings;

// Modify _loadItems to also load average ratings
  Future<void> _loadItems() async {
    try {
      final snapshot = await _firestore.collection('items').get();
      _allItems = snapshot.docs
          .map((doc) => RentItem.fromMap(doc.id, doc.data()))
          .toList();
      await _loadAverageRatings();
      await _loadActiveRentals();
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading items: $e');
    }
  }

  Future<void> _loadAverageRatings() async {
    for (var item in _allItems) {
      _averageRatings[item.docId!] = await getAverageRating(item.docId!);
    }
    notifyListeners();
  }

// Add a helper to fetch a user’s name by uid
  Future<String> getUserName(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    if (doc.exists && doc.data() != null) {
      return doc.data()!['name'] as String? ?? 'Unknown';
    }
    return 'Unknown';
  }

  // --- Favorites ---
  Future<void> _loadFavorites() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (doc.exists && doc.data() != null) {
        final favData = doc.data()!['favorites'] as List<dynamic>?;
        _favoriteIds = favData?.map((e) => e.toString()).toSet() ?? {};
      } else {
        await _firestore.collection('users').doc(user.uid).set({
          'email': user.email,
          'favorites': [],
        });
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading favorites: $e');
    }
  }


  Future<void> _saveFavorites() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      await _firestore.collection('users').doc(user.uid).update({
        'favorites': _favoriteIds.toList(),
      });
    } catch (e) {
      debugPrint('Error saving favorites: $e');
    }
  }

  void toggleFavorite(String itemId) {
    if (_favoriteIds.contains(itemId)) {
      _favoriteIds.remove(itemId);
    } else {
      _favoriteIds.add(itemId);
    }
    _saveFavorites();
    notifyListeners();
  }

  bool isFavorite(String itemId) => _favoriteIds.contains(itemId);

  // --- Filtering with dynamic distance ---
  List<RentItem> get filteredItems {
    // start with ALL items (including rented)
    List<RentItem> result = _allItems;

    // Apply search query
    if (_searchQuery.isNotEmpty) {
      result = result
          .where((item) =>
          item.title.toLowerCase().contains(_searchQuery.toLowerCase()))
          .toList();
    }


    // Optional: filter out rented if the user has toggled "show only available"
    if (!_showRentedItems) {
      result = result.where((item) => !isItemCurrentlyRented(item.docId!)).toList();
    }


    // Apply distance filter (within range)
    if (_userLat != null && _userLng != null) {
      List<RentItem> withinRange = [];
      for (var item in result) {
        double? dist = getDistanceInKm(item.latitude, item.longitude);
        if (dist != null && dist <= _maxRangeKm) {
          withinRange.add(item);
        }
      }
      return withinRange.isNotEmpty ? withinRange : result;
    }

    return result;
  }

  bool _showRentedItems = true;   // default: show all
  bool get showRentedItems => _showRentedItems;

  void setShowRentedItems(bool value) {
    _showRentedItems = value;
    notifyListeners();
  }

  Future<Map<String, dynamic>> getUserProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return {};
    final doc = await _firestore.collection('users').doc(user.uid).get();
    if (doc.exists && doc.data() != null) {
      return doc.data()!;
    }
    return {};
  }

  bool isItemInRange(RentItem item) {
    double? dist = getDistanceInKm(item.latitude, item.longitude);
    return dist != null && dist <= _maxRangeKm;
  }

  void setMaxRange(double range) {
    _maxRangeKm = range;
    notifyListeners();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  // --- Payment simulation (unchanged) ---
  void payForItem(String itemId) {
    _paidItems[itemId] = true;
    notifyListeners();
  }


  bool hasPaidForItem(String itemId) => _paidItems[itemId] ?? false;

  String? getContactIfPaid(String itemId) {
    if (hasPaidForItem(itemId)) {
      return _allItems.firstWhere((item) => item.docId == itemId).renterContact;
    }
    return null;
  }

  // --- Add item with location ---
  Future<String?> uploadImage(String filePath) async {
    try {
      final fileName =
          '${DateTime.now().millisecondsSinceEpoch}_${filePath.split('/').last}';
      final ref = _storage.ref().child('item_images/$fileName');
      await ref.putFile(File(filePath));
      return await ref.getDownloadURL();
    } catch (e) {
      debugPrint('Image upload error: $e');
      return null;
    }
  }

  Future<void> addItem(RentItem item, List<String> imageFilePaths) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('Must be logged in');

    // Upload all images
    List<String> uploadedUrls = [];
    for (final path in imageFilePaths) {
      final url = await uploadImage(path);
      if (url != null) uploadedUrls.add(url);
    }

    // Use the location already set in the item (from map picker)
    final data = item.toMap();
    data['imageUrls'] = uploadedUrls;
    data['ownerUid'] = user.uid;

    await _firestore.collection('items').add(data);
    await _loadItems();
  }

  // --- Get current user's items ---
  List<RentItem> get myItems {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return [];
    return _allItems.where((item) => item.ownerUid == uid).toList();
  }
  Future<void> deleteItem(String docId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    // Optional: verify that the item belongs to the current user
    await _firestore.collection('items').doc(docId).delete();
    await _loadItems(); // refresh list
    notifyListeners();
  }
  // --- Update user phone in Firestore (called after phone verification) ---
  Future<void> updateUserPhone(String phone) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    await _firestore.collection('users').doc(user.uid).set({
      'phone': phone,
      'phoneVerified': true,   // mark as verified
    }, SetOptions(merge: true));
  }
  Future<void> updateUserProfile({String? name, String? phone}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final data = <String, dynamic>{};
    if (name != null) data['name'] = name;
    if (phone != null) data['phone'] = phone;
    await _firestore.collection('users').doc(user.uid).set(data, SetOptions(merge: true));
  }

  Future<String?> getUserPhone() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;
    final doc = await _firestore.collection('users').doc(user.uid).get();
    return doc.data()?['phone'] as String?;
  }

  Future<void> addBooking({
    required String itemId,
    required String renterUid,
    required DateTime bookingDate,
    required TimeOfDay bookingTime,
    required String durationType,
    required int quantity,
    required double totalPrice,
    required String itemTitle,
    required String itemImageUrl,
    required String renterContact,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // 1. Compute the new booking start & end (including grace)
    final startDateTime = DateTime(
      bookingDate.year, bookingDate.month, bookingDate.day,
      bookingTime.hour, bookingTime.minute,
    );
    final rentalDuration = durationType == 'hour'
        ? Duration(hours: quantity)
        : Duration(days: quantity);
    final endDateTime = startDateTime.add(rentalDuration);
    final rentedUntil = endDateTime.add(const Duration(hours: 1));  // grace

    // 2. OVERLAP CHECK (add exactly this block)
    final now = DateTime.now();
    final futureBookingsSnapshot = await _firestore
        .collection('bookings')
        .where('itemId', isEqualTo: itemId)
        .where('rentedUntil', isGreaterThan: Timestamp.fromDate(now))
        .get();

    for (var doc in futureBookingsSnapshot.docs) {
      final bData = doc.data();
      final bDate = (bData['bookingDate'] as Timestamp).toDate();
      final bTimeStr = bData['bookingTime'] as String? ?? '00:00';
      final parts = bTimeStr.split(':');
      final bStart = DateTime(
        bDate.year, bDate.month, bDate.day,
        int.tryParse(parts[0]) ?? 0,
        int.tryParse(parts[1]) ?? 0,
      );
      // The blocked end time is the existing booking's rentedUntil (includes grace)
      final bBlockedEnd = (bData['rentedUntil'] as Timestamp).toDate();

      if (startDateTime.isBefore(bBlockedEnd)) {
        throw Exception(
          'This item is already booked from '
              '${bStart.toString().substring(0, 16)} to ${bBlockedEnd.toString().substring(0, 16)}. '
              'Please choose a different time.',
        );
      }
    }
    // END OVERLAP CHECK

    // 3. Get buyer phone
    final userDoc = await _firestore.collection('users').doc(user.uid).get();
    final buyerPhone = userDoc.data()?['phone'] as String? ?? '';

    // 4. Save booking
    final docRef = await _firestore.collection('bookings').add({
      'itemId': itemId,
      'renterUid': renterUid,
      'bookerUid': user.uid,
      'bookerContact': buyerPhone,
      'bookingDate': Timestamp.fromDate(bookingDate),
      'bookingTime': '${bookingTime.hour}:${bookingTime.minute}',
      'durationType': durationType,
      'quantity': quantity,
      'totalPrice': totalPrice,
      'itemTitle': itemTitle,
      'itemImageUrl': itemImageUrl,
      'renterContact': renterContact,
      'rentedUntil': Timestamp.fromDate(rentedUntil),
      'timestamp': FieldValue.serverTimestamp(),
    });

    await docRef.update({'bookingId': docRef.id});

    // 5. Update item document
    await _firestore.collection('items').doc(itemId).update({
      'rentedUntil': Timestamp.fromDate(rentedUntil),
      'currentBookerUid': user.uid,
    });

    // 6. Refresh local data
    await _loadItems();
  }



  Future<List<Map<String, dynamic>>> getUserBookings() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return [];
    final snapshot = await _firestore
        .collection('bookings')
        .where('bookerUid', isEqualTo: user.uid)
        .orderBy('timestamp', descending: true)
        .get();
    return snapshot.docs.map((doc) => doc.data()).toList();
  }

  Future<Map<String, dynamic>?> getActiveBookingForItem(String itemId) async {
    final now = DateTime.now();
    final snapshot = await _firestore
        .collection('bookings')
        .where('itemId', isEqualTo: itemId)
        .where('rentedUntil', isGreaterThan: Timestamp.fromDate(now))
        .limit(1)
        .get();
    if (snapshot.docs.isNotEmpty) {
      return snapshot.docs.first.data();
    }
    return null;
  }

  // Submit a review (one per booking)
  Future<void> submitReview({
    required String itemId,
    required String bookingId,
    required double rating,
    required String comment,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    await _firestore.collection('reviews').add({
      'itemId': itemId,
      'bookingId': bookingId,
      'reviewerUid': user.uid,
      'rating': rating,
      'comment': comment,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  Future<List<Map<String, dynamic>>> getFutureBookingsForItem(String itemId) async {
    final now = DateTime.now();
    final snapshot = await _firestore
        .collection('bookings')
        .where('itemId', isEqualTo: itemId)
        .where('rentedUntil', isGreaterThan: Timestamp.fromDate(now))
        .orderBy('bookingDate', descending: false)
        .get();

    return snapshot.docs.map((doc) => doc.data()).toList();
  }

// Check if user already reviewed a specific booking
  Future<bool> hasReviewedBooking(String bookingId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return true; // treat as reviewed to prevent double
    final snapshot = await _firestore
        .collection('reviews')
        .where('bookingId', isEqualTo: bookingId)
        .where('reviewerUid', isEqualTo: user.uid)
        .limit(1)
        .get();
    return snapshot.docs.isNotEmpty;
  }

// Get all reviews for an item
  Future<List<Map<String, dynamic>>> getReviewsForItem(String itemId) async {
    final snapshot = await _firestore
        .collection('reviews')
        .where('itemId', isEqualTo: itemId)
        .orderBy('timestamp', descending: true)
        .get();
    return snapshot.docs.map((doc) => doc.data()).toList();
  }

// Get average rating for an item
  Future<double> getAverageRating(String itemId) async {
    final snapshot = await _firestore
        .collection('reviews')
        .where('itemId', isEqualTo: itemId)
        .get();
    if (snapshot.docs.isEmpty) return 0.0;
    double total = 0;
    for (var doc in snapshot.docs) {
      total += (doc.data()['rating'] as num?)?.toDouble() ?? 0;
    }
    return total / snapshot.docs.length;
  }

  Map<String, DateTime?> _activeRentalEnds = {};
  Map<String, DateTime?> get activeRentalEnds => _activeRentalEnds;

  /// Load all future bookings that affect current availability
  Future<void> _loadActiveRentals() async {
    final now = DateTime.now();
    final snapshot = await _firestore
        .collection('bookings')
        .where('rentedUntil', isGreaterThan: Timestamp.fromDate(now))
        .get();

    Map<String, DateTime?> ends = {};
    for (var doc in snapshot.docs) {
      final data = doc.data();
      final itemId = data['itemId'] as String?;
      final rentedUntil = (data['rentedUntil'] as Timestamp?)?.toDate();
      if (itemId == null || rentedUntil == null) continue;

      // Parse booking start
      final bDate = (data['bookingDate'] as Timestamp).toDate();
      final bTimeStr = data['bookingTime'] as String? ?? '00:00';
      final parts = bTimeStr.split(':');
      final bStart = DateTime(
        bDate.year, bDate.month, bDate.day,
        int.tryParse(parts[0]) ?? 0,
        int.tryParse(parts[1]) ?? 0,
      );

      // The item is currently rented ONLY if now is between start and rentedUntil
      if (now.isAfter(bStart) && now.isBefore(rentedUntil)) {
        ends[itemId] = rentedUntil;   // show "Rented until ..." badge with grace end
      }
    }
    _activeRentalEnds = ends;
    notifyListeners();
  }

  bool isItemCurrentlyRented(String itemId) {
    return _activeRentalEnds.containsKey(itemId);
  }

  DateTime? getCurrentRentalEnd(String itemId) {
    return _activeRentalEnds[itemId];
  }



}


