enum GatewayStatus {
  stopped,
  starting,
  running,
  error,
}

class GatewayState {
  final GatewayStatus status;
  final List<String> logs;
  final String? errorMessage;
  final DateTime? startedAt;

  const GatewayState({
    this.status = GatewayStatus.stopped,
    this.logs = const [],
    this.errorMessage,
    this.startedAt,
  });

  GatewayState copyWith({
    GatewayStatus? status,
    List<String>? logs,
    String? errorMessage,
    DateTime? startedAt,
  }) {
    return GatewayState(
      status: status ?? this.status,
      logs: logs ?? this.logs,
      errorMessage: errorMessage,
      startedAt: startedAt ?? this.startedAt,
    );
  }

  bool get isRunning => status == GatewayStatus.running;
  bool get isStopped => status == GatewayStatus.stopped;

  String get statusText {
    switch (status) {
      case GatewayStatus.stopped:
        return 'Stopped';
      case GatewayStatus.starting:
        return 'Starting...';
      case GatewayStatus.running:
        return 'Running';
      case GatewayStatus.error:
        return 'Error';
    }
  }
}
