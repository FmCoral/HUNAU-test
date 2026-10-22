import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/ai/ai_provider.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/l10n_extension.dart';
import '../../../core/utils/route_utils.dart';
import '../../profile/screens/ai_memory_screen.dart';
import '../../profile/screens/ai_settings_screen.dart';

/// 贴合 MD2 规范的 AI 响应卡片组件
class AiResponseCard extends ConsumerStatefulWidget {
  final VoidCallback? onClose;
  final ValueChanged<String>? onQuickQuerySelected;

  const AiResponseCard({
    super.key,
    this.onClose,
    this.onQuickQuerySelected,
  });

  @override
  ConsumerState<AiResponseCard> createState() => _AiResponseCardState();
}

class _AiResponseCardState extends ConsumerState<AiResponseCard> {
  final ScrollController _scrollController = ScrollController();
  GlobalKey _latestUserMessageKey = GlobalKey();
  int _lastUserMessageCount = 0;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToLatestUserMessage() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final targetContext = _latestUserMessageKey.currentContext;
      if (targetContext != null && targetContext.mounted) {
        Scrollable.ensureVisible(
          targetContext,
          alignment: 0.0,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      } else if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final aiState = ref.watch(aiAssistantProvider);

    final userMessageCount =
        aiState.displayMessages.where((m) => m.role == 'user').length;
    if (userMessageCount != _lastUserMessageCount) {
      _lastUserMessageCount = userMessageCount;
      _latestUserMessageKey = GlobalKey();
    }

    // 当消息增加或正在加载时滚动到最新用户消息（用户消息在顶部，AI回答紧接着在下方）
    ref.listen<AiAssistantState>(aiAssistantProvider, (prev, next) {
      if (next.displayMessages.length != prev?.displayMessages.length ||
          next.isLoading != prev?.isLoading) {
        _scrollToLatestUserMessage();
      }
    });

    final screenHeight = MediaQuery.of(context).size.height;
    final cardMaxHeight = screenHeight * 0.52;

    return Material(
      type: MaterialType.transparency,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {},
        child: Container(
          width: double.infinity,
          constraints: BoxConstraints(
            maxHeight: cardMaxHeight,
            minHeight: 100,
          ),
          margin: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: AppRadius.cardAll,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 2,
              offset: const Offset(0, 1),
            ),
          ],
          border: Border.all(
            color: colors.border,
            width: 1.0,
          ),
        ),
        child: ClipRRect(
          borderRadius: AppRadius.cardAll,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 卡片顶栏
              _buildCardHeader(context, aiState),

              // 卡片主体内容
              Flexible(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 4, 14, 12),
                  child: _buildCardContent(context, aiState),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

  /// 卡片头部（显示记忆入口、新对话与配置）
  Widget _buildCardHeader(
      BuildContext context, AiAssistantState aiState) {
    final colors = context.colors;
    if (aiState.displayMessages.isEmpty) {
      return const SizedBox(height: 6);
    }
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 2),
      decoration: const BoxDecoration(
        color: Colors.transparent,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          // 记忆快捷入口
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                createSlideUpRoute(const AiMemoryScreen()),
              );
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.psychology_outlined,
                    size: 14,
                    color: colors.textMuted,
                  ),
                  const SizedBox(width: 3),
                  Text(
                    '记忆',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: colors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          // 开启新对话
          GestureDetector(
            onTap: () {
              ref.read(aiAssistantProvider.notifier).clearSession();
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              child: Row(
                children: [
                  Icon(
                    Icons.refresh_rounded,
                    size: 14,
                    color: colors.textMuted,
                  ),
                  const SizedBox(width: 3),
                  Text(
                    context.l10n.newChat,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: colors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          // 配置
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                createSlideHorizontalRoute(const AiSettingsScreen()),
              );
            },
            child: Padding(
              padding: const EdgeInsets.all(2),
              child: Icon(
                Icons.code_rounded,
                size: 16,
                color: colors.textMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 卡片主体
  Widget _buildCardContent(
      BuildContext context, AiAssistantState aiState) {
    if (aiState.errorMessage != null && aiState.displayMessages.isEmpty) {
      return _buildErrorState(context, aiState.errorMessage!);
    }

    if (aiState.displayMessages.isEmpty && !aiState.isLoading) {
      return _buildInitialQuickActions(context);
    }

    final isLimitReached = aiState.isRoundLimitReached;
    final hasError = aiState.errorMessage != null && !aiState.isLoading && !isLimitReached;
    final itemCount = aiState.displayMessages.length +
        (aiState.isLoading ? 1 : 0) +
        (hasError ? 1 : 0) +
        (isLimitReached ? 1 : 0);

    final latestUserMessageIndex =
        aiState.displayMessages.lastIndexWhere((m) => m.role == 'user');

    return ListView.builder(
      controller: _scrollController,
      shrinkWrap: true,
      physics: const BouncingScrollPhysics(),
      itemCount: itemCount,
      itemBuilder: (context, index) {
        if (index < aiState.displayMessages.length) {
          final msg = aiState.displayMessages[index];
          final isLatestUser = index == latestUserMessageIndex;
          return _buildMessageItem(
            msg,
            key: isLatestUser ? _latestUserMessageKey : null,
          );
        }
        var nextIdx = index - aiState.displayMessages.length;
        if (aiState.isLoading) {
          if (nextIdx == 0) return _buildLoadingBubble(aiState);
          nextIdx--;
        }
        if (hasError) {
          if (nextIdx == 0) return _buildErrorMessageBubble(aiState.errorMessage!);
          nextIdx--;
        }
        if (isLimitReached && nextIdx == 0) {
          return _buildRoundLimitBanner(context);
        }
        return const SizedBox.shrink();
      },
    );
  }

  /// 对话轮次达到上限提示横幅
  Widget _buildRoundLimitBanner(BuildContext context) {
    final colors = context.colors;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: colors.statusBg(colors.warning),
        borderRadius: AppRadius.innerAll,
        border: Border.all(
          color: colors.warning.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.info_outline_rounded,
                size: 15,
                color: colors.warning,
              ),
              const SizedBox(width: 6),
              Text(
                '已达本轮对话上限（20 轮）',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: colors.warning,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '为了保证回答质量，每次对话最多支持 20 个来回。关键信息与偏好已沉淀至长期记忆，开启新对话即可继续交流。',
            style: TextStyle(
              fontSize: 11.5,
              height: 1.4,
              color: colors.text,
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: InkWell(
              onTap: () {
                ref.read(aiAssistantProvider.notifier).clearSession();
              },
              borderRadius: AppRadius.controlAll,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: colors.primaryButtonBg,
                  borderRadius: AppRadius.controlAll,
                ),
                child: const Text(
                  '开启新对话',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 错误提示气泡
  Widget _buildErrorMessageBubble(String error) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: colors.statusBg(colors.danger),
            borderRadius: AppRadius.controlAll,
            border: Border.all(
              color: colors.danger.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.error_outline_rounded, size: 14, color: colors.danger),
                  const SizedBox(width: 4),
                  Text(
                    context.l10n.requestException,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: colors.danger,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              SelectableText(
                error,
                style: TextStyle(
                  fontSize: 12.5,
                  color: colors.text,
                ),
              ),
              const SizedBox(height: 6),
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    createSlideHorizontalRoute(const AiSettingsScreen()),
                  );
                },
                child: Text(
                  context.l10n.checkAgentSettingsArrow,
                  style: TextStyle(
                    fontSize: 11,
                    color: colors.brandText,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 错误提示
  Widget _buildErrorState(BuildContext context, String error) {
    final colors = context.colors;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline_rounded, size: 32, color: colors.danger),
          const SizedBox(height: 8),
          Text(
            error,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: colors.danger),
          ),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                createSlideHorizontalRoute(const AiSettingsScreen()),
              );
            },
            icon: const Icon(Icons.code_rounded, size: 16),
            label: Text(context.l10n.checkAgentSettings),
          ),
        ],
      ),
    );
  }

  /// 初始快捷提问推荐（白底灰边框，胶囊按钮，右上角设置按钮）
  Widget _buildInitialQuickActions(BuildContext context) {
    final colors = context.colors;
    final quickPrompts = [
      {'icon': Icons.calendar_today_outlined, 'text': context.l10n.promptTodayCourses},
      {'icon': Icons.assignment_outlined, 'text': context.l10n.promptPendingHomework},
      {'icon': Icons.local_library_outlined, 'text': context.l10n.promptReserveLibrary},
      {'icon': Icons.wb_sunny_outlined, 'text': context.l10n.promptSubmitSunshine},
      {'icon': Icons.credit_card_outlined, 'text': context.l10n.promptCampusCardBalance},
      {'icon': Icons.flash_on_outlined, 'text': context.l10n.promptDormElectricity},
      {'icon': Icons.meeting_room_outlined, 'text': context.l10n.promptEmptyClassrooms},
      {'icon': Icons.campaign_outlined, 'text': context.l10n.promptImportantNotices},
    ];

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                context.l10n.quickPromptsTitle,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: colors.textMuted,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    createSlideHorizontalRoute(const AiSettingsScreen()),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.all(2),
                  child: Icon(
                    Icons.code_rounded,
                    size: 16,
                    color: colors.textMuted,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: quickPrompts.map((item) {
              return ActionChip(
                avatar: Icon(
                  item['icon'] as IconData,
                  size: 15,
                  color: colors.brand,
                ),
                label: Text(
                  item['text'] as String,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: colors.text,
                  ),
                ),
                backgroundColor: colors.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: AppRadius.controlAll,
                  side: BorderSide(
                    color: colors.border,
                    width: 1.0,
                  ),
                ),
                onPressed: ref.watch(aiAssistantProvider).isLoading
                    ? null
                    : () {
                        final text = item['text'] as String;
                        ref.read(aiAssistantProvider.notifier).sendMessage(text);
                      },
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  /// 消息渲染（Agent 输出直接铺在卡片背景上，用户消息保持右侧对话气泡）
  Widget _buildMessageItem(AiDisplayMessage msg, {Key? key}) {
    final colors = context.colors;
    final isUser = msg.role == 'user';

    if (isUser) {
      return Padding(
        key: key,
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: colors.statusBg(colors.brand),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(AppRadius.control),
                  topRight: Radius.circular(AppRadius.control),
                  bottomLeft: Radius.circular(AppRadius.control),
                  bottomRight: Radius.circular(2),
                ),
                border: Border.all(
                  color: colors.brand.withValues(alpha: 0.2),
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (msg.imagePath != null && File(msg.imagePath!).existsSync()) ...[
                    GestureDetector(
                      onTap: () {
                        showDialog(
                          context: context,
                          builder: (_) => Dialog(
                            backgroundColor: Colors.transparent,
                            insetPadding: const EdgeInsets.all(16),
                            child: Stack(
                              alignment: Alignment.topRight,
                              children: [
                                Center(
                                  child: InteractiveViewer(
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.file(File(msg.imagePath!)),
                                    ),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.close_rounded, color: Colors.white, size: 28),
                                  onPressed: () => Navigator.pop(context),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                      child: Padding(
                        padding: EdgeInsets.only(bottom: msg.text.isNotEmpty ? 6 : 0),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: Image.file(
                            File(msg.imagePath!),
                            width: 140,
                            height: 140,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ),
                  ],
                  if (msg.text.isNotEmpty)
                    SelectableText(
                      msg.text,
                      style: TextStyle(
                        fontSize: 13.5,
                        height: 1.45,
                        color: colors.text,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // Agent 输出：不套在对话框里，直接在背景之上，距离卡片左右两侧间距相同
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: SizedBox(
        width: double.infinity,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            MarkdownBody(
              data: msg.text,
              selectable: true,
              shrinkWrap: true,
              styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
                p: TextStyle(
                  fontSize: 13.5,
                  height: 1.45,
                  color: colors.text,
                ),
                strong: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: colors.text,
                ),
                em: TextStyle(
                  fontStyle: FontStyle.italic,
                  color: colors.text,
                ),
                h1: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: colors.text,
                ),
                h2: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: colors.text,
                ),
                h3: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: colors.text,
                ),
                listBullet: TextStyle(
                  fontSize: 13.5,
                  color: colors.text,
                ),
                code: TextStyle(
                  fontSize: 12,
                  backgroundColor: colors.surfaceSubtle,
                  color: colors.brandText,
                  fontFamily: 'monospace',
                ),
                codeblockDecoration: BoxDecoration(
                  color: colors.surfaceSubtle,
                  borderRadius: AppRadius.controlAll,
                  border: Border.all(
                    color: colors.border,
                    width: 0.5,
                  ),
                ),
                blockquoteDecoration: BoxDecoration(
                  color: colors.surfaceSubtle,
                  borderRadius: BorderRadius.circular(2),
                  border: Border(
                    left: BorderSide(
                      color: colors.brand,
                      width: 3,
                    ),
                  ),
                ),
                tableBorder: TableBorder.all(
                  color: colors.border,
                  width: 0.5,
                ),
                tableHead: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: colors.text,
                ),
                tableBody: TextStyle(
                  color: colors.text,
                ),
                pPadding: const EdgeInsets.only(bottom: 4),
                listIndent: 16,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: msg.text));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(context.l10n.copiedAnswer),
                        duration: const Duration(seconds: 1),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Row(
                      children: [
                        Icon(
                          Icons.copy_rounded,
                          size: 13,
                          color: colors.textMuted,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          context.l10n.copy,
                          style: TextStyle(
                            fontSize: 11,
                            color: colors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 加载等待指示（直接在背景之上展示）
  Widget _buildLoadingBubble(AiAssistantState aiState) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation(colors.brand),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              context.l10n.aiThinking,
              style: TextStyle(
                fontSize: 12,
                color: colors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 暴露在底栏上方的快捷提问按钮列表（无卡片包裹，一行一个）
class AiQuickPromptsList extends ConsumerWidget {
  final ValueChanged<String>? onPromptSelected;
  final VoidCallback? onDismiss;

  const AiQuickPromptsList({
    super.key,
    this.onPromptSelected,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final quickPrompts = [
      {'icon': Icons.calendar_today_outlined, 'text': context.l10n.promptTodayCourses},
      {'icon': Icons.assignment_outlined, 'text': context.l10n.promptPendingHomework},
      {'icon': Icons.local_library_outlined, 'text': context.l10n.promptReserveLibrary},
      {'icon': Icons.wb_sunny_outlined, 'text': context.l10n.promptSubmitSunshine},
      {'icon': Icons.credit_card_outlined, 'text': context.l10n.promptCampusCardBalance},
      {'icon': Icons.flash_on_outlined, 'text': context.l10n.promptDormElectricity},
      {'icon': Icons.meeting_room_outlined, 'text': context.l10n.promptEmptyClassrooms},
      {'icon': Icons.campaign_outlined, 'text': context.l10n.promptImportantNotices},
    ];

    return Material(
      type: MaterialType.transparency,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onDismiss,
        child: Container(
          width: double.infinity,
          margin: const EdgeInsets.symmetric(horizontal: 16),
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: quickPrompts.map((item) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: ActionChip(
                    elevation: 0,
                    pressElevation: 0,
                    avatar: Icon(
                      item['icon'] as IconData,
                      size: 15,
                      color: colors.brand,
                    ),
                    label: Text(
                      item['text'] as String,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: colors.text,
                      ),
                    ),
                    backgroundColor: colors.surface,
                    shape: RoundedRectangleBorder(
                      borderRadius: AppRadius.controlAll,
                      side: BorderSide(
                        color: colors.border,
                        width: 1.0,
                      ),
                    ),
                    onPressed: ref.watch(aiAssistantProvider).isLoading
                        ? null
                        : () {
                            final text = item['text'] as String;
                            if (onPromptSelected != null) {
                              onPromptSelected!(text);
                            }
                            ref.read(aiAssistantProvider.notifier).sendMessage(text);
                          },
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ),
    ),
  );
}
}
