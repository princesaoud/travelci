import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:travelci/core/providers/auth_provider.dart';
import 'package:travelci/core/services/favorite_service.dart';

const _localKey = 'favorite_property_ids';

class FavoritesNotifier extends AsyncNotifier<Set<String>> {
  @override
  Future<Set<String>> build() async {
    final isAuth = ref.watch(authProvider).user != null;
    if (isAuth) {
      return _loadFromApi();
    }
    return _loadFromLocal();
  }

  Future<Set<String>> _loadFromApi() async {
    try {
      final ids = await favoriteService.getFavorites();
      return ids.toSet();
    } catch (_) {
      return _loadFromLocal();
    }
  }

  Future<Set<String>> _loadFromLocal() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_localKey) ?? []).toSet();
  }

  Future<void> _saveLocal(Set<String> ids) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_localKey, ids.toList());
  }

  Future<void> toggleFavorite(String propertyId) async {
    final current = Set<String>.from(state.valueOrNull ?? {});
    final adding = !current.contains(propertyId);

    if (adding) {
      current.add(propertyId);
    } else {
      current.remove(propertyId);
    }
    state = AsyncData(current);
    await _saveLocal(current);

    final isAuth = ref.read(authProvider).user != null;
    if (!isAuth) return;

    try {
      if (adding) {
        await favoriteService.addFavorite(propertyId);
      } else {
        await favoriteService.removeFavorite(propertyId);
      }
    } catch (_) {
      // API call failed — revert optimistic update
      if (adding) {
        current.remove(propertyId);
      } else {
        current.add(propertyId);
      }
      state = AsyncData(current);
      await _saveLocal(current);
    }
  }

  bool isFavorite(String propertyId) =>
      state.valueOrNull?.contains(propertyId) ?? false;
}

final favoritesProvider =
    AsyncNotifierProvider<FavoritesNotifier, Set<String>>(
  FavoritesNotifier.new,
);
