import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:scan_serve/features/cart/presentation/bloc/cart_bloc.dart';
import 'package:scan_serve/features/cart/presentation/bloc/cart_event.dart';
import 'package:scan_serve/features/menu/domain/menu_entities.dart';
import 'package:scan_serve/features/menu/presentation/bloc/menu_bloc.dart';
import 'package:scan_serve/features/menu/presentation/bloc/menu_event.dart';
import 'package:scan_serve/features/menu/presentation/bloc/menu_state.dart';

class MenuPage extends StatefulWidget {
  const MenuPage({
    required this.restaurantId,
    required this.branchId,
    super.key,
  });

  final String restaurantId;
  final String branchId;

  @override
  State<MenuPage> createState() => _MenuPageState();
}

class _MenuPageState extends State<MenuPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<MenuBloc>().add(
          LoadMenu(
            restaurantId: widget.restaurantId,
            branchId: widget.branchId,
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Menu'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Cart',
            onPressed: () => context.go(_cartPath()),
            icon: const Icon(Icons.shopping_cart_outlined),
          ),
        ],
      ),
      body: BlocBuilder<MenuBloc, MenuState>(
        builder: (context, state) {
          return switch (state) {
            MenuInitial() ||
            MenuLoading() => const Center(child: CircularProgressIndicator()),
            MenuError(:final message) => _ErrorView(
              message: message,
              onRetry: () => context.read<MenuBloc>().add(
                RefreshMenu(
                  restaurantId: widget.restaurantId,
                  branchId: widget.branchId,
                ),
              ),
            ),
            MenuLoaded(:final catalog) => _MenuCatalogView(catalog: catalog),
          };
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go(_cartPath()),
        icon: const Icon(Icons.shopping_cart_outlined),
        label: const Text('View cart'),
      ),
    );
  }

  String _cartPath() {
    return Uri(
      path: '/cart',
      queryParameters: <String, String>{
        'restaurantId': widget.restaurantId,
        'branchId': widget.branchId,
      },
    ).toString();
  }
}

class _MenuCatalogView extends StatelessWidget {
  const _MenuCatalogView({required this.catalog});

  final MenuCatalog catalog;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async {
        context.read<MenuBloc>().add(
          RefreshMenu(
            restaurantId: catalog.menu.restaurantId,
            branchId: catalog.menu.branchId,
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 250));
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 104),
        children: <Widget>[
          Text(
            catalog.menu.name,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          if (catalog.menu.description case final description?) ...<Widget>[
            const SizedBox(height: 8),
            Text(description),
          ],
          const SizedBox(height: 24),
          ...catalog.categories.map(
            (category) => _CategorySection(
              category: category,
              items: catalog.items
                  .where((item) => item.categoryId == category.id)
                  .toList(growable: false),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategorySection extends StatelessWidget {
  const _CategorySection({required this.category, required this.items});

  final Category category;
  final List<MenuItem> items;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(category.name, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          if (items.isEmpty)
            const Text('No items are currently available.')
          else
            ...items.map((item) => _MenuItemTile(item: item)),
        ],
      ),
    );
  }
}

class _MenuItemTile extends StatelessWidget {
  const _MenuItemTile({required this.item});

  final MenuItem item;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text(item.name),
        subtitle: item.description == null ? null : Text(item.description!),
        trailing: FilledButton(
          onPressed: item.isAvailable
              ? () =>
                    context.read<CartBloc>().add(AddToCartEvent(menuItem: item))
              : null,
          child: Text(item.price.toString()),
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
