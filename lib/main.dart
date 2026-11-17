import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'core/controllers/value_visibility_controller.dart';
import 'core/database/local_database_helper.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/skin_controller.dart';
import 'features/splash/presentation/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializa o banco de dados SQLite local
  await LocalDatabaseHelper.instance.database;

  // Inicializa a skin (tema de cores) persistida pelo usuário
  await SkinController.instance.initialize();

  // Inicializa o estado de privacidade global do olho (esconder/mostrar valores)
  await ValueVisibilityController.instance.initialize();

  // Inicializa dados de formatação de datas em Português (pt_BR)
  try {
    await initializeDateFormatting('pt_BR', null);
  } catch (e) {
    debugPrint('Erro ao inicializar formatação de datas: $e');
  }

  // Previne tela branca de erro no Flutter com um Card escuro informativo
  ErrorWidget.builder = (FlutterErrorDetails details) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.warning_amber_rounded, color: AppTheme.expense, size: 48),
              const SizedBox(height: 16),
              Text(
                'Ops, ocorreu um erro de exibição',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                details.exceptionAsString(),
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                textAlign: TextAlign.center,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  };

  runApp(const FinancasApp());
}

class FinancasApp extends StatelessWidget {
  const FinancasApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: SkinController.instance,
      builder: (context, _) {
        return MaterialApp(
          title: 'Finanças Local',
          debugShowCheckedModeBanner: false,
          theme: SkinController.instance.themeData,
          home: const SplashScreen(),
        );
      },
    );
  }
}
