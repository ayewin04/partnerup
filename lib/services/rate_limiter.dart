import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Central definition of every rate limit in the app.
class RateLimits {
  static const Duration createPost = Duration(seconds: 30);
  static const Duration sendComment = Duration(seconds: 10);
  static const Duration toggleLike = Duration(seconds: 1);
  static const Duration submitReport = Duration(hours: 72);
  static const Duration proposePartnership = Duration(minutes: 2);
  static const Duration sendChatMessage = Duration(seconds: 2);

  // Hourly caps tracked via Firestore
  static const int likesPerHour = 300;
  static const int chatsPerDay = 50;
}

/// Client-side cooldowns backed by SharedPreferences.
/// This is UX polish — real enforcement lives in Firestore rules.
class RateLimiter {
  static Future<bool> allow({
    required String action,
    required Duration cooldown,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'rl_$action';
    final last = prefs.getInt(key) ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - last < cooldown.inMilliseconds) return false;
    await prefs.setInt(key, now);
    return true;
  }

  static Future<int> secondsRemaining({
    required String action,
    required Duration cooldown,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final last = prefs.getInt('rl_$action') ?? 0;
    final elapsed = DateTime.now().millisecondsSinceEpoch - last;
    final remaining = cooldown.inMilliseconds - elapsed;
    return remaining > 0 ? (remaining / 1000).ceil() : 0;
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((k) => k.startsWith('rl_')).toList();
    for (final k in keys) {
      await prefs.remove(k);
    }
  }
}

/// Friendly formatter for cooldown durations.
String formatCooldown(int seconds) {
  if (seconds < 60) return '${seconds}s';
  if (seconds < 3600) return '${(seconds / 60).ceil()} minute(s)';
  if (seconds < 86400) return '${(seconds / 3600).ceil()} hour(s)';
  return '${(seconds / 86400).ceil()} day(s)';
}

/// Helper: show a friendly rate-limit snackbar.
void showRateLimitMessage(
  BuildContext context, {
  required String action,
  required int seconds,
}) {
  ScaffoldMessenger.of(context).hideCurrentSnackBar();
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Row(
        children: [
          const Icon(Icons.timer, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Please wait ${formatCooldown(seconds)} before $action again.',
              style: const TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
      backgroundColor: Colors.orange[700],
      duration: const Duration(seconds: 3),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
    ),
  );
}

/// Helper: show a generic error snackbar (for Firestore failures).
void showErrorSnack(BuildContext context, String message) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).hideCurrentSnackBar();
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message, style: const TextStyle(fontSize: 13)),
          ),
        ],
      ),
      backgroundColor: Colors.red[700],
      duration: const Duration(seconds: 4),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
    ),
  );
}

/// Translate a Firestore exception into a user-friendly message.
String firestoreErrorToMessage(Object e) {
  final s = e.toString();
  if (s.contains('permission-denied') ||
      s.contains('PERMISSION_DENIED') ||
      s.contains('Missing or insufficient permissions')) {
    return 'You\'re doing that too fast. Please slow down.';
  }
  if (s.contains('unavailable') || s.contains('network')) {
    return 'No internet connection. Try again.';
  }
  if (s.contains('deadline-exceeded')) {
    return 'Request timed out. Try again.';
  }
  if (s.contains('resource-exhausted')) {
    return 'Too many requests right now. Try again shortly.';
  }
  return 'Something went wrong. Please try again.';
}
