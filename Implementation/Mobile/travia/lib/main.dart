import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_phoenix/flutter_phoenix.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:travia/Classes/ConversationDetail.dart';
import 'package:travia/Classes/message_class.dart';

import 'Auth/ForgotPassword.dart';
import 'Auth/SignInPage.dart';
import 'Auth/SignUpPage.dart';
import 'Auth/completeProfilePage.dart';
import 'Classes/Post.dart';
import 'MainFlow/ChatPage.dart';
import 'MainFlow/DMsPage.dart';
import 'MainFlow/ErrorPage.dart';
import 'MainFlow/HomePage.dart';
import 'MainFlow/MediaPickerScreen.dart';
import 'MainFlow/NotificationsPage.dart';
import 'MainFlow/PermissionsPage.dart';
import 'MainFlow/PostDetails.dart';
import 'MainFlow/SplashScreen.dart';
import 'MainFlow/UploadPost.dart';
import 'RecorderService/Recorder.dart';
import 'Services/NotificationService.dart';
import 'firebase_options.dart';

final supabase = Supabase.instance.client;
SharedPreferences? prefs;
late Box messagesBox;
late Box postsBox;
late Box conversationDetailsBox;

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://cqcsgwlskhuylgbqegnz.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImNxY3Nnd2xza2h1eWxnYnFlZ256Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3MzkwMjE0MTMsImV4cCI6MjA1NDU5NzQxM30.j-sQL5Ez7hOt9YbwevWe77ac8w0Y9eJ-4vIb7n6YqGc',
    realtimeClientOptions: const RealtimeClientOptions(
      logLevel: RealtimeLogLevel.info,
    ),
  );

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  await Hive.initFlutter();
  Hive.registerAdapter(MessageClassAdapter());
  Hive.registerAdapter(PostAdapter());
  Hive.registerAdapter(ConversationDetailAdapter());

  messagesBox = await Hive.openBox<MessageClass>('messages');
  postsBox = await Hive.openBox<List>('posts');
  conversationDetailsBox = await Hive.openBox<List>("conversation_details");

  prefs = await SharedPreferences.getInstance();

  NotificationService.init();

  List<String>? clickAction = await _getInitialRoute();
  // 0 is the type, 1 is the source id (USED FOR NOTIFICATIONS)

  FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
    _navigateToRoute(message);
  });

  runApp(Phoenix(
      child: ProviderScope(
          child: Directionality(
              textDirection: TextDirection.ltr,
              child: MyApp(
                type: clickAction != null ? clickAction[0] : null,
                source_id: clickAction != null ? clickAction[1] : null,
              )))));
}

Future<List<String>?> _getInitialRoute() async {
  final message = await FirebaseMessaging.instance.getInitialMessage();
  if (message != null) {
    return _handleMessage(message);
  }
  return null;
}

List<String> _handleMessage(RemoteMessage message) {
  final data = message.data;
  final type = data['type'];
  final sourceId = data['source_id'];
  print("MESSAGE DATA IN HANDLE MESSAGE: $data");
  print("TYPE: $type");
  print("SOURCE ID: $sourceId");
  return [type, sourceId];
}

void _navigateToRoute(RemoteMessage message) {
  final context = navigatorKey.currentContext;
  if (context != null) {
    final route = _handleMessage(message);
    String type = route[0];
    String source_id = route[1];
    print("ROUTE: $route");
    if (type == "comment" || type == "post" || type == "like") {
      context.push("/post/$source_id");
    } else if (type == "message") {
      context.push("/messages/$source_id");
    }
  }
}

class MyApp extends StatelessWidget {
  final String? type;
  final String? source_id;
  const MyApp({super.key, this.type, this.source_id});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    print(user?.uid);
    print(user?.email);
    print(user?.photoURL);
    print(user?.displayName);
    print("------------");
    String initialLocation = "/splash-screen";
    if (type != null && source_id != null) {
      initialLocation = "/splash-screen/${Uri.encodeComponent(type ?? "")}/${Uri.encodeComponent(source_id ?? "")}";
    }

    final GoRouter router = GoRouter(
        initialLocation: initialLocation,
        //initialLocation: "/messages/dd8d9cc6-66c4-4e32-ad80-865aa7fe3113",
        //initialLocation: '/recorder',
        //initialLocation: '/dms-page',
        routes: [
          // ====================== AUTH ROUTES ======================
          GoRoute(
            path: '/signin',
            builder: (context, state) => SignInPage(),
          ),
          GoRoute(
            path: '/signup',
            builder: (context, state) => SignUpPage(),
          ),
          GoRoute(
            path: '/forgotpassword',
            builder: (context, state) => ForgotPassword(),
          ),
          // ====================== MAIN FLOW ROUTES ======================
          GoRoute(
            path: '/home',
            builder: (context, state) => HomePage(),
          ),
          GoRoute(
            path: '/complete-profile',
            builder: (context, state) => CompleteProfilePage(),
          ),
          GoRoute(
            path: '/notifications',
            builder: (context, state) => NotificationsPage(),
          ),
          GoRoute(
            path: '/permissions',
            builder: (context, state) => PermissionPage(),
          ),
          GoRoute(
            path: '/media-picker',
            builder: (context, state) => MediaPickerScreen(),
          ),
          GoRoute(
            path: '/error-page/:error/:path',
            builder: (context, state) {
              final error = state.pathParameters['error']!;
              final path = state.pathParameters['path']!;
              return ErrorPage(
                error: error,
                path: path,
              );
            },
          ),
          GoRoute(
            path: '/splash-screen',
            builder: (context, state) => SplashScreen(),
          ),
          GoRoute(
            path: '/splash-screen/:type/:source_id',
            builder: (context, state) {
              final type = state.pathParameters['type'];
              final source_id = state.pathParameters['source_id'];
              return SplashScreen(
                type: type,
                source_id: source_id,
              );
            },
          ),
          GoRoute(
            path: '/home/:type/:source_id',
            builder: (context, state) {
              final type = state.pathParameters['type'];
              final source_id = state.pathParameters['source_id'];
              return HomePage(
                type: type,
                source_id: source_id,
              );
            },
          ),
          GoRoute(
            path: '/post/:postId',
            builder: (context, state) {
              final postId = state.pathParameters['postId']!;
              return PostDetailsPage(postId: postId);
            },
          ),
          GoRoute(
            path: '/upload-post',
            builder: (context, state) => UploadPostPage(),
          ),
          GoRoute(
            path: '/dms-page',
            builder: (context, state) => DMsPage(),
          ),
          GoRoute(
            path: '/messages/:conversationId',
            builder: (context, state) {
              final conversationId = state.pathParameters['conversationId']!;
              return ChatPage(conversationId: conversationId);
            },
          ),
          GoRoute(
            path: '/recorder',
            builder: (context, state) => RecorderPage(),
          ),
        ],
        navigatorKey: navigatorKey);

    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.light().copyWith(
        scaffoldBackgroundColor: Colors.white,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          elevation: 0,
          iconTheme: IconThemeData(color: Colors.black),
        ),
      ),
      title: 'Travia App',
      routerConfig: router,
    );
  }
}
