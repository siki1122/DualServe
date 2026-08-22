import 'package:flutter/foundation.dart';

class GlobalState {
  // Tracks the bookingId of the currently open chat screen to prevent 
  // duplicate notifications when the user is actively viewing the chat.
  static final ValueNotifier<String?> activeChatBookingId = ValueNotifier<String?>(null);
}
