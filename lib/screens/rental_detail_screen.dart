import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../providers/item_provider.dart';

class RentalDetailScreen extends StatefulWidget {
  final Map<String, dynamic> booking;
  const RentalDetailScreen({super.key, required this.booking});

  @override
  State<RentalDetailScreen> createState() => _RentalDetailScreenState();
}

class _RentalDetailScreenState extends State<RentalDetailScreen> {
  bool _submitting = false;
  double _rating = 3.0;
  final TextEditingController _commentController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final booking = widget.booking;
    final itemTitle = booking['itemTitle'] as String? ?? 'Unknown Item';
    final itemId = booking['itemId'] as String? ?? '';
    final bookingId = (booking['bookingId'] is String) ? booking['bookingId'] as String : '';
    final itemImageUrl = booking['itemImageUrl'] as String? ?? '';
    final bookingDate = (booking['bookingDate'] as Timestamp).toDate();
    final bookingTime = booking['bookingTime'] as String? ?? '00:00';
    final durationType = booking['durationType'] as String? ?? 'hour';
    final quantity = booking['quantity'] as int? ?? 1;
    final totalPrice = (booking['totalPrice'] as num?)?.toDouble() ?? 0.0;
    final renterContact = booking['renterContact'] as String? ?? 'N/A';
    final renterUid = booking['renterUid'] as String? ?? '';
    final rentedUntil = (booking['rentedUntil'] as Timestamp?)?.toDate();

    final bool contactAvailable = rentedUntil != null && DateTime.now().isBefore(rentedUntil!);
    final bool rentalEnded = rentedUntil != null && DateTime.now().isAfter(rentedUntil!);

    return Scaffold(
      appBar: AppBar(title: const Text('Rental Details')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (itemImageUrl.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(itemImageUrl, width: double.infinity, height: 200, fit: BoxFit.cover),
              )
            else
              Container(height: 200, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(itemTitle, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            _infoRow('Date', '${bookingDate.day}/${bookingDate.month}/${bookingDate.year}'),
            _infoRow('Time', bookingTime),
            _infoRow('Duration', '$quantity $durationType(s)'),
            _infoRow('Total Paid', '\$${totalPrice.toStringAsFixed(2)}'),
            const Divider(height: 24),
            const Text('Renter Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance.collection('users').doc(renterUid).get(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Text('Loading...');
                final userData = snapshot.data!.data() as Map<String, dynamic>?;
                final name = userData?['name'] ?? 'Unknown';
                final email = userData?['email'] ?? 'Not available';
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _infoRow('Name', name),
                    _infoRow('Email', email),
                    _infoRow('Phone', contactAvailable ? renterContact : 'Contact expired'),
                  ],
                );
              },
            ),
            const SizedBox(height: 16),
            const Text('Approximate Location', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            SizedBox(
              height: 200,
              child: FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance.collection('items').doc(itemId).get(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData || snapshot.data == null) return const Center(child: Text('Location unavailable'));
                  final itemData = snapshot.data!.data() as Map<String, dynamic>?;
                  final lat = (itemData?['latitude'] as num?)?.toDouble() ?? 0.0;
                  final lng = (itemData?['longitude'] as num?)?.toDouble() ?? 0.0;
                  return FlutterMap(
                    options: MapOptions(initialCenter: LatLng(lat, lng), initialZoom: 14.0),
                    children: [
                      TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'com.example.rent_app'),
                      CircleLayer(circles: [CircleMarker(point: LatLng(lat, lng), radius: 1000, color: Colors.blue.withOpacity(0.2), borderColor: Colors.blue, borderStrokeWidth: 2)]),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 24),
            if (rentedUntil != null)
              Text(
                contactAvailable
                    ? 'Contact available until: ${rentedUntil.day}/${rentedUntil.month}/${rentedUntil.year} ${rentedUntil.hour}:${rentedUntil.minute.toString().padLeft(2, '0')}'
                    : 'Contact expired',
                style: const TextStyle(fontStyle: FontStyle.italic, color: Colors.grey),
              ),
            const Divider(height: 24),
            // Review section
            if (rentalEnded)
              FutureBuilder<bool>(
                future: context.read<ItemProvider>().hasReviewedBooking(bookingId),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const Text('Checking review status...');
                  final alreadyReviewed = snapshot.data!;
                  if (alreadyReviewed) {
                    return const Text('Thank you for your review!', style: TextStyle(color: Colors.green));
                  } else {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Write a Review', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Text('Rating:'),
                            const SizedBox(width: 8),
                            Slider(
                              value: _rating,
                              min: 1,
                              max: 5,
                              divisions: 4,
                              label: _rating.toStringAsFixed(1),
                              onChanged: (val) => setState(() => _rating = val),
                            ),
                            Text(_rating.toStringAsFixed(1)),
                          ],
                        ),
                        TextField(
                          controller: _commentController,
                          decoration: const InputDecoration(
                            labelText: 'Comment (optional)',
                            border: OutlineInputBorder(),
                          ),
                          maxLines: 3,
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: _submitting
                                ? null
                                : () async {
                              setState(() => _submitting = true);
                              await context.read<ItemProvider>().submitReview(
                                itemId: itemId,
                                bookingId: bookingId,
                                rating: _rating,
                                comment: _commentController.text.trim(),
                              );
                              setState(() => _submitting = false);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Review submitted!')),
                              );
                              // force rebuild to show "thank you"
                              (context as Element).reassemble();
                            },
                            child: _submitting
                                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : const Text('Submit Review'),
                          ),
                        ),
                      ],
                    );
                  }
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
          Flexible(child: Text(value, textAlign: TextAlign.right)),
        ],
      ),
    );
  }

}