import 'models.dart';

abstract interface class CustomerRepository {
  Future<List<MenuItem>> getActiveMenu();
  Future<CustomerOrder> submitOrder(List<CartLine> lines);
  Stream<CustomerOrder?> getActiveOrder();
  Future<void> requestWaiter();
  Future<void> requestPayment();
}
