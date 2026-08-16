/// Framework-independent API envelopes mandated by architecture Spec 011.
class ApiRequest<T> {
  const ApiRequest({required this.requestId, required this.payload, required this.timestamp, this.clientVersion});
  final String requestId;
  final T payload;
  final DateTime timestamp;
  final String? clientVersion;
}
class ApiError {
  const ApiError({required this.code, required this.message, this.details});
  final String code;
  final String message;
  final Map<String, Object?>? details;
}
class ApiResponse<T> {
  const ApiResponse.success({required this.requestId, required this.data, required this.serverTimestamp}) : success = true, error = null;
  const ApiResponse.failure({required this.requestId, required this.error, required this.serverTimestamp}) : success = false, data = null;
  final bool success;
  final String requestId;
  final T? data;
  final ApiError? error;
  final DateTime serverTimestamp;
}
