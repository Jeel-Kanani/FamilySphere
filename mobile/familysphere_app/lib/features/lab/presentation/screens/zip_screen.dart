import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:familysphere_app/core/theme/app_theme.dart';
import 'package:familysphere_app/features/lab/presentation/providers/zip_provider.dart';
import 'package:familysphere_app/features/lab/domain/services/lab_file_manager.dart';

class ZipScreen extends ConsumerWidget {
  const ZipScreen({super.key});

  static const Color _primaryBlue = Color(0xFF2563EB);
  static const Color _pageBackground = Color(0xFFF6F7F8);
  static const Color _cardColor = Colors.white;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final state = ref.watch(zipProvider);
    final notifier = ref.read(zipProvider.notifier);

    ref.listen<ZipState>(zipProvider, (prev, next) {
      if (prev?.status != next.status) {
        if (next.status == ZipStatus.success) {
          _showSuccessSheet(context, next, notifier, isDark);
        } else if (next.status == ZipStatus.error && next.errorMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(next.errorMessage!), backgroundColor: Colors.red));
          notifier.dismissError();
        }
      }
    });

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBackground : _pageBackground,
      appBar: AppBar(
        backgroundColor: isDark ? AppTheme.darkBackground : _pageBackground, surfaceTintColor: Colors.transparent, elevation: 0,
        leading: IconButton(icon: Icon(Icons.arrow_back_rounded, color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary), onPressed: () => Navigator.pop(context)),
        title: Text('Zip / Unzip', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary)),
        actions: [Padding(padding: const EdgeInsets.only(right: 12), child: Icon(Icons.folder_zip_rounded, color: _primaryBlue, size: 24))],
      ),
      body: Stack(children: [
        SingleChildScrollView(physics: const BouncingScrollPhysics(), child: Column(children: [
          _buildModeToggle(context, isDark, state, notifier),
          _buildInstructionCard(context, isDark, state),
          _buildPickButton(context, isDark, state, notifier),
          if (state.mode == ZipMode.zip && state.inputFiles.isNotEmpty)
            _buildFileList(context, isDark, state)
          else if (state.mode == ZipMode.unzip && state.archiveFile != null)
            _buildArchiveInfo(context, isDark, state)
          else
            _buildEmptyState(context, isDark, state),
          const SizedBox(height: 120),
        ])),
        if (state.status == ZipStatus.processing) _buildProgressOverlay(context, isDark, state),
      ]),
      bottomNavigationBar: _buildBottomButton(context, isDark, state, notifier),
    );
  }

  Widget _buildModeToggle(BuildContext context, bool isDark, ZipState state, ZipNotifier notifier) {
    return Padding(padding: const EdgeInsets.fromLTRB(16, 8, 16, 0), child: Container(
      decoration: BoxDecoration(color: isDark ? AppTheme.darkSurface : _cardColor, borderRadius: BorderRadius.circular(AppTheme.radiusL), border: Border.all(color: isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0))),
      child: Row(children: [
        Expanded(child: GestureDetector(
          onTap: () => notifier.setMode(ZipMode.zip),
          child: Container(padding: const EdgeInsets.symmetric(vertical: 12), decoration: BoxDecoration(color: state.mode == ZipMode.zip ? _primaryBlue : Colors.transparent, borderRadius: BorderRadius.circular(AppTheme.radiusL)),
            child: Center(child: Text('Zip', style: TextStyle(fontWeight: FontWeight.bold, color: state.mode == ZipMode.zip ? Colors.white : (isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary))))),
        )),
        Expanded(child: GestureDetector(
          onTap: () => notifier.setMode(ZipMode.unzip),
          child: Container(padding: const EdgeInsets.symmetric(vertical: 12), decoration: BoxDecoration(color: state.mode == ZipMode.unzip ? _primaryBlue : Colors.transparent, borderRadius: BorderRadius.circular(AppTheme.radiusL)),
            child: Center(child: Text('Unzip', style: TextStyle(fontWeight: FontWeight.bold, color: state.mode == ZipMode.unzip ? Colors.white : (isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary))))),
        )),
      ]),
    ));
  }

  Widget _buildInstructionCard(BuildContext context, bool isDark, ZipState state) {
    final isZip = state.mode == ZipMode.zip;
    return Padding(padding: const EdgeInsets.all(16), child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: isDark ? _primaryBlue.withOpacity(0.15) : _primaryBlue.withOpacity(0.08), borderRadius: BorderRadius.circular(AppTheme.radiusL), border: Border.all(color: _primaryBlue.withOpacity(0.2))),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(Icons.info_outline_rounded, color: _primaryBlue, size: 22),
        const SizedBox(width: 14),
        Expanded(child: Text(
          isZip ? 'Select multiple files to compress into a single archive.' : 'Select an archive file to extract its contents.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary, height: 1.4),
        )),
      ]),
    ));
  }

  Widget _buildPickButton(BuildContext context, bool isDark, ZipState state, ZipNotifier notifier) {
    final isZip = state.mode == ZipMode.zip;
    return Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4), child: Material(color: Colors.transparent, child: InkWell(
      onTap: state.isProcessing ? null : () => notifier.pickFiles(), borderRadius: BorderRadius.circular(AppTheme.radiusL),
      child: Container(width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(color: isDark ? AppTheme.darkSurface : _cardColor, borderRadius: BorderRadius.circular(AppTheme.radiusL), border: Border.all(color: _primaryBlue.withOpacity(0.4), width: 2)),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.add_circle_rounded, color: _primaryBlue, size: 24), const SizedBox(width: 8),
          Text(isZip ? 'Select Files to Zip' : 'Select Archive to Unzip', style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold, color: _primaryBlue)),
        ]),
      ),
    )));
  }

  Widget _buildFileList(BuildContext context, bool isDark, ZipState state) {
    return Padding(padding: const EdgeInsets.fromLTRB(16, 16, 16, 0), child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: isDark ? AppTheme.darkSurface : _cardColor, borderRadius: BorderRadius.circular(AppTheme.radiusL), border: Border.all(color: isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('${state.inputFiles.length} files selected', style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold, color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary)),
        const SizedBox(height: 8),
        ...state.inputFileNames.take(10).map((name) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(children: [
            Icon(Icons.insert_drive_file_rounded, size: 16, color: isDark ? AppTheme.darkTextSecondary : AppTheme.textTertiary),
            const SizedBox(width: 8),
            Expanded(child: Text(name, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary), maxLines: 1, overflow: TextOverflow.ellipsis)),
          ]),
        )),
        if (state.inputFileNames.length > 10)
          Text('...and ${state.inputFileNames.length - 10} more', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: isDark ? AppTheme.darkTextSecondary : AppTheme.textTertiary)),
      ]),
    ));
  }

  Widget _buildArchiveInfo(BuildContext context, bool isDark, ZipState state) {
    return Padding(padding: const EdgeInsets.fromLTRB(16, 16, 16, 0), child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: isDark ? AppTheme.darkSurface : _cardColor, borderRadius: BorderRadius.circular(AppTheme.radiusL), border: Border.all(color: isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0))),
      child: Row(children: [
        Container(width: 44, height: 44, decoration: BoxDecoration(color: const Color(0xFFFEF3C7), borderRadius: BorderRadius.circular(AppTheme.radiusM)),
          child: const Center(child: Icon(Icons.folder_zip_rounded, color: Color(0xFFD97706), size: 24))),
        const SizedBox(width: 14),
        Expanded(child: Text(state.archiveFileName ?? '', style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold, color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary), maxLines: 1, overflow: TextOverflow.ellipsis)),
      ]),
    ));
  }

  Widget _buildEmptyState(BuildContext context, bool isDark, ZipState state) {
    return Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 40), child: Center(child: Column(children: [
      Container(width: 72, height: 72, decoration: BoxDecoration(color: isDark ? AppTheme.darkSurface : _primaryBlue.withOpacity(0.08), shape: BoxShape.circle),
        child: Icon(Icons.folder_zip_rounded, size: 36, color: isDark ? AppTheme.darkTextSecondary : AppTheme.textTertiary)),
      const SizedBox(height: 16),
      Text('No files selected', style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600, color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary)),
    ])));
  }

  Widget _buildProgressOverlay(BuildContext context, bool isDark, ZipState state) {
    return Container(color: (isDark ? Colors.black : Colors.white).withOpacity(0.85), child: Center(child: Container(
      margin: const EdgeInsets.symmetric(horizontal: 40), padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(color: isDark ? AppTheme.darkSurface : _cardColor, borderRadius: BorderRadius.circular(20)),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        SizedBox(width: 56, height: 56, child: CircularProgressIndicator(value: state.progress > 0.1 ? state.progress : null, strokeWidth: 4, color: _primaryBlue)),
        const SizedBox(height: 20),
        Text(state.progressMessage.isNotEmpty ? state.progressMessage : 'Processing...', style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600), textAlign: TextAlign.center),
      ]),
    )));
  }

  Widget _buildBottomButton(BuildContext context, bool isDark, ZipState state, ZipNotifier notifier) {
    final canProcess = state.canProcess;
    final isZip = state.mode == ZipMode.zip;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      decoration: BoxDecoration(color: isDark ? AppTheme.darkBackground.withOpacity(0.85) : Colors.white.withOpacity(0.85), border: Border(top: BorderSide(color: isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0)))),
      child: SafeArea(top: false, child: SizedBox(width: double.infinity, height: 56, child: ElevatedButton(
        onPressed: canProcess ? () => notifier.startProcess() : null,
        style: ElevatedButton.styleFrom(backgroundColor: _primaryBlue, disabledBackgroundColor: _primaryBlue.withOpacity(0.4), foregroundColor: Colors.white, elevation: canProcess ? 4 : 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusL))),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(isZip ? Icons.compress_rounded : Icons.unarchive_rounded, size: 22), const SizedBox(width: 10),
          Text(isZip ? 'CREATE ARCHIVE' : 'EXTRACT FILES', style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold, color: canProcess ? Colors.white : Colors.white.withOpacity(0.6), letterSpacing: 1.0)),
        ]),
      ))),
    );
  }

  void _showSuccessSheet(BuildContext context, ZipState state, ZipNotifier notifier, bool isDark) {
    final isZip = state.mode == ZipMode.zip;
    showModalBottomSheet(context: context, isDismissible: false, enableDrag: false, backgroundColor: isDark ? AppTheme.darkSurface : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 64, height: 64, decoration: BoxDecoration(color: Colors.green.withOpacity(0.12), shape: BoxShape.circle), child: const Icon(Icons.check_circle_rounded, color: Colors.green, size: 40)),
        const SizedBox(height: 16),
        Text(isZip ? 'Archive Created!' : 'Files Extracted!', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text('${state.fileCount ?? 0} files  •  ${LabFileManager.formatFileSize(state.outputSizeBytes ?? 0)}', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary)),
        const SizedBox(height: 24),
        SizedBox(width: double.infinity, child: ElevatedButton(
          onPressed: () { Navigator.pop(ctx); notifier.reset(); },
          style: ElevatedButton.styleFrom(backgroundColor: _primaryBlue, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusL))),
          child: const Text('Done', style: TextStyle(fontWeight: FontWeight.bold)),
        )),
      ])),
    );
  }
}
