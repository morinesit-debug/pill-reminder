import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/pill_provider.dart';
import '../models/pill.dart';
import '../screens/add_pill_screen.dart';

class TodayPillsWidget extends StatelessWidget {
  const TodayPillsWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<PillProvider>(
      builder: (context, pillProvider, child) {
        final todayPills = pillProvider.getTodayPills();

        if (pillProvider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (todayPills.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle_outline, size: 64, color: Colors.green),
                SizedBox(height: 16),
                Text(
                  '오늘 복용할 알약이 없습니다!',
                  style: TextStyle(fontSize: 18, color: Colors.grey),
                ),
                SizedBox(height: 8),
                Text(
                  '모든 알약을 복용했거나\n오늘은 복용일이 아닙니다.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: Colors.grey),
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
                '오늘 복용할 알약 (${todayPills.length}개)',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              ...todayPills.map(
                (pill) => _buildPillCard(context, pill, pillProvider),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPillCard(
    BuildContext context,
    Pill pill,
    PillProvider pillProvider,
  ) {
    final isTaken = pillProvider.isPillTakenToday(pill.id ?? 0);
    final takenTime = pillProvider.getPillTakenTimeToday(pill.id ?? 0);

    return Card(
      margin: const EdgeInsets.only(bottom: 12.0),
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
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (isTaken && takenTime != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          '복용 시간: ${_formatTime(takenTime)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.green[600],
                            fontWeight: FontWeight.w500,
                          ),
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
                      size: 24,
                    ),
                    onPressed: () {
                      if (isTaken) {
                        pillProvider.untakePill(pill.id ?? 0, DateTime.now());
                      } else {
                        pillProvider.takePill(pill.id ?? 0, DateTime.now());
                      }
                    },
                  ),
                ),
                const SizedBox(width: 8),
                // 점점점 메뉴
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: Colors.grey),
                  onSelected: (value) {
                    if (value == 'edit') {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => AddPillScreen(pill: pill),
                        ),
                      );
                    } else if (value == 'delete') {
                      _showDeleteDialog(context, pill, pillProvider);
                    }
                  },
                  itemBuilder: (BuildContext context) => [
                    const PopupMenuItem<String>(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit, size: 20),
                          SizedBox(width: 8),
                          Text('수정'),
                        ],
                      ),
                    ),
                    const PopupMenuItem<String>(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete, size: 20, color: Colors.red),
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

  void _showDeleteDialog(
    BuildContext context,
    Pill pill,
    PillProvider pillProvider,
  ) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('알약 삭제'),
          content: Text('${pill.name}을(를) 정말 삭제하시겠습니까?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () {
                pillProvider.deletePill(pill.id ?? 0);
                Navigator.of(context).pop();
              },
              child: const Text('삭제', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
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

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }
}
