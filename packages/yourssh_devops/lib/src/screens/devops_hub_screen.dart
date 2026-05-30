import 'package:flutter/material.dart';
import '../devops_plugin_config.dart';

// Stub — full implementation moved in Task 6
class DevOpsHubScreen extends StatelessWidget {
  final DevOpsPluginConfig config;
  const DevOpsHubScreen({super.key, required this.config});

  @override
  Widget build(BuildContext context) => const Center(
        child: Text('DevOps Hub loading...', style: TextStyle(color: Colors.white70)),
      );
}
