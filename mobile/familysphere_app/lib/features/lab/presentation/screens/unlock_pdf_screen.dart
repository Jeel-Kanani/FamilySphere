import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:familysphere_app/core/theme/app_theme.dart';
import 'package:familysphere_app/features/lab/presentation/providers/unlock_pdf_provider.dart';
import 'package:familysphere_app/features/lab/presentation/widgets/merge_result_sheet.dart';

class UnlockPdfScreen extends ConsumerStatefulWidget {
  const UnlockPdfScreen({super.key});

  @override
  ConsumerState<UnlockPdfScreen> createState() => _UnlockPdfScreenState();
}

class _UnlockPdfScreenState extends ConsumerState<UnlockPdfScreen> {
  static const Color _primaryBlue = Color(0xFF137FEC);
  static const Color _pageBackground = Color(0xFFF6F7F8);
  
  late final TextEditingController _outputNameController;
  late final TextEditingController _passwordController;

  @override
  void initState() {
    super.initState();
    _outputNameController = TextEditingController();
    _passwordController = TextEditingController();
  }

  @override
  void dispose() {
    _outputNameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final state = ref.watch(unlockPdfProvider);
    final notifier = ref.read(unlockPdfProvider.notifier);

    // Sync controllers with state
    if (_outputNameController.text != state.outputFileName && state.outputFileName.isNotEmpty) {
      _outputNameController.text = state.outputFileName;
    }
    if (_passwordController.text != state.password) {
      _passwordController.text = state.password;
    }

    // Listen for status changes
    ref.listen<UnlockPdfState>(unlockPdfProvider, (prev, next) {
      if (prev?.status != next.status) {
        if (next.status == UnlockStatus.success && next.outputFilePath != null) {
          MergeResultSheet.showSuccess(
            context,
            outputFilePath: next.outputFilePath!,
            outputSizeBytes: next.outputSizeBytes ?? 0,
            onDone: () => notifier.reset(),
            successTitle: 'PDF Unlocked!',
          );
        } else if (next.status == UnlockStatus.error && next.errorMessage != null) {
          MergeResultSheet.showError(
            context,
            errorMessage: next.errorMessage!,
            errorTitle: 'Unlock Failed',
            onRetry: () => notifier.startUnlock(),
            onDone: () => notifier.dismissError(),
          );
        }
      }
    });

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBackground : _pageBackground,
      appBar: AppBar(
        backgroundColor: isDark ? AppTheme.darkBackground : _pageBackground,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_rounded,
            color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Unlock PDF',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
              ),
        ),
        centerTitle: false,
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildInstructionCard(isDark),
                  const SizedBox(height: 24),
                  if (state.selectedFile == null)
                    _buildFilePickerAction(isDark, state)
                  else
                    _buildSelectedFileCard(isDark, state),
                  const SizedBox(height: 24),
                  _buildPasswordSection(isDark, state),
                  const SizedBox(height: 24),
                  _buildOutputSettings(isDark, state),
                  const SizedBox(height: 32),
                  _buildOfflineBadge(isDark),
                  const SizedBox(height: 100), // Bottom padding for CTA
                ],
              ),
            ),
          ),
          
          if (state.status == UnlockStatus.unlocking)
            _buildProgressOverlay(isDark, state),
        ],
      ),
      bottomNavigationBar: _buildBottomButton(context, isDark, state),
    );
  }

  Widget _buildInstructionCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusL),
        border: Border.all(
          color: isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _primaryBlue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppTheme.radiusM),
            ),
            child: const Icon(Icons.lock_open_rounded, color: _primaryBlue, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Remove PDF Password',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Unlock your PDF using its password. All processing happens locally on your device.',
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
    );
  }

  Widget _buildFilePickerAction(bool isDark, UnlockPdfState state) {
    return InkWell(
      onTap: state.isProcessing ? null : () => ref.read(unlockPdfProvider.notifier).pickFile(),
      borderRadius: BorderRadius.circular(AppTheme.radiusL),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 40),
        decoration: BoxDecoration(
          color: _primaryBlue.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(AppTheme.radiusL),
          border: Border.all(
            color: _primaryBlue.withValues(alpha: 0.3),
            width: 2,
            style: BorderStyle.solid, // Replaced dashed with solid as per app style
          ),
        ),
        child: Column(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: _primaryBlue,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: _primaryBlue.withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(Icons.add_rounded, color: Colors.white, size: 32),
            ),
            const SizedBox(height: 12),
            const Text(
              '+ Select Locked PDF',
              style: TextStyle(
                color: _primaryBlue,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectedFileCard(bool isDark, UnlockPdfState state) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusL),
        border: Border.all(
          color: isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0),
        ),
      ),
      child: Row(
        children: [
          Stack(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppTheme.radiusM),
                ),
                child: const Icon(Icons.picture_as_pdf_rounded, color: Colors.red, size: 28),
              ),
              Positioned(
                bottom: -2,
                right: -2,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: Colors.amber,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: const Icon(Icons.lock_rounded, color: Colors.white, size: 10),
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  state.selectedFile?.name ?? '',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  state.selectedFile?.sizeLabel ?? '',
                  style: TextStyle(
                    color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 20),
            onPressed: () => ref.read(unlockPdfProvider.notifier).removeFile(),
          ),
        ],
      ),
    );
  }

  Widget _buildPasswordSection(bool isDark, UnlockPdfState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            'PDF Password',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkSurface : Colors.white,
            borderRadius: BorderRadius.circular(AppTheme.radiusL),
            border: Border.all(
              color: isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0),
            ),
          ),
          child: TextField(
            controller: _passwordController,
            obscureText: !state.isPasswordVisible,
            onChanged: (val) => ref.read(unlockPdfProvider.notifier).setPassword(val),
            style: const TextStyle(fontWeight: FontWeight.w500),
            decoration: InputDecoration(
              hintText: '••••••••',
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              suffixIcon: IconButton(
                icon: Icon(
                  state.isPasswordVisible ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                  color: isDark ? AppTheme.darkTextSecondary : AppTheme.textTertiary,
                ),
                onPressed: () => ref.read(unlockPdfProvider.notifier).togglePasswordVisibility(),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            const Icon(Icons.verified_user_rounded, color: Colors.green, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Your password is never stored or sent to any server.',
                style: TextStyle(
                  color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildOutputSettings(bool isDark, UnlockPdfState state) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusL),
        border: Border.all(
          color: isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Output File Name',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.darkBackground : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(AppTheme.radiusM),
              border: Border.all(
                color: isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0),
              ),
            ),
            child: TextField(
              controller: _outputNameController,
              onChanged: (val) => ref.read(unlockPdfProvider.notifier).setOutputName(val),
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              decoration: const InputDecoration(
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_rounded, 
                  color: isDark ? AppTheme.darkTextSecondary : AppTheme.textTertiary, 
                  size: 16),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Original file will not be changed. A new unlocked copy will be created in your downloads.',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOfflineBadge(bool isDark) {
    return Center(
      child: Column(
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.wifi_off_rounded, 
                   color: isDark ? AppTheme.darkTextSecondary.withValues(alpha: 0.5) : AppTheme.textTertiary, 
                   size: 14),
              const SizedBox(width: 6),
              Text(
                'FULLY OFFLINE MODE',
                style: TextStyle(
                  color: isDark ? AppTheme.darkTextSecondary.withValues(alpha: 0.5) : AppTheme.textTertiary,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'FAMILY SPHERE – LAB UTILITY • SECURE LOCAL PROCESSING',
            style: TextStyle(
              color: isDark ? AppTheme.darkTextSecondary.withValues(alpha: 0.3) : AppTheme.textTertiary.withValues(alpha: 0.5),
              fontSize: 8,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomButton(BuildContext context, bool isDark, UnlockPdfState state) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, MediaQuery.of(context).padding.bottom + 16),
      child: Material(
        color: state.canUnlock ? _primaryBlue : (isDark ? AppTheme.darkBorder : AppTheme.borderColor),
        borderRadius: BorderRadius.circular(AppTheme.radiusXL),
        elevation: state.canUnlock ? 8 : 0,
        shadowColor: _primaryBlue.withValues(alpha: 0.3),
        child: InkWell(
          onTap: state.canUnlock ? () => ref.read(unlockPdfProvider.notifier).startUnlock() : null,
          borderRadius: BorderRadius.circular(AppTheme.radiusXL),
          child: Container(
            height: 56,
            width: double.infinity,
            alignment: Alignment.center,
            child: state.isProcessing
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
                  )
                : const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.lock_open_rounded, color: Colors.white, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'UNLOCK PDF',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildProgressOverlay(bool isDark, UnlockPdfState state) {
    return Container(
      color: Colors.black.withValues(alpha: 0.3),
      width: double.infinity,
      height: double.infinity,
      child: Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 40),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkSurface : Colors.white,
            borderRadius: BorderRadius.circular(AppTheme.radiusXL),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(
                value: state.progress,
                backgroundColor: _primaryBlue.withValues(alpha: 0.1),
                color: _primaryBlue,
              ),
              const SizedBox(height: 20),
              Text(
                state.statusLabel,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                '${(state.progress * 100).toInt()}%',
                style: const TextStyle(color: _primaryBlue, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => ref.read(unlockPdfProvider.notifier).cancel(),
                child: const Text('Cancel', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
