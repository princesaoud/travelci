import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:travelci/core/providers/favorites_provider.dart';
import 'package:travelci/core/providers/property_provider.dart';
import 'package:travelci/core/providers/review_provider.dart';
import 'package:travelci/core/models/property.dart';
import 'package:travelci/core/utils/currency_formatter.dart';
import 'package:travelci/core/utils/feedback.dart';

class FavoritesScreen extends ConsumerWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favAsync = ref.watch(favoritesProvider);
    final allProperties = ref.watch(propertyProvider).properties;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Favoris'),
        centerTitle: false,
      ),
      body: favAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const Center(child: Text('Erreur de chargement')),
        data: (ids) {
          final favorites =
              allProperties.where((p) => ids.contains(p.id)).toList();

          if (ids.isEmpty) {
            return _EmptyFavorites();
          }

          if (favorites.isEmpty) {
            // IDs exist but properties not loaded yet
            return const Center(child: CircularProgressIndicator());
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: favorites.length,
            itemBuilder: (context, index) =>
                _FavoriteCard(property: favorites[index]),
          );
        },
      ),
    );
  }
}

class _EmptyFavorites extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(FontAwesomeIcons.heart, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 20),
          Text(
            'Aucun favori pour l\'instant',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Appuyez sur ♡ pour sauvegarder\nun logement',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Colors.grey[400]),
          ),
        ],
      ),
    );
  }
}

class _FavoriteCard extends ConsumerWidget {
  final Property property;

  const _FavoriteCard({required this.property});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final reviews = ref.watch(reviewProvider).entries
        .where((e) => e.key == property.id)
        .map((e) => e.value)
        .firstOrNull;
    final avgRating = reviews != null && reviews.isNotEmpty
        ? reviews.map((r) => r.rating).reduce((a, b) => a + b) /
            reviews.length
        : 0.0;
    final reviewCount = reviews?.length ?? 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      child: InkWell(
        onTap: () {
          tapFeedback();
          context.push('/property/${property.id}');
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image + remove favorite overlay
            Stack(
              children: [
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: property.imageUrls.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: property.imageUrls.first,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => Container(
                            color: Colors.grey[200],
                            child: Icon(FontAwesomeIcons.image,
                                size: 48, color: Colors.grey[400]),
                          ),
                        )
                      : Container(
                          color: Colors.grey[200],
                          child: Icon(FontAwesomeIcons.image,
                              size: 48, color: Colors.grey[400]),
                        ),
                ),
                Positioned(
                  top: 10,
                  right: 10,
                  child: _HeartButton(propertyId: property.id),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          property.title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: property.type == PropertyType.apartment
                              ? colorScheme.primary.withValues(alpha: 0.1)
                              : colorScheme.secondary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          property.type == PropertyType.apartment
                              ? 'Appartement'
                              : 'Villa',
                          style: TextStyle(
                            fontSize: 11,
                            color: property.type == PropertyType.apartment
                                ? colorScheme.primary
                                : colorScheme.secondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(FontAwesomeIcons.locationDot,
                          size: 12, color: Colors.grey[500]),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          '${property.city}, ${property.address}',
                          style:
                              TextStyle(fontSize: 13, color: Colors.grey[600]),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  if (reviewCount > 0) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.star_rounded,
                            size: 16, color: Color(0xFFFFC107)),
                        const SizedBox(width: 3),
                        Text(
                          avgRating.toStringAsFixed(1),
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                        Text(
                          ' ($reviewCount avis)',
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey[500]),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      RichText(
                        text: TextSpan(
                          children: [
                            TextSpan(
                              text: CurrencyFormatter.formatXOF(
                                  property.pricePerNight),
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: colorScheme.primary,
                              ),
                            ),
                            TextSpan(
                              text: ' /nuit',
                              style: TextStyle(
                                  fontSize: 12, color: Colors.grey[500]),
                            ),
                          ],
                        ),
                      ),
                      if (property.roomCount != null)
                        Text(
                          property.roomCount == 1
                              ? 'Studio'
                              : '${property.roomCount} pièces',
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey[600]),
                        ),
                    ],
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

class _HeartButton extends ConsumerWidget {
  final String propertyId;

  const _HeartButton({required this.propertyId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isFav = ref
        .watch(favoritesProvider)
        .valueOrNull
        ?.contains(propertyId) ??
        false;

    return GestureDetector(
      onTap: () {
        tapFeedback();
        ref.read(favoritesProvider.notifier).toggleFavorite(propertyId);
      },
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 6,
            ),
          ],
        ),
        child: Icon(
          isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
          size: 20,
          color: isFav ? Colors.red : Colors.grey[600],
        ),
      ),
    );
  }
}
