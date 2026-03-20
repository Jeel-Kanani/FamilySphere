import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:familysphere_app/core/theme/app_theme.dart';
import 'package:familysphere_app/features/lab/domain/services/lab_file_manager.dart';

class PreviewShareScreen extends ConsumerStatefulWidget {
  const PreviewShareScreen({super.key});
  @override
  ConsumerState<PreviewShareScreen> createState() => _PreviewShareScreenState();
}

class _PreviewShareScreenState extends ConsumerState<PreviewShareScreen> {
  static const Color _blue = Color(0xFF2563EB);
  static const Color _bg = Color(0xFFF6F7F8);

  File? _file;
  String? _name;
  int _size = 0;
  String? _ext;

  bool get _isImg => ['jpg','jpeg','png','webp','bmp','gif'].contains(_ext);
  bool get _isTxt => ['txt','md','json','csv','xml','log'].contains(_ext);

  Future<void> _pick() async {
    final r = await FilePicker.platform.pickFiles();
    if (r == null || r.files.isEmpty || r.files.first.path == null) return;
    final f = File(r.files.first.path!);
    setState(() { _file = f; _name = r.files.first.name; _size = r.files.first.size; _ext = _name?.split('.').last.toLowerCase(); });
  }

  @override
  Widget build(BuildContext context) {
    final dk = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: dk ? AppTheme.darkBackground : _bg,
      appBar: AppBar(
        backgroundColor: dk ? AppTheme.darkBackground : _bg, surfaceTintColor: Colors.transparent, elevation: 0,
        leading: IconButton(icon: Icon(Icons.arrow_back_rounded, color: dk ? AppTheme.darkTextPrimary : AppTheme.textPrimary), onPressed: () => Navigator.pop(context)),
        title: Text('Preview & Share', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
        actions: [if (_file != null) IconButton(icon: Icon(Icons.share_rounded, color: _blue), onPressed: () => Share.shareXFiles([XFile(_file!.path)]))],
      ),
      body: _file == null ? _idle(context, dk) : _preview(context, dk),
    );
  }

  Widget _idle(BuildContext context, bool dk) {
    return Center(child: Padding(padding: const EdgeInsets.all(32), child: Material(color: Colors.transparent, child: InkWell(
      onTap: _pick, borderRadius: BorderRadius.circular(AppTheme.radiusL),
      child: Container(padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
        decoration: BoxDecoration(color: dk ? AppTheme.darkSurface : Colors.white, borderRadius: BorderRadius.circular(AppTheme.radiusL), border: Border.all(color: _blue.withOpacity(0.4), width: 2)),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.file_open_rounded, color: _blue, size: 48),
          const SizedBox(height: 16),
          Text('Select a File', style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold, color: _blue)),
          const SizedBox(height: 6),
          Text('Pick any file to preview and share', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: dk ? AppTheme.darkTextSecondary : AppTheme.textTertiary)),
        ]),
      ),
    ))));
  }

  Widget _preview(BuildContext context, bool dk) {
    return Column(children: [
      Container(padding: const EdgeInsets.all(16), color: dk ? AppTheme.darkSurface : Colors.white,
        child: Row(children: [
          Icon(_icon(), color: _blue, size: 28), const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_name ?? '', style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
            Text('${_ext?.toUpperCase()} • ${LabFileManager.formatFileSize(_size)}', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: dk ? AppTheme.darkTextSecondary : AppTheme.textTertiary)),
          ])),
          IconButton(icon: Icon(Icons.swap_horiz_rounded, color: _blue), onPressed: _pick),
        ])),
      Expanded(child: _content(context, dk)),
      Container(padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        decoration: BoxDecoration(border: Border(top: BorderSide(color: dk ? AppTheme.darkBorder : const Color(0xFFE2E8F0)))),
        child: SafeArea(top: false, child: SizedBox(width: double.infinity, height: 56, child: ElevatedButton.icon(
          onPressed: () => Share.shareXFiles([XFile(_file!.path)]),
          icon: const Icon(Icons.share_rounded), label: const Text('SHARE FILE', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
          style: ElevatedButton.styleFrom(backgroundColor: _blue, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusL))),
        )))),
    ]);
  }

  Widget _content(BuildContext context, bool dk) {
    if (_isImg) return InteractiveViewer(child: Center(child: Image.file(_file!, fit: BoxFit.contain, errorBuilder: (_, __, ___) => _noPreview(context, dk))));
    if (_isTxt) return FutureBuilder<String>(future: _file!.readAsString(), builder: (_, s) {
      if (!s.hasData) return const Center(child: CircularProgressIndicator());
      return Container(margin: const EdgeInsets.all(16), padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: dk ? AppTheme.darkSurface : Colors.white, borderRadius: BorderRadius.circular(AppTheme.radiusL)),
        child: SingleChildScrollView(child: SelectableText(s.data ?? '', style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontFamily: 'monospace', height: 1.6))));
    });
    return _noPreview(context, dk);
  }

  Widget _noPreview(BuildContext context, bool dk) => Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
    Icon(Icons.visibility_off_rounded, size: 48, color: dk ? AppTheme.darkTextSecondary : AppTheme.textTertiary),
    const SizedBox(height: 16),
    Text('Preview not available', style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: dk ? AppTheme.darkTextSecondary : AppTheme.textSecondary)),
    const SizedBox(height: 6),
    Text('You can still share this file', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textTertiary)),
  ]));

  IconData _icon() {
    if (_isImg) return Icons.image_rounded;
    if (_isTxt) return Icons.text_snippet_rounded;
    if (_ext == 'pdf') return Icons.picture_as_pdf_rounded;
    return Icons.insert_drive_file_rounded;
  }
}
