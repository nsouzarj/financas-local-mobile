import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/currency_formatter.dart';

class CashFlowChartWidget extends StatefulWidget {
  final double income;
  final double expenses;
  final bool hideValues;

  const CashFlowChartWidget({
    super.key,
    required this.income,
    required this.expenses,
    required this.hideValues,
  });

  @override
  State<CashFlowChartWidget> createState() => _CashFlowChartWidgetState();
}

class _CashFlowChartWidgetState extends State<CashFlowChartWidget> with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _animProgress;
  double? _touchFraction; // null quando não estiver tocando, 0.0 a 1.0 ao tocar

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _animProgress = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    );
    _animController.forward();
  }

  @override
  void didUpdateWidget(covariant CashFlowChartWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.income != widget.income || oldWidget.expenses != widget.expenses) {
      _animController.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final net = widget.income - widget.expenses;
    final isPositive = net >= 0;
    final savingsRate = widget.income > 0 ? ((net / widget.income) * 100).clamp(-100.0, 100.0) : 0.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.border.withOpacity(0.8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Cabeçalho Protegido contra Overflow
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.show_chart_rounded, color: AppTheme.primary, size: 20),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Fluxo de Caixa',
                            style: TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'RECEITAS VS DESPESAS',
                            style: TextStyle(
                              color: AppTheme.textMuted,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.4,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isPositive
                      ? AppTheme.income.withOpacity(0.15)
                      : AppTheme.expense.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isPositive
                        ? AppTheme.income.withOpacity(0.3)
                        : AppTheme.expense.withOpacity(0.3),
                  ),
                ),
                child: Text(
                  isPositive
                      ? '+${savingsRate.toStringAsFixed(0)}% guardado'
                      : 'Déficit no mês',
                  style: TextStyle(
                    color: isPositive ? AppTheme.income : AppTheme.expense,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // 2. Legendas de Valores Formatadas com FittedBox (Zero Overflow)
          Row(
            children: [
              Expanded(
                child: _buildLegendItem(
                  label: 'Receitas',
                  color: const Color(0xFF10B981),
                  amount: widget.income,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildLegendItem(
                  label: 'Despesas',
                  color: const Color(0xFFEF4444),
                  amount: widget.expenses,
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // 3. Gráfico de Área Suave (AreaChart Recharts-style)
          GestureDetector(
            onPanStart: (details) => _updateTouch(details.localPosition),
            onPanUpdate: (details) => _updateTouch(details.localPosition),
            onPanEnd: (_) => setState(() => _touchFraction = null),
            onTapDown: (details) => _updateTouch(details.localPosition),
            onTapUp: (_) => Future.delayed(const Duration(milliseconds: 1500), () {
              if (mounted) setState(() => _touchFraction = null);
            }),
            child: SizedBox(
              height: 190,
              width: double.infinity,
              child: AnimatedBuilder(
                animation: _animProgress,
                builder: (context, _) {
                  return CustomPaint(
                    size: const Size(double.infinity, 190),
                    painter: _AreaChartPainter(
                      income: widget.income,
                      expenses: widget.expenses,
                      progress: _animProgress.value,
                      touchFraction: _touchFraction,
                      hideValues: widget.hideValues,
                    ),
                  );
                },
              ),
            ),
          ),

          const SizedBox(height: 12),

          // 4. Resumo Financeiro em Três Pilares com FittedBox
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            decoration: BoxDecoration(
              color: AppTheme.surfaceLight.withOpacity(0.35),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.border.withOpacity(0.5)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _buildFooterStat(
                    label: 'Entradas',
                    amount: widget.income,
                    color: const Color(0xFF10B981),
                  ),
                ),
                Container(width: 1, height: 28, color: AppTheme.border.withOpacity(0.5)),
                Expanded(
                  child: _buildFooterStat(
                    label: 'Saídas',
                    amount: widget.expenses,
                    color: const Color(0xFFEF4444),
                  ),
                ),
                Container(width: 1, height: 28, color: AppTheme.border.withOpacity(0.5)),
                Expanded(
                  child: _buildFooterStat(
                    label: 'Resultado',
                    amount: net,
                    color: isPositive ? const Color(0xFF38BDF8) : const Color(0xFFF59E0B),
                    showSign: true,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _updateTouch(Offset localPos) {
    const chartLeft = 48.0;
    final chartRight = MediaQuery.of(context).size.width - 64.0;
    final chartWidth = chartRight - chartLeft;
    if (chartWidth <= 0) return;

    final frac = ((localPos.dx - chartLeft) / chartWidth).clamp(0.0, 1.0);
    setState(() {
      _touchFraction = frac;
    });
  }

  Widget _buildLegendItem({
    required String label,
    required Color color,
    required double amount,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.5),
                  blurRadius: 4,
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Text(
                widget.hideValues ? '••••••' : CurrencyFormatter.format(amount),
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooterStat({
    required String label,
    required double amount,
    required Color color,
    bool showSign = false,
  }) {
    final prefix = showSign && amount > 0 ? '+' : '';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              color: AppTheme.textMuted,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 3),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              widget.hideValues ? '••••' : '$prefix${CurrencyFormatter.format(amount)}',
              style: TextStyle(
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
              maxLines: 1,
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}

class _AreaChartPainter extends CustomPainter {
  final double income;
  final double expenses;
  final double progress;
  final double? touchFraction;
  final bool hideValues;

  _AreaChartPainter({
    required this.income,
    required this.expenses,
    required this.progress,
    required this.touchFraction,
    required this.hideValues,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const leftPadding = 48.0; // Espaço suficiente para nunca cortar valores no eixo Y
    const rightPadding = 14.0;
    const topPadding = 16.0;
    const bottomPadding = 24.0;

    final chartWidth = size.width - leftPadding - rightPadding;
    final chartHeight = size.height - topPadding - bottomPadding;

    if (chartWidth <= 0 || chartHeight <= 0) return;

    // Calcular teto do gráfico para manter escala consistente com margem de 15%
    final double rawMax = math.max(income, expenses);
    final double maxY = rawMax > 0 ? rawMax * 1.15 : 1000.0;

    // 1. Linhas de Grade Horizontais (CartesianGrid) com valores no eixo Y
    final gridPaint = Paint()
      ..color = const Color(0xFF334155).withOpacity(0.4)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    const gridLines = 3;
    for (int i = 0; i <= gridLines; i++) {
      final yNorm = i / gridLines;
      final y = topPadding + (chartHeight * (1 - yNorm));

      // Linha tracejada suave
      _drawDashedLine(canvas, Offset(leftPadding, y), Offset(size.width - rightPadding, y), gridPaint);

      // Label do Eixo Y perfeitamente alinhado dentro da margem esquerda
      final yVal = maxY * yNorm;
      final labelText = _formatShortAxisValue(yVal);
      final textPainter = TextPainter(
        text: TextSpan(
          text: labelText,
          style: const TextStyle(
            color: Color(0xFF64748B),
            fontSize: 9,
            fontWeight: FontWeight.w600,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      textPainter.paint(
        canvas,
        Offset(leftPadding - textPainter.width - 6, y - textPainter.height / 2),
      );
    }

    // 2. Labels do Eixo X ("Início" e "Atual")
    _drawXLabel(canvas, 'Início', leftPadding, size.height - bottomPadding + 6, TextAlign.left);
    _drawXLabel(canvas, 'Atual', size.width - rightPadding, size.height - bottomPadding + 6, TextAlign.right);

    // 3. Traçar Curvas de Área (Income e Expenses)
    final bottomY = topPadding + chartHeight;
    final startX = leftPadding;
    final endX = leftPadding + chartWidth;

    final currentIncome = income * progress;
    final currentExpenses = expenses * progress;

    final incomeEndY = bottomY - ((currentIncome / maxY) * chartHeight);
    final expenseEndY = bottomY - ((currentExpenses / maxY) * chartHeight);

    // Renderizar Receitas (Verde #10B981)
    _drawSmoothArea(
      canvas: canvas,
      startX: startX,
      endX: endX,
      bottomY: bottomY,
      targetY: incomeEndY,
      lineColor: const Color(0xFF10B981),
      gradientStart: const Color(0xFF10B981).withOpacity(0.35),
      gradientEnd: const Color(0xFF10B981).withOpacity(0.0),
    );

    // Renderizar Despesas (Vermelho #EF4444)
    _drawSmoothArea(
      canvas: canvas,
      startX: startX,
      endX: endX,
      bottomY: bottomY,
      targetY: expenseEndY,
      lineColor: const Color(0xFFEF4444),
      gradientStart: const Color(0xFFEF4444).withOpacity(0.30),
      gradientEnd: const Color(0xFFEF4444).withOpacity(0.0),
    );

    // 4. Marcadores de Fim de Curva (Glowing Dots)
    _drawGlowDot(canvas, Offset(endX, incomeEndY), const Color(0xFF10B981));
    _drawGlowDot(canvas, Offset(endX, expenseEndY), const Color(0xFFEF4444));

    // 5. Linha Guia e Tooltip Interativo ao Tocar/Arrastar (Clamp 100% dentro do card)
    if (touchFraction != null) {
      final frac = touchFraction!.clamp(0.0, 1.0);
      final touchX = leftPadding + (chartWidth * frac);

      // Calcular valores interpolados suavemente ao longo da curva
      final tSmooth = _smoothStep(frac);
      final touchIncomeVal = income * tSmooth;
      final touchExpenseVal = expenses * tSmooth;

      final touchIncomeY = bottomY - ((touchIncomeVal / maxY) * chartHeight);
      final touchExpenseY = bottomY - ((touchExpenseVal / maxY) * chartHeight);

      // Linha vertical guia
      final guidePaint = Paint()
        ..color = Colors.white.withOpacity(0.4)
        ..strokeWidth = 1.5;
      canvas.drawLine(Offset(touchX, topPadding), Offset(touchX, bottomY), guidePaint);

      // Pontos destacados nos encontros da linha guia
      _drawTouchPoint(canvas, Offset(touchX, touchIncomeY), const Color(0xFF10B981));
      _drawTouchPoint(canvas, Offset(touchX, touchExpenseY), const Color(0xFFEF4444));

      // Tooltip Card Flutuante seguro sem transbordar
      _drawTooltipCard(
        canvas: canvas,
        chartWidth: size.width,
        touchX: touchX,
        incomeVal: touchIncomeVal,
        expenseVal: touchExpenseVal,
      );
    }
  }

  void _drawSmoothArea({
    required Canvas canvas,
    required double startX,
    required double endX,
    required double bottomY,
    required double targetY,
    required Color lineColor,
    required Color gradientStart,
    required Color gradientEnd,
  }) {
    final width = endX - startX;
    final p1 = Offset(startX + (width * 0.45), bottomY);
    final p2 = Offset(startX + (width * 0.55), targetY);
    final endPoint = Offset(endX, targetY);

    // 1. Preenchimento de Área com Gradiente
    final areaPath = Path()..moveTo(startX, bottomY);
    areaPath.cubicTo(p1.dx, p1.dy, p2.dx, p2.dy, endPoint.dx, endPoint.dy);
    areaPath.lineTo(endX, bottomY);
    areaPath.close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [gradientStart, gradientEnd],
      ).createShader(Rect.fromLTRB(startX, targetY, endX, bottomY))
      ..style = PaintingStyle.fill;

    canvas.drawPath(areaPath, fillPaint);

    // 2. Traço da Curva Principal
    final linePath = Path()..moveTo(startX, bottomY);
    linePath.cubicTo(p1.dx, p1.dy, p2.dx, p2.dy, endPoint.dx, endPoint.dy);

    final linePaint = Paint()
      ..color = lineColor
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    canvas.drawPath(linePath, linePaint);
  }

  void _drawGlowDot(Canvas canvas, Offset point, Color color) {
    // Halo externo
    final haloPaint = Paint()
      ..color = color.withOpacity(0.25)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(point, 7, haloPaint);

    // Borda branca suave
    final ringPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(point, 4, ringPaint);

    // Centro da cor
    final centerPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawCircle(point, 3, centerPaint);
  }

  void _drawTouchPoint(Canvas canvas, Offset point, Color color) {
    canvas.drawCircle(point, 5, Paint()..color = Colors.white);
    canvas.drawCircle(point, 3, Paint()..color = color);
  }

  void _drawTooltipCard({
    required Canvas canvas,
    required double chartWidth,
    required double touchX,
    required double incomeVal,
    required double expenseVal,
  }) {
    const cardWidth = 135.0;
    const cardHeight = 52.0;

    // Posicionar tooltip clampado para NUNCA sair do card
    double cardLeft = touchX + 10;
    if (cardLeft + cardWidth > chartWidth - 10) {
      cardLeft = touchX - cardWidth - 10;
    }
    cardLeft = cardLeft.clamp(10.0, math.max(10.0, chartWidth - cardWidth - 10.0));

    const cardTop = 15.0;
    final cardRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(cardLeft, cardTop, cardWidth, cardHeight),
      const Radius.circular(10),
    );

    // Sombra do card
    canvas.drawRRect(
      cardRect,
      Paint()
        ..color = Colors.black.withOpacity(0.55)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );

    // Fundo do card
    canvas.drawRRect(
      cardRect,
      Paint()..color = const Color(0xFF1E293B),
    );

    // Borda do card
    canvas.drawRRect(
      cardRect,
      Paint()
        ..color = const Color(0xFF334155)
        ..strokeWidth = 1
        ..style = PaintingStyle.stroke,
    );

    // Textos do tooltip
    final incStr = hideValues ? '••••••' : CurrencyFormatter.format(incomeVal);
    final expStr = hideValues ? '••••••' : CurrencyFormatter.format(expenseVal);

    _drawTooltipLine(canvas, Offset(cardLeft + 10, cardTop + 10), const Color(0xFF10B981), 'Receita: $incStr');
    _drawTooltipLine(canvas, Offset(cardLeft + 10, cardTop + 28), const Color(0xFFEF4444), 'Despesa: $expStr');
  }

  void _drawTooltipLine(Canvas canvas, Offset pos, Color dotColor, String text) {
    canvas.drawCircle(Offset(pos.dx + 3, pos.dy + 6), 3, Paint()..color = dotColor);
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(pos.dx + 10, pos.dy));
  }

  void _drawDashedLine(Canvas canvas, Offset p1, Offset p2, Paint paint) {
    const dashWidth = 4.0;
    const dashSpace = 4.0;
    double currentX = p1.dx;
    while (currentX < p2.dx) {
      canvas.drawLine(
        Offset(currentX, p1.dy),
        Offset(math.min(currentX + dashWidth, p2.dx), p1.dy),
        paint,
      );
      currentX += dashWidth + dashSpace;
    }
  }

  void _drawXLabel(Canvas canvas, String text, double x, double y, TextAlign align) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          color: Color(0xFF64748B),
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
        ),
      ),
      textAlign: align,
      textDirection: TextDirection.ltr,
    )..layout();

    double drawX = x;
    if (align == TextAlign.right) {
      drawX = x - tp.width;
    }
    tp.paint(canvas, Offset(drawX, y));
  }

  double _smoothStep(double t) {
    return t * t * (3 - 2 * t);
  }

  String _formatShortAxisValue(double val) {
    if (val >= 1000000) {
      return '${(val / 1000000).toStringAsFixed(1)}M';
    } else if (val >= 1000) {
      return '${(val / 1000).toStringAsFixed(0)}k';
    } else {
      return val.toInt().toString();
    }
  }

  @override
  bool shouldRepaint(covariant _AreaChartPainter oldDelegate) {
    return oldDelegate.income != income ||
        oldDelegate.expenses != expenses ||
        oldDelegate.progress != progress ||
        oldDelegate.touchFraction != touchFraction ||
        oldDelegate.hideValues != hideValues;
  }
}
