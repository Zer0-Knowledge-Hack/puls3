/// Severity of a [ChainLog] message.
enum ChainLogLevel { info, warning, error }

/// Where the chain module writes operational messages. The composition
/// root maps it to the Serverpod session log; tests collect it.
typedef ChainLog = void Function(ChainLogLevel level, String message);

/// A [ChainLog] that drops every message.
void ignoreChainLog(ChainLogLevel level, String message) {}
