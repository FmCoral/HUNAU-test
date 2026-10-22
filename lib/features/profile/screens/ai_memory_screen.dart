import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/ai/models/ai_memory_item.dart';
import '../../../core/ai/providers/ai_memory_provider.dart';
import '../../../core/theme/app_tokens.dart';

class AiMemoryScreen extends ConsumerWidget {
  const AiMemoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final memories = ref.watch(aiMemoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Agent 记忆'),
        actions: [
          if (memories.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep_outlined),
              tooltip: '清空所有记忆',
              onPressed: () => _confirmClearAll(context, ref),
            ),
        ],
      ),
      body: memories.isEmpty
          ? _buildEmptyState(context)
          : ListView.builder(
              padding: const EdgeInsets.all(AppSpacing.page),
              itemCount: memories.length,
              itemBuilder: (context, index) {
                // 最新的记忆排在前面
                final memory = memories[memories.length - 1 - index];
                return _buildMemoryCard(context, ref, memory);
              },
            ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final colors = context.colors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.psychology_outlined,
              size: 64,
              color: colors.border,
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              '暂无长期记忆',
              style: AppText.sectionTitle.copyWith(color: colors.text),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              '在对话中提到您的宿舍、日常偏好、作息习惯或备考目标，Agent 会更主动为您添加并沉淀记忆；您也可以随时在此查看和删除记忆。',
              textAlign: TextAlign.center,
              style: AppText.caption.copyWith(
                color: colors.textMuted,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMemoryCard(
    BuildContext context,
    WidgetRef ref,
    AiMemoryItem item,
  ) {
    final colors = context.colors;
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg, vertical: 14),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: AppRadius.cardAll,
        border: Border.all(color: colors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: SelectableText(
              item.content,
              style: AppText.bodyDense.copyWith(
                height: 1.45,
                color: colors.text,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          IconButton(
            icon: Icon(
              Icons.delete_outline_rounded,
              size: 20,
              color: colors.textMuted,
            ),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: () => _confirmDeleteMemory(context, ref, item),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteMemory(
    BuildContext context,
    WidgetRef ref,
    AiMemoryItem item,
  ) {
    final colors = context.colors;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除记忆'),
        content: Text('确定删除记忆「${item.content}」吗？删除后 Agent 将不再调用该信息。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(aiMemoryProvider.notifier).deleteMemory(item.id);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('已删除该记忆'),
                    duration: Duration(seconds: 1),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            style: TextButton.styleFrom(foregroundColor: colors.danger),
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }

  void _confirmClearAll(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('清空所有记忆'),
        content: const Text('确定清空所有沉淀的 Agent 长期记忆吗？此操作不可逆。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(aiMemoryProvider.notifier).clearAll();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('已清空所有记忆'),
                    duration: Duration(seconds: 1),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            style: TextButton.styleFrom(foregroundColor: colors.danger),
            child: const Text('清空全部'),
          ),
        ],
      ),
    );
  }
}
