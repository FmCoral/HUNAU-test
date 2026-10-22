import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/l10n_extension.dart';
import '../../../core/utils/route_utils.dart';
import '../models/repair_models.dart';
import '../services/repair_service.dart';
import 'repair_detail_screen.dart';
import 'repair_form_screen.dart';

class RepairScreen extends ConsumerStatefulWidget {
  const RepairScreen({super.key});
  @override
  ConsumerState<RepairScreen> createState() => _RepairScreenState();
}

class _RepairScreenState extends ConsumerState<RepairScreen> {
  int _selectedTab = 0; // 0: 处理中, 1: 已完成, 2: 草稿箱
  List<RepairOrder> _ongoing = [], _finished = [], _drafts = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final service = ref.read(repairServiceProvider);
      final result = await Future.wait([
        service.fetchOrders(ongoing: true),
        service.fetchOrders(ongoing: false),
        service.fetchOrders(ongoing: false, isDraft: true),
      ]);
      if (!mounted) return;
      setState(() {
        _ongoing = result[0];
        _finished = result[1];
        _drafts = result[2];
      });
    } catch (e) {
      if (mounted) {
        setState(() => _error = e is RepairException
            ? e.message
            : context.l10n.loadFailedCheckNetwork);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    final currentOrders = _selectedTab == 0
        ? _ongoing
        : (_selectedTab == 1 ? _finished : _drafts);

    final isDraftTab = _selectedTab == 2;

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.repairsTitle),
        actions: [
          IconButton(
            onPressed: _loading ? null : _load,
            tooltip: context.l10n.refresh,
            icon: const Icon(Icons.refresh_rounded),
          )
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.page, AppSpacing.md, AppSpacing.page, 36),
          children: [
            // 1. 四大报修分类 2x2 卡片（无箭头，与图书馆风格一致）
            _buildCatalogGrid(colors),
            const SizedBox(height: AppSpacing.xxl),

            // 2. 我的工单（纯标题）
            Text(
              context.l10n.repairsMyOrders,
              style: AppText.sectionTitle.copyWith(color: colors.text),
            ),
            const SizedBox(height: 10),

            // 3. 处理中 / 已完成 / 草稿箱 筛选标签
            Wrap(
              spacing: AppSpacing.sm,
              children: [
                _buildTabChip(0, context.l10n.repairsInProgress, colors),
                _buildTabChip(1, context.l10n.repairsCompleted, colors),
                _buildTabChip(2, context.l10n.repairsDrafts, colors),
              ],
            ),
            const SizedBox(height: AppSpacing.md),

            if (_error != null) _buildError(colors),

            // 4. 工单列表（加载中不打断展示，不走进度条）
            if (currentOrders.isEmpty)
              if (!_loading) _buildEmptyState(colors)
              else
                const SizedBox.shrink()
            else
              ...currentOrders.map(
                  (order) => _buildOrderItem(order, colors, isDraftTab)),
          ],
        ),
      ),
    );
  }

  Widget _buildCatalogGrid(AppSemanticColors colors) {
    const catalogs = RepairService.catalogs;
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _buildCatalogCard(catalogs[0], colors)),
            const SizedBox(width: 10),
            Expanded(child: _buildCatalogCard(catalogs[1], colors)),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: _buildCatalogCard(catalogs[2], colors)),
            const SizedBox(width: 10),
            Expanded(child: _buildCatalogCard(catalogs[3], colors)),
          ],
        ),
      ],
    );
  }

  Widget _buildCatalogCard(RepairCatalog catalog, AppSemanticColors colors) {
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: AppRadius.cardAll,
        border: Border.all(color: colors.border),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: AppRadius.cardAll,
          onTap: () async {
            await Navigator.push(
              context,
              createSlideUpRoute(RepairFormScreen(catalog: catalog)),
            );
            if (mounted) _load();
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            child: Row(
              children: [
                Icon(
                  catalog.icon,
                  color: colors.brand,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    catalog.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.bodyDense.copyWith(
                      color: colors.text,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTabChip(int index, String label, AppSemanticColors colors) {
    final isSelected = _selectedTab == index;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => setState(() => _selectedTab = index),
        borderRadius: AppRadius.controlAll,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: isSelected
                ? colors.statusBg(colors.brand)
                : Colors.transparent,
            borderRadius: AppRadius.controlAll,
            border: Border.all(
              color: isSelected ? colors.brand : colors.border,
            ),
          ),
          child: Text(
            label,
            style: AppText.caption.copyWith(
              color: isSelected ? colors.brandText : colors.text,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(AppSemanticColors colors) {
    final emptyText = _selectedTab == 0
        ? context.l10n.repairsNoOngoing
        : (_selectedTab == 1
            ? context.l10n.repairsNoCompleted
            : context.l10n.repairsNoDrafts);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Center(
        child: Text(
          emptyText,
          style: AppText.bodyDense.copyWith(color: colors.textMuted),
        ),
      ),
    );
  }

  Widget _buildOrderItem(
      RepairOrder order, AppSemanticColors colors, bool isDraftTab) {
    final catalog = RepairService.resolveCatalog(order);

    String dateStr = '';
    if (order.createdAt != null) {
      final y = order.createdAt!.year;
      final m = order.createdAt!.month.toString().padLeft(2, '0');
      final d = order.createdAt!.day.toString().padLeft(2, '0');
      dateStr = '$y-$m-$d';
    }

    final department = order.department.isNotEmpty
        ? order.department
        : catalog.department;
    final type = order.catalog.isNotEmpty ? order.catalog : catalog.title;
    final statusText =
        isDraftTab && (order.status.isEmpty || order.status == 'NEW')
            ? '草稿'
            : order.status;
    final isDone = order.isDone;
    final isDraft = order.isDraft || isDraftTab;
    final statusColor = isDone
        ? colors.brand
        : (isDraft ? colors.warning : colors.textMuted);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: AppRadius.cardAll,
        border: Border.all(color: colors.border),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: AppRadius.cardAll,
          onTap: () {
            if (isDraftTab) {
              Navigator.push(
                context,
                createSlideUpRoute(
                    RepairFormScreen(catalog: catalog, draftOrder: order)),
              ).then((_) => _load());
            } else {
              Navigator.push(
                context,
                createSlideUpRoute(RepairDetailScreen(order: order)),
              ).then((_) => _load());
            }
          },
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.card),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        order.title.isEmpty
                            ? context.l10n.repairsUnnamedOrder
                            : order.title,
                        style: AppText.sectionTitle.copyWith(
                          color: colors.text,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 13,
                      color: colors.textMuted,
                    ),
                  ],
                ),
                if (department.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    department,
                    style: AppText.caption.copyWith(color: colors.textMuted),
                  ),
                ],
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.md,
                  runSpacing: 4,
                  children: [
                    if (type.isNotEmpty)
                      Text(
                        type,
                        style:
                            AppText.caption.copyWith(color: colors.textMuted),
                      ),
                    if (dateStr.isNotEmpty)
                      Text(
                        dateStr,
                        style:
                            AppText.caption.copyWith(color: colors.textMuted),
                      ),
                    if (statusText.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: colors.statusBg(statusColor),
                          borderRadius:
                              BorderRadius.circular(AppRadius.pill),
                        ),
                        child: Text(
                          statusText,
                          style: AppText.caption.copyWith(
                            fontSize: 12,
                            color: statusColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildError(AppSemanticColors colors) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(_error!, style: TextStyle(color: colors.danger)));
}
