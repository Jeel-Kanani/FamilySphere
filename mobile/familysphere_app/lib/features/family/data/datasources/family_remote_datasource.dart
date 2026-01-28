import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:familysphere_app/features/family/data/models/family_model.dart';
import 'package:familysphere_app/features/family/data/models/family_member_model.dart';
import 'package:familysphere_app/features/family/domain/entities/family.dart';
import 'package:familysphere_app/features/family/domain/entities/family_member.dart';

/// Remote Data Source - Firebase Operations
class FamilyRemoteDataSource {
  final FirebaseFirestore _firestore;

  FamilyRemoteDataSource({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Create a new family
  Future<FamilyModel> createFamily(String name, String userId) async {
    final inviteCode = _generateInviteCode();
    final docRef = _firestore.collection('families').doc();
    
    final family = FamilyModel(
      id: docRef.id,
      name: name,
      createdBy: userId,
      createdAt: DateTime.now(),
      memberIds: [userId],
      inviteCode: inviteCode,
      settings: const FamilySettingsModel(),
    );

    // Run transaction to create family and update user
    await _firestore.runTransaction((transaction) async {
      // 1. Create family document
      transaction.set(docRef, family.toFirestore());

      // 2. Update user document
      final userRef = _firestore.collection('users').doc(userId);
      transaction.update(userRef, {
        'familyId': family.id,
        'role': 'admin',
      });
    });

    return family;
  }

  /// Join a family using invite code
  Future<FamilyModel> joinFamily(String inviteCode, String userId) async {
    // 1. Find family by invite code
    final querySnapshot = await _firestore
        .collection('families')
        .where('inviteCode', isEqualTo: inviteCode)
        .limit(1)
        .get();

    if (querySnapshot.docs.isEmpty) {
      throw Exception('Invalid invite code');
    }

    final familyDoc = querySnapshot.docs.first;
    final familyData = familyDoc.data();
    final familyId = familyDoc.id;

    // Check if user is already in a family (optional validation)
    // For now, we assume the UI handles this or we overwrite

    // Run transaction to join family
    await _firestore.runTransaction((transaction) async {
      // 1. Update family: add member
      transaction.update(familyDoc.reference, {
        'memberIds': FieldValue.arrayUnion([userId]),
      });

      // 2. Update user: set family ID and role
      final userRef = _firestore.collection('users').doc(userId);
      transaction.update(userRef, {
        'familyId': familyId,
        'role': 'member', // Default role
      });
    });

    // Return updated family model locally constructed
    // (Actual fresh data might strictly require another fetch, but this is efficient)
    final updatedMemberIds = List<String>.from(familyData['memberIds'] ?? [])..add(userId);
    
    return FamilyModel.fromFirestore(familyDoc).copyWith(
      memberIds: updatedMemberIds.toSet().toList(), // Ensure unique
    ) as FamilyModel;
  }

  /// Get family by ID
  Future<FamilyModel?> getFamily(String familyId) async {
    final doc = await _firestore.collection('families').doc(familyId).get();
    if (!doc.exists) return null;
    return FamilyModel.fromFirestore(doc);
  }

  /// Get all family members with their details
  Future<List<FamilyMemberModel>> getFamilyMembers(String familyId) async {
    final familyDoc = await _firestore.collection('families').doc(familyId).get();
    if (!familyDoc.exists) throw Exception('Family not found');

    final memberIds = List<String>.from(familyDoc.data()?['memberIds'] ?? []);
    if (memberIds.isEmpty) return [];

    // Fetch all user documents for these members
    // Firestore 'in' query supports up to 10 items. 
    // If > 10, typically need multiple queries or just fetch one by one.
    // For MVP, if < 10, use 'in'. If > 10, we'll fetch individually to be safe.
    
    if (memberIds.length <= 10) {
      final snapshot = await _firestore
          .collection('users')
          .where(FieldPath.documentId, whereIn: memberIds)
          .get();
      
      return _mapUsersToFamilyMembers(snapshot.docs, familyDoc);
    } else {
      // Chunked fetching or individual fetching
      final members = <FamilyMemberModel>[];
      for (final userId in memberIds) {
        final userDoc = await _firestore.collection('users').doc(userId).get();
        if (userDoc.exists) {
          members.add(_createFamilyMemberFromDocs(userDoc, familyDoc));
        }
      }
      return members;
    }
  }

  /// Helper to map user docs to FamilyMemberModels
  List<FamilyMemberModel> _mapUsersToFamilyMembers(
      List<QueryDocumentSnapshot> userDocs, DocumentSnapshot familyDoc) {
    return userDocs.map((userDoc) {
      return _createFamilyMemberFromDocs(userDoc, familyDoc);
    }).toList();
  }

  FamilyMemberModel _createFamilyMemberFromDocs(
      DocumentSnapshot userDoc, DocumentSnapshot familyDoc) {
    final userData = userDoc.data() as Map<String, dynamic>;
    final familyData = familyDoc.data() as Map<String, dynamic>;
    
    // Determine info
    final userId = userDoc.id;
    final createdBy = familyData['createdBy'];

    // If 'role' is stored in user doc (which we did in create/join)
    final roleStr = userData['role'] ?? 'member';
    final role = roleStr == 'admin' ? FamilyRole.admin : FamilyRole.member;

    return FamilyMemberModel(
      userId: userId,
      displayName: userData['displayName'] ?? 'Unknown',
      photoUrl: userData['photoUrl'],
      role: role,
      joinedAt: DateTime.now(), // Firestore users don't typically store 'joinedAt' for family unless added. Using now as placeholder or fetch if added.
    );
  }

  /// Generate a new invite code
  Future<String> generateInviteCode(String familyId) async {
    final newCode = _generateInviteCode();
    await _firestore.collection('families').doc(familyId).update({
      'inviteCode': newCode,
    });
    return newCode;
  }

  /// Remove member
  Future<void> removeMember(String familyId, String userId) async {
    await _firestore.runTransaction((transaction) async {
      final familyRef = _firestore.collection('families').doc(familyId);
      final userRef = _firestore.collection('users').doc(userId);

      // Remove from family
      transaction.update(familyRef, {
        'memberIds': FieldValue.arrayRemove([userId]),
      });

      // Clear info from user
      transaction.update(userRef, {
        'familyId': FieldValue.delete(),
        'role': FieldValue.delete(),
      });
    });
  }

  /// Leave family
  Future<void> leaveFamily(String familyId, String userId) async {
    // Same logic as remove member effectively
    await removeMember(familyId, userId);
  }

  /// Update family settings
  Future<FamilyModel> updateFamilySettings(String familyId, FamilySettings settings) async {
    final settingsModel = settings is FamilySettingsModel 
        ? settings 
        : FamilySettingsModel(
            allowMemberInvites: settings.allowMemberInvites,
            requireApproval: settings.requireApproval,
          );
          
    await _firestore.collection('families').doc(familyId).update({
      'settings': settingsModel.toMap(),
    });

    final updatedDoc = await _firestore.collection('families').doc(familyId).get();
    return FamilyModel.fromFirestore(updatedDoc);
  }

  /// Stream family changes
  Stream<FamilyModel?> watchFamily(String familyId) {
    return _firestore.collection('families').doc(familyId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return FamilyModel.fromFirestore(doc);
    });
  }

  /// Generate 6-char random alphanumeric code
  String _generateInviteCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // Excluded confusing chars like I, 1, O, 0
    final rnd = Random();
    return String.fromCharCodes(Iterable.generate(
      6,
      (_) => chars.codeUnitAt(rnd.nextInt(chars.length)),
    ));
  }
}
