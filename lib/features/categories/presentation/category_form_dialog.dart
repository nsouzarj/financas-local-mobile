import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../data/category_service.dart';
import '../models/category_model.dart';

class CategoryFormDialog extends StatefulWidget {
  final CategoryModel? category;
  final String? initialType; // 'expense' ou 'income'

  const CategoryFormDialog({super.key, this.category, this.initialType});

  @override
  State<CategoryFormDialog> createState() => _CategoryFormDialogState();
}

class _CategoryFormDialogState extends State<CategoryFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _categoryService = CategoryService();

  late String _type;
  String _selectedColor = '#38BDF8';
  bool _isLoading = false;

  final List<String> _colorOptions = [
    '#38BDF8', // Sky
    '#10B981', // Emerald
    '#F59E0B', // Amber
    '#F43F5E', // Rose
    '#8B5CF6', // Purple
    '#EC4899', // Pink
    '#06B6D4', // Cyan
    '#64748B', // Slate
  ];

  @override
  void initState() {
    super.initState();
    if (widget.category != null) {
      _nameController.text = widget.category!.name;
      _type = widget.category!.type;
      _selectedColor = widget.category!.color;
    } else {
      _type = widget.initialType ?? 'expense';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final name = _nameController.text.trim();
    bool success;

    if (widget.category == null) {
      success = await _categoryService.createCategory(
        name: name,
        type: _type,
        color: _selectedColor,
      );
    } else {
      success = await _categoryService.updateCategory(
        widget.category!.id,
        name: name,
        type: _type,
        color: _selectedColor,
      );
    }

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (success) {
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erro ao salvar categoria.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.category != null;

    return Dialog(
      backgroundColor: AppTheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                isEditing ? 'Editar Categoria' : 'Nova Categoria',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),

              // Nome da Categoria
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Nome da Categoria'),
                validator: (val) => val == null || val.trim().isEmpty ? 'Informe o nome' : null,
              ),
              const SizedBox(height: 12),

              // Tipo: Despesa ou Receita
              DropdownButtonFormField<String>(
                value: _type,
                dropdownColor: AppTheme.surface,
                decoration: const InputDecoration(labelText: 'Tipo'),
                items: const [
                  DropdownMenuItem(value: 'expense', child: Text('Despesa')),
                  DropdownMenuItem(value: 'income', child: Text('Receita')),
                  DropdownMenuItem(value: 'both', child: Text('Ambos')),
                ],
                onChanged: (val) => setState(() => _type = val ?? 'expense'),
              ),
              const SizedBox(height: 16),

              // Paleta de Cores
              Text('Cor do Ícone:', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: _colorOptions.map((hex) {
                  final colorInt = int.parse(hex.replaceFirst('#', '0xFF'));
                  final isSelected = _selectedColor == hex;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedColor = hex),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: Color(colorInt),
                        shape: BoxShape.circle,
                        border: isSelected ? Border.all(color: Colors.white, width: 2.5) : null,
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),

              // Botões
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text('Cancelar', style: TextStyle(color: AppTheme.textMuted)),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _handleSave,
                    style: ElevatedButton.styleFrom(minimumSize: const Size(100, 44)),
                    child: _isLoading
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Salvar'),
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

