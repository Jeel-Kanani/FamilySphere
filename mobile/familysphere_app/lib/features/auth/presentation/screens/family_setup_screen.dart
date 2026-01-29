import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:familysphere_app/core/theme/app_theme.dart';
import 'package:familysphere_app/features/family/presentation/providers/family_provider.dart';

class FamilySetupScreen extends ConsumerStatefulWidget {
  const FamilySetupScreen({super.key});

  @override
  ConsumerState<FamilySetupScreen> createState() => _FamilySetupScreenState();
}

class _FamilySetupScreenState extends ConsumerState<FamilySetupScreen>
    with TickerProviderStateMixin {
  final _joinCodeController = TextEditingController();
  final _createNameController = TextEditingController();
  late AnimationController _cardAnimationController;
  late Animation<double> _cardSlideAnimation;
  bool _isCreateCardHovered = false;
  bool _isJoinCardHovered = false;

  @override
  void initState() {
    super.initState();
    
    _cardAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    
    _cardSlideAnimation = CurvedAnimation(
      parent: _cardAnimationController,
      curve: Curves.easeOutCubic,
    );
    
    _cardAnimationController.forward();
  }

  @override
  void dispose() {
    _joinCodeController.dispose();
    _createNameController.dispose();
    _cardAnimationController.dispose();
    super.dispose();
  }

  void _handleCreateFamily() async {
    final name = _createNameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please enter a family name'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }

    Navigator.pop(context);

    try {
      await ref.read(familyProvider.notifier).create(name);
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/home');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create family: $e'),
            backgroundColor: AppTheme.errorColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  void _handleJoinFamily() async {
    final code = _joinCodeController.text.trim().toUpperCase();
    if (code.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please enter a valid 6-character code'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }

    Navigator.pop(context);

    try {
      await ref.read(familyProvider.notifier).join(code);
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/home');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to join family: $e'),
            backgroundColor: AppTheme.errorColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  void _showCreateFamilyDialog(BuildContext context) {
    _createNameController.clear();
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Create Family',
      transitionDuration: AppTheme.normalAnimation,
      pageBuilder: (context, animation, secondaryAnimation) {
        return ScaleTransition(
          scale: CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutBack,
          ),
          child: AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: const Text('Create New Family'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Give your family group a name to get started.',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _createNameController,
                  decoration: const InputDecoration(
                    labelText: 'Family Name',
                    hintText: 'e.g. The Smiths',
                    border: OutlineInputBorder(),
                  ),
                  textCapitalization: TextCapitalization.words,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: _handleCreateFamily,
                child: const Text('Create'),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showJoinFamilyDialog(BuildContext context) {
    _joinCodeController.clear();
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Join Family',
      transitionDuration: AppTheme.normalAnimation,
      pageBuilder: (context, animation, secondaryAnimation) {
        return ScaleTransition(
          scale: CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutBack,
          ),
          child: AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: const Text('Join Family'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Enter the 6-character invite code shared by your family admin.',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _joinCodeController,
                  decoration: const InputDecoration(
                    labelText: 'Family Code',
                    hintText: 'e.g. ABC123',
                    border: OutlineInputBorder(),
                    counterText: '',
                  ),
                  maxLength: 6,
                  textCapitalization: TextCapitalization.characters,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: _handleJoinFamily,
                child: const Text('Join'),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final familyState = ref.watch(familyProvider);
    final themeMode = ref.watch(themeModeProvider);

    ref.listen(familyProvider, (previous, next) {
      if (next.error != null && !next.isLoading) {
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
      body: SafeArea(
        child: familyState.isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 40),
                    
                    // Title with animation
                    FadeTransition(
                      opacity: _cardSlideAnimation,
                      child: AnimatedDefaultTextStyle(
                        duration: AppTheme.normalAnimation,
                        style: Theme.of(context).textTheme.headlineMedium!.copyWith(
                              fontWeight: FontWeight.bold,
                              color: themeMode == ThemeMode.dark
                                  ? Colors.white
                                  : AppTheme.textPrimary,
                            ),
                        child: const Text(
                          'Create or Join a Family',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 8),
                    
                    FadeTransition(
                      opacity: _cardSlideAnimation,
                      child: AnimatedDefaultTextStyle(
                        duration: AppTheme.normalAnimation,
                        style: Theme.of(context).textTheme.bodyLarge!.copyWith(
                              color: themeMode == ThemeMode.dark
                                  ? Colors.white70
                                  : AppTheme.textSecondary,
                            ),
                        child: const Text(
                          'Connect with your loved ones',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 48),
                    
                    // Create Family Card with animation
                    SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(-0.5, 0),
                        end: Offset.zero,
                      ).animate(_cardSlideAnimation),
                      child: FadeTransition(
                        opacity: _cardSlideAnimation,
                        child: MouseRegion(
                          onEnter: (_) => setState(() => _isCreateCardHovered = true),
                          onExit: (_) => setState(() => _isCreateCardHovered = false),
                          child: AnimatedContainer(
                            duration: AppTheme.normalAnimation,
                            transform: Matrix4.identity()
                              ..scale(_isCreateCardHovered ? 1.02 : 1.0)
                              ..rotateZ(_isCreateCardHovered ? -0.01 : 0),
                            child: Card(
                              elevation: _isCreateCardHovered ? 12 : 8,
                              shadowColor: AppTheme.primaryColor.withOpacity(
                                _isCreateCardHovered ? 0.3 : 0.2,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(24),
                              ),
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(24),
                                  gradient: LinearGradient(
                                    colors: themeMode == ThemeMode.dark
                                        ? [
                                            AppTheme.darkSurface,
                                            AppTheme.primaryColor.withOpacity(0.1),
                                          ]
                                        : [
                                            Colors.white,
                                            AppTheme.primaryColor.withOpacity(0.05),
                                          ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                ),
                                child: InkWell(
                                  onTap: () => _showCreateFamilyDialog(context),
                                  borderRadius: BorderRadius.circular(24),
                                  child: Padding(
                                    padding: const EdgeInsets.all(32.0),
                                    child: Column(
                                      children: [
                                        TweenAnimationBuilder<double>(
                                          tween: Tween(begin: 0.0, end: 1.0),
                                          duration: const Duration(milliseconds: 600),
                                          builder: (context, value, child) {
                                            return Transform.scale(
                                              scale: 0.5 + (value * 0.5),
                                              child: Opacity(opacity: value, child: child),
                                            );
                                          },
                                          child: Container(
                                            padding: const EdgeInsets.all(16),
                                            decoration: BoxDecoration(
                                              color: AppTheme.primaryColor.withOpacity(0.1),
                                              shape: BoxShape.circle,
                                            ),
                                            child: Icon(
                                              Icons.add_circle_outline,
                                              size: 48,
                                              color: AppTheme.primaryColor,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 20),
                                        Text(
                                          'Create New Family',
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleLarge
                                              ?.copyWith(
                                                fontWeight: FontWeight.bold,
                                              ),
                                        ),
                                        const SizedBox(height: 12),
                                        AnimatedDefaultTextStyle(
                                          duration: AppTheme.normalAnimation,
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodyMedium!
                                              .copyWith(
                                                color: themeMode == ThemeMode.dark
                                                    ? Colors.white70
                                                    : AppTheme.textSecondary,
                                              ),
                                          child: const Text(
                                            'Start your family hub and invite members',
                                            textAlign: TextAlign.center,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Join Family Card with animation
                    SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0.5, 0),
                        end: Offset.zero,
                      ).animate(_cardSlideAnimation),
                      child: FadeTransition(
                        opacity: _cardSlideAnimation,
                        child: MouseRegion(
                          onEnter: (_) => setState(() => _isJoinCardHovered = true),
                          onExit: (_) => setState(() => _isJoinCardHovered = false),
                          child: AnimatedContainer(
                            duration: AppTheme.normalAnimation,
                            transform: Matrix4.identity()
                              ..scale(_isJoinCardHovered ? 1.02 : 1.0)
                              ..rotateZ(_isJoinCardHovered ? 0.01 : 0),
                            child: Card(
                              elevation: _isJoinCardHovered ? 12 : 8,
                              shadowColor: AppTheme.secondaryColor.withOpacity(
                                _isJoinCardHovered ? 0.3 : 0.2,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(24),
                              ),
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(24),
                                  gradient: LinearGradient(
                                    colors: themeMode == ThemeMode.dark
                                        ? [
                                            AppTheme.darkSurface,
                                            AppTheme.secondaryColor.withOpacity(0.1),
                                          ]
                                        : [
                                            Colors.white,
                                            AppTheme.secondaryColor.withOpacity(0.05),
                                          ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                ),
                                child: InkWell(
                                  onTap: () => _showJoinFamilyDialog(context),
                                  borderRadius: BorderRadius.circular(24),
                                  child: Padding(
                                    padding: const EdgeInsets.all(32.0),
                                    child: Column(
                                      children: [
                                        TweenAnimationBuilder<double>(
                                          tween: Tween(begin: 0.0, end: 1.0),
                                          duration: const Duration(milliseconds: 800),
                                          builder: (context, value, child) {
                                            return Transform.scale(
                                              scale: 0.5 + (value * 0.5),
                                              child: Opacity(opacity: value, child: child),
                                            );
                                          },
                                          child: Container(
                                            padding: const EdgeInsets.all(16),
                                            decoration: BoxDecoration(
                                              color: AppTheme.secondaryColor.withOpacity(0.1),
                                              shape: BoxShape.circle,
                                            ),
                                            child: Icon(
                                              Icons.group_add,
                                              size: 48,
                                              color: AppTheme.secondaryColor,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 20),
                                        Text(
                                          'Join Existing Family',
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleLarge
                                              ?.copyWith(
                                                fontWeight: FontWeight.bold,
                                              ),
                                        ),
                                        const SizedBox(height: 12),
                                        AnimatedDefaultTextStyle(
                                          duration: AppTheme.normalAnimation,
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodyMedium!
                                              .copyWith(
                                                color: themeMode == ThemeMode.dark
                                                    ? Colors.white70
                                                    : AppTheme.textSecondary,
                                              ),
                                          child: const Text(
                                            'Enter a family code to join',
                                            textAlign: TextAlign.center,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 48),
                    
                    // Skip button with fade
                    FadeTransition(
                      opacity: _cardSlideAnimation,
                      child: TextButton(
                        onPressed: () {
                          Navigator.pushReplacementNamed(context, '/home');
                        },
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: AnimatedDefaultTextStyle(
                          duration: AppTheme.normalAnimation,
                          style: TextStyle(
                            color: themeMode == ThemeMode.dark
                                ? Colors.white70
                                : AppTheme.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                          child: const Text('Skip for now'),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
      ),
    );
  }
}
