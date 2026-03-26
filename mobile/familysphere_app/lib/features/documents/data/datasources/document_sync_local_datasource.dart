import 'package:hive_flutter/hive_flutter.dart';
import 'package:familysphere_app/features/documents/data/models/document_sync_job_model.dart';

class DocumentSyncLocalDataSource {
  static const String _syncJobsBoxName = 'document_sync_jobs';

  Future<Box<dynamic>> _openBox() async {
    return Hive.openBox<dynamic>(_syncJobsBoxName);
  }

  Future<void> saveJob(DocumentSyncJobModel job) async {
    final box = await _openBox();
    await box.put(job.id, job.toJson());
  }

  Future<void> removeJob(String jobId) async {
    final box = await _openBox();
    await box.delete(jobId);
  }

  Future<List<DocumentSyncJobModel>> getJobsForFamily(String familyId) async {
    final box = await _openBox();
    return box.values
        .whereType<Map>()
        .map((json) => DocumentSyncJobModel.fromJson(
              Map<String, dynamic>.from(json),
            ))
        .where((job) => job.familyId == familyId)
        .toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  }

  Future<List<DocumentSyncJobModel>> getFailedJobsForFamily(
      String familyId, int failureThreshold) async {
    final jobs = await getJobsForFamily(familyId);
    return jobs.where((job) => job.retryCount >= failureThreshold).toList();
  }

  Future<int> countJobsForFamily(String familyId) async {
    final jobs = await getJobsForFamily(familyId);
    return jobs.length;
  }

  Future<List<DocumentSyncJobModel>> getAllJobs() async {
    final box = await _openBox();
    return box.values
        .whereType<Map>()
        .map((json) => DocumentSyncJobModel.fromJson(
              Map<String, dynamic>.from(json),
            ))
        .toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  }

  Future<DocumentSyncJobModel?> findMoveJobForDocument(
      String documentId) async {
    final jobs = await getAllJobs();
    for (final job in jobs) {
      if (job.type != 'move') continue;
      if (job.payload['documentId']?.toString() == documentId) {
        return job;
      }
    }
    return null;
  }
}
