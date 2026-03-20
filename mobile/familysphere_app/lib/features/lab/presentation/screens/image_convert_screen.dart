import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:familysphere_app/core/theme/app_theme.dart';
import 'package:familysphere_app/features/lab/presentation/providers/image_convert_provider.dart';
import 'package:familysphere_app/features/lab/domain/services/image_convert_service.dart';
import 'package:familysphere_app/features/lab/domain/services/lab_file_manager.dart';

class ImageConvertScreen extends ConsumerWidget {
  const ImageConvertScreen({super.key});

  static const Color _primaryBlue = Color(0xFF2563EB);
  static const Color _pageBackground = Color(0xFFF6F7F8);
  static const Color _cardColor = Colors.white;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final state = ref.watch(imageConvertProvider);
    final notifier = ref.read(imageConvertProvider.notifier);

    ref.listen<ImgConvertState>(imageConvertProvider, (prev, next) {
      if (prev?.status != next.status) {
        if (next.status == ImgConvertStatus.success) {
          _showSuccessSheet(context, next, notifier, isDark);
        } else if (next.status == ImgConvertStatus.error && next.errorMessage != null) {
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
        title: Text('Convert Image', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary)),
        actions: [Padding(padding: const EdgeInsets.only(right: 12), child: Icon(Icons.transform_rounded, color: _primaryBlue, size: 24))],
      ),
      body: Stack(children: [
        SingleChildScrollView(physics: const BouncingScrollPhysics(), child: Column(children: [
          _buildInstructionCard(context, isDark),
          _buildPickButton(context, isDark, state, notifier),
          if (state.inputFile != null) ...[
            _buildFileInfo(context, isDark, state),
            _buildFormatSelector(context, isDark, state, notifier),
          ] else
            _buildEmptyState(context, isDark),
          const SizedBox(height: 120),
        ])),
        if (state.status == ImgConvertStatus.converting) _buildProgressOverlay(context, isDark, state),
      ]),
      bottomNavigationBar: _buildBottomButton(context, isDark, state, notifier),
    );
  }

  Widget _buildInstructionCard(BuildContext context, bool isDark) {
    return Padding(padding: const EdgeInsets.all(16), child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: isDark ? _primaryBlue.withOpacity(0.15) : _primaryBlue.withOpacity(0.08), borderRadius: BorderRadius.circular(AppTheme.radiusL), border: Border.all(color: _primaryBlue.withOpacity(0.2))),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(padding: const EdgeInsets.only(top: 2), child: Icon(Icons.info_outline_rounded, color: _primaryBlue, size: 22)),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Convert image format', style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700, color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary)),
          const SizedBox(height: 4),
          Text('Convert between JPG, PNG, and BMP formats. Processing is done locally.', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary, height: 1.4)),
        ])),
      ]),
    ));
  }

  Widget _buildPickButton(BuildContext context, bool isDark, ImgConvertState state, ImgConvertNotifier notifier) {
    return Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4), child: Material(color: Colors.transparent, child: InkWell(
      onTap: state.isProcessing ? null : () => notifier.pickFile(), borderRadius: BorderRadius.circular(AppTheme.radiusL),
      child: Container(width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(color: isDark ? AppTheme.darkSurface : _cardColor, borderRadius: BorderRadius.circular(AppTheme.radiusL), border: Border.all(color: _primaryBlue.withOpacity(0.4), width: 2)),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.add_circle_rounded, color: _primaryBlue, size: 24), const SizedBox(width: 8),
          Text(state.inputFile != null ? 'Change Image' : 'Select Image', style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold, color: _primaryBlue)),
        ]),
      ),
    )));
  }

  Widget _buildFileInfo(BuildContext context, bool isDark, ImgConvertState state) {
    return Padding(padding: const EdgeInsets.fromLTRB(16, 16, 16, 0), child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: isDark ? AppTheme.darkSurface : _cardColor, borderRadius: BorderRadius.circular(AppTheme.radiusL), border: Border.all(color: isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0))),
      child: Row(children: [
        Container(width: 44, height: 44, decoration: BoxDecoration(color: const Color(0xFFDBEAFE), borderRadius: BorderRadius.circular(AppTheme.radiusM)),
          child: const Center(child: Icon(Icons.image_rounded, color: Color(0xFF2563EB), size: 24))),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(state.inputFileName ?? '', style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold, color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary), maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 2),
          Text('${state.sourceFormat ?? "?"} • ${LabFileManager.formatFileSize(state.inputSizeBytes)}', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: isDark ? AppTheme.darkTextSecondary : AppTheme.textTertiary)),
        ])),
      ]),
    ));
  }

  Widget _buildFormatSelector(BuildContext context, bool isDark, ImgConvertState state, ImgConvertNotifier notifier) {
    return Padding(padding: const EdgeInsets.fromLTRB(16, 20, 16, 0), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('TARGET FORMAT', style: Theme.of(context).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold, letterSpacing: 1.0, color: isDark ? AppTheme.darkTextSecondary : AppTheme.textTertiary)),
      const SizedBox(height: 12),
      ...ConvertFormat.values.map((fmt) {
        final isSelected = state.targetFormat == fmt;
        return Padding(padding: const EdgeInsets.only(bottom: 8), child: Material(color: Colors.transparent, child: InkWell(
          onTap: state.isProcessing ? null : () => notifier.setTargetFormat(fmt), borderRadius: BorderRadius.circular(AppTheme.radiusL),
          child: Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(color: isDark ? AppTheme.darkSurface : _cardColor, borderRadius: BorderRadius.circular(AppTheme.radiusL),
              border: Border.all(color: isSelected ? _primaryBlue : (isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0)), width: isSelected ? 2 : 1)),
            child: Row(children: [
              Text(fmt.label, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: isSelected ? FontWeight.bold : FontWeight.w500, color: isSelected ? _primaryBlue : (isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary))),
              const Spacer(),
              if (isSelected) Icon(Icons.check_circle_rounded, color: _primaryBlue, size: 22),
            ]),
          ),
        )));
      }),
    ]));
  }

  Widget _buildEmptyState(BuildContext context, bool isDark) {
    return Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 40), child: Center(child: Column(children: [
      Container(width: 72, height: 72, decoration: BoxDecoration(color: isDark ? AppTheme.darkSurface : _primaryBlue.withOpacity(0.08), shape: BoxShape.circle),
        child: Icon(Icons.transform_rounded, size: 36, color: isDark ? AppTheme.darkTextSecondary : AppTheme.textTertiary)),
      const SizedBox(height: 16),
      Text('No image selected', style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600, color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary)),
    ])));
  }

  Widget _buildProgressOverlay(BuildContext context, bool isDark, ImgConvertState state) {
    return Container(color: (isDark ? Colors.black : Colors.white).withOpacity(0.85), child: Center(child: Container(
      margin: const EdgeInsets.symmetric(horizontal: 40), padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(color: isDark ? AppTheme.darkSurface : _cardColor, borderRadius: BorderRadius.circular(20)),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        SizedBox(width: 56, height: 56, child: CircularProgressIndicator(value: state.progress > 0.1 ? state.progress : null, strokeWidth: 4, color: _primaryBlue)),
        const SizedBox(height: 20),
        Text(state.progressMessage.isNotEmpty ? state.progressMessage : 'Converting...', style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600), textAlign: TextAlign.center),
      ]),
    )));
  }

  Widget _buildBottomButton(BuildContext context, bool isDark, ImgConvertState state, ImgConvertNotifier notifier) {
    final canProcess = state.canConvert;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      decoration: BoxDecoration(color: isDark ? AppTheme.darkBackground.withOpacity(0.85) : Colors.white.withOpacity(0.85), border: Border(top: BorderSide(color: isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0)))),
      child: SafeArea(top: false, child: SizedBox(width: double.infinity, height: 56, child: ElevatedButton(
        onPressed: canProcess ? () => notifier.startConvert() : null,
        style: ElevatedButton.styleFrom(backgroundColor: _primaryBlue, disabledBackgroundColor: _primaryBlue.withOpacity(0.4), foregroundColor: Colors.white, elevation: canProcess ? 4 : 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusL))),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.transform_rounded, size: 22), const SizedBox(width: 10),
          Text('CONVERT IMAGE', style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold, color: canProcess ? Colors.white : Colors.white.withOpacity(0.6), letterSpacing: 1.0)),
        ]),
      ))),
    );
  }

  void _showSuccessSheet(BuildContext context, ImgConvertState state, ImgConvertNotifier notifier, bool isDark) {
    showModalBottomSheet(context: context, isDismissible: false, enableDrag: false, backgroundColor: isDark ? AppTheme.darkSurface : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 64, height: 64, decoration: BoxDecoration(color: Colors.green.withOpacity(0.12), shape: BoxShape.circle), child: const Icon(Icons.check_circle_rounded, color: Colors.green, size: 40)),
        const SizedBox(height: 16),
        Text('Image Converted!', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text('${state.sourceFormat} → ${state.targetFormat.label}  •  ${LabFileManager.formatFileSize(state.outputSizeBytes ?? 0)}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary)),
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
