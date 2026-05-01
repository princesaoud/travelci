import 'package:travelci/core/services/api_service.dart';
import 'package:travelci/core/utils/api_config.dart';

class FavoriteService extends ApiService {
  /// Returns the list of favorited property IDs for the current user.
  Future<List<String>> getFavorites() async {
    final response = await get<Map<String, dynamic>>(
      ApiConfig.favoritesEndpoint,
      parser: (data) => data as Map<String, dynamic>,
    );
    final data = response['data'] as Map<String, dynamic>? ?? {};
    final ids = data['propertyIds'] as List<dynamic>? ?? [];
    return ids.cast<String>();
  }

  /// Adds a property to the current user's favorites.
  Future<void> addFavorite(String propertyId) async {
    await post<void>(
      ApiConfig.favoriteEndpoint(propertyId),
      parser: (_) {},
    );
  }

  /// Removes a property from the current user's favorites.
  Future<void> removeFavorite(String propertyId) async {
    await delete<void>(
      ApiConfig.favoriteEndpoint(propertyId),
      parser: (_) {},
    );
  }
}

final favoriteService = FavoriteService();
