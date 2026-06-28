import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';   // for Timestamp if needed
import '../models/item.dart';
import '../providers/item_provider.dart';
import 'booking_confirmation_screen.dart';             // ← missing import

class PaymentScreen extends StatefulWidget {
  final RentItem item;
  final DateTime bookingDate;
  final TimeOfDay bookingTime;
  final String durationType;
  final int quantity;

  const PaymentScreen({
    super.key,
    required this.item,
    required this.bookingDate,
    required this.bookingTime,
    required this.durationType,
    required this.quantity,
  });

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  bool _processing = false;

  double get _totalPrice {
    double rate = widget.durationType == 'hour'
        ? widget.item.pricePerHour
        : widget.item.pricePerDay;
    return rate * widget.quantity;
  }

  void _pay() {
    setState(() => _processing = true);
    Future.delayed(const Duration(seconds: 2), () async {
      if (!mounted) return;
      try {
        await context.read<ItemProvider>().addBooking(
          itemId: widget.item.docId!,
          renterUid: widget.item.ownerUid,
          bookingDate: widget.bookingDate,
          bookingTime: widget.bookingTime,
          durationType: widget.durationType,
          quantity: widget.quantity,
          totalPrice: _totalPrice,
          itemTitle: widget.item.title,
          itemImageUrl: widget.item.imageUrls.isNotEmpty
              ? widget.item.imageUrls.first
              : '',
          renterContact: widget.item.renterContact,
        );
        // Navigate to confirmation
        if (mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
              builder: (_) => BookingConfirmationScreen(
                item: widget.item,
                bookingDate: widget.bookingDate,
                bookingTime: widget.bookingTime,
                durationType: widget.durationType,
                quantity: widget.quantity,
                totalPrice: _totalPrice,
              ),
            ),
                (route) => route.isFirst,
          );
        }
      } catch (e) {
        // Show conflict popup
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Booking Conflict'),
            content: Text(e.toString().replaceFirst('Exception: ', '')),
            actions: [
              FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
            ],
          ),
        );
      } finally {
        setState(() => _processing = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Payment')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.item.title, style: theme.textTheme.titleLarge),
            const SizedBox(height: 16),
            _infoRow('Date', '${widget.bookingDate.day}/${widget.bookingDate.month}/${widget.bookingDate.year}'),
            const SizedBox(height: 8),
            _infoRow('Time', widget.bookingTime.format(context)),
            const SizedBox(height: 8),
            _infoRow('Duration', '${widget.quantity} ${widget.durationType}(s)'),
            const Divider(height: 24),
            _infoRow('Rate', '\$${widget.durationType == 'hour' ? widget.item.pricePerHour : widget.item.pricePerDay} per ${widget.durationType}'),
            const SizedBox(height: 8),
            _infoRow('Total', '\$${_totalPrice.toStringAsFixed(2)}', bold: true),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _processing ? null : _pay,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _processing
                    ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
                    : const Text('Pay Now'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value, {bool bold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodyLarge),
        Text(
          value,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            fontWeight: bold ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }
}