import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:familysphere_app/core/theme/app_theme.dart';
import 'package:familysphere_app/features/lab/presentation/providers/batch_rename_provider.dart';
import 'package:familysphere_app/features/lab/domain/services/batch_rename_service.dart';

class BatchRenameScreen extends ConsumerWidget {
  const BatchRenameScreen({super.key});

  static const Color _primaryBlue = Color(0xFF2563EB);
  static const Color _pageBackground = Color(0xFFF6F7F8);
  static const Color _cardColor = Colors.white;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final state = ref.watch(batchRenameProvider);
    final notifier = ref.read(batchRenameProvider.notifier);

    ref.listen<BatchRenameState>(batchRenameProvider, (prev, next) {
      if (prev?.status != next.status) {
        if (next.status == BatchRenameStatus.success) {
          _showSuccessSheet(context, next, notifier, isDark);
        } else if (next.status == BatchRenameStatus.error && next.errorMessage != null) {
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
        title: Text('Batch Rename', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary)),
        actions: [Padding(padding: const EdgeInsets.only(right: 12), child: Icon(Icons.drive_file_rename_outline_rounded, color: _primaryBlue, size: 24))],
      ),
      body: Stack(children: [
        SingleChildScrollView(physics: const BouncingScrollPhysics(), child: Column(children: [
          _buildPickButton(context, isDark, state, notifier),
          if (state.files.isNotEmpty) ...[
            _buildModeSelector(context, isDark, state, notifier),
            _buildModeConfig(context, isDark, state, notifier),
            if (state.previews.isNotEmpty) _buildPreview(context, isDark, state),
          ] else
            _buildEmptyState(context, isDark),
          const SizedBox(height: 120),
        ])),
        if (state.status == BatchRenameStatus.processing) _buildProgressOverlay(context, isDark, state),
      ]),
      bottomNavigationBar: _buildBottomButton(context, isDark, state, notifier),
    );
  }

  Widget _buildPickButton(BuildContext context, bool isDark, BatchRenameState state, BatchRenameNotifier notifier) {
    return Padding(padding: const EdgeInsets.all(16), child: Material(color: Colors.transparent, child: InkWell(
      onTap: state.isProcessing ? null : () => notifier.pickFiles(), borderRadius: BorderRadius.circular(AppTheme.radiusL),
      child: Container(width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(color: isDark ? AppTheme.darkSurface : _cardColor, borderRadius: BorderRadius.circular(AppTheme.radiusL), border: Border.all(color: _primaryBlue.withOpacity(0.4), width: 2)),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.add_circle_rounded, color: _primaryBlue, size: 24), const SizedBox(width: 8),
          Text(state.files.isNotEmpty ? 'Change Files (${state.files.length})' : 'Select Files', style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold, color: _primaryBlue)),
        ]),
      ),
    )));
  }

  Widget _buildModeSelector(BuildContext context, bool isDark, BatchRenameState state, BatchRenameNotifier notifier) {
    return Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('RENAME MODE', style: Theme.of(context).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold, letterSpacing: 1.0, color: isDark ? AppTheme.darkTextSecondary : AppTheme.textTertiary)),
      const SizedBox(height: 8),
      Wrap(spacing: 8, children: RenameMode.values.map((m) {
        final isSelected = state.mode == m;
        return ChoiceChip(label: Text(m.label), selected: isSelected, onSelected: (_) => notifier.setMode(m),
          selectedColor: _primaryBlue, labelStyle: TextStyle(color: isSelected ? Colors.white : (isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary), fontWeight: isSelected ? FontWeight.bold : FontWeight.normal));
      }).toList()),
    ]));
  }

  Widget _buildModeConfig(BuildContext context, bool isDark, BatchRenameState state, BatchRenameNotifier notifier) {
    return Padding(padding: const EdgeInsets.fromLTRB(16, 16, 16, 0), child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: isDark ? AppTheme.darkSurface : _cardColor, borderRadius: BorderRadius.circular(AppTheme.radiusL), border: Border.all(color: isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0))),
      child: Column(children: [
        if (state.mode == RenameMode.addPrefix)
          TextField(decoration: const InputDecoration(labelText: 'Prefix', hintText: 'e.g. photo_'), onChanged: notifier.setPrefix),
        if (state.mode == RenameMode.addSuffix)
          TextField(decoration: const InputDecoration(labelText: 'Suffix', hintText: 'e.g. _final'), onChanged: notifier.setSuffix),
        if (state.mode == RenameMode.findReplace) ...[
          TextField(decoration: const InputDecoration(labelText: 'Find', hintText: 'Text to find'), onChanged: notifier.setFindText),
          const SizedBox(height: 12),
          TextField(decoration: const InputDecoration(labelText: 'Replace with', hintText: 'Replacement text'), onChanged: notifier.setReplaceText),
        ],
        if (state.mode == RenameMode.numbering) ...[
          TextField(decoration: const InputDecoration(labelText: 'Prefix', hintText: 'e.g. photo'), onChanged: notifier.setNumberPrefix),
          const SizedBox(height: 12),
          TextField(decoration: const InputDecoration(labelText: 'Start number', hintText: '1'),
            keyboardType: TextInputType.number, onChanged: (v) => notifier.setStartNumber(int.tryParse(v) ?? 1)),
        ],
      ]),
    ));
  }

  Widget _buildPreview(BuildContext context, bool isDark, BatchRenameState state) {
    return Padding(padding: const EdgeInsets.fromLTRB(16, 16, 16, 0), child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: isDark ? AppTheme.darkSurface : _cardColor, borderRadius: BorderRadius.circular(AppTheme.radiusL), border: Border.all(color: isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('PREVIEW', style: Theme.of(context).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold, letterSpacing: 1.0, color: isDark ? AppTheme.darkTextSecondary : AppTheme.textTertiary)),
        const SizedBox(height: 12),
        ...state.previews.take(10).map((p) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(children: [
            Expanded(child: Text(p.originalName, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: isDark ? AppTheme.darkTextSecondary : AppTheme.textTertiary, decoration: TextDecoration.lineThrough), maxLines: 1, overflow: TextOverflow.ellipsis)),
            const Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Icon(Icons.arrow_forward_rounded, size: 14)),
            Expanded(child: Text(p.newName, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: _primaryBlue, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis)),
          ]),
        )),
        if (state.previews.length > 10) Text('...and ${state.previews.length - 10} more', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: isDark ? AppTheme.darkTextSecondary : AppTheme.textTertiary)),
      ]),
    ));
  }

  Widget _buildEmptyState(BuildContext context, bool isDark) {
    return Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 40), child: Center(child: Column(children: [
      Container(width: 72, height: 72, decoration: BoxDecoration(color: isDark ? AppTheme.darkSurface : _primaryBlue.withOpacity(0.08), shape: BoxShape.circle),
        child: Icon(Icons.drive_file_rename_outline_rounded, size: 36, color: isDark ? AppTheme.darkTextSecondary : AppTheme.textTertiary)),
      const SizedBox(height: 16),
      Text('No files selected', style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600, color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary)),
      const SizedBox(height: 6),
      Text('Select files to rename in batch', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: isDark ? AppTheme.darkTextSecondary : AppTheme.textTertiary)),
    ])));
  }

  Widget _buildProgressOverlay(BuildContext context, bool isDark, BatchRenameState state) {
    return Container(color: (isDark ? Colors.black : Colors.white).withOpacity(0.85), child: Center(child: Container(
      margin: const EdgeInsets.symmetric(horizontal: 40), padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(color: isDark ? AppTheme.darkSurface : _cardColor, borderRadius: BorderRadius.circular(20)),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        SizedBox(width: 56, height: 56, child: CircularProgressIndicator(value: state.progress > 0.1 ? state.progress : null, strokeWidth: 4, color: _primaryBlue)),
        const SizedBox(height: 20),
        Text('Renaming files...', style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
      ]),
    )));
  }

  Widget _buildBottomButton(BuildContext context, bool isDark, BatchRenameState state, BatchRenameNotifier notifier) {
    final canProcess = state.canProcess;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      decoration: BoxDecoration(color: isDark ? AppTheme.darkBackground.withOpacity(0.85) : Colors.white.withOpacity(0.85), border: Border(top: BorderSide(color: isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0)))),
      child: SafeArea(top: false, child: SizedBox(width: double.infinity, height: 56, child: ElevatedButton(
        onPressed: canProcess ? () => notifier.applyRenames() : null,
        style: ElevatedButton.styleFrom(backgroundColor: _primaryBlue, disabledBackgroundColor: _primaryBlue.withOpacity(0.4), foregroundColor: Colors.white, elevation: canProcess ? 4 : 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusL))),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.check_rounded, size: 22), const SizedBox(width: 10),
          Text('APPLY RENAMES', style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold, color: canProcess ? Colors.white : Colors.white.withOpacity(0.6), letterSpacing: 1.0)),
        ]),
      ))),
    );
  }

  void _showSuccessSheet(BuildContext context, BatchRenameState state, BatchRenameNotifier notifier, bool isDark) {
    showModalBottomSheet(context: context, isDismissible: false, enableDrag: false, backgroundColor: isDark ? AppTheme.darkSurface : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 64, height: 64, decoration: BoxDecoration(color: Colors.green.withOpacity(0.12), shape: BoxShape.circle), child: const Icon(Icons.check_circle_rounded, color: Colors.green, size: 40)),
        const SizedBox(height: 16),
        Text('Files Renamed!', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text('${state.filesRenamed ?? 0} files renamed successfully', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary)),
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
