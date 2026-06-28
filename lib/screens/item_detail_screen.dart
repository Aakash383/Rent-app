import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../providers/item_provider.dart';
import '../models/item.dart';
import 'booking_screen.dart';

class ItemDetailScreen extends StatelessWidget {
  final RentItem item;
  const ItemDetailScreen({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ItemProvider>();
    final isFav = provider.isFavorite(item.docId!);
    final rented = provider.isItemCurrentlyRented(item.docId!);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Item Details'),
        actions: [
          IconButton(
            icon: Icon(
              isFav ? Icons.favorite : Icons.favorite_border,
              color: isFav ? Colors.red : null,
            ),
            onPressed: () => provider.toggleFavorite(item.docId!),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Swipeable images
            SizedBox(
              height: 300,
              width: double.infinity,
              child: item.imageUrls.isNotEmpty
                  ? PageView.builder(
                itemCount: item.imageUrls.length,
                itemBuilder: (_, index) => Image.network(
                  item.imageUrls[index],
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: Colors.grey.shade300,
                    child: const Icon(Icons.image_not_supported, size: 64),
                  ),
                ),
              )
                  : Container(
                color: Colors.grey.shade300,
                child: const Icon(Icons.image_not_supported, size: 64),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (rented)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.red.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text('Rented', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                    ),
                  const SizedBox(height: 8),
                  Text(item.title, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Consumer<ItemProvider>(
                    builder: (context, provider, _) {
                      final dist = provider.getDistanceInKm(item.latitude, item.longitude);
                      return Row(
                        children: [
                          const Icon(Icons.location_on, size: 18, color: Colors.grey),
                          const SizedBox(width: 4),
                          Text(
                            dist != null ? '~ ${dist.toStringAsFixed(1)} km away' : '...',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey.shade700),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  Text(item.description, style: Theme.of(context).textTheme.bodyLarge),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(child: _PriceOption(label: 'Per Hour', price: item.pricePerHour)),
                      const SizedBox(width: 12),
                      Expanded(child: _PriceOption(label: 'Per Day', price: item.pricePerDay)),
                    ],
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => BookingScreen(item: item)),
                        );
                      },
                      icon: const Icon(Icons.calendar_today),
                      label: const Text('Book Now'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text('Approximate Location', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 200,
                    width: double.infinity,
                    child: FlutterMap(
                      options: MapOptions(
                        initialCenter: LatLng(item.latitude, item.longitude),
                        initialZoom: 14.0,
                        interactionOptions: const InteractionOptions(flags: ~InteractiveFlag.rotate),
                      ),
                      children: [
                        TileLayer(
                          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'com.example.rent_app',
                        ),
                        CircleLayer(
                          circles: [
                            CircleMarker(
                              point: LatLng(item.latitude, item.longitude),
                              radius: 1000, // 1 km radius
                              color: Colors.blue.withOpacity(0.2),
                              borderColor: Colors.blue,
                              borderStrokeWidth: 2,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  ExpansionTile(
                    title: FutureBuilder<double>(
                      future: provider.getAverageRating(item.docId!),
                      builder: (context, snapshot) {
                        final avg = snapshot.data ?? 0.0;
                        return Row(
                          children: [
                            const Icon(Icons.star, color: Colors.amber, size: 20),
                            const SizedBox(width: 4),
                            Text(avg.toStringAsFixed(1),
                                style: const TextStyle(fontWeight: FontWeight.bold)),
                            const Text('  Reviews'),
                          ],
                        );
                      },
                    ),
                    children: [
                      FutureBuilder<List<Map<String, dynamic>>>(
                        future: provider.getReviewsForItem(item.docId!),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) {
                            return const Padding(
                            padding: EdgeInsets.all(16),
                            child: Center(child: CircularProgressIndicator()),
                          );
                          }
                          final reviews = snapshot.data!;
                          if (reviews.isEmpty) {
                            return const Padding(
                            padding: EdgeInsets.all(16),
                            child: Text('No reviews yet.'),
                          );
                          }
                          return Column(
                            children: reviews.map((review) {
                              final rating = (review['rating'] as num?)?.toDouble() ?? 0;
                              final comment = review['comment'] as String? ?? '';
                              final reviewerUid = review['reviewerUid'] as String? ?? '';
                              return FutureBuilder<String>(
                                future: provider.getUserName(reviewerUid),
                                builder: (context, nameSnapshot) {
                                  final name = nameSnapshot.data ?? 'Loading...';
                                  return ListTile(
                                    leading: CircleAvatar(child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?')),
                                    title: Text(name),
                                    subtitle: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: List.generate(5, (i) => Icon(
                                            i < rating.toInt() ? Icons.star : Icons.star_border,
                                            size: 16, color: Colors.amber,
                                          )),
                                        ),
                                        if (comment.isNotEmpty) Text(comment),
                                      ],
                                    ),
                                  );
                                },
                              );
                            }).toList(),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}



class _PriceOption extends StatelessWidget {
  final String label;
  final double price;
  const _PriceOption({required this.label, required this.price});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outline),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 4),
          Text('\$${price.toStringAsFixed(2)}',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              )),
        ],
      ),
    );
  }
}