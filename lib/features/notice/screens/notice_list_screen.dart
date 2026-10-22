import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/message_model.dart';
import '../providers/notice_provider.dart'; // ✅ 导入新 Provider
import 'notice_detail_screen.dart';
import '../../../core/state/auth_state.dart';
import '../../../core/widgets/login_required_placeholder.dart';
import '../../../core/utils/l10n_extension.dart';
import '../../../core/utils/route_utils.dart';
import '../../../core/theme/app_tokens.dart';

class NoticeListScreen extends ConsumerStatefulWidget {
  const NoticeListScreen({super.key});

  @override
  ConsumerState<NoticeListScreen> createState() => _NoticeListScreenState();
}

class _NoticeListScreenState extends ConsumerState<NoticeListScreen> with AutomaticKeepAliveClientMixin {
  final ScrollController _scrollController = ScrollController();
  String? _selectedNoticeId;
  bool _isTransitioningToRoute = false;
  
  @override
  bool get wantKeepAlive => true; // ✅ 保持页面状态，切换 Tab 不会销毁
  
  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      final noticeState = ref.read(noticeProvider);
      if (!noticeState.isLoading && !noticeState.isLoadingMore && noticeState.hasMore) {
        ref.read(noticeProvider.notifier).loadMore();
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    super.build(context); // 必须调用 super.build
    final authState = ref.watch(authStateProvider);
    final noticeState = ref.watch(noticeProvider);
    
    return LayoutBuilder(
      builder: (context, constraints) {
        final isLargeScreen = constraints.maxWidth >= 600;

        if (!isLargeScreen && _selectedNoticeId != null && !_isTransitioningToRoute) {
          _isTransitioningToRoute = true;
          final noticeIdToOpen = _selectedNoticeId!;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            setState(() {
              _selectedNoticeId = null;
              _isTransitioningToRoute = false;
            });
            Navigator.of(context).push(
              createSlideHorizontalRoute(
                NoticeDetailScreen(noticeId: noticeIdToOpen),
              ),
            );
          });
        }

        if (isLargeScreen) {
          return Scaffold(
            body: Row(
              children: [
                Expanded(
                  flex: 1,
                  child: _buildBody(authState, noticeState, isLargeScreen: true),
                ),
                VerticalDivider(
                  width: 1,
                  thickness: 1,
                  color: context.colors.border,
                ),
                Expanded(
                  flex: 1,
                  child: _buildDetailPane(context),
                ),
              ],
            ),
          );
        }
        return Scaffold(
          body: _buildBody(authState, noticeState, isLargeScreen: false),
        );
      },
    );
  }

  Widget _buildDetailPane(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      reverseDuration: const Duration(milliseconds: 250),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) {
        final tween = Tween<Offset>(
          begin: const Offset(0.08, 0.0),
          end: Offset.zero,
        ).chain(CurveTween(curve: Curves.easeOutCubic));

        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: animation.drive(tween),
            child: child,
          ),
        );
      },
      child: _selectedNoticeId == null
          ? Center(
              key: const ValueKey('notice_empty_pane'),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.mark_email_unread_outlined,
                    size: 64,
                    color: context.colors.textMuted,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    context.l10n.selectNoticeHint,
                    style: AppText.bodyDense.copyWith(
                      color: context.colors.textMuted,
                    ),
                  ),
                ],
              ),
            )
          : NoticeDetailScreen(
              key: ValueKey(_selectedNoticeId),
              noticeId: _selectedNoticeId!,
              isEmbedded: true,
              onClose: () {
                setState(() {
                  _selectedNoticeId = null;
                });
              },
            ),
    );
  }
  
  Widget _buildBody(AuthState authState, NoticeState noticeState, {required bool isLargeScreen}) {
    // 只有在完全没有本地账号信息时，才显示登录占位符
    if (authState.status == AuthStatus.unauthenticated && !authState.hasAccount) {
      return LoginRequiredPlaceholder(
        title: context.l10n.noticeLoginTitle,
        message: context.l10n.noticeLoginMessage,
        icon: Icons.notifications_paused_outlined,
      );
    }
    
    if (noticeState.isLoading && noticeState.messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: AppSpacing.lg),
            Text(
              context.l10n.loadingNotices,
              style: AppText.bodyDense.copyWith(color: context.colors.textMuted),
            ),
          ],
        ),
      );
    }

    if (noticeState.errorMessage != null && noticeState.messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: context.colors.danger),
            const SizedBox(height: AppSpacing.lg),
            Text(
              context.l10n.loadFailed,
              style: AppText.sectionTitle.copyWith(color: context.colors.text),
            ),
            const SizedBox(height: AppSpacing.sm),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxxl),
              child: Text(
                noticeState.errorMessage!,
                textAlign: TextAlign.center,
                style: AppText.bodyDense.copyWith(
                  color: context.colors.textMuted,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xxl),
            ElevatedButton.icon(
              onPressed: () => ref.read(noticeProvider.notifier).refresh(),
              icon: const Icon(Icons.refresh),
              label: Text(context.l10n.retry),
            ),
          ],
        ),
      );
    }

    if (noticeState.messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.notifications_none,
                size: 80, color: context.colors.textMuted),
            const SizedBox(height: AppSpacing.lg),
            Text(
              context.l10n.noNotices,
              style: AppText.sectionTitle.copyWith(color: context.colors.text),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              context.l10n.noNoticesSubtitle,
              style: AppText.caption.copyWith(
                color: context.colors.textMuted,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => ref.read(noticeProvider.notifier).refresh(),
      child: ListView.builder(
        controller: _scrollController,
        itemCount: noticeState.messages.length + (noticeState.hasMore ? 1 : 0),
        padding: EdgeInsets.zero,
        itemBuilder: (context, index) {
          if (index == noticeState.messages.length) {
            return _buildLoadMoreIndicator(noticeState);
          }
          final message = noticeState.messages[index];
          return _buildMessageCard(message, isLargeScreen: isLargeScreen);
        },
      ),
    );
  }

  Widget _buildLoadMoreIndicator(NoticeState noticeState) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Center(
        child: noticeState.isLoadingMore
            ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Text(
                    context.l10n.loadingMore,
                    style: AppText.caption.copyWith(color: context.colors.textMuted),
                  ),
                ],
              )
            : noticeState.hasMore
                ? const SizedBox.shrink()
                : Text(
                    context.l10n.noMoreNotices,
                    style: AppText.caption.copyWith(color: context.colors.textMuted),
                  ),
      ),
    );
  }
  
  Widget _buildMessageCard(MessageModel message, {required bool isLargeScreen}) {
    // 提取时间 (仅显示时分或月日)
    String timeDisplay = message.sendTime;
    try {
      final parts = message.sendTime.split(' ');
      if (parts.length > 1) {
        final date = parts[0];
        final time = parts[1];
        final now = DateTime.now();
        final today = '${now.year}-${_twoDigits(now.month)}-${_twoDigits(now.day)}';
        timeDisplay = (date == today) ? time.substring(0, 5) : date.substring(5);
      }
    } catch (_) {}

    // 获取发送者首字母用于头像
    String initial = context.l10n.noticeTagNotice;
    if (message.createrName.isNotEmpty) {
      initial = message.createrName[0];
    }

    final isSelected = isLargeScreen && _selectedNoticeId == message.idCode;

    return Padding(
      padding: isLargeScreen
          ? const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 2)
          : EdgeInsets.zero,
      child: Container(
        decoration: BoxDecoration(
          color: isSelected
              ? context.colors.statusBg(context.colors.brand)
              : Colors.transparent,
          borderRadius: AppRadius.innerAll,
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: AppRadius.innerAll,
          child: InkWell(
            borderRadius: AppRadius.innerAll,
            onTap: () {
              if (isLargeScreen) {
                setState(() {
                  _selectedNoticeId = message.idCode;
                });
              } else {
                Navigator.push(
                  context,
                  createSlideHorizontalRoute(
                    NoticeDetailScreen(
                      noticeId: message.idCode,
                    ),
                  ),
                );
              }
            },
          child: Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.page, vertical: AppSpacing.md),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 左侧头像
                CircleAvatar(
                  radius: 20,
                  backgroundColor:
                      context.colors.statusBg(context.colors.brand),
                  child: Text(
                    initial,
                    style: AppText.bodyDense.copyWith(
                      color: context.colors.brandText,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.lg),
                // 中间内容
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              message.createrName.isEmpty ? context.l10n.systemNotice : message.createrName,
                              style: AppText.body.copyWith(
                                fontWeight: message.isRead ? FontWeight.w400 : FontWeight.w600,
                                color: message.isRead
                                    ? context.colors.textMuted
                                    : context.colors.text,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          // 时间
                          Text(
                            timeDisplay,
                            style: AppText.caption.copyWith(
                              color: context.colors.textMuted,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      // 标题
                      Text(
                        message.title,
                        style: AppText.bodyDense.copyWith(
                          color: message.isRead
                              ? context.colors.textMuted
                              : context.colors.text,
                          fontWeight: message.isRead ? FontWeight.w400 : FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 1),
                      // 内容摘要
                      Text(
                        message.content.replaceAll(RegExp(r'<[^>]*>|&[^;]+;'), '').trim(),
                        style: AppText.caption.copyWith(
                          color: context.colors.textMuted,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

  String _twoDigits(int n) => n.toString().padLeft(2, '0');
  

}
