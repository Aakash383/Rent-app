import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/item_provider.dart';
import '../models/item.dart';
import 'booking_screen.dart';   // ⬅️ make sure this is present

class ItemDetailScreen extends StatefulWidget {
  final RentItem item;
  const ItemDetailScreen({super.key, required this.item});

  @override
  State<ItemDetailScreen> createState() => _ItemDetailScreenState();
}

class _ItemDetailScreenState extends State<ItemDetailScreen> {
  String? _contactRevealed;

  @override
  void initState() {
    super.initState();
    final provider = context.read<ItemProvider>();
    _contactRevealed = provider.getContactIfPaid(widget.item.docId!);
  }

  void _proceedToBooking() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => BookingScreen(item: widget.item)),
    );
    if (result == true && mounted) {
      final provider = context.read<ItemProvider>();
      provider.payForItem(widget.item.docId!);
      setState(() {
        _contactRevealed = provider.getContactIfPaid(widget.item.docId!);
      });
      _showContactDialog();
    }
  }

  void _showContactDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Payment Successful!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Here is the renter contact:'),
            const SizedBox(height: 8),
            Text(
              _contactRevealed ?? 'N/A',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ItemProvider>();
    final isFav = provider.isFavorite(widget.item.docId!);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Item Details'),
        actions: [
          IconButton(
            icon: Icon(
              isFav ? Icons.favorite : Icons.favorite_border,
              color: isFav ? Colors.red : null,
            ),
            onPressed: () => provider.toggleFavorite(widget.item.docId!),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Image.network(
              widget.item.imageUrl,
              width: double.infinity,
              height: 300,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                height: 300,
                color: Colors.grey.shade300,
                child: const Center(child: Icon(Icons.image_not_supported, size: 64)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.item.title,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Dynamic distance from provider
                  Consumer<ItemProvider>(
                    builder: (context, provider, _) {
                      final dist = provider.getDistanceInKm(
                          widget.item.latitude, widget.item.longitude);
                      return Row(
                        children: [
                          const Icon(Icons.location_on, size: 18, color: Colors.grey),
                          const SizedBox(width: 4),
                          Text(
                            dist != null ? '~ ${dist.toStringAsFixed(1)} km away' : '...',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  Text(
                    widget.item.description,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: _PriceOption(
                          label: 'Per Hour',
                          price: widget.item.pricePerHour,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _PriceOption(
                          label: 'Per Day',
                          price: widget.item.pricePerDay,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  if (_contactRevealed != null)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.green.shade200),
                      ),
                      child: Column(
                        children: [
                          const Icon(Icons.check_circle, color: Colors.green, size: 28),
                          const SizedBox(height: 8),
                          const Text('Contact Unlocked',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text(
                            _contactRevealed!,
                            style: const TextStyle(fontSize: 16),
                          ),
                        ],
                      ),
                    )
                  else
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _proceedToBooking,   // ⬅️ use the new method
                        icon: const Icon(Icons.lock_open),
                        label: const Text('Pay to Reveal Contact'),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
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
          Text(label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              )),
          const SizedBox(height: 4),
          Text(
            '\$${price.toStringAsFixed(2)}',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }
}