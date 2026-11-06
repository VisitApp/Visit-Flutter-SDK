/// Suppresses duplicate pending handlers, including their JavaScript effects.
class HealthCallGuard {
  final Set<(int, Object)> _pending = {};
  int _document = 0;
  bool _disposed = false;

  bool isCurrent(int document) => !_disposed && document == _document;

  Future<void> run(
    Object key,
    Future<void> Function(int document) action,
  ) async {
    final document = _document;
    final pendingKey = (document, key);
    if (_disposed || !_pending.add(pendingKey)) return;
    try {
      await action(document);
    } finally {
      _pending.remove(pendingKey);
    }
  }

  void newDocument() {
    _document++;
    _pending.clear();
  }

  void dispose() {
    _disposed = true;
    newDocument();
  }
}
