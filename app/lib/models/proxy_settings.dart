enum ProxyType { none, http, socks5 }

/// Runtime proxy parameters resolved from a Host plus its stored password.
class ProxySettings {
  final ProxyType type;
  final String host;
  final int port;
  final String? username;
  final String? password;
  const ProxySettings({
    required this.type,
    required this.host,
    required this.port,
    this.username,
    this.password,
  });
}
