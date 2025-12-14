import 'package:flutter/foundation.dart';
import '../models/pill.dart';
import '../models/pill_record.dart';
import '../services/pill_service.dart';

class PillProvider with ChangeNotifier {
  final PillService _pillService = PillService();

  List<Pill> _pills = [];
  Map<DateTime, Map<int, PillRecord?>> _pillStatusCache = {};
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;

  List<Pill> get pills => _pills;
  DateTime get selectedDate => _selectedDate;
  bool get isLoading => _isLoading;

  // 알약 목록 로드
  Future<void> loadPills() async {
    _setLoading(true);
    try {
      _pills = await _pillService.getAllPills();

      // 오늘 날짜의 복용 상태도 함께 로드
      await _loadPillStatusForDate(_selectedDate);

      notifyListeners();
    } catch (e) {
      // 알약 목록 로드 실패 처리
    } finally {
      _setLoading(false);
    }
  }

  // 알약 추가
  Future<bool> addPill(Pill pill) async {
    try {
      final id = await _pillService.addPill(pill);

      if (id > 0) {
        await loadPills();
        await _loadPillStatusForDate(_selectedDate);
        return true;
      }
      return false;
    } catch (e) {
      // 알약 추가 실패 처리
      return false;
    }
  }

  // 알약 수정
  Future<bool> updatePill(Pill pill) async {
    try {
      final result = await _pillService.updatePill(pill);

      if (result > 0) {
        await loadPills();
        await _loadPillStatusForDate(_selectedDate);
        return true;
      }
      return false;
    } catch (e) {
      // 알약 수정 실패 처리
      return false;
    }
  }

  // 알약 삭제
  Future<bool> deletePill(int id) async {
    try {
      final result = await _pillService.deletePill(id);

      if (result > 0) {
        await loadPills();
        await _loadPillStatusForDate(_selectedDate);
        return true;
      }
      return false;
    } catch (e) {
      // 알약 삭제 실패 처리
      return false;
    }
  }

  // 선택된 날짜 설정
  void setSelectedDate(DateTime date) {
    _selectedDate = date;
    _loadPillStatusForDate(date);
    notifyListeners();
  }

  // 특정 날짜의 알약 목록 가져오기
  List<Pill> getPillsForDate(DateTime date) {
    final dateKey = DateTime(date.year, date.month, date.day);
    return _pills.where((pill) {
      // 시작일 이후인지 확인 (시간 제거하고 날짜만 비교)
      final pillStartDateOnly = DateTime(
        pill.startDate.year,
        pill.startDate.month,
        pill.startDate.day,
      );
      if (dateKey.isBefore(pillStartDateOnly)) return false;

      // 활성화된 알약인지 확인
      if (!pill.isActive) return false;

      // 복용 빈도에 따른 확인
      switch (pill.frequency) {
        case 'daily':
          return true;
        case 'weekly':
          final daysSinceStart = dateKey.difference(pillStartDateOnly).inDays;
          return daysSinceStart % 7 == 0;
        case 'monthly':
          final monthsSinceStart =
              (dateKey.year - pillStartDateOnly.year) * 12 +
              (dateKey.month - pillStartDateOnly.month);
          return monthsSinceStart >= 0 && dateKey.day == pillStartDateOnly.day;
        case 'custom':
          if (pill.customDays != null) {
            final daysSinceStart = dateKey.difference(pillStartDateOnly).inDays;
            return daysSinceStart % pill.customDays! == 0;
          }
          return false;
        default:
          return false;
      }
    }).toList();
  }

  // 오늘 복용할 알약 목록 가져오기
  List<Pill> getTodayPills() {
    return getPillsForDate(DateTime.now());
  }

  // 특정 날짜의 알약 복용 상태 가져오기
  Map<int, bool> getPillStatusForDate(DateTime date) {
    final dateKey = DateTime(date.year, date.month, date.day);

    if (_pillStatusCache.containsKey(dateKey)) {
      final pillStatus = _pillStatusCache[dateKey]!;
      return Map.fromEntries(
        pillStatus.entries.map(
          (entry) => MapEntry(entry.key, entry.value?.isTaken ?? false),
        ),
      );
    }
    return {};
  }

  // 특정 날짜의 알약 복용 상태 로드
  Future<void> _loadPillStatusForDate(DateTime date) async {
    try {
      final dateKey = DateTime(date.year, date.month, date.day);
      final pillsForDate = getPillsForDate(date);

      final pillStatus = <int, PillRecord?>{};

      for (final pill in pillsForDate) {
        if (pill.id != null) {
          final records = await _pillService.getPillRecords(pill.id!);
          final todayRecord = records.firstWhere(
            (record) => record.scheduledDate.isAtSameMomentAs(dateKey),
            orElse: () => PillRecord(
              id: 0,
              pillId: pill.id!,
              scheduledDate: dateKey,
              takenDate: null,
              isTaken: false,
              isSkipped: false,
            ),
          );
          pillStatus[pill.id!] = todayRecord;
        }
      }

      _pillStatusCache[dateKey] = pillStatus;
    } catch (e) {
      // 알약 상태 로드 실패 처리
    }
  }

  // 오늘 알약 복용 여부 확인
  bool isPillTakenToday(int pillId) {
    final today = DateTime.now();
    final todayKey = DateTime(today.year, today.month, today.day);

    if (_pillStatusCache.containsKey(todayKey)) {
      final pillStatus = _pillStatusCache[todayKey]!;
      if (pillStatus.containsKey(pillId)) {
        final record = pillStatus[pillId];
        return record?.isTaken ?? false;
      }
    }
    return false;
  }

  // 오늘 알약 복용 시간 가져오기
  DateTime? getPillTakenTimeToday(int pillId) {
    final today = DateTime.now();
    final todayKey = DateTime(today.year, today.month, today.day);

    if (_pillStatusCache.containsKey(todayKey)) {
      final pillStatus = _pillStatusCache[todayKey]!;
      if (pillStatus.containsKey(pillId)) {
        final record = pillStatus[pillId];
        return record?.takenDate;
      }
    }
    return null;
  }

  // 특정 날짜의 알약 복용 시간 가져오기
  DateTime? getPillTakenTimeForDate(int pillId, DateTime date) {
    final dateKey = DateTime(date.year, date.month, date.day);

    if (_pillStatusCache.containsKey(dateKey)) {
      final pillStatus = _pillStatusCache[dateKey]!;
      if (pillStatus.containsKey(pillId)) {
        final record = pillStatus[pillId];
        return record?.takenDate;
      }
    }
    return null;
  }

  // 특정 날짜에 알약 복용 처리
  Future<void> takePill(int pillId, DateTime date) async {
    final dateKey = DateTime(date.year, date.month, date.day);

    try {
      // 기존 기록이 있는지 확인
      final existingRecords = await _pillService.getPillRecords(pillId);
      final targetRecord = existingRecords.firstWhere(
        (record) => record.scheduledDate.isAtSameMomentAs(dateKey),
        orElse: () => PillRecord(
          id: 0,
          pillId: pillId,
          scheduledDate: dateKey,
          takenDate: null,
          isTaken: false,
          isSkipped: false,
        ),
      );

      if (targetRecord.id == 0) {
        // 새 기록 생성
        final newRecord = PillRecord(
          pillId: pillId,
          scheduledDate: dateKey,
          takenDate: date,
          isTaken: true,
          isSkipped: false,
        );
        await _pillService.insertPillRecord(newRecord);
      } else {
        // 기존 기록 수정
        final updatedRecord = targetRecord.copyWith(
          takenDate: date,
          isTaken: true,
          isSkipped: false,
        );
        await _pillService.updatePillRecord(updatedRecord);
      }

      // 캐시 업데이트
      if (_pillStatusCache.containsKey(dateKey)) {
        _pillStatusCache[dateKey]![pillId] = PillRecord(
          id: targetRecord.id == 0 ? 1 : targetRecord.id,
          pillId: pillId,
          scheduledDate: dateKey,
          takenDate: date,
          isTaken: true,
          isSkipped: false,
        );
      }

      notifyListeners();
    } catch (e) {
      // 알약 복용 처리 실패 처리
    }
  }

  // 특정 날짜에 알약 복용 취소 처리
  Future<void> untakePill(int pillId, DateTime date) async {
    final dateKey = DateTime(date.year, date.month, date.day);

    try {
      // 기존 기록이 있는지 확인
      final existingRecords = await _pillService.getPillRecords(pillId);
      final targetRecord = existingRecords.firstWhere(
        (record) => record.scheduledDate.isAtSameMomentAs(dateKey),
        orElse: () => PillRecord(
          id: 0,
          pillId: pillId,
          scheduledDate: dateKey,
          takenDate: null,
          isTaken: false,
          isSkipped: false,
        ),
      );

      if (targetRecord.id != null && targetRecord.id! > 0) {
        // 기존 기록 수정
        final updatedRecord = targetRecord.copyWith(
          takenDate: null,
          isTaken: false,
          isSkipped: false,
        );
        await _pillService.updatePillRecord(updatedRecord);

        // 캐시 업데이트
        if (_pillStatusCache.containsKey(dateKey)) {
          _pillStatusCache[dateKey]![pillId] = updatedRecord;
        }
      }

      notifyListeners();
    } catch (e) {
      // 알약 복용 취소 처리 실패 처리
    }
  }

  // 로딩 상태 설정
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }
}
