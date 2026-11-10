# Opportunity and application demo

Run with:

```sh
flutter run -d web-server --web-port=7357 --dart-define=USE_MOCK=true
```

Open **http://localhost:7357** in your normal Chrome window. Keep using that
browser profile and URL: opportunities and applications are saved locally and
survive page refreshes and app relaunches. Signing out does not delete them.
Changing the hostname, port, browser profile, or clearing browser data opens a
different/empty local store. Flutter's `-d chrome` launcher normally uses a
temporary browser profile; the web-server command avoids losing that profile
between launches. Mock sessions still reset on reload, so sign in again.

Separate app instances using the same browser storage read the same recruitment
records. Different browsers/profiles and devices do not share data. Sign out
and switch roles in the same window for the simplest demo.

1. Sign in as `admin@example.com` / `admin123`.
2. Open **Post an opportunity**, enter the role, company, location and
   description, choose a future deadline, and press **Publish opportunity**.
   Publish a second role too; each is stored as a separate opportunity.
3. Sign out using the top-right icon.
4. Sign in as `member@example.com` / `member123`.
5. Open **Job opportunities**. **Open** shows every unexpired role, including
   those already applied to; **All** also includes closed roles. Apply to both
   roles. Each button changes independently to **Applied**.
6. Open **Your applications** to see both submitted applications and their count.
7. Sign out and sign back in as the admin. Open **Review applications** to see
   all applications grouped by opportunity, total applications, distinct
   applicant count, and each candidate's name, email and application reference.
8. Press **Shortlist candidate**. The candidate appears in **Candidate shortlist**.
9. Switch back to the member account and open **Your applications** to see
   **Shortlisted**. Dashboard application counts use these same records.

The recruitment lists reload every 15 seconds, when the app resumes, and when
the refresh controls are pressed. Changes from another instance appear on its
next refresh. Learners must
complete onboarding before applying. Each learner can apply once to a role,
application deadlines are enforced by the mock backend, and only admins can
publish opportunities, list all applications, or change application statuses.
Applications use the authenticated learner's identity; submitting an application
does not require a CV upload or additional form in this initial demo.

## HTTP contract

The screens use the existing authenticated `ApiService`. A future real backend
must implement these endpoints and enforce the same ownership and role rules:

| Method | Path | Behaviour |
| --- | --- | --- |
| POST | `/opportunities` | Admin publishes `{title, company, location, description, deadline}`; server assigns ID and timestamps. |
| GET | `/opportunities` | Returns a JSON array of roles with `id`, publication fields, and learner-specific `has_applied`. |
| POST | `/opportunities/:id/apply` | Learner submits `{}`; server derives candidate identity, status and timestamps and returns the application. |
| GET | `/applications/me` | Returns only the current learner's applications. |
| GET | `/applications` | Admin lists all applications; optional `?status=shortlisted` filter. |
| PUT | `/applications/:id` | Admin updates `{status}`; supported statuses are `submitted`, `reviewing`, `shortlisted`, and `rejected`. |

Application JSON contains `id`, `opportunity_id`, `opportunity_title`, `company`,
`learner_id`, `candidate_name`, `candidate_email`, `status`, and `created_at`.
Dates are ISO 8601 UTC. Invalid publication input returns 400, unauthenticated
requests 401, disallowed roles or incomplete onboarding 403, missing records
404, duplicate applications 409, and closed applications 410.

Recruitment persistence uses `MockRecruitmentStore` with separate preference
keys for each role/application. Requests reload stored records before reading
or writing; one write cannot replace the other roles or applicants. IDs are
unique across instances and one learner-role pair has one application record.

Mock authentication, newly created accounts and programme registrations remain
in memory. This demo does not implement shared Firebase storage, document
attachment to applications, or cross-device synchronisation.
