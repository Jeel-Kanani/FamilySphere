import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:familysphere_app/core/theme/app_theme.dart';
import '../providers/crop_image_provider.dart';
import '../../domain/services/crop_image_service.dart';

class CropImageScreen extends ConsumerStatefulWidget {
  const CropImageScreen({super.key});

  @override
  ConsumerState<CropImageScreen> createState() => _CropImageScreenState();
}

class _CropImageScreenState extends ConsumerState<CropImageScreen> {
  final TextEditingController _fileNameController = TextEditingController();

  @override
  void dispose() {
    _fileNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(cropImageProvider);
    final notifier = ref.read(cropImageProvider.notifier);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Update controller if name changes from outside
    if (_fileNameController.text != state.outputFileName) {
      _fileNameController.text = state.outputFileName;
    }

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBackground : const Color(0xFFF6F7F8),
      appBar: AppBar(
        title: const Text('Crop Image'),
        actions: [
          IconButton(
            icon: const Icon(Icons.restart_alt_rounded, color: AppTheme.primaryColor),
            onPressed: () => notifier.reset(),
            tooltip: 'Reset',
          ),
        ],
      ),
      body: state.imageFile == null
          ? _buildEmptyState(notifier, isDark)
          : Stack(
              children: [
                SingleChildScrollView(
                  padding: const EdgeInsets.only(bottom: 120),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Instruction Card
                      _buildInstructionCard(notifier, isDark),
                      
                      // Crop Area
                      _buildCropArea(state, notifier, isDark),
                      
                      // Aspect Ratio Toolbar
                      _buildAspectRatioToolbar(state, notifier, isDark),
                      
                      // Control Row
                      _buildControlRow(state, notifier, isDark),
                      
                      // Output Settings
                      _buildOutputSettings(state, notifier, isDark),
                    ],
                  ),
                ),
                
                // Bottom Action Button
                _buildBottomButton(state, notifier, isDark),
                
                // Loading Overlay
                if (state.isLoading) _buildLoadingOverlay(state),
              ],
            ),
    );
  }

  Widget _buildEmptyState(CropImageNotifier notifier, bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.add_photo_alternate_rounded, size: 80, color: AppTheme.primaryColor.withValues(alpha: 0.3)),
          const SizedBox(height: 20),
          Text(
            'No image selected',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white70 : Colors.black54,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => notifier.pickImage(),
            icon: const Icon(Icons.photo_library_rounded),
            label: const Text('Pick Image'),
          ),
        ],
      ),
    );
  }

  Widget _buildInstructionCard(CropImageNotifier notifier, bool isDark) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusXL),
        border: Border.all(color: isDark ? AppTheme.darkBorder : AppTheme.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Crop Your Image',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          const Text(
            'Select the area you want to keep from your family memory.',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 16),
          InkWell(
            onTap: () => notifier.pickImage(),
            borderRadius: BorderRadius.circular(AppTheme.radiusM),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(AppTheme.radiusM),
                border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.3), style: BorderStyle.none), // Should be dashed but we'll use solid for now
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_photo_alternate_rounded, color: AppTheme.primaryColor, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Change Image',
                    style: TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCropArea(CropImageState state, CropImageNotifier notifier, bool isDark) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      constraints: const BoxConstraints(maxHeight: 400),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : Colors.black12,
        borderRadius: BorderRadius.circular(AppTheme.radiusXL),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppTheme.radiusXL),
        child: LayoutBuilder(
          builder: (context, constraints) {
            // We need to calculate how the image fits within these constraints (BoxFit.contain)
            return _CropCanvas(
              state: state,
              notifier: notifier,
              constraints: constraints,
            );
          },
        ),
      ),
    );
  }
}

class _CropCanvas extends StatefulWidget {
  final CropImageState state;
  final CropImageNotifier notifier;
  final BoxConstraints constraints;

  const _CropCanvas({
    required this.state,
    required this.notifier,
    required this.constraints,
  });

  @override
  State<_CropCanvas> createState() => _CropCanvasState();
}

class _CropCanvasState extends State<_CropCanvas> {
  late double _localX;
  late double _localY;
  late double _localW;
  late double _localH;
  
  // Display dimensions of the image
  double _imgW = 0;
  double _imgH = 0;
  double _imgX = 0;
  double _imgY = 0;

  @override
  void initState() {
    super.initState();
    _syncFromState();
  }

  @override
  void didUpdateWidget(_CropCanvas oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state.imageFile != widget.state.imageFile || 
        oldWidget.state.cropX != widget.state.cropX ||
        oldWidget.state.cropY != widget.state.cropY ||
        oldWidget.state.cropWidth != widget.state.cropWidth ||
        oldWidget.state.cropHeight != widget.state.cropHeight ||
        oldWidget.state.rotation != widget.state.rotation ||
        oldWidget.state.flipHorizontal != widget.state.flipHorizontal ||
        oldWidget.state.flipVertical != widget.state.flipVertical ||
        oldWidget.state.aspectRatio != widget.state.aspectRatio) {
      _syncFromState();
    }
  }

  void _syncFromState() {
    _localX = widget.state.cropX;
    _localY = widget.state.cropY;
    _localW = widget.state.cropWidth;
    _localH = widget.state.cropHeight;
  }

  void _calculateImageMetrics() {
    // In a real app, we'd get the actual image resolution. 
    // For now, assume a 4:5 ratio for the placeholder or calculate based on constraints.
    // Ideally we should have the image dimensions in CropImageState.
    // This logic should calculate the actual displayed image size and position
    // when BoxFit.contain is used within the constraints.
    final containerWidth = widget.constraints.maxWidth;
    final containerHeight = widget.constraints.maxHeight;

    // For simplicity, let's assume the image itself has a 1:1 aspect ratio initially
    // or we fetch its actual dimensions. For now, we'll use the container's aspect ratio
    // as a placeholder for the image's "natural" aspect ratio if not provided.
    // In a real scenario, you'd load the image and get its intrinsic width/height.
    // For this example, we'll assume the image fits perfectly or is scaled to fit.
    // Let's assume the image has a 4:3 aspect ratio for demonstration.
    // A more robust solution would involve Image.file().image.resolve() to get actual dimensions.
    double imageNaturalWidth = 1000; // Placeholder
    double imageNaturalHeight = 750; // Placeholder (4:3 ratio)

    // If the image dimensions are available in state, use them
    if (widget.state.imageWidth != null && widget.state.imageHeight != null) {
      imageNaturalWidth = widget.state.imageWidth!.toDouble();
      imageNaturalHeight = widget.state.imageHeight!.toDouble();
    }

    // Apply rotation to natural dimensions for calculation
    double effectiveImageWidth = imageNaturalWidth;
    double effectiveImageHeight = imageNaturalHeight;
    if (widget.state.rotation % 180 != 0) { // If rotated 90 or 270 degrees
      effectiveImageWidth = imageNaturalHeight;
      effectiveImageHeight = imageNaturalWidth;
    }

    final containerAspectRatio = containerWidth / containerHeight;
    final imageAspectRatio = effectiveImageWidth / effectiveImageHeight;

    if (imageAspectRatio > containerAspectRatio) {
      // Image is wider than container, fit by width
      _imgW = containerWidth;
      _imgH = containerWidth / imageAspectRatio;
      _imgX = 0;
      _imgY = (containerHeight - _imgH) / 2;
    } else {
      // Image is taller than container, fit by height
      _imgH = containerHeight;
      _imgW = containerHeight * imageAspectRatio;
      _imgX = (containerWidth - _imgW) / 2;
      _imgY = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    _calculateImageMetrics();

    final x = _imgX + _localX * _imgW;
    final y = _imgY + _localY * _imgH;
    final w = _localW * _imgW;
    final h = _localH * _imgH;

    return Stack(
      children: [
        // Background Image (Full)
        Positioned.fill(
          child: Opacity(
            opacity: 0.5,
            child: _buildImage(BoxFit.contain),
          ),
        ),

        // Crop Window (Clear part)
        Positioned(
          left: x,
          top: y,
          width: w,
          height: h,
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white, width: 2),
            ),
            child: ClipRect(
              child: Stack(
                children: [
                  Positioned(
                    left: -x,
                    top: -y,
                    width: widget.constraints.maxWidth,
                    height: widget.constraints.maxHeight,
                    child: _buildImage(BoxFit.contain),
                  ),
                  _buildGridLines(),
                ],
              ),
            ),
          ),
        ),

        // Handles
        _buildHandle(x, y, (dx, dy) => _onResize(dx, dy, true, true)), // TL
        _buildHandle(x + w, y, (dx, dy) => _onResize(dx, dy, false, true)), // TR
        _buildHandle(x, y + h, (dx, dy) => _onResize(dx, dy, true, false)), // BL
        _buildHandle(x + w, y + h, (dx, dy) => _onResize(dx, dy, false, false)), // BR

        // Drag Center
        Positioned(
          left: x + 20,
          top: y + 20,
          width: (w - 40).clamp(0, double.infinity),
          height: (h - 40).clamp(0, double.infinity),
          child: GestureDetector(
            onPanUpdate: (details) {
              setState(() {
                _localX = (_localX + details.delta.dx / _imgW).clamp(0.0, 1.0 - _localW);
                _localY = (_localY + details.delta.dy / _imgH).clamp(0.0, 1.0 - _localH);
              });
            },
            onPanEnd: (_) => widget.notifier.updateCrop(_localX, _localY, _localW, _localH),
            child: Container(color: Colors.transparent),
          ),
        ),
      ],
    );
  }

  void _onResize(double dx, double dy, bool left, bool top) {
    setState(() {
      double newX = _localX;
      double newY = _localY;
      double newW = _localW;
      double newH = _localH;

      final deltaX = dx / _imgW;
      final deltaY = dy / _imgH;

      if (left) {
        final change = deltaX.clamp(-_localX, _localW - 0.1);
        newX += change;
        newW -= change;
      } else {
        newW = (newW + deltaX).clamp(0.1, 1.0 - _localX);
      }

      if (top) {
        final change = deltaY.clamp(-_localY, _localH - 0.1);
        newY += change;
        newH -= change;
      } else {
        newH = (newH + deltaY).clamp(0.1, 1.0 - _localY);
      }

      // Aspect Ratio Enforcement
      final ratio = widget.state.aspectRatio;
      if (ratio != null && ratio > 0) {
        // Adjust based on the side being dragged
        if (left || !left && !top) { // Dragging from left or bottom-right
          newH = newW / ratio;
          if (newY + newH > 1.0) {
            newH = 1.0 - newY;
            newW = newH * ratio;
          }
          if (newX + newW > 1.0) {
            newW = 1.0 - newX;
            newH = newW / ratio;
          }
        } else { // Dragging from top or top-right
          newW = newH * ratio;
          if (newX + newW > 1.0) {
            newW = 1.0 - newX;
            newH = newW / ratio;
          }
          if (newY + newH > 1.0) {
            newH = 1.0 - newY;
            newW = newH * ratio;
          }
        }
      }

      _localX = newX;
      _localY = newY;
      _localW = newW;
      _localH = newH;
    });
    // Sync with provider on drag end usually better for performance but provider might be needed for UI logic
    widget.notifier.updateCrop(_localX, _localY, _localW, _localH);
  }

  Widget _buildImage(BoxFit fit) {
    Widget img = Image.file(widget.state.imageFile!, fit: fit);
    if (widget.state.flipHorizontal || widget.state.flipVertical) {
      img = Transform(
        alignment: Alignment.center,
        transform: Matrix4.rotationY(widget.state.flipHorizontal ? 3.14159 : 0)
          ..rotateX(widget.state.flipVertical ? 3.14159 : 0),
        child: img,
      );
    }
    if (widget.state.rotation != 0) {
      img = RotatedBox(quarterTurns: widget.state.rotation ~/ 90, child: img);
    }
    return img;
  }

  Widget _buildHandle(double x, double y, Function(double, double) onDrag) {
    return Positioned(
      left: x - 20,
      top: y - 20,
      child: GestureDetector(
        onPanUpdate: (details) => onDrag(details.delta.dx, details.delta.dy),
        child: Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          color: Colors.transparent,
          child: Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: AppTheme.primaryColor, width: 2.5),
              boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4)],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGridLines() {
    return Stack(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Container(width: 1, color: Colors.white38),
            Container(width: 1, color: Colors.white38),
          ],
        ),
        Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Container(height: 1, color: Colors.white38),
            Container(height: 1, color: Colors.white38),
          ],
        ),
      ],
    );
  }
}

extension _Placeholder on _CropImageScreenState {

  Widget _buildAspectRatioToolbar(CropImageState state, CropImageNotifier notifier, bool isDark) {
    final ratios = [
      {'label': 'Free', 'value': null},
      {'label': '1:1', 'value': 1.0},
      {'label': '4:3', 'value': 4 / 3},
      {'label': '16:9', 'value': 16 / 9},
      {'label': 'Original', 'value': -1.0}, // Special value for original
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: ratios.map((r) {
            final isSelected = state.aspectRatio == r['value'];
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(r['label'] as String),
                selected: isSelected,
                onSelected: (selected) {
                  if (selected) {
                    final val = r['value'] as double?;
                    notifier.setAspectRatio(val);
                  }
                },
                selectedColor: AppTheme.primaryColor,
                labelStyle: TextStyle(
                  color: isSelected ? Colors.white : AppTheme.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
                backgroundColor: isDark ? AppTheme.darkSurface : Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusXL)),
                showCheckmark: false,
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildControlRow(CropImageState state, CropImageNotifier notifier, bool isDark) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusXL),
        border: Border.all(color: isDark ? AppTheme.darkBorder : AppTheme.borderColor),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildControlButton(
            icon: Icons.rotate_90_degrees_ccw_rounded,
            label: 'Rotate 90°',
            onTap: () => notifier.rotate(),
            isDark: isDark,
          ),
          _buildVerticalDivider(isDark),
          _buildControlButton(
            icon: Icons.flip_rounded,
            label: 'Flip Horiz.',
            onTap: () => notifier.flipHorizontal(),
            isDark: isDark,
          ),
          _buildVerticalDivider(isDark),
          _buildControlButton(
            icon: Icons.flip_rounded, // Should be rotating it
            label: 'Flip Vert.',
            onTap: () => notifier.flipVertical(),
            isDark: isDark,
            rotateIcon: true,
          ),
        ],
      ),
    );
  }

  Widget _buildControlButton({required IconData icon, required String label, required VoidCallback onTap, required bool isDark, bool rotateIcon = false}) {
    return InkWell(
      onTap: onTap,
      child: Column(
        children: [
          Transform.rotate(
            angle: rotateIcon ? 1.5708 : 0,
            child: Icon(icon, color: AppTheme.textSecondary, size: 28),
          ),
          const SizedBox(height: 6),
          Text(
            label.toUpperCase(),
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5),
          ),
        ],
      ),
    );
  }

  Widget _buildVerticalDivider(bool isDark) {
    return Container(
      height: 30,
      width: 1,
      color: isDark ? Colors.white12 : Colors.black12,
    );
  }

  Widget _buildOutputSettings(CropImageState state, CropImageNotifier notifier, bool isDark) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusXL),
        border: Border.all(color: isDark ? AppTheme.darkBorder : AppTheme.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('OUTPUT FORMAT', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.textSecondary)),
          const SizedBox(height: 8),
          DropdownButtonFormField<ImageOutputFormat>(
            initialValue: state.outputFormat,
            decoration: InputDecoration(
              fillColor: isDark ? AppTheme.darkBackground : const Color(0xFFF8FAFC),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
            ),
            items: ImageOutputFormat.values.map((f) {
              return DropdownMenuItem(value: f, child: Text(f.label, style: const TextStyle(fontSize: 14)));
            }).toList(),
            onChanged: (val) => val != null ? notifier.setOutputFormat(val) : null,
          ),
          const SizedBox(height: 20),
          const Text('OUTPUT FILE NAME', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.textSecondary)),
          const SizedBox(height: 8),
          TextFormField(
            controller: _fileNameController,
            onChanged: (val) => notifier.setOutputFileName(val),
            decoration: InputDecoration(
              fillColor: isDark ? AppTheme.darkBackground : const Color(0xFFF8FAFC),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
            style: const TextStyle(fontSize: 14),
          ),
          const SizedBox(height: 16),
          const Row(
            children: [
              Icon(Icons.info_outline_rounded, size: 14, color: AppTheme.textSecondary),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Original image will not be changed (Offline-first)',
                  style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBottomButton(CropImageState state, CropImageNotifier notifier, bool isDark) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        decoration: BoxDecoration(
          color: (isDark ? AppTheme.darkBackground : Colors.white).withValues(alpha: 0.9),
          border: Border(top: BorderSide(color: isDark ? AppTheme.darkBorder : AppTheme.borderColor)),
        ),
        child: ElevatedButton.icon(
          onPressed: () => _handleCropAction(context, notifier),
          icon: const Icon(Icons.crop_rounded),
          label: const Text('CROP IMAGE'),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 18),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusM)),
          ),
        ),
      ),
    );
  }

  Future<void> _handleCropAction(BuildContext context, CropImageNotifier notifier) async {
    final result = await notifier.processImage();
    if (result != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Image cropped successfully!'),
          backgroundColor: AppTheme.successColor,
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: 'View',
            textColor: Colors.white,
            onPressed: () {
              // Open viewer logic
            },
          ),
        ),
      );
      Navigator.pop(context);
    } else if (mounted) {
      final error = ref.read(cropImageProvider).error;
      if (error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error), backgroundColor: AppTheme.errorColor),
        );
      }
    }
  }

  Widget _buildLoadingOverlay(CropImageState state) {
    return Container(
      color: Colors.black54,
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(AppTheme.radiusXL),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(value: state.processingProgress > 0 ? state.processingProgress : null),
              const SizedBox(height: 24),
              Text(
                state.processingStatus,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text('${(state.processingProgress * 100).toInt()}%'),
            ],
          ),
        ),
      ),
    );
  }
}
