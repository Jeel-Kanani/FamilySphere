import 'package:familysphere_app/features/documents/data/models/sync_history_entry_model.dart';
import 'package:hive_flutter/hive_flutter.dart';

class SyncHistoryLocalDataSource {
  static const String _boxName = 'sync_history_box';
  static const int _maxEntriesPerFamily = 50;

  Future<Box<dynamic>> _openBox() async {
    return Hive.openBox<dynamic>(_boxName);
  }

  Future<void> addEntry(SyncHistoryEntryModel entry) async {
    final box = await _openBox();
    final existing = await getEntries(entry.familyId);
    final updated = [entry, ...existing]
        .take(_maxEntriesPerFamily)
        .map((item) => item.toJson())
        .toList();
    await box.put(entry.familyId, updated);
  }

  Future<List<SyncHistoryEntryModel>> getEntries(String familyId) async {
    final box = await _openBox();
    final raw = box.get(familyId);
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((item) => SyncHistoryEntryModel.fromJson(
              Map<String, dynamic>.from(item),
            ))
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }
}
