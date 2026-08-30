import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class OrderTrackingPage extends StatelessWidget {
  const OrderTrackingPage({required this.orderId, super.key});

  final String orderId;

  @override
  Widget build(BuildContext context) {
    final normalizedOrderId = orderId.trim();

    return Scaffold(
      appBar: AppBar(title: const Text('Order tracking')),
      body: normalizedOrderId.isEmpty
          ? const _TrackingMessage(
              icon: Icons.receipt_long_outlined,
              message: 'No order was selected for tracking.',
            )
          : StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('orders')
                  .doc(normalizedOrderId)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return _TrackingMessage(
                    icon: Icons.cloud_off_outlined,
                    message: 'Unable to load this order right now.',
                    detail: snapshot.error.toString(),
                  );
                }

                final document = snapshot.data;
                if (document == null || !document.exists) {
                  return const _TrackingMessage(
                    icon: Icons.receipt_long_outlined,
                    message: 'This order is no longer available.',
                  );
                }

                return _OrderTrackingContent(
                  orderId: document.id,
                  data: document.data() ?? const <String, dynamic>{},
                );
              },
            ),
    );
  }
}

class _OrderTrackingContent extends StatelessWidget {
  const _OrderTrackingContent({required this.orderId, required this.data});

  final String orderId;
  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final status = _normalizedStatus(data['status']);
    final statusColor = _statusColors[status] ?? Colors.blueGrey;
    final totalAmount = _asNumber(data['totalAmount'] ?? data['total']);
    final items = _asList(data['items'] ?? data['lines']);
    final itemCount = items.fold<int>(0, (total, item) {
      if (item is Map<String, dynamic>) {
        return total +
            (_asNumber(item['quantity']).round().clamp(0, 100000).toInt());
      }
      if (item is Map) {
        return total +
            (_asNumber(item['quantity']).round().clamp(0, 100000).toInt());
      }
      return total;
    });

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          'Order ${_truncateOrderId(orderId)}',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 20),
        Align(
          alignment: Alignment.centerLeft,
          child: _StatusBadge(status: status, color: statusColor),
        ),
        const SizedBox(height: 24),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Order summary',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 16),
                _SummaryRow(
                  label: 'Total amount',
                  value: NumberFormat.currency(
                    locale: 'vi_VN',
                    symbol: '₫',
                    decimalDigits: 0,
                  ).format(totalAmount),
                ),
                const SizedBox(height: 10),
                _SummaryRow(
                  label: 'Items',
                  value: '$itemCount ${itemCount == 1 ? 'item' : 'items'}',
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          _statusDescription(status),
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      ],
    );
  }

  static String _normalizedStatus(Object? value) {
    final status = value?.toString().trim().toUpperCase();
    return status == null || status.isEmpty ? 'PENDING' : status;
  }

  static String _truncateOrderId(String value) {
    if (value.length <= 12) return value;
    return '${value.substring(0, 8)}…${value.substring(value.length - 4)}';
  }

  static double _asNumber(Object? value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  static List<Object?> _asList(Object? value) {
    if (value is Iterable<Object?>) return value.toList(growable: false);
    if (value is Iterable) return List<Object?>.from(value);
    return const <Object?>[];
  }

  static String _statusDescription(String status) {
    switch (status) {
      case 'PENDING':
        return 'Your order has been received and is waiting for the kitchen.';
      case 'ACCEPTED':
        return 'The kitchen has accepted your order.';
      case 'PREPARING':
        return 'The kitchen is preparing your order now.';
      case 'READY':
        return 'Your order is ready to be served.';
      case 'SERVED':
        return 'This order has been served. Thank you.';
      case 'CANCELLED':
        return 'This order was cancelled.';
      default:
        return 'The order status is being updated.';
    }
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status, required this.color});

  final String status;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.55)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.circle, size: 10, color: color),
            const SizedBox(width: 8),
            Text(
              status,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
      ],
    );
  }
}

class _TrackingMessage extends StatelessWidget {
  const _TrackingMessage({
    required this.icon,
    required this.message,
    this.detail,
  });

  final IconData icon;
  final String message;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center),
            if (detail != null) ...[
              const SizedBox(height: 8),
              Text(
                detail!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

const _statusColors = <String, Color>{
  'PENDING': Colors.orange,
  'ACCEPTED': Colors.blue,
  'PREPARING': Colors.deepPurple,
  'READY': Colors.green,
  'SERVED': Colors.grey,
  'CANCELLED': Colors.red,
};
