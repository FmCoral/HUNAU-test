import 'package:flutter/material.dart';
import 'app_tokens.dart';

/// 简约数据派全局主题。
///
/// 规则（对应 docs/App_UI_视觉规范_简约数据派.md）：
/// - 浅灰底 `#F3F4F6`，白色内容面；深色用冷调深灰
/// - 绿色只强调重点；实心主按钮用 `#166534`（深色模式 `#4ADE80`）
/// - 卡片：白底 + 1px 细边框 + 14 圆角，默认无阴影
/// - 控件圆角 8，内嵌容器 12，弹层 14
/// - 禁止渐变填充、玻璃拟态、重阴影
class AppTheme {
  AppTheme._();

  static ThemeData light() => _build(AppSemanticColors.light, Brightness.light);
  static ThemeData dark() => _build(AppSemanticColors.dark, Brightness.dark);

  static ThemeData _build(AppSemanticColors c, Brightness brightness) {
    final isDark = brightness == Brightness.dark;

    final colorScheme = ColorScheme(
      brightness: brightness,
      primary: c.brand,
      onPrimary: isDark ? AppColors.bgDark : Colors.white,
      secondary: c.brand,
      onSecondary: isDark ? AppColors.bgDark : Colors.white,
      error: c.danger,
      onError: Colors.white,
      surface: c.surface,
      onSurface: c.text,
      surfaceContainerHighest: c.surfaceSubtle,
      outline: c.border,
      outlineVariant: c.border,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      fontFamily: 'sans-serif',
      splashFactory: InkRipple.splashFactory,
      colorScheme: colorScheme,
      primaryColor: c.brand,
      scaffoldBackgroundColor: c.bg,
      extensions: [c],

      // 顶部导航：中性背景 + 细分割线，标题 20/700
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: c.bg,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: AppText.pageTitle.copyWith(color: c.text),
        iconTheme: IconThemeData(color: c.text),
      ),

      // 卡片：1px 边框 + 14 圆角 + 无阴影
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: c.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.cardAll,
          side: BorderSide(color: c.border),
        ),
      ),

      // 底部导航：仅激活态绿色
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: c.surface,
        selectedItemColor: c.brand,
        unselectedItemColor: c.textMuted,
        selectedLabelStyle:
            const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        unselectedLabelStyle: const TextStyle(fontSize: 12),
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),

      // 弹层：白色内容面 + 14 圆角
      dialogTheme: DialogThemeData(
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.cardAll),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.card)),
        ),
      ),

      // 列表行：细分隔线
      listTileTheme: ListTileThemeData(
        iconColor: c.textMuted,
        textColor: c.text,
        minTileHeight: 48,
      ),
      dividerTheme: DividerThemeData(
        color: c.border,
        thickness: 1,
        space: 1,
      ),

      // 输入框：8 圆角 + 浅边框，聚焦绿色描边
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.surface,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: AppRadius.controlAll,
          borderSide: BorderSide(color: c.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.controlAll,
          borderSide: BorderSide(color: c.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.controlAll,
          borderSide: BorderSide(color: c.brand, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: AppRadius.controlAll,
          borderSide: BorderSide(color: c.danger),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: AppRadius.controlAll,
          borderSide: BorderSide(color: c.danger, width: 1.5),
        ),
        labelStyle: AppText.bodyDense.copyWith(color: c.textMuted),
        hintStyle: AppText.bodyDense.copyWith(color: c.textMuted),
      ),

      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: c.brand,
        linearTrackColor: c.brand.withValues(alpha: 0.15),
        circularTrackColor: c.brand.withValues(alpha: 0.15),
      ),

      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: c.primaryButtonBg,
        foregroundColor: isDark ? AppColors.bgDark : Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.controlAll),
      ),

      // 主按钮：深绿实心 + 白字 + 8 圆角 + 高 48
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: c.primaryButtonBg,
          foregroundColor: isDark ? AppColors.bgDark : Colors.white,
          disabledBackgroundColor: c.primaryButtonBg.withValues(alpha: 0.12),
          disabledForegroundColor: c.textMuted,
          minimumSize: const Size.fromHeight(48),
          elevation: 0,
          textStyle:
              const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(borderRadius: AppRadius.controlAll),
        ),
      ),

      // 次按钮：白底 + 浅灰描边 + 深色字
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: c.text,
          side: BorderSide(color: c.border),
          minimumSize: const Size.fromHeight(44),
          textStyle:
              const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
          shape: RoundedRectangleBorder(borderRadius: AppRadius.controlAll),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: c.brandText,
          textStyle:
              const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          shape: RoundedRectangleBorder(borderRadius: AppRadius.controlAll),
        ),
      ),

      // 开关/复选：绿色仅作选中态
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? (isDark ? AppColors.bgDark : Colors.white)
              : null,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? c.brand : null,
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.selected) ? c.brand : Colors.transparent,
        ),
        side: BorderSide(color: c.textMuted, width: 1.5),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.selected) ? c.brand : c.textMuted,
        ),
      ),

      tabBarTheme: TabBarThemeData(
        labelColor: c.brand,
        unselectedLabelColor: c.textMuted,
        indicatorColor: c.brand,
      ),

      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isDark ? c.surfaceSubtle : const Color(0xFF1F2937),
        contentTextStyle: TextStyle(color: isDark ? c.text : Colors.white),
        shape: RoundedRectangleBorder(borderRadius: AppRadius.controlAll),
      ),

      dividerColor: c.border,
    );
  }
}
