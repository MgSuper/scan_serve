import 'package:scan_serve/features/session/domain/session_context.dart';

sealed class SessionEvent {
  const SessionEvent();
}

final class SessionStarted extends SessionEvent {
  const SessionStarted(this.context);

  final SessionContext context;
}
