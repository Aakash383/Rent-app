import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/item.dart';

class BookingConfirmationScreen extends StatelessWidget {
  final RentItem item;
  final DateTime bookingDate;
  final TimeOfDay bookingTime;
  final String durationType;
  final int quantity;
  final double totalPrice;

  const BookingConfirmationScreen({
    super.key,
    required this.item,
    required this.bookingDate,
    required this.bookingTime,
    required this.durationType,
    required this.quantity,
    required this.totalPrice,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Booking Confirmed')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 64),
            const SizedBox(height: 16),
            Text('Booking Successful!',
                style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 24),
            Text('Item: ${item.title}',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
                'Date: ${bookingDate.day}/${bookingDate.month}/${bookingDate.year}'),
            const SizedBox(height: 8),
            Text('Time: ${bookingTime.format(context)}'),
            const SizedBox(height: 8),
            Text('Duration: $quantity ${durationType}(s)'),
            const SizedBox(height: 8),
            Text('Total Paid: \$${totalPrice.toStringAsFixed(2)}'),
            const Divider(height: 32),
            const Text('Renter Details',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            FutureBuilder<Map<String, dynamic>?>(
              future: FirebaseFirestore.instance
                  .collection('users')
                  .doc(item.ownerUid)
                  .get()
                  .then((doc) => doc.data()),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Text('Loading...');
                final data = snapshot.data!;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Name: ${data['name'] ?? 'Unknown'}'),
                    Text('Phone: ${item.renterContact}'),
                  ],
                );
              },
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () =>
                    Navigator.popUntil(context, (route) => route.isFirst),
                child: const Text('Back to Home'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}