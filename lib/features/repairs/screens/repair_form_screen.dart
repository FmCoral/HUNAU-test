import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/l10n_extension.dart';
import '../models/repair_models.dart';
import '../services/repair_service.dart';
import '../widgets/authenticated_bxpt_image.dart';

class _AttachedImage {
  final RepairAttachment attachment;
  final String? localFilePath;
  const _AttachedImage({required this.attachment, this.localFilePath});
}

class RepairFormScreen extends ConsumerStatefulWidget {
  final RepairCatalog catalog;
  final RepairOrder? draftOrder;
  const RepairFormScreen({
    super.key,
    required this.catalog,
    this.draftOrder,
  });
  @override
  ConsumerState<RepairFormScreen> createState() => _RepairFormScreenState();
}

class _RepairFormScreenState extends ConsumerState<RepairFormScreen> {
  RepairFormSession? _session;
  bool _loading = true;
  bool _submitting = false;
  String? _error;
  final Map<String, TextEditingController> _controllers = {};
  final Map<String, RepairChoice> _choices = {};
  final Map<String, List<_AttachedImage>> _attachments = {};
  final Map<String, bool> _uploading = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final service = ref.read(repairServiceProvider);
      final session = widget.draftOrder != null
          ? await service.loadDraftForm(widget.draftOrder!)
          : await service.loadForm(widget.catalog);
      if (!mounted) return;
      for (final field in session.fields) {
        final rawVal = session.initialValues[field.name];
        String initialText = '';
        if (rawVal is Map) {
          final id = '${rawVal['id'] ?? rawVal['name'] ?? ''}';
          final label = '${rawVal['display_name'] ?? rawVal['name'] ?? id}';
          if (field.isChoice && id.isNotEmpty) {
            _choices[field.name] = RepairChoice(id, label);
          }
          initialText = label;
        } else if (rawVal != null) {
          initialText = '$rawVal'.trim();
          if (field.isChoice && initialText.isNotEmpty) {
            String label = initialText;
            if (field.editor == 'priority') {
              if (initialText == '1') label = '低';
              if (initialText == '2') label = '中';
              if (initialText == '3') label = '高';
            }
            _choices[field.name] = RepairChoice(initialText, label);
            initialText = label;
          }
        }

        if (field.isDate) {
          if (initialText.isNotEmpty) {
            final ts = int.tryParse(initialText);
            if (ts != null) {
              final dt = DateTime.fromMillisecondsSinceEpoch(ts);
              final y = dt.year.toString().padLeft(4, '0');
              final m = dt.month.toString().padLeft(2, '0');
              final d = dt.day.toString().padLeft(2, '0');
              initialText = '$y/$m/$d';
            } else {
              final parsed =
                  DateTime.tryParse(initialText.replaceAll('/', '-'));
              if (parsed != null) {
                final y = parsed.year.toString().padLeft(4, '0');
                final m = parsed.month.toString().padLeft(2, '0');
                final d = parsed.day.toString().padLeft(2, '0');
                initialText = '$y/$m/$d';
              }
            }
          } else {
            final now = DateTime.now();
            final y = now.year.toString().padLeft(4, '0');
            final m = now.month.toString().padLeft(2, '0');
            final d = now.day.toString().padLeft(2, '0');
            initialText = '$y/$m/$d';
          }
        }
        _controllers[field.name] = TextEditingController(text: initialText);
      }

      for (final field in session.fields) {
        if (field.isUpload) {
          try {
            final draftFiles = await service.fetchDraftAttachments(
              session.instanceId,
              field.name,
            );
            if (draftFiles.isNotEmpty) {
              _attachments[field.name] = draftFiles
                  .map((a) => _AttachedImage(attachment: a))
                  .toList();
            }
          } catch (_) {}
        }
      }

      setState(() {
        _session = session;
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e is RepairException
              ? e.message
              : context.l10n.loadFailedCheckNetwork;
        });
      }
    }
  }

  Future<void> _pickDate(RepairField field) async {
    final controller = _controllers[field.name]!;
    final now = DateTime.now();
    DateTime initial = now;
    if (controller.text.isNotEmpty) {
      final sanitized = controller.text.replaceAll('/', '-');
      final parsed = DateTime.tryParse(sanitized);
      if (parsed != null) initial = parsed;
    }

    final isYyrq = field.name == 'yyrq' || field.label.contains('预约日期');
    final firstDate =
        isYyrq ? DateTime(now.year, now.month, now.day) : DateTime(2020);
    final lastDate = isYyrq
        ? DateTime(now.year, now.month, now.day).add(const Duration(days: 7))
        : DateTime(2035);

    if (initial.isBefore(firstDate)) initial = firstDate;
    if (initial.isAfter(lastDate)) initial = lastDate;

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: firstDate,
      lastDate: lastDate,
    );

    if (picked != null) {
      final y = picked.year.toString().padLeft(4, '0');
      final m = picked.month.toString().padLeft(2, '0');
      final d = picked.day.toString().padLeft(2, '0');
      final formatted = '$y/$m/$d';
      setState(() {
        controller.text = formatted;
        if (isYyrq && _choices['yywxsj'] != null) {
          final isToday = picked.year == now.year &&
              picked.month == now.month &&
              picked.day == now.day;
          const amTimes = ['8_9', '9_10', '10_11', '11_12'];
          if (isToday &&
              now.hour >= 12 &&
              amTimes.contains(_choices['yywxsj']?.id)) {
            _choices.remove('yywxsj');
            _controllers['yywxsj']?.text = '';
          }
        }
      });
    }
  }

  Future<void> _choose(RepairField field) async {
    var choices = <RepairChoice>[];
    try {
      if (field.editor == 'priority') {
        choices = await ref.read(repairServiceProvider).lookup(
            field.referenceType ?? '51ba96d7-9f0c-4077-ac91-921e30fcde3c');
      } else if (field.referenceType != null) {
        List<String>? notInNames;
        if (field.name == 'yywxsj' ||
            field.referenceType == '3965f192-b6ed-11eb-8b80-af0eafc5dd38' ||
            field.label.contains('维修时间')) {
          final now = DateTime.now();
          final y = now.year.toString().padLeft(4, '0');
          final m = now.month.toString().padLeft(2, '0');
          final d = now.day.toString().padLeft(2, '0');
          final todayStr = '$y/$m/$d';
          final selectedDate = _controllers['yyrq']?.text.trim() ?? todayStr;

          if (selectedDate == todayStr && now.hour >= 12) {
            notInNames = const ['8_9', '9_10', '10_11', '11_12'];
          }
        }
        choices = await ref.read(repairServiceProvider).lookup(
              field.referenceType!,
              notInNames: notInNames,
            );
      } else if (field.reference != null) {
        choices =
            await ref.read(repairServiceProvider).references(field.reference!);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e is RepairException ? e.message : e.toString()),
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
    if (!mounted) return;
    if (choices.isEmpty) {
      await _editRaw(field);
      return;
    }
    final selected = await showModalBottomSheet<RepairChoice>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        final colors = context.colors;
        return SafeArea(
          child: ListView(
            padding: const EdgeInsets.only(bottom: 20),
            children: [
              Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                  child: Text(field.label,
                      style: AppText.sectionTitle.copyWith(
                          color: colors.text))),
              ...choices.map((choice) => ListTile(
                    title: Text(choice.label),
                    trailing: _choices[field.name]?.id == choice.id
                        ? Icon(Icons.check, color: colors.brand)
                        : null,
                    onTap: () => Navigator.pop(context, choice),
                  )),
            ],
          ),
        );
      },
    );
    if (selected != null) {
      setState(() {
        _choices[field.name] = selected;
        _controllers[field.name]!.text = selected.label;
      });
    }
  }

  Future<void> _editRaw(RepairField field) async {
    final controller = _controllers[field.name]!;
    final value = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(field.label),
        content: TextField(
            controller: controller,
            autofocus: true,
            decoration:
                InputDecoration(hintText: context.l10n.repairsEnterValue)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(context.l10n.cancel)),
          ElevatedButton(
              onPressed: () => Navigator.pop(context, controller.text),
              child: Text(context.l10n.confirm)),
        ],
      ),
    );
    if (value != null) setState(() {});
  }

  Future<void> _pickAndUploadImage(
    RepairField field,
    ImageSource source,
  ) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: source,
        maxWidth: 1920,
        imageQuality: 85,
      );
      if (picked == null) return;

      setState(() => _uploading[field.name] = true);
      final service = ref.read(repairServiceProvider);
      final attachment = await service.uploadAttachment(
        _session!,
        field,
        File(picked.path),
      );
      if (!mounted) return;
      setState(() {
        _attachments.putIfAbsent(field.name, () => []).add(
              _AttachedImage(
                attachment: attachment,
                localFilePath: picked.path,
              ),
            );
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e is RepairException
                ? e.message
                : context.l10n.repairsUploadFailed),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _uploading[field.name] = false);
    }
  }

  Future<void> _showImageSourcePicker(RepairField field) async {
    await showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_rounded),
              title: Text(context.l10n.takePhoto),
              onTap: () {
                Navigator.pop(ctx);
                _pickAndUploadImage(field, ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded),
              title: Text(context.l10n.chooseFromGallery),
              onTap: () {
                Navigator.pop(ctx);
                _pickAndUploadImage(field, ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteAttachment(
    RepairField field,
    _AttachedImage image,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.l10n.repairsDeleteImage),
        content: Text(context.l10n.repairsDeleteConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(context.l10n.cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(context.l10n.confirm),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      await ref.read(repairServiceProvider).deleteAttachment(image.attachment.id);
      if (!mounted) return;
      setState(() {
        _attachments[field.name]
            ?.removeWhere((a) => a.attachment.id == image.attachment.id);
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e is RepairException ? e.message : '$e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _previewImage(RepairAttachment attachment, [String? localPath]) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(12),
        child: Stack(
          alignment: Alignment.center,
          children: [
            InteractiveViewer(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: localPath != null
                    ? Image.file(
                        File(localPath),
                        fit: BoxFit.contain,
                      )
                    : AuthenticatedBxptImage(
                        url: attachment.downloadUrl,
                        fit: BoxFit.contain,
                        loadingWidget: const Center(
                            child: CircularProgressIndicator(
                                color: Colors.white)),
                        errorWidget: const Center(
                          child: Icon(Icons.broken_image_rounded,
                              size: 48, color: Colors.white70),
                        ),
                      ),
              ),
            ),
            Positioned(
              top: 0,
              right: 0,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 28),
                onPressed: () => Navigator.pop(ctx),
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool get _isLogistics =>
      widget.catalog.title.contains('后勤') ||
      widget.catalog.id == '5bbbaf0a-b7b7-11eb-b305-4bcc6b2984af' ||
      widget.catalog.department.contains('后勤');

  bool _isFieldRequired(RepairField field) =>
      _isLogistics ? true : field.required;

  InputDecoration _inputDecoration({
    required String hint,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hint,
      suffixIcon: suffixIcon,
    );
  }

  Widget _fieldLabel(String label, bool required, AppSemanticColors colors) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: RichText(
        text: TextSpan(
          style: AppText.bodyDense.copyWith(
            fontWeight: FontWeight.w600,
            color: colors.text,
          ),
          children: [
            if (required)
              TextSpan(
                text: '* ',
                style: TextStyle(color: colors.danger),
              ),
            TextSpan(text: label),
          ],
        ),
      ),
    );
  }

  Future<void> _submit({bool isDraft = false}) async {
    final session = _session!;
    final values = <String, dynamic>{};
    for (final field in session.fields) {
      if (field.hidden) continue;
      if (field.isUpload) {
        final count = _attachments[field.name]?.length ?? 0;
        if (!isDraft &&
            !field.readonly &&
            _isFieldRequired(field) &&
            count == 0) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(context.l10n.repairsRequiredField(field.label)),
              behavior: SnackBarBehavior.floating));
          return;
        }
        values[field.name] = count;
        continue;
      }
      final text = _controllers[field.name]?.text.trim() ?? '';
      if (!isDraft &&
          !field.readonly &&
          _isFieldRequired(field) &&
          text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(context.l10n.repairsRequiredField(field.label)),
            behavior: SnackBarBehavior.floating));
        return;
      }
      if (text.isNotEmpty) {
        if (field.isDate) {
          values[field.name] = RepairService.parseDateToTimestamp(text) ?? text;
        } else {
          values[field.name] = _choices[field.name]?.id ?? text;
        }
      }
    }
    setState(() => _submitting = true);
    try {
      await ref
          .read(repairServiceProvider)
          .submit(session, values, isDraft: isDraft);
      if (!mounted) return;
      if (isDraft) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(context.l10n.repairsSaveDraftSuccess),
            behavior: SnackBarBehavior.floating));
        Navigator.pop(context);
      } else {
        await showDialog(
            context: context,
            builder: (_) => AlertDialog(
                    title: Text(context.l10n.repairsSubmitSuccess),
                    content: Text(context.l10n.repairsSubmitSuccessMessage),
                    actions: [
                      ElevatedButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text(context.l10n.gotIt))
                    ]));
        if (mounted) Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(e is RepairException
                ? e.message
                : context.l10n.loadFailedCheckNetwork),
            behavior: SnackBarBehavior.floating));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Widget _buildBottomBar(AppSemanticColors colors) {
    final onBrand = Theme.of(context).colorScheme.onPrimary;
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.page, vertical: AppSpacing.md),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(
          top: BorderSide(color: colors.border),
        ),
      ),
      child: SafeArea(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(80, 40),
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
              ),
              onPressed: _submitting ? null : () => _submit(isDraft: false),
              child: _submitting
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: onBrand,
                      ),
                    )
                  : Text(context.l10n.submit),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    Widget body;
    if (_loading) {
      body = const Center(child: CircularProgressIndicator());
    } else if (_error != null) {
      body = Center(
          child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xxl),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text(_error!, textAlign: TextAlign.center),
                const SizedBox(height: 14),
                ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _loading = true;
                        _error = null;
                      });
                      _load();
                    },
                    child: Text(context.l10n.retry))
              ])));
    } else {
      body = ListView(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.page, AppSpacing.lg, AppSpacing.page, 24),
        children: [
          ..._session!.fields
              .where((field) => !field.hidden && !field.readonly)
              .map((field) => _buildField(field, colors)),
        ],
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.draftOrder != null
            ? '${widget.catalog.title} · ${context.l10n.repairsDrafts}'
            : widget.catalog.title),
      ),
      body: body,
      bottomNavigationBar:
          _loading || _error != null ? null : _buildBottomBar(colors),
    );
  }

  Widget _buildUploadField(RepairField field, AppSemanticColors colors) {
    final images = _attachments[field.name] ?? [];
    final isUploading = _uploading[field.name] == true;
    final required = _isFieldRequired(field);

    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _fieldLabel('${field.label}${images.isNotEmpty ? ' (${images.length})' : ''}',
              required, colors),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              ...images.map((item) => Stack(
                    clipBehavior: Clip.none,
                    children: [
                      GestureDetector(
                        onTap: () => _previewImage(
                          item.attachment,
                          item.localFilePath,
                        ),
                        child: Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: colors.surfaceSubtle,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: colors.border,
                              width: 1,
                            ),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: item.localFilePath != null
                              ? Image.file(
                                  File(item.localFilePath!),
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Center(
                                    child: Icon(Icons.broken_image_rounded,
                                        size: 26, color: colors.textMuted),
                                  ),
                                )
                              : AuthenticatedBxptImage(
                                  url: item.attachment.thumbnailUrl ??
                                      item.attachment.downloadUrl,
                                  fit: BoxFit.cover,
                                  loadingWidget: const Center(
                                    child: SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2),
                                    ),
                                  ),
                                  errorWidget: Center(
                                    child: Icon(Icons.image_outlined,
                                        size: 26, color: colors.textMuted),
                                  ),
                                ),
                        ),
                      ),
                      Positioned(
                        top: -6,
                        right: -6,
                        child: GestureDetector(
                          onTap: () => _deleteAttachment(field, item),
                          child: Container(
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              color: colors.danger,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.close,
                              size: 13,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  )),
              if (isUploading)
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: colors.surfaceSubtle,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: colors.border,
                      width: 1,
                    ),
                  ),
                  child: const Center(
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                      ),
                    ),
                  ),
                ),
              InkWell(
                onTap: isUploading ? null : () => _showImageSourcePicker(field),
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: colors.surfaceSubtle,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: colors.border,
                      width: 1,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.add_a_photo_outlined,
                        size: 22,
                        color: colors.textMuted,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        context.l10n.repairsUploadImage,
                        style: AppText.caption
                            .copyWith(fontSize: 11, color: colors.textMuted),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildField(RepairField field, AppSemanticColors colors) {
    if (field.isUpload) {
      return _buildUploadField(field, colors);
    }
    final controller = _controllers[field.name]!;
    final required = _isFieldRequired(field);
    if (field.isDate) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _fieldLabel(field.label, required, colors),
            InkWell(
              onTap: () => _pickDate(field),
              borderRadius: BorderRadius.circular(4),
              child: InputDecorator(
                decoration: _inputDecoration(
                  hint: context.l10n.repairsSelectValue,
                  suffixIcon: const Icon(
                    Icons.calendar_today_outlined,
                    size: 20,
                  ),
                ),
                child: Text(
                  controller.text.isEmpty
                      ? context.l10n.repairsSelectValue
                      : controller.text,
                  style: AppText.bodyDense.copyWith(color: colors.text),
                ),
              ),
            ),
          ],
        ),
      );
    }
    if (field.isChoice) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _fieldLabel(field.label, required, colors),
            InkWell(
              onTap: () => _choose(field),
              borderRadius: BorderRadius.circular(4),
              child: InputDecorator(
                decoration: _inputDecoration(
                  hint: context.l10n.repairsSelectValue,
                  suffixIcon: const Icon(
                    Icons.expand_more_rounded,
                    size: 22,
                  ),
                ),
                child: Text(
                  controller.text.isEmpty
                      ? context.l10n.repairsSelectValue
                      : controller.text,
                  style: AppText.bodyDense.copyWith(color: colors.text),
                ),
              ),
            ),
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _fieldLabel(field.label, required, colors),
          TextField(
            controller: controller,
            minLines: field.isMultiline ? 4 : 1,
            maxLines: field.isMultiline ? 7 : 1,
            textInputAction:
                field.isMultiline ? TextInputAction.newline : TextInputAction.next,
            style: AppText.bodyDense.copyWith(color: colors.text),
          ),
        ],
      ),
    );
  }
}
