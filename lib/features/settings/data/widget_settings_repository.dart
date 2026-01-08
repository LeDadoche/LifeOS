import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'widget_settings_model.dart';

part 'widget_settings_repository.g.dart';

@riverpod
WidgetSettingsRepository widgetSettingsRepository(WidgetSettingsRepositoryRef ref) {
  return WidgetSettingsRepository(Supabase.instance.client);
}

@riverpod
Stream<List<WidgetSetting>> widgetSettings(WidgetSettingsRef ref) {
  return ref.watch(widgetSettingsRepositoryProvider).getSettings();
}

class WidgetSettingsRepository {
  final SupabaseClient _client;

  WidgetSettingsRepository(this._client);

  Stream<List<WidgetSetting>> getSettings() {
    debugPrint('🔄 [Realtime] Initialisation stream WIDGET_SETTINGS');
    return _client
        .from('widget_settings')
        .stream(primaryKey: ['widget_type'])
        .map((data) {
          debugPrint('🔄 [Realtime] Nouvelle donnée reçue pour [widget_settings] - ${data.length} éléments');
          return data.map((json) => WidgetSetting.fromJson(json)).toList();
        });
  }

  Future<void> saveSetting(String widgetType, Color color, IconData icon) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;

    final data = {
      'user_id': userId,
      'widget_type': widgetType,
      'color_value': color.value,
      'icon_code_point': icon.codePoint,
    };

    await _client.from('widget_settings').upsert(data, onConflict: 'user_id, widget_type');
  }
}
