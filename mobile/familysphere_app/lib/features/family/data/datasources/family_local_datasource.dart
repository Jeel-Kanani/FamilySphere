import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:familysphere_app/features/family/data/models/family_model.dart';
import 'package:familysphere_app/features/family/data/models/family_member_model.dart';

/// Local Data Source - Hive Storage
class FamilyLocalDataSource {
  static const String _familyBox = 'family_box';
  static const String _membersBox = 'family_members_box';
  static const String _currentFamilyKey = 'current_family';

  /// Initialize Hive box
  Future<void> init() async {
    if (!Hive.isBoxOpen(_familyBox)) {
      await Hive.openBox(_familyBox);
    }
    if (!Hive.isBoxOpen(_membersBox)) {
      await Hive.openBox(_membersBox);
    }
  }

  /// Cache Family Data
  Future<void> cacheFamily(FamilyModel family) async {
    final box = Hive.box(_familyBox);
    await box.put(_currentFamilyKey, jsonEncode(family.toJson()));
  }

  /// Get Cached Family
  Future<FamilyModel?> getCachedFamily() async {
    final box = Hive.box(_familyBox);
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
    final box = Hive.box(_membersBox);
    final membersJson = members.map((m) => m.toJson()).toList();
    await box.put(familyId, jsonEncode(membersJson));
  }

  /// Get Cached Family Members
  Future<List<FamilyMemberModel>> getCachedFamilyMembers(String familyId) async {
    final box = Hive.box(_membersBox);
    final jsonStr = box.get(familyId);
    
    if (jsonStr == null) return [];
    
    try {
      final List<dynamic> jsonList = jsonDecode(jsonStr);
      return jsonList.map((j) => FamilyMemberModel.fromJson(j)).toList();
    } catch (e) {
      return [];
    }
  }

  /// Clear Cache
  Future<void> clearCache() async {
    final familyBox = Hive.box(_familyBox);
    final membersBox = Hive.box(_membersBox);
    await familyBox.clear();
    await membersBox.clear();
  }
}
