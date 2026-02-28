import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:familysphere_app/core/services/smart_ocr_service.dart';
import 'package:familysphere_app/core/theme/app_theme.dart';
import 'package:familysphere_app/core/utils/routes.dart';

class ScannerScreen extends StatefulWidget {
  final bool returnOnly;
  final String? initialCategory;
  final String? initialFolder;
  final String? initialMemberId;

  const ScannerScreen({
    super.key,
    this.returnOnly = false,
    this.initialCategory,
    this.initialFolder,
    this.initialMemberId,
  });

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  final ImagePicker _picker = ImagePicker();
  final List<String> _imagePaths = <String>[];
  int _activeIndex = 0;
  bool _isBusy = false;

  // ── Smart OCR Intelligence ────────────────────────────────────────────────
  SmartOcrResult? _ocrResult;
  bool _isAnalyzing = false;

  @override
  void dispose() {
    SmartOcrService.dispose();
    super.dispose();
  }

  /// Run on-device OCR on the most recently added image.
  Future<void> _analyzeLatestPage(String imagePath) async {
    setState(() => _isAnalyzing = true);
    try {
      final result = await SmartOcrService.processImage(imagePath);
      if (mounted) setState(() => _ocrResult = result);
    } catch (_) {
      // Silent — OCR is enhancement only, not blocking
    } finally {
      if (mounted) setState(() => _isAnalyzing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBackground : AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Smart Scanner'),
        actions: [
          if (_isAnalyzing)
            const Padding(
              padding: EdgeInsets.only(right: 8),
              child: Center(
                child: SizedBox(
                  width: 18, height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
          if (_imagePaths.isNotEmpty)
            IconButton(
              onPressed: _isBusy ? null : _clearAll,
              tooltip: 'Clear all',
              icon: const Icon(Icons.delete_sweep_rounded),
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
              children: [
                _buildTopHint(context),
                const SizedBox(height: 12),
                _buildPreview(context),
                if (_imagePaths.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _buildThumbStrip(context),
                ],
                const SizedBox(height: 12),
                _buildDetectionFeedback(context),
              ],
            ),
          ),
          _buildBottomBar(context),
        ],
      ),
    );
  }

  Widget _buildTopHint(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? AppTheme.darkBorder : AppTheme.borderColor),
      ),
      child: Row(
        children: [
          const Icon(Icons.document_scanner_rounded),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _imagePaths.isEmpty
                  ? 'Capture pages clearly, then continue to upload.'
                  : '${_imagePaths.length} page(s) captured',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreview(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_imagePaths.isEmpty) {
      return AspectRatio(
        aspectRatio: 3 / 4,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isDark
                  ? const [Color(0xFF0B1220), Color(0xFF111827)]
                  : const [Color(0xFFEEF2FF), Color(0xFFE0F2FE)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isDark ? AppTheme.darkBorder : AppTheme.borderColor),
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppTheme.primaryColor.withValues(alpha: 0.16),
                  ),
                  child: const Icon(Icons.camera_alt_rounded, size: 34, color: AppTheme.primaryColor),
                ),
                const SizedBox(height: 12),
                Text(
                  'No scan pages yet',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  'Tap Capture to scan first page',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
      );
    }

    final currentPath = _imagePaths[_activeIndex];
    final cacheWidth = (MediaQuery.sizeOf(context).width * MediaQuery.devicePixelRatioOf(context)).round();

    return AspectRatio(
      aspectRatio: 3 / 4,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.file(
              File(currentPath),
              fit: BoxFit.cover,
              cacheWidth: cacheWidth,
              filterQuality: FilterQuality.low,
            ),
            Positioned(
              top: 10,
              right: 10,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  child: Text(
                    '${_activeIndex + 1}/${_imagePaths.length}',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThumbStrip(BuildContext context) {
    return SizedBox(
      height: 92,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _imagePaths.length,
        itemBuilder: (context, index) {
          final isSelected = index == _activeIndex;
          final cacheWidth = (72 * MediaQuery.devicePixelRatioOf(context)).round();

          return Container(
            width: 72,
            margin: const EdgeInsets.only(right: 10),
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => setState(() => _activeIndex = index),
              child: Stack(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSelected ? AppTheme.primaryColor : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(
                        File(_imagePaths[index]),
                        fit: BoxFit.cover,
                        cacheWidth: cacheWidth,
                        filterQuality: FilterQuality.low,
                        width: 72,
                        height: 92,
                      ),
                    ),
                  ),
                  Positioned(
                    top: 2,
                    right: 2,
                    child: InkWell(
                      onTap: _isBusy ? null : () => _removePage(index),
                      child: const CircleAvatar(
                        radius: 10,
                        backgroundColor: Colors.black54,
                        child: Icon(Icons.close_rounded, size: 12, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ─── Detection Feedback Panel ─────────────────────────────────────────────
  //
  // Shown immediately after a page is captured/picked.
  // Displays what the on-device ML Kit detected before the upload starts.
  Widget _buildDetectionFeedback(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Not yet scanned
    if (_imagePaths.isEmpty) return const SizedBox.shrink();

    // Scanning in progress
    if (_isAnalyzing) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0F172A) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppTheme.primaryColor.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          children: [
            const SizedBox(
              width: 18, height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 12),
            Text(
              'Analysing document…',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                color: isDark ? Colors.white70 : Colors.black54,
              ),
            ),
          ],
        ),
      );
    }

    // No result yet (e.g. first open before any capture)
    if (_ocrResult == null) return const SizedBox.shrink();

    final result = _ocrResult!;
    final hasIntel = result.hasIntelligence;
    final accentColor = hasIntel
        ? (result.needsReview ? Colors.orange : Colors.green)
        : Colors.grey;

    // Confidence badge colour
    Color confidenceColor;
    if (result.confidence >= 0.75) {
      confidenceColor = Colors.green;
    } else if (result.confidence >= 0.5) {
      confidenceColor = Colors.orange;
    } else {
      confidenceColor = Colors.red;
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOut,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accentColor.withValues(alpha: 0.4)),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: accentColor.withValues(alpha: 0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            children: [
              Icon(
                hasIntel ? Icons.psychology_outlined : Icons.help_outline_rounded,
                size: 18,
                color: accentColor,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  hasIntel ? 'Smart Detection' : 'No match found',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                    color: accentColor,
                  ),
                ),
              ),
              // Confidence badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: confidenceColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: confidenceColor.withValues(alpha: 0.4)),
                ),
                child: Text(
                  '${(result.confidence * 100).toStringAsFixed(0)}% ${result.confidenceLabel}',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: confidenceColor,
                  ),
                ),
              ),
            ],
          ),

          if (hasIntel) ...[
            const SizedBox(height: 12),
            // Doc type chip
            _detectionRow(
              context,
              icon: Icons.description_outlined,
              label: 'Document Type',
              value: result.docTypeLabel,
              isDark: isDark,
            ),

            if (result.expiryDate != null) ...[
              const SizedBox(height: 8),
              _detectionRow(
                context,
                icon: Icons.event_outlined,
                label: 'Expiry / Due Date',
                value: _formatDate(result.expiryDate!),
                isDark: isDark,
                highlight: result.expiryDate!.isBefore(DateTime.now()),
              ),
            ],

            if (result.amount != null) ...[
              const SizedBox(height: 8),
              _detectionRow(
                context,
                icon: Icons.currency_rupee,
                label: 'Amount',
                value: '₹${result.amount!.toStringAsFixed(2)}',
                isDark: isDark,
              ),
            ],

            // Script detected
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.translate_rounded, size: 12, color: Colors.grey),
                const SizedBox(width: 4),
                Text(
                  'Script: ${_scriptLabel(result.dominantScript)}',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10,
                    color: Colors.grey,
                  ),
                ),
                if (result.needsReview) ...[
                  const SizedBox(width: 12),
                  const Icon(Icons.info_outline, size: 12, color: Colors.orange),
                  const SizedBox(width: 4),
                  Text(
                    'Review required on timeline',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 10,
                      color: Colors.orange,
                    ),
                  ),
                ],
              ],
            ),
          ] else ...[
            const SizedBox(height: 8),
            Text(
              'Ensure the document is well-lit and text is clearly visible.',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                color: isDark ? Colors.white54 : Colors.black45,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _detectionRow(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    required bool isDark,
    bool highlight = false,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 14, color: isDark ? Colors.white38 : Colors.black38),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label.toUpperCase(),
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                  color: isDark ? Colors.white38 : Colors.black38,
                ),
              ),
              Text(
                value,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: highlight
                      ? Colors.red
                      : (isDark ? Colors.white : Colors.black87),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  String _scriptLabel(OcrScript script) {
    switch (script) {
      case OcrScript.devanagari: return 'Devanagari (Hindi)';
      case OcrScript.gujarati:   return 'Gujarati';
      case OcrScript.latin:      return 'Latin (English)';
    }
  }

  Widget _buildBottomBar(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : Colors.white,
        border: Border(top: BorderSide(color: isDark ? AppTheme.darkBorder : AppTheme.borderColor)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isBusy ? null : _pickFromGallery,
                  icon: const Icon(Icons.photo_library_outlined),
                  label: const Text('Gallery'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isBusy ? null : _captureFromCamera,
                  icon: _isBusy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.camera_alt_rounded),
                  label: Text(_isBusy ? 'Capturing...' : 'Capture'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _imagePaths.isEmpty ? null : _continueFlow,
              icon: const Icon(Icons.check_circle_outline_rounded),
              label: Text(widget.returnOnly ? 'Use These Pages' : 'Use / Upload Pages'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _captureFromCamera() async {
    setState(() => _isBusy = true);
    try {
      final image = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 90,
        maxWidth: 2200,
        preferredCameraDevice: CameraDevice.rear,
      );
      if (image == null || !mounted) return;

      setState(() {
        _imagePaths.add(image.path);
        _activeIndex = _imagePaths.length - 1;
      });
      // Run OCR in background — non-blocking
      await _analyzeLatestPage(image.path);
    } catch (e) {
      if (!mounted) return;
      _showSnack('Camera capture failed');
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _pickFromGallery() async {
    setState(() => _isBusy = true);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png'],
        allowMultiple: true,
      );
      if (result == null || !mounted) return;

      final newPaths = result.files
          .where((f) => f.path != null)
          .map((f) => f.path!)
          .where((path) => !_imagePaths.contains(path))
          .toList();

      if (newPaths.isEmpty) return;
      setState(() {
        _imagePaths.addAll(newPaths);
        _activeIndex = _imagePaths.length - 1;
      });
      // Run OCR on first newly added page
      await _analyzeLatestPage(newPaths.first);
    } catch (_) {
      if (!mounted) return;
      _showSnack('Gallery import failed');
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _clearAll() async {
    final shouldClear = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Clear all pages?'),
            content: const Text('This will remove all scanned pages from this session.'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
              FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Clear')),
            ],
          ),
        ) ??
        false;
    if (!shouldClear || !mounted) return;

    setState(() {
      _imagePaths.clear();
      _activeIndex = 0;
      _ocrResult = null;
    });
  }

  void _removePage(int index) {
    if (index < 0 || index >= _imagePaths.length) return;
    setState(() {
      _imagePaths.removeAt(index);
      if (_imagePaths.isEmpty) {
        _activeIndex = 0;
      } else if (_activeIndex >= _imagePaths.length) {
        _activeIndex = _imagePaths.length - 1;
      }
    });
  }

  void _continueFlow() {
    if (_imagePaths.isEmpty) return;
    final pages = List<String>.from(_imagePaths);

    if (widget.returnOnly) {
      Navigator.pop(context, pages);
      return;
    }

    showModalBottomSheet<void>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.arrow_back_rounded),
                  title: const Text('Return scanned pages'),
                  subtitle: const Text('Use pages in previous screen'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pop(this.context, pages);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.upload_file_rounded),
                  title: const Text('Upload to Vault'),
                  subtitle: const Text('Open upload flow with these pages'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushReplacementNamed(
                      this.context,
                      AppRoutes.addDocument,
                      arguments: {
                        'paths': pages,
                        'category': widget.initialCategory,
                        'folder': widget.initialFolder,
                        'memberId': widget.initialMemberId,
                      },
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showSnack(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }
}

