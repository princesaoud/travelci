import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:travelci/core/models/property.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _cityController = TextEditingController(text: 'Abidjan');
  PropertyType? _selectedType;
  bool? _furnished;
  int? _priceMin;
  int? _priceMax;

  @override
  void dispose() {
    _cityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recherche avancée'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          TextField(
            controller: _cityController,
            decoration: const InputDecoration(
              labelText: 'Ville',
              prefixIcon: Icon(FontAwesomeIcons.city),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Type de logement',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ChoiceChip(
                  label: const Text('Appartement'),
                  selected: _selectedType == PropertyType.apartment,
                  onSelected: (selected) {
                    setState(() {
                      _selectedType = selected ? PropertyType.apartment : null;
                    });
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ChoiceChip(
                  label: const Text('Villa'),
                  selected: _selectedType == PropertyType.villa,
                  onSelected: (selected) {
                    setState(() {
                      _selectedType = selected ? PropertyType.villa : null;
                    });
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Text(
            'Meublé',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              ChoiceChip(
                label: const Text('Oui'),
                selected: _furnished == true,
                onSelected: (selected) {
                  setState(() {
                    _furnished = selected ? true : null;
                  });
                },
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: const Text('Non'),
                selected: _furnished == false,
                onSelected: (selected) {
                  setState(() {
                    _furnished = selected ? false : null;
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Text(
            'Prix par nuit (XOF)',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Min',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) {
                    _priceMin = value.isEmpty ? null : int.tryParse(value);
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextField(
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Max',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) {
                    _priceMax = value.isEmpty ? null : int.tryParse(value);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context, {
                'city': _cityController.text,
                'type': _selectedType,
                'furnished': _furnished,
                'priceMin': _priceMin,
                'priceMax': _priceMax,
              });
            },
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: const Text('Appliquer les filtres'),
          ),
        ],
      ),
    );
  }
}

