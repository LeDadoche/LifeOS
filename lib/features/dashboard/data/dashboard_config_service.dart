import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'dashboard_config_service.g.dart';

/// Types de layout selon l'environnement
enum LayoutType {
  mobilePortrait, // Mobile en mode portrait (2 colonnes)
  mobileLandscape, // Mobile en mode paysage (4 colonnes)
  desktop, // Desktop/Web (6 colonnes)
}

extension LayoutTypeExtension on LayoutType {
  /// Nombre de colonnes pour ce layout
  int get columnCount {
    switch (this) {
      case LayoutType.mobilePortrait:
        return 2;
      case LayoutType.mobileLandscape:
        return 4;
      case LayoutType.desktop:
        return 6;
    }
  }

  /// Clé de stockage pour SharedPreferences
  String get storageKey {
    switch (this) {
      case LayoutType.mobilePortrait:
        return 'dashboard_positions_mobile_portrait';
      case LayoutType.mobileLandscape:
        return 'dashboard_positions_mobile_landscape';
      case LayoutType.desktop:
        return 'dashboard_positions_desktop';
    }
  }

  String get displayName {
    switch (this) {
      case LayoutType.mobilePortrait:
        return 'Mobile Portrait';
      case LayoutType.mobileLandscape:
        return 'Mobile Paysage';
      case LayoutType.desktop:
        return 'Desktop';
    }
  }
}

/// Tailles de tuiles disponibles
enum TileSize {
  small, // 1x1
  wide, // 2x1
  tall, // 1x2
  large, // 2x2
  extraWide, // 3x1
  extraLarge, // 3x2
  huge, // 4x2
}

class DashboardItem {
  final String id;
  final String label;
  final bool isVisible;
  final int x; // Position X sur la grille (colonne)
  final int y; // Position Y sur la grille (ligne)
  final int width; // Largeur en cellules (1-4)
  final int height; // Hauteur en cellules (1-4)

  DashboardItem({
    required this.id,
    required this.label,
    this.isVisible = true,
    this.x = 0,
    this.y = 0,
    this.width = 1,
    this.height = 1,
  });

  /// Alias pour compatibilité
  int get crossAxisCellCount => width.clamp(1, 4);
  int get mainAxisCellCount => height.clamp(1, 4);

  /// Rectangle occupé par ce widget sur la grille
  bool occupiesCell(int cellX, int cellY) {
    return cellX >= x && cellX < x + width && cellY >= y && cellY < y + height;
  }

  /// Vérifie si ce widget chevauche un autre
  bool overlaps(DashboardItem other) {
    if (id == other.id) return false;
    return !(x + width <= other.x ||
        other.x + other.width <= x ||
        y + height <= other.y ||
        other.y + other.height <= y);
  }

  /// Convertit vers TileSize pour compatibilité
  TileSize get tileSize {
    if (width >= 3 && height >= 2) return TileSize.huge;
    if (width >= 3) return TileSize.extraWide;
    if (width >= 2 && height >= 2) return TileSize.large;
    if (width >= 2) return TileSize.wide;
    if (height >= 2) return TileSize.tall;
    return TileSize.small;
  }

  DashboardItem copyWith({
    String? id,
    String? label,
    bool? isVisible,
    int? x,
    int? y,
    int? width,
    int? height,
    TileSize? tileSize,
  }) {
    int newWidth = width ?? this.width;
    int newHeight = height ?? this.height;

    if (tileSize != null) {
      switch (tileSize) {
        case TileSize.small:
          newWidth = 1;
          newHeight = 1;
          break;
        case TileSize.wide:
          newWidth = 2;
          newHeight = 1;
          break;
        case TileSize.tall:
          newWidth = 1;
          newHeight = 2;
          break;
        case TileSize.large:
          newWidth = 2;
          newHeight = 2;
          break;
        case TileSize.extraWide:
          newWidth = 3;
          newHeight = 1;
          break;
        case TileSize.extraLarge:
          newWidth = 3;
          newHeight = 2;
          break;
        case TileSize.huge:
          newWidth = 4;
          newHeight = 2;
          break;
      }
    }

    return DashboardItem(
      id: id ?? this.id,
      label: label ?? this.label,
      isVisible: isVisible ?? this.isVisible,
      x: x ?? this.x,
      y: y ?? this.y,
      width: newWidth.clamp(1, 4),
      height: newHeight.clamp(1, 4),
    );
  }

  static TileSize sizeFromLegacy(int size, String id) {
    if (size == 2) {
      if (id == 'agenda') return TileSize.large;
      return TileSize.wide;
    }
    if (id == 'notes') return TileSize.tall;
    return TileSize.small;
  }

  static String tileSizeToString(TileSize size) => size.name;

  static TileSize tileSizeFromString(String? str) {
    if (str == null) return TileSize.small;
    return TileSize.values.firstWhere(
      (e) => e.name == str,
      orElse: () => TileSize.small,
    );
  }
}

/// Provider pour le mode édition du dashboard
final dashboardEditModeProvider = StateProvider<bool>((ref) => false);

/// Provider pour le type de layout actuel
final currentLayoutTypeProvider =
    StateProvider<LayoutType>((ref) => LayoutType.desktop);

/// Détermine le LayoutType basé sur les dimensions de l'écran
LayoutType detectLayoutType(double width, double height, bool isLandscape) {
  // Desktop/Web : largeur >= 800px
  if (kIsWeb || width >= 800) {
    return LayoutType.desktop;
  }

  // Mobile
  if (isLandscape) {
    return LayoutType.mobileLandscape;
  }
  return LayoutType.mobilePortrait;
}

@riverpod
class DashboardConfig extends _$DashboardConfig {
  // Configurations par défaut pour chaque layout
  static Map<LayoutType, List<DashboardItem>> get _defaultLayouts => {
        LayoutType.desktop: [
          DashboardItem(
              id: 'agenda', label: 'Agenda', x: 0, y: 0, width: 2, height: 2),
          DashboardItem(
              id: 'money', label: 'Budget', x: 2, y: 0, width: 2, height: 1),
          DashboardItem(
              id: 'tasks', label: 'Tâches', x: 4, y: 0, width: 2, height: 1),
          DashboardItem(
              id: 'notes', label: 'Notes', x: 2, y: 1, width: 2, height: 2),
          DashboardItem(
              id: 'kitchen', label: 'Cuisine', x: 4, y: 1, width: 2, height: 1),
        ],
        LayoutType.mobileLandscape: [
          DashboardItem(
              id: 'agenda', label: 'Agenda', x: 0, y: 0, width: 2, height: 2),
          DashboardItem(
              id: 'money', label: 'Budget', x: 2, y: 0, width: 2, height: 1),
          DashboardItem(
              id: 'tasks', label: 'Tâches', x: 2, y: 1, width: 2, height: 1),
          DashboardItem(
              id: 'notes', label: 'Notes', x: 0, y: 2, width: 2, height: 1),
          DashboardItem(
              id: 'kitchen', label: 'Cuisine', x: 2, y: 2, width: 2, height: 1),
        ],
        LayoutType.mobilePortrait: [
          DashboardItem(
              id: 'agenda', label: 'Agenda', x: 0, y: 0, width: 2, height: 2),
          DashboardItem(
              id: 'money', label: 'Budget', x: 0, y: 2, width: 2, height: 1),
          DashboardItem(
              id: 'tasks', label: 'Tâches', x: 0, y: 3, width: 1, height: 1),
          DashboardItem(
              id: 'notes', label: 'Notes', x: 1, y: 3, width: 1, height: 1),
          DashboardItem(
              id: 'kitchen', label: 'Cuisine', x: 0, y: 4, width: 2, height: 1),
        ],
      };

  // static List<DashboardItem> get _allWidgets => [
  //       DashboardItem(id: 'agenda', label: 'Agenda'),
  //       DashboardItem(id: 'money', label: 'Budget'),
  //       DashboardItem(id: 'tasks', label: 'Tâches'),
  //       DashboardItem(id: 'notes', label: 'Notes'),
  //       DashboardItem(id: 'kitchen', label: 'Cuisine'),
  //     ];

  LayoutType _currentLayout = LayoutType.desktop;

  @override
  Future<List<DashboardItem>> build() async {
    // Par défaut, charger le layout desktop
    return await loadLayout(LayoutType.desktop);
  }

  /// Charge le layout pour un type donné
  Future<List<DashboardItem>> loadLayout(LayoutType layoutType) async {
    _currentLayout = layoutType;
    final prefs = await SharedPreferences.getInstance();

    final String storageKey = layoutType.storageKey;
    final List<String>? savedPositions = prefs.getStringList(storageKey);
    final List<String>? hiddenItems =
        prefs.getStringList('dashboard_hidden_$storageKey');

    print(
        '[Dashboard] Chargement layout: ${layoutType.displayName} (${layoutType.columnCount} colonnes)');

    // Parse positions (format: id:x,y,width,height)
    final Map<String, (int, int, int, int)> positions = {};
    if (savedPositions != null) {
      for (final entry in savedPositions) {
        final parts = entry.split(':');
        if (parts.length == 2) {
          final values = parts[1].split(',');
          if (values.length == 4) {
            positions[parts[0]] = (
              int.tryParse(values[0]) ?? 0,
              int.tryParse(values[1]) ?? 0,
              int.tryParse(values[2]) ?? 1,
              int.tryParse(values[3]) ?? 1,
            );
          }
        }
      }
    }

    // Si aucune position sauvegardée, utiliser les défauts
    final defaults = _defaultLayouts[layoutType]!;
    final List<DashboardItem> items = [];

    for (final defaultItem in defaults) {
      final pos = positions[defaultItem.id];
      final isHidden = hiddenItems?.contains(defaultItem.id) ?? false;

      if (pos != null) {
        // Position sauvegardée
        items.add(DashboardItem(
          id: defaultItem.id,
          label: defaultItem.label,
          isVisible: !isHidden,
          x: pos.$1,
          y: pos.$2,
          width: pos.$3.clamp(1, layoutType.columnCount),
          height: pos.$4,
        ));
      } else {
        // Position par défaut
        items.add(defaultItem.copyWith(
          isVisible: !isHidden,
          width: defaultItem.width.clamp(1, layoutType.columnCount),
        ));
      }
    }

    state = AsyncData(items);
    debugPrintWidgets();
    return items;
  }

  /// Change de layout et recharge les positions
  Future<void> switchLayout(LayoutType newLayout) async {
    if (_currentLayout == newLayout) return;

    print(
        '[Dashboard] Changement de layout: ${_currentLayout.displayName} → ${newLayout.displayName}');
    await loadLayout(newLayout);
  }

  /// Vérifie si un layout a été configuré
  Future<bool> hasLayoutConfiguration(LayoutType layoutType) async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList(layoutType.storageKey);
    return saved != null && saved.isNotEmpty;
  }

  /// Copie le layout d'un type vers un autre
  Future<void> copyLayoutFrom(LayoutType source, LayoutType target) async {
    final prefs = await SharedPreferences.getInstance();

    // Charger le layout source
    final sourcePositions = prefs.getStringList(source.storageKey);
    if (sourcePositions == null) {
      print('[Dashboard] Layout source vide, utilisation des défauts');
      await resetLayout(target);
      return;
    }

    // Adapter les positions au nouveau nombre de colonnes
    final List<String> adaptedPositions = [];
    for (final entry in sourcePositions) {
      final parts = entry.split(':');
      if (parts.length == 2) {
        final values = parts[1].split(',');
        if (values.length == 4) {
          final x = int.tryParse(values[0]) ?? 0;
          final width = int.tryParse(values[2]) ?? 1;

          // Adapter si hors limites
          final newWidth = width.clamp(1, target.columnCount);
          final newX = x.clamp(0, target.columnCount - newWidth);

          adaptedPositions
              .add('${parts[0]}:$newX,${values[1]},$newWidth,${values[3]}');
        }
      }
    }

    await prefs.setStringList(target.storageKey, adaptedPositions);

    print(
        '[Dashboard] Layout copié de ${source.displayName} vers ${target.displayName}');

    if (_currentLayout == target) {
      await loadLayout(target);
    }
  }

  /// Réinitialise un layout à ses valeurs par défaut
  Future<void> resetLayout(LayoutType layoutType) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(layoutType.storageKey);
    await prefs.remove('dashboard_hidden_${layoutType.storageKey}');

    print('[Dashboard] Layout ${layoutType.displayName} réinitialisé');

    if (_currentLayout == layoutType) {
      await loadLayout(layoutType);
    }
  }

  Future<void> updateItems(List<DashboardItem> newItems) async {
    state = AsyncData(newItems);

    final prefs = await SharedPreferences.getInstance();
    final storageKey = _currentLayout.storageKey;

    final hidden =
        newItems.where((e) => !e.isVisible).map((e) => e.id).toList();
    final positions = newItems
        .map((e) => '${e.id}:${e.x},${e.y},${e.width},${e.height}')
        .toList();

    await prefs.setStringList('dashboard_hidden_$storageKey', hidden);
    await prefs.setStringList(storageKey, positions);
  }

  Future<void> updatePosition(String id, int x, int y) async {
    final currentItems = state.value;
    if (currentItems == null) return;

    final columnCount = _currentLayout.columnCount;
    final newItems = currentItems.map((item) {
      if (item.id == id) {
        return item.copyWith(
          x: x.clamp(0, columnCount - item.width),
          y: y.clamp(0, 20),
        );
      }
      return item;
    }).toList();

    await updateItems(newItems);
  }

  Future<void> updateSize(String id, int width, int height) async {
    final currentItems = state.value;
    if (currentItems == null) return;

    final columnCount = _currentLayout.columnCount;
    final newItems = currentItems.map((item) {
      if (item.id == id) {
        return item.copyWith(
          width: width.clamp(1, columnCount),
          height: height.clamp(1, 4),
        );
      }
      return item;
    }).toList();

    await updateItems(newItems);
  }

  Future<void> updatePositionAndSize(
      String id, int x, int y, int width, int height) async {
    final currentItems = state.value;
    if (currentItems == null) return;

    final columnCount = _currentLayout.columnCount;
    final newItems = currentItems.map((item) {
      if (item.id == id) {
        final newWidth = width.clamp(1, columnCount);
        return item.copyWith(
          x: x.clamp(0, columnCount - newWidth),
          y: y.clamp(0, 20),
          width: newWidth,
          height: height.clamp(1, 4),
        );
      }
      return item;
    }).toList();

    await updateItems(newItems);
  }

  bool canPlaceAt(
      String movingId, int x, int y, int width, int height, int columnCount) {
    final currentItems = state.value;
    if (currentItems == null) return false;

    if (x < 0 || x + width > columnCount) return false;
    if (y < 0) return false;

    final testItem = DashboardItem(
        id: movingId, label: '', x: x, y: y, width: width, height: height);

    for (final item
        in currentItems.where((i) => i.isVisible && i.id != movingId)) {
      if (testItem.overlaps(item)) {
        return false;
      }
    }

    return true;
  }

  Future<void> updateTileSize(String id, TileSize newSize) async {
    final currentItems = state.value;
    if (currentItems == null) return;

    final newItems = currentItems.map((item) {
      if (item.id == id) {
        return item.copyWith(tileSize: newSize);
      }
      return item;
    }).toList();

    await updateItems(newItems);
  }

  Future<void> updateTileCells(String id, int width, int height) async {
    await updateSize(id, width, height);
  }

  Future<void> toggleVisibility(String id) async {
    final currentItems = state.value;
    if (currentItems == null) return;

    final newItems = currentItems.map((item) {
      if (item.id == id) {
        return item.copyWith(isVisible: !item.isVisible);
      }
      return item;
    }).toList();

    await updateItems(newItems);
  }

  Future<void> hideWidget(String id) async {
    final currentItems = state.value;
    if (currentItems == null) return;

    final newItems = currentItems.map((item) {
      if (item.id == id) {
        return item.copyWith(isVisible: false);
      }
      return item;
    }).toList();

    await updateItems(newItems);
  }

  Future<void> showWidget(String id, int columnCount) async {
    final currentItems = state.value;
    if (currentItems == null) return;

    final itemIndex = currentItems.indexWhere((i) => i.id == id);
    if (itemIndex == -1) return;

    final item = currentItems[itemIndex];
    final effectiveWidth = item.width.clamp(1, columnCount);
    final (x, y) =
        _findEmptySpace(currentItems, effectiveWidth, item.height, columnCount);

    print(
        '[Dashboard] Ajout widget "${item.id}" à ($x, $y) avec taille ${effectiveWidth}x${item.height}');

    final newItems = currentItems.map((i) {
      if (i.id == id) {
        return i.copyWith(isVisible: true, x: x, y: y, width: effectiveWidth);
      }
      return i;
    }).toList();

    await updateItems(newItems);
    debugPrintWidgets();
  }

  (int, int) _findEmptySpace(
      List<DashboardItem> items, int width, int height, int columnCount) {
    final visibleItems = items.where((i) => i.isVisible).toList();
    final effectiveWidth = width.clamp(1, columnCount);

    for (int y = 0; y < 20; y++) {
      for (int x = 0; x <= columnCount - effectiveWidth; x++) {
        bool canPlace = true;
        for (int dy = 0; dy < height && canPlace; dy++) {
          for (int dx = 0; dx < effectiveWidth && canPlace; dx++) {
            for (final item in visibleItems) {
              if (item.occupiesCell(x + dx, y + dy)) {
                canPlace = false;
                break;
              }
            }
          }
        }
        if (canPlace) {
          return (x, y);
        }
      }
    }

    int maxY = 0;
    for (final item in visibleItems) {
      final bottom = item.y + item.height;
      if (bottom > maxY) maxY = bottom;
    }
    return (0, maxY);
  }

  List<DashboardItem> getHiddenWidgets([int? columnCount]) {
    final currentItems = state.value;
    if (currentItems == null) return [];

    final cols = columnCount ?? _currentLayout.columnCount;

    return currentItems.where((item) {
      if (!item.isVisible) return true;
      if (item.x >= cols) return true;
      if (item.x + item.width > cols) return true;
      return false;
    }).toList();
  }

  void debugPrintWidgets() {
    final currentItems = state.value;
    if (currentItems == null) {
      print('[Dashboard DEBUG] Aucun item chargé');
      return;
    }

    print('═══════════════════════════════════════════════');
    print(
        '[Dashboard DEBUG] Layout: ${_currentLayout.displayName} (${_currentLayout.columnCount} cols)');
    for (final item in currentItems) {
      final status = item.isVisible ? '✓ VISIBLE' : '✗ CACHÉ';
      print(
          '  ${item.id.padRight(10)} | $status | pos(${item.x},${item.y}) | size(${item.width}x${item.height})');
    }
    print('═══════════════════════════════════════════════');
  }

  Future<void> hardReset() async {
    print('[Dashboard] HARD RESET - Réinitialisation de TOUS les layouts');

    final prefs = await SharedPreferences.getInstance();

    // Supprimer tous les layouts
    for (final layout in LayoutType.values) {
      await prefs.remove(layout.storageKey);
      await prefs.remove('dashboard_hidden_${layout.storageKey}');
    }

    // Supprimer aussi les anciennes clés (migration)
    await prefs.remove('dashboard_hidden');
    await prefs.remove('dashboard_positions');

    await loadLayout(_currentLayout);
  }

  Future<void> fixOutOfBoundsWidgets(int columnCount) async {
    final currentItems = state.value;
    if (currentItems == null) return;

    print(
        '[Dashboard] Réparation des widgets hors écran (colonnes: $columnCount)');

    final List<DashboardItem> fixedItems = [];
    final List<DashboardItem> toReposition = [];

    for (final item in currentItems) {
      if (!item.isVisible) {
        fixedItems.add(item);
        continue;
      }

      if (item.x >= columnCount || item.x + item.width > columnCount) {
        print(
            '[Dashboard] Widget "${item.id}" hors limites, sera repositionné');
        toReposition.add(item);
      } else {
        fixedItems.add(item);
      }
    }

    for (final item in toReposition) {
      final effectiveWidth = item.width.clamp(1, columnCount);
      final (x, y) =
          _findEmptySpace(fixedItems, effectiveWidth, item.height, columnCount);
      fixedItems.add(item.copyWith(x: x, y: y, width: effectiveWidth));
      print('[Dashboard] Widget "${item.id}" repositionné à ($x, $y)');
    }

    await updateItems(fixedItems);
    debugPrintWidgets();
  }

  /// Getter pour le layout actuel
  LayoutType get currentLayout => _currentLayout;

  Future<void> reorder(int oldIndex, int newIndex) async {
    // Non applicable en mode Canvas libre
  }
}
