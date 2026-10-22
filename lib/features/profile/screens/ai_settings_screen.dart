import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/ai/ai_provider.dart';
import '../../../core/ai/ai_service.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/l10n_extension.dart';
import '../../../core/utils/route_utils.dart';
import 'ai_memory_screen.dart';

class AiSettingsScreen extends ConsumerStatefulWidget {
  const AiSettingsScreen({super.key});

  @override
  ConsumerState<AiSettingsScreen> createState() => _AiSettingsScreenState();
}

class _AiSettingsScreenState extends ConsumerState<AiSettingsScreen> {
  late TextEditingController _apiUrlController;
  late TextEditingController _modelController;
  late TextEditingController _apiKeyController;
  bool _obscureApiKey = true;
  bool _isSaving = false;
  bool _isFetchingModels = false;
  bool _isTestingConnection = false;
  List<String> _availableModels = [];

  @override
  void initState() {
    super.initState();
    final aiState = ref.read(aiAssistantProvider);
    _apiUrlController = TextEditingController(text: aiState.resolvedApiUrl);
    _modelController = TextEditingController(text: aiState.resolvedModel);
    _apiKeyController = TextEditingController(text: aiState.apiKey ?? '');
    _apiUrlController.addListener(_onFieldChanged);
    _modelController.addListener(_onFieldChanged);
    _apiKeyController.addListener(_onFieldChanged);
  }

  void _onFieldChanged() {
    setState(() {});
  }

  bool get _isDefaultConfig {
    final apiUrl = _apiUrlController.text.trim();
    final model = _modelController.text.trim();
    final apiKey = _apiKeyController.text.trim();
    final isDefaultUrl = apiUrl.isEmpty || apiUrl == AiAssistantService.defaultApiUrl;
    final isDefaultModel = model.isEmpty || model == AiAssistantService.defaultModel;
    final isDefaultKey = apiKey.isEmpty;
    return isDefaultUrl && isDefaultModel && isDefaultKey;
  }

  @override
  void dispose() {
    _apiUrlController.removeListener(_onFieldChanged);
    _modelController.removeListener(_onFieldChanged);
    _apiKeyController.removeListener(_onFieldChanged);
    _apiUrlController.dispose();
    _modelController.dispose();
    _apiKeyController.dispose();
    super.dispose();
  }

  Future<void> _saveSettings() async {
    setState(() {
      _isSaving = true;
    });

    final apiUrl = _apiUrlController.text.trim();
    final model = _modelController.text.trim();
    final apiKey = _apiKeyController.text.trim();

    // 留空表示跟随默认（Worker 中转），由 saveFullSettings 落盘为“清除”。
    await ref.read(aiAssistantProvider.notifier).saveFullSettings(
      apiUrl: apiUrl,
      model: model,
      apiKey: apiKey,
    );

    setState(() {
      _isSaving = false;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.aiSettingsSaved),
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.pop(context);
    }
  }

  Future<void> _resetDefaults() async {
    await ref.read(aiAssistantProvider.notifier).resetToDefaults();
    setState(() {
      _apiUrlController.text = AiAssistantService.defaultApiUrl;
      _modelController.text = AiAssistantService.defaultModel;
      _apiKeyController.clear();
      _availableModels.clear();
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.aiSettingsResetDefaults),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _testConnection() async {
    final apiKey = _apiKeyController.text.trim();
    final aiState = ref.read(aiAssistantProvider);
    if (apiKey.isEmpty && !aiState.hasApiKey) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.aiApiKeyRequired),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() {
      _isTestingConnection = true;
    });

    try {
      final apiUrl = _apiUrlController.text.trim();
      final model = _modelController.text.trim();
      final latency =
          await ref.read(aiAssistantProvider.notifier).testConnection(
                apiUrl: apiUrl,
                model: model,
                apiKey: apiKey,
              );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('✅ ${context.l10n.aiTestSuccess(latency.inMilliseconds)}'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        final errorMsg = e.toString().replaceFirst('Exception: ', '');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ ${context.l10n.aiTestFailed(errorMsg)}'),
            backgroundColor: context.colors.danger,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isTestingConnection = false;
        });
      }
    }
  }

  Future<void> _downloadModels({bool openDropdownAfter = false}) async {
    final apiKey = _apiKeyController.text.trim();
    final aiState = ref.read(aiAssistantProvider);
    if (apiKey.isEmpty && !aiState.hasApiKey) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.aiApiKeyRequired),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() {
      _isFetchingModels = true;
    });

    try {
      final apiUrl = _apiUrlController.text.trim();
      final models = await ref.read(aiAssistantProvider.notifier).fetchModels(
            apiUrl: apiUrl,
            apiKey: apiKey,
          );

      setState(() {
        _availableModels = models;
        if (models.isNotEmpty) {
          _modelController.text = models.first;
        }
      });

      if (mounted) {
        if (openDropdownAfter) {
          _showModelSelectionSheet();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                models.isNotEmpty
                    ? '获取成功，共 ${models.length} 个模型，已默认选择第 1 个'
                    : context.l10n.aiNoModelsFound,
              ),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        final errorMsg = e.toString().replaceFirst('Exception: ', '');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMsg),
            backgroundColor: context.colors.danger,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isFetchingModels = false;
        });
      }
    }
  }

  void _openModelDropdown() {
    if (_availableModels.isEmpty) {
      _downloadModels(openDropdownAfter: true);
    } else {
      _showModelSelectionSheet();
    }
  }

  void _showModelSelectionSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return _ModelSelectionModal(
          initialModels: _availableModels,
          selectedModel: _modelController.text.trim(),
          onModelSelected: (model) {
            setState(() {
              _modelController.text = model;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(context.l10n.aiModelSelected(model)),
                behavior: SnackBarBehavior.floating,
                duration: const Duration(seconds: 2),
              ),
            );
          },
          onRefresh: () async {
            Navigator.pop(sheetContext);
            await _downloadModels(openDropdownAfter: true);
          },
        );
      },
    );
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data != null && data.text != null) {
      setState(() {
        _apiKeyController.text = data.text!.trim();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final aiState = ref.watch(aiAssistantProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.agentSettings),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.page),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // API 接口地址 (Base URL)
            TextField(
              controller: _apiUrlController,
              style: AppText.bodyDense.copyWith(color: colors.text),
              decoration: InputDecoration(
                labelText: context.l10n.aiApiUrl,
                hintText: context.l10n.aiApiUrlHint,
                prefixIcon: Icon(
                  Icons.link_rounded,
                  size: 20,
                  color: colors.textMuted,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            // 模型名称 (Model Name)
            TextField(
              controller: _modelController,
              style: AppText.bodyDense.copyWith(color: colors.text),
              decoration: InputDecoration(
                labelText: context.l10n.aiModelName,
                hintText: context.l10n.aiModelNameHint,
                prefixIcon: Icon(
                  Icons.memory_outlined,
                  size: 20,
                  color: colors.textMuted,
                ),
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_isFetchingModels)
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    else ...[
                      IconButton(
                        icon: const Icon(Icons.download_rounded, size: 20),
                        tooltip: context.l10n.aiFetchModels,
                        onPressed: _downloadModels,
                      ),
                      IconButton(
                        icon: const Icon(Icons.arrow_drop_down_rounded, size: 24),
                        tooltip: context.l10n.aiSelectModel,
                        onPressed: _openModelDropdown,
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            // API Key
            TextField(
              controller: _apiKeyController,
              obscureText: _obscureApiKey,
              style: AppText.bodyDense.copyWith(color: colors.text),
              decoration: InputDecoration(
                labelText: aiState.hasCustomApiKey
                    ? context.l10n.aiApiKeyCustom
                    : context.l10n.aiApiKeyDefault,
                hintText: context.l10n.aiApiKeyHint,
                prefixIcon: Icon(
                  Icons.vpn_key_outlined,
                  size: 20,
                  color: colors.textMuted,
                ),
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(
                        _obscureApiKey
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        size: 20,
                        color: colors.textMuted,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscureApiKey = !_obscureApiKey;
                        });
                      },
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.paste_rounded,
                        size: 20,
                        color: colors.textMuted,
                      ),
                      tooltip: context.l10n.paste,
                      onPressed: _pasteFromClipboard,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),

            // 记忆管理入口
            Container(
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: AppRadius.cardAll,
                border: Border.all(color: colors.border),
              ),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    createSlideUpRoute(const AiMemoryScreen()),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg, vertical: AppSpacing.md),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '记忆管理',
                        style: AppText.body.copyWith(
                          fontWeight: FontWeight.w600,
                          color: colors.text,
                        ),
                      ),
                      Icon(
                        Icons.chevron_right_rounded,
                        size: 20,
                        color: colors.textMuted,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xxxl),

            if (!_isDefaultConfig) ...[
              // 测试连接按钮
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _isTestingConnection ? null : _testConnection,
                  icon: _isTestingConnection
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.wifi_tethering_rounded, size: 20),
                  label: Text(
                    _isTestingConnection
                        ? context.l10n.aiTestingConnection
                        : context.l10n.aiTestConnection,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
            ],

            // 保存按钮（主按钮交给全局 elevatedButtonTheme）
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _saveSettings,
                child: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(Colors.white),
                        ),
                      )
                    : Text(context.l10n.saveSettings),
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // 恢复默认配置按钮
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _resetDefaults,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: Text(context.l10n.resetDefaults),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModelSelectionModal extends StatefulWidget {
  final List<String> initialModels;
  final String selectedModel;
  final ValueChanged<String> onModelSelected;
  final Future<void> Function() onRefresh;

  const _ModelSelectionModal({
    required this.initialModels,
    required this.selectedModel,
    required this.onModelSelected,
    required this.onRefresh,
  });

  @override
  State<_ModelSelectionModal> createState() => _ModelSelectionModalState();
}

class _ModelSelectionModalState extends State<_ModelSelectionModal> {
  final TextEditingController _searchController = TextEditingController();
  late List<String> _filteredModels;

  @override
  void initState() {
    super.initState();
    _filteredModels = List.from(widget.initialModels);
    _searchController.addListener(_filter);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filter() {
    final query = _searchController.text.trim().toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredModels = List.from(widget.initialModels);
      } else {
        _filteredModels = widget.initialModels
            .where((m) => m.toLowerCase().contains(query))
            .toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Container(
      height: MediaQuery.of(context).size.height * 0.72,
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(AppRadius.card)),
      ),
      child: Column(
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 6),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: colors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.l10n.aiSelectModel,
                        style: AppText.sectionTitle.copyWith(color: colors.text),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '共 ${widget.initialModels.length} 个模型',
                        style:
                            AppText.caption.copyWith(color: colors.textMuted),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh_rounded, size: 20),
                  tooltip: context.l10n.aiFetchModels,
                  onPressed: widget.onRefresh,
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          // Search box
          Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg, vertical: 6),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: context.l10n.aiSearchModelHint,
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 18),
                        onPressed: () => _searchController.clear(),
                      )
                    : null,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                filled: true,
                fillColor: colors.surfaceSubtle,
                border: OutlineInputBorder(
                  borderRadius: AppRadius.controlAll,
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: AppRadius.controlAll,
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          Divider(height: 1, color: colors.border),
          // Models list
          Expanded(
            child: _filteredModels.isEmpty
                ? Center(
                    child: Text(
                      context.l10n.aiNoModelsFound,
                      style:
                          AppText.bodyDense.copyWith(color: colors.textMuted),
                    ),
                  )
                : ListView.builder(
                    itemCount: _filteredModels.length,
                    itemBuilder: (context, index) {
                      final model = _filteredModels[index];
                      final isSelected = model == widget.selectedModel;
                      return ListTile(
                        leading: Icon(
                          Icons.memory_outlined,
                          size: 20,
                          color: isSelected ? colors.brand : colors.textMuted,
                        ),
                        title: Text(
                          model,
                          style: AppText.bodyDense.copyWith(
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.normal,
                            color: isSelected ? colors.brandText : colors.text,
                          ),
                        ),
                        trailing: isSelected
                            ? Icon(Icons.check_rounded,
                                color: colors.brand, size: 20)
                            : null,
                        onTap: () {
                          widget.onModelSelected(model);
                          Navigator.pop(context);
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
