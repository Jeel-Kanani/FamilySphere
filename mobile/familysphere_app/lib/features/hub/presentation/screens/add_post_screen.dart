import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:familysphere_app/core/theme/app_theme.dart';
import '../providers/hub_provider.dart';

class AddPostScreen extends ConsumerStatefulWidget {
  const AddPostScreen({super.key});

  @override
  ConsumerState<AddPostScreen> createState() => _AddPostScreenState();
}

class _AddPostScreenState extends ConsumerState<AddPostScreen> {
  final TextEditingController _contentController = TextEditingController();
  final List<String> _mediaUrls = [];
  String _selectedType = 'moment';

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBackground : AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text(
          'Share Moment',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextButton(
              onPressed: () async {
                if (_contentController.text.trim().isNotEmpty) {
                  await ref.read(hubProvider.notifier).createPost(
                    content: _contentController.text.trim(),
                    type: _selectedType,
                    mediaUrls: _mediaUrls,
                  );
                  if (mounted) Navigator.pop(context);
                }
              },
              child: Text(
                'Share',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryColor,
                ),
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // User Meta
            Row(
              children: [
                CircleAvatar(backgroundColor: AppTheme.primaryColor.withOpacity(0.1)),
                const SizedBox(width: 12),
                Text(
                  'Sharing to Family Hub',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Content Input
            TextField(
              controller: _contentController,
              maxLines: 10,
              style: GoogleFonts.plusJakartaSans(fontSize: 16),
              decoration: InputDecoration(
                hintText: 'What\'s on your mind?',
                border: InputBorder.none,
                hintStyle: TextStyle(
                  color: isDark ? Colors.white24 : Colors.black38,
                ),
              ),
            ),

            const SizedBox(height: 32),

            // Post Type Selection
            Text(
              'TYPE',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5,
                color: isDark ? Colors.white38 : Colors.grey,
              ),
            ),
            const SizedBox(height: 12),
            _buildTypeSelector(),

            const SizedBox(height: 40),
            
            // Media Placeholder (Simple indicator for now)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.darkSurface : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: isDark ? AppTheme.darkBorder : AppTheme.borderColor),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.add_photo_alternate_rounded, color: AppTheme.primaryColor),
                  const SizedBox(width: 12),
                  Text(
                    'Add Photos / Videos',
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryColor,
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

  Widget _buildTypeSelector() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _typeChip('moment', 'Moment', Icons.camera_rounded),
          const SizedBox(width: 12),
          _typeChip('milestone', 'Milestone', Icons.emoji_events_rounded),
          const SizedBox(width: 12),
          _typeChip('document_share', 'Doc Share', Icons.description_rounded),
        ],
      ),
    );
  }

  Widget _typeChip(String type, String label, IconData icon) {
    final isSelected = _selectedType == type;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: () => setState(() => _selectedType = type),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected 
              ? AppTheme.primaryColor 
              : (isDark ? AppTheme.darkSurface : Colors.grey.withOpacity(0.05)),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppTheme.primaryColor : (isDark ? AppTheme.darkBorder : Colors.transparent),
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected ? Colors.white : (isDark ? Colors.white54 : Colors.grey),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: isSelected ? Colors.white : (isDark ? Colors.white54 : Colors.grey),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
