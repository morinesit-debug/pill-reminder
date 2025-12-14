import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import '../providers/pill_provider.dart';
import '../models/pill.dart';
import '../models/pill_record.dart';
import '../screens/add_pill_screen.dart';

class CalendarWidget extends StatefulWidget {
  const CalendarWidget({super.key});

  @override
  State<CalendarWidget> createState() => _CalendarWidgetState();
}

class _CalendarWidgetState extends State<CalendarWidget> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<PillProvider>(
      builder: (context, pillProvider, child) {
        return Column(
          children: [
            // 캘린더 영역 - 고정 크기
            Container(
              height: 400, // 캘린더 높이 고정
              child: TableCalendar(
                firstDay: DateTime.utc(2020, 1, 1),
                lastDay: DateTime.utc(2030, 12, 31),
                focusedDay: _focusedDay,
                selectedDayPredicate: (day) {
                  return isSameDay(_selectedDay, day);
                },
                onDaySelected: (selectedDay, focusedDay) {
                  setState(() {
                    _selectedDay = selectedDay;
                    _focusedDay = focusedDay;
                  });
                  pillProvider.setSelectedDate(selectedDay);
                },
                onPageChanged: (focusedDay) {
                  _focusedDay = focusedDay;
                },
                calendarFormat: CalendarFormat.month,
                eventLoader: (day) {
                  final pills = pillProvider.getPillsForDate(day);
                  return pills;
                },
                calendarStyle: const CalendarStyle(
                  outsideDaysVisible: false,
                  weekendTextStyle: TextStyle(color: Colors.red),
                  holidayTextStyle: TextStyle(color: Colors.red),
                ),
                headerStyle: const HeaderStyle(
                  formatButtonVisible: false,
                  titleCentered: true,
                ),
              ),
            ),
            const Divider(),
            // 선택된 날짜의 알약 목록 - 남은 공간 사용
            Expanded(child: _buildSelectedDayPills(pillProvider)),
          ],
        );
      },
    );
  }

  Widget _buildSelectedDayPills(PillProvider pillProvider) {
    if (_selectedDay == null) return const SizedBox.shrink();

    final selectedDate = _selectedDay!;
    final pills = pillProvider.getPillsForDate(selectedDate);
    final pillStatus = pillProvider.getPillStatusForDate(selectedDate);

    if (pills.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event_busy, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              '${_formatDate(selectedDate)}에는\n복용할 알약이 없습니다.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _formatDate(selectedDate),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          ...pills.map(
            (pill) => _buildPillCard(pill, pillStatus[pill.id ?? 0] ?? false),
          ),
        ],
      ),
    );
  }

  Widget _buildPillCard(Pill pill, bool isTaken) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        pill.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (isTaken) ...[
                        const SizedBox(height: 4),
                        Consumer<PillProvider>(
                          builder: (context, pillProvider, child) {
                            final takenTime = pillProvider
                                .getPillTakenTimeForDate(
                                  pill.id ?? 0,
                                  _selectedDay!,
                                );
                            if (takenTime != null) {
                              return Text(
                                '복용 시간: ${_formatTime(takenTime)}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.green[600],
                                  fontWeight: FontWeight.w500,
                                ),
                              );
                            }
                            return const SizedBox.shrink();
                          },
                        ),
                      ],
                    ],
                  ),
                ),
                // 초록색 복용 버튼
                Container(
                  decoration: BoxDecoration(
                    color: isTaken ? Colors.green : Colors.grey[300],
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: IconButton(
                    icon: Icon(
                      isTaken ? Icons.check : Icons.medication,
                      color: isTaken ? Colors.white : Colors.grey[600],
                      size: 20,
                    ),
                    onPressed: () {
                      if (isTaken) {
                        _untakePillOnDate(pill.id ?? 0);
                      } else {
                        _takePillOnDate(pill.id ?? 0);
                      }
                    },
                  ),
                ),
                const SizedBox(width: 8),
                // 점점점 메뉴
                PopupMenuButton<String>(
                  icon: const Icon(
                    Icons.more_vert,
                    color: Colors.grey,
                    size: 20,
                  ),
                  onSelected: (value) {
                    if (value == 'edit') {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => AddPillScreen(pill: pill),
                        ),
                      );
                    } else if (value == 'delete') {
                      _showDeleteDialog(pill);
                    }
                  },
                  itemBuilder: (BuildContext context) => [
                    const PopupMenuItem<String>(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit, size: 18),
                          SizedBox(width: 8),
                          Text('수정'),
                        ],
                      ),
                    ),
                    const PopupMenuItem<String>(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete, size: 18, color: Colors.red),
                          SizedBox(width: 8),
                          Text('삭제', style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '복용 빈도: ${_getFrequencyText(pill.frequency, pill.customDays)}',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
            if (pill.alarmTimes.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                '알람 시간: ${pill.alarmTimes.join(', ')}',
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final targetDate = DateTime(date.year, date.month, date.day);

    if (targetDate.isAtSameMomentAs(today)) {
      return '오늘 (${date.month}월 ${date.day}일)';
    } else if (targetDate.isAtSameMomentAs(
      today.add(const Duration(days: 1)),
    )) {
      return '내일 (${date.month}월 ${date.day}일)';
    } else if (targetDate.isAtSameMomentAs(
      today.subtract(const Duration(days: 1)),
    )) {
      return '어제 (${date.month}월 ${date.day}일)';
    } else {
      final weekdays = ['월', '화', '수', '목', '금', '토', '일'];
      final weekday = weekdays[date.weekday - 1];
      return '${date.month}월 ${date.day}일 ($weekday)';
    }
  }

  String _formatDateTime(DateTime date) {
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  String _formatTime(DateTime date) {
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$hour:${minute}';
  }

  String _getFrequencyText(String frequency, int? customDays) {
    switch (frequency) {
      case 'daily':
        return '매일';
      case 'weekly':
        return '매주';
      case 'monthly':
        return '매월';
      case 'custom':
        return '${customDays}일마다';
      default:
        return '알 수 없음';
    }
  }

  void _takePillOnDate(int pillId) {
    if (_selectedDay == null) return;
    final pillProvider = Provider.of<PillProvider>(context, listen: false);
    pillProvider.takePill(pillId, _selectedDay!);
  }

  void _untakePillOnDate(int pillId) {
    if (_selectedDay == null) return;
    final pillProvider = Provider.of<PillProvider>(context, listen: false);
    pillProvider.untakePill(pillId, _selectedDay!);
  }

  void _showDeleteDialog(Pill pill) {
    final pillProvider = Provider.of<PillProvider>(context, listen: false);
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('알약 삭제'),
          content: Text('${pill.name} 알약을 삭제하시겠습니까?'),
          actions: <Widget>[
            TextButton(
              child: const Text('취소'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('삭제'),
              onPressed: () {
                pillProvider.deletePill(pill.id ?? 0);
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }
}
