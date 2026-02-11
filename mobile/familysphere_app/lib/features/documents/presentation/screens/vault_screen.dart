import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:familysphere_app/core/utils/routes.dart';
import 'package:familysphere_app/features/documents/presentation/providers/document_provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class VaultScreen extends ConsumerStatefulWidget {
  const VaultScreen({super.key});

  @override
  ConsumerState<VaultScreen> createState() => _VaultScreenState();
}

class _VaultScreenState extends ConsumerState<VaultScreen> {
  @override
  void initState() {
    super.initState();
    // Load documents on startup
    Future.microtask(() => 
      ref.read(documentProvider.notifier).loadDocuments()
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(documentProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF111418);
    final secondaryTextColor = isDark ? Colors.white70 : const Color(0xFF637588);
    final borderColor = isDark ? const Color(0xFF1E293B) : const Color(0xFFDCE0E5);
    final iconBgColor = isDark ? const Color(0xFF1E293B) : const Color(0xFFF0F2F4);

    final storageUsedStr = _formatBytes(state.storageUsed);
    final storageLimitStr = _formatBytes(state.storageLimit);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF020617) : Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Custom App Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  const SizedBox(width: 48), // Spacing for balance
                  Expanded(
                    child: Text(
                      'Family Vault',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => ref.read(documentProvider.notifier).loadDocuments(),
                    icon: Icon(state.isLoading ? Icons.sync : Icons.settings_outlined, color: textColor, size: 24),
                  ),
                ],
              ),
            ),

            if (state.isLoading && state.documents.isEmpty)
              const Expanded(child: Center(child: CircularProgressIndicator()))
            else
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () => ref.read(documentProvider.notifier).loadDocuments(),
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Storage Info Card
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: borderColor),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Storage',
                                  style: GoogleFonts.inter(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                    color: textColor,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '$storageUsedStr / $storageLimitStr',
                                  style: GoogleFonts.inter(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: textColor,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: LinearProgressIndicator(
                                    value: state.storageLimit > 0 ? state.storageUsed / state.storageLimit : 0,
                                    backgroundColor: iconBgColor,
                                    valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF1980E6)),
                                    minHeight: 8,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Quick Access Section
                        _buildSectionHeader('Quick Access', textColor),

                        _buildQuickAccessCard(
                          context,
                          category: 'Shared',
                          title: 'Family Vault',
                          description: 'Access documents shared with your family',
                          imageUrl: 'https://lh3.googleusercontent.com/aida-public/AB6AXuARFceGqNLWSMLJXCM4gfSGgBK5E4Yv7euZelb5kr95Rcw3P5MIfRRdQRNRnnCJTLNqaNVUBGL2mJEc3gRaMy6asf040WiWqjkuho0wDPSxG5uGpt_lnaxRS70sRGBiZvsCOZ1m-JxHJdaHA0uNJPhFEtX_t7EIZp8FRfqPrSFJC1lnwSS-Jsnq8XYWMjh0lRJeyR0YM969PCPmVXqF9hiCQ956dBzrEcg4IVlYIzQyE-bOb5ZRMAFL3580ioF3yS1IQu6Oli4EFQ',
                          textColor: textColor,
                          secondaryTextColor: secondaryTextColor,
                          onTap: () => _showCategoryFilter(context, 'Shared'),
                        ),

                        _buildQuickAccessCard(
                          context,
                          category: 'Personal',
                          title: 'My Documents',
                          description: 'Store your own non-family documents',
                          imageUrl: 'https://lh3.googleusercontent.com/aida-public/AB6AXuCQ9m31mRjMPJROHvR9O3nVymTJPcuf_KS9YL9FyudXmw_zkOZNlPaCxq-CGaRbhmuTiPEpBmEOg9G5RXcbdziUnqj0jo9qZi1htg3J-ureNYgnwsNPPXnGRe6DGGLll0c0crc4YpLiLC87QZsBS50XWg0LsrVaF_CylA0BewwAmBroLRkrul9q5Vu8V7ufkSsbsvCfC6AGHgo9oS-qMRaiWTD523EQolbVo5-eEtQaHwdKcJa3MjGDTqWleea1rjSqT0gWE_kFZg',
                          textColor: textColor,
                          secondaryTextColor: secondaryTextColor,
                          onTap: () => _showCategoryFilter(context, 'Personal'),
                        ),

                        _buildQuickAccessCard(
                          context,
                          category: 'Private',
                          title: 'Vault',
                          description: 'Securely store sensitive documents for personal use',
                          imageUrl: 'https://lh3.googleusercontent.com/aida-public/AB6AXuCruux6y-5ZgZS2O2Vy8_uh-GvBBKlJfueapBy1zs1htvDgU4E0ixrTfHRzE9XvphPm2B75WOUjRX66acMjOhmL_vd_k39RPOIO5xJVO7Jk2_t66r68TEiycF7t5no8sxK3kvESQ7P-x581Wxui9C0ZH1Af1CH0Czt0-CPkqjZqbtJTBCCABEwkfgF7nAj4e3DEZcL1hEx89bhHSWj7yn-L0ncGKfL6JuCfaOk0Cct-6pUoYNNTN6D2EyGoWGu6_dWJ6xw3Z3Xlpg',
                          textColor: textColor,
                          secondaryTextColor: secondaryTextColor,
                          onTap: () => _showCategoryFilter(context, 'Private'),
                        ),

                        // Recent Documents
                        _buildSectionHeader('Recent Documents', textColor),

                        if (state.documents.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                            child: Text(
                              'No documents yet. Tap Scan/Upload to add one.',
                              style: TextStyle(color: secondaryTextColor),
                            ),
                          )
                        else
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: state.documents.length > 5 ? 5 : state.documents.length,
                            itemBuilder: (context, index) {
                              final doc = state.documents[index];
                              return _buildRecentDocItem(
                                doc.title, 
                                _formatDate(doc.uploadedAt), 
                                textColor, 
                                secondaryTextColor, 
                                iconBgColor,
                                () => Navigator.pushNamed(context, AppRoutes.documentViewer, arguments: doc),
                              );
                            },
                          ),

                        const SizedBox(height: 100), // Space for bottom button
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
      bottomSheet: Container(
        color: isDark ? const Color(0xFF020617) : Colors.white,
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                ElevatedButton.icon(
                  onPressed: () async {
                    await Navigator.pushNamed(context, AppRoutes.addDocument);
                    ref.read(documentProvider.notifier).loadDocuments();
                  },
                  icon: const Icon(Icons.add_rounded, size: 24, color: Colors.white),
                  label: const Text('Scan/Upload'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1980E6),
                    foregroundColor: Colors.white,
                    minimumSize: const Size(180, 56),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    textStyle: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showCategoryFilter(BuildContext context, String category) {
    // Navigate to a filtered list or show a modal
    Navigator.pushNamed(context, AppRoutes.documents, arguments: {'category': category});
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) return "Today";
    if (difference.inDays == 1) return "Yesterday";
    if (difference.inDays < 7) return "${difference.inDays} days ago";
    return DateFormat('MMM d, yyyy').format(date);
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) return "0 B";
    if (bytes < 1024) return "$bytes B";
    if (bytes < 1024 * 1024) return "${(bytes / 1024).toStringAsFixed(1)} KB";
    if (bytes < 1024 * 1024 * 1024) return "${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB";
    return "${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB";
  }

  Widget _buildSectionHeader(String title, Color textColor) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
      child: Text(
        title,
        style: GoogleFonts.inter(
          fontSize: 22,
          fontWeight: FontWeight.bold,
          color: textColor,
          letterSpacing: -0.4,
        ),
      ),
    );
  }

  Widget _buildQuickAccessCard(
    BuildContext context, {
    required String category,
    required String title,
    required String description,
    required String imageUrl,
    required Color textColor,
    required Color secondaryTextColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    category,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.normal,
                      color: secondaryTextColor,
                    ),
                  ),
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.normal,
                      color: secondaryTextColor,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    image: DecorationImage(
                      image: NetworkImage(imageUrl),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentDocItem(String title, String subtitle, Color textColor, Color secondaryTextColor, Color iconBgColor, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: iconBgColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.insert_drive_file_outlined, color: textColor),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: textColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: secondaryTextColor,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
