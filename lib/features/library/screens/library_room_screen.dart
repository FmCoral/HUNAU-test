import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/l10n_extension.dart';
import '../../../core/utils/route_utils.dart';
import '../models/library_models.dart';
import '../providers/library_provider.dart';
import '../utils/library_time_utils.dart';
import '../widgets/library_time_range_picker.dart';
import 'library_seat_screen.dart';
import 'library_quick_reserve_screen.dart';

class LibraryRoomScreen extends ConsumerStatefulWidget {
  const LibraryRoomScreen({super.key});

  @override
  ConsumerState<LibraryRoomScreen> createState() => _LibraryRoomScreenState();
}

class _LibraryRoomScreenState extends ConsumerState<LibraryRoomScreen> {
  late String _selectedDay;
  late List<String> _availableDays;
  String? _selectedFloor; // null means 'all'
  String? _selectedStartTime;
  String? _selectedEndTime;

  @override
  void initState() {
    super.initState();
    _initDays();
  }

  void _initDays() {
    _availableDays = LibraryTimeUtils.availableReserveDays();
    _selectedDay = _availableDays.first;
  }

  String _formatDayTab(String dayStr) {
    return LibraryTimeUtils.formatDayLabelLocalized(context, dayStr);
  }

  @override
  Widget build(BuildContext context) {
    final roomsAsync = ref.watch(libraryRoomsProvider(_selectedDay));
    final colors = context.colors;

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.selectReadingRoom),
        actions: [
          IconButton(
            icon: const Icon(Icons.bolt_rounded),
            tooltip: context.l10n.quickReserve,
            onPressed: () {
              Navigator.push(
                context,
                createSlideUpRoute(const LibraryQuickReserveScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: context.l10n.refresh,
            onPressed: () {
              setState(() {
                _availableDays = LibraryTimeUtils.availableReserveDays();
                if (!_availableDays.contains(_selectedDay)) {
                  _selectedDay = _availableDays.first;
                  _selectedStartTime = null;
                  _selectedEndTime = null;
                }
              });
              ref.invalidate(libraryRoomsProvider(_selectedDay));
            },
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. 日期选择栏
          Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.page, vertical: AppSpacing.sm),
            child: Align(
              alignment: Alignment.centerLeft,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _availableDays.map((day) {
                    final isSelected = day == _selectedDay;
                    return Padding(
                      padding: const EdgeInsets.only(right: AppSpacing.sm),
                      child: ChoiceChip(
                        label: Text(_formatDayTab(day)),
                        selected: isSelected,
                        selectedColor: colors.statusBg(colors.brand),
                        labelStyle: AppText.caption.copyWith(
                          color:
                              isSelected ? colors.brandText : colors.text,
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.w400,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: AppRadius.controlAll,
                          side: BorderSide(
                            color:
                                isSelected ? colors.brand : colors.border,
                          ),
                        ),
                        onSelected: (selected) {
                          if (selected && _selectedDay != day) {
                            setState(() {
                              _selectedDay = day;
                              _selectedStartTime = null;
                              _selectedEndTime = null;
                            });
                          }
                        },
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ),

          // 2. 阅览室列表
          Expanded(
            child: roomsAsync.when(
              data: (rooms) => _buildRoomList(rooms),
              loading: () => const Center(
                child: CircularProgressIndicator(),
              ),
              error: (err, stack) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline,
                        size: 48, color: colors.danger),
                    const SizedBox(height: AppSpacing.md),
                    Text(err.toString().replaceAll('Exception:', '').trim()),
                    const SizedBox(height: AppSpacing.md),
                    ElevatedButton(
                      onPressed: () =>
                          ref.invalidate(libraryRoomsProvider(_selectedDay)),
                      child: Text(context.l10n.retry),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoomList(List<LibraryRoomModel> rooms) {
    final colors = context.colors;

    // 提取全部楼层
    final rawFloors = <String>{};
    for (final r in rooms) {
      if (r.secondLevelName.isNotEmpty) {
        rawFloors.add(r.secondLevelName);
      }
    }

    // 过滤列表
    final filtered = rooms.where((r) {
      if (_selectedFloor != null && r.secondLevelName != _selectedFloor) {
        return false;
      }
      return true;
    }).toList();

    final allFloorItems = [null, ...rawFloors];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 楼层快捷过滤
        if (rawFloors.length > 1)
          Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.page, vertical: 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: allFloorItems.map((floor) {
                    final isSelected = floor == _selectedFloor;
                    final label = floor ?? context.l10n.all;
                    return Padding(
                      padding: const EdgeInsets.only(right: AppSpacing.sm),
                      child: FilterChip(
                        label: Text(label),
                        selected: isSelected,
                        selectedColor: colors.statusBg(colors.brand),
                        labelStyle: AppText.caption.copyWith(
                          color:
                              isSelected ? colors.brandText : colors.text,
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.w400,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: AppRadius.controlAll,
                          side: BorderSide(
                            color:
                                isSelected ? colors.brand : colors.border,
                          ),
                        ),
                        onSelected: (selected) {
                          setState(() {
                            _selectedFloor = selected ? floor : null;
                          });
                        },
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ),

        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Text(
                    context.l10n.noRoomsFound,
                    style: AppText.bodyDense.copyWith(color: colors.textMuted),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(AppSpacing.page),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final room = filtered[index];
                    return _buildRoomCard(room);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildRoomCard(LibraryRoomModel room) {
    final colors = context.colors;

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
          onTap: () async {
            final result = await showLibraryTimeRangePicker(
              context: context,
              day: _selectedDay,
              initialStartTime: _selectedStartTime,
              initialEndTime: _selectedEndTime,
            );
            if (!mounted || result == null) return;

            setState(() {
              _selectedStartTime = result.startTime;
              _selectedEndTime = result.endTime;
            });

            Navigator.push(
              context,
              createSlideUpRoute(LibrarySeatScreen(
                room: room,
                day: _selectedDay,
                initialStartTime: result.startTime,
                initialEndTime: result.endTime,
              )),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.card),
            child: Row(
              children: [
                // 楼层图标装饰
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: colors.statusBg(colors.brand),
                    borderRadius: AppRadius.controlAll,
                  ),
                  child: Icon(
                    Icons.meeting_room_rounded,
                    color: colors.brand,
                    size: 22,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),

                // 阅览室详细信息
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              room.displayName,
                              style: AppText.sectionTitle.copyWith(
                                color: colors.text,
                                fontSize: 15,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: colors.statusBg(colors.info),
                              borderRadius:
                                  BorderRadius.circular(AppRadius.pill),
                            ),
                            child: Text(
                              room.floorName,
                              style: AppText.caption.copyWith(
                                fontSize: 11,
                                color: colors.info,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          Icon(
                            Icons.event_seat_outlined,
                            size: 13,
                            color: colors.textMuted,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            context.l10n.totalSeats(room.capacity.toString()),
                            style: AppText.caption
                                .copyWith(color: colors.textMuted),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Icon(
                            Icons.schedule_rounded,
                            size: 13,
                            color: colors.textMuted,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '07:00 - 22:00',
                            style: AppText.caption
                                .copyWith(color: colors.textMuted),
                          ),
                        ],
                      ),
                    ],
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
          ),
        ),
      ),
    );
  }
}
