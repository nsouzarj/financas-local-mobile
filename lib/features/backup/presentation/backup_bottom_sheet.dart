import 'package:flutter/material.dart';
import '../../../core/database/backup_service.dart';
import '../../../core/theme/app_theme.dart';

class BackupBottomSheet extends StatefulWidget {
  const BackupBottomSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const BackupBottomSheet(),
    );
  }

  @override
  State<BackupBottomSheet> createState() => _BackupBottomSheetState();
}

class _BackupBottomSheetState extends State<BackupBottomSheet> {
  final BackupService _backupService = BackupService.instance;
  List<BackupItem> _backups = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadBackups();
  }

  Future<void> _loadBackups() async {
    setState(() => _isLoading = true);
    final list = await _backupService.listBackups();
    if (mounted) {
      setState(() {
        _backups = list;
        _isLoading = false;
      });
    }
  }

  Future<void> _handleCreateBackup() async {
    setState(() => _isLoading = true);
    try {
      final bkp = await _backupService.createManualBackup();
      await _loadBackups();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Backup salvo com sucesso: ${bkp.fileName} (${bkp.formattedSize})'),
            backgroundColor: AppTheme.income,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao criar backup: $e'), backgroundColor: AppTheme.expense),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleExportJson() async {
    setState(() => _isLoading = true);
    try {
      final path = await _backupService.exportDataToJson();
      await _loadBackups();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('📄 Exportação JSON gerada em: $path'),
            backgroundColor: AppTheme.primary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao exportar JSON: $e'), backgroundColor: AppTheme.expense),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _confirmRestore(BackupItem item) async {
    if (item.type == 'json') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Restauração direta disponível para backups de banco (.db).')),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: Text('Restaurar Backup?', style: TextStyle(color: AppTheme.textPrimary)),
        content: Text(
          'Deseja restaurar o banco a partir de:\n"${item.fileName}"?\n\nO estado do banco voltará para o momento em que este backup foi gerado (${item.formattedDate}).',
          style: TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancelar', style: TextStyle(color: AppTheme.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.warning),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Restaurar Agora', style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isLoading = true);
      final success = await _backupService.restoreDatabaseFromBackup(item.filePath);
      if (mounted) {
        setState(() => _isLoading = false);
        if (success) {
          Navigator.pop(context); // Fecha bottom sheet
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('🎉 Banco restaurado com sucesso a partir de ${item.fileName}!'),
              backgroundColor: AppTheme.income,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Falha ao restaurar banco de dados.'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  /// Confirma e exclui um arquivo de backup individual com modal de confirmação
  Future<void> _confirmDeleteBackup(BackupItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.delete_outline_rounded, color: AppTheme.expense, size: 24),
            const SizedBox(width: 8),
            Text(
              'Excluir Backup?',
              style: TextStyle(color: AppTheme.textPrimary, fontSize: 17, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Text(
          'Tem certeza que deseja apagar o backup:\n"${item.fileName}"?\n\nO arquivo (${item.formattedSize}) será excluído definitivamente da memória do aparelho.',
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancelar', style: TextStyle(color: AppTheme.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.expense,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirmar Exclusão'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isLoading = true);
      final success = await _backupService.deleteBackup(item.filePath);
      await _loadBackups();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success ? '🗑️ Backup "${item.fileName}" excluído com sucesso.' : 'Falha ao excluir backup.',
            ),
            backgroundColor: success ? AppTheme.surfaceLight : AppTheme.expense,
          ),
        );
      }
    }
  }

  /// Confirma e limpa todos os backups com modal de confirmação
  Future<void> _confirmDeleteAllBackups() async {
    if (_backups.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppTheme.expense, size: 24),
            const SizedBox(width: 8),
            Text(
              'Excluir Todos os Backups?',
              style: TextStyle(color: AppTheme.textPrimary, fontSize: 17, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Text(
          'Tem certeza que deseja apagar todas as ${_backups.length} cópias de backup salvas no aparelho?\n\nEsta ação liberará espaço, mas os pontos de restauração anteriores serão perdidos.',
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancelar', style: TextStyle(color: AppTheme.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.expense,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sim, Excluir Todos'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isLoading = true);
      final success = await _backupService.deleteAllBackups();
      await _loadBackups();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success ? '🗑️ Todas as cópias de backup foram excluídas com sucesso.' : 'Falha ao limpar backups.',
            ),
            backgroundColor: success ? AppTheme.surfaceLight : AppTheme.expense,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.88,
        ),
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
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
                      child: Icon(Icons.shield_rounded, color: AppTheme.primary, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Backups & Segurança',
                          style: TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Cópia do banco local SQLite (Offline)',
                          style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
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

            // Banner explicativo do backup pré-atualização
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.primary.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  Icon(Icons.auto_awesome, color: AppTheme.primary, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '🛡️ Proteção ativa: Se houver qualquer atualização de versão no app, um backup pré-atualização é gerado automaticamente antes de alterar o banco.',
                      style: TextStyle(color: AppTheme.textPrimary, fontSize: 12, height: 1.3),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // Ações rápidas de Backup
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: AppTheme.isDark ? const Color(0xFF0F172A) : Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: _isLoading ? null : _handleCreateBackup,
                    icon: const Icon(Icons.save_rounded, size: 18),
                    label: const Text('Backup (.db)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.textPrimary,
                      side: BorderSide(color: AppTheme.border),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: _isLoading ? null : _handleExportJson,
                    icon: Icon(Icons.code_rounded, color: AppTheme.primary, size: 18),
                    label: const Text('Exportar JSON', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 18),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Cópias Salvas no Aparelho (${_backups.length})',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_backups.isNotEmpty)
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          visualDensity: VisualDensity.compact,
                        ),
                        onPressed: _isLoading ? null : _confirmDeleteAllBackups,
                        icon: Icon(Icons.delete_sweep_outlined, color: AppTheme.expense, size: 16),
                        label: Text(
                          'Limpar Todos',
                          style: TextStyle(
                            color: AppTheme.expense,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    IconButton(
                      icon: Icon(Icons.refresh_rounded, color: AppTheme.textMuted, size: 18),
                      tooltip: 'Atualizar lista',
                      onPressed: _loadBackups,
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 8),

            // Lista de backups
            Flexible(
              child: _isLoading
                  ? Center(child: CircularProgressIndicator(color: AppTheme.primary))
                  : _backups.isEmpty
                      ? Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceLight.withOpacity(0.4),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppTheme.border),
                          ),
                          child: Center(
                            child: Text(
                              'Nenhum backup encontrado ainda.\nToque no botão acima para criar o primeiro!',
                              style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        )
                      : ListView.separated(
                          shrinkWrap: true,
                          physics: const BouncingScrollPhysics(),
                          itemCount: _backups.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final item = _backups[index];
                            final isPreUpdate = item.type == 'pre_upgrade';
                            final isJson = item.type == 'json';

                            return Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppTheme.surfaceLight.withOpacity(0.3),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isPreUpdate ? AppTheme.warning.withOpacity(0.3) : AppTheme.border,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: isPreUpdate
                                          ? AppTheme.warning.withOpacity(0.15)
                                          : (isJson ? AppTheme.primary.withOpacity(0.12) : AppTheme.income.withOpacity(0.15)),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(
                                      isPreUpdate
                                          ? Icons.update_rounded
                                          : (isJson ? Icons.data_object_rounded : Icons.storage_rounded),
                                      color: isPreUpdate
                                          ? AppTheme.warning
                                          : (isJson ? AppTheme.primary : AppTheme.income),
                                      size: 18,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                item.fileName,
                                                style: TextStyle(
                                                  color: AppTheme.textPrimary,
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            if (isPreUpdate)
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: AppTheme.warning.withOpacity(0.15),
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                                child: Text(
                                                  'PRÉ-UPDATE',
                                                  style: TextStyle(
                                                    color: AppTheme.warning,
                                                    fontSize: 8,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          '${item.formattedDate} • ${item.formattedSize}',
                                          style: TextStyle(color: AppTheme.textMuted, fontSize: 11),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  if (!isJson)
                                    IconButton(
                                      icon: Icon(Icons.settings_backup_restore_rounded, color: AppTheme.warning, size: 20),
                                      tooltip: 'Restaurar este backup',
                                      visualDensity: VisualDensity.compact,
                                      onPressed: () => _confirmRestore(item),
                                    ),
                                  IconButton(
                                    icon: Icon(Icons.delete_outline_rounded, color: AppTheme.expense, size: 20),
                                    tooltip: 'Excluir este backup',
                                    visualDensity: VisualDensity.compact,
                                    onPressed: () => _confirmDeleteBackup(item),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

