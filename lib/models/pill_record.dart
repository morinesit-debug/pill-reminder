class PillRecord {
  final int? id;
  final int pillId;
  final DateTime scheduledDate;
  final DateTime? takenDate;
  final bool isTaken;
  final bool isSkipped;

  PillRecord({
    this.id,
    required this.pillId,
    required this.scheduledDate,
    this.takenDate,
    this.isTaken = false,
    this.isSkipped = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'pillId': pillId,
      'scheduledDate': scheduledDate.millisecondsSinceEpoch,
      'takenDate': takenDate?.millisecondsSinceEpoch,
      'isTaken': isTaken ? 1 : 0,
      'isSkipped': isSkipped ? 1 : 0,
    };
  }

  factory PillRecord.fromMap(Map<String, dynamic> map) {
    return PillRecord(
      id: map['id'],
      pillId: map['pillId'],
      scheduledDate: DateTime.fromMillisecondsSinceEpoch(map['scheduledDate']),
      takenDate: map['takenDate'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['takenDate'])
          : null,
      isTaken: map['isTaken'] == 1,
      isSkipped: map['isSkipped'] == 1,
    );
  }

  PillRecord copyWith({
    int? id,
    int? pillId,
    DateTime? scheduledDate,
    DateTime? takenDate,
    bool? isTaken,
    bool? isSkipped,
  }) {
    return PillRecord(
      id: id ?? this.id,
      pillId: pillId ?? this.pillId,
      scheduledDate: scheduledDate ?? this.scheduledDate,
      takenDate: takenDate ?? this.takenDate,
      isTaken: isTaken ?? this.isTaken,
      isSkipped: isSkipped ?? this.isSkipped,
    );
  }
}
