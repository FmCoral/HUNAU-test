import 'package:flutter/material.dart';

/// 简约数据派设计 Token。
///
/// 色彩与深浅色值严格对应 docs/App_UI_视觉规范_简约数据派.md 第 02 节。
/// 页面与组件内禁止再硬编码颜色、圆角和间距，统一从这里取。
class AppColors {
  AppColors._();

  // ---------- 浅色模式 ----------
  static const Color bg = Color(0xFFF3F4F6);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceSubtle = Color(0xFFF9FAFB);
  static const Color text = Color(0xFF111827);
  static const Color textMuted = Color(0xFF6B7280);
  static const Color border = Color(0xFFE5E7EB);
  static const Color brand = Color(0xFF16A34A);
  static const Color brandText = Color(0xFF166534);
  static const Color primaryButtonBg = Color(0xFF166534);
  static const Color danger = Color(0xFFDC2626);
  static const Color warning = Color(0xFFD97706);
  static const Color info = Color(0xFF0EA5E9);

  // ---------- 深色模式 ----------
  static const Color bgDark = Color(0xFF0F1115);
  static const Color surfaceDark = Color(0xFF171A21);
  static const Color surfaceSubtleDark = Color(0xFF1C2029);
  static const Color textDark = Color(0xFFE5E7EB);
  static const Color textMutedDark = Color(0xFF8B93A1);
  static const Color borderDark = Color(0xFF262B35);
  static const Color brandDark = Color(0xFF4ADE80);
  static const Color dangerDark = Color(0xFFF87171);
  static const Color warningDark = Color(0xFFFBBF24);
  static const Color infoDark = Color(0xFF38BDF8);

  /// 语义色 12% 透明度状态底色
  static Color statusBg(Color semantic) => semantic.withValues(alpha: 0.12);
}

/// 间距刻度（4 的倍数）
class AppSpacing {
  AppSpacing._();
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double xxxl = 32;

  /// 页面左右内边距
  static const double page = 16;

  /// 卡片内边距
  static const double card = 16;
}

/// 圆角层级
class AppRadius {
  AppRadius._();
  static const double card = 14;
  static const double inner = 12;
  static const double control = 8;
  static const double pill = 999;

  static final BorderRadius cardAll = BorderRadius.circular(card);
  static final BorderRadius innerAll = BorderRadius.circular(inner);
  static final BorderRadius controlAll = BorderRadius.circular(control);
}

/// 文字层级
class AppText {
  AppText._();

  static const TextStyle pageTitle = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w700,
    height: 28 / 20,
  );

  static const TextStyle keyNumber = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w700,
    height: 28 / 22,
  );

  static const TextStyle sectionTitle = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    height: 24 / 16,
  );

  static const TextStyle body = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 24 / 16,
  );

  static const TextStyle bodyDense = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 22 / 14,
  );

  static const TextStyle caption = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    height: 20 / 13,
  );
}

/// 通过 BuildContext 解析当前亮度下的语义色。
///
/// 用法：`context.colors.text`、`context.colors.brand`。
extension AppColorSchemeX on BuildContext {
  AppSemanticColors get colors => Theme.of(this).extension<AppSemanticColors>()!;
}

/// 随主题亮度切换的语义色集合（ThemeExtension）。
class AppSemanticColors extends ThemeExtension<AppSemanticColors> {
  final Color bg;
  final Color surface;
  final Color surfaceSubtle;
  final Color text;
  final Color textMuted;
  final Color border;
  final Color brand;

  /// 小字号绿色文字（满足对比度）
  final Color brandText;

  /// 实心主按钮底色
  final Color primaryButtonBg;
  final Color danger;
  final Color warning;
  final Color info;

  const AppSemanticColors({
    required this.bg,
    required this.surface,
    required this.surfaceSubtle,
    required this.text,
    required this.textMuted,
    required this.border,
    required this.brand,
    required this.brandText,
    required this.primaryButtonBg,
    required this.danger,
    required this.warning,
    required this.info,
  });

  static const AppSemanticColors light = AppSemanticColors(
    bg: AppColors.bg,
    surface: AppColors.surface,
    surfaceSubtle: AppColors.surfaceSubtle,
    text: AppColors.text,
    textMuted: AppColors.textMuted,
    border: AppColors.border,
    brand: AppColors.brand,
    brandText: AppColors.brandText,
    primaryButtonBg: AppColors.primaryButtonBg,
    danger: AppColors.danger,
    warning: AppColors.warning,
    info: AppColors.info,
  );

  static const AppSemanticColors dark = AppSemanticColors(
    bg: AppColors.bgDark,
    surface: AppColors.surfaceDark,
    surfaceSubtle: AppColors.surfaceSubtleDark,
    text: AppColors.textDark,
    textMuted: AppColors.textMutedDark,
    border: AppColors.borderDark,
    brand: AppColors.brandDark,
    brandText: AppColors.brandDark,
    primaryButtonBg: AppColors.brandDark,
    danger: AppColors.dangerDark,
    warning: AppColors.warningDark,
    info: AppColors.infoDark,
  );

  Color statusBg(Color semantic) => semantic.withValues(alpha: 0.12);

  @override
  AppSemanticColors copyWith({
    Color? bg,
    Color? surface,
    Color? surfaceSubtle,
    Color? text,
    Color? textMuted,
    Color? border,
    Color? brand,
    Color? brandText,
    Color? primaryButtonBg,
    Color? danger,
    Color? warning,
    Color? info,
  }) {
    return AppSemanticColors(
      bg: bg ?? this.bg,
      surface: surface ?? this.surface,
      surfaceSubtle: surfaceSubtle ?? this.surfaceSubtle,
      text: text ?? this.text,
      textMuted: textMuted ?? this.textMuted,
      border: border ?? this.border,
      brand: brand ?? this.brand,
      brandText: brandText ?? this.brandText,
      primaryButtonBg: primaryButtonBg ?? this.primaryButtonBg,
      danger: danger ?? this.danger,
      warning: warning ?? this.warning,
      info: info ?? this.info,
    );
  }

  @override
  AppSemanticColors lerp(ThemeExtension<AppSemanticColors>? other, double t) {
    if (other is! AppSemanticColors) return this;
    return AppSemanticColors(
      bg: Color.lerp(bg, other.bg, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceSubtle: Color.lerp(surfaceSubtle, other.surfaceSubtle, t)!,
      text: Color.lerp(text, other.text, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      border: Color.lerp(border, other.border, t)!,
      brand: Color.lerp(brand, other.brand, t)!,
      brandText: Color.lerp(brandText, other.brandText, t)!,
      primaryButtonBg: Color.lerp(primaryButtonBg, other.primaryButtonBg, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      info: Color.lerp(info, other.info, t)!,
    );
  }
}
