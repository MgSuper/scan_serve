import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:scan_serve/features/cart/presentation/bloc/cart_bloc.dart';
import 'package:scan_serve/features/cart/presentation/bloc/cart_event.dart';
import 'package:scan_serve/features/cart/presentation/bloc/cart_state.dart';

class CartPage extends StatelessWidget {
  const CartPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cart'),
        leading: BackButton(onPressed: () => context.go('/menu')),
      ),
      body: BlocBuilder<CartBloc, CartState>(
        builder: (context, state) {
          if (state is CartSubmitted) {
            return _SubmittedView(orderId: state.orderId);
          }
          return CartContent(state: state);
        },
      ),
    );
  }
}

class CartSheet extends StatelessWidget {
  const CartSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      heightFactor: .82,
      child: Material(
        clipBehavior: Clip.antiAlias,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: Column(
          children: <Widget>[
            const SizedBox(height: 12),
            Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Your order',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
            ),
            Expanded(
              child: BlocBuilder<CartBloc, CartState>(
                builder: (context, state) {
                  if (state is CartSubmitted) {
                    return _SubmittedView(
                      orderId: state.orderId,
                      closeSheetBeforeNavigate: true,
                    );
                  }
                  return CartContent(state: state);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CartContent extends StatelessWidget {
  const CartContent({required this.state, super.key});

  final CartState state;

  @override
  Widget build(BuildContext context) {
    final cart = state.cart;
    if (cart.items.isEmpty) {
      return const Center(child: Text('Your cart is empty.'));
    }

    return Column(
      children: <Widget>[
        if (state is CartError)
          MaterialBanner(
            content: Text((state as CartError).message),
            actions: <Widget>[
              TextButton(
                onPressed: () =>
                    context.read<CartBloc>().add(const SubmitOrderEvent()),
                child: const Text('Retry'),
              ),
            ],
          ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: cart.items.length,
            separatorBuilder: (context, index) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final item = cart.items[index];
              return Card(
                child: ListTile(
                  title: Text(item.name),
                  subtitle: Text('${item.quantity} × ${item.unitPrice}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(item.lineTotal.toString()),
                      IconButton(
                        tooltip: 'Remove one',
                        onPressed: () => context.read<CartBloc>().add(
                          RemoveFromCartEvent(menuItemId: item.menuItemId),
                        ),
                        icon: const Icon(Icons.remove_circle_outline),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        SafeArea(
          minimum: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  const Text('Subtotal'),
                  Text(cart.subtotal.toString()),
                ],
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: state is CartSubmitting
                    ? null
                    : () => context.read<CartBloc>().add(
                        const SubmitOrderEvent(),
                      ),
                child: state is CartSubmitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Submit order'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SubmittedView extends StatelessWidget {
  const _SubmittedView({
    required this.orderId,
    this.closeSheetBeforeNavigate = false,
  });

  final String orderId;
  final bool closeSheetBeforeNavigate;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(Icons.check_circle_outline, size: 64),
            const SizedBox(height: 16),
            const Text('Order submitted.'),
            const SizedBox(height: 8),
            Text('Order ID: $orderId', textAlign: TextAlign.center),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => _trackOrder(context),
              child: const Text('Track order'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _trackOrder(BuildContext context) async {
    if (!context.mounted) return;

    final destination = Uri(
      path: '/order-tracking',
      queryParameters: <String, String>{'orderId': orderId},
    ).toString();
    final router = GoRouter.of(context);

    if (!closeSheetBeforeNavigate) {
      if (!context.mounted) return;
      context.go(destination);
      return;
    }

    if (!context.mounted) return;
    final navigator = Navigator.of(context);
    navigator.pop();
    await Future<void>.delayed(Duration.zero);
    router.go(destination);
  }
}
