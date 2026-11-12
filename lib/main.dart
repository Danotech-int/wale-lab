import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'firebase_options.dart';
import 'services/api_service.dart';
import 'services/api_program_service.dart';
import 'services/auth_service.dart';
import 'services/auth_backend.dart';
import 'services/firebase_auth_backend.dart';
import 'services/mock_api.dart';
import 'services/mock_recruitment_store.dart';
import 'services/mock_program_service.dart';
import 'services/program_repository.dart';
import 'services/storage_service.dart';
import 'state/program_store.dart';
import 'utils/app_router.dart';
import 'utils/constants.dart';
import 'utils/themes.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!AppConstants.useMock) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }

  final preferences = await SharedPreferences.getInstance();

  runApp(
    AppConstants.useMock
        ? ExcelerateApp(
            preferences: preferences,
            apiBaseUrl: MockApi.baseUrl,
            apiClient: MockApi(
              recruitmentStore: MockRecruitmentStore(preferences),
            ).client,
          )
        : ExcelerateApp(
            preferences: preferences,
            authBackend: FirebaseAuthBackend(
              auth: FirebaseAuth.instance,
              firestore: FirebaseFirestore.instance,
            ),
            tokenProvider: () async =>
                FirebaseAuth.instance.currentUser?.getIdToken(),
          ),
  );
}

class ExcelerateApp extends StatelessWidget {
  const ExcelerateApp({
    super.key,
    required this.preferences,
    this.apiBaseUrl = AppConstants.apiBaseUrl,
    this.apiClient,
    this.programService,
    this.authBackend,
    this.tokenProvider,
  });

  final SharedPreferences preferences;
  final String apiBaseUrl;
  final http.Client? apiClient;
  final ProgramService? programService;
  final AuthBackend? authBackend;
  final Future<String?> Function()? tokenProvider;

  @override
  Widget build(BuildContext context) => MultiProvider(
        providers: [
          Provider<StorageService>(
            create: (_) => StorageService(preferences),
          ),
          Provider<ApiService>(
            create: (_) => ApiService(
              baseUrl: apiBaseUrl,
              client: apiClient,
              tokenProvider: tokenProvider,
            ),
            dispose: (_, api) => api.dispose(),
          ),
          Provider<ProgramService>(
            create: (context) =>
                programService ??
                (apiBaseUrl == MockApi.baseUrl
                    ? MockProgramService(context.read<ApiService>())
                    : ApiProgramService(context.read<ApiService>())),
          ),
          Provider<ProgramRepository>(
            create: (context) =>
                ServiceProgramRepository(context.read<ProgramService>()),
          ),
          ChangeNotifierProvider<ProgramStore>(
            create: (context) =>
                ProgramStore(context.read<ProgramRepository>()),
          ),
          ChangeNotifierProvider<AuthService>(
            create: (context) {
              final auth = AuthService(
                context.read<ApiService>(),
                context.read<StorageService>(),
                backend: authBackend,
              );
              unawaited(auth.restoreSession());
              return auth;
            },
          ),
        ],
        child: MaterialApp(
          title: AppConstants.name,
          debugShowCheckedModeBanner: false,
          theme: AppThemes.light,
          initialRoute: AppRoutes.home,
          onGenerateRoute: AppRouter.generate,
        ),
      );
}
