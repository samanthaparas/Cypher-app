# Refactor & DRY Audit

> **Status:** living document. Tick items off as they ship.
> **Last audited:** 2026-10-04, against `main` at the time the shared components work began.
> **Scope:** iOS app (`c705/`), backend (`c705-backend/`), admin panel (`c705-admin/`), database (`c705_db/`), and repo documentation.

## Why this exists

This codebase was inherited, not started from scratch. Before building more on top of it, we audited it for repeated code (**DRY: Don't Repeat Yourself**) and structural problems. The goal is simple:

> **When we want to change something, we change it in one place, instead of hunting for every copy.**

Nothing in this document has been changed in code yet. It is a map and a plan.

## How the audit was done (and its limits)

- Findings come from repository-wide searches (`grep`, file sizes, counting patterns) plus reading the files named below.
- **Counts are real, but not every file was read line by line.** Some code that looks duplicated may differ in small, intentional ways. Each item should be re-checked.
- The admin panel was only skimmed.
- Nothing was compiled or run as part of the audit.
- The numbers below can be reproduced; see [Reproducing the numbers](#reproducing-the-numbers).

## Guiding principles

1. **Rule of Three.** Copying code once or twice is acceptable. When it appears a third time, extract it. Everything listed here has three or more copies.
2. **Don't over-abstract.** Two things that look alike but change for different reasons should stay separate. Forcing them together creates code that is harder to change, not easier.
3. **One concern per branch and PR.** Refactors are easy to review when they are small and do one thing.
4. **Look the same before and after.** A pure refactor should not change behavior. Build, run, and click through the affected screens every time.
5. **Name by role, not by value.** `Theme.accent`, not `Theme.blue`.

## Summary scorecard

| Area | Verdict |
|---|---|
| Folder structure (Models / ViewModels / Views / Services) | Good. Sensible MVVM layout. |
| UI duplication | High. The same pills, cards, search bars, empty states and alerts are pasted across many files. |
| Networking (`APIService.swift`) | Medium-high. A helper exists, but many functions bypass it. Upload code is copied. |
| ViewModels | Medium. Identical loading/error boilerplate in all ten. |
| Giant files | `ProfileView.swift` (2,012 lines), `APIService.swift` (1,218 lines). |
| Backend (NestJS) | Medium. Pagination, guards, and Prisma selects repeat. |
| Documentation | Messy. ~45 loose `.md` files with overlap and stale content. |
| Tests | Very thin on iOS; some backend specs exist. |

---

## Tier 1: UI duplication (iOS)

These directly support the design-system work (`Theme`, shared components).

### 1.1 Pill / chip buttons: **3 near-identical copies + 2 look-alikes**

- `SubTabButton` in `Views/TrendingView.swift`
- `SourceButton` in `Views/ArticlesView.swift`
- `CityChip` in `Views/CityView.swift`
- Look-alikes: `FilterChip` (`Views/BeatsHubView.swift`), `TabButton` (`Views/ProfileView.swift`)

All three main copies use the same font, padding, 20pt corner radius, and selected/unselected colors. Only the title text differs. Two of them still use `Color.blue` and `Color(.systemGray6)` instead of `Theme`.

**Fix:** one `PillButton` in `Views/PillButton.swift`, using `Theme` colors. Replace or wrap the copies.
**Effort:** small. **Risk:** low.

- [ ] `PillButton.swift` created
- [ ] `SubTabButton` migrated
- [ ] `SourceButton` migrated
- [ ] `CityChip` migrated
- [ ] `FilterChip` evaluated (may differ intentionally)
- [ ] Profile `TabButton` evaluated (it is an underline tab, not a pill)

### 1.2 Card look: **repeated in ~14 files**

The pattern "padding + background + rounded corners + shadow" is rebuilt by hand in `ArticlesView`, `ArtistsListView`, `CypherHubView`, `CypherVotingView`, `CypherEntryRowView`, `CreateCypherView`, `TopCypherCardView`, `BeatsHubView`, `FeedItemView`, `AudioPlayerView`, `RoleSelectionView`, and others. Many use `Color(.systemBackground)` with a black shadow, which disappears on a dark background.

**Fix:** a `ViewModifier` plus `.themeCard()` shortcut in `Views/CardStyle.swift` (padding, `Theme.card`, `Theme.cardRadius`, subtle `Theme.cardBorder` outline). This is the mockup's card.
**Effort:** small to create, medium to adopt everywhere. **Risk:** low.

- [ ] `CardStyle.swift` created
- [ ] `ArticleCardView` migrated (first adopter)
- [ ] Remaining card-like views migrated screen by screen

### 1.3 Search bar: **hand-built in 6 screens**

`FeedView`, `BeatsHubView`, `ArtistsListView`, `CypherHubView`, `UniversalSearchView`, and `ProfileView` (beats section) each build "magnifying glass + text field + rounded gray background" separately.

**Fix:** one `SearchField(placeholder:text:)` view.
**Effort:** small. **Risk:** low.

- [ ] `SearchField` created
- [ ] Six screens migrated

### 1.4 Empty states: **21 hand-built messages**

"No trending beats found," "No artists found," "No cypher invites yet," and so on are each a hand-built icon + text stack, with 30 hard-coded large `.font(.system(size: 4x-6x))` icons.

**Fix:** `EmptyStateView(systemImage:title:message:)`.
**Effort:** small. **Risk:** low.

- [ ] `EmptyStateView` created
- [ ] Screens migrated

### 1.5 Loading spinners: **36 `ProgressView` uses**

Many are `ProgressView("Loading ...")` with slightly different padding. Fold into the same family of state components as 1.4 (`LoadingView`).

- [ ] `LoadingView` created and adopted

### 1.6 Error alert: **same `.alert("Error", ...)` block pasted 12 times**

**Fix:** a single `.errorAlert(message:retry:)` view modifier.

- [ ] `.errorAlert` created and adopted

### 1.7 Hard-coded colors: **~480 usages**

`Color(.gray)` (116), `Color(.blue)` (65), `Color.blue` (55), `.black` (~100 combined), `Color(.systemGray6)`, `Color(.systemBackground)`, and so on. `Theme.swift` now exists, but only the tab bar, Home chrome, and Trending pills use it.

**Fix:** adopt `Theme` screen by screen as each is touched. Do not attempt a single giant find-and-replace.

- [x] `Theme.swift` created
- [x] Tab bar
- [x] Home screen chrome (`FeedView`, `TrendingView` pills)
- [ ] Articles, Events, City
- [ ] Beats, Arena (Cypher Hub), Discover (Search), Profile
- [ ] Login and onboarding screens
- [ ] Sheets (Settings, Upload Beat, Create Cypher, ...)

### 1.8 `.environmentObject(authService)` re-passed **17 times**

The app root already provides `authService` through the environment; many views re-inject it by hand, and many views also re-declare it as an `@EnvironmentObject` only to forward it.

**Fix:** remove redundant forwarding after confirming each one (sheets and `NavigationLink` destinations are the places where it can still matter).
**Risk:** low-medium. A missing injection crashes at runtime, so test each screen.

- [ ] Audit each of the 17 sites

### 1.9 Date formatters created ad hoc in **8 files**

`DateFormatter()` / `ISO8601DateFormatter()` are created in `APIService`, `AnalyticsService` (5), `ArticlesView` (2), `ArtistProfileView` (2), `CommentsView`, `CypherHubView`, `FeedItemView` (3), and `ProfileView`. Formatters are relatively expensive to create and the formats should be consistent.

**Fix:** a small shared `DateFormatting` helper (static formatters and a "time ago" helper).

- [ ] Helper created and adopted

### 1.10 `ProfileView.swift` is **2,012 lines** and holds ~40 structs

Settings screens, sheets, rows, permission pickers, and the profile itself all live in one file. It is hard to navigate and a likely source of merge conflicts.

**Fix:** split into a `Views/Profile/` folder, one file per screen. Move only; do not change behavior in the same PR.
**Effort:** medium. **Risk:** low if it is a pure move.

- [ ] Plan the split (profile header, beats section, cyphers section, settings screens, sheets)
- [ ] Execute the split

### 1.11 Look-alike models

- `Beat` (Models) vs `ProfileBeat` (in `ProfileView.swift`)
- `Article` (Models) vs `ArticleItem` (in `ArticlesView.swift`) vs `NewsArticle` (Models)

These may be legitimate view-specific shapes or accidental copies. Investigate whether they can share a model or be created by a mapping function.

- [ ] Investigate and decide

---

## Tier 2: Networking and data (iOS)

Higher value, higher risk. Do after the UI work, and add tests as we go.

### 2.1 `Services/APIService.swift`: **1,218 lines, 54 functions**

- A helper `createRequest(endpoint:method:body:)` already exists (sets method, JSON header, 30s timeout, auth token) but **13 functions build `URLRequest` by hand** instead (for example `reportCypherEntry`, `inviteArtistToCypher`, `respondToCypherInvite`, `createCypher`, `purchaseBeat`, `reportBeat`, `subscribe`, `cancelSubscription`, `requestPayout`).
- The `Authorization: Bearer` header is written out by hand **15 times**.
- **Multipart file-upload code is copied 4 times** (`uploadTrack`, `submitCypherEntry`, `createCypher`, `uploadBeat`): boundary generation, form-field writing, and `Content-Disposition` lines.
- 13 `JSONEncoder()` instances and 1 `JSONDecoder()`; configuration is not shared.
- 56 `print(...)` calls.

**Fix:**
1. Make `createRequest` the only way requests are built (accept an `Encodable` body).
2. A `MultipartFormData` builder used by all upload functions.
3. One shared encoder/decoder with agreed date strategies.
4. Split the file into feature extensions (`APIService+Auth.swift`, `+Cyphers.swift`, `+Beats.swift`, `+Subscriptions.swift`, ...).

**Risk:** high (this is the app's connection to everything). Do it in small steps, and verify login, upload, purchase, and cypher flows after each.

- [ ] Single request builder
- [ ] `MultipartFormData` builder
- [ ] Shared encoder/decoder
- [ ] Split into feature files

### 2.2 Backend address logic is scattered

`APIService` chooses the base URL (custom, production override, then default). `AuthService` and `ConnectionTestService` re-derive whether the app is talking to localhost / plain HTTP themselves.

**Fix:** one `AppConfig` (or `Environment`) type that owns the base URL and answers "is this a local/HTTP connection?" for everyone.

- [ ] `AppConfig` created and adopted

### 2.3 Stale text in `ConnectionTestView`

`Views/ConnectionTestView.swift` tells the user the default backend is a bare IP address over `http://`, but `APIService` actually defaults to `https://api.c705.online`. The text is stale, and it puts a server IP address in a public repo.

- [ ] Replace with a value read from `AppConfig`, and remove the hard-coded IP

### 2.4 ViewModel boilerplate: **all 10 ViewModels**

Every ViewModel declares `isLoading` and `errorMessage` and repeats `do { ... } catch { errorMessage = error.localizedDescription }` (27 near-identical catch blocks).

**Fix:** a small shared helper (for example a `perform { ... }` function or a tiny base type) that handles loading flag + error capture in one place.

- [ ] Helper created
- [ ] ViewModels migrated one at a time

### 2.5 `print(...)` used as logging: **~150 calls**

Concentrated in `APIService` (56), `AuthService` (52), `LoginView` (11), `IAPManager` (5).

**Fix:** Apple's `Logger` (`os.Logger`) with categories and levels, and make sure no tokens, receipts, or personal data are ever logged.

- [ ] Logger wrapper created
- [ ] `APIService` and `AuthService` migrated
- [ ] Remaining files

---

## Tier 3: Backend (NestJS) and admin (Next.js)

### 3.1 Pagination math repeated in **8 services**

`skip` / `take` / `Math.ceil(total / limit)` appears in `tracks`, `articles`, `artists`, `cyphers`, `beats`, `feed`, `admin`, and `comments` services.

**Fix:** a `paginate()` helper and a shared pagination DTO.

- [ ] Helper created and adopted

### 3.2 `@UseGuards(JwtAuthGuard)` on **28 individual methods**

**Fix:** apply the guard at class level (or globally) and mark the few public routes with a `@Public()` decorator. This also removes the risk of forgetting a guard on a new route.

- [ ] Plan and migrate

### 3.3 Same Prisma `select` blocks (~21 uses of `username: true`, 69 `select:` blocks)

**Fix:** shared constants such as `userPublicSelect`.

- [ ] Constants created and adopted

### 3.4 Role checks repeated (11)

**Fix:** a `RolesGuard` plus a `@Roles(...)` decorator.

- [ ] Create and migrate

### 3.5 Example code shipped in `src`

`src/auth/examples/example-usage.controller.ts` (10 guard usages) looks like sample code, not product code.

- [ ] Confirm it is unused and remove

### 3.6 Admin panel (`c705-admin`)

Eight dashboard pages (users, articles, journalists, cyphers, events, reports, settings, overview) probably repeat the same fetch / loading / table pattern. Not yet verified.

- [ ] Audit the dashboard pages

---

## Tier 4: Dead code, stale docs, repo hygiene

### 4.1 Likely-unused code (verify each before deleting)

| Item | Evidence |
|---|---|
| `Models/Item.swift` and `Views/ContentView.swift` | Leftover Xcode SwiftData template (`ARCHITECTURE.md` itself calls them "legacy ... can be removed") |
| `ArtistsView` in `MainTabView.swift` | No call sites found outside its own definition |
| `TopCypherCardView` / `TopCypherRowView` | No call sites found for `TopCypherCardView(` outside its file |

- [ ] Verify and remove

### 4.2 Documentation sprawl: **~45 loose `.md` files**

- 19 in the repo root, 13 beside the iOS code, 11 in `c705-backend/`, and 2 in `c705-admin/`.
- Overlapping topics: 4 about login errors (`LOGIN_ERROR_*`, `DEBUG_LOGIN_ISSUE`, `LOGIN_FIX_VERIFICATION`), 3 about ngrok, 2 about the news API, several about connection setup, plus Apple Sign-In and OAuth notes.
- Several are status notes (`*_COMPLETE`, `*_APPLIED`, `*_VERIFICATION`) that git history already records.
- At least one is stale: `c705/c705/ARCHITECTURE.md` says the auth token is stored in `UserDefaults`, but the code uses the Keychain.

**Fix:** a `docs/` folder with one living document per topic (setup, authentication, backend connection / ngrok, news API, architecture), and delete the status notes.

- [ ] Plan the consolidation (which doc replaces which)
- [ ] Execute and remove duplicates
- [ ] Refresh `ARCHITECTURE.md`

### 4.3 Tests

- iOS: the test targets are the Xcode template stubs (about 91 lines total).
- Backend: 8 `*.spec.ts` files and one e2e folder.

Refactoring without tests is riskier. Plan a small set of tests (see the README roadmap), especially around `APIService` and authentication, before the Tier 2 work.

- [ ] Add tests before refactoring the networking layer

---

## Suggested order of work

Each line is its own branch and PR. Safest first.

1. **`feature/shared-components`**: `PillButton` and `CardStyle` (approved)
2. **`feature/state-components`**: `EmptyStateView`, `LoadingView`, `SearchField`, `.errorAlert`
3. **Theme adoption sweep**, screen by screen (one PR per screen or small group)
4. **Split `ProfileView.swift`** into `Views/Profile/`
5. **Tests for networking and auth**
6. **Networking refactor**: `AppConfig`, request builder, multipart builder, shared coders, split `APIService`
7. **ViewModel boilerplate and `Logger`**
8. **Backend helpers**: pagination, guards, shared selects, roles
9. **Dead code removal and documentation consolidation**

## Reproducing the numbers

Run from the repository root.

```bash
# Biggest Swift files
find c705/c705 -name "*.swift" -exec wc -l {} + | sort -rn | head -25

# Hard-coded colors in Views
grep -rn "Color(\.\|Color\.\|\.foregroundColor\|systemGray\|systemBackground" --include=*.swift c705/c705/Views | wc -l

# Pill-like copies
grep -rn "struct SubTabButton\|struct SourceButton\|struct CityChip\|struct FilterChip" --include=*.swift c705/c705

# Hand-built URLRequests in APIService (vs the createRequest helper)
grep -n "URLRequest(url" c705/c705/Services/APIService.swift

# Redundant environment forwarding
grep -rn "\.environmentObject(authService)" --include=*.swift c705/c705/Views | wc -l

# print() used as logging
grep -rc "print(" --include=*.swift c705/c705 | grep -v ":0" | sort -t: -k2 -rn | head

# Backend: guards on individual methods
grep -rn "@UseGuards(JwtAuthGuard)" c705-backend/src --include=*.ts | wc -l

# Loose docs
ls *.md c705/c705/*.md | wc -l
```

## Related documents

- [`README.md`](../README.md): project overview, strengths, concerns and roadmap
- [`docs/design/README.md`](design/README.md): the target look and component list
