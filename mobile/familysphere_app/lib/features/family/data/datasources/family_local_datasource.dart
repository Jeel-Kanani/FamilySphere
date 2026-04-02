import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:familysphere_app/features/family/domain/entities/family_activity.dart';
import 'package:familysphere_app/features/family/data/models/family_model.dart';
import 'package:familysphere_app/features/family/data/models/family_member_model.dart';

/// Local Data Source - Hive Storage
class FamilyLocalDataSource {
  static const String _familyBox = 'family_box';
  static const String _membersBox = 'family_members_box';
  static const String _activityBox = 'family_activity_box';
  static const String _currentFamilyKey = 'current_family';

  /// Initialize Hive box
  Future<void> init() async {
    if (!Hive.isBoxOpen(_familyBox)) {
      await Hive.openBox(_familyBox);
    }
    if (!Hive.isBoxOpen(_membersBox)) {
      await Hive.openBox(_membersBox);
    }
    if (!Hive.isBoxOpen(_activityBox)) {
      await Hive.openBox(_activityBox);
    }
  }

  /// Cache Family Data
  Future<void> cacheFamily(FamilyModel family) async {
    final box = await Hive.openBox(_familyBox);
    await box.put(_currentFamilyKey, jsonEncode(family.toJson()));
  }

  /// Get Cached Family
  Future<FamilyModel?> getCachedFamily() async {
    final box = await Hive.openBox(_familyBox);
    final jsonStr = box.get(_currentFamilyKey);
    
    if (jsonStr == null) return null;
    
    try {
      return FamilyModel.fromJson(jsonDecode(jsonStr));
    } catch (e) {
      return null;
    }
  }

  /// Cache Family Members
  Future<void> cacheFamilyMembers(String familyId, List<FamilyMemberModel> members) async {
    final box = await Hive.openBox(_membersBox);
    final membersJson = members.map((m) => m.toJson()).toList();
    await box.put(familyId, jsonEncode(membersJson));
  }

  /// Get Cached Family Members
  Future<List<FamilyMemberModel>> getCachedFamilyMembers(String familyId) async {
    final box = await Hive.openBox(_membersBox);
    final jsonStr = box.get(familyId);
    
    if (jsonStr == null) return [];
    
    try {
      final List<dynamic> jsonList = jsonDecode(jsonStr);
      return jsonList.map((j) => FamilyMemberModel.fromJson(j)).toList();
    } catch (e) {
      return [];
    }
  }

  Future<void> cacheFamilyActivity(
    String familyId,
    List<FamilyActivity> activities,
  ) async {
    final box = await Hive.openBox(_activityBox);
    final payload = activities
        .map((activity) => {
              'id': activity.id,
              'type': activity.type,
              'message': activity.message,
              'actorName': activity.actorName,
              'createdAt': activity.createdAt.toIso8601String(),
            })
        .toList();
    await box.put(familyId, jsonEncode(payload));
  }

  Future<List<FamilyActivity>> getCachedFamilyActivity(String familyId) async {
    final box = await Hive.openBox(_activityBox);
    final jsonStr = box.get(familyId);
    if (jsonStr == null) return [];

    try {
      final List<dynamic> jsonList = jsonDecode(jsonStr);
      return jsonList
          .whereType<Map>()
          .map((item) => FamilyActivity(
                id: item['id']?.toString() ?? '',
                type: item['type']?.toString() ?? 'unknown',
                message: item['message']?.toString() ?? '',
                actorName: item['actorName']?.toString(),
                createdAt: item['createdAt'] != null
                    ? DateTime.parse(item['createdAt'].toString())
                    : DateTime.now(),
              ))
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    } catch (_) {
      return [];
    }
  }

  /// Clear Cache
  Future<void> clearCache() async {
    final familyBox = await Hive.openBox(_familyBox);
    final membersBox = await Hive.openBox(_membersBox);
    final activityBox = await Hive.openBox(_activityBox);
    await familyBox.clear();
    await membersBox.clear();
    await activityBox.clear();
  }
}
