import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/theme_provider.dart';
import '../widgets/widget_style_dialog.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeState = ref.watch(themeNotifierProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Paramètres'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: ListView(
        children: [
          _buildSectionHeader(context, 'Affichage'),
          SwitchListTile(
            title: const Text('Mode Sombre'),
            value: themeState.mode == ThemeMode.dark,
            onChanged: (value) {
              ref.read(themeNotifierProvider.notifier).toggleMode();
            },
            secondary: Icon(
              themeState.mode == ThemeMode.dark ? Icons.dark_mode : Icons.light_mode,
            ),
          ),
          const Divider(),
          _buildSectionHeader(context, 'Thème Global'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _buildColorOption(ref, themeState.scheme, FlexScheme.mandyRed, Colors.pink),
                _buildColorOption(ref, themeState.scheme, FlexScheme.materialBaseline, Colors.purple),
                _buildColorOption(ref, themeState.scheme, FlexScheme.blueWhale, Colors.blue),
                _buildColorOption(ref, themeState.scheme, FlexScheme.jungle, Colors.green),
                _buildColorOption(ref, themeState.scheme, FlexScheme.mango, Colors.orange),
              ],
            ),
          ),
          const Divider(),
          _buildSectionHeader(context, 'Personnalisation des Widgets'),
          _buildWidgetCustomizationTile(context, ref, 'Argent', 'money', Icons.attach_money),
          _buildWidgetCustomizationTile(context, ref, 'Tâches', 'tasks', Icons.check_circle_outline),
          _buildWidgetCustomizationTile(context, ref, 'Notes', 'notes', Icons.note),
          _buildWidgetCustomizationTile(context, ref, 'Agenda', 'agenda', Icons.calendar_today),
          _buildWidgetCustomizationTile(context, ref, 'Cuisine', 'kitchen', Icons.restaurant_menu),
          const Divider(),
          _buildSectionHeader(context, 'À propos'),
          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('LifeOS'),
            subtitle: Text('v0.1.0'),
          ),
        ],
      ),
    );
  }

  Widget _buildWidgetCustomizationTile(BuildContext context, WidgetRef ref, String label, String type, IconData defaultIcon) {
    return ListTile(
      leading: Icon(defaultIcon),
      title: Text(label),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => WidgetStyleDialog.show(context, label, type, defaultIcon),
    );
  }

  Widget _buildColorOption(WidgetRef ref, FlexScheme current, FlexScheme scheme, Color color) {
    final isSelected = current == scheme;
    return GestureDetector(
      onTap: () {
        ref.read(themeNotifierProvider.notifier).setScheme(scheme);
      },
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: isSelected ? Border.all(color: Colors.white, width: 3) : null,
          boxShadow: [
            if (isSelected)
              BoxShadow(
                color: color.withOpacity(0.4),
                blurRadius: 8,
                spreadRadius: 2,
              )
          ],
        ),
        child: isSelected
            ? const Icon(Icons.check, color: Colors.white)
            : null,
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title.toUpperCase(),
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }
}

