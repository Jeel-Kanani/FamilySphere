import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:familysphere_app/core/theme/app_theme.dart';
import 'package:familysphere_app/core/utils/routes.dart';

class ScannerScreen extends StatefulWidget {
  final bool returnOnly;

  const ScannerScreen({super.key, this.returnOnly = false});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  final ImagePicker _picker = ImagePicker();
  final List<String> _imagePaths = <String>[];
  int _activeIndex = 0;
  bool _isBusy = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBackground : AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Scanner'),
        actions: [
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
    } catch (e) {
      if (!mounted) return;
      _showSnack('Camera capture failed');
    } finally {
      if (mounted) {
        setState(() => _isBusy = false);
      }
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
    } catch (_) {
      if (!mounted) return;
      _showSnack('Gallery import failed');
    } finally {
      if (mounted) {
        setState(() => _isBusy = false);
      }
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
                      arguments: pages,
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

