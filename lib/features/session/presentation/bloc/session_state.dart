import 'package:scan_serve/features/session/domain/session_context.dart';

sealed class SessionState {
  const SessionState();
}

final class SessionInitial extends SessionState {
  const SessionInitial();
}

final class SessionReady extends SessionState {
  const SessionReady(this.context);

  final SessionContext context;
}
