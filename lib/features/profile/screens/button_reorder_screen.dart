import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/home_widget_service.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/brand_switch.dart';
import '../providers/appearance_provider.dart';
import '../models/appearance_state.dart';
import '../../../core/utils/l10n_extension.dart';

class ButtonReorderScreen extends ConsumerWidget {
  final String title;
  final String listType;

  const ButtonReorderScreen({
    super.key,
    required this.title,
    required this.listType,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appearance = ref.watch(appearanceProvider);

    // 功能排序按支付/学习/生活/出行/工具/小程序分组展示
    if (listType == 'functions') {
      return _buildGroupedFunctions(context, ref, appearance);
    }

    // 获取当前列表并按可见性排序
    final rawItems = listType == 'home'
        ? appearance.homeItems
        : (listType == 'feed'
            ? appearance.feedItems
            : (listType == 'widget'
                ? appearance.widgetItems
                : appearance.functionItems));
    final visibleItems = rawItems.where((e) => e.isVisible).toList();
    final hiddenItems = rawItems.where((e) => !e.isVisible).toList();

    final isAutoSort = listType == 'feed' && appearance.feedAutoSort;

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: listType == 'widget'
            ? [
                IconButton(
                  icon: const Icon(Icons.refresh_rounded),
                  tooltip: context.l10n.widgetRefresh,
                  onPressed: () async {
                    await HomeWidgetService().syncWidgets();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(context.l10n.widgetRefreshed)),
                      );
                    }
                  },
                ),
              ]
            : null,
      ),
      body: Column(
        children: [
          if (listType == 'feed')
            _buildAutoSortTile(context, ref, appearance),
          Expanded(
            child: _buildSortSection(
              context,
              ref,
              listType: listType,
              isAutoSort: isAutoSort,
              visibleItems: visibleItems,
              hiddenItems: hiddenItems,
            ),
          ),
        ],
      ),
    );
  }

  static const ColorFilter _grayscaleFilter = ColorFilter.matrix(<double>[
    0.2126, 0.7152, 0.0722, 0, 0,
    0.2126, 0.7152, 0.0722, 0, 0,
    0.2126, 0.7152, 0.0722, 0, 0,
    0,      0,      0,      1, 0,
  ]);

  Widget _buildSortSection(
    BuildContext context,
    WidgetRef ref, {
    required String listType,
    required bool isAutoSort,
    required List<FunctionItem> visibleItems,
    required List<FunctionItem> hiddenItems,
  }) {
    final colors = context.colors;
    Widget content = Column(
      children: [
        _buildInfoBanner(context),
        Expanded(
          child: ReorderableListView(
            padding: const EdgeInsets.only(top: 0, bottom: 60), // 增加底部边距，方便拖拽到最后
            buildDefaultDragHandles: !isAutoSort,
            header: _buildSectionHeader(
              context,
              context.l10n.visibleFunctions,
              Icons.visibility_outlined,
              isFixed: true,
            ),
            proxyDecorator: (Widget child, int index, Animation<double> animation) {
              return AnimatedBuilder(
                animation: animation,
                builder: (BuildContext context, Widget? child) {
                  final double animValue = Curves.easeInOut.transform(animation.value);
                  final double elevation = lerpDouble(0, 2, animValue)!;
                  return Material(
                    elevation: elevation,
                    color: colors.surface,
                    borderRadius:
                        BorderRadius.circular(animValue * AppRadius.control),
                    child: child,
                  );
                },
                child: child,
              );
            },
            onReorder: (oldIndex, newIndex) {
              if (isAutoSort) return;
              // 将 UI 层的索引直接传递给 Notifier，由 Notifier 处理 HeaderHidden 的偏移逻辑
              ref.read(appearanceProvider.notifier).reorderItems(listType, oldIndex, newIndex);
            },
            children: [
              // 1. 显示中的项
              ...visibleItems.map((item) => _buildReorderItem(context, ref, item)),

              // 2. 已隐藏的功能区域标题 (分界线)
              _buildSectionHeader(
                context,
                context.l10n.hiddenFunctions,
                Icons.visibility_off_outlined,
                key: const ValueKey('header_hidden'),
              ),

              // 3. 隐藏中的项
              ...hiddenItems.map((item) => _buildReorderItem(context, ref, item)),
            ],
          ),
        ),
      ],
    );

    if (isAutoSort) {
      content = ColorFiltered(
        colorFilter: _grayscaleFilter,
        child: content,
      );
    }

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: isAutoSort ? 0.38 : 1.0,
      child: content,
    );
  }

  /// 功能排序：6 个大模块，拖过隐藏线切换显隐（与首页排序同手势）
  Widget _buildGroupedFunctions(BuildContext context, WidgetRef ref,
      AppearanceState appearance) {
    final colors = context.colors;
    final hiddenSet = appearance.hiddenFunctionGroups.toSet();
    final visibleKeys = appearance.functionGroupOrder
        .where((k) => !hiddenSet.contains(k))
        .toList();
    final hiddenKeys = appearance.functionGroupOrder
        .where((k) => hiddenSet.contains(k))
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
      ),
      body: Column(
        children: [
          _buildInfoBanner(context),
          Expanded(
            child: ReorderableListView(
              padding: const EdgeInsets.only(bottom: 60),
              proxyDecorator:
                  (Widget child, int index, Animation<double> animation) {
                return AnimatedBuilder(
                  animation: animation,
                  builder: (BuildContext context, Widget? child) {
                    final double animValue =
                        Curves.easeInOut.transform(animation.value);
                    final double elevation = lerpDouble(0, 2, animValue)!;
                    return Material(
                      elevation: elevation,
                      color: colors.surface,
                      borderRadius:
                          BorderRadius.circular(animValue * AppRadius.control),
                      child: child,
                    );
                  },
                  child: child,
                );
              },
              onReorder: (oldIndex, newIndex) {
                ref
                    .read(appearanceProvider.notifier)
                    .reorderFunctionGroups(oldIndex, newIndex);
              },
              children: [
                ...visibleKeys.map((key) => _buildGroupTile(
                      context,
                      key,
                    )),
                _buildSectionHeader(
                  context,
                  context.l10n.hiddenFunctions,
                  Icons.visibility_off_outlined,
                  key: const ValueKey('header_hidden'),
                ),
                ...hiddenKeys.map((key) => _buildGroupTile(
                      context,
                      key,
                    )),
              ],
            ),
          ),
        ],
      ),
    );
  }

  ({IconData icon, Color color}) _groupVisual(String titleKey) {
    return switch (titleKey) {
      'groupPayment' =>
        (icon: Icons.payments_outlined, color: Colors.orange),
      'groupStudy' =>
        (icon: Icons.school_outlined, color: const Color(0xFF795548)),
      'groupLife' =>
        (icon: Icons.favorite_outline, color: const Color(0xFFE63476)),
      'groupTravel' =>
        (icon: Icons.directions_bus_outlined, color: const Color(0xFF2196F3)),
      'groupTools' =>
        (icon: Icons.build_outlined, color: const Color(0xFF607D8B)),
      _ => (icon: Icons.apps_outlined, color: const Color(0xFF16A34A)),
    };
  }

  Widget _buildGroupTile(
    BuildContext context,
    String titleKey,
  ) {
    final colors = context.colors;
    final visual = _groupVisual(titleKey);
    return Container(
      key: ValueKey(titleKey),
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xxl, vertical: AppSpacing.md),
      color: Colors.transparent,
      child: Row(
        children: [
          Icon(Icons.drag_indicator_rounded,
              color: colors.textMuted, size: 24),
          const SizedBox(width: AppSpacing.xl),
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: visual.color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(visual.icon, color: visual.color, size: 22),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Text(
              functionGroupTitle(context, titleKey),
              style: AppText.body.copyWith(color: colors.text),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoBanner(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xxl, vertical: AppSpacing.md),
      width: double.infinity,
      color: colors.surfaceSubtle,
      child: Row(
        children: [
          Icon(Icons.touch_app_outlined, size: 16, color: colors.textMuted),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              context.l10n.dragToReorderTip,
              style: AppText.caption.copyWith(color: colors.textMuted),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title, IconData icon, {Key? key, bool isFixed = false}) {
    final colors = context.colors;
    return Container(
      key: key,
      padding: EdgeInsets.fromLTRB(AppSpacing.xxl,
          isFixed ? AppSpacing.lg : AppSpacing.xxl, AppSpacing.xxl, AppSpacing.sm),
      child: Row(
        children: [
          Icon(icon, size: 16, color: colors.textMuted),
          const SizedBox(width: AppSpacing.sm),
          Text(
            title,
            style: AppText.caption.copyWith(
              fontWeight: FontWeight.w600,
              color: colors.textMuted,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReorderItem(
    BuildContext context,
    WidgetRef ref,
    FunctionItem item,
  ) {
    final colors = context.colors;

    return Container(
      key: ValueKey(item.id),
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xxl, vertical: AppSpacing.md),
      color: Colors.transparent,
      child: Row(
        children: [
          Icon(Icons.drag_indicator_rounded,
              color: colors.textMuted, size: 24),
          const SizedBox(width: AppSpacing.xl),
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: item.color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(item.icon, color: item.color, size: 22),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Text(
              item.getLocalizedTitle(context),
              style: AppText.body.copyWith(color: colors.text),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAutoSortTile(
      BuildContext context, WidgetRef ref, AppearanceState appearance) {
    final colors = context.colors;
    return InkWell(
      onTap: () {
        ref
            .read(appearanceProvider.notifier)
            .updateFeedAutoSort(!appearance.feedAutoSort);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xxl, vertical: AppSpacing.sm),
        child: Row(
          children: [
            Expanded(
              child: Text(
                context.l10n.feedAutoSort,
                style: AppText.body.copyWith(color: colors.text),
              ),
            ),
            BrandSwitch(
              value: appearance.feedAutoSort,
              onChanged: (val) {
                ref.read(appearanceProvider.notifier).updateFeedAutoSort(val);
              },
            ),
          ],
        ),
      ),
    );
  }
}
