import 'hire_flow_store.dart';

/// Without browser storage, pending hires live for the session.
HireFlowStore createHireFlowStore() => MemoryHireFlowStore();
