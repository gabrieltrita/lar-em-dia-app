import 'package:go_router/go_router.dart';
import 'package:lar_em_dia/features/home/presentation/home_page.dart';

abstract final class AppRoutes {
  static const home = '/';
}

GoRouter buildRouter() => GoRouter(
  initialLocation: AppRoutes.home,
  routes: [
    GoRoute(
      path: AppRoutes.home,
      builder: (context, state) => const HomePage(),
    ),
  ],
);
