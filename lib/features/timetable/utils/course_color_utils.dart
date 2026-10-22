import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../cloudisk/services/cloud_backup_manager.dart';

/// 描述 Material UI 调色板中的单个颜色项
class MaterialColorItem {
  final String family;
  final String shade;
  final Color color;

  const MaterialColorItem({
    required this.family,
    required this.shade,
    required this.color,
  });
}

/// 课程配色工具类
///
/// 色板为 19 种低饱和度柔和色调（与浅灰页面底协调，深/浅模式均可读），
/// 覆盖 Red, Pink, Purple, Deep Purple, Indigo, Blue, Light Blue, Cyan, Teal,
/// Green, Light Green, Lime, Yellow, Amber, Orange, Deep Orange, Brown, Grey,
/// Blue Grey 共 19 个色相。
///
/// 课程块实际渲染为「淡色底（课程色低透明度）+ 深色文字」，
/// 取色仍按课程名哈希唯一分配，并保证同课表内互不重复（唯一分配 + 换色对调机制）。
class CourseColorUtils {
  static const String _prefsKey = 'custom_course_colors';
  static final Map<String, Color> _assignedColors = {};
  static bool _initialized = false;
  static Future<void>? _initFuture;

  /// 19 种低饱和度课程色（作为强调色：淡色底 + 深色文字）
  static const List<MaterialColorItem> materialColorItems = [
    MaterialColorItem(family: 'Red', shade: 'muted', color: Color(0xFFB4524E)),
    MaterialColorItem(family: 'Pink', shade: 'muted', color: Color(0xFFBA5A78)),
    MaterialColorItem(family: 'Purple', shade: 'muted', color: Color(0xFF9A6AB0)),
    MaterialColorItem(family: 'Deep Purple', shade: 'muted', color: Color(0xFF7E6BB8)),
    MaterialColorItem(family: 'Indigo', shade: 'muted', color: Color(0xFF5C6BC0)),
    MaterialColorItem(family: 'Blue', shade: 'muted', color: Color(0xFF4A7FB5)),
    MaterialColorItem(family: 'Light Blue', shade: 'muted', color: Color(0xFF4A90A4)),
    MaterialColorItem(family: 'Cyan', shade: 'muted', color: Color(0xFF4A9B9B)),
    MaterialColorItem(family: 'Teal', shade: 'muted', color: Color(0xFF4A9084)),
    MaterialColorItem(family: 'Green', shade: 'muted', color: Color(0xFF5E9A5E)),
    MaterialColorItem(family: 'Light Green', shade: 'muted', color: Color(0xFF82A85C)),
    MaterialColorItem(family: 'Lime', shade: 'muted', color: Color(0xFFA3A24E)),
    MaterialColorItem(family: 'Yellow', shade: 'muted', color: Color(0xFFC0A44A)),
    MaterialColorItem(family: 'Amber', shade: 'muted', color: Color(0xFFCB9A4A)),
    MaterialColorItem(family: 'Orange', shade: 'muted', color: Color(0xFFC98A50)),
    MaterialColorItem(family: 'Deep Orange', shade: 'muted', color: Color(0xFFC06A4A)),
    MaterialColorItem(family: 'Brown', shade: 'muted', color: Color(0xFF8D6E63)),
    MaterialColorItem(family: 'Grey', shade: 'muted', color: Color(0xFF8A8A8A)),
    MaterialColorItem(family: 'Blue Grey', shade: 'muted', color: Color(0xFF7A8A99)),
  ];

  /// 供选取的全部颜色列表（严格限定为 19 个低饱和度色）
  static List<Color> get selectablePalette =>
      materialColorItems.map((item) => item.color).toList();

  /// 默认推荐分配顺序：冷暖与明暗交替轮换，确保相邻课程视觉反差鲜明
  static const List<Color> defaultPaletteOrder = [
    Color(0xFF5C6BC0), // Indigo
    Color(0xFFC06A4A), // Deep Orange
    Color(0xFF4A9084), // Teal
    Color(0xFFBA5A78), // Pink
    Color(0xFF4A7FB5), // Blue
    Color(0xFFCB9A4A), // Amber
    Color(0xFF9A6AB0), // Purple
    Color(0xFF5E9A5E), // Green
    Color(0xFFB4524E), // Red
    Color(0xFF4A9B9B), // Cyan
    Color(0xFFC98A50), // Orange
    Color(0xFF7E6BB8), // Deep Purple
    Color(0xFF82A85C), // Light Green
    Color(0xFF4A90A4), // Light Blue
    Color(0xFF8D6E63), // Brown
    Color(0xFFA3A24E), // Lime
    Color(0xFF7A8A99), // Blue Grey
    Color(0xFFC0A44A), // Yellow
    Color(0xFF8A8A8A), // Grey
  ];

  /// 课程块淡色底（课程色 12-18% 透明度，深色模式稍提高以保证可辨识）
  static Color blockBackground(Color accent, Brightness brightness) =>
      accent.withValues(alpha: brightness == Brightness.dark ? 0.22 : 0.14);

  /// 课程块深色文字（浅色模式压暗，深色模式提亮，保证对比度）
  static Color blockForeground(Color accent, Brightness brightness) {
    final hsl = HSLColor.fromColor(accent);
    if (brightness == Brightness.dark) {
      return hsl
          .withLightness((hsl.lightness + 0.3).clamp(0.62, 0.78))
          .toColor();
    }
    return hsl
        .withLightness((hsl.lightness * 0.55).clamp(0.2, 0.36))
        .toColor();
  }

  /// 初始化从 SharedPreferences 读取已保存的课程颜色配置
  static Future<void> init() async {
    if (_initialized) return;
    if (_initFuture != null) return _initFuture;
    _initFuture = _doInit();
    await _initFuture;
  }

  static Future<void> _doInit() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_prefsKey);
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final Map<String, dynamic> decoded = jsonDecode(jsonStr);
        final validARGBs = selectablePalette.map((c) => c.toARGB32()).toSet();
        for (final entry in decoded.entries) {
          if (entry.value is int) {
            final val = entry.value as int;
            // 仅载入属于 19 种候选色的配置，历史旧版配置将在 syncCourses 时统一重分配
            if (validARGBs.contains(val)) {
              _assignedColors[entry.key] = Color(val);
            }
          }
        }
      }
    } catch (_) {
      // 容错读取
    } finally {
      _initialized = true;
    }
  }

  static Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = <String, int>{};
      for (final entry in _assignedColors.entries) {
        data[entry.key] = entry.value.toARGB32();
      }
      await prefs.setString(_prefsKey, jsonEncode(data));
    } catch (_) {}
  }

  /// 同步规范化全量课程列表，保证当前所有课程颜色各自唯一，不产生重复冲突
  static void syncCourses(Iterable<String> courseNames) {
    final validNames = courseNames
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toSet()
        .toList();
    if (validNames.isEmpty) return;

    final validARGBs = selectablePalette.map((c) => c.toARGB32()).toSet();
    final usedColors = <int>{};
    final coursesNeedingAssignment = <String>[];

    // 1. 保留已有且属于候选色板且互不重复的颜色
    for (final name in validNames) {
      final existingColor = _assignedColors[name];
      if (existingColor != null &&
          validARGBs.contains(existingColor.toARGB32()) &&
          !usedColors.contains(existingColor.toARGB32())) {
        usedColors.add(existingColor.toARGB32());
      } else {
        coursesNeedingAssignment.add(name);
      }
    }

    // 2. 为未分配或冲突的课程逐个分配未使用的颜色
    int searchIndex = 0;
    for (final name in coursesNeedingAssignment) {
      while (searchIndex < defaultPaletteOrder.length &&
          usedColors.contains(defaultPaletteOrder[searchIndex].toARGB32())) {
        searchIndex++;
      }

      Color picked;
      if (searchIndex < defaultPaletteOrder.length) {
        picked = defaultPaletteOrder[searchIndex];
        searchIndex++;
      } else {
        // 极端兜底（课程数超过 19 门）
        final hash = name.hashCode.abs();
        picked = defaultPaletteOrder[hash % defaultPaletteOrder.length];
      }

      _assignedColors[name] = picked;
      usedColors.add(picked.toARGB32());
    }

    _persist();
  }

  /// 获取课程对应颜色（若未分配则分配并保证与其他课程互不冲突）
  static Color getColorForCourse(String courseName) {
    final trimmed = courseName.trim();
    if (trimmed.isEmpty) return defaultPaletteOrder[0];

    final existing = _assignedColors[trimmed];
    if (existing != null &&
        selectablePalette.any((c) => c.toARGB32() == existing.toARGB32())) {
      return existing;
    }

    // 查找当前未被占用的颜色
    final usedColors = _assignedColors.values.map((c) => c.toARGB32()).toSet();
    for (final color in defaultPaletteOrder) {
      if (!usedColors.contains(color.toARGB32())) {
        _assignedColors[trimmed] = color;
        _persist();
        return color;
      }
    }

    final fallback =
        defaultPaletteOrder[trimmed.hashCode.abs() % defaultPaletteOrder.length];
    _assignedColors[trimmed] = fallback;
    _persist();
    return fallback;
  }

  /// 为指定课程手动设置新颜色（严格限定在 19 种低饱和度候选色板）
  ///
  /// 如果新颜色已被其他课程占用，两者自动对调（swap），始终保证无课程颜色重复。
  static Future<void> setCourseColor(String courseName, Color newColor) async {
    final trimmed = courseName.trim();
    if (trimmed.isEmpty) return;

    final targetARGB = newColor.toARGB32();

    // 校验新颜色是否属于候选色板
    final isValidColor = selectablePalette.any((c) => c.toARGB32() == targetARGB);
    if (!isValidColor) {
      throw ArgumentError('所选颜色不在候选色板中');
    }

    // 检测是否有其他课程占用了目标颜色
    String? conflictCourse;
    for (final entry in _assignedColors.entries) {
      if (entry.key != trimmed && entry.value.toARGB32() == targetARGB) {
        conflictCourse = entry.key;
        break;
      }
    }

    final oldColor = _assignedColors[trimmed] ?? getColorForCourse(trimmed);

    _assignedColors[trimmed] = newColor;

    if (conflictCourse != null) {
      // 对调：让冲突课程接管当前课程的原颜色
      _assignedColors[conflictCourse] = oldColor;
    }

    await _persist();
    CloudBackupManager.instance.markDirty();
  }

  /// 重新从 SharedPreferences 加载颜色配置（备份恢复或外部变更后调用）
  static Future<void> reload() async {
    _assignedColors.clear();
    _initialized = false;
    _initFuture = null;
    await init();
  }

  /// 查找当前正在使用指定颜色的课程名称（若有）
  static String? getCourseUsingColor(Color color, {String? excludeCourse}) {
    final targetARGB = color.toARGB32();
    final excludeTrimmed = excludeCourse?.trim();
    for (final entry in _assignedColors.entries) {
      if (excludeTrimmed != null && entry.key == excludeTrimmed) continue;
      if (entry.value.toARGB32() == targetARGB) {
        return entry.key;
      }
    }
    return null;
  }

  /// 仅供测试时清理状态
  @visibleForTesting
  static void resetForTesting() {
    _assignedColors.clear();
    _initialized = false;
    _initFuture = null;
  }
}
