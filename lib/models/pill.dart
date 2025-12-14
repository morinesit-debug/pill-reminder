class Pill {
  final int? id;
  final String name;
  final String frequency; // 'daily', 'weekly', 'monthly', 'custom'
  final DateTime startDate;
  final int? customDays; // custom 주기일 때 사용
  final bool isActive;
  final DateTime createdAt;
  final List<String> alarmTimes; // 알람 시간들 (HH:mm 형식)

  Pill({
    this.id,
    required this.name,
    required this.frequency,
    required this.startDate,
    this.customDays,
    this.isActive = true,
    DateTime? createdAt,
    List<String>? alarmTimes,
  }) : createdAt = createdAt ?? DateTime.now(),
       alarmTimes = alarmTimes ?? ['09:00']; // 기본값: 오전 9시

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'frequency': frequency,
      'startDate': startDate.millisecondsSinceEpoch,
      'customDays': customDays,
      'isActive': isActive ? 1 : 0,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'alarmTimes': alarmTimes.join(','), // 쉼표로 구분하여 저장
    };
  }

  factory Pill.fromMap(Map<String, dynamic> map) {
    return Pill(
      id: map['id'],
      name: map['name'],
      frequency: map['frequency'],
      startDate: DateTime.fromMillisecondsSinceEpoch(map['startDate']),
      customDays: map['customDays'],
      isActive: map['isActive'] == 1,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt']),
      alarmTimes: map['alarmTimes'] != null
          ? map['alarmTimes'].toString().split(',')
          : ['09:00'],
    );
  }

  Pill copyWith({
    int? id,
    String? name,
    String? frequency,
    DateTime? startDate,
    int? customDays,
    bool? isActive,
    DateTime? createdAt,
    List<String>? alarmTimes,
  }) {
    return Pill(
      id: id ?? this.id,
      name: name ?? this.name,
      frequency: frequency ?? this.frequency,
      startDate: startDate ?? this.startDate,
      customDays: customDays ?? this.customDays,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      alarmTimes: alarmTimes ?? this.alarmTimes,
    );
  }
}
