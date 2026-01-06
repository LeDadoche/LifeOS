import 'package:flutter/material.dart';
import '../../../settings/presentation/widgets/widget_style_dialog.dart';
import '../../data/dashboard_config_service.dart';

class DashboardWidgetWrapper extends StatelessWidget {
  final Widget child;
  final String label;
  final String widgetType;
  final IconData defaultIcon;
  final bool isEditMode;
  final TileSize currentSize;
  final void Function(TileSize)? onResize;

  const DashboardWidgetWrapper({
    super.key,
    required this.child,
    required this.label,
    required this.widgetType,
    required this.defaultIcon,
    this.isEditMode = false,
    this.currentSize = TileSize.small,
    this.onResize,
  });

  void _showContextMenu(BuildContext context, Offset position) {
    showMenu(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        position.dx + 1,
        position.dy + 1,
      ),
      items: [
        const PopupMenuItem(
          value: 'customize',
          child: ListTile(
            leading: Icon(Icons.palette_outlined),
            title: Text('Personnaliser l\'apparence'),
            contentPadding: EdgeInsets.zero,
            dense: true,
          ),
        ),
        const PopupMenuItem(
          value: 'resize',
          child: ListTile(
            leading: Icon(Icons.aspect_ratio),
            title: Text('Ajuster'),
            contentPadding: EdgeInsets.zero,
            dense: true,
          ),
        ),
      ],
    ).then((value) {
      if (value == 'customize') {
        WidgetStyleDialog.show(context, label, widgetType, defaultIcon);
      } else if (value == 'resize') {
        _showResizeDialog(context);
      }
    });
  }

  void _showResizeDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => _ResizeDialog(
        currentSize: currentSize,
        widgetLabel: label,
        onSizeSelected: (size) {
          onResize?.call(size);
          Navigator.of(context).pop();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onSecondaryTapUp: (details) {
        _showContextMenu(context, details.globalPosition);
      },
      onLongPressStart: (details) {
        if (!isEditMode) {
          _showContextMenu(context, details.globalPosition);
        }
      },
      child: child,
    );
  }
}

/// Dialog pour choisir la taille de la tuile
class _ResizeDialog extends StatelessWidget {
  final TileSize currentSize;
  final String widgetLabel;
  final void Function(TileSize) onSizeSelected;

  const _ResizeDialog({
    required this.currentSize,
    required this.widgetLabel,
    required this.onSizeSelected,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return AlertDialog(
      title: Text('Ajuster "$widgetLabel"'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Choisissez la taille de la tuile :',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            alignment: WrapAlignment.center,
            children: [
              _SizeOption(
                label: 'Petit',
                subtitle: '1×1',
                icon: Icons.crop_square,
                isSelected: currentSize == TileSize.small,
                onTap: () => onSizeSelected(TileSize.small),
                colorScheme: colorScheme,
              ),
              _SizeOption(
                label: 'Large',
                subtitle: '2×1',
                icon: Icons.crop_16_9,
                isSelected: currentSize == TileSize.wide,
                onTap: () => onSizeSelected(TileSize.wide),
                colorScheme: colorScheme,
              ),
              _SizeOption(
                label: 'Haut',
                subtitle: '1×2',
                icon: Icons.crop_portrait,
                isSelected: currentSize == TileSize.tall,
                onTap: () => onSizeSelected(TileSize.tall),
                colorScheme: colorScheme,
              ),
              _SizeOption(
                label: 'Grand',
                subtitle: '2×2',
                icon: Icons.crop_din,
                isSelected: currentSize == TileSize.large,
                onTap: () => onSizeSelected(TileSize.large),
                colorScheme: colorScheme,
              ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Annuler'),
        ),
      ],
    );
  }
}

/// Option de taille individuelle
class _SizeOption extends StatelessWidget {
  final String label;
  final String subtitle;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;
  final ColorScheme colorScheme;

  const _SizeOption({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.isSelected,
    required this.onTap,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? colorScheme.primaryContainer
              : colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? colorScheme.primary : Colors.transparent,
            width: 2,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 32,
              color: isSelected
                  ? colorScheme.onPrimaryContainer
                  : colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected
                    ? colorScheme.onPrimaryContainer
                    : colorScheme.onSurfaceVariant,
              ),
            ),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 12,
                color: isSelected
                    ? colorScheme.onPrimaryContainer.withOpacity(0.7)
                    : colorScheme.onSurfaceVariant.withOpacity(0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
