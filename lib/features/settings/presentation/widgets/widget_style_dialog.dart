import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../data/widget_settings_repository.dart';

class WidgetStyleDialog extends ConsumerWidget {
  final String label;
  final String widgetType;
  final IconData defaultIcon;

  const WidgetStyleDialog({
    super.key,
    required this.label,
    required this.widgetType,
    required this.defaultIcon,
  });

  static void show(BuildContext context, String label, String widgetType, IconData defaultIcon) {
    showDialog(
      context: context,
      builder: (context) => WidgetStyleDialog(
        label: label,
        widgetType: widgetType,
        defaultIcon: defaultIcon,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = [
      Colors.red, Colors.pink, Colors.purple, Colors.deepPurple,
      Colors.indigo, Colors.blue, Colors.lightBlue, Colors.cyan,
      Colors.teal, Colors.green, Colors.lightGreen, Colors.lime,
      Colors.yellow, Colors.amber, Colors.orange, Colors.deepOrange,
      Colors.brown, Colors.grey, Colors.blueGrey,
    ];

    return AlertDialog(
      title: Text('Personnaliser $label'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Choisir une couleur :'),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: colors.map((color) {
                return GestureDetector(
                  onTap: () {
                    ref.read(widgetSettingsRepositoryProvider).saveSetting(widgetType, color, defaultIcon);
                    context.pop();
                  },
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => context.pop(),
          child: const Text('Annuler'),
        ),
      ],
    );
  }
}
