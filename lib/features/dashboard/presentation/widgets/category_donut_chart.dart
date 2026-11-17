import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../models/dashboard_model.dart';

class CategoryDonutChartWidget extends StatefulWidget {
  final List<CategoryBreakdownItem> categories;
  final double totalExpenses;
  final bool hideValues;

  const CategoryDonutChartWidget({
    super.key,
    required this.categories,
    required this.totalExpenses,
    required this.hideValues,
  });

  @override
  State<CategoryDonutChartWidget> createState() => _CategoryDonutChartWidgetState();
}

class _CategoryDonutChartWidgetState extends State<CategoryDonutChartWidget> {
  int? _selectedIndex;

  Color _parseSafeColor(String hex) {
    String cleanHex = hex.replaceFirst('#', '').toUpperCase();
    if (cleanHex.length == 6) {
      cleanHex = 'FF$cleanHex';
    }
    int? val = int.tryParse(cleanHex, radix: 16);
    if (val == null) return const Color(0xFF38BDF8);

    Color c = Color(val);
    // Purple Ban: converter tons arroxeados para tons elegantes de ciano/azul/sky
    final hsl = HSLColor.fromColor(c);
    if (hsl.hue >= 250 && hsl.hue <= 305) {
      return const Color(0xFF0EA5E9);
    }
    return c;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.categories.isEmpty || widget.totalExpenses <= 0) {
      return Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.border.withOpacity(0.8)),
        ),
        child: Center(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 20.0),
            child: Column(
              children: [
                Icon(Icons.pie_chart_outline_rounded, size: 36, color: AppTheme.textMuted),
                SizedBox(height: 10),
                Text(
                  'Nenhum gasto registrado este mês para gerar o gráfico.',
                  style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    final total = widget.totalExpenses;
    final selectedCategory = (_selectedIndex != null && _selectedIndex! < widget.categories.length)
        ? widget.categories[_selectedIndex!]
        : null;

    // Categoria de maior despesa para destaque no topo
    final highestCategory = widget.categories.isNotEmpty ? widget.categories.first : null;
    final highestPct = (highestCategory != null && total > 0)
        ? ((highestCategory.value / total) * 100).toStringAsFixed(0)
        : '0';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.border.withOpacity(0.8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cabeçalho da seção com contadores
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.pie_chart_rounded, color: AppTheme.primary, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Gastos por Categoria',
                        style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${widget.categories.length} ${widget.categories.length == 1 ? 'CATEGORIA' : 'CATEGORIAS REGISTRADAS'}',
                        style: TextStyle(
                          color: AppTheme.textMuted,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              if (highestCategory != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceLight,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.star_rounded, color: AppTheme.primary, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        'Top: $highestPct%',
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),

          const SizedBox(height: 22),

          // Gráfico de Rosca Ampliado (220px x 220px) com Centro Interativo
          Center(
            child: SizedBox(
              width: 220,
              height: 220,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CustomPaint(
                    size: const Size(220, 220),
                    painter: _DonutChartPainter(
                      categories: widget.categories,
                      totalExpenses: total,
                      selectedIndex: _selectedIndex,
                      colorParser: _parseSafeColor,
                    ),
                  ),
                  // Conteúdo Central Ampliado (136px de diâmetro)
                  GestureDetector(
                    onTap: () {
                      setState(() => _selectedIndex = null);
                    },
                    child: Container(
                      width: 136,
                      height: 136,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppTheme.surface,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.35),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(10),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            selectedCategory != null
                                ? selectedCategory.name
                                : 'Total de Gastos',
                            style: TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.hideValues
                                ? '••••••'
                                : CurrencyFormatter.format(
                                    selectedCategory != null ? selectedCategory.value : total,
                                  ),
                            style: TextStyle(
                              color: selectedCategory != null
                                  ? _parseSafeColor(selectedCategory.color)
                                  : AppTheme.textPrimary,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              letterSpacing: -0.3,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: selectedCategory != null
                                  ? _parseSafeColor(selectedCategory.color).withOpacity(0.18)
                                  : AppTheme.surfaceLight,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              selectedCategory != null
                                  ? '${((selectedCategory.value / total) * 100).toStringAsFixed(1)}%'
                                  : '100% no mês',
                              style: TextStyle(
                                color: selectedCategory != null
                                    ? _parseSafeColor(selectedCategory.color)
                                    : AppTheme.textMuted,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Título da Lista Expandida
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Todas as Categorias',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (_selectedIndex != null)
                GestureDetector(
                  onTap: () => setState(() => _selectedIndex = null),
                  child: Text(
                    'Limpar seleção',
                    style: TextStyle(
                      color: AppTheme.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),

          // Lista Completa de Categorias (Todas Expandidas por Padrão) com Cards Ricos
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: widget.categories.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final cat = widget.categories[index];
              final isSelected = _selectedIndex == index;
              final catColor = _parseSafeColor(cat.color);
              final pct = total > 0 ? (cat.value / total) : 0.0;
              final pctLabel = '${(pct * 100).toStringAsFixed(1)}%';
              final initial = cat.name.isNotEmpty ? cat.name[0].toUpperCase() : '?';

              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedIndex = isSelected ? null : index;
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? catColor.withOpacity(0.12)
                        : AppTheme.surfaceLight.withOpacity(0.35),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isSelected
                          ? catColor.withOpacity(0.7)
                          : AppTheme.border.withOpacity(0.6),
                      width: isSelected ? 1.5 : 1,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: catColor.withOpacity(0.15),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          // Badge Circular com Inicial e Glow da Cor da Categoria
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: catColor.withOpacity(0.18),
                              shape: BoxShape.circle,
                              border: Border.all(color: catColor, width: 1.5),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              initial,
                              style: TextStyle(
                                color: catColor,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),

                          // Nome da Categoria
                          Expanded(
                            child: Text(
                              cat.name,
                              style: TextStyle(
                                color: AppTheme.textPrimary,
                                fontSize: 14,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),

                          // Badge com Porcentagem
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: catColor.withOpacity(0.16),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              pctLabel,
                              style: TextStyle(
                                color: catColor,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),

                          // Valor Total Formatado
                          Text(
                            widget.hideValues ? '••••••' : CurrencyFormatter.format(cat.value),
                            style: TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Barra de Progresso Enriquecida
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: SizedBox(
                          height: 7,
                          child: Stack(
                            children: [
                              Container(
                                color: AppTheme.surfaceLight,
                              ),
                              FractionallySizedBox(
                                widthFactor: pct.clamp(0.0, 1.0),
                                child: Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        catColor.withOpacity(0.8),
                                        catColor,
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _DonutChartPainter extends CustomPainter {
  final List<CategoryBreakdownItem> categories;
  final double totalExpenses;
  final int? selectedIndex;
  final Color Function(String) colorParser;

  _DonutChartPainter({
    required this.categories,
    required this.totalExpenses,
    required this.selectedIndex,
    required this.colorParser,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (categories.isEmpty || totalExpenses <= 0) return;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    const strokeWidth = 22.0;
    final arcRadius = radius - strokeWidth / 2;
    final rect = Rect.fromCircle(center: center, radius: arcRadius);

    double startAngle = -math.pi / 2;
    const gapAngle = 0.04; // Espaçamento elegante entre fatias

    for (int i = 0; i < categories.length; i++) {
      final item = categories[i];
      final sweepAngle = (item.value / totalExpenses) * (2 * math.pi);
      final isSelected = selectedIndex == i;

      final paint = Paint()
        ..color = colorParser(item.color)
        ..style = PaintingStyle.stroke
        ..strokeWidth = isSelected ? strokeWidth + 5.0 : strokeWidth
        ..strokeCap = StrokeCap.round;

      if (sweepAngle > gapAngle * 2) {
        canvas.drawArc(
          rect,
          startAngle + gapAngle / 2,
          sweepAngle - gapAngle,
          false,
          paint,
        );
      } else {
        canvas.drawArc(rect, startAngle, sweepAngle, false, paint);
      }

      startAngle += sweepAngle;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutChartPainter oldDelegate) {
    return oldDelegate.selectedIndex != selectedIndex ||
        oldDelegate.totalExpenses != totalExpenses ||
        oldDelegate.categories != categories;
  }
}
