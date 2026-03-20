import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
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
        elevation: 0,
        backgroundColor: isDark ? AppTheme.darkBackground : AppTheme.backgroundColor,
        titleSpacing: 0,
        title: Row(
          children: [
            const SizedBox(width: 16),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient,
                borderRadius: BorderRadius.circular(11),
              ),
              child: const Icon(Icons.document_scanner_rounded,
                  color: Colors.white, size: 18),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Smart Scanner',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w800)),
                Text(
                  _imagePaths.isEmpty
                      ? 'Capture or import pages'
                      : '${_imagePaths.length} page${_imagePaths.length > 1 ? 's' : ''} ready',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: isDark ? Colors.white54 : AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ],
        ),
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
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: IconButton(
                onPressed: _isBusy ? null : _clearAll,
                tooltip: 'Clear all',
                icon: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.delete_sweep_rounded,
                      color: Colors.red, size: 18),
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
              children: [
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

  // _buildTopHint removed — info is now embedded in AppBar subtitle and preview overlay

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
                    color: AppTheme.primaryColor.withOpacity(0.16),
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
                  color: Colors.black.withOpacity(0.45),
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
              color: AppTheme.primaryColor.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppTheme.primaryColor,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Analysing document…',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: isDark
                          ? Colors.white.withOpacity(0.87)
                          : const Color(0xFF0F172A),
                    ),
                  ),
                  Text(
                    'On-device OCR running',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark
                          ? Colors.white38
                          : AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    if (_ocrResult == null) return const SizedBox.shrink();

    final result = _ocrResult!;
    final hasIntel = result.hasIntelligence;

    final Color confidenceColor;
    final String confidenceLevel;
    if (result.confidence >= 0.75) {
      confidenceColor = const Color(0xFF10B981);
      confidenceLevel = 'High';
    } else if (result.confidence >= 0.5) {
      confidenceColor = const Color(0xFFF59E0B);
      confidenceLevel = 'Medium';
    } else {
      confidenceColor = const Color(0xFFEF4444);
      confidenceLevel = 'Low';
    }

    final cardBg = isDark ? const Color(0xFF0F172A) : Colors.white;
    final textP = isDark ? Colors.white : const Color(0xFF0F172A);
    final textS = isDark ? Colors.white54 : const Color(0xFF64748B);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.06),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Left accent strip
              Container(
                width: 4,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      confidenceColor,
                      confidenceColor.withOpacity(0.4)
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Header ──────────────────────────────────────
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(7),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryColor
                                  .withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              hasIntel
                                  ? Icons.auto_awesome_rounded
                                  : Icons.help_outline_rounded,
                              size: 16,
                              color: AppTheme.primaryColor,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              hasIntel
                                  ? 'Smart Insight'
                                  : 'No match found',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: textP,
                              ),
                            ),
                          ),
                          // Confidence pill
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: confidenceColor
                                  .withOpacity(0.12),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                  color: confidenceColor
                                      .withOpacity(0.4)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: confidenceColor,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  '$confidenceLevel  ${(result.confidence * 100).toStringAsFixed(0)}%',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: confidenceColor,
                                  ),
                                ),
                              ],
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

            // Script + review hint
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.translate_rounded, size: 12, color: textS),
                const SizedBox(width: 4),
                Text(
                  'Script: ${_scriptLabel(result.dominantScript)}',
                  style: TextStyle(fontSize: 10, color: textS),
                ),
                if (result.needsReview) ...[
                  const SizedBox(width: 12),
                  const Icon(Icons.info_outline,
                      size: 12, color: Colors.orange),
                  const SizedBox(width: 4),
                  Text(
                    'Review required on timeline',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.orange.shade700,
                    ),
                  ),
                ],
              ],
            ),
          ] else ...[
            const SizedBox(height: 10),
            Text(
              'Ensure the document is well-lit and text is clearly visible.',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white54 : Colors.black45,
              ),
            ),
          ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
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
    final textP = isDark ? Colors.white : const Color(0xFF0F172A);
    final textS = isDark ? Colors.white54 : const Color(0xFF64748B);
    return Container(
      margin: const EdgeInsets.only(bottom: 0),
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withOpacity(0.04)
            : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 14, color: AppTheme.primaryColor),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: textS),
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: highlight ? const Color(0xFFEF4444) : textP,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
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
    final bg = isDark ? AppTheme.darkSurface : Colors.white;
    final borderTop = isDark ? AppTheme.darkBorder : AppTheme.borderColor;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      decoration: BoxDecoration(
        color: bg,
        border: Border(top: BorderSide(color: borderTop)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.06),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Primary capture row ──────────────────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Gallery icon button
              _BottomIconAction(
                icon: Icons.photo_library_outlined,
                label: 'Gallery',
                onTap: _isBusy ? null : _pickFromGallery,
                isDark: isDark,
              ),
              const SizedBox(width: 14),
              // Centre — main capture CTA
              Expanded(
                child: GestureDetector(
                  onTap: _isBusy ? null : _captureFromCamera,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    height: 54,
                    decoration: BoxDecoration(
                      gradient: _isBusy ? null : AppTheme.primaryGradient,
                      color: _isBusy ? Colors.grey.shade400 : null,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: _isBusy
                          ? null
                          : [
                              BoxShadow(
                                color: AppTheme.primaryColor
                                    .withOpacity(0.35),
                                blurRadius: 16,
                                offset: const Offset(0, 6),
                              ),
                            ],
                    ),
                    child: Center(
                      child: _isBusy
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            )
                          : const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.camera_alt_rounded,
                                    color: Colors.white, size: 22),
                                SizedBox(width: 8),
                                Text(
                                  'Capture',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 15,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              // Files icon button
              _BottomIconAction(
                icon: Icons.attach_file_rounded,
                label: 'Files',
                onTap: _isBusy ? null : _pickFromGallery,
                isDark: isDark,
              ),
            ],
          ),

          // ── Continue button (shows only when pages are ready) ─────────
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            child: _imagePaths.isEmpty
                ? const SizedBox.shrink()
                : Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: GestureDetector(
                      onTap: _continueFlow,
                      child: Container(
                        width: double.infinity,
                        height: 50,
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981)
                              .withOpacity(0.1),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: const Color(0xFF10B981)
                                .withOpacity(0.45),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.check_circle_outline_rounded,
                              color: Color(0xFF10B981),
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              widget.returnOnly
                                  ? 'Use ${_imagePaths.length} Page${_imagePaths.length > 1 ? 's' : ''}'
                                  : 'Continue with ${_imagePaths.length} Page${_imagePaths.length > 1 ? 's' : ''}',
                              style: const TextStyle(
                                color: Color(0xFF10B981),
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                              ),
                            ),
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

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0F172A) : Colors.white;
    final textP = isDark ? Colors.white : const Color(0xFF0F172A);
    final textS = isDark ? Colors.white60 : const Color(0xFF64748B);

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetCtx) {
        return Container(
          decoration: BoxDecoration(
            color: bg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.18),
                blurRadius: 28,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 36),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag pill
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Gradient header
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primaryColor.withOpacity(0.3),
                      blurRadius: 14,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.photo_library_rounded,
                          color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${pages.length} page${pages.length > 1 ? 's' : ''} ready',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            'What would you like to do?',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.8),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              _ContinueOption(
                icon: Icons.arrow_back_rounded,
                title: 'Use in Previous Screen',
                subtitle: 'Return these pages to the previous flow',
                iconColor: AppTheme.primaryColor,
                isDark: isDark,
                textP: textP,
                textS: textS,
                onTap: () {
                  Navigator.pop(sheetCtx);
                  Navigator.pop(this.context, pages);
                },
              ),

              const SizedBox(height: 10),

              _ContinueOption(
                icon: Icons.cloud_upload_rounded,
                title: 'Upload to Vault',
                subtitle: 'Open the upload form with these scanned pages',
                iconColor: const Color(0xFF10B981),
                isDark: isDark,
                textP: textP,
                textS: textS,
                onTap: () {
                  Navigator.pop(sheetCtx);
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
        );
      },
    );
  }

  void _showSnack(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Bottom bar icon action button
// ─────────────────────────────────────────────────────────────────────────────
class _BottomIconAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool isDark;

  const _BottomIconAction({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final bg = isDark
        ? Colors.white.withOpacity(0.07)
        : const Color(0xFFF1F5F9);
    final iconColor = onTap == null
        ? (isDark ? Colors.white24 : Colors.black26)
        : (isDark ? Colors.white70 : const Color(0xFF475569));
    final labelColor = onTap == null
        ? (isDark ? Colors.white24 : Colors.black26)
        : (isDark ? Colors.white54 : const Color(0xFF64748B));

    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark
                    ? Colors.white12
                    : Colors.black.withOpacity(0.06),
              ),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: labelColor,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Continue-flow option row
// ─────────────────────────────────────────────────────────────────────────────
class _ContinueOption extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color iconColor;
  final bool isDark;
  final Color textP;
  final Color textS;
  final VoidCallback onTap;

  const _ContinueOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.iconColor,
    required this.isDark,
    required this.textP,
    required this.textS,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bg = isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC);
    final border = isDark
        ? Colors.white12
        : Colors.black.withOpacity(0.07);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: border),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: textP,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 12, color: textS),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: textS, size: 20),
          ],
        ),
      ),
    );
  }
}

