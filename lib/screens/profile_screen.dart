import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:rent_app/screens/login_screen.dart';
import '../providers/item_provider.dart';
import '../models/item.dart';
import 'item_detail_screen.dart';
import 'rentals_history_sheet.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final provider = context.watch<ItemProvider>();
    final myItems = provider.myItems;

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // User info – tappable to edit profile
          FutureBuilder<Map<String, dynamic>>(
            future: provider.getUserProfile(),
            builder: (context, snapshot) {
              final data = snapshot.data ?? {};
              final name = data['name'] as String?;
              final phone = data['phone'] as String?;
              final email = user?.email ?? '';

              return GestureDetector(
                onTap: () => _showEditProfileDialog(context, provider, name, phone),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 40,
                          child: Text(
                            (name ?? email)[0].toUpperCase(),
                            style: const TextStyle(fontSize: 32),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          name ?? email,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          phone ?? 'No phone',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Tap to edit',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          // My Items section
          Row(
            children: [
              const Text('My Items', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const Spacer(),
              Text('${myItems.length} items'),
            ],
          ),
          const SizedBox(height: 8),
          if (myItems.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text('You haven\'t listed any items yet.'),
            )
          else
            ...myItems.map((item) {
              final rented = provider.isItemCurrentlyRented(item.docId!);
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      item.imageUrls.isNotEmpty ? item.imageUrls.first : '',
                      width: 60, height: 60, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        width: 60, height: 60, color: Colors.grey.shade300,
                      ),
                    ),
                  ),
                  title: Row(
                    children: [
                      Expanded(child: Text(item.title)),
                      if (rented)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.red.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text('Rented', style: TextStyle(fontSize: 12, color: Colors.red)),
                        ),
                    ],
                  ),
                  subtitle: Text('\$${item.pricePerHour}/hr'),
                  trailing: rented
                      ? const Icon(Icons.info_outline, color: Colors.blue)
                      : IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Delete Item'),
                          content: const Text('Are you sure?'),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
                          ],
                        ),
                      );
                      if (confirm == true && item.docId != null) {
                        await context.read<ItemProvider>().deleteItem(item.docId!);
                      }
                    },
                  ),
                  onTap: () async {
                    if (rented) {
                      final activeBooking = await provider.getActiveBookingForItem(item.docId!);
                      if (activeBooking != null && mounted) {
                        _showRentalInfoDialog(context, activeBooking);
                      }
                    } else {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => ItemDetailScreen(item: item)),
                      );
                    }
                  },
                ),
              );
            }),
          const SizedBox(height: 24),
          // My Rentals button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => const RentalsHistorySheet(),
                );
              },
              icon: const Icon(Icons.history),
              label: const Text('My Rentals'),
            ),
          ),
          const SizedBox(height: 24),
          // Sign Out
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () async {
                await FirebaseAuth.instance.signOut();
                if (!context.mounted) return;
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                      (route) => false,
                );
              },
              icon: const Icon(Icons.logout),
              label: const Text('Sign Out'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showEditProfileDialog(
      BuildContext context,
      ItemProvider provider,
      String? currentName,
      String? currentPhone,
      ) {
    final nameController = TextEditingController(text: currentName ?? '');
    final phoneController = TextEditingController(text: currentPhone ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Profile'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: phoneController,
              decoration: const InputDecoration(labelText: 'Phone'),
              keyboardType: TextInputType.phone,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              await provider.updateUserProfile(
                name: nameController.text.trim(),
                phone: phoneController.text.trim(),
              );
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showRentalInfoDialog(BuildContext context, Map<String, dynamic> booking) {
    // ... keep the existing dialog code for renter info
    final bookerContact = booking['bookerContact'] as String?;
    final quantity = booking['quantity'];
    final durationType = booking['durationType'];
    final bookerUid = booking['bookerUid'] as String?;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rental Active'),
        content: FutureBuilder<DocumentSnapshot>(
          future: FirebaseFirestore.instance.collection('users').doc(bookerUid).get(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const Text('Loading...');
            final userData = snapshot.data!.data() as Map<String, dynamic>?;
            final name = userData?['name'] ?? 'Unknown';
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Rented by: $name'),
                Text('Phone: ${bookerContact ?? "N/A"}'),
                const SizedBox(height: 8),
                Text('Duration: $quantity $durationType(s)'),
                Text('Contact available until rental ends + 1 hour.'),
              ],
            );
          },
        ),
        actions: [
          FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
        ],
      ),
    );
  }
}