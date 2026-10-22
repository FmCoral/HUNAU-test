import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/l10n_extension.dart';
import '../../../core/utils/route_utils.dart';
import '../models/library_book_models.dart';
import '../providers/library_provider.dart';
import 'library_book_detail_screen.dart';

class LibraryBookSearchScreen extends ConsumerStatefulWidget {
  final String? initialKeyword;

  const LibraryBookSearchScreen({super.key, this.initialKeyword});

  @override
  ConsumerState<LibraryBookSearchScreen> createState() =>
      _LibraryBookSearchScreenState();
}

class _LibraryBookSearchScreenState
    extends ConsumerState<LibraryBookSearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    final kw = widget.initialKeyword?.trim();
    if (kw != null && kw.isNotEmpty) {
      _searchController.text = kw;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _onSearch();
      });
    }
  }

  @override
  void dispose() {
    ref.read(libraryBookSearchProvider.notifier).cancel();
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onSearch() {
    final text = _searchController.text.trim();
    if (text.isEmpty) return;
    _focusNode.unfocus();
    ref.read(libraryBookSearchProvider.notifier).search(text);
  }

  @override
  Widget build(BuildContext context) {
    final searchState = ref.watch(libraryBookSearchProvider);
    final colors = context.colors;

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          ref.read(libraryBookSearchProvider.notifier).cancel();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(context.l10n.bookSearch),
        ),
        body: Column(
          children: [
            // 1. 搜索框与类型切换栏
            _buildSearchHeader(searchState, colors),

            // 2. 加载进度提示栏
            if (searchState.isLoading) _buildLoadingIndicator(colors),

            // 3. 结果或状态内容区
            Expanded(
              child: _buildBody(searchState, colors),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchHeader(
      LibraryBookSearchState state, AppSemanticColors colors) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.page, AppSpacing.sm, AppSpacing.page, AppSpacing.md),
      child: Column(
        children: [
          // 输入框行
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: colors.surfaceSubtle,
                    borderRadius: AppRadius.controlAll,
                  ),
                  child: Row(
                    children: [
                      const SizedBox(width: AppSpacing.md),
                      Icon(
                        Icons.search_rounded,
                        size: 20,
                        color: colors.textMuted,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          focusNode: _focusNode,
                          textInputAction: TextInputAction.search,
                          onSubmitted: (_) => _onSearch(),
                          style:
                              AppText.bodyDense.copyWith(color: colors.text),
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            filled: false,
                            fillColor: Colors.transparent,
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ),
                      if (_searchController.text.isNotEmpty)
                        IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 18),
                          color: colors.textMuted,
                          splashRadius: 16,
                          onPressed: () {
                            setState(() {
                              _searchController.clear();
                            });
                          },
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(64, 48),
                  padding:
                      const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                ),
                onPressed: _onSearch,
                child: Text(context.l10n.search),
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.md),

          // 检索类型切换器（书名 / 作者 / 主题 / 标准编码）左对齐
          Align(
            alignment: Alignment.centerLeft,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildTypeChip(
                      'title', context.l10n.searchTypeTitle, state.searchType, colors),
                  const SizedBox(width: AppSpacing.sm),
                  _buildTypeChip(
                      'author', context.l10n.searchTypeAuthor, state.searchType, colors),
                  const SizedBox(width: AppSpacing.sm),
                  _buildTypeChip('subject', context.l10n.searchTypeSubject,
                      state.searchType, colors),
                  const SizedBox(width: AppSpacing.sm),
                  _buildTypeChip('Identifier', context.l10n.searchTypeIdentifier,
                      state.searchType, colors),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeChip(
    String type,
    String label,
    String currentType,
    AppSemanticColors colors,
  ) {
    final isSelected = type == currentType;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: AppRadius.controlAll,
        onTap: () {
          ref.read(libraryBookSearchProvider.notifier).setSearchType(type);
          if (_searchController.text.trim().isNotEmpty) {
            _onSearch();
          }
        },
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

  Widget _buildLoadingIndicator(AppSemanticColors colors) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.page, vertical: AppSpacing.sm),
      color: colors.statusBg(colors.brand),
      child: Row(
        children: [
          const SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              context.l10n.bookSearchLoading,
              style: AppText.caption.copyWith(
                color: colors.brandText,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(LibraryBookSearchState state, AppSemanticColors colors) {
    if (state.error != null) {
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
                state.error!,
                textAlign: TextAlign.center,
                style: AppText.bodyDense.copyWith(color: colors.text),
              ),
              const SizedBox(height: AppSpacing.lg),
              ElevatedButton(
                onPressed: _onSearch,
                child: Text(context.l10n.retry),
              ),
            ],
          ),
        ),
      );
    }

    if (state.result == null) {
      return const SizedBox.shrink();
    }

    final books = state.result!.books;
    if (books.isEmpty) {
      if (state.isLoading) {
        return const SizedBox.shrink();
      }
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.search_off_rounded,
              size: 56,
              color: colors.textMuted,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              context.l10n.bookSearchEmpty,
              style: AppText.bodyDense.copyWith(color: colors.textMuted),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.page, vertical: AppSpacing.md),
      itemCount: books.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(
              context.l10n.bookSearchTotalCount(books.length),
              style: AppText.caption.copyWith(
                color: colors.textMuted,
                fontWeight: FontWeight.w600,
              ),
            ),
          );
        }

        final book = books[index - 1];
        return _buildBookCard(book, colors);
      },
    );
  }

  Widget _buildBookCard(LibraryBook book, AppSemanticColors colors) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
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
            Navigator.push(
              context,
              createSlideUpRoute(LibraryBookDetailScreen(book: book)),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.card),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 题名与箭头
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        book.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.sectionTitle.copyWith(color: colors.text),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 14,
                      color: colors.textMuted,
                    ),
                  ],
                ),

                const SizedBox(height: AppSpacing.sm),

                // 作者与出版社
                if (book.author.isNotEmpty || book.publisher.isNotEmpty)
                  Text(
                    [
                      if (book.author.isNotEmpty) book.author,
                      if (book.publisher.isNotEmpty) book.publisher,
                    ].join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style:
                        AppText.bodyDense.copyWith(color: colors.textMuted),
                  ),

                const SizedBox(height: AppSpacing.sm),

                // 索书号与出版年份标签
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: 6,
                  children: [
                    if (book.callNumber.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: colors.statusBg(colors.brand),
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                        ),
                        child: Text(
                          '${context.l10n.callNumber}: ${book.callNumber}',
                          style: AppText.caption.copyWith(
                            color: colors.brandText,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    if (book.isbn.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: colors.surfaceSubtle,
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                        ),
                        child: Text(
                          'ISBN: ${book.isbn}',
                          style: AppText.caption
                              .copyWith(color: colors.textMuted),
                        ),
                      ),
                    if (book.publishYear.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: colors.surfaceSubtle,
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                        ),
                        child: Text(
                          book.publishYear,
                          style: AppText.caption
                              .copyWith(color: colors.textMuted),
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
}
