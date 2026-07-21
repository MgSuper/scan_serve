class OnboardingState {
  const OnboardingState({
    required this.currentPage,
    required this.isSubmitting,
  });

  factory OnboardingState.initial() {
    return const OnboardingState(currentPage: 0, isSubmitting: false);
  }

  final int currentPage;
  final bool isSubmitting;

  OnboardingState copyWith({int? currentPage, bool? isSubmitting}) {
    return OnboardingState(
      currentPage: currentPage ?? this.currentPage,
      isSubmitting: isSubmitting ?? this.isSubmitting,
    );
  }
}
