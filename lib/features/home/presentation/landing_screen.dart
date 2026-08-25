import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:scan_serve/app/routes/app_routes.dart';
import 'package:scan_serve/features/customer/domain/customer_repository.dart';

class LandingScreen extends StatefulWidget {
  const LandingScreen({
    required this.restaurantName,
    required this.branchName,
    required this.openingHours,
    required this.tableId,
    required this.menuLocation,
    required this.repository,
    super.key,
  });

  final String restaurantName;
  final String branchName;
  final String openingHours;
  final String tableId;
  final String menuLocation;
  final CustomerRepository repository;

  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen> {
  String? _busyAction;

  Future<void> _requestAssistance({
    required String action,
    required Future<void> Function() request,
    required String successMessage,
    required String errorMessage,
  }) async {
    if (_busyAction != null) return;
    setState(() => _busyAction = action);
    try {
      await request();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(successMessage)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(errorMessage)));
    } finally {
      if (mounted) setState(() => _busyAction = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Your table'),
        centerTitle: false,
        actions: [
          IconButton(
            tooltip: 'Settings',
            onPressed: () => context.go(AppRoutes.settings),
            icon: const Icon(Icons.settings),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(28),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.restaurant_menu_rounded,
                          size: 36,
                          color: colorScheme.onPrimaryContainer,
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'Welcome',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: colorScheme.onPrimaryContainer.withValues(
                              alpha: .78,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.restaurantName,
                          style: theme.textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: colorScheme.onPrimaryContainer,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Your table is ready. Explore the menu, order at your pace, and enjoy your visit.',
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: colorScheme.onPrimaryContainer.withValues(
                              alpha: .84,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          _VisitDetail(
                            icon: Icons.storefront_outlined,
                            label: 'Branch',
                            value: widget.branchName,
                          ),
                          const Divider(height: 24),
                          _VisitDetail(
                            icon: Icons.schedule_outlined,
                            label: 'Opening hours',
                            value: widget.openingHours,
                          ),
                          const Divider(height: 24),
                          _VisitDetail(
                            icon: Icons.table_restaurant_outlined,
                            label: 'Table',
                            value: widget.tableId,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  Text(
                    'Need assistance?',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Our team is happy to help whenever you need us.',
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 14),
                  OutlinedButton.icon(
                    onPressed: _busyAction == null
                        ? () => _requestAssistance(
                            action: 'staff',
                            request: widget.repository.requestWaiter,
                            successMessage: 'A staff member has been notified.',
                            errorMessage:
                                'Unable to call a staff member right now.',
                          )
                        : null,
                    icon: _busyAction == 'staff'
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.room_service_outlined),
                    label: const Text('Call a staff member'),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _busyAction == null
                        ? () => _requestAssistance(
                            action: 'payment',
                            request: widget.repository.requestPayment,
                            successMessage:
                                'A staff member will come to help with payment.',
                            errorMessage:
                                'Unable to request payment assistance right now.',
                          )
                        : null,
                    icon: _busyAction == 'payment'
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.payments_outlined),
                    label: const Text('Call for payment'),
                  ),
                  const SizedBox(height: 28),
                  FilledButton.icon(
                    onPressed: () => context.go(widget.menuLocation),
                    icon: const Icon(Icons.restaurant_menu),
                    label: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 4),
                      child: Text('Menu & ordering'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _VisitDetail extends StatelessWidget {
  const _VisitDetail({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: Theme.of(context).textTheme.labelMedium),
              const SizedBox(height: 2),
              Text(
                value,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
