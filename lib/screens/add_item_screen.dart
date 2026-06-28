import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import '../providers/item_provider.dart';
import '../models/item.dart';
import 'location_picker_screen.dart';

class AddItemScreen extends StatefulWidget {
  const AddItemScreen({super.key});

  @override
  State<AddItemScreen> createState() => _AddItemScreenState();
}

class _AddItemScreenState extends State<AddItemScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _hourPriceController = TextEditingController();
  final _dayPriceController = TextEditingController();
  final _contactController = TextEditingController();

  List<File> _imageFiles = [];
  bool _uploading = false;
  final ImagePicker _picker = ImagePicker();
  LatLng? _pickedLocation;

  Future<void> _pickImages() async {
    final List<XFile> images = await _picker.pickMultiImage();
    if (images.isNotEmpty) {
      setState(() {
        _imageFiles = images.map((e) => File(e.path)).toList();
      });
    }
  }

  Future<void> _pickLocation() async {
    final result = await Navigator.push<LatLng>(
      context,
      MaterialPageRoute(builder: (_) => const LocationPickerScreen()),
    );
    if (result != null) {
      setState(() => _pickedLocation = result);
    }
  }

  Future<void> _submit() async {
    if (_formKey.currentState!.validate()) {
      if (_pickedLocation == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please pick a location on the map')),
        );
        return;
      }
      setState(() => _uploading = true);
      try {
        final provider = context.read<ItemProvider>();
        final newItem = RentItem(
          title: _titleController.text.trim(),
          description: _descController.text.trim(),
          imageUrls: [], // will be filled by upload
          pricePerHour: double.parse(_hourPriceController.text),
          pricePerDay: double.parse(_dayPriceController.text),
          latitude: _pickedLocation!.latitude,
          longitude: _pickedLocation!.longitude,
          renterContact: _contactController.text.trim(),
          ownerUid: '', // provider fills
        );
        await provider.addItem(newItem, _imageFiles.map((f) => f.path).toList());

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Item listed successfully!')),
          );
          _titleController.clear();
          _descController.clear();
          _hourPriceController.clear();
          _dayPriceController.clear();
          _contactController.clear();
          setState(() {
            _imageFiles = [];
            _pickedLocation = null;
          });
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      } finally {
        setState(() => _uploading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('List Your Item')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // Image picker
              GestureDetector(
                onTap: _pickImages,
                child: Container(
                  height: 150,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: _imageFiles.isNotEmpty
                      ? ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _imageFiles.length,
                    itemBuilder: (_, index) => Padding(
                      padding: const EdgeInsets.all(4),
                      child: Image.file(_imageFiles[index], width: 100, fit: BoxFit.cover),
                    ),
                  )
                      : const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_a_photo, size: 48, color: Colors.grey),
                      SizedBox(height: 8),
                      Text('Tap to select images'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Location picker
              ListTile(
                leading: const Icon(Icons.location_on),
                title: Text(_pickedLocation == null
                    ? 'Pick location on map'
                    : 'Location selected'),
                trailing: const Icon(Icons.map),
                onTap: _pickLocation,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _titleController,
                decoration: _inputDecoration('Title', Icons.label_outline),
                validator: (v) => v!.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descController,
                decoration: _inputDecoration('Description', Icons.description_outlined),
                maxLines: 3,
                validator: (v) => v!.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _hourPriceController,
                      decoration: _inputDecoration('Price/hr', Icons.attach_money),
                      keyboardType: TextInputType.number,
                      validator: (v) => v!.isEmpty ? 'Required' : null,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _dayPriceController,
                      decoration: _inputDecoration('Price/day', Icons.attach_money),
                      keyboardType: TextInputType.number,
                      validator: (v) => v!.isEmpty ? 'Required' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _contactController,
                decoration: _inputDecoration('Contact phone', Icons.phone_outlined),
                keyboardType: TextInputType.phone,
                validator: (v) => v!.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _uploading ? null : _submit,
                  icon: _uploading
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.add),
                  label: Text(_uploading ? 'Uploading...' : 'List Item'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    );
  }
}