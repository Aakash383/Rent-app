import 'package:flutter/material.dart';
import '../models/item.dart';
import 'payment_screen.dart';

class BookingScreen extends StatefulWidget {
  final RentItem item;
  const BookingScreen({super.key, required this.item});

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  DateTime? _startDate;
  TimeOfDay? _startTime;
  int _quantity = 1;
  String _durationType = 'hour'; // hour or day

  double get _totalPrice {
    double rate = _durationType == 'hour'
        ? widget.item.pricePerHour
        : widget.item.pricePerDay;
    return rate * _quantity;
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date != null) {
      setState(() => _startDate = date);
    }
  }

  Future<void> _pickTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (time != null) {
      setState(() => _startTime = time);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Book This Item')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.item.title, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 16),
            // Start Date
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickDate,
                    icon: const Icon(Icons.calendar_today),
                    label: Text(_startDate != null
                        ? '${_startDate!.day}/${_startDate!.month}/${_startDate!.year}'
                        : 'Choose start date'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickTime,
                    icon: const Icon(Icons.access_time),
                    label: Text(_startTime != null
                        ? _startTime!.format(context)
                        : 'Pick time'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            // Duration type
            Text('Duration type', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Row(
              children: [
                ChoiceChip(
                  label: const Text('Per Hour'),
                  selected: _durationType == 'hour',
                  onSelected: (_) => setState(() => _durationType = 'hour'),
                ),
                const SizedBox(width: 12),
                ChoiceChip(
                  label: const Text('Per Day'),
                  selected: _durationType == 'day',
                  onSelected: (_) => setState(() => _durationType = 'day'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Quantity
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Quantity', style: Theme.of(context).textTheme.titleMedium),
                Row(
                  children: [
                    IconButton.filledTonal(
                      onPressed: _quantity > 1 ? () => setState(() => _quantity--) : null,
                      icon: const Icon(Icons.remove),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text('$_quantity', style: Theme.of(context).textTheme.titleMedium),
                    ),
                    IconButton.filledTonal(
                      onPressed: () => setState(() => _quantity++),
                      icon: const Icon(Icons.add),
                    ),
                  ],
                ),
              ],
            ),
            const Spacer(),
            // Total and proceed button
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.4),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Total', style: Theme.of(context).textTheme.titleMedium),
                  Text('\$${_totalPrice.toStringAsFixed(2)}',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      )),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: (_startDate == null || _startTime == null)
                    ? null
                    : () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PaymentScreen(
                        item: widget.item,
                        bookingDate: _startDate!,
                        bookingTime: _startTime!,
                        durationType: _durationType,
                        quantity: _quantity,
                      ),
                    ),
                  );
                },
                child: const Text('Proceed to Payment'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}