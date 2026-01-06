import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'theme_provider.g.dart';

class ThemeState {
  final ThemeMode mode;
  final FlexScheme scheme;

  const ThemeState({
    this.mode = ThemeMode.dark,
    this.scheme = FlexScheme.mandyRed,
  });

  ThemeState copyWith({
    ThemeMode? mode,
    FlexScheme? scheme,
  }) {
    return ThemeState(
      mode: mode ?? this.mode,
      scheme: scheme ?? this.scheme,
    );
  }
}

@riverpod
class ThemeNotifier extends _$ThemeNotifier {
  @override
  ThemeState build() {
    return const ThemeState();
  }

  void toggleMode() {
    state = state.copyWith(
      mode: state.mode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light,
    );
  }

  void setMode(ThemeMode mode) {
    state = state.copyWith(mode: mode);
  }

  void setScheme(FlexScheme scheme) {
    state = state.copyWith(scheme: scheme);
  }
}
