import 'package:flutter/widgets.dart';

class WebToolsPluginConfig {
  /// Builder for the port-forward browser tab.
  /// Receives [onOpenUrl] so clicking a tunnel opens the Browser tab.
  final Widget Function(void Function(String url) onOpenUrl) portForwardBrowserBuilder;

  const WebToolsPluginConfig({
    required this.portForwardBrowserBuilder,
  });
}
