import 'dart:async';

class NotificationSignal {
  final String title;
  final String message;
  final String type;
  final Map<String, dynamic>? payload;

  const NotificationSignal({
    required this.title,
    required this.message,
    required this.type,
    this.payload,
  });

  String? get battleId => payload?['battle_id']?.toString();
}

class NotificationSignalService {
  NotificationSignalService._();

  static final NotificationSignalService instance =
      NotificationSignalService._();

  final StreamController<NotificationSignal> _controller =
      StreamController<NotificationSignal>.broadcast();

  Stream<NotificationSignal> get stream => _controller.stream;

  void show({
    required String title,
    required String message,
    required String type,
    Map<String, dynamic>? payload,
  }) {
    if (title.trim().isEmpty && message.trim().isEmpty) return;

    _controller.add(NotificationSignal(
      title: title,
      message: message,
      type: type,
      payload: payload,
    ));
  }
}
