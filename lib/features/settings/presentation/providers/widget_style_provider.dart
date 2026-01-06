import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/widget_settings_repository.dart';

class WidgetStyle {
  final Color color;
  final IconData icon;

  const WidgetStyle({required this.color, required this.icon});
}

final widgetStyleProvider = Provider.family<WidgetStyle, ({String type, Color defaultColor, IconData defaultIcon})>((ref, args) {
  final settingsAsync = ref.watch(widgetSettingsProvider);
  
  return settingsAsync.maybeWhen(
    data: (settings) {
      final setting = settings.where((s) => s.widgetType == args.type).firstOrNull;
      if (setting != null) {
        return WidgetStyle(color: setting.color, icon: setting.icon);
      }
      return WidgetStyle(color: args.defaultColor, icon: args.defaultIcon);
    },
    orElse: () => WidgetStyle(color: args.defaultColor, icon: args.defaultIcon),
  );
});
