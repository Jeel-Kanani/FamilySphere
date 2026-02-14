import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:familysphere_app/core/theme/app_theme.dart';
import 'package:familysphere_app/features/lab/presentation/providers/split_pdf_provider.dart';
import 'package:familysphere_app/features/lab/domain/services/split_pdf_service.dart';
import 'package:familysphere_app/features/lab/presentation/widgets/merge_result_sheet.dart';

class SplitPdfScreen extends ConsumerStatefulWidget {
  const SplitPdfScreen({super.key});

  @override
  ConsumerState<SplitPdfScreen> createState() => _SplitPdfScreenState();
}

class _SplitPdfScreenState extends ConsumerState<SplitPdfScreen> {
  final TextEditingController _rangeController = TextEditingController();
  final TextEditingController _outputNameController = TextEditingController();

  final Color _primaryBlue = const Color(0xFF2563EB);
  final Color _cardColor = Colors.white;

  @override
  void dispose() {
    _rangeController.dispose();
    _outputNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(splitPdfProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Listen for success to show the result sheet
    ref.listen(splitPdfProvider, (previous, next) {
      if (next.status == SplitStatus.success &&
          previous?.status != SplitStatus.success) {
        if (next.outputFilePaths.isNotEmpty) {
          MergeResultSheet.showSuccess(
            context,
            outputFilePath: next.outputFilePaths.first,
            outputSizeBytes: 0, // Not strictly needed for the sheet display here
            successTitle: 'Split Completed!',
            onDone: () {
              ref.read(splitPdfProvider.notifier).reset();
            },
          );
        }
      }
    });

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBackground : const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: const Text('Split PDF'),
        backgroundColor: isDark ? AppTheme.darkSurface : Colors.white,
        foregroundColor: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
        elevation: 0,
        centerTitle: true,
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 100),
            child: Column(
              children: [
                _buildInfoCard(isDark),
                const SizedBox(height: 16),
                _buildFileSelection(isDark, state),
                if (state.selectedFile != null) ...[
                  const SizedBox(height: 16),
                  _buildSplitOptions(isDark, state),
                  const SizedBox(height: 16),
                  _buildOutputSettings(isDark, state),
                ],
                if (state.errorMessage != null)
                  _buildErrorBanner(isDark, state.errorMessage!),
              ],
            ),
          ),
          if (state.isProcessing) _buildProgressOverlay(isDark, state),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _buildBottomButton(isDark, state),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(bool isDark) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : _cardColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusL),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _primaryBlue.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.info_outline, color: _primaryBlue, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Split PDF Pages',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
                      ),
                ),
                Text(
                  'Extract specific pages or split into multiple PDFs with ease.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFileSelection(bool isDark, SplitPdfState state) {
    if (state.selectedFile == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: ElevatedButton.icon(
          onPressed: () => ref.read(splitPdfProvider.notifier).pickFile(),
          icon: const Icon(Icons.picture_as_pdf_outlined),
          label: const Text('+ SELECT PDF FILE'),
          style: ElevatedButton.styleFrom(
            backgroundColor: _primaryBlue,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 56),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : _cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _primaryBlue.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.picture_as_pdf, color: Colors.red, size: 32),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  state.selectedFile!.name,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${state.selectedFile!.sizeLabel} • ${state.selectedFile!.pageCount} pages',
                  style: TextStyle(color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => ref.read(splitPdfProvider.notifier).removeFile(),
          ),
        ],
      ),
    );
  }

  Widget _buildSplitOptions(bool isDark, SplitPdfState state) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : _cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'SPLIT OPTIONS',
            style: TextStyle(
              color: _primaryBlue,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 16),
          RadioListTile<SplitMode>(
            title: const Text('Split by Page Range'),
            value: SplitMode.range,
            groupValue: state.mode,
            activeColor: _primaryBlue,
            onChanged: (val) => ref.read(splitPdfProvider.notifier).setMode(val!),
            contentPadding: EdgeInsets.zero,
          ),
          if (state.mode == SplitMode.range) ...[
            Padding(
              padding: const EdgeInsets.only(left: 48, right: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _rangeController,
                    onChanged: (val) => ref.read(splitPdfProvider.notifier).setRange(val),
                    decoration: InputDecoration(
                      hintText: 'e.g. 1-3, 5, 7-10',
                      filled: true,
                      fillColor: isDark ? AppTheme.darkBackground : const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.withOpacity(0.2)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.withOpacity(0.2)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Pages start from 1',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ],
          RadioListTile<SplitMode>(
            title: const Text('Split into Individual Pages'),
            value: SplitMode.individual,
            groupValue: state.mode,
            activeColor: _primaryBlue,
            onChanged: (val) => ref.read(splitPdfProvider.notifier).setMode(val!),
            contentPadding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }

  Widget _buildOutputSettings(bool isDark, SplitPdfState state) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : _cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'OUTPUT FILE NAME',
            style: TextStyle(
              color: _primaryBlue,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _outputNameController,
            onChanged: (val) => ref.read(splitPdfProvider.notifier).setOutputName(val),
            decoration: InputDecoration(
              suffixIcon: const Icon(Icons.edit, size: 20),
              filled: true,
              fillColor: isDark ? AppTheme.darkBackground : const Color(0xFFF8FAFC),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.withOpacity(0.2)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomButton(bool isDark, SplitPdfState state) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.withOpacity(0.1))),
      ),
      child: ElevatedButton(
        onPressed: state.canSplit ? () => ref.read(splitPdfProvider.notifier).startSplit() : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: _primaryBlue,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 56),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: const Text(
          'SPLIT PDF',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ),
    );
  }

  Widget _buildErrorBanner(bool isDark, String message) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.red),
          const SizedBox(width: 12),
          Expanded(child: Text(message, style: const TextStyle(color: Colors.red))),
          IconButton(
            icon: const Icon(Icons.close, size: 18, color: Colors.red),
            onPressed: () => ref.read(splitPdfProvider.notifier).dismissError(),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressOverlay(bool isDark, SplitPdfState state) {
    return Container(
      color: Colors.black.withOpacity(0.5),
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkSurface : Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(value: state.progress > 0 ? state.progress : null),
              const SizedBox(height: 16),
              Text(state.progressMessage),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => ref.read(splitPdfProvider.notifier).cancelSplit(),
                child: const Text('Cancel'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
