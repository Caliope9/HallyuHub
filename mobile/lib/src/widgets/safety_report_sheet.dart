import 'package:flutter/material.dart';

import '../services/local_safety_service.dart';
import '../theme/app_theme.dart';
import 'premium_form_shell.dart';

Future<bool> showSafetyReportSheet({
  required BuildContext context,
  required LocalSafetyService safetyService,
  required String contentType,
  required String title,
  String contentId = '',
  String reportedUserId = '',
  Map<String, Object?> metadata = const {},
}) async {
  final submitted = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _SafetyReportSheet(
      safetyService: safetyService,
      contentType: contentType,
      contentId: contentId,
      reportedUserId: reportedUserId,
      title: title,
      metadata: metadata,
    ),
  );
  return submitted ?? false;
}

class _SafetyReportSheet extends StatefulWidget {
  const _SafetyReportSheet({
    required this.safetyService,
    required this.contentType,
    required this.contentId,
    required this.reportedUserId,
    required this.title,
    required this.metadata,
  });

  final LocalSafetyService safetyService;
  final String contentType;
  final String contentId;
  final String reportedUserId;
  final String title;
  final Map<String, Object?> metadata;

  @override
  State<_SafetyReportSheet> createState() => _SafetyReportSheetState();
}

class _SafetyReportSheetState extends State<_SafetyReportSheet> {
  final _detailsController = TextEditingController();
  String _reason = safetyReportReasons.first.key;
  bool _submitting = false;
  String _error = '';

  @override
  void dispose() {
    _detailsController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) return;
    setState(() {
      _submitting = true;
      _error = '';
    });
    try {
      await widget.safetyService.reportContent(
        contentType: widget.contentType,
        contentId: widget.contentId,
        reportedUserId: widget.reportedUserId,
        reason: _reason,
        details: _detailsController.text,
        metadata: widget.metadata,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = _friendlyError(error);
      });
    }
  }

  String _friendlyError(Object error) {
    final message = error.toString();
    if (message.startsWith('SafetyServiceException: ')) {
      return message.replaceFirst('SafetyServiceException: ', '');
    }
    return 'No pudimos guardar el reporte. Probá de nuevo.';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 14,
        right: 14,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 12,
      ),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.86,
        ),
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
        decoration: BoxDecoration(
          color: const Color(0xFF060913),
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: AppTheme.amber.withValues(alpha: 0.2)),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const PremiumSheetHandle(),
                const SizedBox(height: 14),
                PremiumFormHero(
                  title: 'Reportar',
                  subtitle: widget.title,
                  icon: Icons.outlined_flag_rounded,
                  visual: PremiumFormVisual.report,
                  trailing: IconButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    icon: const Icon(Icons.close_rounded),
                    tooltip: 'Cerrar',
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'MOTIVO',
                  style: TextStyle(
                    color: AppTheme.amber.withValues(alpha: 0.9),
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final reason in safetyReportReasons)
                      ChoiceChip(
                        label: Text(reason.label),
                        selected: _reason == reason.key,
                        onSelected: (_) => setState(() => _reason = reason.key),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _detailsController,
                  minLines: 3,
                  maxLines: 5,
                  maxLength: 600,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Detalle opcional',
                    hintText: 'Contanos brevemente qué pasó.',
                    filled: true,
                    fillColor: const Color(0xFF0D1425),
                  ),
                ),
                if (_error.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    _error,
                    style: const TextStyle(
                      color: AppTheme.rose,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _submitting ? null : _submit,
                  icon: _submitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.flag_outlined),
                  label: const Text('Enviar reporte'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
