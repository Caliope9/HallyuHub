import 'dart:async';

import 'package:flutter/material.dart';

import '../services/hally_feature_tip_service.dart';
import '../theme/app_theme.dart';

/// Shows a brief, non-modal Hally popup in the feature where it is mounted.
/// The popup floats above the page and does not take up layout space.
class HallyFeatureTip extends StatefulWidget {
  const HallyFeatureTip({
    super.key,
    required this.featureId,
    required this.title,
    required this.message,
    this.mascotAsset = 'assets/brand/hally_mascot_wave_transparent.png',
    this.compact = false,
    this.service = const HallyFeatureTipService(),
  });

  final String featureId;
  final String title;
  final String message;
  final String mascotAsset;
  final bool compact;
  final HallyFeatureTipService service;

  @override
  State<HallyFeatureTip> createState() => _HallyFeatureTipState();
}

class _HallyFeatureTipState extends State<HallyFeatureTip> {
  bool _disabled = false;
  bool _loaded = false;
  bool _popupQueued = false;
  OverlayEntry? _popupEntry;
  Completer<void>? _popupCompletion;

  @override
  void initState() {
    super.initState();
    _loadPreference();
  }

  Future<void> _loadPreference() async {
    final disabled = await widget.service.isDisabled(widget.featureId);
    if (!mounted) return;
    setState(() {
      _disabled = disabled;
      _loaded = true;
    });
  }

  bool _isActiveAndVisible() {
    if (!mounted || !TickerMode.valuesOf(context).enabled) return false;
    final route = ModalRoute.of(context);
    if (route != null && !route.isCurrent) return false;
    var visible = true;
    context.visitAncestorElements((element) {
      final ancestor = element.widget;
      if ((ancestor is Offstage && ancestor.offstage) ||
          (ancestor is Visibility && !ancestor.visible)) {
        visible = false;
        return false;
      }
      return true;
    });
    return visible;
  }

  void _queuePopupIfNeeded() {
    if (!_loaded ||
        _disabled ||
        _popupQueued ||
        widget.service.wasDismissedThisSession(widget.featureId) ||
        !_isActiveAndVisible()) {
      return;
    }
    _popupQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!_isActiveAndVisible()) {
        _popupQueued = false;
        return;
      }
      widget.service.enqueuePopup(() async {
        if (!mounted || !_isActiveAndVisible()) {
          _popupQueued = false;
          return;
        }
        await _showPopup();
      });
    });
  }

  Future<void> _showPopup() async {
    if (!mounted ||
        _disabled ||
        widget.service.wasDismissedThisSession(widget.featureId)) {
      return;
    }

    final overlay = Overlay.of(context, rootOverlay: true);
    final completion = Completer<void>();
    _popupCompletion = completion;
    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (overlayContext) => Positioned(
        top: MediaQuery.paddingOf(overlayContext).top + 68,
        left: 14,
        right: 14,
        child: SafeArea(
          bottom: false,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 370),
              child: _popupCard(entry),
            ),
          ),
        ),
      ),
    );
    _popupEntry = entry;
    overlay.insert(entry);
    await completion.future;
  }

  Widget _popupCard(OverlayEntry entry) {
    return Material(
      key: ValueKey('hally-tip-popup-${widget.featureId}'),
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 8, 8),
        decoration: BoxDecoration(
          color: const Color(0xFF11172A),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppTheme.violet.withValues(alpha: .66)),
          boxShadow: [
            BoxShadow(
              color: AppTheme.violet.withValues(alpha: .22),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
          gradient: LinearGradient(
            colors: [
              AppTheme.violet.withValues(alpha: .18),
              AppTheme.cyan.withValues(alpha: .08),
            ],
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.asset(
                    widget.mascotAsset,
                    width: 36,
                    height: 36,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => Container(
                      width: 36,
                      height: 36,
                      color: AppTheme.violet,
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.auto_awesome_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    widget.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                    ),
                  ),
                ),
                IconButton(
                  key: ValueKey('hally-tip-close-${widget.featureId}'),
                  tooltip: 'Cerrar ayuda',
                  visualDensity: VisualDensity.compact,
                  constraints: const BoxConstraints.tightFor(
                    width: 34,
                    height: 34,
                  ),
                  padding: EdgeInsets.zero,
                  onPressed: () => _dismiss(entry),
                  icon: Icon(
                    Icons.close,
                    color: Colors.white.withValues(alpha: .72),
                    size: 19,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 5),
            Padding(
              padding: const EdgeInsets.only(left: 45, right: 8),
              child: Text(
                widget.message,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: .78),
                  height: 1.25,
                  fontSize: 11.5,
                ),
              ),
            ),
            const SizedBox(height: 3),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  key: ValueKey('hally-tip-disable-${widget.featureId}'),
                  onPressed: () => _disablePermanently(entry),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white.withValues(alpha: .68),
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    textStyle: const TextStyle(fontSize: 11),
                  ),
                  child: const Text('No volver a mostrar'),
                ),
                const SizedBox(width: 4),
                TextButton(
                  key: ValueKey('hally-tip-understood-${widget.featureId}'),
                  onPressed: () => _dismiss(entry),
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.cyan,
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    textStyle: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  child: const Text('Entendido'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _dismiss(OverlayEntry entry) {
    widget.service.dismissForSession(widget.featureId);
    _removePopup(entry);
  }

  Future<void> _disablePermanently(OverlayEntry entry) async {
    await widget.service.disable(widget.featureId);
    widget.service.dismissForSession(widget.featureId);
    _disabled = true;
    _removePopup(entry);
  }

  void _removePopup(OverlayEntry entry) {
    if (entry.mounted) entry.remove();
    if (identical(_popupEntry, entry)) _popupEntry = null;
    final completion = _popupCompletion;
    _popupCompletion = null;
    if (completion != null && !completion.isCompleted) completion.complete();
  }

  @override
  void dispose() {
    final entry = _popupEntry;
    if (entry != null) _removePopup(entry);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _queuePopupIfNeeded();
    // Help is an overlay, never a fixed banner that pushes feature content.
    return const SizedBox.shrink();
  }
}
