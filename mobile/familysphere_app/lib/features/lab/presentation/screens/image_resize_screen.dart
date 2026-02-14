import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:familysphere_app/core/theme/app_theme.dart';
import 'package:familysphere_app/features/lab/presentation/providers/image_resize_provider.dart';
import 'package:familysphere_app/features/lab/domain/services/image_resize_service.dart';
import 'package:familysphere_app/features/lab/presentation/widgets/merge_result_sheet.dart';
import 'dart:io';

class ImageResizeScreen extends ConsumerStatefulWidget {
  const ImageResizeScreen({super.key});

  @override
  ConsumerState<ImageResizeScreen> createState() => _ImageResizeScreenState();
}

class _ImageResizeScreenState extends ConsumerState<ImageResizeScreen> {
  final TextEditingController _outputNameController = TextEditingController();
  final Color _primaryBlue = const Color(0xFF2563EB);

  @override
  void dispose() {
    _outputNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(imageResizeProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Sync output name controller with state if it's empty
    if (_outputNameController.text.isEmpty && state.outputFileName.isNotEmpty) {
      _outputNameController.text = state.outputFileName;
    }

    // Listen for success
    ref.listen(imageResizeProvider, (previous, next) {
      if (next.status == ResizeStatus.success && previous?.status != ResizeStatus.success) {
        if (next.outputFilePath != null) {
          MergeResultSheet.showSuccess(
            context,
            outputFilePath: next.outputFilePath!,
            outputSizeBytes: next.outputSizeBytes ?? 0,
            successTitle: 'Image Resized!',
            onDone: () {
              ref.read(imageResizeProvider.notifier).reset();
              _outputNameController.clear();
            },
          );
        }
      }
    });

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBackground : const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: const Text('Resize Image'),
        backgroundColor: isDark ? AppTheme.darkSurface : Colors.white,
        foregroundColor: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
        elevation: 0,
        centerTitle: true,
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 120),
            child: Column(
              children: [
                _buildInfoCard(isDark),
                const SizedBox(height: 16),
                _buildAddImageButton(state),
                if (state.selectedImage != null) ...[
                  const SizedBox(height: 16),
                  _buildImagePreviewCard(isDark, state),
                  const SizedBox(height: 16),
                  _buildResizeModeSection(isDark, state),
                  const SizedBox(height: 16),
                  _buildOutputSettings(isDark, state),
                ],
                if (state.errorMessage != null)
                  _buildErrorBanner(isDark, state.errorMessage!),
              ],
            ),
          ),
          if (state.status == ResizeStatus.processing) _buildProgressOverlay(isDark, state),
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _primaryBlue.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _primaryBlue.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _primaryBlue,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.info_outline, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Resize Images Easily',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : AppTheme.textPrimary,
                      ),
                ),
                Text(
                  'Change image size without losing quality',
                  style: TextStyle(
                    color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddImageButton(ImageResizeState state) {
    if (state.selectedImage != null) return const SizedBox.shrink();
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ElevatedButton.icon(
        onPressed: () => ref.read(imageResizeProvider.notifier).pickImage(),
        icon: const Icon(Icons.add_photo_alternate_outlined),
        label: const Text('+ Add Image'),
        style: ElevatedButton.styleFrom(
          backgroundColor: _primaryBlue,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 56),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 4,
          shadowColor: _primaryBlue.withOpacity(0.3),
        ),
      ),
    );
  }

  Widget _buildImagePreviewCard(bool isDark, ImageResizeState state) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Stack(
            children: [
              AspectRatio(
                aspectRatio: 16 / 9,
                child: Image.file(
                  File(state.selectedImage!.path),
                  fit: BoxFit.cover,
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: CircleAvatar(
                  backgroundColor: Colors.black54,
                  child: IconButton(
                    icon: const Icon(Icons.close, color: Colors.white, size: 20),
                    onPressed: () => ref.read(imageResizeProvider.notifier).removeImage(),
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        state.selectedImage!.name,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.aspect_ratio, size: 14, color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary),
                          const SizedBox(width: 4),
                          Text(
                            state.selectedImage!.dimensionLabel,
                            style: TextStyle(color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary, fontSize: 12),
                          ),
                          const SizedBox(width: 12),
                          Icon(Icons.storage, size: 14, color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary),
                          const SizedBox(width: 4),
                          Text(
                            state.selectedImage!.sizeLabel,
                            style: TextStyle(color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary, fontSize: 12),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: (isDark ? Colors.white : Colors.black).withOpacity(0.05),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'ORIGINAL',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResizeModeSection(bool isDark, ImageResizeState state) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.straighten, color: _primaryBlue, size: 20),
              const SizedBox(width: 8),
              const Text('Resize Mode', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          const SizedBox(height: 16),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 2.8,
            children: ImageResizeMode.values.map((mode) => _buildModeItem(mode, state)).toList(),
          ),
          const SizedBox(height: 24),
          if (state.mode == ImageResizeMode.percentage) _buildPercentageSlider(isDark, state),
          const SizedBox(height: 16),
          _buildAspectToggle(isDark, state),
        ],
      ),
    );
  }

  Widget _buildModeItem(ImageResizeMode mode, ImageResizeState state) {
    final isSelected = state.mode == mode;
    return GestureDetector(
      onTap: () => ref.read(imageResizeProvider.notifier).setMode(mode),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected ? _primaryBlue.withOpacity(0.05) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? _primaryBlue : Colors.grey.withOpacity(0.2),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                mode.label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? _primaryBlue : Colors.grey,
                ),
              ),
            ),
            if (isSelected) Icon(Icons.check_circle, color: _primaryBlue, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildPercentageSlider(bool isDark, ImageResizeState state) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Scaling Value', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: _primaryBlue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${state.percentage.toInt()}%',
                style: TextStyle(color: _primaryBlue, fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Slider(
          value: state.percentage,
          min: 10,
          max: 100,
          activeColor: _primaryBlue,
          onChanged: (val) => ref.read(imageResizeProvider.notifier).setPercentage(val),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('10%', style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
              Text('100%', style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAspectToggle(bool isDark, ImageResizeState state) {
    return Container(
      padding: const EdgeInsets.only(top: 16),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Colors.grey.withOpacity(0.1))),
      ),
      child: Row(
        children: [
          Icon(Icons.link, color: Colors.grey.withOpacity(0.5)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Lock Aspect Ratio', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                Text(
                  'Prevent image stretching',
                  style: TextStyle(color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
          Switch(
            value: state.lockAspectRatio,
            activeColor: _primaryBlue,
            onChanged: (val) => ref.read(imageResizeProvider.notifier).setLockAspectRatio(val),
          ),
        ],
      ),
    );
  }

  Widget _buildOutputSettings(bool isDark, ImageResizeState state) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.settings, color: _primaryBlue, size: 20),
              const SizedBox(width: 8),
              const Text('Output Settings', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          const SizedBox(height: 20),
          const Text('OUTPUT FORMAT', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.darkBackground : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.withOpacity(0.1)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<ImageOutputFormat>(
                value: state.format,
                isExpanded: true,
                onChanged: (val) => ref.read(imageResizeProvider.notifier).setFormat(val!),
                items: ImageOutputFormat.values.map((f) {
                  return DropdownMenuItem(value: f, child: Text(f.label, style: const TextStyle(fontSize: 14)));
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text('OUTPUT FILE NAME', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
          const SizedBox(height: 8),
          TextField(
            controller: _outputNameController,
            onChanged: (val) => ref.read(imageResizeProvider.notifier).setOutputFileName(val),
            decoration: InputDecoration(
              suffixIcon: const Icon(Icons.edit, size: 20),
              filled: true,
              fillColor: isDark ? AppTheme.darkBackground : const Color(0xFFF8FAFC),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.withOpacity(0.1)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.withOpacity(0.1)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomCTA(bool isDark, ImageResizeState state) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.withOpacity(0.1))),
      ),
      child: ElevatedButton(
        onPressed: state.canProcess ? () => ref.read(imageResizeProvider.notifier).startResize() : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: _primaryBlue,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 56),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 8,
          shadowColor: _primaryBlue.withOpacity(0.4),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.photo_size_select_large),
            const SizedBox(width: 8),
            const Text('RESIZE IMAGE', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorBanner(bool isDark, String message) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.red),
          const SizedBox(width: 12),
          Expanded(child: Text(message, style: const TextStyle(color: Colors.red))),
          IconButton(
            icon: const Icon(Icons.close, size: 18, color: Colors.red),
            onPressed: () => ref.read(imageResizeProvider.notifier).dismissError(),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressOverlay(bool isDark, ImageResizeState state) {
    return Container(
      color: Colors.black.withOpacity(0.5),
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(24),
          margin: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkSurface : Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(value: state.progress > 0 ? state.progress : null),
              const SizedBox(height: 20),
              Text(state.progressMessage, style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              TextButton(
                onPressed: () => ref.read(imageResizeProvider.notifier).cancelResize(),
                child: const Text('Cancel'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
