import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:familysphere_app/core/theme/app_theme.dart';
import 'package:familysphere_app/features/lab/presentation/providers/protect_pdf_provider.dart';
import 'package:familysphere_app/features/lab/presentation/widgets/merge_result_sheet.dart';
import 'dart:io';

class ProtectPdfScreen extends ConsumerStatefulWidget {
  const ProtectPdfScreen({super.key});

  @override
  ConsumerState<ProtectPdfScreen> createState() => _ProtectPdfScreenState();
}

class _ProtectPdfScreenState extends ConsumerState<ProtectPdfScreen> {
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmController = TextEditingController();
  final TextEditingController _outputNameController = TextEditingController();
  
  final Color _primaryBlue = const Color(0xFF137FEC);
  bool _showPassword = false;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    _outputNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(protectPdfProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Sync controllers with state
    if (_outputNameController.text.isEmpty && state.outputFileName.isNotEmpty) {
      _outputNameController.text = state.outputFileName;
    }

    // Listen for success
    ref.listen(protectPdfProvider, (previous, next) {
      if (next.status == ProtectStatus.success && previous?.status != ProtectStatus.success) {
        if (next.outputFilePath != null) {
          MergeResultSheet.showSuccess(
            context,
            outputFilePath: next.outputFilePath!,
            outputSizeBytes: 0, // Not strictly required for display
            successTitle: 'PDF Protected!',
            onDone: () {
              ref.read(protectPdfProvider.notifier).reset();
              _passwordController.clear();
              _confirmController.clear();
              _outputNameController.clear();
            },
          );
        }
      }
    });

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBackground : const Color(0xFFF6F7F8),
      appBar: AppBar(
        title: const Text('Protect PDF', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: isDark ? AppTheme.darkSurface : Colors.white,
        foregroundColor: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
        elevation: 0,
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16, top: 12, bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: _primaryBlue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Center(
              child: Text(
                'LAB',
                style: TextStyle(
                  color: _primaryBlue,
                  fontWeight: FontWeight.bold,
                  fontSize: 10,
                  letterSpacing: 1.2,
                ),
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 120),
            child: Column(
              children: [
                _buildInfoCard(isDark),
                const SizedBox(height: 4),
                _buildFileSelection(isDark, state),
                if (state.selectedFile != null) ...[
                  const SizedBox(height: 16),
                  _buildPasswordCard(isDark, state),
                  const SizedBox(height: 16),
                  _buildSecurityOptionsCard(isDark, state),
                  const SizedBox(height: 16),
                  _buildOutputSettings(isDark, state),
                ],
                if (state.errorMessage != null)
                  _buildErrorBanner(isDark, state.errorMessage!),
              ],
            ),
          ),
          if (state.status == ProtectStatus.protecting) _buildProgressOverlay(isDark, state),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _buildBottomCTA(isDark, state),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(bool isDark) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _primaryBlue.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _primaryBlue.withOpacity(0.1)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _primaryBlue,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.security, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Secure Your PDF',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: isDark ? Colors.white : const Color(0xFF101922),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Add a password to protect your document from unauthorized access.',
                  style: TextStyle(
                    color: isDark ? AppTheme.darkTextSecondary : const Color(0xFF64748B),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFileSelection(bool isDark, ProtectPdfState state) {
    if (state.selectedFile == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: InkWell(
          onTap: () => ref.read(protectPdfProvider.notifier).pickFile(),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 24),
            decoration: BoxDecoration(
              color: _primaryBlue.withOpacity(0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _primaryBlue.withOpacity(0.3),
                style: BorderStyle.solid,
                width: 2,
              ),
            ),
            child: Column(
              children: [
                Icon(Icons.add_circle, color: _primaryBlue, size: 32),
                const SizedBox(height: 8),
                Text(
                  '+ Select PDF File',
                  style: TextStyle(
                    color: _primaryBlue,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 64,
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.05),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: Colors.red.withOpacity(0.1)),
            ),
            child: const Icon(Icons.picture_as_pdf, color: Color(0xFFEF4444), size: 32),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  state.selectedFile!.name,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${state.selectedFile!.sizeLabel} • ${state.selectedFile!.pageCount} pages',
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.grey, size: 20),
            onPressed: () => ref.read(protectPdfProvider.notifier).removeFile(),
          ),
        ],
      ),
    );
  }

  Widget _buildPasswordCard(bool isDark, ProtectPdfState state) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'PASSWORD SETUP',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Password',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF137FEC)),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _passwordController,
            obscureText: !_showPassword,
            onChanged: (val) => ref.read(protectPdfProvider.notifier).setPassword(val),
            style: const TextStyle(fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Enter password',
              filled: true,
              fillColor: isDark ? AppTheme.darkBackground : const Color(0xFFF8FAFC),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
              suffixIcon: IconButton(
                icon: Icon(
                  _showPassword ? Icons.visibility : Icons.visibility_off,
                  size: 20,
                  color: Colors.grey,
                ),
                onPressed: () => setState(() => _showPassword = !_showPassword),
              ),
            ),
          ),
          const SizedBox(height: 8),
          _buildStrengthIndicator(state.passwordStrength),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Strength: ${state.strengthLabel}',
                style: const TextStyle(fontSize: 10, color: Colors.grey),
              ),
              const Text(
                'Min. 6 characters',
                style: TextStyle(fontSize: 10, color: Colors.grey),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'Confirm Password',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _confirmController,
            obscureText: !_showPassword,
            onChanged: (val) => ref.read(protectPdfProvider.notifier).setConfirmPassword(val),
            style: const TextStyle(fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Repeat password',
              filled: true,
              fillColor: isDark ? AppTheme.darkBackground : const Color(0xFFF8FAFC),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStrengthIndicator(int strength) {
    return Row(
      children: List.generate(4, (index) {
        bool isActive = index < strength;
        Color color = Colors.grey.withOpacity(0.2);
        if (isActive) {
          if (strength == 1) color = Colors.red;
          else if (strength == 2) color = Colors.orange;
          else if (strength == 3) color = Colors.blue;
          else color = Colors.green;
        }
        return Expanded(
          child: Container(
            height: 4,
            margin: EdgeInsets.only(right: index == 3 ? 0 : 4),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildSecurityOptionsCard(bool isDark, ProtectPdfState state) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'SECURITY OPTIONS',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 16),
          _buildOptionToggle(
            'Allow Printing',
            'Restrict high-quality prints',
            state.allowPrinting,
            (val) => ref.read(protectPdfProvider.notifier).togglePrinting(val),
          ),
          const Divider(height: 24),
          _buildOptionToggle(
            'Allow Copy Text',
            'Restrict clipboard copying',
            state.allowCopyContent,
            (val) => ref.read(protectPdfProvider.notifier).toggleCopying(val),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Icon(Icons.info_outline, size: 14, color: Colors.grey),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'These settings apply after opening the PDF with the correct password.',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.withOpacity(0.7),
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOptionToggle(String title, String subtitle, bool value, Function(bool) onChanged) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ],
          ),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeColor: _primaryBlue,
        ),
      ],
    );
  }

  Widget _buildOutputSettings(bool isDark, ProtectPdfState state) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'OUTPUT SETTINGS',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Output File Name',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _outputNameController,
            onChanged: (val) => ref.read(protectPdfProvider.notifier).setOutputName(val),
            style: const TextStyle(fontSize: 14),
            decoration: InputDecoration(
              filled: true,
              fillColor: isDark ? AppTheme.darkBackground : const Color(0xFFF8FAFC),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.check_circle, size: 14, color: Color(0xFF137FEC)),
              const SizedBox(width: 8),
              const Text(
                'Original file will not be changed.',
                style: TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBottomCTA(bool isDark, ProtectPdfState state) {
    final bool canProtect = state.canProtect;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.withOpacity(0.1))),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: ElevatedButton(
          onPressed: canProtect ? () => ref.read(protectPdfProvider.notifier).startProtect() : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: _primaryBlue,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 60),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: canProtect ? 8 : 0,
            shadowColor: _primaryBlue.withOpacity(0.3),
            disabledBackgroundColor: _primaryBlue.withOpacity(0.5),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock, size: 20),
              const SizedBox(width: 12),
              const Text(
                'PROTECT PDF',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 0.5),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorBanner(bool isDark, String message) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: Colors.red, fontSize: 13),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18, color: Colors.red),
            onPressed: () => ref.read(protectPdfProvider.notifier).dismissError(),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressOverlay(bool isDark, ProtectPdfState state) {
    return Container(
      color: Colors.black.withOpacity(0.6),
      child: Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 32),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkSurface : Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF137FEC)),
              ),
              const SizedBox(height: 24),
              const Text(
                'Protecting PDF...',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              const SizedBox(height: 8),
              Text(
                state.progressMessage,
                style: const TextStyle(color: Colors.grey, fontSize: 14),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => ref.read(protectPdfProvider.notifier).cancelProtect(),
                  child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
