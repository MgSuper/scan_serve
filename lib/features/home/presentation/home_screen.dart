import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:scan_serve/app/routes/app_routes.dart';
import 'package:scan_serve/core/di/service_locator.dart';
import 'package:scan_serve/features/customer/domain/customer_repository.dart';
import 'package:scan_serve/features/customer/domain/models.dart';
import 'package:scan_serve/features/customer/presentation/customer_cubit.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => CustomerCubit(sl<CustomerRepository>())..load(),
      child: const _CustomerHomeView(),
    );
  }
}

class _CustomerHomeView extends StatelessWidget {
  const _CustomerHomeView();

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<CustomerCubit, CustomerState>(
      listenWhen: (previous, current) => previous.message != current.message,
      listener: (context, state) {
        if (state.message != null) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(state.message!)));
        }
      },
      builder: (context, state) {
        return Scaffold(
          appBar: AppBar(
            title: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('ScanServe'),
              Text('Table 12 · Riverside Branch', style: TextStyle(fontSize: 12)),
            ]),
            actions: [
              IconButton(tooltip: 'Call waiter', onPressed: context.read<CustomerCubit>().callWaiter, icon: const Icon(Icons.room_service_outlined)),
              IconButton(tooltip: 'Settings', onPressed: () => context.go(AppRoutes.settings), icon: const Icon(Icons.settings)),
            ],
          ),
          body: state.loading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: context.read<CustomerCubit>().load,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
                    children: [
                      if (state.order != null) _OrderStatusCard(order: state.order!),
                      const Text('Today’s menu', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      const Text('Tap an item to add it to your order.'),
                      const SizedBox(height: 16),
                      ...state.menu.map((item) => _MenuItemCard(item: item)),
                    ],
                  ),
                ),
          bottomSheet: state.cart.isEmpty ? null : _CartSheet(state: state),
        );
      },
    );
  }
}

class _MenuItemCard extends StatelessWidget {
  const _MenuItemCard({required this.item});
  final MenuItem item;

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 12),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(item.category, style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: 4),
          Text(item.name, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(item.description),
          const SizedBox(height: 10),
          Text(_price(item.price), style: const TextStyle(fontWeight: FontWeight.bold)),
        ])),
        IconButton.filled(onPressed: item.available ? () => context.read<CustomerCubit>().add(item) : null, icon: const Icon(Icons.add)),
      ]),
    ),
  );
}

class _CartSheet extends StatelessWidget {
  const _CartSheet({required this.state});
  final CustomerState state;

  @override
  Widget build(BuildContext context) => Material(
    elevation: 12,
    child: SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(children: [
          Expanded(child: Text('${state.cartQuantity} item${state.cartQuantity == 1 ? '' : 's'} · ${_price(state.cartTotal)}', style: const TextStyle(fontWeight: FontWeight.bold))),
          FilledButton(onPressed: () => _showCart(context), child: const Text('Review order')),
        ]),
      ),
    ),
  );

  void _showCart(BuildContext context) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) => BlocProvider.value(
      value: context.read<CustomerCubit>(),
      child: FractionallySizedBox(
        heightFactor: .75,
        child: BlocBuilder<CustomerCubit, CustomerState>(builder: (context, state) => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Your order', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Expanded(child: ListView(children: state.cart.map((line) => ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(line.item.name), subtitle: Text(_price(line.total)),
              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                IconButton(onPressed: () => context.read<CustomerCubit>().changeQuantity(line.item, line.quantity - 1), icon: const Icon(Icons.remove_circle_outline)),
                Text('${line.quantity}'),
                IconButton(onPressed: () => context.read<CustomerCubit>().changeQuantity(line.item, line.quantity + 1), icon: const Icon(Icons.add_circle_outline)),
              ]),
            )).toList())),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Total', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)), Text(_price(state.cartTotal), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))]),
            const SizedBox(height: 12),
            SizedBox(width: double.infinity, child: FilledButton(onPressed: () { context.read<CustomerCubit>().submitOrder(); Navigator.of(sheetContext).pop(); }, child: const Text('Place order'))),
          ]),
        )),
      ),
    ),
  );
}

class _OrderStatusCard extends StatelessWidget {
  const _OrderStatusCard({required this.order});
  final CustomerOrder order;
  @override
  Widget build(BuildContext context) => Card(
    color: Theme.of(context).colorScheme.primaryContainer,
    child: ListTile(
      leading: const Icon(Icons.receipt_long_outlined),
      title: Text('Order ${order.id}'),
      subtitle: Text(order.status.label),
      trailing: const Icon(Icons.chevron_right),
    ),
  );
}

String _price(int price) => '${(price / 1000).toStringAsFixed(0)}.000 ₫';
