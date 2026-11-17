import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/database/local_database_helper.dart';
import '../../../core/services/biometric_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/skin_controller.dart';
import '../../auth/presentation/biometric_lock_screen.dart';
import '../../auth/presentation/login_screen.dart';
import '../../navigation/presentation/main_nav_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  String _statusMessage = 'Inicializando banco de dados local...';

  @override
  void initState() {
    super.initState();

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeIn,
    );

    _scaleAnimation = Tween<double>(begin: 0.82, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: Curves.easeOutBack,
      ),
    );

    _animController.forward();
    _startAppInitialization();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _startAppInitialization() async {
    final stopwatch = Stopwatch()..start();

    // 1. Garante inicialização e integridade do banco SQLite local
    try {
      await LocalDatabaseHelper.instance.database;
      if (mounted) {
        setState(() => _statusMessage = 'Verificando segurança e sessão...');
      }
    } catch (e) {
      debugPrint('Aviso ao inicializar DB no splash: $e');
    }

    // 2. Consulta credenciais biométricas e sessão salva
    final biometricService = BiometricService();
    final token = await biometricService.getSavedToken();
    final biometricsEnabled =
        await biometricService.isBiometricEnabledByUser();

    if (mounted) {
      setState(() => _statusMessage = 'Pronto!');
    }

    // Garante tempo mínimo agradável de exibição da animação (~1.6s)
    final elapsed = stopwatch.elapsedMilliseconds;
    if (elapsed < 1600) {
      await Future.delayed(Duration(milliseconds: 1600 - elapsed));
    }

    if (!mounted) return;

    // 3. Determina tela de destino com transição suave
    Widget destination;
    final hasToken = token != null && token.isNotEmpty;

    if (hasToken && biometricsEnabled) {
      destination = const BiometricLockScreen();
    } else if (hasToken) {
      destination = const MainNavScreen();
    } else {
      destination = const LoginScreen();
    }

    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => destination,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 450),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: SkinController.instance,
      builder: (context, _) {
        final currentSkin = SkinController.instance.currentSkin;
        final primaryColor = currentSkin.primary;

        return Scaffold(
          backgroundColor: AppTheme.background,
          body: Stack(
            children: [
              // Gradiente sutil de fundo
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: const Alignment(0, -0.2),
                      radius: 1.1,
                      colors: [
                        primaryColor.withOpacity(0.12),
                        AppTheme.background,
                      ],
                    ),
                  ),
                ),
              ),

              // Conteúdo central animado
              Center(
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: ScaleTransition(
                    scale: _scaleAnimation,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Emblema / Ícone do App
                          Container(
                            width: 96,
                            height: 96,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: [
                                  primaryColor,
                                  primaryColor.withOpacity(0.75),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: primaryColor.withOpacity(0.35),
                                  blurRadius: 28,
                                  spreadRadius: 2,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: const Center(
                              child: Icon(
                                Icons.account_balance_wallet_rounded,
                                size: 48,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(height: 28),

                          // Título Principal
                          Text(
                            'Finanças Local',
                            style: TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 8),

                          // Tag / Subtítulo
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: primaryColor.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: primaryColor.withOpacity(0.3),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.offline_bolt_rounded,
                                  size: 14,
                                  color: primaryColor,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  '100% OFFLINE & PRIVADO',
                                  style: TextStyle(
                                    color: primaryColor,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 48),

                          // Indicador de progresso elegante
                          SizedBox(
                            width: 140,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: LinearProgressIndicator(
                                backgroundColor: AppTheme.surfaceLight,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  primaryColor,
                                ),
                                minHeight: 4,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Status text
                          Text(
                            _statusMessage,
                            style: TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 12,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // Rodapé de segurança e versão
              Positioned(
                bottom: 24,
                left: 0,
                right: 0,
                child: Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.shield_outlined,
                        size: 14,
                        color: AppTheme.textMuted,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Banco SQLite Seguro • Versão Local',
                        style: TextStyle(
                          color: AppTheme.textMuted,
                          fontSize: 11,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

