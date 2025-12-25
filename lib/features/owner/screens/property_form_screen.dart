import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:travelci/core/models/property.dart';
import 'package:travelci/core/providers/auth_provider.dart';
import 'package:travelci/core/providers/property_provider.dart';
import 'package:uuid/uuid.dart';

class PropertyFormScreen extends ConsumerStatefulWidget {
  final String? propertyId;

  const PropertyFormScreen({
    super.key,
    this.propertyId,
  });

  @override
  ConsumerState<PropertyFormScreen> createState() => _PropertyFormScreenState();
}

class _PropertyFormScreenState extends ConsumerState<PropertyFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController(text: 'Abidjan');
  final _priceController = TextEditingController();
  PropertyType _selectedType = PropertyType.apartment;
  bool _furnished = false;
  final List<String> _amenities = [];
  final List<File> _selectedImages = [];
  final ImagePicker _imagePicker = ImagePicker();
  final List<String> _availableAmenities = [
    'WiFi',
    'Climatisation',
    'Parking',
    'Cuisine équipée',
    'TV',
    'Piscine',
    'Jardin',
    'Ascenseur',
  ];

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.propertyId != null) {
      _loadProperty();
    }
  }

  Future<void> _loadProperty() async {
    setState(() {
      _isLoading = true;
    });

    try {
      var property = ref.read(propertyProvider.notifier).getPropertyById(widget.propertyId!);
      
      // If property not in cache, fetch from API
      if (property == null) {
        property = await ref.read(propertyProvider.notifier).fetchPropertyById(widget.propertyId!);
      }

      if (property != null && mounted) {
        _titleController.text = property.title;
        _descriptionController.text = property.description ?? '';
        _addressController.text = property.address;
        _cityController.text = property.city;
        _priceController.text = property.pricePerNight.toString();
        _selectedType = property.type;
        _furnished = property.furnished;
        _amenities.clear();
        _amenities.addAll(property.amenities);
        // Note: Images are loaded from URLs in the API response
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors du chargement: ${e.toString().replaceFirst('Exception: ', '')}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _pickImages() async {
    try {
      final List<XFile> images = await _imagePicker.pickMultiImage();
      if (images.isNotEmpty) {
        setState(() {
          _selectedImages.addAll(images.map((xFile) => File(xFile.path)));
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur lors de la sélection des images: $e')),
      );
    }
  }

  void _removeImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _saveProperty() async {
    if (!_formKey.currentState!.validate()) return;
      final user = ref.read(authProvider).user;
      if (user == null) return;

      try {
        if (widget.propertyId != null) {
          // Update existing property
          await ref.read(propertyProvider.notifier).updateProperty(
                id: widget.propertyId!,
                title: _titleController.text.trim(),
                description: _descriptionController.text.trim().isEmpty
                    ? null
                    : _descriptionController.text.trim(),
                type: _selectedType,
                furnished: _furnished,
                pricePerNight: double.parse(_priceController.text),
                address: _addressController.text.trim(),
                city: _cityController.text.trim(),
                amenities: _amenities,
              );

          if (mounted) {
            context.pop();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Logement mis à jour')),
            );
          }
        } else {
          // Create new property
          await ref.read(propertyProvider.notifier).createProperty(
                title: _titleController.text.trim(),
                description: _descriptionController.text.trim().isEmpty
                    ? null
                    : _descriptionController.text.trim(),
                type: _selectedType,
                furnished: _furnished,
                pricePerNight: double.parse(_priceController.text),
                address: _addressController.text.trim(),
                city: _cityController.text.trim(),
                amenities: _amenities,
                images: _selectedImages.isEmpty ? null : _selectedImages,
              );

          if (mounted) {
            context.pop();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Logement ajouté')),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erreur: ${e.toString().replaceFirst('Exception: ', '')}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.propertyId != null ? 'Modifier le logement' : 'Nouveau logement'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Titre',
                border: OutlineInputBorder(),
                hintText: 'Ex: Appartement moderne à Cocody',
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Veuillez entrer un titre';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description',
                border: OutlineInputBorder(),
                hintText: 'Décrivez votre logement...',
              ),
              maxLines: 5,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Veuillez entrer une description';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),
            const Text(
              'Photos',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Builder(
              builder: (context) {
                final existingProperty = widget.propertyId != null
                    ? ref.read(propertyProvider.notifier).getPropertyById(widget.propertyId!)
                    : null;
                final hasExistingImages = existingProperty?.imageUrls.isNotEmpty ?? false;
                
                if (_selectedImages.isEmpty && !hasExistingImages) {
                  return OutlinedButton.icon(
                    onPressed: _pickImages,
                    icon: const Icon(FontAwesomeIcons.image),
                    label: const Text('Ajouter des photos'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      minimumSize: const Size(double.infinity, 50),
                    ),
                  );
                } else {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        height: 120,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: _selectedImages.length,
                          itemBuilder: (context, index) {
                            return Container(
                              margin: const EdgeInsets.only(right: 8),
                              width: 120,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.grey[300]!),
                              ),
                              child: Stack(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.file(
                                      _selectedImages[index],
                                      fit: BoxFit.cover,
                                      width: 120,
                                      height: 120,
                                    ),
                                  ),
                                  Positioned(
                                    top: 4,
                                    right: 4,
                                    child: IconButton(
                                      icon: const Icon(FontAwesomeIcons.xmark, color: Colors.white),
                                      style: IconButton.styleFrom(
                                        backgroundColor: Colors.black54,
                                        padding: const EdgeInsets.all(4),
                                        minimumSize: const Size(32, 32),
                                      ),
                                      onPressed: () => _removeImage(index),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: _pickImages,
                        icon: const Icon(FontAwesomeIcons.image),
                        label: const Text('Ajouter plus de photos'),
                      ),
                    ],
                  );
                }
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<PropertyType>(
              value: _selectedType,
              decoration: const InputDecoration(
                labelText: 'Type',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(
                  value: PropertyType.apartment,
                  child: Text('Appartement'),
                ),
                DropdownMenuItem(
                  value: PropertyType.villa,
                  child: Text('Villa'),
                ),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _selectedType = value;
                  });
                }
              },
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('Meublé'),
              value: _furnished,
              onChanged: (value) {
                setState(() {
                  _furnished = value;
                });
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _addressController,
              decoration: const InputDecoration(
                labelText: 'Adresse',
                border: OutlineInputBorder(),
                hintText: 'Rue, quartier',
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Veuillez entrer une adresse';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _cityController,
              decoration: const InputDecoration(
                labelText: 'Ville',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Veuillez entrer une ville';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _priceController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Prix par nuit (XOF)',
                border: OutlineInputBorder(),
                prefixText: 'XOF ',
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Veuillez entrer un prix';
                }
                if (int.tryParse(value) == null) {
                  return 'Prix invalide';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),
            const Text(
              'Équipements',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _availableAmenities.map((amenity) {
                final isSelected = _amenities.contains(amenity);
                return FilterChip(
                  label: Text(amenity),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        _amenities.add(amenity);
                      } else {
                        _amenities.remove(amenity);
                      }
                    });
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _saveProperty,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: Text(widget.propertyId != null ? 'Mettre à jour' : 'Ajouter'),
            ),
          ],
        ),
      ),
    );
  }
}

