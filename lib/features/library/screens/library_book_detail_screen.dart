import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/l10n_extension.dart';
import '../models/library_book_models.dart';
import '../providers/library_provider.dart';

class LibraryBookDetailScreen extends ConsumerStatefulWidget {
  final LibraryBook book;

  const LibraryBookDetailScreen({
    super.key,
    required this.book,
  });

  @override
  ConsumerState<LibraryBookDetailScreen> createState() =>
      _LibraryBookDetailScreenState();
}

class _LibraryBookDetailScreenState
    extends ConsumerState<LibraryBookDetailScreen> {
  late Future<LibraryBookDetail> _detailFuture;

  @override
  void initState() {
    super.initState();
    _detailFuture = _fetch();
  }

  Future<LibraryBookDetail> _fetch() {
    return ref.read(libraryBookServiceProvider).fetchBookDetail(widget.book);
  }

  void _retry() {
    setState(() {
      _detailFuture = _fetch();
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.bookDetailTitle),
      ),
      body: FutureBuilder<LibraryBookDetail>(
        future: _detailFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xxl),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.error_outline_rounded,
                        size: 48, color: colors.danger),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      snapshot.error
                          .toString()
                          .replaceAll('Exception:', '')
                          .trim(),
                      textAlign: TextAlign.center,
                      style: AppText.bodyDense.copyWith(color: colors.text),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    ElevatedButton(
                      onPressed: _retry,
                      child: Text(context.l10n.retry),
                    ),
                  ],
                ),
              ),
            );
          }

          final detail = snapshot.data!;
          return _buildDetailContent(detail, colors);
        },
      ),
    );
  }

  Widget _buildDetailContent(
      LibraryBookDetail detail, AppSemanticColors colors) {
    return ListView(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.page, vertical: AppSpacing.md),
      children: [
        // 1. 图书主要信息（不包在框内）
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 4, 4, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                detail.title,
                style: AppText.pageTitle.copyWith(color: colors.text),
              ),
              const SizedBox(height: 14),
              for (final item in detail.effectiveCatalogItems)
                _buildInfoRow(
                  _iconForLabel(item.key),
                  item.key,
                  item.value,
                  colors,
                ),
            ],
          ),
        ),

        const SizedBox(height: AppSpacing.md),

        // 2. 馆藏副本标题（不显示“在馆”）
        Text(
          context.l10n.holdingsTitle,
          style: AppText.sectionTitle.copyWith(color: colors.text),
        ),

        const SizedBox(height: AppSpacing.md),

        // 3. 馆藏副本列表
        if (detail.holdings.isEmpty)
          Container(
            padding: const EdgeInsets.all(AppSpacing.xl),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: AppRadius.cardAll,
              border: Border.all(color: colors.border),
            ),
            child: Text(
              '暂无馆藏详细副本信息',
              style: AppText.bodyDense.copyWith(color: colors.textMuted),
            ),
          )
        else
          ...detail.holdings.map((h) => _buildHoldingItem(h, colors)),

        const SizedBox(height: AppSpacing.xxxl),
      ],
    );
  }

  Widget _buildInfoRow(
    IconData icon,
    String label,
    String value,
    AppSemanticColors colors,
  ) {
    final cleanValue = value.replaceFirst(RegExp(r'^[:：\s]+'), '').trim();
    final cleanLabel = label.replaceAll(RegExp(r'[:：\s]+$'), '').trim();
    final isCallNumber = cleanLabel.contains('索书号');

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(top: isCallNumber ? 2 : 0),
            child: Icon(
              icon,
              size: 16,
              color: colors.textMuted,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          if (cleanLabel.isNotEmpty)
            Padding(
              padding: EdgeInsets.only(top: isCallNumber ? 1 : 0),
              child: Text(
                '$cleanLabel：',
                style: AppText.caption.copyWith(color: colors.textMuted),
              ),
            ),
          Expanded(
            child: isCallNumber
                ? Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: colors.statusBg(colors.brand),
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                      child: Text(
                        cleanValue,
                        style: AppText.caption.copyWith(
                          color: colors.brandText,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  )
                : Text(
                    cleanValue,
                    style: AppText.bodyDense.copyWith(color: colors.text),
                  ),
          ),
        ],
      ),
    );
  }

  IconData _iconForLabel(String label) {
    if (label.contains('题名') || label.contains('责任者') || label.contains('作者')) {
      return Icons.person_outline_rounded;
    }
    if (label.contains('ISBN') || label.contains('定价')) {
      return Icons.tag_rounded;
    }
    if (label.contains('出版')) {
      return Icons.business_outlined;
    }
    if (label.contains('索书号') || label.contains('主题')) {
      return Icons.bookmark_outline_rounded;
    }
    if (label.contains('形态')) {
      return Icons.menu_book_rounded;
    }
    if (label.contains('丛编') || label.contains('丛书')) {
      return Icons.collections_bookmark_outlined;
    }
    if (label.contains('文摘') ||
        label.contains('题要') ||
        label.contains('简介') ||
        label.contains('摘要')) {
      return Icons.description_outlined;
    }
    return Icons.info_outline_rounded;
  }

  Widget _buildHoldingItem(
      LibraryBookHolding holding, AppSemanticColors colors) {
    final isAvailable = holding.isAvailable;
    final statusColor = isAvailable ? colors.brand : colors.warning;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(AppSpacing.card),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: AppRadius.cardAll,
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  holding.holdingUnit.isNotEmpty
                      ? holding.holdingUnit
                      : '湖南农业大学图书馆',
                  style: AppText.sectionTitle
                      .copyWith(color: colors.text, fontSize: 14),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: colors.statusBg(statusColor),
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: Text(
                  holding.status.isNotEmpty ? holding.status : '在库',
                  style: AppText.caption.copyWith(
                    color: statusColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          if (holding.location.isNotEmpty)
            Row(
              children: [
                Icon(
                  Icons.place_outlined,
                  size: 15,
                  color: colors.textMuted,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    '${context.l10n.holdingLocation}: ${holding.location}',
                    style: AppText.bodyDense.copyWith(color: colors.text),
                  ),
                ),
              ],
            ),
          const SizedBox(height: 6),
          Wrap(
            spacing: AppSpacing.md,
            runSpacing: 4,
            children: [
              if (holding.barcode.isNotEmpty)
                Text(
                  '${context.l10n.barcode}: ${holding.barcode}',
                  style: AppText.caption.copyWith(color: colors.textMuted),
                ),
              if (holding.accessionNo.isNotEmpty)
                Text(
                  '${context.l10n.accessionNo}: ${holding.accessionNo}',
                  style: AppText.caption.copyWith(color: colors.textMuted),
                ),
              if (holding.copyType.isNotEmpty)
                Text(
                  '${context.l10n.copyType}: ${holding.copyType}',
                  style: AppText.caption.copyWith(color: colors.textMuted),
                ),
              if (holding.notes.isNotEmpty)
                Text(
                  '备注: ${holding.notes}',
                  style: AppText.caption.copyWith(color: colors.danger),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
