import 'package:flutter/material.dart';

enum SkinId {
  // Dark Skins
  midnight,
  sunsetCoral,
  auroraNeon,
  onyxGold,
  emeraldForest,
  cyberCiano,
  nordicOcean,
  // Light Skins
  citrusSolar,
  tropicalLagoon,
  roseGold,
  pureIce,
  warmSand,
  mintFresh,
  nordicFrost,
  titaniumSilver,
}

class AppSkin {
  final SkinId id;
  final String name;
  final String description;
  final bool isDark;
  final String? badge;

  final Color background;
  final Color surface;
  final Color surfaceLight;
  final Color border;

  final Color primary;
  final Color income;
  final Color expense;
  final Color warning;

  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;

  Color get primaryColor => primary;

  const AppSkin({
    required this.id,
    required this.name,
    required this.description,
    this.isDark = true,
    this.badge,
    required this.background,
    required this.surface,
    required this.surfaceLight,
    required this.border,
    required this.primary,
    required this.income,
    required this.expense,
    required this.warning,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
  });

  // ==========================================
  // 🌙 SKINS ESCURAS (MODO DARK)
  // ==========================================

  // 1. Sunset Coral (Tropical Sunset - Noite Índigo Profunda + Coral Laranja Solar Vibrante)
  static const AppSkin sunsetCoral = AppSkin(
    id: SkinId.sunsetCoral,
    name: 'Sunset Coral',
    description: 'Noite tropical vibrante com acentos marcantes em coral solar e âmbar.',
    isDark: true,
    badge: 'Vibrante',
    background: Color(0xFF0C101D), // Deep Night Indigo
    surface: Color(0xFF141C2E),    // Twilight Blue
    surfaceLight: Color(0xFF1E2A42), // Indigo Slate
    border: Color(0xFF2B3C5E),
    primary: Color(0xFFFF6B4A),   // Vibrant Sunset Coral
    income: Color(0xFF10B981),    // Mint Emerald
    expense: Color(0xFFF43F5E),   // Rose Crimson
    warning: Color(0xFFF59E0B),   // Solar Amber
    textPrimary: Color(0xFFFFF7ED), // Warm Cream
    textSecondary: Color(0xFFFDBA74), // Peach Glow
    textMuted: Color(0xFFEA580C),
  );

  // 2. Aurora Neon (Grafite Obsidiana + Ciano & Menta Elétrica Hipercolorida)
  static const AppSkin auroraNeon = AppSkin(
    id: SkinId.auroraNeon,
    name: 'Aurora Neon',
    description: 'Estética futurista hipercolorida com ciano neon e menta elétrica.',
    isDark: true,
    badge: 'Neon',
    background: Color(0xFF070D12), // Obsidian
    surface: Color(0xFF0E1720),    // Dark Cyan Surface
    surfaceLight: Color(0xFF172633), // Surface Light
    border: Color(0xFF1E3547),
    primary: Color(0xFF00E5FF),   // Cyan / Aqua Elétrico
    income: Color(0xFF00E676),    // Green Neon Vivo
    expense: Color(0xFFFF3366),   // Pink Coral Neon
    warning: Color(0xFFFFD600),   // Amarelo Neon
    textPrimary: Color(0xFFF0FDF4),
    textSecondary: Color(0xFF67E8F9),
    textMuted: Color(0xFF0891B2),
  );

  // 3. Midnight Slate (Original Web - Slate 900 + Azul Celeste)
  static const AppSkin midnight = AppSkin(
    id: SkinId.midnight,
    name: 'Midnight Slate',
    description: 'Padrão original com tons de ardósia e azul celeste.',
    isDark: true,
    badge: 'Padrão',
    background: Color(0xFF0F172A), // Slate 900
    surface: Color(0xFF1E293B),    // Slate 800
    surfaceLight: Color(0xFF334155), // Slate 700
    border: Color(0xFF334155),
    primary: Color(0xFF38BDF8),   // Sky Blue
    income: Color(0xFF10B981),    // Emerald
    expense: Color(0xFFF43F5E),   // Rose
    warning: Color(0xFFF59E0B),   // Amber
    textPrimary: Color(0xFFF8FAFC),
    textSecondary: Color(0xFF94A3B8),
    textMuted: Color(0xFF64748B),
  );

  // 4. Onyx Gold (Preto Puro + Ouro Dourado de Luxo)
  static const AppSkin onyxGold = AppSkin(
    id: SkinId.onyxGold,
    name: 'Onyx Gold',
    description: 'Preto profundo minimalista com detalhes em ouro luxo.',
    isDark: true,
    background: Color(0xFF09090B), // Zinc 950
    surface: Color(0xFF18181B),    // Zinc 900
    surfaceLight: Color(0xFF27272A), // Zinc 800
    border: Color(0xFF27272A),
    primary: Color(0xFFEAB308),   // Gold
    income: Color(0xFF10B981),    // Emerald
    expense: Color(0xFFE11D48),   // Crimson
    warning: Color(0xFFF59E0B),   // Amber
    textPrimary: Color(0xFFFAFAFA),
    textSecondary: Color(0xFFA1A1AA),
    textMuted: Color(0xFF71717A),
  );

  // 5. Emerald Forest (Verde Petróleo Escuro + Menta Alta Finança)
  static const AppSkin emeraldForest = AppSkin(
    id: SkinId.emeraldForest,
    name: 'Emerald Forest',
    description: 'Tons de floresta e petróleo com acentos em menta viva.',
    isDark: true,
    background: Color(0xFF051B14), // Deep Pine
    surface: Color(0xFF0D281E),    // Dark Forest
    surfaceLight: Color(0xFF163C2E), // Pine Mid
    border: Color(0xFF1E4D3C),
    primary: Color(0xFF10B981),   // Emerald Mint
    income: Color(0xFF34D399),    // Light Mint
    expense: Color(0xFFF43F5E),   // Rose Red
    warning: Color(0xFFFBBF24),   // Amber
    textPrimary: Color(0xFFECFDF5),
    textSecondary: Color(0xFFA7F3D0),
    textMuted: Color(0xFF6EE7B7),
  );

  // 6. Cyber Ciano (Grafite Profundo + Ciano Elétrico)
  static const AppSkin cyberCiano = AppSkin(
    id: SkinId.cyberCiano,
    name: 'Cyber Ciano',
    description: 'Estética moderna em grafite escuro e ciano neon.',
    isDark: true,
    background: Color(0xFF0D1117), // GitHub Dark
    surface: Color(0xFF161B22),    // Steel Slate
    surfaceLight: Color(0xFF21262D), // Steel 700
    border: Color(0xFF30363D),
    primary: Color(0xFF06B6D4),   // Electric Cyan
    income: Color(0xFF10B981),    // Green Neon
    expense: Color(0xFFEF4444),   // Coral Red
    warning: Color(0xFFF97316),   // Orange
    textPrimary: Color(0xFFF0F6FC),
    textSecondary: Color(0xFF8B949E),
    textMuted: Color(0xFF6E7681),
  );

  // 7. Nordic Ocean (Azul Abissal + Gelo Ártico)
  static const AppSkin nordicOcean = AppSkin(
    id: SkinId.nordicOcean,
    name: 'Nordic Ocean',
    description: 'Azul marinho escandinavo com toques de gelo ártico.',
    isDark: true,
    background: Color(0xFF0B132B), // Deep Abyss
    surface: Color(0xFF1C2541),    // Navy Night
    surfaceLight: Color(0xFF2E3A59), // Slate Navy
    border: Color(0xFF3A4766),
    primary: Color(0xFF48CAE4),   // Ice Blue
    income: Color(0xFF10B981),    // Sea Green
    expense: Color(0xFFE11D48),   // Crimson
    warning: Color(0xFFF59E0B),   // Amber
    textPrimary: Color(0xFFF1F5F9),
    textSecondary: Color(0xFF94A3B8),
    textMuted: Color(0xFF64748B),
  );

  // ==========================================
  // ☀️ SKINS CLARAS (MODO LIGHT)
  // ==========================================

  // 8. Citrus Solar (Tangerina Glow / Citrino Ensolarado Alegre)
  static const AppSkin citrusSolar = AppSkin(
    id: SkinId.citrusSolar,
    name: 'Solar Citrino',
    description: 'Visual alegre, ensolarado e vibrante com tangerina viva e âmbar.',
    isDark: false,
    badge: 'Vibrante',
    background: Color(0xFFFFFBEB), // Amber 50
    surface: Color(0xFFFFFFFF),    // Pure White
    surfaceLight: Color(0xFFFEF3C7), // Amber 100
    border: Color(0xFFFDE68A),     // Amber 200
    primary: Color(0xFFEA580C),   // Tangerine Orange
    income: Color(0xFF059669),    // Emerald
    expense: Color(0xFFE11D48),   // Rose
    warning: Color(0xFFD97706),   // Amber
    textPrimary: Color(0xFF78350F), // Amber 900
    textSecondary: Color(0xFFB45309), // Amber 700
    textMuted: Color(0xFFF59E0B),
  );

  // 9. Tropical Lagoon (Lagoa Tropical / Turquesa & Coral Alegre)
  static const AppSkin tropicalLagoon = AppSkin(
    id: SkinId.tropicalLagoon,
    name: 'Lagoa Tropical',
    description: 'Brisa marinha refrescante e colorida com turquesa e toques de coral.',
    isDark: false,
    badge: 'Tropical',
    background: Color(0xFFF0FDFA), // Teal 50
    surface: Color(0xFFFFFFFF),    // Pure White
    surfaceLight: Color(0xFFCCFBF1), // Teal 100
    border: Color(0xFF99F6E4),     // Teal 200
    primary: Color(0xFF0D9488),   // Teal 600
    income: Color(0xFF16A34A),    // Green 600
    expense: Color(0xFFF43F5E),   // Rose Coral
    warning: Color(0xFFEA580C),   // Tangerine
    textPrimary: Color(0xFF134E4A), // Teal 900
    textSecondary: Color(0xFF0F766E), // Teal 700
    textMuted: Color(0xFF2DD4BF),
  );

  // 10. Rose Gold (Blush Elegance / Rosé Sofisticado)
  static const AppSkin roseGold = AppSkin(
    id: SkinId.roseGold,
    name: 'Rose Gold',
    description: 'Tons sofisticados de rosé com detalhes em carmim elegante.',
    isDark: false,
    badge: 'Elegante',
    background: Color(0xFFFFF1F2), // Rose 50
    surface: Color(0xFFFFFFFF),    // Pure White
    surfaceLight: Color(0xFFFFE4E6), // Rose 100
    border: Color(0xFFFECDD3),     // Rose 200
    primary: Color(0xFFE11D48),   // Rose Carmine 600
    income: Color(0xFF059669),    // Emerald
    expense: Color(0xFFBE123C),    // Deep Rose
    warning: Color(0xFFD97706),    // Amber
    textPrimary: Color(0xFF881337), // Rose 900
    textSecondary: Color(0xFF9F1239), // Rose 700
    textMuted: Color(0xFFFB7185),
  );

  // 11. Pure Ice (Gelo Puro Minimalista - Fundo Gelo + Azul Céu)
  static const AppSkin pureIce = AppSkin(
    id: SkinId.pureIce,
    name: 'Pure Ice',
    description: 'Estética clean e minimalista com fundo gelo e azul celeste.',
    isDark: false,
    background: Color(0xFFF8FAFC), // Slate 50
    surface: Color(0xFFFFFFFF),    // Pure White
    surfaceLight: Color(0xFFF1F5F9), // Slate 100
    border: Color(0xFFE2E8F0),     // Slate 200
    primary: Color(0xFF0284C7),   // Sky 600
    income: Color(0xFF16A34A),    // Green 600
    expense: Color(0xFFDC2626),   // Red 600
    warning: Color(0xFFD97706),   // Amber 600
    textPrimary: Color(0xFF0F172A), // Slate 900
    textSecondary: Color(0xFF475569), // Slate 600
    textMuted: Color(0xFF94A3B8), // Slate 400
  );

  // 12. Warm Sand (Areia Dourada / Editorial Sofisticado)
  static const AppSkin warmSand = AppSkin(
    id: SkinId.warmSand,
    name: 'Warm Sand',
    description: 'Tons quentes de areia e marfim com bronze luxuoso.',
    isDark: false,
    background: Color(0xFFFBFBF9), // Warm Ivory
    surface: Color(0xFFFFFFFF),    // Pure White
    surfaceLight: Color(0xFFF5F3EF), // Sand 100
    border: Color(0xFFE7E3D8),     // Warm Sand Border
    primary: Color(0xFFB45309),   // Bronze Amber 700
    income: Color(0xFF15803D),    // Forest Green 700
    expense: Color(0xFFBE123C),   // Rose Carmine 700
    warning: Color(0xFFD97706),   // Amber 600
    textPrimary: Color(0xFF1C1917), // Stone 900
    textSecondary: Color(0xFF57534E), // Stone 600
    textMuted: Color(0xFFA8A29E), // Stone 400
  );

  // 13. Mint Fresh (Menta Suave / Alta Finança)
  static const AppSkin mintFresh = AppSkin(
    id: SkinId.mintFresh,
    name: 'Mint Fresh',
    description: 'Fundo menta suave revigorante com esmeralda refinada.',
    isDark: false,
    background: Color(0xFFF0FDF4), // Mint 50
    surface: Color(0xFFFFFFFF),    // Pure White
    surfaceLight: Color(0xFFDCFCE7), // Mint 100
    border: Color(0xFFBBF7D0),     // Mint 200
    primary: Color(0xFF059669),   // Emerald 600
    income: Color(0xFF16A34A),    // Green 600
    expense: Color(0xFFE11D48),   // Crimson 600
    warning: Color(0xFFD97706),   // Amber 600
    textPrimary: Color(0xFF064E3B), // Emerald 950
    textSecondary: Color(0xFF047857), // Emerald 700
    textMuted: Color(0xFF6EE7B7), // Mint 400
  );

  // 14. Nordic Frost (Gelo Ártico / Brisa Nórdica)
  static const AppSkin nordicFrost = AppSkin(
    id: SkinId.nordicFrost,
    name: 'Nordic Frost',
    description: 'Brisa nórdica azulada com ciano sereno de alta legibilidade.',
    isDark: false,
    background: Color(0xFFF0F9FF), // Sky 50
    surface: Color(0xFFFFFFFF),    // Pure White
    surfaceLight: Color(0xFFE0F2FE), // Sky 100
    border: Color(0xFFBAE6FD),     // Sky 200
    primary: Color(0xFF0891B2),   // Cyan 600
    income: Color(0xFF0D9488),    // Teal 600
    expense: Color(0xFFE11D48),   // Rose 600
    warning: Color(0xFFEA580C),   // Orange 600
    textPrimary: Color(0xFF0C4A6E), // Sky 900
    textSecondary: Color(0xFF0369A1), // Sky 700
    textMuted: Color(0xFF7DD3FC), // Sky 300
  );

  // 15. Titanium Silver (Prata Titânio / Monocromático Moderno)
  static const AppSkin titaniumSilver = AppSkin(
    id: SkinId.titaniumSilver,
    name: 'Titanium Silver',
    description: 'Prata metálica sóbria e moderna com detalhes em azul real.',
    isDark: false,
    background: Color(0xFFF4F4F5), // Zinc 100
    surface: Color(0xFFFFFFFF),    // Pure White
    surfaceLight: Color(0xFFE4E4E7), // Zinc 200
    border: Color(0xFFD4D4D8),     // Zinc 300
    primary: Color(0xFF2563EB),   // Royal Blue 600
    income: Color(0xFF16A34A),    // Green 600
    expense: Color(0xFFDC2626),   // Red 600
    warning: Color(0xFFD97706),   // Amber 600
    textPrimary: Color(0xFF18181B), // Zinc 900
    textSecondary: Color(0xFF52525B), // Zinc 600
    textMuted: Color(0xFFA1A1AA), // Zinc 400
  );

  static const List<AppSkin> darkSkins = [
    sunsetCoral,
    auroraNeon,
    midnight,
    onyxGold,
    emeraldForest,
    cyberCiano,
    nordicOcean,
  ];

  static const List<AppSkin> lightSkins = [
    citrusSolar,
    tropicalLagoon,
    roseGold,
    pureIce,
    warmSand,
    mintFresh,
    nordicFrost,
    titaniumSilver,
  ];

  static const List<AppSkin> all = [
    sunsetCoral,
    auroraNeon,
    midnight,
    onyxGold,
    emeraldForest,
    cyberCiano,
    nordicOcean,
    citrusSolar,
    tropicalLagoon,
    roseGold,
    pureIce,
    warmSand,
    mintFresh,
    nordicFrost,
    titaniumSilver,
  ];

  static AppSkin fromId(String? idStr) {
    if (idStr == null) return midnight;
    for (final skin in all) {
      if (skin.id.name == idStr) return skin;
    }
    return midnight;
  }

  ThemeData toThemeData() {
    final brightness = isDark ? Brightness.dark : Brightness.light;

    return ThemeData(
      brightness: brightness,
      scaffoldBackgroundColor: background,
      primaryColor: primary,
      colorScheme: isDark
          ? ColorScheme.dark(
              primary: primary,
              surface: surface,
              error: expense,
            )
          : ColorScheme.light(
              primary: primary,
              surface: surface,
              error: expense,
            ),
      fontFamily: 'Inter',
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
        iconTheme: IconThemeData(color: textPrimary),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
          elevation: 0,
          minimumSize: const Size.fromHeight(50),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        hintStyle: TextStyle(color: textMuted),
        labelStyle: TextStyle(color: textSecondary),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: primary, width: 2),
        ),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: border, width: 1),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
    );
  }
}
