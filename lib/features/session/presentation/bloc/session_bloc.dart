import 'package:flutter_bloc/flutter_bloc.dart';

import 'session_event.dart';
import 'session_state.dart';

class SessionBloc extends Bloc<SessionEvent, SessionState> {
  SessionBloc() : super(const SessionInitial()) {
    on<SessionStarted>((event, emit) => emit(SessionReady(event.context)));
  }
}
