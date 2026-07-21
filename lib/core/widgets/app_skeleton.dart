import 'package:flutter/material.dart';
import 'package:skeletonizer/skeletonizer.dart';

class AppSkeleton extends StatelessWidget {
  final bool loading;
  final Widget child;

  const AppSkeleton({super.key, required this.loading, required this.child});

  @override
  Widget build(BuildContext context) {
    return Skeletonizer(enabled: loading, child: child);
  }
}

/**
 later can use

 AppSkeleton(
  loading: state.isLoading,
  child: ProductList(),
)

 */
