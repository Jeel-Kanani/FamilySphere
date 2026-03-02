import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:familysphere_app/features/documents/data/datasources/document_remote_datasource.dart';
import 'package:familysphere_app/features/documents/data/models/document_intelligence_model.dart';
import 'package:familysphere_app/features/documents/presentation/providers/document_provider.dart';

// ── FutureProvider: fetch intelligence for a given docId ─────────────────────

final documentIntelligenceProvider = FutureProvider.family<DocumentIntelligenceModel, String>(
  (ref, docId) async {
    final ds = ref.read(documentRemoteDataSourceProvider);
    return ds.getDocumentIntelligence(documentId: docId);
  },
);

// ── StateNotifier for confirm-type action ─────────────────────────────────────

class ConfirmTypeNotifier extends StateNotifier<AsyncValue<void>> {
  final DocumentRemoteDataSource _ds;

  ConfirmTypeNotifier(this._ds) : super(const AsyncValue.data(null));

  Future<void> confirm({required String docId, required String docType}) async {
    state = const AsyncValue.loading();
    try {
      await _ds.confirmDocumentType(documentId: docId, docType: docType);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

final confirmTypeProvider =
    StateNotifierProvider.autoDispose<ConfirmTypeNotifier, AsyncValue<void>>(
  (ref) => ConfirmTypeNotifier(ref.read(documentRemoteDataSourceProvider)),
);

// ── Allowed document types list (mirrors backend) ─────────────────────────────

const kAllowedDocTypes = [
  'Aadhaar', 'PAN Card', 'Passport', 'Driving License', 'Voter ID',
  'Bank Statement', 'Loan Agreement', 'Insurance Policy', 'Investment Document',
  'Lab Report', 'Prescription', 'Medical Certificate',
  'Rent Agreement', 'Property Deed', 'Affidavit', 'Contract',
  'Marksheet', 'Degree Certificate', 'Admission Letter',
  'Electricity Bill', 'Water Bill', 'Gas Bill',
  'Salary Slip', 'Tax Return', 'Vehicle RC',
  'Other',
];
