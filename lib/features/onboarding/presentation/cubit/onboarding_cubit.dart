import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:startup_launch/features/onboarding/data/onboarding_storage.dart';
import 'package:startup_launch/features/onboarding/presentation/cubit/onboarding_state.dart';

class OnboardingCubit extends Cubit<OnboardingState> {
  OnboardingCubit({required OnboardingStorage storage})
    : _storage = storage,
      super(OnboardingState.initial());

  final OnboardingStorage _storage;

  void setPage(int index) {
    emit(state.copyWith(currentPage: index));
  }

  Future<void> complete() async {
    if (state.isSubmitting) return;

    emit(state.copyWith(isSubmitting: true));
    await _storage.setCompleted();
    emit(state.copyWith(isSubmitting: false));
  }
}
