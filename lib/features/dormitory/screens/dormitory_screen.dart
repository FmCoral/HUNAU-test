import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/utils/l10n_extension.dart';
import '../models/dormitory_info.dart';
import '../services/dormitory_service.dart';

/// 我的宿舍页面
class DormitoryScreen extends ConsumerStatefulWidget {
  const DormitoryScreen({super.key});

  @override
  ConsumerState<DormitoryScreen> createState() => _DormitoryScreenState();
}

class _DormitoryScreenState extends ConsumerState<DormitoryScreen> {
  DormitoryInfo? _info;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData({bool forceRefresh = false}) async {
    final service = ref.read(dormitoryServiceProvider);

    // 先读缓存秒开首帧
    if (!forceRefresh) {
      final cached = await service.getCachedDormitoryInfo();
      if (cached != null && mounted) {
        setState(() {
          _info = cached;
          _loading = false;
        });
      }
    }

    if (_info == null) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final fresh = await service.fetchDormitoryInfo(forceRefresh: forceRefresh);
      if (mounted) {
        setState(() {
          _info = fresh;
          _loading = false;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          final errText = e
              .toString()
              .replaceFirst('AppException: ', '')
              .replaceFirst('Exception: ', '');
          if (_info == null) {
            _error = errText;
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(errText),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.funcDormitory),
        actions: [
          IconButton(
            tooltip: context.l10n.refresh,
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => _loadData(forceRefresh: true),
          ),
        ],
      ),
      body: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    final colors = context.colors;

    if (_loading && _info == null) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_error != null && _info == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline_rounded,
                size: 48,
                color: colors.warning,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: AppText.bodyDense.copyWith(color: colors.text),
              ),
              const SizedBox(height: AppSpacing.lg),
              ElevatedButton.icon(
                onPressed: () => _loadData(forceRefresh: true),
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: Text(context.l10n.retry),
              ),
            ],
          ),
        ),
      );
    }

    final info = _info ?? const DormitoryInfo(isAssigned: false);

    return RefreshIndicator(
      onRefresh: () => _loadData(forceRefresh: true),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.page, AppSpacing.md, AppSpacing.page, AppSpacing.xxxl),
        children: [
          _buildDormCard(context, info, colors),
        ],
      ),
    );
  }

  Widget _buildDormCard(
      BuildContext context, DormitoryInfo info, AppSemanticColors colors) {
    final building = info.building ??
        (!info.isAssigned ? context.l10n.dormitoryNotAssigned : '--');
    final floor = info.floor ?? '--';
    final room = info.room ?? '--';
    final bed = info.bed ?? '--';

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: AppRadius.cardAll,
        border: Border.all(color: colors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          _buildItemRow(
            label: context.l10n.dormitoryBuilding,
            value: building,
            colors: colors,
          ),
          Divider(height: 1, indent: AppSpacing.card, color: colors.border),
          _buildItemRow(
            label: context.l10n.dormitoryFloor,
            value: floor,
            colors: colors,
          ),
          Divider(height: 1, indent: AppSpacing.card, color: colors.border),
          _buildItemRow(
            label: context.l10n.dormitoryRoom,
            value: room,
            colors: colors,
          ),
          Divider(height: 1, indent: AppSpacing.card, color: colors.border),
          _buildItemRow(
            label: context.l10n.dormitoryBed,
            value: bed,
            colors: colors,
          ),
        ],
      ),
    );
  }

  Widget _buildItemRow({
    required String label,
    required String value,
    required AppSemanticColors colors,
  }) {
    return InkWell(
      onLongPress: value != '--'
          ? () {
              Clipboard.setData(ClipboardData(text: value));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('$label 已复制: $value'),
                  behavior: SnackBarBehavior.floating,
                  duration: const Duration(seconds: 1),
                ),
              );
            }
          : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.card, vertical: 16),
        child: Row(
          children: [
            Text(
              label,
              style: AppText.bodyDense.copyWith(color: colors.textMuted),
            ),
            const Spacer(),
            Text(
              value,
              style: AppText.bodyDense.copyWith(
                fontWeight: FontWeight.w500,
                color: colors.text,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
