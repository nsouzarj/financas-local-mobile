import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../controllers/value_visibility_controller.dart';

class CurrencyFormatter {
  static NumberFormat get _formatter {
    try {
      return NumberFormat.currency(
        locale: 'pt_BR',
        symbol: 'R\$',
        decimalDigits: 2,
      );
    } catch (_) {
      return NumberFormat.currency(
        symbol: 'R\$ ',
        decimalDigits: 2,
      );
    }
  }

  /// Formata número para Real brasileiro: R$ 1.234,56
  static String format(double value) {
    try {
      return _formatter.format(value);
    } catch (_) {
      return 'R\$ ${value.toStringAsFixed(2).replaceAll('.', ',')}';
    }
  }

  /// Formata número para Real brasileiro ou oculta com •••••• respeitando a preferência global do olho
  static String formatOrHide(double value, {String? prefix, bool? hide}) {
    final shouldHide = hide ?? ValueVisibilityController.instance.hideValues;
    if (shouldHide) {
      return prefix != null ? '$prefix••••••' : '••••••';
    }
    final formatted = format(value);
    return prefix != null ? '$prefix$formatted' : formatted;
  }

  /// Formata data para formato brasileiro dd/MM/yyyy
  static String formatDate(DateTime date) {
    try {
      return DateFormat('dd/MM/yyyy').format(date);
    } catch (_) {
      final day = date.day.toString().padLeft(2, '0');
      final month = date.month.toString().padLeft(2, '0');
      return '$day/$month/${date.year}';
    }
  }

  /// Formata para a API: yyyy-MM-dd
  static String formatDateToApi(DateTime date) {
    try {
      return DateFormat('yyyy-MM-dd').format(date);
    } catch (_) {
      final month = date.month.toString().padLeft(2, '0');
      final day = date.day.toString().padLeft(2, '0');
      return '${date.year}-$month-$day';
    }
  }

  /// Nome do mês por extenso seguro com primeira letra maiúscula (ex: "Novembro 2026")
  static String formatMonthYear(DateTime date) {
    try {
      final label = DateFormat('MMMM yyyy', 'pt_BR').format(date);
      if (label.isNotEmpty) {
        return label[0].toUpperCase() + label.substring(1);
      }
    } catch (_) {}

    const months = [
      'Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho',
      'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro'
    ];
    final mIndex = (date.month >= 1 && date.month <= 12) ? date.month - 1 : 0;
    return '${months[mIndex]} ${date.year}';
  }

  /// Converte string digitada (ex: "200,31" ou "1.200,50") de volta para double
  static double parseCurrencyToNumber(String text) {
    if (text.trim().isEmpty) return 0.0;
    // Remove tudo exceto dígitos e vírgula/ponto
    final clean = text
        .replaceAll('R\$', '')
        .replaceAll(' ', '')
        .replaceAll('.', '')
        .replaceAll(',', '.')
        .trim();
    return double.tryParse(clean) ?? 0.0;
  }
}

/// Máscara idêntica ao Frontend Web:
/// À medida que o usuário digita dígitos, divide por 100 e formata como moeda (ex: "200,31")
class CurrencyInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) {
      return const TextEditingValue(
        text: '0,00',
        selection: TextSelection.collapsed(offset: 4),
      );
    }

    // Apenas dígitos
    final cleanDigits = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (cleanDigits.isEmpty) {
      return const TextEditingValue(
        text: '0,00',
        selection: TextSelection.collapsed(offset: 4),
      );
    }

    final double value = (double.tryParse(cleanDigits) ?? 0.0) / 100.0;
    String formatted;
    try {
      formatted = NumberFormat('#,##0.00', 'pt_BR').format(value);
    } catch (_) {
      formatted = value.toStringAsFixed(2).replaceAll('.', ',');
    }

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
