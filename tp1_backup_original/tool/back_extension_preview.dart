import 'package:flutter/material.dart';
import 'package:tp1/widgets/back_extension_diagram.dart';

/// Local visual QA entry point; does not read accounts or workout data.
void main() => runApp(MaterialApp(
  debugShowCheckedModeBanner: false,
  theme: ThemeData.dark(),
  home: Scaffold(
    backgroundColor: const Color(0xFF0B0F14),
    body: SafeArea(child: SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Center(child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
        child: const BackExtensionDiagram(),
      )),
    )),
  ),
));
