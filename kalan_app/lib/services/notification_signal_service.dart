import 'dart:async';

class NotificationSignal {
  final String title;
  final String message;
  final String type;

  const NotificationSignal({
    required this.title,
    required this.message,
    required this.type,
  });
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
  }) {
    if (title.trim().isEmpty && message.trim().isEmpty) return;

    _controller.add(NotificationSignal(
      title: title,
      message: message,
      type: type,
    ));
  }
}
