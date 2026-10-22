import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/l10n_extension.dart';
import '../models/classroom_model.dart';
import '../services/classroom_service.dart';
import '../../../core/theme/app_tokens.dart';

final classroomServiceProvider = Provider((ref) => ClassroomService());

class ClassroomInquiryScreen extends ConsumerStatefulWidget {
  const ClassroomInquiryScreen({super.key});

  @override
  ConsumerState<ClassroomInquiryScreen> createState() => _ClassroomInquiryScreenState();
}

class _ClassroomInquiryScreenState extends ConsumerState<ClassroomInquiryScreen> {
  ClassroomInquiryOptions? _options;
  bool _loadingOptions = true;
  bool _searching = false;
  List<ClassroomModel> _classrooms = [];
  
  String? _selectedBuilding;
  String? _selectedWeek;
  String? _selectedSection;
  String? _selectedDay;

  @override
  void initState() {
    super.initState();
    _loadOptions();
  }

  Future<void> _loadOptions() async {
    try {
      final options = await ref.read(classroomServiceProvider).fetchOptions();
      if (mounted) {
        setState(() {
          _options = options;
          _loadingOptions = false;
          
          if (options.buildings.isNotEmpty) _selectedBuilding = options.buildings.first;
          if (options.weeks.isNotEmpty) _selectedWeek = options.weeks.first;
          if (options.sections.isNotEmpty) _selectedSection = options.sections.first;
          if (options.days.isNotEmpty) _selectedDay = options.days.first['value'];
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loadingOptions = false);
      }
    }
  }

  Future<void> _search() async {
    if (_selectedBuilding == null || _selectedWeek == null || _selectedSection == null || _selectedDay == null) {
      return;
    }

    setState(() => _searching = true);
    try {
      final results = await ref.read(classroomServiceProvider).queryClassrooms(
        building: _selectedBuilding!,
        week: _selectedWeek!,
        jc: _selectedSection!,
        day: _selectedDay!,
      );
      if (mounted) {
        setState(() {
          _classrooms = results;
          _searching = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _searching = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.classroomInquiry),
      ),
      body: _loadingOptions
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildSearchPanel(),
                Expanded(
                  child: _searching
                      ? const Center(child: CircularProgressIndicator())
                      : _buildResultList(),
                ),
              ],
            ),
    );
  }

  Widget _buildSearchPanel() {
    if (_options == null) return const SizedBox();

    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.page, vertical: AppSpacing.sm),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: _buildPlainDropdown(context.l10n.building, _options!.buildings, _selectedBuilding, (val) => setState(() => _selectedBuilding = val))),
              const SizedBox(width: AppSpacing.md),
              Expanded(child: _buildPlainDropdown(context.l10n.weeksLabel, _options!.weeks, _selectedWeek, (val) => setState(() => _selectedWeek = val))),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(child: _buildPlainDropdown(context.l10n.periodSlot, _options!.sections, _selectedSection, (val) => setState(() => _selectedSection = val))),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: _buildPlainDropdown(
                  context.l10n.weekday,
                  _options!.days.map((e) => e['label']!).toList(),
                  _options!.days.firstWhere((e) => e['value'] == _selectedDay, orElse: () => _options!.days.first)['label'],
                  (label) {
                    final val = _options!.days.firstWhere((e) => e['label'] == label)['value'];
                    setState(() => _selectedDay = val);
                  }
                )
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Align(
            alignment: Alignment.centerRight,
            child: SizedBox(
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _search,
                icon: const Icon(Icons.search, size: 18),
                label: Text(context.l10n.query),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlainDropdown(String label, List<String> items, String? current, Function(String?) onChanged) {
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: AppText.caption.copyWith(color: colors.textMuted)),
        const SizedBox(height: AppSpacing.xs),
        Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          decoration: BoxDecoration(
            color: colors.surface,
            border: Border.all(color: colors.border),
            borderRadius: AppRadius.controlAll,
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: current,
              isExpanded: true,
              dropdownColor: colors.surface,
              style: AppText.bodyDense.copyWith(color: colors.text),
              icon: Icon(Icons.keyboard_arrow_down,
                  size: 20, color: colors.textMuted),
              items: items
                  .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                  .toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildResultList() {
    final colors = context.colors;
    if (_classrooms.isEmpty) {
      if (!_searching && _options != null) {
        return Center(
          child: Text(context.l10n.noData,
              style: AppText.bodyDense.copyWith(color: colors.textMuted)),
        );
      }
      return const SizedBox();
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.page, vertical: AppSpacing.sm),
      itemCount: _classrooms.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
      itemBuilder: (context, index) {
        final room = _classrooms[index];
        return Container(
          padding: const EdgeInsets.all(AppSpacing.card),
          decoration: BoxDecoration(
            color: colors.surface,
            border: Border.all(color: colors.border),
            borderRadius: AppRadius.cardAll,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                room.jsmc,
                style: AppText.sectionTitle.copyWith(color: colors.text),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                context.l10n.capacityCount(room.zws),
                style: AppText.bodyDense.copyWith(color: colors.textMuted),
              ),
            ],
          ),
        );
      },
    );
  }
}
