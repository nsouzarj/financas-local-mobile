import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../theme/app_theme.dart';

class ValueVisibilityController extends ChangeNotifier {
  static final ValueVisibilityController instance = ValueVisibilityController._internal();
  ValueVisibilityController._internal();

  static const String _storageKey = 'hide_financial_values';
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  bool _hideValues = false;

  bool get hideValues => _hideValues;

  Future<void> initialize() async {
    try {
      final saved = await _storage.read(key: _storageKey);
      if (saved != null) {
        _hideValues = saved == 'true';
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Erro ao carregar preferência de visibilidade: $e');
    }
  }

  Future<void> toggle() async {
    _hideValues = !_hideValues;
    notifyListeners();
    try {
      await _storage.write(key: _storageKey, value: _hideValues.toString());
    } catch (e) {
      debugPrint('Erro ao persistir preferência de visibilidade: $e');
    }
  }

  Future<void> setHideValues(bool hide) async {
    if (_hideValues == hide) return;
    _hideValues = hide;
    notifyListeners();
    try {
      await _storage.write(key: _storageKey, value: _hideValues.toString());
    } catch (e) {
      debugPrint('Erro ao persistir preferência de visibilidade: $e');
    }
  }
}

/// Botão de olho reutilizável para o AppBar em todas as telas
class EyeVisibilityButton extends StatelessWidget {
  final Color? color;
  final double size;

  const EyeVisibilityButton({
    super.key,
    this.color,
    this.size = 20,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ValueVisibilityController.instance,
      builder: (context, _) {
        final isHidden = ValueVisibilityController.instance.hideValues;
        return IconButton(
          icon: Icon(
            isHidden ? Icons.visibility_off : Icons.visibility,
            color: color ?? AppTheme.textSecondary,
            size: size,
          ),
          tooltip: isHidden ? 'Mostrar valores' : 'Ocultar valores',
          onPressed: () => ValueVisibilityController.instance.toggle(),
        );
      },
    );
  }
}

