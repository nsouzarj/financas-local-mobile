import 'package:flutter/foundation.dart';

/// Notificador global para sincronizar automaticamente todas as abas e telas
/// (Dashboard, Extrato, Relatórios, Planejamento e Contas) sempre que um
/// lançamento, conta, categoria ou baixa for salvo, editado ou excluído.
class DataRefreshController extends ChangeNotifier {
  DataRefreshController._();
  static final DataRefreshController instance = DataRefreshController._();

  int _version = 0;
  int get version => _version;

  void notify() {
    _version++;
    notifyListeners();
  }
}
