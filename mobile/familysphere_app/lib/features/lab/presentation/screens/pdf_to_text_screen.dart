import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:familysphere_app/core/theme/app_theme.dart';
import 'package:familysphere_app/features/lab/presentation/providers/pdf_to_text_provider.dart';
import 'package:familysphere_app/features/lab/domain/services/lab_file_manager.dart';

class PdfToTextScreen extends ConsumerWidget {
  const PdfToTextScreen({super.key});

  static const Color _primaryBlue = Color(0xFF2563EB);
  static const Color _pageBackground = Color(0xFFF6F7F8);
  static const Color _cardColor = Colors.white;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final state = ref.watch(pdfToTextProvider);
    final notifier = ref.read(pdfToTextProvider.notifier);

    ref.listen<PdfToTextState>(pdfToTextProvider, (prev, next) {
      if (prev?.status != next.status && next.status == PdfToTextStatus.error && next.errorMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next.errorMessage!), backgroundColor: Colors.red),
        );
      }
    });

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBackground : _pageBackground,
      appBar: AppBar(
        backgroundColor: isDark ? AppTheme.darkBackground : _pageBackground,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded,
              color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'PDF to Text',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
              ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Icon(Icons.text_snippet_rounded, color: _primaryBlue, size: 24),
          ),
        ],
      ),
      body: _buildBody(context, isDark, state, notifier),
    );
  }

  Widget _buildBody(BuildContext context, bool isDark, PdfToTextState state, PdfToTextNotifier notifier) {
    // Processing state
    if (state.status == PdfToTextStatus.processing || state.status == PdfToTextStatus.picking) {
      return _buildProcessingView(context, isDark, state);
    }

    // Success state
    if (state.status == PdfToTextStatus.success && state.extractedText != null) {
      return _buildResultView(context, isDark, state, notifier);
    }

    // Idle / error state
    return _buildIdleView(context, isDark, state, notifier);
  }

  Widget _buildIdleView(BuildContext context, bool isDark, PdfToTextState state, PdfToTextNotifier notifier) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        children: [
          // Instruction
          Padding(
            padding: const EdgeInsets.all(16),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? _primaryBlue.withOpacity(0.15) : _primaryBlue.withOpacity(0.08),
                borderRadius: BorderRadius.circular(AppTheme.radiusL),
                border: Border.all(color: _primaryBlue.withOpacity(0.2)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Icon(Icons.info_outline_rounded, color: _primaryBlue, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Extract text from a PDF',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
                                )),
                        const SizedBox(height: 4),
                        Text(
                          'Select a PDF and the tool will extract readable text from each page into a .txt file.',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
                                height: 1.4,
                              ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Big action button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => notifier.pickAndExtract(),
                borderRadius: BorderRadius.circular(AppTheme.radiusL),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  decoration: BoxDecoration(
                    color: isDark ? AppTheme.darkSurface : _cardColor,
                    borderRadius: BorderRadius.circular(AppTheme.radiusL),
                    border: Border.all(color: _primaryBlue.withOpacity(0.4), width: 2),
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 72, height: 72,
                        decoration: BoxDecoration(
                          color: _primaryBlue.withOpacity(0.08),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.upload_file_rounded, color: _primaryBlue, size: 36),
                      ),
                      const SizedBox(height: 16),
                      Text('Select PDF to Extract Text',
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: _primaryBlue,
                              )),
                      const SizedBox(height: 6),
                      Text('Supported: Text-based PDFs',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: isDark ? AppTheme.darkTextSecondary : AppTheme.textTertiary,
                              )),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProcessingView(BuildContext context, bool isDark, PdfToTextState state) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 40),
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkSurface : _cardColor,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20)],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 56, height: 56,
              child: CircularProgressIndicator(
                value: state.progress > 0.1 ? state.progress : null,
                strokeWidth: 4, color: _primaryBlue,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              state.progressMessage.isNotEmpty ? state.progressMessage : 'Extracting text...',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultView(BuildContext context, bool isDark, PdfToTextState state, PdfToTextNotifier notifier) {
    return Column(
      children: [
        // Stats bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          color: isDark ? AppTheme.darkSurface : _cardColor,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStat(context, isDark, Icons.pages_rounded, '${state.pageCount} pages'),
              _buildStat(context, isDark, Icons.text_fields_rounded, '${state.characterCount} chars'),
              _buildStat(context, isDark, Icons.save_rounded,
                  LabFileManager.formatFileSize(state.outputSizeBytes ?? 0)),
            ],
          ),
        ),

        // Actions row
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: state.extractedText ?? ''));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Text copied to clipboard'), backgroundColor: Colors.green),
                    );
                  },
                  icon: const Icon(Icons.copy_rounded, size: 18),
                  label: const Text('Copy All'),
                  style: OutlinedButton.styleFrom(foregroundColor: _primaryBlue, padding: const EdgeInsets.symmetric(vertical: 12)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    if (state.outputFilePath != null) {
                      Share.shareXFiles([XFile(state.outputFilePath!)], text: 'Extracted text');
                    }
                  },
                  icon: const Icon(Icons.share_rounded, size: 18),
                  label: const Text('Share'),
                  style: OutlinedButton.styleFrom(foregroundColor: _primaryBlue, padding: const EdgeInsets.symmetric(vertical: 12)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => notifier.reset(),
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('New'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Text preview
        Expanded(
          child: Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.darkSurface : _cardColor,
              borderRadius: BorderRadius.circular(AppTheme.radiusL),
              border: Border.all(color: isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0)),
            ),
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: SelectableText(
                state.extractedText ?? '',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
                      height: 1.6,
                      fontFamily: 'monospace',
                    ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStat(BuildContext context, bool isDark, IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: _primaryBlue),
        const SizedBox(width: 6),
        Text(label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
                )),
      ],
    );
  }
}
