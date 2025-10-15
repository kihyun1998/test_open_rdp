import 'package:flutter/material.dart';

import 'pages/rdp_connection_page.dart';

void main() {
  runApp(const RDPApp());
}

class RDPApp extends StatelessWidget {
  const RDPApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RDP Connection Manager',
      theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
      home: const RDPConnectionPage(),
    );
  }
}
