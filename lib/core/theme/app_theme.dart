import 'package:flutter/material.dart';
import 'skin_controller.dart';

class AppTheme {
  // Getters reativos sincronizados com a Skin ativa no SkinController
  static Color get background => SkinController.instance.currentSkin.background;
  static Color get surface => SkinController.instance.currentSkin.surface;
  static Color get surfaceLight => SkinController.instance.currentSkin.surfaceLight;
  static Color get border => SkinController.instance.currentSkin.border;

  static Color get primary => SkinController.instance.currentSkin.primary;
  static Color get income => SkinController.instance.currentSkin.income;
  static Color get expense => SkinController.instance.currentSkin.expense;
  static Color get warning => SkinController.instance.currentSkin.warning;

  static Color get textPrimary => SkinController.instance.currentSkin.textPrimary;
  static Color get textSecondary => SkinController.instance.currentSkin.textSecondary;
  static Color get textMuted => SkinController.instance.currentSkin.textMuted;

  static bool get isDark => SkinController.instance.currentSkin.isDark;

  static ThemeData get theme => SkinController.instance.themeData;
  static ThemeData get darkTheme => SkinController.instance.themeData;
}
