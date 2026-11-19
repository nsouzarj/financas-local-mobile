# Finanças Mobile (Flutter)

Aplicativo móvel completo do sistema financeiro, construído em **Flutter** e integrado à API RESTful PHP em produção (`https://nsouza.eti.br/financas/api`).

---

## ✨ Módulos e Funcionalidades

1. **Autenticação com Impressão Digital (Biometria / FaceID):**
   - No 1º login (e-mail e senha), o app salva o token JWT com `flutter_secure_storage`.
   - Permite desbloqueio instantâneo pelo sensor biométrico do celular.
   - Fallback para e-mail e senha.
2. **Navegação Inferior com 4 Abas:**
   - 🏠 **Início (Dashboard):** Saldo consolidado, totalizadores de receitas e despesas do mês e lançamentos recentes.
   - 📑 **Extrato (Lançamentos):** Pesquisa instantânea por texto, filtro rápido (Todos / Despesas / Receitas), badges de status e exclusão com recálculo.
   - 💳 **Contas & Cartões:** Listagem de todas as contas, saldos individuais, cartões com vencimento e fechamento, e modal completo para criar/editar contas e limites.
   - 🏷️ **Categorias:** Abas separadas de Despesas e Receitas, paleta de cores para ícones e modal para criar/editar/excluir.
3. **Novo Lançamento Rápido (+):**
   - Criação de receitas e despesas.
   - Dropdowns com contas e categorias filtradas dinamicamente.
   - Seletor nativo de data e valor em R$.
4. **Planejamento Futuro & Cópia com Dias Úteis (`SettlePlannedDialog` & `PlanningScreen`):**
   - Baixa de contas com edição de valor, data e opção de pagamento parcial jogando a diferença para o próximo mês.
   - Cópia individual e em lote de previsões para o próximo mês com ajuste automático de finais de semana (sábado/domingo) para o próximo dia útil (segunda-feira).
   - Sincronização reativa global (`DataRefreshController`) entre todas as abas.

---

## 🚀 Como Compilar o APK

No terminal na pasta `mobile`:

```powershell
flutter build apk --release
```

O arquivo gerado estará em:
📁 **`mobile\build\app\outputs\flutter-apk\app-release.apk`**
