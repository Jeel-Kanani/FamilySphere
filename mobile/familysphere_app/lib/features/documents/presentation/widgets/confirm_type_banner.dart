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
    // Ensure the initial value is always a valid entry in the dropdown list.
    // If AI returned an unknown/raw value, fall back to the first allowed type.
    _selectedType = kAllowedDocTypes.contains(widget.aiDetectedType)
        ? widget.aiDetectedType
        : kAllowedDocTypes.first;
  }

  @override
  Widget build(BuildContext context) {
    if (_dismissed) return const SizedBox.shrink();

    final confirmState = ref.watch(confirmTypeProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isLoading = confirmState.isLoading;

    const amberDeep = Color(0xFFFF6F00);
    const amber = Color(0xFFF59E0B);
    final textPrimary = isDark
        ? Colors.white.withValues(alpha: 0.9)
        : const Color(0xFF1C1917);
    final textSub = isDark ? Colors.white54 : Colors.grey.shade600;
    final dropdownBg = isDark ? const Color(0xFF1E1A00) : Colors.white;
    final dropdownBorder =
        isDark ? amber.withValues(alpha: 0.3) : amber.withValues(alpha: 0.45);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF241B00) : const Color(0xFFFFF8E6),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: dropdownBorder, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ─────────────────────────────────────────────────────────
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: amberDeep.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: const Icon(Icons.auto_awesome_rounded,
                    color: amberDeep, size: 14),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'AI needs your help',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: textPrimary,
                  ),
                ),
              ),
              GestureDetector(
                onTap: () => setState(() => _dismissed = true),
                child: Icon(Icons.close_rounded,
                    size: 16, color: textSub),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Detected as "${widget.aiDetectedType}". Confidence is low — pick the correct type:',
            style: TextStyle(fontSize: 11.5, color: textSub),
          ),
          const SizedBox(height: 12),

          // ── Dropdown ───────────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: dropdownBg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: dropdownBorder, width: 1.2),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedType,
                isExpanded: true,
                icon: Icon(Icons.expand_more_rounded,
                    color: amber, size: 20),
                dropdownColor:
                    isDark ? const Color(0xFF1E1A00) : Colors.white,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: textPrimary,
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
                      color: isDark
                          ? Colors.white24
                          : Colors.grey.shade300,
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  child: const Text('Skip', style: TextStyle(fontSize: 13)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: GestureDetector(
                  onTap: isLoading ? null : _confirm,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      gradient: isLoading
                          ? null
                          : const LinearGradient(
                              colors: [Color(0xFFFF6F00), Color(0xFFF59E0B)],
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            ),
                      color: isLoading ? Colors.grey.shade400 : null,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: isLoading
                          ? null
                          : [
                              BoxShadow(
                                color: const Color(0xFFF59E0B)
                                    .withValues(alpha: 0.35),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                    ),
                    alignment: Alignment.center,
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
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
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
