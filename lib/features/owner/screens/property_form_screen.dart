import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
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
  final List<String> _removedImageUrls = []; // Track removed existing images
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
        // Reset removed images list when loading property
        _removedImageUrls.clear();
        // Note: Existing images are loaded from URLs in the API response
        // They will be displayed automatically via ref.watch
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

  void _removeExistingImage(int index) {
    setState(() {
      final existingProperty = widget.propertyId != null
          ? ref.read(propertyProvider.notifier).getPropertyById(widget.propertyId!)
          : null;
      if (existingProperty != null && index < existingProperty.imageUrls.length) {
        final imageUrl = existingProperty.imageUrls[index];
        _removedImageUrls.add(imageUrl);
      }
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
    if (_isLoading) return; // Prevent multiple submissions
    
    final user = ref.read(authProvider).user;
    if (user == null) return;

    setState(() {
      _isLoading = true;
    });

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
          // Refresh properties to ensure dashboard shows the updated property
          await ref.read(propertyProvider.notifier).refresh();
          
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
          // Refresh properties to ensure dashboard shows the new property
          await ref.read(propertyProvider.notifier).refresh();
          
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
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
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
              enabled: !_isLoading,
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
              enabled: !_isLoading,
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
                    ? ref.watch(propertyProvider).propertyCache[widget.propertyId!] ??
                      ref.read(propertyProvider.notifier).getPropertyById(widget.propertyId!)
                    : null;
                // Filter out removed images
                final existingImageUrls = (existingProperty?.imageUrls ?? [])
                    .where((url) => !_removedImageUrls.contains(url))
                    .toList();
                final totalImages = existingImageUrls.length + _selectedImages.length;
                
                if (totalImages == 0) {
                  return OutlinedButton.icon(
                    onPressed: _isLoading ? null : _pickImages,
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
                          itemCount: totalImages,
                          itemBuilder: (context, index) {
                            // Show existing images first, then new images
                            if (index < existingImageUrls.length) {
                              // Existing image from URL
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
                                      child: CachedNetworkImage(
                                        imageUrl: existingImageUrls[index],
                                        fit: BoxFit.cover,
                                        width: 120,
                                        height: 120,
                                        placeholder: (context, url) => Container(
                                          width: 120,
                                          height: 120,
                                          color: Colors.grey[200],
                                          child: const Center(
                                            child: CircularProgressIndicator(strokeWidth: 2),
                                          ),
                                        ),
                                        errorWidget: (context, url, error) => Container(
                                          width: 120,
                                          height: 120,
                                          color: Colors.grey[300],
                                          child: const Icon(FontAwesomeIcons.image, size: 40),
                                        ),
                                      ),
                                    ),
                                    Positioned(
                                      top: 4,
                                      right: 4,
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: Colors.black54,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: IconButton(
                                          icon: const Icon(FontAwesomeIcons.xmark, color: Colors.white, size: 16),
                                          style: IconButton.styleFrom(
                                            padding: const EdgeInsets.all(4),
                                            minimumSize: const Size(32, 32),
                                          ),
                                          onPressed: _isLoading ? null : () => _removeExistingImage(index),
                                          tooltip: 'Supprimer cette image',
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            } else {
                              // New image from file
                              final fileIndex = index - existingImageUrls.length;
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
                                        _selectedImages[fileIndex],
                                        fit: BoxFit.cover,
                                        width: 120,
                                        height: 120,
                                      ),
                                    ),
                                    Positioned(
                                      top: 4,
                                      right: 4,
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: Colors.black54,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: IconButton(
                                          icon: const Icon(FontAwesomeIcons.xmark, color: Colors.white, size: 16),
                                          style: IconButton.styleFrom(
                                            padding: const EdgeInsets.all(4),
                                            minimumSize: const Size(32, 32),
                                          ),
                                          onPressed: _isLoading ? null : () => _removeImage(fileIndex),
                                          tooltip: 'Supprimer cette image',
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }
                          },
                        ),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: _isLoading ? null : _pickImages,
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
              onChanged: _isLoading ? null : (value) {
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
              onChanged: _isLoading ? null : (value) {
                setState(() {
                  _furnished = value;
                });
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _addressController,
              enabled: !_isLoading,
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
              enabled: !_isLoading,
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
              enabled: !_isLoading,
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
                  onSelected: _isLoading ? null : (selected) {
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
              onPressed: _isLoading ? null : _saveProperty,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Text(widget.propertyId != null ? 'Mettre à jour' : 'Ajouter'),
            ),
          ],
        ),
      ),
    );
  }
}
