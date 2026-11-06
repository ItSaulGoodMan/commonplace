import 'dart:async';

import 'package:flutter/material.dart';

/// "0:42": how long something has been going, updated every second.
class Elapsed extends StatefulWidget {
  const Elapsed(this.since, {super.key, this.style});

  final DateTime since;
  final TextStyle? style;

  @override
  State<Elapsed> createState() => _ElapsedState();
}

class _ElapsedState extends State<Elapsed> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final seconds = DateTime.now()
        .difference(widget.since)
        .inSeconds
        .clamp(0, 359999);
    final text =
        '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
    return Text(text, style: widget.style);
  }
}
