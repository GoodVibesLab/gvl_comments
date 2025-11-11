class TokenStore {
  String? _token;
  DateTime? _exp;

  void save(String token, int expiresInSec) {
    _token = token;
    _exp = DateTime.now().add(Duration(seconds: expiresInSec - 30)); // marge 30s
  }

  String? validBearer() {
    if (_token == null || _exp == null) return null;
    if (DateTime.now().isAfter(_exp!)) return null;
    return _token!;
  }

  Future<void> clear() async {
    _token = null;
    _exp = null;
  }
}