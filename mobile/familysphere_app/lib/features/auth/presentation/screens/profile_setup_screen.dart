import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:familysphere_app/core/theme/app_theme.dart';
import 'package:familysphere_app/features/auth/presentation/providers/auth_provider.dart';

class ProfileSetupScreen extends ConsumerStatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  ConsumerState<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends ConsumerState<ProfileSetupScreen>
    with SingleTickerProviderStateMixin {
  final _nameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  String? _photoUrl;
  bool _isPhotoHovered = false;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.elasticOut,
      ),
    );
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeIn,
      ),
    );
    
    _animationController.forward();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _continue() {
    if (_formKey.currentState!.validate()) {
      ref.read(authProvider.notifier).updateProfile(
            displayName: _nameController.text.trim(),
            photoUrl: _photoUrl,
          );
    }
  }

  void _pickPhoto() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Photo picker coming soon!'),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final themeMode = ref.watch(themeModeProvider);

    ref.listen(authProvider, (previous, next) {
      if (next.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.error!),
            backgroundColor: AppTheme.errorColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    });

    return Scaffold(
      body: AnimatedContainer(
        duration: AppTheme.normalAnimation,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: themeMode == ThemeMode.dark
                ? [
                    AppTheme.darkBackground,
                    AppTheme.darkSurface,
                    AppTheme.darkBackground,
                  ]
                : [
                    Colors.white,
                    AppTheme.primaryColor.withValues(alpha: 0.05),
                    AppTheme.secondaryColor.withValues(alpha: 0.1),
                  ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32.0),
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 48),
                    
                    // Title with animation
                    ScaleTransition(
                      scale: _scaleAnimation,
                      child: AnimatedDefaultTextStyle(
                        duration: AppTheme.normalAnimation,
                        style: Theme.of(context).textTheme.headlineMedium!.copyWith(
                              fontWeight: FontWeight.bold,
                              color: themeMode == ThemeMode.dark
                                  ? Colors.white
                                  : AppTheme.textPrimary,
                            ),
                        child: const Text(
                          "Create your profile",
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 12),
                    
                    AnimatedDefaultTextStyle(
                      duration: AppTheme.normalAnimation,
                      style: Theme.of(context).textTheme.bodyLarge!.copyWith(
                            color: themeMode == ThemeMode.dark
                                ? Colors.white70
                                : AppTheme.textSecondary,
                          ),
                      child: const Text(
                        'Let your family members recognize you',
                        textAlign: TextAlign.center,
                      ),
                    ),
                    
                    const SizedBox(height: 56),
                    
                    // Profile Photo with hover animation
                    Center(
                      child: MouseRegion(
                        onEnter: (_) => setState(() => _isPhotoHovered = true),
                        onExit: (_) => setState(() => _isPhotoHovered = false),
                        child: GestureDetector(
                          onTap: _pickPhoto,
                          child: AnimatedContainer(
                            duration: AppTheme.normalAnimation,
                            curve: Curves.easeInOut,
                            transform: Matrix4.identity()
                              // ignore: deprecated_member_use
                              ..scale(_isPhotoHovered ? 1.05 : 1.0),
                            child: Stack(
                              children: [
                                Hero(
                                  tag: 'profile-photo',
                                  child: Container(
                                    width: 140,
                                    height: 140,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: themeMode == ThemeMode.dark
                                          ? AppTheme.darkSurface
                                          : Colors.white,
                                      boxShadow: [
                                        BoxShadow(
                                          color: AppTheme.primaryColor.withValues(
                                            alpha: _isPhotoHovered ? 0.3 : 0.1,
                                          ),
                                          blurRadius: _isPhotoHovered ? 30 : 20,
                                          spreadRadius: _isPhotoHovered ? 8 : 5,
                                        ),
                                      ],
                                      border: Border.all(
                                        color: AppTheme.primaryColor.withValues(alpha: 0.2),
                                        width: 4,
                                      ),
                                    ),
                                    child: _photoUrl != null
                                        ? ClipOval(
                                            child: Image.network(
                                              _photoUrl!,
                                              fit: BoxFit.cover,
                                            ),
                                          )
                                        : Icon(
                                            Icons.person_add_alt_1,
                                            size: 56,
                                            color: AppTheme.primaryColor.withValues(alpha: 0.5),
                                          ),
                                  ),
                                ),
                                Positioned(
                                  bottom: 0,
                                  right: 0,
                                  child: AnimatedContainer(
                                    duration: AppTheme.fastAnimation,
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: AppTheme.primaryColor,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: themeMode == ThemeMode.dark
                                            ? AppTheme.darkBackground
                                            : Colors.white,
                                        width: 3,
                                      ),
                                    ),
                                    child: const Icon(
                                      Icons.camera_alt,
                                      size: 20,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 56),
                    
                    // Name Input with animation
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.0, end: 1.0),
                      duration: const Duration(milliseconds: 600),
                      curve: Curves.easeOut,
                      builder: (context, value, child) {
                        return Transform.translate(
                          offset: Offset(0, 20 * (1 - value)),
                          child: Opacity(
                            opacity: value,
                            child: child,
                          ),
                        );
                      },
                      child: AnimatedContainer(
                        duration: AppTheme.fastAnimation,
                        child: TextFormField(
                          controller: _nameController,
                          decoration: InputDecoration(
                            labelText: 'Full Name',
                            hintText: 'How should we call you?',
                            prefixIcon: const Icon(Icons.badge_outlined),
                            filled: true,
                            fillColor: themeMode == ThemeMode.dark
                                ? AppTheme.darkSurface
                                : Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide.none,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Please enter your name';
                            }
                            if (value.trim().length < 2) return 'Name too short';
                            return null;
                          },
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 48),
                    
                    // Continue Button with animation
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.0, end: 1.0),
                      duration: const Duration(milliseconds: 800),
                      curve: Curves.elasticOut,
                      builder: (context, value, child) {
                        return Transform.scale(
                          scale: value,
                          child: child,
                        );
                      },
                      child: AnimatedContainer(
                        duration: AppTheme.fastAnimation,
                        child: ElevatedButton(
                          onPressed: authState.isLoading ? null : _continue,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 20),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            backgroundColor: AppTheme.primaryColor,
                            foregroundColor: Colors.white,
                            elevation: 4,
                            shadowColor: AppTheme.primaryColor.withValues(alpha: 0.4),
                          ),
                          child: authState.isLoading
                              ? const SizedBox(
                                  height: 24,
                                  width: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
                                  ),
                                )
                              : const Text(
                                  'Complete My Profile',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
