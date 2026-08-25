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
    required this.tableId,
    required this.tableSessionId,
    required this.customerSessionId,
    super.key,
  });

  final String restaurantId;
  final String branchId;
  final String tableId;
  final String tableSessionId;
  final String customerSessionId;

  @override
  State<MenuPage> createState() => _MenuPageState();
}

class _MenuPageState extends State<MenuPage> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String? _selectedCategoryName;

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
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<MenuBloc, MenuState>(
      builder: (context, state) {
        final catalog = switch (state) {
          MenuLoaded(:final catalog) => catalog,
          _ => null,
        };

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
          drawer: catalog == null
              ? null
              : _CategoryDrawer(
                  categories: _categoriesFor(catalog),
                  selectedCategoryName: _selectedCategoryName,
                  onCategorySelected: (categoryName) {
                    setState(() => _selectedCategoryName = categoryName);
                    Navigator.of(context).pop();
                  },
                ),
          body: switch (state) {
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
            MenuLoaded(:final catalog) => _MenuCatalogView(
              catalog: catalog,
              searchController: _searchController,
              searchQuery: _searchQuery,
              selectedCategoryName: _selectedCategoryName,
              onSearchChanged: (value) => setState(() => _searchQuery = value),
              onClearSearch: () {
                _searchController.clear();
                setState(() => _searchQuery = '');
              },
              onClearCategory: () =>
                  setState(() => _selectedCategoryName = null),
              categoryNameFor: _categoryNameFor,
            ),
          },
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => context.go(_cartPath()),
            icon: const Icon(Icons.shopping_cart_outlined),
            label: const Text('View cart'),
          ),
        );
      },
    );
  }

  String _cartPath() {
    return Uri(
      path: '/cart',
      queryParameters: <String, String>{
        'restaurantId': widget.restaurantId,
        'branchId': widget.branchId,
        'tableId': widget.tableId,
        'tableSessionId': widget.tableSessionId,
        'customerSessionId': widget.customerSessionId,
      },
    ).toString();
  }

  List<String> _categoriesFor(MenuCatalog catalog) {
    final categories = <String>{};
    for (final category in catalog.categories) {
      final name = category.name.trim();
      if (name.isNotEmpty) categories.add(name);
    }
    for (final item in catalog.items) {
      categories.add(_categoryNameFor(catalog, item));
    }
    return categories.toList(growable: false);
  }

  String _categoryNameFor(MenuCatalog catalog, MenuItem item) {
    final explicitName = item.categoryName?.trim();
    if (explicitName != null && explicitName.isNotEmpty) return explicitName;

    for (final category in catalog.categories) {
      if (category.id == item.categoryId) return category.name;
    }
    return item.categoryId;
  }
}

class _MenuCatalogView extends StatelessWidget {
  const _MenuCatalogView({
    required this.catalog,
    required this.searchController,
    required this.searchQuery,
    required this.selectedCategoryName,
    required this.onSearchChanged,
    required this.onClearSearch,
    required this.onClearCategory,
    required this.categoryNameFor,
  });

  final MenuCatalog catalog;
  final TextEditingController searchController;
  final String searchQuery;
  final String? selectedCategoryName;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onClearSearch;
  final VoidCallback onClearCategory;
  final String Function(MenuCatalog catalog, MenuItem item) categoryNameFor;

  @override
  Widget build(BuildContext context) {
    final normalizedSearch = searchQuery.trim().toLowerCase();
    final filteredItems = catalog.items
        .where((item) {
          final categoryName = categoryNameFor(catalog, item);
          final matchesCategory =
              selectedCategoryName == null ||
              categoryName == selectedCategoryName;
          final matchesSearch =
              normalizedSearch.isEmpty ||
              item.name.toLowerCase().contains(normalizedSearch);
          return matchesCategory && matchesSearch;
        })
        .toList(growable: false);

    final groupedItems = <String, List<MenuItem>>{};
    for (final item in filteredItems) {
      final categoryName = categoryNameFor(catalog, item);
      groupedItems.putIfAbsent(categoryName, () => <MenuItem>[]).add(item);
    }

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
          const SizedBox(height: 20),
          TextField(
            controller: searchController,
            onChanged: onSearchChanged,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Search menu items',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: searchQuery.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Clear search',
                      onPressed: onClearSearch,
                      icon: const Icon(Icons.clear),
                    ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              filled: true,
            ),
          ),
          if (selectedCategoryName != null) ...<Widget>[
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                Chip(
                  avatar: const Icon(Icons.filter_list, size: 18),
                  label: Text(selectedCategoryName!),
                  onDeleted: onClearCategory,
                ),
                const SizedBox(width: 8),
                Text(
                  '${filteredItems.length} item${filteredItems.length == 1 ? '' : 's'}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ],
          const SizedBox(height: 24),
          if (filteredItems.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 48),
              child: Column(
                children: <Widget>[
                  Icon(Icons.search_off, size: 48),
                  SizedBox(height: 12),
                  Text('No menu items match your search.'),
                ],
              ),
            )
          else
            ...groupedItems.entries.map(
              (entry) =>
                  _CategorySection(categoryName: entry.key, items: entry.value),
            ),
        ],
      ),
    );
  }
}

class _CategoryDrawer extends StatelessWidget {
  const _CategoryDrawer({
    required this.categories,
    required this.selectedCategoryName,
    required this.onCategorySelected,
  });

  final List<String> categories;
  final String? selectedCategoryName;
  final ValueChanged<String?> onCategorySelected;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 16, 12),
              child: Text(
                'Browse by category',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: Icon(
                Icons.grid_view_rounded,
                color: selectedCategoryName == null
                    ? colorScheme.primary
                    : null,
              ),
              title: const Text('All categories'),
              selected: selectedCategoryName == null,
              onTap: () => onCategorySelected(null),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                itemCount: categories.length,
                itemBuilder: (context, index) {
                  final categoryName = categories[index];
                  final selected = categoryName == selectedCategoryName;
                  return ListTile(
                    leading: Icon(
                      Icons.restaurant_outlined,
                      color: selected ? colorScheme.primary : null,
                    ),
                    title: Text(categoryName),
                    selected: selected,
                    onTap: () => onCategorySelected(categoryName),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategorySection extends StatelessWidget {
  const _CategorySection({required this.categoryName, required this.items});

  final String categoryName;
  final List<MenuItem> items;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(categoryName, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
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
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _MenuItemImage(imageUrl: item.imageUrl),
            const SizedBox(width: 12),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      item.name,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (item.description case final description?) ...<Widget>[
                      const SizedBox(height: 5),
                      Text(
                        description,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                    const SizedBox(height: 8),
                    Text(
                      _formatPrice(item.price),
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: IconButton.filled(
                tooltip: item.isAvailable ? 'Add to cart' : 'Unavailable',
                onPressed: item.isAvailable
                    ? () => context.read<CartBloc>().add(
                        AddToCartEvent(menuItem: item),
                      )
                    : null,
                icon: const Icon(Icons.add),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuItemImage extends StatelessWidget {
  const _MenuItemImage({this.imageUrl});

  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final url = imageUrl?.trim();
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox.square(
        dimension: 88,
        child: url == null || url.isEmpty
            ? const _ImagePlaceholder()
            : Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    const _ImagePlaceholder(),
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return const _ImagePlaceholder(showProgress: true);
                },
              ),
      ),
    );
  }
}

class _ImagePlaceholder extends StatelessWidget {
  const _ImagePlaceholder({this.showProgress = false});

  final bool showProgress;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return ColoredBox(
      color: colorScheme.surfaceContainerHighest,
      child: Center(
        child: showProgress
            ? SizedBox.square(
                dimension: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: colorScheme.primary,
                ),
              )
            : Icon(
                Icons.restaurant_rounded,
                color: colorScheme.onSurfaceVariant,
                size: 30,
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

String _formatPrice(int price) {
  final formatted = price.toString().replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => '.',
  );
  return '$formatted ₫';
}
