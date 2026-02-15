import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:familysphere_app/core/theme/app_theme.dart';
import 'package:familysphere_app/features/family/presentation/providers/family_provider.dart';

class JoinFamilyScreen extends ConsumerStatefulWidget {
  const JoinFamilyScreen({super.key});

  @override
  ConsumerState<JoinFamilyScreen> createState() => _JoinFamilyScreenState();
}

class _JoinFamilyScreenState extends ConsumerState<JoinFamilyScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _codeController = TextEditingController();
  bool _isScanning = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  void _handleJoinByCode() async {
    final code = _codeController.text.trim().toUpperCase();
    if (code.isEmpty) return;

    try {
      await ref.read(familyProvider.notifier).joinWithInvite(code: code);
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/join-success');
      }
    } catch (e) {
      _showError(e.toString());
    }
  }

  void _onDetect(BarcodeCapture capture) async {
    if (_isScanning) return;
    final List<Barcode> barcodes = capture.barcodes;
    for (final barcode in barcodes) {
      final String? token = barcode.rawValue;
      if (token != null) {
        _isScanning = true;
        try {
          await ref.read(familyProvider.notifier).joinWithInvite(token: token);
          if (mounted) {
            Navigator.pushReplacementNamed(context, '/join-success');
          }
        } catch (e) {
          _isScanning = false;
          _showError('Invalid QR Code: $e');
        }
        break;
      }
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: AppTheme.errorColor,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isLoading = ref.watch(familyProvider).isLoading;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Join Family'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Enter Code', icon: Icon(Icons.keyboard_outlined)),
            Tab(text: 'Scan QR', icon: Icon(Icons.qr_code_scanner_outlined)),
          ],
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildCodeEntryView(isDark),
                _buildScannerView(),
              ],
            ),
    );
  }

  Widget _buildCodeEntryView(bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.group_add_outlined, size: 80, color: AppTheme.primaryColor),
          const SizedBox(height: 24),
          const Text(
            'Enter Invite Code',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Ask the family admin for a 6-digit code.',
            style: TextStyle(color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 48),
          TextField(
            controller: _codeController,
            decoration: InputDecoration(
              hintText: 'ABC 123',
              counterText: '',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
              filled: true,
              fillColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey[100],
            ),
            maxLength: 8,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: 8),
            textCapitalization: TextCapitalization.characters,
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _handleJoinByCode,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleAppTheme.radiusM,
              ),
              child: const Text('Join Family', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScannerView() {
    return Stack(
      children: [
        MobileScanner(
          onDetect: _onDetect,
        ),
        _buildScannerOverlay(),
      ],
    );
  }

  Widget _buildScannerOverlay() {
    return Container(
      decoration: ShapeDecoration(
        shape: QrScannerOverlayShape(
          borderColor: AppTheme.primaryColor,
          borderRadius: 16,
          borderLength: 30,
          borderWidth: 10,
          cutOutSize: 250,
        ),
      ),
    );
  }
}

// Simple custom overlay shape for QR scanner
class QrScannerOverlayShape extends ShapeBorder {
  final Color borderColor;
  final double borderWidth;
  final Color overlayColor;
  final double borderRadius;
  final double borderLength;
  final double cutOutSize;

  QrScannerOverlayShape({
    this.borderColor = Colors.white,
    this.borderWidth = 10,
    this.overlayColor = const Color(0x88000000),
    this.borderRadius = 0,
    this.borderLength = 40,
    this.cutOutSize = 250,
  });

  @override
  EdgeInsetsGeometry get dimensions => const EdgeInsets.all(10);

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) {
    return Path()
      ..addRRect(RRect.fromRectAndRadius(
          Rect.fromCenter(center: rect.center, width: cutOutSize, height: cutOutSize), Radius.circular(borderRadius)))
      ..fillType = PathFillType.evenOdd;
  }

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    return Path()..addRect(rect);
  }

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    final width = rect.width;
    final height = rect.height;

    final backgroundPaint = Paint()
      ..color = overlayColor
      ..style = PaintingStyle.fill;

    final cutOutRect = Rect.fromCenter(
      center: Offset(width / 2, height / 2),
      width: cutOutSize,
      height: cutOutSize,
    );

    canvas.drawPath(
      Path.combine(
        PathOperation.difference,
        Path()..addRect(rect),
        Path()..addRRect(RRect.fromRectAndRadius(cutOutRect, Radius.circular(borderRadius))),
      ),
      backgroundPaint,
    );

    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth
      ..strokeCap = StrokeCap.round;

    final double halfWidth = cutOutSize / 2;
    final double halfHeight = cutOutSize / 2;
    final center = rect.center;

    // Top Left
    canvas.drawPath(
      Path()
        ..moveTo(center.dx - halfWidth, center.dy - halfHeight + borderLength)
        ..lineTo(center.dx - halfWidth, center.dy - halfHeight + borderRadius)
        ..arcToPoint(Offset(center.dx - halfWidth + borderRadius, center.dy - halfHeight), radius: Radius.circular(borderRadius))
        ..lineTo(center.dx - halfWidth + borderLength, center.dy - halfHeight),
      borderPaint,
    );

    // Top Right
    canvas.drawPath(
      Path()
        ..moveTo(center.dx + halfWidth - borderLength, center.dy - halfHeight)
        ..lineTo(center.dx + halfWidth - borderRadius, center.dy - halfHeight)
        ..arcToPoint(Offset(center.dx + halfWidth, center.dy - halfHeight + borderRadius), radius: Radius.circular(borderRadius))
        ..lineTo(center.dx + halfWidth, center.dy - halfHeight + borderLength),
      borderPaint,
    );

    // Bottom Right
    canvas.drawPath(
      Path()
        ..moveTo(center.dx + halfWidth, center.dy + halfHeight - borderLength)
        ..lineTo(center.dx + halfWidth, center.dy + halfHeight - borderRadius)
        ..arcToPoint(Offset(center.dx + halfWidth - borderRadius, center.dy + halfHeight), radius: Radius.circular(borderRadius))
        ..lineTo(center.dx + halfWidth - borderLength, center.dy + halfHeight),
      borderPaint,
    );

    // Bottom Left
    canvas.drawPath(
      Path()
        ..moveTo(center.dx - halfWidth + borderLength, center.dy + halfHeight)
        ..lineTo(center.dx - halfWidth + borderRadius, center.dy + halfHeight)
        ..arcToPoint(Offset(center.dx - halfWidth, center.dy + halfHeight - borderRadius), radius: Radius.circular(borderRadius))
        ..lineTo(center.dx - halfWidth, center.dy + halfHeight - borderLength),
      borderPaint,
    );
  }

  @override
  ShapeBorder scale(double t) {
    return QrScannerOverlayShape(
      borderColor: borderColor,
      borderWidth: borderWidth,
      overlayColor: overlayColor,
    );
  }
}
// Helper for border radius on ElevatedButton which I used and might not be exactly in AppTheme
extension RoundedRectangleAppTheme on RoundedRectangleBorder {
  static final radiusM = RoundedRectangleBorder(borderRadius: BorderRadius.circular(16));
}
