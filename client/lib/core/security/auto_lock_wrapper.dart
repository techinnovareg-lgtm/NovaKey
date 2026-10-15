import 'dart:async';
import 'package:flutter/material.dart';

/// Detector global de inactividad de usuario con bloqueo automático de seguridad
class AutoLockWrapper extends StatefulWidget {
  final Widget child;
  final VoidCallback onTimeout;
  final Duration timeout;
  final bool isEnabled;

  const AutoLockWrapper({
    super.key,
    required this.child,
    required this.onTimeout,
    this.timeout = const Duration(minutes: 2),
    this.isEnabled = true,
  });

  @override
  State<AutoLockWrapper> createState() => _AutoLockWrapperState();
}

class _AutoLockWrapperState extends State<AutoLockWrapper> with WidgetsBindingObserver {
  Timer? _inactivityTimer;
  DateTime? _lastActivityTime;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.isEnabled) {
      _resetTimer();
    }
  }

  @override
  void didUpdateWidget(covariant AutoLockWrapper oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isEnabled != oldWidget.isEnabled || widget.timeout != oldWidget.timeout) {
      if (widget.isEnabled) {
        _resetTimer();
      } else {
        _cancelTimer();
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cancelTimer();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!widget.isEnabled) return;

    if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
      // Si la app pasa a segundo plano o se minimiza, guardar el momento de salida
      _lastActivityTime = DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      // Al regresar, verificar si el tiempo en segundo plano superó el límite permitido
      if (_lastActivityTime != null) {
        final elapsed = DateTime.now().difference(_lastActivityTime!);
        if (elapsed >= widget.timeout) {
          widget.onTimeout();
          return;
        }
      }
      _resetTimer();
    }
  }

  void _resetTimer() {
    _cancelTimer();
    if (!widget.isEnabled) return;

    _lastActivityTime = DateTime.now();
    _inactivityTimer = Timer(widget.timeout, () {
      if (mounted && widget.isEnabled) {
        widget.onTimeout();
      }
    });
  }

  void _cancelTimer() {
    _inactivityTimer?.cancel();
    _inactivityTimer = null;
  }

  void _handleUserActivity() {
    if (widget.isEnabled) {
      _resetTimer();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isEnabled) {
      return widget.child;
    }

    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _handleUserActivity(),
      onPointerMove: (_) => _handleUserActivity(),
      onPointerHover: (_) => _handleUserActivity(),
      onPointerSignal: (_) => _handleUserActivity(),
      child: widget.child,
    );
  }
}
