import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:familysphere_app/core/theme/app_theme.dart';
import 'package:familysphere_app/core/utils/routes.dart';

class FileConverterScreen extends ConsumerWidget {
  const FileConverterScreen({super.key});

  static const Color _blue = Color(0xFF2563EB);
  static const Color _bg = Color(0xFFF6F7F8);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dk = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: dk ? AppTheme.darkBackground : _bg,
      appBar: AppBar(
        backgroundColor: dk ? AppTheme.darkBackground : _bg, surfaceTintColor: Colors.transparent, elevation: 0,
        leading: IconButton(icon: Icon(Icons.arrow_back_rounded, color: dk ? AppTheme.darkTextPrimary : AppTheme.textPrimary), onPressed: () => Navigator.pop(context)),
        title: Text('File Converter', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
        actions: [Padding(padding: const EdgeInsets.only(right: 12), child: Icon(Icons.swap_horiz_rounded, color: _blue, size: 24))],
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(children: [
          Padding(padding: const EdgeInsets.all(16), child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: dk ? _blue.withOpacity(0.15) : _blue.withOpacity(0.08), borderRadius: BorderRadius.circular(AppTheme.radiusL), border: Border.all(color: _blue.withOpacity(0.2))),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(Icons.info_outline_rounded, color: _blue, size: 22), const SizedBox(width: 14),
              Expanded(child: Text('Pick a conversion type below. Each tool handles a specific file transformation.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: dk ? AppTheme.darkTextSecondary : AppTheme.textSecondary, height: 1.4))),
            ]),
          )),
          _buildSection(context, dk, 'PDF Conversions', [
            _ConvertOption('PDF → Text', 'Extract readable text from PDF', Icons.text_snippet_rounded, () => Navigator.pushNamed(context, AppRoutes.pdfToText)),
          ]),
          _buildSection(context, dk, 'Image Conversions', [
            _ConvertOption('Convert Format', 'JPG ↔ PNG ↔ BMP', Icons.transform_rounded, () => Navigator.pushNamed(context, AppRoutes.imageConvert)),
            _ConvertOption('Image → PDF', 'Convert images to PDF', Icons.picture_as_pdf_rounded, () => Navigator.pushNamed(context, AppRoutes.imageProcess)),
          ]),
        ]),
      ),
    );
  }

  Widget _buildSection(BuildContext context, bool dk, String title, List<_ConvertOption> options) {
    return Padding(padding: const EdgeInsets.fromLTRB(16, 8, 16, 8), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: Theme.of(context).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold, letterSpacing: 1.0, color: dk ? AppTheme.darkTextSecondary : AppTheme.textTertiary)),
      const SizedBox(height: 8),
      ...options.map((o) => Padding(padding: const EdgeInsets.only(bottom: 8), child: Material(color: Colors.transparent, child: InkWell(
        onTap: o.onTap, borderRadius: BorderRadius.circular(AppTheme.radiusL),
        child: Container(padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: dk ? AppTheme.darkSurface : Colors.white, borderRadius: BorderRadius.circular(AppTheme.radiusL), border: Border.all(color: dk ? AppTheme.darkBorder : const Color(0xFFE2E8F0))),
          child: Row(children: [
            Container(width: 44, height: 44, decoration: BoxDecoration(color: _blue.withOpacity(0.08), borderRadius: BorderRadius.circular(AppTheme.radiusM)),
              child: Icon(o.icon, color: _blue, size: 24)),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(o.title, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold, color: dk ? AppTheme.darkTextPrimary : AppTheme.textPrimary)),
              Text(o.subtitle, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: dk ? AppTheme.darkTextSecondary : AppTheme.textTertiary)),
            ])),
            Icon(Icons.chevron_right_rounded, color: dk ? AppTheme.darkTextSecondary : AppTheme.textTertiary),
          ]),
        ),
      )))),
    ]));
  }
}

class _ConvertOption {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
  const _ConvertOption(this.title, this.subtitle, this.icon, this.onTap);
}
