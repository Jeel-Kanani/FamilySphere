import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:familysphere_app/features/documents/presentation/providers/document_intelligence_provider.dart';

/// Shows a banner when AI confidence is low (< 70%).
/// Lets user pick the correct document type from a dropdown.
/// On confirm → calls PATCH /api/documents/:id/confirm-type.
class ConfirmTypeBanner extends ConsumerStatefulWidget {
  final String docId;
  final String aiDetectedType;

  /// Called after user successfully confirms the type.
  final VoidCallback? onConfirmed;

  const ConfirmTypeBanner({
    super.key,
    required this.docId,
    required this.aiDetectedType,
    this.onConfirmed,
  });

  @override
  ConsumerState<ConfirmTypeBanner> createState() => _ConfirmTypeBannerState();
}

class _ConfirmTypeBannerState extends ConsumerState<ConfirmTypeBanner> {
  late String _selectedType;
  bool _dismissed = false;

  @override
  void initState() {
    super.initState();
    _selectedType = widget.aiDetectedType;
  }

  @override
  Widget build(BuildContext context) {
    if (_dismissed) return const SizedBox.shrink();

    final confirmState = ref.watch(confirmTypeProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isLoading = confirmState.isLoading;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF2C2200)
            : const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark
              ? const Color(0xFFFF6F00).withValues(alpha: 0.4)
              : const Color(0xFFFF6F00).withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ─────────────────────────────────────────────────────────
          Row(
            children: [
              const Icon(Icons.auto_awesome, color: Color(0xFFFF6F00), size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'AI is not fully sure about this document',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: isDark ? Colors.white.withValues(alpha: 0.87) : Colors.grey.shade800,
                  ),
                ),
              ),
              GestureDetector(
                onTap: () => setState(() => _dismissed = true),
                child: Icon(Icons.close, size: 18,
                    color: isDark ? Colors.white38 : Colors.grey.shade500),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Detected as "${widget.aiDetectedType}". Is this correct?',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.white54 : Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 12),

          // ── Dropdown ───────────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: isDark ? Colors.white10 : Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isDark ? Colors.white24 : Colors.grey.shade300,
              ),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedType,
                isExpanded: true,
                dropdownColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.white87 : Colors.grey.shade800,
                ),
                items: kAllowedDocTypes.map((type) {
                  return DropdownMenuItem<String>(
                    value: type,
                    child: Text(type),
                  );
                }).toList(),
                onChanged: isLoading
                    ? null
                    : (val) {
                        if (val != null) setState(() => _selectedType = val);
                      },
              ),
            ),
          ),
          const SizedBox(height: 12),

          // ── Action Buttons ─────────────────────────────────────────────────
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: isLoading
                      ? null
                      : () => setState(() => _dismissed = true),
                  style: OutlinedButton.styleFrom(
                    foregroundColor:
                        isDark ? Colors.white54 : Colors.grey.shade600,
                    side: BorderSide(
                      color: isDark ? Colors.white24 : Colors.grey.shade300,
                    ),
                  ),
                  child: const Text('Skip', style: TextStyle(fontSize: 13)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: FilledButton(
                  onPressed: isLoading ? null : _confirm,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFFF6F00),
                  ),
                  child: isLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Confirm Type',
                          style: TextStyle(fontSize: 13, color: Colors.white),
                        ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _confirm() async {
    await ref
        .read(confirmTypeProvider.notifier)
        .confirm(docId: widget.docId, docType: _selectedType);

    if (!mounted) return;

    final state = ref.read(confirmTypeProvider);
    if (state.hasError) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to update document type. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
    } else {
      setState(() => _dismissed = true);
      // Invalidate intelligence cache so the card refreshes
      ref.invalidate(documentIntelligenceProvider(widget.docId));
      widget.onConfirmed?.call();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Document type updated to "$_selectedType"'),
          backgroundColor: const Color(0xFF43A047),
        ),
      );
    }
  }
}
