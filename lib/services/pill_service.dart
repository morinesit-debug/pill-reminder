import '../models/pill.dart';
import '../models/pill_record.dart';
import 'database_helper.dart';
import 'notification_service.dart';

class PillService {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final NotificationService _notificationService = NotificationService();

  // 알약 추가
  Future<int> addPill(Pill pill) async {
    try {
      final id = await _dbHelper.insertPill(pill);
      if (id > 0) {
        // 알약 추가 후 알림 스케줄링
        await _notificationService.scheduleAllPillNotifications([pill]);
      }
      return id;
    } catch (e) {
      return -1;
    }
  }

  // 알약 수정
  Future<int> updatePill(Pill pill) async {
    try {
      final result = await _dbHelper.updatePill(pill);
      if (result > 0) {
        // 알약 수정 후 알림 재스케줄링
        await _notificationService.scheduleAllPillNotifications([pill]);
      }
      return result;
    } catch (e) {
      return -1;
    }
  }

  // 알약 삭제
  Future<int> deletePill(int id) async {
    try {
      // 알약 삭제 전 알림 취소
      await _notificationService.cancelPillNotification(id);
      return await _dbHelper.deletePill(id);
    } catch (e) {
      return -1;
    }
  }

  // 모든 알약 조회
  Future<List<Pill>> getAllPills() async {
    return await _dbHelper.getAllPills();
  }

  // 특정 알약 조회
  Future<Pill?> getPill(int id) async {
    return await _dbHelper.getPill(id);
  }

  // 알약의 복용 기록 생성
  Future<void> _generatePillRecords(Pill pill) async {
    if (pill.id == null) return;

    final now = DateTime.now();
    final nowOnly = DateTime(now.year, now.month, now.day);
    final startDateOnly = DateTime(
      pill.startDate.year,
      pill.startDate.month,
      pill.startDate.day,
    );

    DateTime recordGenerationStartDate;

    if (startDateOnly.isBefore(nowOnly)) {
      recordGenerationStartDate = nowOnly;
    } else {
      recordGenerationStartDate = startDateOnly;
    }

    // 다음 90일간의 복용 기록 생성
    for (int i = 0; i < 90; i++) {
      final scheduledDate = recordGenerationStartDate.add(Duration(days: i));

      // 복용 주기에 따라 기록 생성
      if (_shouldTakePillOnDate(pill, scheduledDate)) {
        final record = PillRecord(
          pillId: pill.id!,
          scheduledDate: scheduledDate,
        );
        await _dbHelper.insertPillRecord(record);
      }
    }

    // 알림 스케줄링
    await _notificationService.scheduleAllPillNotifications([pill]);
  }

  // 복용 기록 재생성 (알약 수정 시)
  Future<void> _regeneratePillRecords(Pill pill) async {
    try {
      // 기존 복용 기록 삭제
      final existingRecords = await _dbHelper.getPillRecords(pill.id!);
      for (final record in existingRecords) {
        await _dbHelper.deletePillRecord(record.id!);
      }

      // 새로운 복용 기록 생성
      await _generatePillRecords(pill);
    } catch (e) {
      // 복용 기록 재생성 실패는 무시
    }
  }

  // 특정 날짜에 복용해야 하는지 확인
  bool _shouldTakePillOnDate(Pill pill, DateTime date) {
    final dateOnly = DateTime(date.year, date.month, date.day);
    final startDateOnly = DateTime(
      pill.startDate.year,
      pill.startDate.month,
      pill.startDate.day,
    );

    final daysSinceStart = dateOnly.difference(startDateOnly).inDays;

    // If the scheduled date is before the pill's start date, it should not be taken.
    if (daysSinceStart < 0) {
      return false;
    }

    bool shouldTake = false;

    switch (pill.frequency) {
      case 'daily':
        shouldTake = true;
        break;
      case 'weekly':
        shouldTake = daysSinceStart % 7 == 0;
        break;
      case 'monthly':
        shouldTake = dateOnly.day == startDateOnly.day;
        break;
      case 'custom':
        if (pill.customDays != null && pill.customDays! > 0) {
          shouldTake = daysSinceStart % pill.customDays! == 0;
        } else {
          shouldTake = false;
        }
        break;
      default:
        shouldTake = false;
    }

    return shouldTake;
  }

  // 복용 체크
  Future<int> markPillAsTaken(int pillId, DateTime date) async {
    final records = await _dbHelper.getPillRecords(pillId);
    final targetRecord = records.firstWhere(
      (record) =>
          record.scheduledDate.year == date.year &&
          record.scheduledDate.month == date.month &&
          record.scheduledDate.day == date.day,
      orElse: () => PillRecord(
        pillId: pillId,
        scheduledDate: date,
        isTaken: true,
        takenDate: DateTime.now(),
      ),
    );

    if (targetRecord.id != null) {
      // 기존 기록 업데이트
      final updatedRecord = targetRecord.copyWith(
        isTaken: true,
        takenDate: DateTime.now(),
      );
      return await _dbHelper.updatePillRecord(updatedRecord);
    } else {
      // 새 기록 생성
      return await _dbHelper.insertPillRecord(targetRecord);
    }
  }

  // 복용 건너뛰기
  Future<int> markPillAsSkipped(int pillId, DateTime date) async {
    final records = await _dbHelper.getPillRecords(pillId);
    final targetRecord = records.firstWhere(
      (record) =>
          record.scheduledDate.year == date.year &&
          record.scheduledDate.month == date.month &&
          record.scheduledDate.day == date.day,
      orElse: () =>
          PillRecord(pillId: pillId, scheduledDate: date, isSkipped: true),
    );

    if (targetRecord.id != null) {
      final updatedRecord = targetRecord.copyWith(isSkipped: true);
      return await _dbHelper.updatePillRecord(updatedRecord);
    } else {
      return await _dbHelper.insertPillRecord(targetRecord);
    }
  }

  // 특정 날짜의 복용 상태 조회
  Future<Map<int, PillRecord?>> getPillStatusForDate(DateTime date) async {
    return await _dbHelper.getPillStatusForDate(date);
  }

  // 알약 활성화/비활성화
  Future<int> togglePillActive(int pillId, bool isActive) async {
    final pill = await _dbHelper.getPill(pillId);
    if (pill == null) return 0;

    final updatedPill = pill.copyWith(isActive: isActive);
    final result = await _dbHelper.updatePill(updatedPill);

    if (isActive) {
      await _notificationService.scheduleAllPillNotifications([updatedPill]);
    } else {
      await _notificationService.cancelPillNotification(pillId);
    }

    return result;
  }

  // 특정 알약의 복용 기록 조회
  Future<List<PillRecord>> getPillRecords(int pillId) async {
    return await _dbHelper.getPillRecords(pillId);
  }

  // 복용 기록 추가
  Future<int> insertPillRecord(PillRecord record) async {
    return await _dbHelper.insertPillRecord(record);
  }

  // 복용 기록 수정
  Future<int> updatePillRecord(PillRecord record) async {
    return await _dbHelper.updatePillRecord(record);
  }
}
