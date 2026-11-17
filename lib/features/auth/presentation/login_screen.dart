import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../data/auth_service.dart';
import '../../navigation/presentation/main_nav_screen.dart';

class LoginScreen extends StatefulWidget {
  final int initialTab; // 0 = Login, 1 = Criar Workspace

  const LoginScreen({super.key, this.initialTab = 0});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  late int _selectedTab;

  // Controllers Login
  final _loginEmailController =
      TextEditingController(text: 'usuario@financas.local');
  final _loginPasswordController = TextEditingController();

  // Controllers Cadastro de Workspace
  final _registerNameController = TextEditingController();
  final _registerWorkspaceController =
      TextEditingController(text: 'Finanças Pessoais');
  final _registerEmailController = TextEditingController();
  final _registerPasswordController = TextEditingController();

  final _authService = AuthService();

  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _selectedTab = widget.initialTab;
  }

  @override
  void dispose() {
    _loginEmailController.dispose();
    _loginPasswordController.dispose();
    _registerNameController.dispose();
    _registerWorkspaceController.dispose();
    _registerEmailController.dispose();
    _registerPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin({bool enterDirect = false}) async {
    final email = enterDirect || _loginEmailController.text.trim().isEmpty
        ? 'usuario@financas.local'
        : _loginEmailController.text.trim();
    final password = enterDirect ? '' : _loginPasswordController.text;

    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final result = await _authService.login(email, password);

      if (!mounted) return;

      if (result.success) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const MainNavScreen()),
        );
      } else {
        setState(() => _errorMessage = result.errorMessage);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result.errorMessage ?? 'Erro ao entrar'),
              backgroundColor: AppTheme.expense,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Erro no login local: $e');
      if (mounted) {
        setState(() => _errorMessage = 'Erro ao processar login: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao processar login: $e'),
            backgroundColor: AppTheme.expense,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleRegisterWorkspace() async {
    final rawName = _registerNameController.text.trim();
    final rawWorkspace = _registerWorkspaceController.text.trim();
    final rawEmail = _registerEmailController.text.trim();
    final password = _registerPasswordController.text;

    final email = rawEmail.isNotEmpty ? rawEmail : 'usuario@financas.local';
    final name = rawName.isNotEmpty
        ? rawName
        : (email.contains('@') ? email.split('@').first : 'Usuário Principal');
    final workspace =
        rawWorkspace.isNotEmpty ? rawWorkspace : 'Finanças Pessoais';

    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final result = await _authService.register(
        name: name,
        email: email,
        workspaceName: workspace,
        password: password,
      );

      if (!mounted) return;

      if (result.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Conta criada com sucesso! Bem-vindo, $name.',
            ),
            backgroundColor: AppTheme.income,
          ),
        );

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const MainNavScreen()),
        );
      } else {
        setState(() => _errorMessage = result.errorMessage);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result.errorMessage ?? 'Não foi possível cadastrar'),
              backgroundColor: AppTheme.expense,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Erro ao registrar workspace local: $e');
      if (mounted) {
        setState(() => _errorMessage = 'Erro ao criar conta: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao criar conta: $e'),
            backgroundColor: AppTheme.expense,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showOfflineInfoDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: Row(
          children: [
            Icon(Icons.offline_bolt_rounded,
                color: AppTheme.income, size: 24),
            const SizedBox(width: 8),
            Text('Modo 100% Offline',
                style: TextStyle(
                    color: AppTheme.textPrimary, fontSize: 16)),
          ],
        ),
        content: Text(
          'Este aplicativo opera com banco de dados local SQLite no aparelho.\n\nTodos os seus lançamentos, categorias, workspaces e alarmes funcionam sem internet, com velocidade instantânea e privacidade total.',
          style: TextStyle(
              color: AppTheme.textSecondary, fontSize: 13, height: 1.4),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Entendi'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_selectedTab == 0 ? 'Entrar' : 'Novo Workspace'),
        actions: [
          IconButton(
            icon: Icon(Icons.info_outline_rounded,
                color: AppTheme.textSecondary),
            onPressed: _showOfflineInfoDialog,
            tooltip: 'Sobre o Modo Offline',
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding:
              const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Logo e Título
              Center(
                child: Container(
                  width: 68,
                  height: 68,
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withOpacity(0.12),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppTheme.primary.withOpacity(0.3),
                      width: 1.5,
                    ),
                  ),
                  child: Icon(
                    Icons.account_balance_wallet_rounded,
                    size: 34,
                    color: AppTheme.primary,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Finanças Local',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppTheme.income.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.cloud_off_rounded,
                            size: 13, color: AppTheme.income),
                        const SizedBox(width: 5),
                        Text(
                          '100% Offline • SQLite',
                          style: TextStyle(
                            color: AppTheme.income,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Seletor de Abas: [ Entrar ] | [ Criar Workspace ]
              Container(
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppTheme.border.withOpacity(0.6),
                    width: 1,
                  ),
                ),
                padding: const EdgeInsets.all(4),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildTabButton('Entrar', 0, Icons.login_rounded),
                    ),
                    Expanded(
                      child: _buildTabButton(
                          'Criar Workspace', 1, Icons.business_center_outlined),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Mensagem de Erro
              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.expense.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: AppTheme.expense.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline,
                          color: AppTheme.expense, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _errorMessage!,
                              style: TextStyle(
                                  color: AppTheme.expense, fontSize: 13),
                            ),
                            if (_errorMessage!.contains('Senha')) ...[
                              const SizedBox(height: 6),
                              InkWell(
                                onTap: () => _handleLogin(enterDirect: true),
                                child: Text(
                                  'Toque aqui para Entrar Direto sem senha',
                                  style: TextStyle(
                                    color: AppTheme.primary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Formulário selecionado
              if (_selectedTab == 0)
                _buildLoginForm()
              else
                _buildRegisterWorkspaceForm(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabButton(String label, int index, IconData icon) {
    final isSelected = _selectedTab == index;
    return InkWell(
      onTap: () => setState(() {
        _selectedTab = index;
        _errorMessage = null;
      }),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? Colors.white : AppTheme.textSecondary,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : AppTheme.textSecondary,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoginForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Campo de E-mail / Identificador
        TextField(
          controller: _loginEmailController,
          keyboardType: TextInputType.emailAddress,
          decoration: InputDecoration(
            labelText: 'Identificador / E-mail',
            prefixIcon:
                Icon(Icons.person_outline, color: AppTheme.textMuted),
            hintText: 'usuario@financas.local',
          ),
        ),
        const SizedBox(height: 14),

        // Campo de Senha (Opcional)
        TextField(
          controller: _loginPasswordController,
          obscureText: _obscurePassword,
          decoration: InputDecoration(
            labelText: 'Senha Local (Opcional)',
            prefixIcon: Icon(Icons.lock_outline, color: AppTheme.textMuted),
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassword
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                color: AppTheme.textMuted,
              ),
              onPressed: () =>
                  setState(() => _obscurePassword = !_obscurePassword),
            ),
          ),
        ),
        const SizedBox(height: 22),

        // Botão Entrar
        ElevatedButton(
          onPressed: _isLoading ? null : () => _handleLogin(),
          child: _isLoading
              ? const SizedBox(
                  height: 22,
                  width: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Colors.white,
                  ),
                )
              : const Text('Entrar no Aplicativo'),
        ),
        const SizedBox(height: 12),

        // Atalho Direto
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: AppTheme.textPrimary,
            side: BorderSide(color: AppTheme.border),
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          onPressed:
              _isLoading ? null : () => _handleLogin(enterDirect: true),
          icon: Icon(Icons.flash_on_rounded,
              color: AppTheme.primary, size: 18),
          label: const Text('Entrar Direto (Acesso Rápido)'),
        ),

        const SizedBox(height: 20),
        Center(
          child: TextButton(
            onPressed: () => setState(() {
              _selectedTab = 1;
              _errorMessage = null;
            }),
            child: Text(
              'Novo por aqui? Criar meu Workspace',
              style: TextStyle(
                color: AppTheme.primary,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRegisterWorkspaceForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Nome Completo
        TextField(
          controller: _registerNameController,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            labelText: 'Seu Nome Completo',
            prefixIcon:
                Icon(Icons.badge_outlined, color: AppTheme.textMuted),
            hintText: 'Ex: Nilson Souza',
          ),
        ),
        const SizedBox(height: 14),

        // Nome do Workspace
        TextField(
          controller: _registerWorkspaceController,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            labelText: 'Nome do Workspace / Organização',
            prefixIcon: Icon(Icons.business_center_outlined,
                color: AppTheme.textMuted),
            hintText: 'Ex: Finanças da Família, Pessoal ou Empresa',
          ),
        ),
        const SizedBox(height: 14),

        // E-mail
        TextField(
          controller: _registerEmailController,
          keyboardType: TextInputType.emailAddress,
          decoration: InputDecoration(
            labelText: 'E-mail para Acesso',
            prefixIcon:
                Icon(Icons.mail_outline, color: AppTheme.textMuted),
            hintText: 'seu@email.com',
          ),
        ),
        const SizedBox(height: 14),

        // Senha Local
        TextField(
          controller: _registerPasswordController,
          obscureText: _obscurePassword,
          decoration: InputDecoration(
            labelText: 'Senha Local (Opcional)',
            prefixIcon: Icon(Icons.lock_outline, color: AppTheme.textMuted),
            helperText:
                'Você também poderá usar a biometria/digital do aparelho.',
            helperStyle:
                TextStyle(color: AppTheme.textMuted, fontSize: 11),
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassword
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                color: AppTheme.textMuted,
              ),
              onPressed: () =>
                  setState(() => _obscurePassword = !_obscurePassword),
            ),
          ),
        ),
        const SizedBox(height: 22),

        if (_errorMessage != null) ...[
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 14),
            decoration: BoxDecoration(
              color: AppTheme.expense.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.expense.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.error_outline, color: AppTheme.expense, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _errorMessage!,
                    style: TextStyle(color: AppTheme.expense, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        ],

        // Botão Criar Workspace / Cadastro
        ElevatedButton.icon(
          onPressed: _isLoading ? null : _handleRegisterWorkspace,
          icon: const Icon(Icons.rocket_launch_rounded, size: 18),
          label: _isLoading
              ? const SizedBox(
                  height: 22,
                  width: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Colors.white,
                  ),
                )
              : const Text('Cadastrar e Entrar no App'),
        ),

        const SizedBox(height: 16),
        Center(
          child: TextButton(
            onPressed: () => setState(() {
              _selectedTab = 0;
              _errorMessage = null;
            }),
            child: Text(
              'Já possui cadastro? Fazer Login',
              style: TextStyle(
                color: AppTheme.primary,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
