import 'models.dart';

abstract interface class CustomerRepository {
  Future<List<MenuItem>> getActiveMenu();
  Future<CustomerOrder> submitOrder(List<CartLine> lines);
  Future<CustomerOrder?> getActiveOrder();
  Future<void> requestWaiter();
}
