import 'package:flutter/material.dart';

class WidgetSetting {
  final String widgetType;
  final int colorValue;
  final int iconCodePoint;

  const WidgetSetting({
    required this.widgetType,
    required this.colorValue,
    required this.iconCodePoint,
  });

  factory WidgetSetting.fromJson(Map<String, dynamic> json) {
    return WidgetSetting(
      widgetType: json['widget_type'] as String,
      colorValue: json['color_value'] as int,
      iconCodePoint: json['icon_code_point'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'widget_type': widgetType,
      'color_value': colorValue,
      'icon_code_point': iconCodePoint,
    };
  }

  Color get color => Color(colorValue);
  IconData get icon => IconData(iconCodePoint, fontFamily: 'MaterialIcons');
}
