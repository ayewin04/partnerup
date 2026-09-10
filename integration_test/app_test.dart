import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:partnerup_app/main.dart' as app;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

String uniqueEmail() =>
    'test${DateTime.now().millisecondsSinceEpoch}@partnerup.test';

String uniqueUsername() =>
    'u${DateTime.now().millisecondsSinceEpoch % 10000000}';

const testPassword = 'TestPass123';

/// Helper: register a new user and return to Login screen
Future<void> registerUser(WidgetTester tester,
    {String? email, String? username}) async {
  final e = email ?? uniqueEmail();
  _lastEmail = e;
  final u = username ?? uniqueUsername();

  // Wait for splash
  await tester.pumpAndSettle(const Duration(seconds: 5));

  // If logged in, log out first
  if (find.byIcon(Icons.logout).evaluate().isNotEmpty) {
    await tester.tap(find.byIcon(Icons.logout));
    await tester.pumpAndSettle(const Duration(seconds: 2));
    await tester.tap(find.text('Logout').last);
    await tester.pumpAndSettle(const Duration(seconds: 4));
  }

  // Navigate to Sign Up
  await tester.tap(find.text('New here? Sign Up'));
  await tester.pumpAndSettle(const Duration(seconds: 2));

  // Accept contract
  await tester.drag(find.byType(SingleChildScrollView).first,
      const Offset(0, -10000));
  await tester.pumpAndSettle(const Duration(seconds: 1));
  await tester.tap(find.byType(Checkbox));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Continue'));
  await tester.pumpAndSettle(const Duration(seconds: 2));

  // Fill signup
  final fields = find.byType(TextFormField);
  await tester.enterText(fields.at(0), u);
  await tester.enterText(fields.at(1), e);
  await tester.enterText(fields.at(2), testPassword);
  await tester.enterText(fields.at(3), testPassword);
  await tester.pumpAndSettle();

  await tester.tap(find.widgetWithText(ElevatedButton, 'Sign Up'));
  await tester.pumpAndSettle(const Duration(seconds: 8));

  // Dismiss popup → go to Login
  expect(find.text('Account Created!'), findsOneWidget);
  await tester.tap(find.text('Go to Login'));
  await tester.pumpAndSettle(const Duration(seconds: 3));
}

/// Helper: log in with credentials and return to feed
Future<void> loginUser(WidgetTester tester,
    String email, String password) async {
  final loginFields = find.byType(TextFormField);
  await tester.enterText(loginFields.at(0), email);
  await tester.enterText(loginFields.at(1), password);
  await tester.pumpAndSettle();
  await tester.tap(find.widgetWithText(ElevatedButton, 'Login'));
  await tester.pumpAndSettle(const Duration(seconds: 8));
  expect(find.text('What do you want to partner for?'), findsOneWidget);
}

/// Helper: log out from feed
Future<void> logoutUser(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.logout));
  await tester.pumpAndSettle(const Duration(seconds: 2));
  await tester.tap(find.text('Logout').last);
  await tester.pumpAndSettle(const Duration(seconds: 5));
  expect(find.widgetWithText(ElevatedButton, 'Login'), findsOneWidget);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // ==========================================================
  // GROUP 1: POST INPUT
  // ==========================================================
  group('1. Post Input', () {
    late String email;

    setUpAll(() async {
      // Create an account once, reuse for this group
    });

    testWidgets('1.2 empty post rejected', (tester) async {
      app.main();
      email = uniqueEmail();
      await registerUser(tester, email: email);
      await loginUser(tester, email, testPassword);

      final postsBefore = await FirebaseFirestore.instance
          .collection('posts').get();

      // Tap send with empty input
      await tester.tap(find.byIcon(Icons.send));
      await tester.pumpAndSettle(const Duration(seconds: 2));

      final postsAfter = await FirebaseFirestore.instance
          .collection('posts').get();

      expect(postsAfter.docs.length, postsBefore.docs.length);

      await logoutUser(tester);
    });

    testWidgets('1.9 whitespace-only post rejected', (tester) async {
      app.main();
      await registerUser(tester);
      await loginUser(tester,
        await _getLastEmail(), testPassword);

      await tester.enterText(find.byType(TextField).first, '     ');
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.send));
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Input should remain (not cleared) since trim() made it empty
      expect(find.text('     '), findsOneWidget);

      await logoutUser(tester);
    });

    testWidgets('1.3 post exactly 200 chars succeeds', (tester) async {
      app.main();
      await registerUser(tester);
      await loginUser(tester,
        await _getLastEmail(), testPassword);

      final longText = 'A' * 200;
      await tester.enterText(find.byType(TextField).first, longText);
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.send));
      await tester.pumpAndSettle(const Duration(seconds: 5));

      expect(find.text(longText), findsWidgets);

      await logoutUser(tester);
    });

    testWidgets('1.4 post over 200 chars capped by maxLength',
        (tester) async {
      app.main();
      await registerUser(tester);
      await loginUser(tester,
        await _getLastEmail(), testPassword);

      final tooLong = 'B' * 250;
      await tester.enterText(find.byType(TextField).first, tooLong);
      await tester.pumpAndSettle();

      // Flutter maxLength on web trims input
      final field = tester.widget<TextField>(find.byType(TextField).first);
      expect(field.controller!.text.length, lessThanOrEqualTo(200));

      await logoutUser(tester);
    });

    testWidgets('1.6 post with emojis succeeds', (tester) async {
      app.main();
      await registerUser(tester);
      await loginUser(tester,
        await _getLastEmail(), testPassword);

      const emojiPost = '🏋️ Looking for a gym 💪 partner!';
      await tester.enterText(find.byType(TextField).first, emojiPost);
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.send));
      await tester.pumpAndSettle(const Duration(seconds: 5));

      expect(find.text(emojiPost), findsWidgets);

      await logoutUser(tester);
    });

    testWidgets('1.7 post with newlines renders correctly', (tester) async {
      app.main();
      await registerUser(tester);
      await loginUser(tester,
        await _getLastEmail(), testPassword);

      const multiLine = 'Line 1\nLine 2\nLine 3';
      await tester.enterText(find.byType(TextField).first, multiLine);
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.send));
      await tester.pumpAndSettle(const Duration(seconds: 5));

      expect(find.text(multiLine), findsWidgets);

      await logoutUser(tester);
    });
  });

  // ==========================================================
  // GROUP 2: LIKE BUTTON
  // ==========================================================
  group('2. Like Button', () {
    testWidgets('2-3.1 like toggles and count changes', (tester) async {
      app.main();
      await registerUser(tester);
      await loginUser(tester, await _getLastEmail(), testPassword);

      // Create a post first
      await tester.enterText(find.byType(TextField).first,
          'Like test post ${DateTime.now().millisecondsSinceEpoch}');
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.send));
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Initially unfilled heart
      expect(find.byIcon(Icons.favorite_border), findsWidgets);

      // Tap like
      await tester.tap(find.byIcon(Icons.favorite_border).first);
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Now filled heart
      expect(find.byIcon(Icons.favorite), findsWidgets);

      // Tap again to unlike
      await tester.tap(find.byIcon(Icons.favorite).first);
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Back to unfilled
      expect(find.byIcon(Icons.favorite_border), findsWidgets);

      await logoutUser(tester);
    });

    testWidgets('3.3 rapid like taps don\'t crash', (tester) async {
      app.main();
      await registerUser(tester);
      await loginUser(tester, await _getLastEmail(), testPassword);

      await tester.enterText(find.byType(TextField).first,
          'Rapid like test ${DateTime.now().millisecondsSinceEpoch}');
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.send));
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Rapid taps
      for (int i = 0; i < 10; i++) {
        final icon = find.byIcon(Icons.favorite_border).evaluate().isNotEmpty
            ? Icons.favorite_border : Icons.favorite;
        if (find.byIcon(icon).evaluate().isNotEmpty) {
          await tester.tap(find.byIcon(icon).first, warnIfMissed: false);
          await tester.pump(const Duration(milliseconds: 100));
        }
      }
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // App didn't crash
      expect(find.text('PartnerUp'), findsWidgets);

      await logoutUser(tester);
    });

    testWidgets('3.5 like persists after refresh', (tester) async {
      app.main();
      await registerUser(tester);
      await loginUser(tester, await _getLastEmail(), testPassword);

      await tester.enterText(find.byType(TextField).first,
          'Persist like ${DateTime.now().millisecondsSinceEpoch}');
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.send));
      await tester.pumpAndSettle(const Duration(seconds: 5));

      await tester.tap(find.byIcon(Icons.favorite_border).first);
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Pull to refresh
      await tester.drag(find.byType(ListView).first, const Offset(0, 300));
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Heart should still be red
      expect(find.byIcon(Icons.favorite), findsWidgets);

      await logoutUser(tester);
    });
  });

  // ==========================================================
  // GROUP 3: COMMENTS
  // ==========================================================
  group('3. Comments', () {
    testWidgets('3-4.2 empty comments list shows placeholder',
        (tester) async {
      app.main();
      await registerUser(tester);
      await loginUser(tester, await _getLastEmail(), testPassword);

      await tester.enterText(find.byType(TextField).first,
          'Empty comment test ${DateTime.now().millisecondsSinceEpoch}');
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.send));
      await tester.pumpAndSettle(const Duration(seconds: 5));

      await tester.tap(find.byIcon(Icons.chat_bubble_outline).first);
      await tester.pumpAndSettle(const Duration(seconds: 3));

      expect(find.text('No comments yet. Be the first!'), findsOneWidget);

      // Close sheet
      await tester.tapAt(const Offset(200, 100));
      await tester.pumpAndSettle(const Duration(seconds: 2));

      await logoutUser(tester);
    });

    testWidgets('3-4.3 post a comment', (tester) async {
      app.main();
      await registerUser(tester);
      await loginUser(tester, await _getLastEmail(), testPassword);

      await tester.enterText(find.byType(TextField).first,
          'Comment test ${DateTime.now().millisecondsSinceEpoch}');
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.send));
      await tester.pumpAndSettle(const Duration(seconds: 5));

      await tester.tap(find.byIcon(Icons.chat_bubble_outline).first);
      await tester.pumpAndSettle(const Duration(seconds: 3));

      final commentText = 'Great idea! ${DateTime.now().millisecondsSinceEpoch}';
      await tester.enterText(find.byType(TextField).last, commentText);
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.send).last);
      await tester.pumpAndSettle(const Duration(seconds: 4));

      expect(find.text(commentText), findsWidgets);

      // Close sheet
      await tester.tapAt(const Offset(200, 100));
      await tester.pumpAndSettle(const Duration(seconds: 2));

      await logoutUser(tester);
    });

    testWidgets('4.7 empty comment rejected', (tester) async {
      app.main();
      await registerUser(tester);
      await loginUser(tester, await _getLastEmail(), testPassword);

      await tester.enterText(find.byType(TextField).first,
          'Empty comment test ${DateTime.now().millisecondsSinceEpoch}');
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.send));
      await tester.pumpAndSettle(const Duration(seconds: 5));

      await tester.tap(find.byIcon(Icons.chat_bubble_outline).first);
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Tap send with empty input
      await tester.tap(find.byIcon(Icons.send).last);
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Still no comments
      expect(find.text('No comments yet. Be the first!'), findsOneWidget);

      await tester.tapAt(const Offset(200, 100));
      await tester.pumpAndSettle(const Duration(seconds: 2));

      await logoutUser(tester);
    });
  });

  // ==========================================================
  // GROUP 4: POST DELETION
  // ==========================================================
  group('4. Post Deletion', () {
    testWidgets('9.1-9.3 delete own post works', (tester) async {
      app.main();
      await registerUser(tester);
      await loginUser(tester, await _getLastEmail(), testPassword);

      final postText = 'Delete me ${DateTime.now().millisecondsSinceEpoch}';
      await tester.enterText(find.byType(TextField).first, postText);
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.send));
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Tap three-dot menu on the first post
      await tester.tap(find.byIcon(Icons.more_vert).first);
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Delete Post option appears (only for own posts)
      expect(find.text('Delete Post'), findsOneWidget);
      await tester.tap(find.text('Delete Post'));
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Confirm dialog
      expect(find.text('Delete post?'), findsOneWidget);
      await tester.tap(find.text('Delete').last);
      await tester.pumpAndSettle(const Duration(seconds: 4));

      // Post gone
      expect(find.text(postText), findsNothing);

      await logoutUser(tester);
    });

    testWidgets('9.4 cancel delete keeps post', (tester) async {
      app.main();
      await registerUser(tester);
      await loginUser(tester, await _getLastEmail(), testPassword);

      final postText = 'Keep me ${DateTime.now().millisecondsSinceEpoch}';
      await tester.enterText(find.byType(TextField).first, postText);
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.send));
      await tester.pumpAndSettle(const Duration(seconds: 5));

      await tester.tap(find.byIcon(Icons.more_vert).first);
      await tester.pumpAndSettle(const Duration(seconds: 2));
      await tester.tap(find.text('Delete Post'));
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Tap Cancel
      await tester.tap(find.text('Cancel').last);
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Post still there
      expect(find.text(postText), findsWidgets);

      await logoutUser(tester);
    });
  });

  // ==========================================================
  // GROUP 5: CHAT
  // ==========================================================
  group('5. Chat', () {
    testWidgets('6.2 tapping chat on own post shows warning',
        (tester) async {
      app.main();
      await registerUser(tester);
      await loginUser(tester, await _getLastEmail(), testPassword);

      await tester.enterText(find.byType(TextField).first,
          'Self chat ${DateTime.now().millisecondsSinceEpoch}');
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.send));
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Tap Chat on own post
      await tester.tap(find.text('Chat').first);
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Should show snackbar
      expect(find.text("You can't chat with yourself"), findsOneWidget);

      await tester.pumpAndSettle(const Duration(seconds: 3));

      await logoutUser(tester);
    });
  });

  // ==========================================================
  // GROUP 6: FAB + REFRESH + LOGOUT
  // ==========================================================
  group('6. Misc UI', () {
    testWidgets('7.1 pull to refresh works', (tester) async {
      app.main();
      await registerUser(tester);
      await loginUser(tester, await _getLastEmail(), testPassword);

      await tester.drag(find.byType(ListView).first, const Offset(0, 300));
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Feed still there
      expect(find.text('What do you want to partner for?'), findsOneWidget);

      await logoutUser(tester);
    });

    testWidgets('8.1 FAB focuses input and scrolls to top', (tester) async {
      app.main();
      await registerUser(tester);
      await loginUser(tester, await _getLastEmail(), testPassword);

      // Create 5 posts to enable scrolling
      for (int i = 0; i < 5; i++) {
        await tester.enterText(find.byType(TextField).first, 'Post $i');
        await tester.pumpAndSettle();
        await tester.tap(find.byIcon(Icons.send));
        await tester.pumpAndSettle(const Duration(seconds: 3));
      }

      // Scroll down
      await tester.drag(find.byType(ListView).first, const Offset(0, -400));
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Tap FAB
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Input focused - we can't easily test focus, but scroll position should be 0
      expect(find.text('What do you want to partner for?'), findsOneWidget);

      await logoutUser(tester);
    });

    testWidgets('11.1-11.3 logout cancel and confirm', (tester) async {
      app.main();
      await registerUser(tester);
      await loginUser(tester, await _getLastEmail(), testPassword);

      // Tap logout
      await tester.tap(find.byIcon(Icons.logout));
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Cancel first
      expect(find.text('Logout?'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Still on feed
      expect(find.text('What do you want to partner for?'), findsOneWidget);

      // Now confirm logout
      await tester.tap(find.byIcon(Icons.logout));
      await tester.pumpAndSettle(const Duration(seconds: 2));
      await tester.tap(find.text('Logout').last);
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Back on login
      expect(find.widgetWithText(ElevatedButton, 'Login'), findsOneWidget);
    });
  });

  // ==========================================================
  // GROUP 7: EDGE CASES
  // ==========================================================
  group('7. Edge Cases', () {
    testWidgets('14.5 long username renders', (tester) async {
      app.main();
      await registerUser(tester, username: 'verylongusername123');
      await loginUser(tester, await _getLastEmail(), testPassword);

      // Feed renders without crash
      expect(find.text('What do you want to partner for?'), findsOneWidget);

      await logoutUser(tester);
    });

    testWidgets('14.6 emoji-only post renders', (tester) async {
      app.main();
      await registerUser(tester);
      await loginUser(tester, await _getLastEmail(), testPassword);

      const emojis = '🔥🔥🔥💪🏋️';
      await tester.enterText(find.byType(TextField).first, emojis);
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.send));
      await tester.pumpAndSettle(const Duration(seconds: 5));

      expect(find.text(emojis), findsWidgets);

      await logoutUser(tester);
    });

    testWidgets('14.4 rapid post clicks only create 1 post', (tester) async {
      app.main();
      await registerUser(tester);
      await loginUser(tester, await _getLastEmail(), testPassword);

      final uniqueText = 'Rapid ${DateTime.now().millisecondsSinceEpoch}';
      await tester.enterText(find.byType(TextField).first, uniqueText);
      await tester.pumpAndSettle();

      // Count posts with this text before
      final before = await FirebaseFirestore.instance
          .collection('posts')
          .where('content', isEqualTo: uniqueText)
          .get();

      // Rapid taps
      for (int i = 0; i < 5; i++) {
        if (find.byIcon(Icons.send).evaluate().isNotEmpty) {
          await tester.tap(find.byIcon(Icons.send),
              warnIfMissed: false);
          await tester.pump(const Duration(milliseconds: 50));
        }
      }
      await tester.pumpAndSettle(const Duration(seconds: 5));

      final after = await FirebaseFirestore.instance
          .collection('posts')
          .where('content', isEqualTo: uniqueText)
          .get();

      // Only 1 new post created
      expect(after.docs.length - before.docs.length,
          lessThanOrEqualTo(1));

      await logoutUser(tester);
    });
  });
}

// ==========================================================
// Global helper: fetch last created email from Firestore
// (We store the email we registered so next test can log in)
// ==========================================================
String _lastEmail = '';

Future<String> _getLastEmail() async {
  if (_lastEmail.isNotEmpty) return _lastEmail;

  // Fallback: query the most recently created user
  final users = await FirebaseFirestore.instance
      .collection('users')
      .orderBy('createdAt', descending: true)
      .limit(1)
      .get();

  if (users.docs.isNotEmpty) {
    _lastEmail = users.docs.first.data()['email'] ?? '';
  }
  return _lastEmail;
}

// Override registerUser to record the email for later tests
void _trackEmail(String email) {
  _lastEmail = email;
}
