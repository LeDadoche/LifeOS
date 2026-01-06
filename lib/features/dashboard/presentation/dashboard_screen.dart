import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../money/presentation/widgets/money_dashboard_tile.dart';
import '../../tasks/presentation/widgets/tasks_dashboard_tile.dart';
import '../../notes/presentation/widgets/notes_dashboard_tile.dart';
import '../../agenda/presentation/widgets/agenda_dashboard_tile.dart';
import '../../meals/presentation/widgets/kitchen_dashboard_tile.dart';
import '../../dashboard/data/dashboard_config_service.dart';
import 'widgets/dashboard_widget_wrapper.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _floatingController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _shadowAnimation;

  // Pour le drag libre
  String? _draggingItemId;
  Offset? _dragStartOffset;
  int _dragStartX = 0;
  int _dragStartY = 0;

  // Pour le resize par poignée
  String? _resizingItemId;
  Offset? _resizeStartOffset;
  int _resizeStartWidth = 1;
  int _resizeStartHeight = 1;

  // Ghost position pour preview
  int? _ghostX;
  int? _ghostY;

  @override
  void initState() {
    super.initState();
    _floatingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.03).animate(
      CurvedAnimation(parent: _floatingController, curve: Curves.easeInOut),
    );

    _shadowAnimation = Tween<double>(begin: 4.0, end: 12.0).animate(
      CurvedAnimation(parent: _floatingController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _floatingController.dispose();
    super.dispose();
  }

  /// Détecte et applique le layout approprié (appelé depuis LayoutBuilder)
  void _detectAndApplyLayout(double width, double height) {
    final isLandscape = width > height;
    final newLayoutType = detectLayoutType(width, height, isLandscape);

    final currentLayoutType = ref.read(currentLayoutTypeProvider);
    if (newLayoutType != currentLayoutType) {
      print(
          '[Dashboard UI] Changement de layout détecté: ${currentLayoutType.displayName} → ${newLayoutType.displayName}');
      // Utiliser addPostFrameCallback pour éviter setState pendant le build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ref.read(currentLayoutTypeProvider.notifier).state = newLayoutType;
          ref
              .read(dashboardConfigProvider.notifier)
              .switchLayout(newLayoutType);
        }
      });
    }
  }

  /// Returns the number of grid columns based on current layout
  int _getColumnCount(double width) {
    final layoutType = ref.read(currentLayoutTypeProvider);
    return layoutType.columnCount;
  }

  /// Calcule la hauteur max du canvas basée sur les widgets
  int _getMaxRows(List<DashboardItem> items) {
    int maxRow = 4; // Minimum 4 lignes
    for (final item in items.where((i) => i.isVisible)) {
      final itemBottom = item.y + item.height;
      if (itemBottom > maxRow) maxRow = itemBottom;
    }
    return maxRow + 2; // Ajouter 2 lignes vides en bas pour expansion
  }

  @override
  Widget build(BuildContext context) {
    final configAsync = ref.watch(dashboardConfigProvider);
    final isEditMode = ref.watch(dashboardEditModeProvider);
    final currentLayout = ref.watch(currentLayoutTypeProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('LifeOS'),
        titleSpacing: 8,
        actions: [
          // Bouton ajouter widget (mode édition uniquement)
          if (isEditMode)
            IconButton(
              icon: const Icon(Icons.add_circle_outline),
              tooltip: 'Ajouter un widget',
              onPressed: () => _showAddWidgetSheet(context),
            ),
          IconButton(
            icon: Icon(
              isEditMode ? Icons.edit_off : Icons.edit,
              color: isEditMode ? Theme.of(context).colorScheme.primary : null,
            ),
            tooltip: isEditMode ? 'Quitter le mode édition' : 'Mode édition',
            onPressed: () {
              ref.read(dashboardEditModeProvider.notifier).state = !isEditMode;
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      floatingActionButton: isEditMode
          ? FloatingActionButton.extended(
              onPressed: () {
                ref.read(dashboardEditModeProvider.notifier).state = false;
                ScaffoldMessenger.of(context).clearSnackBars();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Modifications enregistrées !'),
                    behavior: SnackBarBehavior.floating,
                    duration: Duration(seconds: 2),
                  ),
                );
              },
              icon: const Icon(Icons.check),
              label: const Text('Terminer'),
            )
          : null,
      body: configAsync.when(
        data: (items) {
          final visibleItems = items.where((i) => i.isVisible).toList();

          if (visibleItems.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Aucun widget activé'),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: () => context.push('/customize'),
                    icon: const Icon(Icons.edit),
                    label: const Text('Personnaliser'),
                  ),
                ],
              ),
            );
          }

          return LayoutBuilder(
            builder: (context, constraints) {
              // Détecter le layout basé sur les contraintes réelles
              _detectAndApplyLayout(
                  constraints.maxWidth, constraints.maxHeight);

              final columnCount = _getColumnCount(constraints.maxWidth);
              final maxRows = _getMaxRows(visibleItems);
              const padding = 16.0;
              const spacing = 12.0;
              final availableWidth = constraints.maxWidth - (padding * 2);
              final cellWidth =
                  (availableWidth - (spacing * (columnCount - 1))) /
                      columnCount;
              final cellHeight = cellWidth; // Cellules carrées
              final canvasHeight = (cellHeight * maxRows) +
                  (spacing * (maxRows - 1)) +
                  padding * 2;

              return SingleChildScrollView(
                padding: const EdgeInsets.only(
                    bottom: 100.0, left: padding, right: padding, top: padding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (isEditMode) _buildEditModeHeader(),
                    SizedBox(
                      width: availableWidth,
                      height: canvasHeight,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          // Grille de fond en mode édition
                          if (isEditMode)
                            _buildGridOverlay(columnCount, maxRows, cellWidth,
                                cellHeight, spacing),

                          // Ghost preview pendant le drag
                          if (isEditMode &&
                              _draggingItemId != null &&
                              _ghostX != null &&
                              _ghostY != null)
                            _buildGhostPreview(
                              visibleItems
                                  .firstWhere((i) => i.id == _draggingItemId),
                              cellWidth,
                              cellHeight,
                              spacing,
                            ),

                          // Les tuiles positionnées
                          ...visibleItems.map((item) => _buildPositionedTile(
                                item,
                                visibleItems,
                                columnCount,
                                cellWidth,
                                cellHeight,
                                spacing,
                                isEditMode,
                              )),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Erreur: $err')),
      ),
    );
  }

  Widget _buildEditModeHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline,
            size: 20,
            color: Theme.of(context).colorScheme.onPrimaryContainer,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Glissez librement • Tirez le coin pour redimensionner',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onPrimaryContainer,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Grille de fond pour visualiser les cellules en mode édition
  Widget _buildGridOverlay(int columnCount, int maxRows, double cellWidth,
      double cellHeight, double spacing) {
    return CustomPaint(
      size: Size(
        columnCount * cellWidth + (columnCount - 1) * spacing,
        maxRows * cellHeight + (maxRows - 1) * spacing,
      ),
      painter: _GridPainter(
        columns: columnCount,
        rows: maxRows,
        cellWidth: cellWidth,
        cellHeight: cellHeight,
        spacing: spacing,
        color: Theme.of(context).colorScheme.outline.withOpacity(0.15),
      ),
    );
  }

  /// Ghost preview montrant où la tuile sera placée
  Widget _buildGhostPreview(
      DashboardItem item, double cellWidth, double cellHeight, double spacing) {
    final left = _ghostX! * (cellWidth + spacing);
    final top = _ghostY! * (cellHeight + spacing);
    final width = item.width * cellWidth + (item.width - 1) * spacing;
    final height = item.height * cellHeight + (item.height - 1) * spacing;

    final canPlace = ref.read(dashboardConfigProvider.notifier).canPlaceAt(
          item.id,
          _ghostX!,
          _ghostY!,
          item.width,
          item.height,
          _getColumnCount(MediaQuery.of(context).size.width),
        );

    return Positioned(
      left: left,
      top: top,
      width: width,
      height: height,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: canPlace
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.error,
            width: 3,
          ),
          color: (canPlace
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.error)
              .withOpacity(0.2),
        ),
      ),
    );
  }

  Widget _buildPositionedTile(
    DashboardItem item,
    List<DashboardItem> items,
    int columnCount,
    double cellWidth,
    double cellHeight,
    double spacing,
    bool isEditMode,
  ) {
    // Calculer position pixel à partir des coordonnées de grille
    final left = item.x * (cellWidth + spacing);
    final top = item.y * (cellHeight + spacing);
    final width = item.width * cellWidth + (item.width - 1) * spacing;
    final height = item.height * cellHeight + (item.height - 1) * spacing;

    // Si on drag cette tuile, la rendre semi-transparente à sa place d'origine
    final isDragging = _draggingItemId == item.id;

    return Positioned(
      key: ValueKey('pos_${item.id}'),
      left: left,
      top: top,
      width: width,
      height: height,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 150),
        opacity: isDragging ? 0.3 : 1.0,
        child: isEditMode
            ? _buildEditableTile(
                item, items, columnCount, cellWidth, cellHeight, spacing)
            : _buildStaticTile(item),
      ),
    );
  }

  Widget _buildStaticTile(DashboardItem item) {
    return DashboardWidgetWrapper(
      key: ValueKey('wrapper_${item.id}'),
      label: item.label,
      widgetType: item.id,
      defaultIcon: _getIconForWidget(item.id),
      isEditMode: false,
      currentSize: item.tileSize,
      onResize: (newSize) {
        ref
            .read(dashboardConfigProvider.notifier)
            .updateTileSize(item.id, newSize);
      },
      child: _buildTileContent(item),
    );
  }

  Widget _buildEditableTile(
    DashboardItem item,
    List<DashboardItem> items,
    int columnCount,
    double cellWidth,
    double cellHeight,
    double spacing,
  ) {
    return AnimatedBuilder(
      animation: _floatingController,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: GestureDetector(
            onPanStart: (details) => _onDragStart(item, details),
            onPanUpdate: (details) => _onDragUpdate(
                item, details, columnCount, cellWidth, cellHeight, spacing),
            onPanEnd: (details) => _onDragEnd(item, columnCount),
            child: _buildTileWithOverlay(
                item, columnCount, cellWidth, cellHeight, spacing),
          ),
        );
      },
    );
  }

  Widget _buildTileWithOverlay(DashboardItem item, int columnCount,
      double cellWidth, double cellHeight, double spacing,
      {bool isDragging = false}) {
    final colorScheme = Theme.of(context).colorScheme;

    return Stack(
      key: ValueKey('stack_${item.id}'),
      clipBehavior: Clip.none,
      children: [
        // Contenu de la tuile avec ombre dynamique
        Positioned.fill(
          child: AnimatedBuilder(
            animation: _shadowAnimation,
            builder: (context, child) {
              return Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: colorScheme.shadow
                          .withOpacity(isDragging ? 0.3 : 0.15),
                      blurRadius: isDragging ? 16 : _shadowAnimation.value,
                      offset: Offset(
                          0, isDragging ? 8 : _shadowAnimation.value / 2),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: SizedBox.expand(
                    child: _buildTileContent(item),
                  ),
                ),
              );
            },
          ),
        ),

        // Bouton de suppression en haut à gauche
        if (!isDragging)
          Positioned(
            top: 8,
            left: 8,
            child: GestureDetector(
              onTap: () => _removeWidget(item),
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: colorScheme.error,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.close,
                  size: 18,
                  color: Colors.white,
                ),
              ),
            ),
          ),

        // Icône centrale de déplacement (20% opacité)
        if (!isDragging)
          Positioned.fill(
            child: Center(
              child: Icon(
                Icons.open_with,
                size: 48,
                color: colorScheme.onSurface.withOpacity(0.2),
              ),
            ),
          ),

        // Poignée de redimensionnement en bas à droite
        if (!isDragging)
          Positioned(
            bottom: 12,
            right: 12,
            child: GestureDetector(
              onPanStart: (details) => _onResizeStart(item, details),
              onPanUpdate: (details) => _onResizeUpdate(
                  item, details, columnCount, cellWidth, cellHeight),
              onPanEnd: (details) => _onResizeEnd(item, columnCount),
              child: Icon(
                Icons.south_east,
                size: 24,
                color: colorScheme.onSurface.withOpacity(0.25),
              ),
            ),
          ),
      ],
    );
  }

  // ============ DRAG HANDLERS ============

  void _onDragStart(DashboardItem item, DragStartDetails details) {
    setState(() {
      _draggingItemId = item.id;
      _dragStartOffset = details.globalPosition;
      _dragStartX = item.x;
      _dragStartY = item.y;
      _ghostX = item.x;
      _ghostY = item.y;
    });
  }

  void _onDragUpdate(
    DashboardItem item,
    DragUpdateDetails details,
    int columnCount,
    double cellWidth,
    double cellHeight,
    double spacing,
  ) {
    if (_draggingItemId != item.id || _dragStartOffset == null) return;

    final delta = details.globalPosition - _dragStartOffset!;
    final cellTotalWidth = cellWidth + spacing;
    final cellTotalHeight = cellHeight + spacing;

    final deltaX = (delta.dx / cellTotalWidth).round();
    final deltaY = (delta.dy / cellTotalHeight).round();

    final newX = (_dragStartX + deltaX).clamp(0, columnCount - item.width);
    final newY = (_dragStartY + deltaY).clamp(0, 20);

    if (newX != _ghostX || newY != _ghostY) {
      setState(() {
        _ghostX = newX;
        _ghostY = newY;
      });
    }
  }

  void _onDragEnd(DashboardItem item, int columnCount) {
    if (_ghostX != null && _ghostY != null) {
      final canPlace = ref.read(dashboardConfigProvider.notifier).canPlaceAt(
            item.id,
            _ghostX!,
            _ghostY!,
            item.width,
            item.height,
            columnCount,
          );

      if (canPlace) {
        ref
            .read(dashboardConfigProvider.notifier)
            .updatePosition(item.id, _ghostX!, _ghostY!);
      }
      // Si collision, la tuile reste à sa place d'origine (pas de mouvement)
    }

    setState(() {
      _draggingItemId = null;
      _dragStartOffset = null;
      _ghostX = null;
      _ghostY = null;
    });
  }

  // ============ RESIZE HANDLERS ============

  void _onResizeStart(DashboardItem item, DragStartDetails details) {
    setState(() {
      _resizingItemId = item.id;
      _resizeStartOffset = details.globalPosition;
      _resizeStartWidth = item.width;
      _resizeStartHeight = item.height;
    });
  }

  void _onResizeUpdate(
    DashboardItem item,
    DragUpdateDetails details,
    int columnCount,
    double cellWidth,
    double cellHeight,
  ) {
    if (_resizingItemId != item.id || _resizeStartOffset == null) return;

    final delta = details.globalPosition - _resizeStartOffset!;
    final widthDelta = (delta.dx / cellWidth).round();
    final heightDelta = (delta.dy / cellHeight).round();

    final newWidth = (_resizeStartWidth + widthDelta).clamp(1, 4);
    final newHeight = (_resizeStartHeight + heightDelta).clamp(1, 4);

    // Vérifier que le resize ne sort pas de la grille
    final maxWidth = columnCount - item.x;
    final clampedWidth = newWidth.clamp(1, maxWidth);

    if (clampedWidth != item.width || newHeight != item.height) {
      // Vérifier les collisions avec la nouvelle taille
      final canResize = ref.read(dashboardConfigProvider.notifier).canPlaceAt(
            item.id,
            item.x,
            item.y,
            clampedWidth,
            newHeight,
            columnCount,
          );

      if (canResize) {
        ref
            .read(dashboardConfigProvider.notifier)
            .updateSize(item.id, clampedWidth, newHeight);
      }
    }
  }

  void _onResizeEnd(DashboardItem item, int columnCount) {
    setState(() {
      _resizingItemId = null;
      _resizeStartOffset = null;
    });
  }

  // ============ HELPERS ============

  Widget _buildTileContent(DashboardItem item) {
    switch (item.id) {
      case 'agenda':
        return const AgendaDashboardTile(key: ValueKey('content_agenda'));
      case 'money':
        return const MoneyDashboardTile(key: ValueKey('content_money'));
      case 'tasks':
        return const TasksDashboardTile(key: ValueKey('content_tasks'));
      case 'notes':
        return const NotesDashboardTile(key: ValueKey('content_notes'));
      case 'kitchen':
        return const KitchenDashboardTile(key: ValueKey('content_kitchen'));
      default:
        return const SizedBox.shrink();
    }
  }

  IconData _getIconForWidget(String id) {
    switch (id) {
      case 'agenda':
        return Icons.calendar_today;
      case 'money':
        return Icons.attach_money;
      case 'tasks':
        return Icons.check_circle_outline;
      case 'notes':
        return Icons.note;
      case 'kitchen':
        return Icons.restaurant_menu;
      default:
        return Icons.widgets;
    }
  }

  /// Affiche le bottom sheet pour ajouter un widget
  void _showAddWidgetSheet(BuildContext context) {
    final columnCount = _getColumnCount(MediaQuery.of(context).size.width);

    // Debug : afficher l'état actuel
    ref.read(dashboardConfigProvider.notifier).debugPrintWidgets();
    print('[Dashboard UI] Colonnes actuelles: $columnCount');

    // Obtenir les widgets cachés OU hors écran
    final hiddenWidgets = ref
        .read(dashboardConfigProvider.notifier)
        .getHiddenWidgets(columnCount);
    print(
        '[Dashboard UI] Widgets disponibles pour ajout: ${hiddenWidgets.map((w) => w.id).join(', ')}');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurfaceVariant
                        .withOpacity(0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Ajouter un widget',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 16),

              if (hiddenWidgets.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle,
                          color: Theme.of(context).colorScheme.primary),
                      const SizedBox(width: 12),
                      Text(
                        'Tous les widgets sont affichés',
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ],
                  ),
                )
              else
                ...hiddenWidgets.map((widget) => ListTile(
                      leading: CircleAvatar(
                        backgroundColor:
                            Theme.of(context).colorScheme.primaryContainer,
                        child: Icon(
                          _getIconForWidget(widget.id),
                          color:
                              Theme.of(context).colorScheme.onPrimaryContainer,
                        ),
                      ),
                      title: Text(widget.label),
                      subtitle: Text(
                        widget.isVisible
                            ? 'Hors écran (sera repositionné)'
                            : '${widget.width}x${widget.height} cellules',
                      ),
                      trailing: const Icon(Icons.add_circle_outline),
                      onTap: () {
                        Navigator.pop(sheetContext);
                        ref
                            .read(dashboardConfigProvider.notifier)
                            .showWidget(widget.id, columnCount);
                        ScaffoldMessenger.of(context).clearSnackBars();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content:
                                Text('${widget.label} ajouté au dashboard'),
                            behavior: SnackBarBehavior.floating,
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      },
                    )),

              const Divider(height: 32),

              // Bouton réparer les widgets hors écran
              ListTile(
                leading: CircleAvatar(
                  backgroundColor:
                      Theme.of(context).colorScheme.tertiaryContainer,
                  child: Icon(Icons.auto_fix_high,
                      color: Theme.of(context).colorScheme.onTertiaryContainer),
                ),
                title: const Text('Réparer les widgets'),
                subtitle: const Text('Repositionne les widgets hors écran'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  ref
                      .read(dashboardConfigProvider.notifier)
                      .fixOutOfBoundsWidgets(columnCount);
                  ScaffoldMessenger.of(context).clearSnackBars();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Widgets repositionnés !'),
                      behavior: SnackBarBehavior.floating,
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
              ),

              // Bouton Hard Reset
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: Theme.of(context).colorScheme.errorContainer,
                  child: Icon(Icons.refresh,
                      color: Theme.of(context).colorScheme.onErrorContainer),
                ),
                title: const Text('Réinitialiser le Dashboard'),
                subtitle: const Text('Restaure la disposition par défaut'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _confirmHardReset(context);
                },
              ),

              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  /// Confirmation avant Hard Reset
  void _confirmHardReset(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: Icon(Icons.warning_amber,
            size: 48, color: Theme.of(context).colorScheme.error),
        title: const Text('Réinitialiser le Dashboard ?'),
        content: const Text(
          'Cette action va restaurer tous les widgets à leur position par défaut. '
          'Vos personnalisations seront perdues.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Annuler'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () {
              Navigator.pop(dialogContext);
              ref.read(dashboardConfigProvider.notifier).hardReset();
              ScaffoldMessenger.of(context).clearSnackBars();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Dashboard réinitialisé !'),
                  behavior: SnackBarBehavior.floating,
                  duration: Duration(seconds: 2),
                ),
              );
            },
            child: const Text('Réinitialiser'),
          ),
        ],
      ),
    );
  }

  /// Supprime un widget du dashboard
  void _removeWidget(DashboardItem item) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Retirer ce widget ?'),
        content: Text(
            'Le widget "${item.label}" sera retiré du dashboard. Vous pourrez le réajouter plus tard.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              ref.read(dashboardConfigProvider.notifier).hideWidget(item.id);
              ScaffoldMessenger.of(context).clearSnackBars();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('${item.label} retiré'),
                  behavior: SnackBarBehavior.floating,
                  duration: const Duration(seconds: 2),
                  action: SnackBarAction(
                    label: 'Annuler',
                    onPressed: () {
                      final columnCount =
                          _getColumnCount(MediaQuery.of(context).size.width);
                      ref
                          .read(dashboardConfigProvider.notifier)
                          .showWidget(item.id, columnCount);
                    },
                  ),
                ),
              );
            },
            child: const Text('Retirer'),
          ),
        ],
      ),
    );
  }
}

/// Custom painter pour dessiner la grille de fond
class _GridPainter extends CustomPainter {
  final int columns;
  final int rows;
  final double cellWidth;
  final double cellHeight;
  final double spacing;
  final Color color;

  _GridPainter({
    required this.columns,
    required this.rows,
    required this.cellWidth,
    required this.cellHeight,
    required this.spacing,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    for (int row = 0; row < rows; row++) {
      for (int col = 0; col < columns; col++) {
        final left = col * (cellWidth + spacing);
        final top = row * (cellHeight + spacing);
        final rect = RRect.fromRectAndRadius(
          Rect.fromLTWH(left, top, cellWidth, cellHeight),
          const Radius.circular(12),
        );
        canvas.drawRRect(rect, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _GridPainter oldDelegate) {
    return columns != oldDelegate.columns ||
        rows != oldDelegate.rows ||
        cellWidth != oldDelegate.cellWidth;
  }
}
