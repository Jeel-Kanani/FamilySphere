import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:familysphere_app/core/theme/app_theme.dart';

enum UploadStage { scanning, depositing, success }

class PremiumUploadOverlay extends StatefulWidget {
  final VoidCallback onComplete;

  const PremiumUploadOverlay({
    super.key,
    required this.onComplete,
  });

  @override
  State<PremiumUploadOverlay> createState() => PremiumUploadOverlayState();
}

class PremiumUploadOverlayState extends State<PremiumUploadOverlay>
    with TickerProviderStateMixin {
  late AnimationController _scannerController;
  late AnimationController _depositController;
  late AnimationController _successController;

  UploadStage _stage = UploadStage.scanning;

  @override
  void initState() {
    super.initState();
    
    _scannerController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _depositController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _successController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
  }

  void startDeposit() {
    if (!mounted) return;
    setState(() => _stage = UploadStage.depositing);
    _scannerController.stop();
    _depositController.forward().then((_) {
      if (!mounted) return;
      setState(() => _stage = UploadStage.success);
      _successController.forward().then((_) {
        // Wait a bit to show success before completing
        Future.delayed(const Duration(milliseconds: 800), widget.onComplete);
      });
    });
  }

  @override
  void dispose() {
    _scannerController.dispose();
    _depositController.dispose();
    _successController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
      child: Container(
        color: Colors.black.withOpacity(0.7),
        child: Center(
          child: _buildContent(),
        ),
      ),
    );
  }

  Widget _buildContent() {
    switch (_stage) {
      case UploadStage.scanning:
        return _buildScanningStage();
      case UploadStage.depositing:
        return _buildDepositingStage();
      case UploadStage.success:
        return _buildSuccessStage();
    }
  }

  Widget _buildScanningStage() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            // Document Card
            Container(
              width: 140,
              height: 180,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.3)),
              ),
              child: const Icon(Icons.description_rounded, size: 64, color: Colors.white70),
            ),
            
            // Scanning Beam
            AnimatedBuilder(
              animation: _scannerController,
              builder: (context, child) {
                return Positioned(
                  top: 180 * _scannerController.value,
                  child: Container(
                    width: 160,
                    height: 4,
                    decoration: BoxDecoration(
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primaryColor.withOpacity(0.8),
                          blurRadius: 10,
                          spreadRadius: 2,
                        ),
                      ],
                      gradient: LinearGradient(
                        colors: [
                          AppTheme.primaryColor.withOpacity(0),
                          AppTheme.primaryColor,
                          AppTheme.primaryColor.withOpacity(0),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
        const SizedBox(height: 40),
        const Text(
          'Securing Document...',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Moving to Vault encrypted storage',
          style: TextStyle(
            color: Colors.white.withOpacity(0.6),
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Widget _buildDepositingStage() {
    final slideAnimation = CurvedAnimation(parent: _depositController, curve: Curves.easeInBack);
    final scaleAnimation = Tween<double>(begin: 1.0, end: 0.2).animate(_depositController);
    final opacityAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _depositController, curve: const Interval(0.5, 1.0))
    );

    return Stack(
      alignment: Alignment.center,
      children: [
        // Vault Icon at destination
        Opacity(
          opacity: _depositController.value,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.2),
              shape: BoxShape.circle,
              border: Border.all(color: AppTheme.primaryColor.withOpacity(0.5)),
            ),
            child: Icon(Icons.shield_rounded, size: 80, color: AppTheme.primaryColor),
          ),
        ),
        
        // Flying Document
        AnimatedBuilder(
          animation: _depositController,
          builder: (context, child) {
            return Transform.translate(
              offset: Offset(0, -100 * (1 - slideAnimation.value)),
              child: Transform.scale(
                scale: scaleAnimation.value,
                child: Opacity(
                  opacity: opacityAnimation.value,
                  child: Container(
                    width: 140,
                    height: 180,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white),
                    ),
                    child: const Icon(Icons.file_upload_rounded, size: 64, color: Colors.white),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildSuccessStage() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ScaleTransition(
          scale: CurvedAnimation(parent: _successController, curve: Curves.elasticOut),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: Color(0xFF16A34A),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_rounded, size: 64, color: Colors.white),
          ),
        ),
        const SizedBox(height: 32),
        const Text(
          'Safe in Vault!',
          style: TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}
