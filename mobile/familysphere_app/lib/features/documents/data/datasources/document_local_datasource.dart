import 'package:hive_flutter/hive_flutter.dart';
import 'package:familysphere_app/features/documents/data/models/document_model.dart';

class DocumentLocalDataSource {
  static const String _documentsBoxName = 'document_cache';

  String _queryKey(
    String familyId, {
    String? category,
    String? folder,
    String? memberId,
  }) {
    return [
      familyId,
      category ?? '',
      folder ?? '',
      memberId ?? '',
    ].join('|');
  }

  Future<Box<dynamic>> _openBox() async {
    return Hive.openBox<dynamic>(_documentsBoxName);
  }

  Future<void> cacheDocuments({
    required String familyId,
    required List<DocumentModel> documents,
    required int storageUsed,
    required int storageLimit,
    String? category,
    String? folder,
    String? memberId,
  }) async {
    final box = await _openBox();
    final key = _queryKey(
      familyId,
      category: category,
      folder: folder,
      memberId: memberId,
    );

    await box.put(key, {
      'documents': documents.map((doc) => doc.toJson()).toList(),
      'storageUsed': storageUsed,
      'storageLimit': storageLimit,
      'cachedAt': DateTime.now().toIso8601String(),
    });
  }

  Future<Map<String, dynamic>?> getCachedDocuments({
    required String familyId,
    String? category,
    String? folder,
    String? memberId,
  }) async {
    final box = await _openBox();
    final key = _queryKey(
      familyId,
      category: category,
      folder: folder,
      memberId: memberId,
    );
    final data = box.get(key);
    if (data is! Map) {
      return null;
    }

    final docsJson = (data['documents'] as List<dynamic>? ?? const <dynamic>[])
        .whereType<Map>()
        .map((json) => DocumentModel.fromJson(Map<String, dynamic>.from(json)))
        .toList();

    return {
      'documents': docsJson,
      'storageUsed': (data['storageUsed'] as num?)?.toInt() ?? 0,
      'storageLimit':
          (data['storageLimit'] as num?)?.toInt() ?? 25 * 1024 * 1024 * 1024,
      'cachedAt': data['cachedAt'] != null
          ? DateTime.tryParse(data['cachedAt'].toString())
          : null,
    };
  }

  Future<void> updateOfflineAvailability({
    required String documentId,
    required bool isOfflineAvailable,
    String? localPath,
  }) async {
    final box = await _openBox();
    for (final key in box.keys) {
      final data = box.get(key);
      if (data is! Map) {
        continue;
      }

      final updatedDocuments =
          (data['documents'] as List<dynamic>? ?? const <dynamic>[])
              .map((item) {
        if (item is! Map) {
          return item;
        }
        final json = Map<String, dynamic>.from(item);
        final id = (json['_id'] ?? json['id'] ?? '').toString();
        if (id != documentId) {
          return json;
        }
        json['isOfflineAvailable'] = isOfflineAvailable;
        json['localPath'] = localPath;
        return json;
      }).toList();

      await box.put(key, {
        ...Map<String, dynamic>.from(data.cast<String, dynamic>()),
        'documents': updatedDocuments,
      });
    }
  }
}
