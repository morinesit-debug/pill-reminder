import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/pill.dart';
import '../providers/pill_provider.dart';

class AddPillScreen extends StatefulWidget {
  final Pill? pill; // 수정 시 사용

  const AddPillScreen({super.key, this.pill});

  @override
  State<AddPillScreen> createState() => _AddPillScreenState();
}

class _AddPillScreenState extends State<AddPillScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  String _selectedFrequency = 'daily';
  DateTime _selectedDate = DateTime.now();
  int? _customDays;
  bool _isActive = true;
  List<String> _alarmTimes = ['09:00']; // 기본 알람 시간

  @override
  void initState() {
    super.initState();
    if (widget.pill != null) {
      // 수정 모드
      _nameController.text = widget.pill!.name;
      _selectedFrequency = widget.pill!.frequency;
      _selectedDate = widget.pill!.startDate;
      _customDays = widget.pill!.customDays;
      _isActive = widget.pill!.isActive;
      _alarmTimes = List.from(widget.pill!.alarmTimes);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.pill != null ? '알약 수정' : '알약 추가'),
        backgroundColor: Colors.blue[600],
        foregroundColor: Colors.white,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            // 알약 이름
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: '알약 이름',
                hintText: '예: 심장병 약, 관절염 약',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.medication),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return '알약 이름을 입력해주세요';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),

            // 복용 주기
            Text('복용 주기', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            _buildFrequencySelector(),
            const SizedBox(height: 24),

            // 시작일
            Text('시작일', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            _buildDateSelector(),
            const SizedBox(height: 24),

            // 알람 시간
            Text('알람 시간', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            _buildAlarmTimesSelector(),
            const SizedBox(height: 24),

            // 활성화 여부
            SwitchListTile(
              title: const Text('알약 활성화'),
              subtitle: const Text('비활성화하면 알림이 발송되지 않습니다'),
              value: _isActive,
              onChanged: (value) {
                setState(() {
                  _isActive = value;
                });
              },
              activeColor: Colors.blue[600],
            ),
            const SizedBox(height: 32),

            // 저장 버튼
            ElevatedButton(
              onPressed: _savePill,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue[600],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                widget.pill != null ? '수정하기' : '추가하기',
                style: const TextStyle(fontSize: 18),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFrequencySelector() {
    return Column(
      children: [
        RadioListTile<String>(
          title: const Text('매일'),
          value: 'daily',
          groupValue: _selectedFrequency,
          onChanged: (value) {
            setState(() {
              _selectedFrequency = value!;
              _customDays = null;
            });
          },
        ),
        RadioListTile<String>(
          title: const Text('매주'),
          value: 'weekly',
          groupValue: _selectedFrequency,
          onChanged: (value) {
            setState(() {
              _selectedFrequency = value!;
              _customDays = null;
            });
          },
        ),
        RadioListTile<String>(
          title: const Text('매월'),
          value: 'monthly',
          groupValue: _selectedFrequency,
          onChanged: (value) {
            setState(() {
              _selectedFrequency = value!;
              _customDays = null;
            });
          },
        ),
        RadioListTile<String>(
          title: const Text('커스텀'),
          value: 'custom',
          groupValue: _selectedFrequency,
          onChanged: (value) {
            setState(() {
              _selectedFrequency = value!;
            });
          },
        ),
        if (_selectedFrequency == 'custom') ...[
          const SizedBox(height: 8),
          TextFormField(
            initialValue: _customDays?.toString() ?? '',
            decoration: const InputDecoration(
              labelText: '일수',
              hintText: '예: 3 (3일마다)',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.schedule),
            ),
            keyboardType: TextInputType.number,
            validator: (value) {
              if (_selectedFrequency == 'custom') {
                if (value == null || value.isEmpty) {
                  return '일수를 입력해주세요';
                }
                final days = int.tryParse(value);
                if (days == null || days < 1) {
                  return '1 이상의 숫자를 입력해주세요';
                }
              }
              return null;
            },
            onChanged: (value) {
              _customDays = int.tryParse(value);
            },
          ),
        ],
      ],
    );
  }

  Widget _buildDateSelector() {
    return InkWell(
      onTap: () async {
        final date = await showDatePicker(
          context: context,
          initialDate: _selectedDate,
          firstDate: DateTime(2020),
          lastDate: DateTime(2030),
        );
        if (date != null) {
          setState(() {
            _selectedDate = date;
          });
        }
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today),
            const SizedBox(width: 12),
            Text(
              '${_selectedDate.year}년 ${_selectedDate.month}월 ${_selectedDate.day}일',
              style: const TextStyle(fontSize: 16),
            ),
            const Spacer(),
            const Icon(Icons.arrow_drop_down),
          ],
        ),
      ),
    );
  }

  Widget _buildAlarmTimesSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ..._alarmTimes.asMap().entries.map((entry) {
          final index = entry.key;
          final time = entry.value;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () async {
                      final timeOfDay = _parseTimeString(time);
                      final newTime = await showTimePicker(
                        context: context,
                        initialTime: timeOfDay,
                      );
                      if (newTime != null) {
                        setState(() {
                          _alarmTimes[index] =
                              '${newTime.hour.toString().padLeft(2, '0')}:${newTime.minute.toString().padLeft(2, '0')}';
                        });
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.access_time),
                          const SizedBox(width: 12),
                          Text(time, style: const TextStyle(fontSize: 16)),
                          const Spacer(),
                          const Icon(Icons.arrow_drop_down),
                        ],
                      ),
                    ),
                  ),
                ),
                if (_alarmTimes.length > 1) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () {
                      setState(() {
                        _alarmTimes.removeAt(index);
                      });
                    },
                    icon: const Icon(Icons.delete, color: Colors.red),
                    tooltip: '알람 시간 삭제',
                  ),
                ],
              ],
            ),
          );
        }).toList(),
        const SizedBox(height: 8),
        Center(
          child: OutlinedButton.icon(
            onPressed: () {
              setState(() {
                _alarmTimes.add('09:00');
              });
            },
            icon: const Icon(Icons.add),
            label: const Text('알람 시간 추가'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.blue[600],
              side: BorderSide(color: Colors.blue[600]!),
            ),
          ),
        ),
      ],
    );
  }

  TimeOfDay _parseTimeString(String timeString) {
    final parts = timeString.split(':');
    final hour = int.parse(parts[0]);
    final minute = int.parse(parts[1]);
    return TimeOfDay(hour: hour, minute: minute);
  }

  void _savePill() async {
    if (!_formKey.currentState!.validate()) return;

    final pill = Pill(
      id: widget.pill?.id,
      name: _nameController.text.trim(),
      frequency: _selectedFrequency,
      startDate: _selectedDate,
      customDays: _customDays,
      isActive: _isActive,
      alarmTimes: _alarmTimes,
    );

    final pillProvider = context.read<PillProvider>();
    bool success;

    if (widget.pill != null) {
      success = await pillProvider.updatePill(pill);
    } else {
      success = await pillProvider.addPill(pill);
    }

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.pill != null ? '알약이 수정되었습니다.' : '알약이 추가되었습니다.'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('저장에 실패했습니다. 다시 시도해주세요.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
