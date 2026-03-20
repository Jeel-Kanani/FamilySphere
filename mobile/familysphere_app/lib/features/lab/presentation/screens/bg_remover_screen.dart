import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:familysphere_app/core/theme/app_theme.dart';
import 'package:familysphere_app/features/lab/presentation/providers/bg_remover_provider.dart';
import 'package:familysphere_app/features/lab/domain/services/lab_file_manager.dart';

class BgRemoverScreen extends ConsumerWidget {
  const BgRemoverScreen({super.key});

  static const Color _primaryBlue = Color(0xFF2563EB);
  static const Color _pageBackground = Color(0xFFF6F7F8);
  static const Color _cardColor = Colors.white;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final state = ref.watch(bgRemoverProvider);
    final notifier = ref.read(bgRemoverProvider.notifier);

    ref.listen<BgRemoverState>(bgRemoverProvider, (prev, next) {
      if (prev?.status != next.status) {
        if (next.status == BgRemoverStatus.success) {
          _showSuccessSheet(context, next, notifier, isDark);
        } else if (next.status == BgRemoverStatus.error && next.errorMessage != null) {
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
        title: Text('BG Remover', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary)),
        actions: [Padding(padding: const EdgeInsets.only(right: 12), child: Icon(Icons.auto_fix_high_rounded, color: _primaryBlue, size: 24))],
      ),
      body: Stack(children: [
        SingleChildScrollView(physics: const BouncingScrollPhysics(), child: Column(children: [
          _buildInstructionCard(context, isDark),
          _buildPickButton(context, isDark, state, notifier),
          if (state.inputFile != null) ...[
            _buildFileInfo(context, isDark, state),
            _buildToleranceSlider(context, isDark, state, notifier),
          ] else
            _buildEmptyState(context, isDark),
          const SizedBox(height: 120),
        ])),
        if (state.status == BgRemoverStatus.processing) _buildProgressOverlay(context, isDark, state),
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
          Text('Remove solid backgrounds', style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700, color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary)),
          const SizedBox(height: 4),
          Text('Detects and removes solid-color backgrounds (white, light gray, etc.) and replaces with transparency. Output is saved as PNG.', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary, height: 1.4)),
        ])),
      ]),
    ));
  }

  Widget _buildPickButton(BuildContext context, bool isDark, BgRemoverState state, BgRemoverNotifier notifier) {
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

  Widget _buildFileInfo(BuildContext context, bool isDark, BgRemoverState state) {
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
          Text(LabFileManager.formatFileSize(state.inputSizeBytes), style: Theme.of(context).textTheme.labelSmall?.copyWith(color: isDark ? AppTheme.darkTextSecondary : AppTheme.textTertiary)),
        ])),
      ]),
    ));
  }

  Widget _buildToleranceSlider(BuildContext context, bool isDark, BgRemoverState state, BgRemoverNotifier notifier) {
    return Padding(padding: const EdgeInsets.fromLTRB(16, 20, 16, 0), child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: isDark ? AppTheme.darkSurface : _cardColor, borderRadius: BorderRadius.circular(AppTheme.radiusL), border: Border.all(color: isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('Color Tolerance', style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold, color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary)),
          Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4), decoration: BoxDecoration(color: _primaryBlue.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
            child: Text('${state.tolerance}', style: TextStyle(color: _primaryBlue, fontWeight: FontWeight.bold))),
        ]),
        const SizedBox(height: 8),
        Slider(value: state.tolerance.toDouble(), min: 5, max: 100, divisions: 19, activeColor: _primaryBlue,
          onChanged: state.isProcessing ? null : (v) => notifier.setTolerance(v.round())),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('Precise', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: isDark ? AppTheme.darkTextSecondary : AppTheme.textTertiary)),
          Text('Aggressive', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: isDark ? AppTheme.darkTextSecondary : AppTheme.textTertiary)),
        ]),
      ]),
    ));
  }

  Widget _buildEmptyState(BuildContext context, bool isDark) {
    return Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 40), child: Center(child: Column(children: [
      Container(width: 72, height: 72, decoration: BoxDecoration(color: isDark ? AppTheme.darkSurface : _primaryBlue.withOpacity(0.08), shape: BoxShape.circle),
        child: Icon(Icons.auto_fix_high_rounded, size: 36, color: isDark ? AppTheme.darkTextSecondary : AppTheme.textTertiary)),
      const SizedBox(height: 16),
      Text('No image selected', style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600, color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary)),
    ])));
  }

  Widget _buildProgressOverlay(BuildContext context, bool isDark, BgRemoverState state) {
    return Container(color: (isDark ? Colors.black : Colors.white).withOpacity(0.85), child: Center(child: Container(
      margin: const EdgeInsets.symmetric(horizontal: 40), padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(color: isDark ? AppTheme.darkSurface : _cardColor, borderRadius: BorderRadius.circular(20)),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        SizedBox(width: 56, height: 56, child: CircularProgressIndicator(value: state.progress > 0.1 ? state.progress : null, strokeWidth: 4, color: _primaryBlue)),
        const SizedBox(height: 20),
        Text(state.progressMessage.isNotEmpty ? state.progressMessage : 'Removing background...', style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600), textAlign: TextAlign.center),
      ]),
    )));
  }

  Widget _buildBottomButton(BuildContext context, bool isDark, BgRemoverState state, BgRemoverNotifier notifier) {
    final canProcess = state.canProcess;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      decoration: BoxDecoration(color: isDark ? AppTheme.darkBackground.withOpacity(0.85) : Colors.white.withOpacity(0.85), border: Border(top: BorderSide(color: isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0)))),
      child: SafeArea(top: false, child: SizedBox(width: double.infinity, height: 56, child: ElevatedButton(
        onPressed: canProcess ? () => notifier.startRemoval() : null,
        style: ElevatedButton.styleFrom(backgroundColor: _primaryBlue, disabledBackgroundColor: _primaryBlue.withOpacity(0.4), foregroundColor: Colors.white, elevation: canProcess ? 4 : 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusL))),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.auto_fix_high_rounded, size: 22), const SizedBox(width: 10),
          Text('REMOVE BACKGROUND', style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold, color: canProcess ? Colors.white : Colors.white.withOpacity(0.6), letterSpacing: 1.0)),
        ]),
      ))),
    );
  }

  void _showSuccessSheet(BuildContext context, BgRemoverState state, BgRemoverNotifier notifier, bool isDark) {
    showModalBottomSheet(context: context, isDismissible: false, enableDrag: false, backgroundColor: isDark ? AppTheme.darkSurface : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 64, height: 64, decoration: BoxDecoration(color: Colors.green.withOpacity(0.12), shape: BoxShape.circle), child: const Icon(Icons.check_circle_rounded, color: Colors.green, size: 40)),
        const SizedBox(height: 16),
        Text('Background Removed!', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text('${state.pixelsRemoved ?? 0} pixels removed  •  ${LabFileManager.formatFileSize(state.outputSizeBytes ?? 0)}',
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
