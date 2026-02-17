import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:familysphere_app/core/theme/app_theme.dart';
import 'package:familysphere_app/features/lab/domain/services/pdf_compress_service.dart';
import 'package:familysphere_app/features/lab/presentation/providers/pdf_compress_provider.dart';
import 'package:familysphere_app/features/lab/presentation/widgets/merge_result_sheet.dart';
import 'package:familysphere_app/features/lab/domain/services/lab_file_manager.dart';

class CompressPdfScreen extends ConsumerStatefulWidget {
  const CompressPdfScreen({super.key});

  @override
  ConsumerState<CompressPdfScreen> createState() => _CompressPdfScreenState();
}

class _CompressPdfScreenState extends ConsumerState<CompressPdfScreen> {
  static const Color _primaryBlue = Color(0xFF137FEC);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final state = ref.watch(pdfCompressProvider);
    final notifier = ref.read(pdfCompressProvider.notifier);

    // Listen for success/error
    ref.listen<PdfCompressState>(pdfCompressProvider, (prev, next) {
      if (prev?.status != next.status) {
        if (next.status == CompressStatus.success && next.outputFilePath != null) {
          MergeResultSheet.showSuccess(
            context,
            outputFilePath: next.outputFilePath!,
            outputSizeBytes: next.estimatedSize, // Using estimated/final size
            successTitle: 'Compression Done!',
            onDone: () => notifier.reset(),
          );
        }
      }
    });

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBackground : const Color(0xFFF6F7F8),
      appBar: _buildAppBar(context, isDark),
      body: Stack(
        children: [
          // Decoration
          Positioned(
            top: -50,
            right: -100,
            child: Opacity(
              opacity: isDark ? 0.05 : 0.1,
              child: Container(
                width: 400,
                height: 400,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [_primaryBlue, _primaryBlue.withOpacity(0)],
                  ),
                ),
              ),
            ),
          ),

          // Content
          Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.only(bottom: 120),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildInfoCard(isDark),
                      _buildAddButton(isDark, state, notifier),
                      if (state.inputFile != null) ...[
                        _buildSelectedFileCard(isDark, state, notifier),
                        _buildCompressionLevels(isDark, state, notifier),
                        _buildEstimatedSize(isDark, state),
                      ],
                      if (state.errorMessage != null)
                        _buildErrorBanner(isDark, state.errorMessage!, notifier),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // Overlays
          if (state.isProcessing && state.status != CompressStatus.idle)
            _buildProgressOverlay(isDark, state, notifier),
        ],
      ),
      bottomNavigationBar: _buildBottomButton(isDark, state, notifier),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context, bool isDark) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_rounded),
        onPressed: () => Navigator.pop(context),
      ),
      title: const Text('Compress PDF', style: TextStyle(fontWeight: FontWeight.bold)),
      actions: [
        Container(
          margin: const EdgeInsets.only(right: 16),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: isDark ? Colors.green.withOpacity(0.2) : const Color(0xFFDCFCE7),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              Icon(Icons.cloud_off_rounded, size: 14, color: isDark ? Colors.green.shade400 : const Color(0xFF15803D)),
              const SizedBox(width: 4),
              const Text('OFFLINE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInfoCard(bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: _primaryBlue.withOpacity(isDark ? 0.15 : 0.08),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            const Icon(Icons.compress_rounded, color: _primaryBlue, size: 32),
            const SizedBox(width: 16),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Secure Compression', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  SizedBox(height: 4),
                  Text('Reduce PDF size locally. Your files never leave your phone.', style: TextStyle(fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddButton(bool isDark, PdfCompressState state, PdfCompressNotifier notifier) {
    if (state.inputFile != null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: InkWell(
        onTap: () => notifier.pickFile(),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 40),
          decoration: BoxDecoration(
            border: Border.all(color: _primaryBlue.withOpacity(0.3), width: 2),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Column(
            children: [
              Icon(Icons.picture_as_pdf_rounded, color: _primaryBlue, size: 40),
              SizedBox(height: 12),
              Text('Add PDF File', style: TextStyle(fontWeight: FontWeight.bold, color: _primaryBlue)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSelectedFileCard(bool isDark, PdfCompressState state, PdfCompressNotifier notifier) {
    final fileName = state.inputFile!.path.split(Platform.pathSeparator).last;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkSurface : Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
        ),
        child: Row(
          children: [
            const Icon(Icons.picture_as_pdf_rounded, color: Colors.red, size: 32),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(fileName, style: const TextStyle(fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text(LabFileManager.formatFileSize(state.originalSize), style: const TextStyle(fontSize: 12)),
                ],
              ),
            ),
            IconButton(icon: const Icon(Icons.close), onPressed: () => notifier.reset()),
          ],
        ),
      ),
    );
  }

  Widget _buildCompressionLevels(bool isDark, PdfCompressState state, PdfCompressNotifier notifier) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('COMPRESSION LEVEL', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
          const SizedBox(height: 12),
          ...CompressionLevel.values.map((level) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: InkWell(
                  onTap: () => notifier.setCompressionLevel(level),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: state.compressionLevel == level 
                            ? _primaryBlue 
                            : (isDark ? AppTheme.darkBorder : Colors.grey.withOpacity(0.3)),
                        width: state.compressionLevel == level ? 2 : 1,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      color: state.compressionLevel == level 
                          ? _primaryBlue.withOpacity(0.08) 
                          : (isDark ? AppTheme.darkSurface : Colors.white),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              state.compressionLevel == level 
                                  ? Icons.radio_button_checked 
                                  : Icons.radio_button_off,
                              color: state.compressionLevel == level 
                                  ? _primaryBlue 
                                  : (isDark ? Colors.grey[600] : Colors.grey),
                              size: 22,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              level.label,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: state.compressionLevel == level 
                                    ? _primaryBlue 
                                    : (isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary),
                              ),
                            ),
                            const Spacer(),
                            if (level.hasQualityWarning)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.orange.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: const [
                                    Icon(Icons.warning_rounded, size: 12, color: Colors.orange),
                                    SizedBox(width: 4),
                                    Text(
                                      'Quality Loss',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.orange,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Padding(
                          padding: const EdgeInsets.only(left: 34),
                          child: Text(
                            level.description,
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark 
                                  ? AppTheme.darkTextSecondary 
                                  : AppTheme.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildEstimatedSize(bool isDark, PdfCompressState state) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), borderRadius: BorderRadius.circular(16)),
        child: Row(
          children: [
            const Icon(Icons.analytics_outlined, color: Colors.blue),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Estimated Result', style: TextStyle(fontSize: 12)),
                  Text(LabFileManager.formatFileSize(state.estimatedSize), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.blue)),
                  const SizedBox(height: 4),
                  Text(
                    'Actual size may vary based on content',
                    style: TextStyle(
                      fontSize: 10,
                      color: isDark ? AppTheme.darkTextSecondary : AppTheme.textTertiary,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomButton(bool isDark, PdfCompressState state, PdfCompressNotifier notifier) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: ElevatedButton(
        onPressed: state.canCompress ? () => notifier.startCompression() : null,
        style: ElevatedButton.styleFrom(backgroundColor: _primaryBlue, minimumSize: const Size(double.infinity, 56), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
        child: const Text('COMPRESS PDF', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildProgressOverlay(bool isDark, PdfCompressState state, PdfCompressNotifier notifier) {
    return Container(
      color: Colors.black54,
      child: Center(
        child: Card(
          margin: const EdgeInsets.all(32),
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(value: state.progress > 0 ? state.progress : null),
                const SizedBox(height: 24),
                const Text('Compressing PDF...', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                const Text('Processing locally on your device', style: TextStyle(fontSize: 12)),
                const SizedBox(height: 24),
                TextButton(onPressed: () => notifier.cancelCompression(), child: const Text('Cancel', style: TextStyle(color: Colors.red))),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorBanner(bool isDark, String message, PdfCompressNotifier notifier) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.red),
          const SizedBox(width: 12),
          Expanded(child: Text(message, style: const TextStyle(color: Colors.red))),
        ],
      ),
    );
  }
}
