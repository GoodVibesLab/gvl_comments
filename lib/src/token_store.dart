class TokenStore {
  String? _token;
  DateTime? _exp;

  bool get isValid =>
      _token != null && _exp != null && DateTime.now().isBefore(_exp!);
  String? get token => _token;

  void setToken(String token, Duration ttl) {
    _token = token;
    _exp = DateTime.now().add(ttl - const Duration(minutes: 5));
  }

  void clear() {
    _token = null;
    _exp = null;
  }
}