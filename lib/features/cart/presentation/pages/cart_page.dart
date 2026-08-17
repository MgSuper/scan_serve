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
          return _CartContent(state: state);
        },
      ),
    );
  }
}

class _CartContent extends StatelessWidget {
  const _CartContent({required this.state});

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
  const _SubmittedView({required this.orderId});

  final String orderId;

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
              onPressed: () => context.go(
                Uri(
                  path: '/order-tracking',
                  queryParameters: <String, String>{'orderId': orderId},
                ).toString(),
              ),
              child: const Text('Track order'),
            ),
          ],
        ),
      ),
    );
  }
}
