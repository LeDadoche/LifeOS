import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../data/dashboard_config_service.dart';

class CustomizeDashboardScreen extends ConsumerWidget {
  const CustomizeDashboardScreen({super.key});

  IconData _getTileSizeIcon(TileSize size) {
    switch (size) {
      case TileSize.small:
        return Icons.crop_square;
      case TileSize.wide:
      case TileSize.extraWide:
        return Icons.crop_16_9;
      case TileSize.tall:
        return Icons.crop_portrait;
      case TileSize.large:
      case TileSize.extraLarge:
      case TileSize.huge:
        return Icons.crop_din;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final configAsync = ref.watch(dashboardConfigProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Personnaliser l\'accueil'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: configAsync.when(
        data: (items) {
          return ReorderableListView(
            padding: const EdgeInsets.all(16),
            buildDefaultDragHandles: false,
            onReorder: (oldIndex, newIndex) {
              ref.read(dashboardConfigProvider.notifier).reorder(oldIndex, newIndex);
            },
            children: [
              for (int index = 0; index < items.length; index++)
                Card(
                  key: ValueKey(items[index].id),
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Row(
                          children: [
                            ReorderableDragStartListener(
                              index: index,
                              child: const Icon(Icons.drag_indicator, color: Colors.grey),
                            ),
                            const SizedBox(width: 16),
                            Text(
                              items[index].label,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            // Bouton de taille avec menu popup
                            PopupMenuButton<TileSize>(
                              icon: Icon(
                                _getTileSizeIcon(items[index].tileSize),
                                color: Colors.grey[700],
                              ),
                              tooltip: 'Ajuster la taille',
                              onSelected: (size) {
                                ref
                                    .read(dashboardConfigProvider.notifier)
                                    .updateTileSize(items[index].id, size);
                              },
                              itemBuilder: (context) => [
                                PopupMenuItem(
                                  value: TileSize.small,
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.crop_square,
                                        color: items[index].tileSize == TileSize.small
                                            ? Theme.of(context).colorScheme.primary
                                            : null,
                                      ),
                                      const SizedBox(width: 12),
                                      const Text('Petit (1×1)'),
                                    ],
                                  ),
                                ),
                                PopupMenuItem(
                                  value: TileSize.wide,
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.crop_16_9,
                                        color: items[index].tileSize == TileSize.wide
                                            ? Theme.of(context).colorScheme.primary
                                            : null,
                                      ),
                                      const SizedBox(width: 12),
                                      const Text('Large (2×1)'),
                                    ],
                                  ),
                                ),
                                PopupMenuItem(
                                  value: TileSize.large,
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.crop_din,
                                        color: items[index].tileSize == TileSize.large
                                            ? Theme.of(context).colorScheme.primary
                                            : null,
                                      ),
                                      const SizedBox(width: 12),
                                      const Text('Grand (2×2)'),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            Switch(
                              value: items[index].isVisible,
                              onChanged: (value) {
                                ref
                                    .read(dashboardConfigProvider.notifier)
                                    .toggleVisibility(items[index].id);
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Erreur: $err')),
      ),
    );
  }
}
