import 'package:flutter/material.dart';
import '../../../core/services/biometric_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../navigation/presentation/main_nav_screen.dart';
import 'login_screen.dart';

class BiometricLockScreen extends StatefulWidget {
  final VoidCallback? onAuthenticated;
  final VoidCallback? onFallbackToPassword;

  const BiometricLockScreen({
    super.key,
    this.onAuthenticated,
    this.onFallbackToPassword,
  });

  @override
  State<BiometricLockScreen> createState() => _BiometricLockScreenState();
}

class _BiometricLockScreenState extends State<BiometricLockScreen> {
  final BiometricService _biometricService = BiometricService();
  bool _isAuthenticating = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // Inicia o leitor biométrico assim que a tela estiver montada no ciclo do Flutter
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 350), () {
        if (mounted) {
          _startBiometricAuth();
        }
      });
    });
  }

  @override
  void dispose() {
    _biometricService.stopAuthentication();
    super.dispose();
  }

  void _navigateToHome() {
    if (!mounted) return;
    if (widget.onAuthenticated != null) {
      try {
        widget.onAuthenticated!();
        return;
      } catch (e) {
        debugPrint('Aviso ao executar onAuthenticated: $e');
      }
    }
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const MainNavScreen()),
    );
  }

  void _navigateToLogin() {
    if (!mounted) return;
    if (widget.onFallbackToPassword != null) {
      try {
        widget.onFallbackToPassword!();
        return;
      } catch (e) {
        debugPrint('Aviso ao executar onFallbackToPassword: $e');
      }
    }
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  Future<void> _startBiometricAuth() async {
    if (_isAuthenticating) return;

    bool success = false;
    try {
      setState(() {
        _isAuthenticating = true;
        _errorMessage = null;
      });

      success = await _biometricService.authenticate(
        customMessage: 'Use sua impressão digital para desbloquear o Finanças App',
      );
    } catch (e) {
      debugPrint('Aviso no sensor biométrico: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isAuthenticating = false;
        });
      }
    }

    if (!mounted) return;

    if (success) {
      _navigateToHome();
    } else {
      setState(() {
        _errorMessage =
            'Biometria não reconhecida ou cancelada. Toque na digital para tentar novamente ou use o botão abaixo.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Cabeçalho da Marca
              Column(
                children: [
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: Icon(
                      Icons.account_balance_wallet_rounded,
                      size: 40,
                      color: AppTheme.primary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Finanças Premium',
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Acesso Seguro Rápido',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),

              // Área Central: Sensor de Impressão Digital
              Column(
                children: [
                  GestureDetector(
                    onTap: _isAuthenticating ? null : _startBiometricAuth,
                    child: Container(
                      width: 110,
                      height: 110,
                      decoration: BoxDecoration(
                        color: AppTheme.surface,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _isAuthenticating ? AppTheme.primary : AppTheme.border,
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primary.withOpacity(_isAuthenticating ? 0.35 : 0.1),
                            blurRadius: 30,
                            spreadRadius: 6,
                          ),
                        ],
                      ),
                      child: Center(
                        child: _isAuthenticating
                            ? CircularProgressIndicator(color: AppTheme.primary)
                            : Icon(
                                Icons.fingerprint,
                                size: 64,
                                color: AppTheme.primary,
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Toque no sensor',
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _errorMessage ?? 'Use sua impressão digital para autenticar',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _errorMessage != null ? AppTheme.expense : AppTheme.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),

              // Rodapé: Opções de Acesso e Alternativas
              Column(
                children: [
                  ElevatedButton.icon(
                    onPressed: () async {
                      await _biometricService.stopAuthentication();
                      _navigateToHome();
                    },
                    icon: const Icon(Icons.flash_on_rounded, size: 20),
                    label: const Text(
                      'Pular Biometria e Entrar Direto',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(50),
                      backgroundColor: AppTheme.primary,
                      foregroundColor: const Color(0xFF0F172A),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: () async {
                      await _biometricService.stopAuthentication();
                      _navigateToLogin();
                    },
                    icon: Icon(Icons.lock_outline, size: 18, color: AppTheme.textSecondary),
                    label: Text(
                      'Entrar com e-mail e senha',
                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: AppTheme.border),
                      minimumSize: const Size.fromHeight(46),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextButton.icon(
                    onPressed: () async {
                      await _biometricService.stopAuthentication();
                      await _biometricService.setBiometricsEnabled(false);
                      _navigateToHome();
                    },
                    icon: Icon(Icons.lock_open_rounded, size: 16, color: AppTheme.textMuted),
                    label: Text(
                      'Desativar biometria nos próximos acessos',
                      style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

