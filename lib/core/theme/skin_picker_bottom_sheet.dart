import 'package:flutter/material.dart';
import 'app_skin.dart';
import 'app_theme.dart';
import 'skin_controller.dart';

class SkinPickerBottomSheet extends StatefulWidget {
  const SkinPickerBottomSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const SkinPickerBottomSheet(),
    );
  }

  @override
  State<SkinPickerBottomSheet> createState() => _SkinPickerBottomSheetState();
}

class _SkinPickerBottomSheetState extends State<SkinPickerBottomSheet> {
  // 0: Modo Escuro, 1: Modo Claro
  late int _selectedTab;

  @override
  void initState() {
    super.initState();
    _selectedTab = SkinController.instance.currentSkin.isDark ? 0 : 1;
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: SkinController.instance,
      builder: (context, _) {
        final currentSkin = SkinController.instance.currentSkin;
        final displayedSkins = _selectedTab == 0 ? AppSkin.darkSkins : AppSkin.lightSkins;

        return SafeArea(
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.85,
            ),
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Barra de puxar (Drag Handle)
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: AppTheme.border.withOpacity(0.8),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),

                // Cabeçalho
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(Icons.palette_rounded, color: AppTheme.primary, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Temas & Skins',
                              style: TextStyle(
                                color: AppTheme.textPrimary,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Escolha o estilo visual do seu app',
                              style: TextStyle(
                                color: AppTheme.textMuted,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    IconButton(
                      icon: Icon(Icons.close, color: AppTheme.textSecondary, size: 20),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Seletor Segmentado (Modo Escuro / Modo Claro)
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: AppTheme.background,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: Row(
                    children: [
                      // Aba Modo Escuro
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedTab = 0;
                            });
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: _selectedTab == 0
                                  ? AppTheme.surface
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: _selectedTab == 0
                                  ? [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.08),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.dark_mode_rounded,
                                  size: 16,
                                  color: _selectedTab == 0
                                      ? AppTheme.primary
                                      : AppTheme.textMuted,
                                ),
                                const SizedBox(width: 8),
                                 Text(
                                  'Modo Escuro (${AppSkin.darkSkins.length})',
                                  style: TextStyle(
                                    color: _selectedTab == 0
                                        ? AppTheme.textPrimary
                                        : AppTheme.textMuted,
                                    fontSize: 13,
                                    fontWeight: _selectedTab == 0
                                        ? FontWeight.bold
                                        : FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      // Aba Modo Claro
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedTab = 1;
                            });
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: _selectedTab == 1
                                  ? AppTheme.surface
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: _selectedTab == 1
                                  ? [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.08),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.light_mode_rounded,
                                  size: 16,
                                  color: _selectedTab == 1
                                      ? AppTheme.primary
                                      : AppTheme.textMuted,
                                ),
                                const SizedBox(width: 8),
                                 Text(
                                  'Modo Claro (${AppSkin.lightSkins.length})',
                                  style: TextStyle(
                                    color: _selectedTab == 1
                                        ? AppTheme.textPrimary
                                        : AppTheme.textMuted,
                                    fontSize: 13,
                                    fontWeight: _selectedTab == 1
                                        ? FontWeight.bold
                                        : FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Lista de Skins disponíveis
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    physics: const BouncingScrollPhysics(),
                    itemCount: displayedSkins.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final skin = displayedSkins[index];
                      final isSelected = currentSkin.id == skin.id;

                      return GestureDetector(
                        onTap: () {
                          SkinController.instance.setSkin(skin);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: skin.surface,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isSelected ? skin.primary : skin.border,
                              width: isSelected ? 2 : 1,
                            ),
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: skin.primary.withOpacity(0.2),
                                      blurRadius: 10,
                                      offset: const Offset(0, 2),
                                    ),
                                  ]
                                : null,
                          ),
                          child: Row(
                            children: [
                              // Ícone de seleção / Checkmark
                              Container(
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  color: isSelected ? skin.primary : Colors.transparent,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: isSelected ? skin.primary : skin.textMuted,
                                    width: 1.5,
                                  ),
                                ),
                                child: isSelected
                                    ? Icon(
                                        Icons.check,
                                        size: 16,
                                        color: skin.isDark ? const Color(0xFF0F172A) : Colors.white,
                                      )
                                    : null,
                              ),
                              const SizedBox(width: 14),

                              // Informações da Skin
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          skin.name,
                                          style: TextStyle(
                                            color: skin.textPrimary,
                                            fontSize: 15,
                                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                          ),
                                        ),
                                        if (isSelected) ...[
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: skin.primary.withOpacity(0.18),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              'ATIVO',
                                              style: TextStyle(
                                                color: skin.primary,
                                                fontSize: 9,
                                                fontWeight: FontWeight.bold,
                                                letterSpacing: 0.5,
                                              ),
                                            ),
                                          ),
                                        ] else if (skin.badge != null) ...[
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: skin.primary.withOpacity(0.12),
                                              borderRadius: BorderRadius.circular(6),
                                              border: Border.all(color: skin.primary.withOpacity(0.3), width: 0.8),
                                            ),
                                            child: Text(
                                              skin.badge!.toUpperCase(),
                                              style: TextStyle(
                                                color: skin.primary,
                                                fontSize: 9,
                                                fontWeight: FontWeight.bold,
                                                letterSpacing: 0.5,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      skin.description,
                                      style: TextStyle(
                                        color: skin.textMuted,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(width: 10),

                              // Mostruário de Paleta (4 Swatches)
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _buildColorSwatch(skin.background, skin.isDark),
                                  const SizedBox(width: 4),
                                  _buildColorSwatch(skin.surface, skin.isDark),
                                  const SizedBox(width: 4),
                                  _buildColorSwatch(skin.primary, skin.isDark),
                                  const SizedBox(width: 4),
                                  _buildColorSwatch(skin.income, skin.isDark),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildColorSwatch(Color color, bool isDarkSkin) {
    return Container(
      width: 16,
      height: 16,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(
          color: isDarkSkin
              ? Colors.white.withOpacity(0.25)
              : Colors.black.withOpacity(0.15),
          width: 1,
        ),
      ),
    );
  }
}
