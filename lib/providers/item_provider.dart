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
  Future<void> _loadItems() async {
    try {
      final snapshot = await _firestore.collection('items').get();
      _allItems = snapshot.docs
          .map((doc) => RentItem.fromMap(doc.id, doc.data()))
          .toList();
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading items: $e');
    }
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
    List<RentItem> result = _allItems;

    if (_searchQuery.isNotEmpty) {
      result = result
          .where((item) =>
          item.title.toLowerCase().contains(_searchQuery.toLowerCase()))
          .toList();
    }

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

  Future<void> addItem(RentItem item, String? imageFilePath) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('Must be logged in');

    // Ensure we have location
    if (_userLat == null || _userLng == null) {
      await _getCurrentLocation();
    }
    if (_userLat == null || _userLng == null) {
      throw Exception('Location not available');
    }

    String imageUrl = item.imageUrl;
    if (imageFilePath != null) {
      final uploadedUrl = await uploadImage(imageFilePath);
      if (uploadedUrl != null) imageUrl = uploadedUrl;
    }

    await _firestore.collection('items').add({
      ...item.toMap(),
      'imageUrl': imageUrl,
      'latitude': _userLat,
      'longitude': _userLng,
      'ownerUid': user.uid,
    });

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

  Future<String?> getUserPhone() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;
    final doc = await _firestore.collection('users').doc(user.uid).get();
    return doc.data()?['phone'] as String?;
  }
}

