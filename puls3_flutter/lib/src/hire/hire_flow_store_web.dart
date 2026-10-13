import 'dart:js_interop';

import 'hire_flow_store.dart';

@JS('localStorage')
external _Storage? get _localStorage;

extension type _Storage(JSObject _) implements JSObject {
  external JSString? getItem(JSString key);
  external void setItem(JSString key, JSString value);
  external void removeItem(JSString key);
}

/// The browser's `localStorage`: a pending hire survives a reload. When
/// storage is blocked (private mode, disabled site data) it keeps the hire
/// in memory instead, so the flow still works within the session.
class BrowserHireFlowStore implements HireFlowStore {
  final _fallback = MemoryHireFlowStore();

  @override
  PendingHire? read(String key) {
    try {
      final storage = _localStorage;
      if (storage != null) {
        return PendingHire.decode(storage.getItem(key.toJS)?.toDart);
      }
    } on Object {
      // Storage blocked: use the session copy.
    }
    return _fallback.read(key);
  }

  @override
  void write(String key, PendingHire hire) {
    _fallback.write(key, hire);
    try {
      _localStorage?.setItem(key.toJS, hire.encode().toJS);
    } on Object {
      // Storage blocked or full: the session copy still protects the flow.
    }
  }

  @override
  void remove(String key) {
    _fallback.remove(key);
    try {
      _localStorage?.removeItem(key.toJS);
    } on Object {
      // Nothing to remove.
    }
  }
}

HireFlowStore createHireFlowStore() => BrowserHireFlowStore();
