import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:scan_serve/features/cart/presentation/bloc/cart_bloc.dart';
import 'package:scan_serve/features/cart/presentation/bloc/cart_event.dart';
import 'package:scan_serve/features/cart/presentation/bloc/cart_state.dart';
import 'package:scan_serve/features/cart/presentation/pages/cart_page.dart';
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
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(
      text: context.read<MenuBloc>().state.searchQuery,
    );
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
        final categoryTree = catalog == null
            ? const <_CategoryNode>[]
            : _buildCategoryTree(catalog);

        return Scaffold(
          appBar: AppBar(
            title: const Text('Menu'),
            actions: <Widget>[
              IconButton(
                tooltip: 'View order',
                onPressed: _showCartPreview,
                icon: const Icon(Icons.shopping_cart_outlined),
              ),
            ],
          ),
          drawer: catalog == null
              ? null
              : _CategoryDrawer(
                  categories: categoryTree,
                  totalItemCount: catalog.items.length,
                  selectedCategoryId: state.selectedCategoryId,
                  onCategorySelected: (categoryId) {
                    context.read<MenuBloc>().add(
                      MenuCategoryChanged(categoryId),
                    );
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
              categoryTree: categoryTree,
              searchController: _searchController,
              searchQuery: state.searchQuery,
              selectedCategoryId: state.selectedCategoryId,
              onSearchChanged: (query) =>
                  context.read<MenuBloc>().add(MenuSearchChanged(query)),
              onClearSearch: () {
                _searchController.clear();
                context.read<MenuBloc>().add(const MenuSearchChanged(''));
              },
              onClearCategory: () =>
                  context.read<MenuBloc>().add(const MenuCategoryChanged(null)),
            ),
          },
          floatingActionButton: FloatingActionButton.extended(
            onPressed: _showCartPreview,
            icon: const Icon(Icons.shopping_cart_outlined),
            label: const Text('View order'),
          ),
        );
      },
    );
  }

  Future<void> _showCartPreview() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BlocProvider.value(
        value: context.read<CartBloc>(),
        child: const CartSheet(),
      ),
    );
  }
}

class _MenuCatalogView extends StatelessWidget {
  const _MenuCatalogView({
    required this.catalog,
    required this.categoryTree,
    required this.searchController,
    required this.searchQuery,
    required this.selectedCategoryId,
    required this.onSearchChanged,
    required this.onClearSearch,
    required this.onClearCategory,
  });

  final MenuCatalog catalog;
  final List<_CategoryNode> categoryTree;
  final TextEditingController searchController;
  final String searchQuery;
  final String? selectedCategoryId;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onClearSearch;
  final VoidCallback onClearCategory;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CartBloc, CartState>(
      builder: (context, cartState) {
        final quantities = <String, int>{
          for (final item in cartState.cart.items)
            item.menuItemId: item.quantity,
        };
        final normalizedSearch = searchQuery.trim().toLowerCase();
        final selectedNode = _findCategoryNode(
          categoryTree,
          selectedCategoryId,
        );
        final selectedCategoryIds = selectedNode?.allCategoryIds ?? const {};
        final filteredItems = catalog.items
            .where((item) {
              final matchesCategory =
                  selectedNode == null ||
                  selectedCategoryIds.contains(item.categoryId);
              final matchesSearch =
                  normalizedSearch.isEmpty ||
                  item.name.toLowerCase().contains(normalizedSearch);
              return matchesCategory && matchesSearch;
            })
            .toList(growable: false);

        final groupedItems = <String, List<MenuItem>>{};
        for (final item in filteredItems) {
          final categoryName = _categoryNameFor(catalog, item);
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
              if (selectedNode case final selected?) ...<Widget>[
                const SizedBox(height: 12),
                Row(
                  children: <Widget>[
                    Chip(
                      avatar: const Icon(Icons.filter_list, size: 18),
                      label: Text(selected.name),
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
                      Text('No menu items match your filters.'),
                    ],
                  ),
                )
              else
                ...groupedItems.entries.map(
                  (entry) => _CategorySection(
                    categoryName: entry.key,
                    items: entry.value,
                    quantities: quantities,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _CategoryDrawer extends StatelessWidget {
  const _CategoryDrawer({
    required this.categories,
    required this.totalItemCount,
    required this.selectedCategoryId,
    required this.onCategorySelected,
  });

  final List<_CategoryNode> categories;
  final int totalItemCount;
  final String? selectedCategoryId;
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
                color: selectedCategoryId == null ? colorScheme.primary : null,
              ),
              title: _CategoryLabel(
                name: 'All categories',
                itemCount: totalItemCount,
              ),
              selected: selectedCategoryId == null,
              onTap: () => onCategorySelected(null),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                children: categories
                    .map(
                      (category) => _CategoryTreeTile(
                        node: category,
                        selectedCategoryId: selectedCategoryId,
                        onCategorySelected: onCategorySelected,
                      ),
                    )
                    .toList(growable: false),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryLabel extends StatelessWidget {
  const _CategoryLabel({required this.name, required this.itemCount});

  final String name;
  final int itemCount;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: <Widget>[
        Expanded(child: Text(name, overflow: TextOverflow.ellipsis)),
        const SizedBox(width: 8),
        Container(
          constraints: const BoxConstraints(minWidth: 28),
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
          decoration: BoxDecoration(
            color: colorScheme.secondaryContainer,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            '$itemCount',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: colorScheme.onSecondaryContainer,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _CategoryTreeTile extends StatelessWidget {
  const _CategoryTreeTile({
    required this.node,
    required this.selectedCategoryId,
    required this.onCategorySelected,
  });

  final _CategoryNode node;
  final String? selectedCategoryId;
  final ValueChanged<String?> onCategorySelected;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isSelected = node.id == selectedCategoryId;
    final leading = Icon(
      node.children.isEmpty ? Icons.restaurant_outlined : Icons.folder_outlined,
      color: isSelected ? colorScheme.primary : null,
    );
    final title = _CategoryLabel(name: node.name, itemCount: node.itemCount);

    if (node.children.isEmpty) {
      return ListTile(
        leading: leading,
        title: title,
        selected: isSelected,
        contentPadding: const EdgeInsetsDirectional.only(start: 16, end: 16),
        onTap: () => onCategorySelected(node.id),
      );
    }

    return ExpansionTile(
      key: PageStorageKey<String>('menu-category-${node.id}'),
      initiallyExpanded: node.containsCategory(selectedCategoryId),
      maintainState: true,
      controlAffinity: ListTileControlAffinity.trailing,
      tilePadding: const EdgeInsetsDirectional.only(start: 16, end: 16),
      leading: leading,
      title: InkWell(
        onTap: () => onCategorySelected(node.id),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: title,
        ),
      ),
      trailing: const Icon(Icons.expand_more),
      childrenPadding: EdgeInsets.zero,
      children: node.children
          .map(
            (child) => Padding(
              padding: const EdgeInsets.only(left: 16.0),
              child: _CategoryTreeTile(
                node: child,
                selectedCategoryId: selectedCategoryId,
                onCategorySelected: onCategorySelected,
              ),
            ),
          )
          .toList(growable: false),
    );
  }
}

class _CategorySection extends StatelessWidget {
  const _CategorySection({
    required this.categoryName,
    required this.items,
    required this.quantities,
  });

  final String categoryName;
  final List<MenuItem> items;
  final Map<String, int> quantities;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(categoryName, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          ...items.map(
            (item) =>
                _MenuItemTile(item: item, quantity: quantities[item.id] ?? 0),
          ),
        ],
      ),
    );
  }
}

class _MenuItemTile extends StatelessWidget {
  const _MenuItemTile({required this.item, required this.quantity});

  final MenuItem item;
  final int quantity;

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
                tooltip: item.isAvailable
                    ? quantity > 0
                          ? 'Add another'
                          : 'Add to order'
                    : 'Unavailable',
                onPressed: item.isAvailable
                    ? () {
                        context.read<CartBloc>().add(
                          AddToCartEvent(menuItem: item),
                        );
                        ScaffoldMessenger.of(context)
                          ..hideCurrentSnackBar()
                          ..showSnackBar(
                            SnackBar(
                              content: Text('Added ${item.name} to order'),
                              duration: const Duration(seconds: 2),
                            ),
                          );
                      }
                    : null,
                icon: quantity > 0
                    ? Text(
                        '$quantity',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      )
                    : const Icon(Icons.add),
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

class _CategoryNode {
  _CategoryNode({
    required this.id,
    required this.name,
    required this.displayOrder,
    this.parentCategoryId,
  });

  final String id;
  final String name;
  final int displayOrder;
  String? parentCategoryId;
  int directItemCount = 0;
  final Set<String> itemCategoryIds = <String>{};
  final List<_CategoryNode> children = <_CategoryNode>[];

  int get itemCount =>
      directItemCount + children.fold(0, (sum, child) => sum + child.itemCount);

  Set<String> get allCategoryIds => <String>{
    id,
    ...itemCategoryIds,
    ...children.expand((child) => child.allCategoryIds),
  };

  bool containsCategory(String? categoryId) {
    if (categoryId == null) return false;
    return allCategoryIds.contains(categoryId);
  }
}

List<_CategoryNode> _buildCategoryTree(MenuCatalog catalog) {
  final nodesById = <String, _CategoryNode>{};
  for (final category in catalog.categories) {
    nodesById[category.id] = _CategoryNode(
      id: category.id,
      name: category.name,
      displayOrder: category.displayOrder,
      parentCategoryId: category.parentCategoryId,
    );
  }

  for (final item in catalog.items) {
    final categoryName = _categoryNameFor(catalog, item);
    final itemParentCategoryId = item.parentCategoryId;
    if (itemParentCategoryId != null &&
        itemParentCategoryId != item.categoryId &&
        !nodesById.containsKey(itemParentCategoryId)) {
      nodesById[itemParentCategoryId] = _CategoryNode(
        id: itemParentCategoryId,
        name:
            _categoryNameForId(catalog, itemParentCategoryId) ??
            itemParentCategoryId,
        displayOrder: catalog.items.indexOf(item),
      );
    }
    final node = nodesById.putIfAbsent(
      item.categoryId,
      () => _CategoryNode(
        id: item.categoryId,
        name: categoryName,
        displayOrder: catalog.items.indexOf(item),
        parentCategoryId: itemParentCategoryId,
      ),
    );
    if (node.parentCategoryId == null &&
        itemParentCategoryId != null &&
        itemParentCategoryId != node.id) {
      node.parentCategoryId = itemParentCategoryId;
    }
    node.directItemCount += 1;
    node.itemCategoryIds.add(item.categoryId);
  }

  final roots = <_CategoryNode>[];
  for (final node in nodesById.values) {
    final parent = node.parentCategoryId == null
        ? null
        : nodesById[node.parentCategoryId!];
    if (parent == null || parent.id == node.id) {
      roots.add(node);
    } else {
      parent.children.add(node);
    }
  }

  void sortNodes(List<_CategoryNode> nodes) {
    nodes.sort(
      (left, right) => left.displayOrder == right.displayOrder
          ? left.name.toLowerCase().compareTo(right.name.toLowerCase())
          : left.displayOrder.compareTo(right.displayOrder),
    );
    for (final node in nodes) {
      sortNodes(node.children);
    }
  }

  void addGeneralChildren(List<_CategoryNode> nodes) {
    for (final node in nodes) {
      addGeneralChildren(node.children);
      if (node.directItemCount == 0) continue;
      final general = _CategoryNode(
        id: '${node.id}__general',
        name: 'General',
        displayOrder: -1,
        parentCategoryId: node.id,
      );
      general.directItemCount = node.directItemCount;
      general.itemCategoryIds.add(node.id);
      node.children.insert(0, general);
      node.directItemCount = 0;
    }
  }

  addGeneralChildren(roots);
  sortNodes(roots);
  return roots;
}

_CategoryNode? _findCategoryNode(
  Iterable<_CategoryNode> nodes,
  String? categoryId,
) {
  if (categoryId == null) return null;
  for (final node in nodes) {
    if (node.id == categoryId) return node;
    final match = _findCategoryNode(node.children, categoryId);
    if (match != null) return match;
  }
  return null;
}

String? _categoryNameForId(MenuCatalog catalog, String categoryId) {
  for (final category in catalog.categories) {
    if (category.id == categoryId) return category.name;
  }
  return null;
}

String _categoryNameFor(MenuCatalog catalog, MenuItem item) {
  final explicitName = item.categoryName?.trim();
  if (explicitName != null && explicitName.isNotEmpty) return explicitName;

  for (final category in catalog.categories) {
    if (category.id == item.categoryId) return category.name;
  }
  return item.categoryId;
}

String _formatPrice(int price) {
  final formatted = price.toString().replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => '.',
  );
  return '$formatted ₫';
}
