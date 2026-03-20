import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:familysphere_app/core/providers/ocr_status_provider.dart';
import 'package:familysphere_app/features/documents/presentation/widgets/confirm_type_banner.dart';

/// Animated card that shows real-time OCR job progress.
///
/// Mount it after a document upload with the returned [docId].
/// Call [onDone] when the job finishes so the caller can navigate away.
class OcrStatusBanner extends ConsumerStatefulWidget {
  final String docId;
  final VoidCallback? onDone;
  final VoidCallback? onDismiss;

  const OcrStatusBanner({
    super.key,
    required this.docId,
    this.onDone,
    this.onDismiss,
  });

  @override
  ConsumerState<OcrStatusBanner> createState() => _OcrStatusBannerState();
}

class _OcrStatusBannerState extends ConsumerState<OcrStatusBanner>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulse;
  bool _calledDone = false;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final polling = ref.watch(ocrStatusProvider(widget.docId));

    // Fire onDone automatically only for truly terminal states (done / failed).
    // For needs_confirmation the user must interact with ConfirmTypeBanner first.
    final autoFinished = polling.result?.isDone == true ||
        polling.result?.isFailed == true;
    if (autoFinished && !_calledDone) {
      _calledDone = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => widget.onDone?.call());
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 350),
      transitionBuilder: (child, anim) =>
          FadeTransition(opacity: anim, child: SizeTransition(sizeFactor: anim, child: child)),
      child: _buildCard(polling),
    );
  }

  Widget _buildCard(OcrPollingState polling) {
    // ── Error ────────────────────────────────────────────────────────────────
    if (polling.error != null) {
      return _shell(
        key: const ValueKey('error'),
        color: const Color(0xFFFEF2F2),
        border: const Color(0xFFEF4444),
        child: Row(children: [
          const Icon(Icons.error_outline_rounded, color: Color(0xFFEF4444), size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              polling.error!,
              style: const TextStyle(fontSize: 13, color: Color(0xFFDC2626)),
            ),
          ),
          _dismissButton(),
        ]),
      );
    }

    final result = polling.result;

    // ── Done ─────────────────────────────────────────────────────────────────
    if (result?.isDone == true) {
      return _shell(
        key: const ValueKey('done'),
        color: const Color(0xFFF0FDF4),
        border: const Color(0xFF22C55E),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 20),
              const SizedBox(width: 8),
              const Text(
                'AI Analysis Complete',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF15803D),
                ),
              ),
              const Spacer(),
              _dismissButton(),
            ]),
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 6, children: [
              if (result!.docType != null && result.docType != 'unknown')
                _chip(
                  Icons.article_rounded,
                  result.docTypeLabel,
                  const Color(0xFF1D4ED8),
                  const Color(0xFFEFF6FF),
                ),
              _chip(
                Icons.analytics_rounded,
                '${result.confidencePct}% confidence',
                _confidenceColor(result.ocrConfidence ?? 0),
                _confidenceColor(result.ocrConfidence ?? 0).withOpacity(0.1),
              ),
              if (result.expiryDate != null)
                _chip(
                  Icons.event_rounded,
                  'Exp: ${_fmt(result.expiryDate!)}',
                  const Color(0xFF9333EA),
                  const Color(0xFFF5F3FF),
                ),
              if (result.amount != null)
                _chip(
                  Icons.currency_rupee_rounded,
                  '₹${result.amount!.toStringAsFixed(2)}',
                  const Color(0xFF0369A1),
                  const Color(0xFFE0F2FE),
                ),
            ]),
          ],
        ),
      );
    }

    // ── Needs Confirmation ────────────────────────────────────────────────────
    if (result?.isNeedsConfirmation == true) {
      return _shell(
        key: const ValueKey('needs_confirmation'),
        color: const Color(0xFFFFFBEB),
        border: const Color(0xFFF59E0B),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(Icons.help_outline_rounded, color: Color(0xFFD97706), size: 20),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'AI needs your confirmation',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF92400E),
                  ),
                ),
              ),
              _dismissButton(),
            ]),
            const SizedBox(height: 4),
            Text(
              'Confidence is low — please confirm the document type below.',
              style: TextStyle(fontSize: 12, color: Colors.orange.shade800),
            ),
            const SizedBox(height: 10),
            ConfirmTypeBanner(
              docId: widget.docId,
              aiDetectedType: result!.docType ?? 'unknown',
              onConfirmed: widget.onDone,
            ),
          ],
        ),
      );
    }

    // ── Failed ───────────────────────────────────────────────────────────────
    if (result?.isFailed == true) {
      return _shell(
        key: const ValueKey('failed'),
        color: const Color(0xFFFFF7ED),
        border: const Color(0xFFF97316),
        child: Row(children: [
          const Icon(Icons.warning_amber_rounded, color: Color(0xFFEA580C), size: 20),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'AI analysis failed — document saved successfully.',
              style: TextStyle(fontSize: 13, color: Color(0xFFC2410C)),
            ),
          ),
          _dismissButton(),
        ]),
      );
    }

    // ── Pending / Processing ─────────────────────────────────────────────────
    return _shell(
      key: const ValueKey('processing'),
      color: const Color(0xFFF0F9FF),
      border: const Color(0xFF38BDF8),
      child: Row(children: [
        AnimatedBuilder(
          animation: _pulse,
          builder: (_, __) => Opacity(
            opacity: 0.5 + _pulse.value * 0.5,
            child: const Icon(Icons.auto_awesome_rounded,
                color: Color(0xFF0284C7), size: 20),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Analyzing document with AI…',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF0369A1),
                ),
              ),
              const SizedBox(height: 5),
              LinearProgressIndicator(
                value: null,
                backgroundColor: const Color(0xFFBAE6FD),
                color: const Color(0xFF0284C7),
                borderRadius: BorderRadius.circular(4),
                minHeight: 3,
              ),
              const SizedBox(height: 4),
              Text(
                result?.isPending == true
                    ? 'Queued — waiting for worker…'
                    : 'Extracting text, classifying, detecting dates…',
                style: const TextStyle(fontSize: 11, color: Color(0xFF0369A1)),
              ),
            ],
          ),
        ),
      ]),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  Widget _shell({
    required Key key,
    required Color color,
    required Color border,
    required Widget child,
  }) {
    return Container(
      key: key,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border.withOpacity(0.4), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: border.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _chip(IconData icon, String label, Color fg, Color bg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: fg.withOpacity(0.25)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 12, color: fg),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: fg,
          ),
        ),
      ]),
    );
  }

  Widget _dismissButton() {
    return GestureDetector(
      onTap: widget.onDismiss,
      child: const Icon(Icons.close_rounded, size: 16, color: Colors.black45),
    );
  }

  Color _confidenceColor(double c) {
    if (c >= 0.75) return const Color(0xFF16A34A);
    if (c >= 0.5)  return const Color(0xFFCA8A04);
    return const Color(0xFFDC2626);
  }

  String _fmt(DateTime dt) {
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }
}
