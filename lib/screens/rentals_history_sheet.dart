import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../providers/item_provider.dart';
import 'rental_detail_screen.dart';

class RentalsHistorySheet extends StatefulWidget {
  const RentalsHistorySheet({super.key});

  @override
  State<RentalsHistorySheet> createState() => _RentalsHistorySheetState();
}

class _RentalsHistorySheetState extends State<RentalsHistorySheet> {
  @override
  Widget build(BuildContext context) {
    final provider = context.read<ItemProvider>();
    return DraggableScrollableSheet(
      expand: false,
      builder: (context, scrollController) {
        return FutureBuilder<List<Map<String, dynamic>>>(
          future: provider.getUserBookings(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final bookings = snapshot.data!;
            if (bookings.isEmpty) {
              return const Center(child: Text('No past rentals.'));
            }
            return ListView.builder(
              controller: scrollController,
              itemCount: bookings.length,
              itemBuilder: (context, index) {
                final booking = bookings[index];
                final date = (booking['bookingDate'] as Timestamp).toDate();
                final timeStr = booking['bookingTime'] as String?; // e.g. "14:30"
                final quantity = booking['quantity'] as int? ?? 1;
                final durationType = booking['durationType'] as String? ?? 'hour';

                // Parse booking time
                TimeOfDay bookingTimeOfDay = const TimeOfDay(hour: 0, minute: 0);
                if (timeStr != null) {
                  final parts = timeStr.split(':');
                  if (parts.length == 2) {
                    bookingTimeOfDay = TimeOfDay(
                      hour: int.tryParse(parts[0]) ?? 0,
                      minute: int.tryParse(parts[1]) ?? 0,
                    );
                  }
                }

                // Calculate rental start DateTime
                final startDateTime = DateTime(
                  date.year,
                  date.month,
                  date.day,
                  bookingTimeOfDay.hour,
                  bookingTimeOfDay.minute,
                );

                // Calculate rental end DateTime
                final rentalDuration = durationType == 'hour'
                    ? Duration(hours: quantity)
                    : Duration(days: quantity);
                final endDateTime = startDateTime.add(rentalDuration);

                // Grace period: 1 hour after rental end
                final contactDeadline = endDateTime.add(const Duration(hours: 1));

                // Show contact only if current time is before the deadline
                final now = DateTime.now();
                final bool showContact = now.isBefore(contactDeadline);

                final renterContact = booking['renterContact'] as String?;

                return ListTile(
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      booking['itemImageUrl'] ?? '',
                      width: 50,
                      height: 50,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        width: 50,
                        height: 50,
                        color: Colors.grey.shade300,
                      ),
                    ),
                  ),
                  title: Text(booking['itemTitle'] ?? 'Unknown Item'),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${startDateTime.day}/${startDateTime.month}/${startDateTime.year} '
                            '${bookingTimeOfDay.format(context)}',
                      ),
                      Text('$quantity $durationType(s)  –  \$${booking['totalPrice']}'),
                      if (showContact && renterContact != null)
                        Text('📞 $renterContact', style: const TextStyle(fontWeight: FontWeight.bold)),
                      if (!showContact)
                        const Text('Contact expired', style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                  trailing: Builder(builder: (context) {
                    final rentedUntil = (booking['rentedUntil'] as Timestamp?)?.toDate();
                    final bool ended = rentedUntil != null && DateTime.now().isAfter(rentedUntil);
                    if (!ended) return const SizedBox();

                    return FutureBuilder<bool>(
                      future: context.read<ItemProvider>().hasReviewedBooking(booking['bookingId'] as String? ?? ''),
                      builder: (context, snapshot) {
                        final reviewed = snapshot.data ?? true; // if error, hide button
                        return TextButton(
                          onPressed: reviewed ? null : () {
                            Navigator.pop(context); // close sheet
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => RentalDetailScreen(booking: booking),
                              ),
                            );
                          },
                          child: Text(reviewed ? 'Reviewed' : 'Review'),
                        );
                      },
                    );
                  }),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => RentalDetailScreen(booking: booking)),
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }
}