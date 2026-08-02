import 'package:flutter/material.dart';
import 'map_screen.dart';

class DriveCenterScreen extends StatelessWidget {
  const DriveCenterScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: const Color(0xff020a18),
        appBar: AppBar(title: const Text('Drive Center'), backgroundColor: Colors.transparent),
        body: Center(child: FilledButton.icon(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MapScreen())), icon: const Icon(Icons.navigation), label: const Text('Start drive'))),
      );
}
