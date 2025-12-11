/// In-memory cache for bearer tokens with a small safety margin on expiry.
class TokenStore {
  String? _token;
  DateTime? _exp;
  String? _plan;

  /// Stores the token and expires it 30 seconds before the official time.
  void save(String token, int expiresInSec, {String? plan}) {
    _token = token;
    _exp = DateTime.now().add(Duration(seconds: expiresInSec - 30));
    _plan = plan;
  }

  String? validBearer() {
    if (_token == null || _exp == null) return null;
    if (DateTime.now().isAfter(_exp!)) return null;
    return _token!;
  }

  String? get plan => _plan;

  Future<void> clear() async {
    _token = null;
    _exp = null;
    _plan = null;
  }
}