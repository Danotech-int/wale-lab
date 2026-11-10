# Program service contract

This is a logical application contract, expressed using REST-style operations.
These are **not promised production HTTP endpoints**. A Firebase adapter must
return the same Dart models and exceptions without changing program screens.
No Firebase backend, Auth, CV Storage, applications, interviews, or recruitment
workflows are implemented by this refactor.

## Inspection and existing flow

The baseline was run before refactoring: **97 tests passed** using
`flutter test --no-pub --concurrency=1 --reporter expanded`.

| Area | Existing implementation and change |
| --- | --- |
| Model | `lib/models/program.dart`: manual JSON serialization, string domain IDs, snake_case wire fields. Retained; empty/missing/invalid IDs now fail parsing. Numeric legacy IDs normalize to strings on reads only. |
| Repository | `lib/services/program_repository.dart`: list parsing, detail lookup, registration and coarse errors originally lived in `ApiProgramRepository`. The stable repository now delegates to `ProgramService`; the old constructor remains a compatibility adapter. |
| Transport | `lib/services/api_service.dart`: generic authenticated HTTP/JSON transport. Unchanged; program-specific parsing and error translation now live in `ApiProgramService`. |
| Fixtures | `assets/data/programs.json` contains eight programs; `lib/services/mock_data.dart::loadMockPrograms` loads that asset. No duplicate dataset was added. |
| Mock backend | `lib/services/mock_api.dart`: lazy raw catalogue cache, latency, current session and per-learner registration sets. Registration already persisted in memory before this refactor; it previously accepted duplicates. It now rejects duplicates atomically and returns backend-generated relationship metadata. |
| List | `lib/views/learner/programs_list.dart`: fetches once through the repository, filters locally, tracks pending registration IDs, displays skipped-record notices, loading/empty/error/manual-retry states. Refreshes after returning from details and retains the previous list if that refresh fails. |
| Detail route | `lib/utils/app_router.dart` and `ProgramDetailsLoader`: ID-only `/program-details/<encoded-id>` route; independently loads that ID through the repository. No JSON route arguments. |
| Detail registration | `lib/views/shared/program_details.dart` previously bypassed the repository with a direct HTTP POST. Now uses the same repository path as the list and handles typed duplicate errors. Layout unchanged. |
| Dashboard | Learner registered-program count previously fetched `/programs` and inspected `is_registered` in raw maps. It now counts typed `Program` objects through the repository. Other dashboard metrics retain their existing generic collection behavior. |
| Composition | `lib/main.dart` provides `ProgramService` and a service-backed repository. Mock mode skips Firebase initialization. Non-mock startup retains existing Firebase initialization and HTTP behavior. |

Raw program JSON boundaries remaining deliberately:

- `assets/data/programs.json`, `mock_data.dart` asset decoding, and `MockApi`'s
  loader/cache/list/detail/registration HTTP responses are fake backend wire data.
- `ApiService` returns generic transport JSON; `ApiProgramService` consumes it.
- `Program`, `ProgramRegistration`, and response models consume/produce JSON for
  serialization. Only these boundary layers use program maps.
- Tests use raw fixture/HTTP maps to exercise parsing, malformed records, transport
  failures and backend behavior (`program_test`, `program_repository_test`,
  `mock_api_test`, `programs_list_test`, `program_details_loader_test`,
  `program_routes_test`, `program_service_test`). Component tests pass typed models;
  dashboard integration tests verify the resulting counts.
- No program screen, route argument, card, or dashboard program metric consumes
  raw program JSON after this change. Generic JSON for other domains is unchanged.

## Dart boundary and swapping adapters

```dart
abstract interface class ProgramService {
  Future<ProgramListResponse> getPrograms({String? search, String? category});
  Future<ProgramDetailResponse> getProgramById(String id);
  Future<ProgramRegistrationResponse> registerForProgram(String id);
}
```

`ServiceProgramRepository` depends only on this interface. `MockProgramService`
reuses `ApiProgramService` against the **same MockApi-backed ApiService** used by
the app, so authentication, latency, fixtures and per-learner state remain shared.
It does not create another mock store. Each MockApi instance represents a separate
backend for authentication and programme registrations; keep one instance per app
session for these. That in-memory data resets on app restart. Recruitment records
(job opportunities/applications) are separately persisted locally by
`MockRecruitmentStore`; see `docs/OPPORTUNITIES_DEMO.md`.

`ExcelerateApp(programService: yourImplementation, ...)` injects a replacement.
The default uses `MockProgramService` with the mock API base URL, otherwise
`ApiProgramService`. `FirebaseProgramService` implements the contract but currently
throws safe, non-retryable `notConfigured` exceptions for all operations. It is not
enabled by default. Implement it before injecting it into a working app.

## Operations and response shapes

All examples below show serialized **typed service responses**. Dates are UTC
ISO 8601 strings. IDs and relationship references are strings. Read models and
their `toJson()` methods are not database write payloads.

### GET /programs

Logical request: `GET /programs?search=digital&category=course`.
Dart: `getPrograms(search: 'digital', category: 'course')`.

- Search trims whitespace, ignores case and matches a substring in title or
  description. Category is a trimmed, case-insensitive exact match.
- Both conditions must match. Null/blank parameters mean no constraint.
- Preserve source order. Unknown categories and no matches return an empty list.
- The HTTP/mock adapter retrieves the current complete catalogue and applies
  `ProgramQuery` locally; it does not require new HTTP query support. The list UI
  uses the same query helper over its loaded catalogue to preserve category chips.
- No pagination is currently supported. Future pagination requires an explicit
  contract update, rather than silently changing filtering over a partial list.

```json
{
  "items": [{
    "id": "prog-001",
    "title": "Digital Skills Bootcamp",
    "description": "Build digital skills.",
    "start_date": "2026-11-03T09:00:00.000Z",
    "end_date": null,
    "schedule": "Tuesdays and Thursdays",
    "eligibility": ["Completed onboarding"],
    "outcomes": ["Certificate"],
    "category": "course",
    "image_url": null,
    "is_registered": false
  }],
  "skipped": 0
}
```

Model: `ProgramListResponse` (`programs` in Dart, `items` in JSON). Invalid list
records are skipped and counted; a wrong outer shape is an `invalidData` error.
An entirely empty valid catalogue yields `items: []`, `skipped: 0`. Required record
fields are non-empty ID, string title/category and parseable `start_date`.
Optional fields retain existing defaults. Legacy numeric IDs are normalized only
for backward compatibility; new backend records must use string IDs.

### GET /programs/{id}

Logical request: `GET /programs/prog-001`.
Dart: `getProgramById('prog-001')`.

Response: `{"program": { ...the program record above... }}`.
Model: `ProgramDetailResponse`. The returned ID must match the requested ID.
A missing program gives `notFound`; an incomplete/mismatched record gives
`invalidData`. The caller does not have to load the list first.

### POST /programs/{id}/registrations

Logical request: `POST /programs/prog-001/registrations`, body `{}`.
Dart: `registerForProgram('prog-001')`.

```json
{
  "program": {
    "id": "prog-001",
    "title": "Digital Skills Bootcamp",
    "description": "Build digital skills.",
    "start_date": "2026-11-03T09:00:00.000Z",
    "end_date": null,
    "schedule": "Tuesdays and Thursdays",
    "eligibility": [],
    "outcomes": [],
    "category": "course",
    "image_url": null,
    "is_registered": true
  },
  "registration": {
    "id": "registration-123",
    "programId": "prog-001",
    "learnerId": "learner-456",
    "status": "registered",
    "registeredAt": "2026-10-23T12:00:00.000Z"
  }
}
```

Model: `ProgramRegistrationResponse` plus `ProgramRegistration`. The backend
authenticates the learner, checks permissions and program existence, atomically
enforces one active registration per learner/program pair, and returns a program
with `is_registered: true`. Duplicate requests (including concurrent requests)
produce `alreadyRegistered` (logical 409), without creating another registration.
Admins can preview programs but cannot register. Unknown IDs give `notFound`.

The client sends only the program ID. It never supplies learner identity, an
authoritative status, registration ID, timestamps, `createdAt` or `createdBy`.
The fake backend generates metadata to emulate this behavior; it is not a
production client write pattern. Failed requests do not optimistically enroll.
An `alreadyRegistered` UI response reconciles a stale card/detail to enrolled.

### Existing HTTP compatibility

`ApiProgramService` retains the current HTTP wire shapes: GET list is a **bare
array**, GET detail is a **flat program**, and POST uses
`/programs/{encoded-id}/register` with `{}` and a flat updated program. MockApi
also accepts `/registrations`. Mock registration adds a `registration` field to
that flat response. The adapter wraps these into the typed shapes above. Older
HTTP responses may omit relationship metadata; it remains null rather than being
fabricated. Canonical `Program*Response.fromJson` methods accept the wrapped
service shapes. Changing HTTP shapes requires changing only the adapter.

## Firebase-friendly data structure and ownership

| Document | Data and ownership |
| --- | --- |
| `programs/{programId}` | String document ID; program content fields from the record schema. Backend-provided `createdAt`/`createdBy` may exist but are outside this read model. |
| `program_registrations/{registrationId}` | String document ID, string `programId`, string `learnerId`, `status`, `registeredAt`. Enforce uniqueness of the active `(programId, learnerId)` relationship in a trusted operation. |

The adapter maps document IDs to the DTO `id`, converts Firestore Timestamp values
to UTC `DateTime`, and derives `isRegistered`/`is_registered` from the current
learner's active registration. Do not store a shared `is_registered` flag on a
program document. The fixture's seeded flag is mock-only compatibility data.
Read enum values are `registered` and `cancelled`; no cancellation operation is
implemented. Unknown statuses fail parsing, rather than granting enrollment.

A trusted registration operation must derive `learnerId` from authenticated
context and own status, document ID, and server timestamp assignment. Choose and
enforce document-ID uniqueness/transaction rules on the backend. Security rules
must enforce read scope and deny admin enrollment and cross-learner writes.
This document describes required behavior; it does not deploy collections,
indexes, security rules, or Cloud Functions.

## Errors and retry policy

Screens receive `ProgramException`, never raw HTTP/Firebase exceptions or private
backend messages. Existing `ProgramFailure` presentation categories remain
`notFound`, `invalidData`, `unavailable`; `ProgramErrorCode` carries finer reasons.

| Code | HTTP/current source | Future Firebase mapping | Retry guidance |
| --- | --- | --- | --- |
| `networkUnavailable` | `http.ClientException` | offline/unavailable network | Explicit user retry; automatic read retry may use bounded backoff |
| `timeout` | TimeoutException, 408, 504 | deadline-exceeded | Explicit user retry; read retry may use bounded backoff |
| `notFound` | 404 | not-found / missing snapshot | Do not automatically retry; return to list |
| `alreadyRegistered` | 409 | trusted duplicate result / already-exists | Do not retry; show existing enrollment |
| `permissionDenied` | 403 | permission-denied | Do not retry automatically; permissions must change |
| `unauthenticated` | 401 | unauthenticated | Sign in again; do not retry automatically |
| `invalidData` | malformed JSON/schema/mismatched ID, 400/422 | invalid backend data | Do not retry automatically; fix data or adapter |
| `unexpectedBackendFailure` | 5xx except 504, unexpected Exception | internal / other backend failure | Explicit user retry; bounded read retry only if appropriate |
| `notConfigured` | missing API URL / Firebase placeholder | unconfigured adapter | No retry; finish configuration/implementation |

`retryable` is true only for network, timeout and unexpected backend failures.
The current implementation has **no automatic retries**. Details offers Retry for
retryable failures; the list retains its existing explicit manual Retry control
even after malformed responses (to allow recovery after data repair). Dashboard
refresh/retry remains manual. No screen automatically retries a registration:
after an uncertain write, re-read status first; a deliberate second request must
be safe through backend duplicate enforcement.

## Validation and Firebase teammate handoff

Tests require neither a live Firebase project nor new credentials. Existing
repository, model, route, responsive layout, error/retry and dashboard tests remain
in place. `program_service_test.dart` adds response/relationship parsing, filtering,
empty results, ID lookup, persisted per-user registration, concurrent/duplicate
registration, safe error mapping, no automatic write retry, and adapter substitution.

To finish Firebase: implement the three methods in `FirebaseProgramService`, map
Firestore data/errors at that boundary, resolve learner identity through the team's
existing auth boundary, implement the trusted atomic registration operation and
security rules, and inject the adapter. Preserve the shared query semantics and
response validation. Configure/emulator-test Firebase separately; no screen
rewrite should be required. Production auth and other team workflows remain
outside this program-service change.

Final verification (2026-10-23):

- `dart format .` ran; formatting-only edits to unrelated files were reverted.
- `flutter analyze`: no issues found.
- `flutter test --concurrency=1 --reporter expanded`: **118 tests passed**
  (97 existing plus 21 new tests).
- `flutter build web --debug --dart-define=USE_MOCK=true`: succeeded.
- Mock learner/admin navigation and registration updates are exercised by widget
  tests; a replacement service is also tested through the actual screens.
- No new secrets or credentials were introduced. Existing Firebase configuration
  files and unrelated working-tree changes were left intact.
