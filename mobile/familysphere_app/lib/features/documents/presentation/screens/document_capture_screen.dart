import 'dart:io';
import 'package:flutter/material.dart';
import 'package:familysphere_app/core/services/document_scanner_service.dart';
import 'package:familysphere_app/core/theme/app_theme.dart';
import 'package:familysphere_app/core/utils/routes.dart';
import 'package:flutter/services.dart';

class DocumentCaptureScreen extends StatefulWidget {
  final bool returnOnly;
  final String? initialCategory;
  final String? initialFolder;
  final String? initialMemberId;

  const DocumentCaptureScreen({
    super.key,
    this.returnOnly = false,
    this.initialCategory,
    this.initialFolder,
    this.initialMemberId,
  });

  @override
  State<DocumentCaptureScreen> createState() => _DocumentCaptureScreenState();
}

class _DocumentCaptureScreenState extends State<DocumentCaptureScreen> {
  final List<String> _imagePaths = [];
  bool _isBusy = false;

  @override
  void initState() {
    super.initState();
    // Start scanning immediately when screen opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startScanning();
    });
  }

  Future<void> _startScanning() async {
    setState(() => _isBusy = true);
    HapticFeedback.mediumImpact();
    try {
      final images = await DocumentScannerService.scanDocument(pageLimit: 20);
      if (images.isNotEmpty) {
        HapticFeedback.lightImpact();
        setState(() {
          _imagePaths.addAll(images);
        });
      } else if (_imagePaths.isEmpty) {
        // If user cancelled first scan and no pages exist, go back
        if (mounted) Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Scanning failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBackground : AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Document Capture', style: TextStyle(fontWeight: FontWeight.w800)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline_rounded),
            onPressed: _showTips,
          ),
        ],
      ),
      body: _imagePaths.isEmpty
          ? Center(
              child: _isBusy
                  ? const CircularProgressIndicator()
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.document_scanner_rounded, size: 64, color: AppTheme.primaryColor.withOpacity(0.5)),
                        const SizedBox(height: 16),
                        const Text('Ready to capture high-quality scans', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                      ],
                    ),
            )
          : Column(
              children: [
                _buildInfoBanner(),
                Expanded(
                  child: GridView.builder(
                    padding: const EdgeInsets.all(16),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 0.75,
                    ),
                    itemCount: _imagePaths.length,
                    itemBuilder: (context, index) {
                      return _buildPageCard(_imagePaths[index], index);
                    },
                  ),
                ),
                _buildBottomActions(),
              ],
            ),
    );
  }

  Widget _buildInfoBanner() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.primaryColor.withOpacity(0.15)),
      ),
      child: Row(
        children: [
          const Icon(Icons.auto_fix_high_rounded, size: 18, color: AppTheme.primaryColor),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Perspective and quality enhanced automatically',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.primaryColor),
            ),
          ),
          Text(
            '${_imagePaths.length} PGS',
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppTheme.primaryColor),
          ),
        ],
      ),
    );
  }

  void _showTips() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Scanning Tips'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            _TipItem(icon: Icons.light_mode_rounded, text: 'Ensure document is well-lit'),
            _TipItem(icon: Icons.contrast_rounded, text: 'Use a contrasting background'),
            _TipItem(icon: Icons.stay_current_portrait_rounded, text: 'Keep phone parallel to paper'),
            _TipItem(icon: Icons.auto_awesome_rounded, text: 'Wait for the auto-capture highlight'),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Got it')),
        ],
      ),
    );
  }

  Widget _buildPageCard(String path, int index) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.file(File(path), fit: BoxFit.cover),
            Positioned(
              top: 8,
              left: 8,
              child: CircleAvatar(
                radius: 12,
                backgroundColor: AppTheme.primaryColor,
                child: Text(
                  '${index + 1}',
                  style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            Positioned(
              top: 4,
              right: 4,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 18),
                onPressed: () {
                  setState(() {
                    _imagePaths.removeAt(index);
                  });
                },
                style: IconButton.styleFrom(backgroundColor: Colors.black45),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomActions() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _isBusy ? null : _startScanning,
              icon: const Icon(Icons.add_a_photo_rounded),
              label: const Text('Add Pages'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: FilledButton.icon(
              onPressed: _isBusy ? null : _finalize,
              icon: const Icon(Icons.check_circle_rounded),
              label: const Text('Save HD Scan'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: const Color(0xFF10B981),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _finalize() {
    if (_imagePaths.isEmpty) return;
    
    if (widget.returnOnly) {
      Navigator.pop(context, _imagePaths);
    } else {
      Navigator.pushReplacementNamed(
        context,
        AppRoutes.addDocument,
        arguments: {
          'paths': _imagePaths,
          'category': widget.initialCategory,
          'folder': widget.initialFolder,
          'memberId': widget.initialMemberId,
        },
      );
    }
  }
}

class _TipItem extends StatelessWidget {
  final IconData icon;
  final String text;
  const _TipItem({required this.icon, required this.text});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppTheme.primaryColor),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }
}
