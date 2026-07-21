import 'dart:async';

import 'package:flutter/material.dart';

class TypewriterText extends StatefulWidget {
  const TypewriterText({
    super.key,
    required this.text,
    this.style,
    this.charDelay = const Duration(milliseconds: 28),
  });

  final String text;
  final TextStyle? style;
  final Duration charDelay;

  @override
  State<TypewriterText> createState() => _TypewriterTextState();
}

class _TypewriterTextState extends State<TypewriterText> {
  Timer? _timer;
  int _visibleCount = 0;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void didUpdateWidget(covariant TypewriterText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      _timer?.cancel();
      _visibleCount = 0;
      _start();
    }
  }

  void _start() {
    _timer = Timer.periodic(widget.charDelay, (timer) {
      if (!mounted) return;

      if (_visibleCount >= widget.text.length) {
        timer.cancel();
        return;
      }

      setState(() {
        _visibleCount++;
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final visible = widget.text.substring(
      0,
      _visibleCount.clamp(0, widget.text.length),
    );
    return Text(visible, style: widget.style);
  }
}
