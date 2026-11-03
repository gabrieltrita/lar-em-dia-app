# lar-em-dia-app

## Non-negotiable rules

1. **Never write comments** in Dart, YAML, ARB, shell or workflow files. Names, small widgets and functions, and tests carry the intent. Explanations belong in `README.md`, commit messages or PR descriptions.
2. **Everything in English**: code, identifiers, tests, commit messages, branch names, PR titles and descriptions. User-facing copy lives in `lib/l10n/app_pt.arb` (pt-BR). Only the chat with the user is in Portuguese.
3. **Errors are handled by `ApiError.code`**, never by message text. The codes come from the API's `docs/openapi.yaml` (lar-em-dia-api).
4. **Keep the checks green**: `dart format --set-exit-if-changed lib test`, `flutter analyze` (very_good_analysis, no issues), `flutter test --coverage` and `tool/check_core_coverage.sh` (100% lines in `lib/core`). Every feature ships with tests for its blocs/cubits (`bloc_test`), repositories and pages.
5. Branch from `dev` and open every PR against `dev`; never against `main`. `main` only receives `dev` through a `release/YYYY-MM-DD` branch when the owner promotes it. Never open a PR whose head is `dev`. Repo `gabrieltrita/lar-em-dia-app`, commits authored with `g.trita.f@gmail.com`.
6. **Plan before every change, then go file by file.** Before modifying, adding or removing any file, present the plan and wait for the owner's explicit approval: the files, the changes in each, why, alternatives in prose, and the recommended one. After approval, show each file's change and wait for approval before writing it. Test files covered by an approved plan can be written without a per-file preview. Read-only investigation needs no approval.
7. **Never merge pull requests** or enable auto-merge.

## What this is

Flutter front end (web, Android, iOS) for Lar em Dia, a family budgeting and cash-flow projection app. The backend is the Rails API `gabrieltrita/lar-em-dia-api`; its `.claude/CLAUDE.md` describes the domain (balances, entries, entry series, projection, what-if simulation, due-date alerts) and the delivery waves. The owner is learning Flutter and asked for the stack most used in the market, so prefer idiomatic, widely adopted patterns over clever ones.

## Architecture

- Clean Architecture per feature: `features/<feature>/{data,domain,presentation}`. Presentation depends on domain; data implements domain contracts; domain has no Flutter or Dio imports.
- State: Cubit for simple screens, Bloc when the flow is event-driven. States and events are `freezed` classes. Widgets read state with `BlocBuilder`/`BlocSelector` and never call repositories directly.
- DI: annotate with `@injectable`/`@lazySingleton`/`@LazySingleton(as: Contract)`; third-party objects go in `core/di/register_module.dart`. Run `dart run build_runner build -d` after changes.
- HTTP: only through `ApiClient` (`get/post/patch/delete` with a `decode` function). DTOs are `freezed` + `json_serializable` with snake_case keys (`@JsonKey(name: ...)` or `fieldRename`).
- Routing: routes and paths in `core/routing/app_router.dart` (`AppRoutes` constants).
- Money: amounts travel as decimal strings from the API and are formatted with `intl` (`NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$')`); never use `double` for money in domain logic.
- Tokens: access token in memory, refresh token in `flutter_secure_storage`. `AuthInterceptor` refreshes once on 401 through a separate Dio without interceptors (retrying through the intercepted Dio deadlocks the `QueuedInterceptor`).

## Gotchas

- Dart 3.13 syntax: constructors are declared with `new`/`factory` without repeating the class name, and private named parameters (`required this._field`) are allowed; `dart fix --apply` converts older code.
- Generated files are git-ignored; CI regenerates them. A missing `*.config.dart` or `*.freezed.dart` locally means `build_runner` has not run.
- Tests that call `configureDependencies()` share the global `getIt`; call it once per test file in `setUpAll`.
