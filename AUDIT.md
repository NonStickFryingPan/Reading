# AUDIT.md — Reading App Code Audit

**Date:** 2026-05-29
**Scope:** All 14 files in `reading/lib/`
**Auditors:** 3 parallel agents (error handling, architecture/coupling, security/quality) + manual review

---

## Summary

| Severity | Pass 1 | Pass 2 | Combined | Status |
|----------|--------|--------|----------|--------|
| CRITICAL | 6 | 1 | 7 | Must fix before first run |
| HIGH | 7 | 5 | 12 | Must fix before release |
| MEDIUM | 9 | 5 | 14 | Should fix, tech debt |
| LOW | 6 | 11 | 17 | Nice to have |
| **Total** | **28** | **22** | **50** | |

---

## CRITICAL

### C1. Storage layer has zero error handling
**Files:** `storage_service.dart:18-65`, `main.dart:12`
**Issue:** Every `Hive.openBox()`, `jsonDecode()`, and `rootBundle.loadString()` call can throw. None are wrapped in try/catch. If Hive storage is corrupted (partial write, power loss), the app is dead on arrival with no recovery.
**Impact:** App crashes immediately on launch. No error UI, no fallback.
**Fix:** Wrap all storage operations in try/catch. Return defaults (empty lists) on failure. Add a "reset storage" escape hatch.

### C2. FeedProvider.init() has no error boundary
**File:** `feed_provider.dart:54-61`
**Issue:** `init()` calls storage, then `refreshAll()`. If either throws, `_initialized` stays `false` forever. User sees a permanent loading spinner with no way to recover.
**Impact:** App stuck on loading screen, no retry mechanism.
**Fix:** Wrap init in try/catch. Set `_initialized = true` even on partial failure. Show loaded data with error banner for failed sources.

### C3. WebView executes arbitrary JavaScript
**File:** `article_screen.dart:27`
**Issue:** `JavaScriptMode.unrestricted` enables arbitrary JS execution. A malicious article page could exploit WebView APIs, perform phishing, or exfiltrate data.
**Impact:** Security vulnerability on every article load.
**Fix:** Use `JavaScriptMode.disabled` unless JS is explicitly needed. If JS is needed, allowlist schemes (http/https only) and block non-article navigation.

### C4. No URL scheme validation before WebView load
**File:** `article_screen.dart:41`
**Issue:** `Uri.parse(widget.url)` is called without validating the scheme. A `javascript:`, `data:`, or `file:` URL from an RSS feed could lead to local file access or script injection.
**Impact:** Potential code injection via crafted RSS entries.
**Fix:** Validate `widget.url.startsWith('http')` before loading. Reject or sanitize at the boundary.

### C5. FeedProvider mutates model internals directly
**File:** `feed_provider.dart:118, 149, 165-166`
**Issue:** Provider directly mutates `feed.enabled` and `feed.order` on `FeedSource` objects. This is pass-by-reference mutation — the provider manipulates model internals, bypassing encapsulation.
**Impact:** State changes untraceable. Any change to `FeedSource` fields silently breaks provider logic.
**Fix:** Make `FeedSource` fields final. Use `copyWith()` pattern. Manage enabled/order state in the provider, not on the model.

### C6. FeedProvider is a God Object
**File:** `feed_provider.dart` (entire file, 193 lines)
**Issue:** Manages 7+ concerns: feed CRUD, article fetching, bookmark management, dark mode toggle, UI expansion state, loading state, URL parsing, feed validation.
**Impact:** Unmaintainable, untestable, any change risks breaking unrelated features.
**Fix:** Split into `FeedManager`, `BookmarkManager`, `AppSettings`. Move UI state (`_expanded`, `_loading`) into widgets.

---

## HIGH

### H1. Storage writes are fire-and-forget
**File:** `feed_provider.dart:104, 123, 160, 169, 184, 190`
**Issue:** `_storage.saveFeeds()` and `_storage.saveBookmarks()` are called without `await`. If the app is killed before the write completes, state is lost.
**Impact:** User thinks bookmarks/saves persisted but they're gone on restart.
**Fix:** `await` storage writes, or use a write-ahead approach with dirty flags.

### H2. Uri.parse with no validation
**File:** `feed_provider.dart:88-91`
**Issue:** `Uri.parse(url)` throws `FormatException` on malformed URLs. `name[0].toUpperCase()` throws `RangeError` if hostname is empty.
**Impact:** Adding a custom feed with a bad URL crashes the settings screen.
**Fix:** Use `Uri.tryParse()`, validate scheme is http/https, validate host is non-empty.

### H3. ArticleScreen has no error state
**File:** `article_screen.dart` (entire file)
**Issue:** No `onWebResourceError` handler. WebView load failures (DNS error, SSL error, no internet) show a blank white screen with a stuck progress indicator.
**Impact:** User sees blank screen, no way to retry or know what happened.
**Fix:** Add error handler to NavigationDelegate. Show error state with retry button.

### H4. Future.wait in refreshAll() is fragile
**File:** `feed_provider.dart:63-78`
**Issue:** If any single `_rss.fetchAny` throws (currently safe due to internal catch, but the pattern is brittle), `Future.wait` rejects immediately and all other results are lost.
**Impact:** One bad feed could kill all feed loading.
**Fix:** Use `Future.wait` with individual try/catch per feed, or use `Future.forEach`.

### H5. No abstractions for services
**File:** `feed_provider.dart:8-9`, `main.dart:11-12`
**Issue:** `FeedProvider` depends on concrete `StorageService` and `RssService`. No interfaces exist. Testing requires modifying production code.
**Impact:** Untestable, impossible to swap implementations.
**Fix:** Define abstract classes (`StorageRepository`, `FeedFetcher`). Inject abstractions.

### H6. Silent error swallowing everywhere
**File:** `rss_service.dart:21-23, 39-41, 62, 69, 72-73, 114, 122`
**Issue:** Every `catch (_) { return []; }` discards the exception entirely. Network errors, parse errors, and malicious payloads all silently return empty lists.
**Impact:** Impossible to debug. User sees "No articles available" with zero diagnostic info.
**Fix:** At minimum, `debugPrint` the error. Consider returning `Either<Error, List<Article>>` so callers can distinguish "no articles" from "fetch failed."

### H7. User-supplied URL not strictly validated
**File:** `settings_screen.dart:167-168` → `feed_provider.dart:88-101`
**Issue:** The "Add Feed" dialog only checks `url.isEmpty`. A malformed or malicious URL propagates into the feed list and later into the WebView.
**Impact:** Malicious feed URL could lead to script injection via WebView.
**Fix:** Validate URL with `Uri.tryParse`, check scheme is http/https, check host is non-empty.

---

## MEDIUM

### M1. Duplicated HTTP fetch pattern
**File:** `rss_service.dart:8-24, 26-42, 44-75`
**Issue:** `fetchFeed`, `fetchAtomFeed`, and `fetchAny` repeat the same HTTP GET → status check → body parse → timeout pattern (~60 lines of near-identical code).
**Fix:** Extract `_fetchRaw(String url)` that returns the response body.

### M2. Duplicated empty-state UI
**Files:** `home_screen.dart:70-92`, `bookmarks_screen.dart:22-49`
**Issue:** Both screens duplicate the same empty-state pattern (~20 lines each).
**Fix:** Extract an `EmptyState` widget with `icon`, `title`, `subtitle` parameters.

### M3. Magic numbers throughout
**Files:** Multiple
**Issue:**
- `rss_service.dart:6` — `Duration(seconds: 10)` timeout
- `rss_service.dart:78, 90` — `.take(30)` article limit
- `feed_section.dart:33, 35` — `10` default display count
- `feed_provider.dart:93` — `'/favicon.ico'` path
**Fix:** Extract all to named constants.

### M4. Non-functional "Open in Browser" button
**File:** `article_screen.dart:55-61`
**Issue:** `IconButton` with `Icons.open_in_browser` has an empty `onPressed`. Users can tap it but nothing happens — dead UI.
**Fix:** Implement with `url_launcher` or remove the button.

### M5. reorderFeeds mutates getter result
**File:** `feed_provider.dart:140-161`
**Issue:** `enabledFeeds` returns a new filtered+sorted list each call. `enabled.removeAt(oldIndex)` mutates this temporary list, then syncs back by name lookup. If two feeds share a name (custom feeds), this breaks silently.
**Fix:** Work directly on `_feeds` with proper index mapping.

### M6. refreshAll() calls enabledFeeds getter twice
**File:** `feed_provider.dart:63-78`
**Issue:** `enabledFeeds` called on line 64 (loading states) and line 69 (fetch futures). Each call creates a new list. If feeds change between calls, behavior is inconsistent.
**Fix:** Cache `final feeds = enabledFeeds;` locally.

### M7. Dialog has 7+ side effects in one callback
**File:** `settings_screen.dart:144-217`
**Issue:** `_showAddFeedDialog()` creates dialog, shows loading overlay, validates URL, calls provider, shows snackbar, handles errors — all in one 73-line anonymous async callback. Untestable.
**Fix:** Extract async logic into a provider method. Keep the dialog thin.

### M8. FeedSource model tolerates missing fields silently
**File:** `models/feed_source.dart:26-34`
**Issue:** All fields default to `''` / `false` / `0` if missing from JSON. A corrupt storage entry produces a valid-looking but broken `FeedSource` (empty URL, empty name).
**Fix:** Validate required fields (`name`, `url`) in `fromMap` and throw or skip malformed entries.

### M9. No timeout on feed validation parse step
**File:** `rss_service.dart:101-125`
**Issue:** `validateFeed` fetches with timeout but parses synchronously. An extremely large malicious response could cause high memory usage.
**Fix:** Cap response body size (`response.contentLength` check) before parsing.

---

## LOW

### L1. Hardcoded theme colors
**File:** `theme/app_theme.dart` (throughout)
**Issue:** Dozens of inline hex colors (`0xFF1A1A2E`, `0xFFF8F9FA`, etc.) with no named constants. Changing the palette requires editing dozens of lines.
**Fix:** Extract to `AppColors` class.

### L2. _stripHtml is naive
**File:** `widgets/article_tile.dart:78-81`
**Issue:** `RegExp(r'<[^>]*>')` strips tags but doesn't handle entities (`&amp;`, `&lt;`) or malformed HTML.
**Fix:** Use `html` package's `parse()` + `.text`, or accept limitation with a comment.

### L3. UI state leaked into provider
**File:** `feed_provider.dart:13-14`
**Issue:** `_expanded` and `_loading` maps are pure UI state. They belong in the widget layer.
**Fix:** Move to local widget state or separate UI-state providers.

### L4. Article.fromMap allows empty URLs
**File:** `models/article.dart:29`
**Issue:** `url: map['url'] ?? ''` allows empty URLs into the model. Downstream filter catches this, but the model doesn't enforce the invariant.
**Fix:** Document the convention or validate in the model.

### L5. FeedProvider constructor position
**File:** `feed_provider.dart:52`
**Issue:** Constructor declared after getters and fields. Dart convention places it near the top.
**Fix:** Move constructor to after field declarations.

### L6. No SSL pinning
**File:** `rss_service.dart` (all http calls)
**Issue:** Uses bare `http.get()` with no certificate pinning. On rooted devices, MITM could modify feed responses.
**Fix:** Low priority for MVP. Add for production with `dio` or custom `SecurityContext`.

---

## False Positives Ruled Out

| Finding | Verdict | Reason |
|---------|---------|--------|
| "No tests exist" | Not filed | User didn't request tests, code audit only |
| "Missing Android/iOS config" | Not filed | User said to write code first, build tools after |
| "Package versions may be outdated" | Not filed | Will be checked during `flutter pub get` |
| "webfeed package may not parse all formats" | Not filed | `fetchAny` already tries RSS then Atom as fallback |

---

## Recommended Fix Order

1. **C1 + C2** — Storage error handling (app won't launch without this)
2. **C3 + C4** — WebView security (injection risk)
3. **C5 + C6** — FeedProvider refactor (everything depends on this)
4. **H1 + H2** — Storage writes + URL validation
5. **H3 + H6** — ArticleScreen error state + logging
6. **M1-M9** — Quality improvements (DRY, constants, dead code)

---

## Second Pass — New Findings (Pass 2)

**Date:** 2026-05-29
**Auditors:** 3 parallel agents (async/lifecycle, security/input, architecture/performance) + manual cross-reference against Pass 1
**Goal:** Catch bugs missed in Pass 1. No duplication with the 28 existing findings.

| Severity | Count | Status |
|----------|-------|--------|
| CRITICAL | 1 | Must fix before first run |
| HIGH | 5 | Must fix before release |
| MEDIUM | 5 | Should fix, tech debt |
| LOW | 11 | Nice to have |
| **Total (new)** | **22** | |

---

## CRITICAL (Pass 2)

### P2-C1. No duplicate feed URL detection
**File:** `feed_provider.dart:81-114`
**Issue:** `validateAndAddFeed()` never checks whether a URL already exists in `_feeds`. The same RSS feed can be added multiple times, creating duplicate entries that all get fetched on every refresh. Feed names are derived from the host, so identical URLs produce identical names and articles silently overwrite each other.
**Impact:** Wasted network bandwidth, duplicate UI entries, confusing user experience.
**Fix:** Check `_feeds.any((f) => f.url == url)` before adding. If duplicate exists, throw or return early with a clear message.

---

## HIGH (Pass 2)

### P2-H1. Concurrent `refreshAll()` races on `_articles` and `_loading`
**File:** `feed_provider.dart:63-78`
**Issue:** Multiple `refreshAll()` invocations (from `init()` and rapid pull-to-refresh) run concurrently with no deduplication, debounce, or cancellation. Each invocation maps `enabledFeeds`, fires per-feed HTTP requests, and writes to `_articles[feed.name]` independently. A slower first call's response can overwrite fresher data from a faster second call.
**Impact:** Stale data overwrites fresh data. `_loading` flags flicker or settle incorrectly. Duplicate HTTP requests waste bandwidth.
**Fix:** Introduce an in-flight guard (`_isRefreshing`) or cancellation token. Debounce pull-to-refresh. Use `async` mutex per feed.

### P2-H2. Context shadowing in add-feed dialog — user receives zero feedback
**File:** `settings_screen.dart:145-217` (line 170 specifically)
**Issue:** The `builder: (context) => ...` lambda shadows the outer `_showAddFeedDialog` parameter with a same-named `context`. All references to `context` inside `onPressed` resolve to the **dialog builder's context**, not the `SettingsView` context. After `Navigator.pop(context)` on line 170 dismisses the dialog, the builder's context is unmounted, so every subsequent `context.mounted` check evaluates to `false`. The loading overlay (`showDialog` at line 174), success snackbar (line 199), and error snackbar (line 207) are **never executed**.
**Impact:** User taps "Add" → dialog closes → nothing visible happens. Feed may be added silently (or fail silently) with zero visual confirmation. Complete breakdown of user feedback for a primary interaction.
**Fix:** Rename the builder parameter (e.g., `builder: (dialogContext) => ...`) so the outer `context` remains accessible in the `onPressed` closure.

### P2-H3. Root `Consumer<FeedProvider>` wraps entire `MaterialApp`
**File:** `main.dart:26-37`
**Issue:** `Consumer<FeedProvider>` at the app root causes the entire widget tree — including `MaterialApp`, theme resolution, and all child screens — to rebuild on **every** `notifyListeners()` call. This includes feed loading, bookmark toggling, dark mode, and expansion state changes.
**Impact:** Degraded performance and UI jank during feed loading, where multiple `notifyListeners()` calls fire per feed.
**Fix:** Narrow the `Consumer` to the widgets that need provider data. Use `Selector` or split the provider. Move `MaterialApp` outside the `Consumer` and only rebuild `ThemeMode` via a lightweight builder.

### P2-H4. No HTTP response body size limit — OOM vector across all fetch methods
**File:** `rss_service.dart:8-75` (all four methods: `fetchFeed`, `fetchAtomFeed`, `fetchAny`, `validateFeed`)
**Issue:** Every HTTP fetch reads the full response body into memory without checking `response.contentLength` or imposing a size cap. A malicious RSS server returning a multi-gigabyte response causes the app to buffer it entirely in RAM. (Pass 1's M9 only covered `validateFeed`'s synchronous parse step; this finding covers the unchecked body read across all methods.)
**Impact:** Out-of-memory crash on low-memory devices from a malicious or misconfigured RSS server.
**Fix:** Check `response.contentLength` and reject responses exceeding a reasonable limit (e.g., 5 MB) before reading the body. Use `http.Client.send()` with a streaming response for forward-only parsing.

### P2-H5. `removeFeed` leaves stale order values — feeds mis-sorted until manual reorder
**File:** `feed_provider.dart:164-171`
**Issue:** `removeFeed` sets `feed.order = _feeds.length` but never recalculates the `order` field for remaining enabled feeds. After removing feed at index 1 from orders `[0,1,2,3]`, remaining feeds have orders `[1,2,3]` instead of `[0,1,2]`. New feeds added later may interleave with these stale values.
**Impact:** Feed sort order is silently corrupted until the user manually reorders in Settings.
**Fix:** Re-normalize `order` for remaining enabled feeds after removal. Alternatively, sort `enabledFeeds` by `order` field and recompute on load.

---

## MEDIUM (Pass 2)

### P2-M1. Feed name collision from same host — articles silently overwrite
**File:** `feed_provider.dart:88-91`
**Issue:** Feed names are derived via `uri.host.replaceAll('www.', '').split('.').first`. Two distinct feeds from the same domain (e.g., `https://example.com/tech/rss` and `https://example.com/news/atom`) both become `"Example"`. The `_articles` map keys by feed name, so the second feed's articles silently overwrite the first's.
**Impact:** Users lose articles from the first feed when adding a second feed from the same domain. No error or warning is shown.
**Fix:** Generate unique feed names. Append a suffix (`name`, `name_1`) or use the full URL path to disambiguate.

### P2-M2. Empty favicon URL passed to `CachedNetworkImage`
**File:** `source_header.dart:24-28`
**Issue:** When `favicon` is an empty string (from `FeedSource.fromMap` where field is missing, or from the naive URL builder at `feed_provider.dart:93` producing `":///favicon.ico"`), `CachedNetworkImage` makes an HTTP GET request to an empty URL. This generates a failed network request and an error-level log on every source header render.
**Impact:** Wasteful failed network requests on every build for any feed without a valid favicon.
**Fix:** Guard with `favicon.isNotEmpty` before passing to `CachedNetworkImage`. Show the RSS fallback icon directly when the URL is empty.

### P2-M3. `enabledFeeds` / `availableFeeds` getters break referential equality
**File:** `feed_provider.dart:27-34`
**Issue:** Both getters call `.toList()` on every invocation, creating a new `List` instance. Any `Consumer` or widget comparing references sees a different object on every `notifyListeners()` call, even when the underlying feed data has not changed. This forces unnecessary rebuilds on all three screens (Home, Bookmarks, Settings).
**Impact:** Unnecessary widget rebuilds on every provider notification, impacting scroll performance and battery.
**Fix:** Cache the sorted/filtered lists and only recompute when `_feeds` actually changes. Or use `equatable` / identity-based comparison in widgets.

### P2-M4. `WebView.loadRequest` continues after widget disposal
**File:** `article_screen.dart:26-41`
**Issue:** `loadRequest(Uri.parse(widget.url))` fires in `initState` with no cancellation mechanism. If the user pops `ArticleScreen` before the page finishes loading, the `WebViewController` continues its network request in the background. The `onPageFinished` / `onProgress` callbacks may attempt `setState` on a disposed widget (mitigated by `mounted` checks, but the network waste remains).
**Impact:** Wasted network bandwidth and processing for discarded page loads. Callbacks may fire after disposal.
**Fix:** Call `_controller.stopLoading()` in a `dispose()` override. Alternatively, defer `loadRequest` to `initState` only after mounting is confirmed.

### P2-M5. `toggleFeed` fires unawaited async `_fetchForFeed` — race with refresh
**File:** `feed_provider.dart:117-125`
**Issue:** `toggleFeed()` calls `_fetchForFeed(feed)` without `await`. If the user rapidly toggles a feed on/off/on, multiple concurrent fetches for the same feed run in parallel, with the slowest response overwriting the most recent one. This also races against concurrent `refreshAll()` calls for the same feed name.
**Impact:** Stale or interleaved article data appears when users rapidly toggle feeds.
**Fix:** `await` the fetch call, or cancel any in-flight request for the same feed before starting a new one.

---

## LOW (Pass 2)

### P2-L1. Unused dependency: `flutter_slidable`
**File:** `pubspec.yaml:19`
**Issue:** `flutter_slidable: ^3.0.1` is declared but never imported or referenced in any Dart file.
**Impact:** Unnecessary app bundle size and dependency surface area.
**Fix:** Remove the dependency.

### P2-L2. Unused dependency: `url_launcher`
**File:** `pubspec.yaml:20`
**Issue:** `url_launcher: ^6.2.1` is declared but never imported in executable code. Only referenced in a comment at `article_screen.dart:58`.
**Impact:** Unnecessary app bundle size. The "Open in Browser" button remains dead UI despite having the dependency available.
**Fix:** Wire up the dependency (implement the button) or remove it.

### P2-L3. Dead dev dependencies: `hive_generator` + `build_runner`
**File:** `pubspec.yaml:26-27`
**Issue:** `hive_generator` and `build_runner` are declared as dev dependencies, but no model classes use `@HiveType` / `@HiveField` annotations. Serialization is manual via `toMap()`/`fromMap()`. No `.g.dart` files exist.
**Impact:** Unnecessary `pub get` installs. Developers may run `build_runner` expecting generated output and get confusing empty results.
**Fix:** Remove both dev dependencies, or annotate models and commit to using generated adapters.

### P2-L4. Inconsistent `async`/`sync` signatures in `StorageService`
**File:** `storage_service.dart:25, 49, 54, 63`
**Issue:** `loadFeeds()` returns `Future<List<FeedSource>>` (async) while `loadBookmarks()` returns `List<Article>` (sync), despite both performing the same kind of Hive box read. `isDarkMode()` is sync but `setDarkMode()` is async.
**Impact:** Confusing API surface for callers and test mocks. Sync methods cannot be `await`ed uniformly.
**Fix:** Make all read methods return `Future<T>` for consistency, even if the underlying Hive read is synchronous.

### P2-L5. `validateAndAddFeed` emits duplicate `notifyListeners` calls
**File:** `feed_provider.dart:105, 111`
**Issue:** `notifyListeners()` fires at line 105 (after adding the feed to `_feeds`) and again at line 111 (after articles finish fetching). The first call triggers a rebuild before articles are available, causing the new feed section to flash empty then populate.
**Impact:** Visual flicker and two rapid rebuilds per feed addition.
**Fix:** Batch the state change: set `_articles[newFeed.name]` before the first `notifyListeners()`, or defer notification until articles are ready.

### P2-L6. `isBookmarked` performs O(n*m) scan per build pass
**File:** `feed_provider.dart:48-50`
**Issue:** `isBookmarked` iterates the entire `_bookmarks` list for every article tile. Passed as a callback from `FeedSection` to each `ArticleTile`, it's invoked once per rendered article per build. With 300 articles and 50 bookmarks, this is 15,000 iterations per rebuild.
**Impact:** Degraded scrolling performance on devices with large feed or bookmark collections.
**Fix:** Convert `_bookmarks` to a `Set<String>` keyed by URL for O(1) lookups.

### P2-L7. Naive favicon URL construction produces 404s
**File:** `feed_provider.dart:93`
**Issue:** Favicon URLs are constructed as `'${uri.scheme}://${uri.host}/favicon.ico'`, assuming all sites serve their icon at this exact path. Many sites use `/favicon.png`, `/favicon.svg`, or nested paths.
**Impact:** Most custom feed favicons silently fail to load, rendering the generic RSS fallback icon instead.
**Fix:** Use a service like `https://www.google.com/s2/favicons?domain=${uri.host}` or try the default path and fall back gracefully.

### P2-L8. `FeedSection` creates unnecessary list copies on every build
**File:** `feed_section.dart:33-34`
**Issue:** `articles.take(displayCount).toList()` allocates a new `List` on every build. When `isExpanded` is true, `displayCount == articles.length`, so the entire list is copied needlessly.
**Impact:** Extra GC pressure during scrolling and state changes.
**Fix:** Slice without allocation: use `articles.take(displayCount)` directly in the loop (the iterator is lazy).

### P2-L9. Article equality by URL causes bookmark confusion for cross-posts
**File:** `article.dart:38-46`
**Issue:** `operator ==` and `hashCode` only consider `url`. If two articles from different feeds share the same URL (syndicated content), `isBookmarked` returns `true` for both, and `toggleBookmark` on one removes the other's bookmark.
**Impact:** Users may lose bookmarks on syndicated articles without realizing. False-positive bookmark indicator appears for unbookmarked articles sharing a URL.
**Fix:** Include `sourceName` in equality and hash, or document and accept the dedup behavior.

### P2-L10. `TextEditingController` not disposed in add-feed dialog
**File:** `settings_screen.dart:145`
**Issue:** A `TextEditingController` is allocated in the method scope each time the dialog is shown. It is never `dispose()`d. While the controller will be GC'd after the dialog closes, leaving it undisposed violates Flutter best practices.
**Impact:** Minor resource accumulation over the app session. Potential listener leaks during hot reload.
**Fix:** Dispose the controller in the dialog's close callback, or move ownership to an `initState`/`dispose` lifecycle pair.

### P2-L11. `RssService` eagerly instantiated as field initializer
**File:** `feed_provider.dart:9`
**Issue:** `final RssService _rss = RssService()` creates the service object at provider construction time, even if `init()` is never called or the provider is only used for bookmark/settings operations.
**Impact:** Trivial unnecessary object allocation.
**Fix:** Make `_rss` `late final` and initialize lazily, or inject via constructor.

---

## False Positives Ruled Out (Pass 2)

| Agent Finding | Verdict | Reason |
|---------------|---------|--------|
| "feed_section.dart has empty state for no articles" | Not filed | This is intentional UI, not a bug |
| "no connectivity check before HTTP" | Not filed | Covered by existing H6 (silent error swallowing) + P2-H4 |
| "BookmarksView empty state uses Theme.of inside build" | Not filed | Safe pattern, `Theme.of` caches on the `context` |
| "flutter_slidable could be used for swipe actions" | Not filed | Speculative feature, not a bug |
| "Nested SizedBox(height: 80) is magic number" | Not filed | Covered by existing M3 (magic numbers) |
| "ArticleScreen missing onBackPressed callback" | Not filed | Platform default back behavior works correctly |
| "FeedProvider has no dispose() override" | Not filed | `ChangeNotifierProvider` handles disposal; no timers/streams to clean up |
| "storage_service.dart init() could fail silently" | Not filed | Covered by existing C1 (storage error handling) |
| "removeFeed should also remove bookmarks" | Not filed | Removing a feed should not destroy user's bookmarks |

---

## Recommended Fix Order (Combined Pass 1 + Pass 2)

1. **C1–C6** (Pass 1) — Storage + init + WebView security + model encapsulation
2. **P2-C1** — Duplicate feed URL detection
3. **P2-H1 + P2-H5** — Concurrent refresh race + removeFeed order corruption
4. **P2-H2** — Context shadowing (user feedback broken)
5. **P2-H3** — Root Consumer performance
6. **P2-H4** — HTTP body size limit
7. **P2-M1 → P2-M5** — Feed name collision, favicon URL, referential equality, WebView lifecycle, unawaited fetch
8. **P2-L1 → P2-L11** — Dead deps, API consistency, performance micro-optimizations

---

*Pass 2 complete: 22 new findings (1 critical, 5 high, 5 medium, 11 low). 28 previous + 22 new = 50 total issues identified across both passes.*

---

## Third Pass - New Findings (Pass 3)

**Date:** 2026-05-29
**Auditors:** 3 parallel sub-agents (async/state/lifecycle, security/input/network, data/UI correctness) + manual review
**Goal:** Find additional, non-duplicative bugs after Pass 1 and Pass 2.

| Severity | Count | Status |
|----------|-------|--------|
| CRITICAL | 1 | Blocks compilation |
| HIGH | 1 | Core feature broken |
| MEDIUM | 5 | User-visible correctness, privacy, or data issues |
| LOW | 3 | UX polish and responsiveness issues |
| **Total (new)** | **10** | |

---

## CRITICAL (Pass 3)

### P3-C1. `FeedSection.isBookmarked` is typed as a bool but used as a callback
**Files:** `lib/widgets/feed_section.dart:13`, `lib/widgets/feed_section.dart:68`, `lib/screens/home_screen.dart:122`
**Issue:** `FeedSection` declares `final bool isBookmarked;`, but `HomeScreen` passes `provider.isBookmarked`, which is a `bool Function(Article)`. `FeedSection` then calls `isBookmarked(visibleArticles[i])` as if it were a function.
**Impact:** The app does not compile. This is a hard type error before runtime behavior can be tested.
**Fix:** Change the field and constructor parameter to `final bool Function(Article) isBookmarked;`.

---

## HIGH (Pass 3)

### P3-H1. "Show More" expansion can never reveal articles past the first 10
**Files:** `lib/providers/feed_provider.dart:36-37`, `lib/screens/home_screen.dart:117`, `lib/widgets/feed_section.dart:33-35`, `lib/widgets/feed_section.dart:72-80`
**Issue:** `HomeScreen` always calls `provider.articlesForSource(feed.name)` with the default limit of 10. `FeedSection` receives that already-truncated list and computes `hasMore` from `articles.length > 10`, so `hasMore` is always false. Even if `isExpanded` is true, only 10 articles were passed into the widget.
**Impact:** Feeds that fetched 11-30 articles are permanently capped at 10. The expansion state and `Show More` UI path are effectively dead.
**Fix:** Pass the full article list into `FeedSection`, or pass a limit based on `provider.isExpanded(feed.name)`. Compute `hasMore` from `totalArticles`, not from the truncated visible list.

---

## MEDIUM (Pass 3)

### P3-M1. Empty or failed refreshes leave stale articles visible
**Files:** `lib/providers/feed_provider.dart:70-72`, `lib/providers/feed_provider.dart:131-133`, `lib/services/rss_service.dart:71-73`
**Issue:** `refreshAll()` and `_fetchForFeed()` only replace `_articles[feed.name]` when the fetched list is non-empty. `RssService.fetchAny()` returns `[]` for both real empty feeds and network/parse failures.
**Impact:** A feed can refresh successfully to zero articles, or fail after previously loading articles, while the UI continues showing old content as if it were current. This is distinct from the earlier silent-error finding: the provider preserves stale data because empty results are ignored.
**Fix:** Return a result type that distinguishes success-empty from failure. On successful empty responses, write `[]`; on failure, show a stale/error marker or intentionally retain last-known data with status.

### P3-M2. Private feed URLs and tokens are stored and displayed raw
**Files:** `lib/services/storage_service.dart:18-21`, `lib/services/storage_service.dart:49-52`, `lib/screens/settings_screen.dart:65-68`, `lib/screens/settings_screen.dart:96-99`
**Issue:** Custom RSS URLs can contain query tokens or `user:pass@host` credentials. The app stores the full feed URL in an unencrypted Hive box and renders it verbatim in Settings.
**Impact:** Private feed tokens can leak through device backups, filesystem access, screenshots, or shoulder-surfing. This affects common private feeds from services that authenticate with URL tokens.
**Fix:** Reject `uri.userInfo`, redact sensitive query parameters in UI, and use Hive encryption with a key stored in platform secure storage if private feeds are supported.

### P3-M3. Atom entries use the first link, not the article link
**File:** `lib/services/rss_service.dart:93`
**Issue:** `_parseAtomArticles()` uses `item.links!.first.href` as the article URL. Atom entries may contain multiple links such as `self`, `enclosure`, `related`, and `alternate`; the first link is not guaranteed to be the article page.
**Impact:** The app can open, bookmark, and deduplicate the wrong URL for Atom feeds, even when the correct article URL exists elsewhere in the entry.
**Fix:** Prefer a link whose `rel` is missing or `alternate`, require an `http` or `https` URL, and only fall back to the first usable link.

### P3-M4. Valid but temporarily empty feeds are rejected as invalid
**Files:** `lib/services/rss_service.dart:111-118`
**Issue:** `validateFeed()` returns true only when parsed RSS or Atom documents have non-empty `items`. A valid feed with zero current entries is treated the same as a malformed or unreachable feed.
**Impact:** Users cannot add valid feeds during quiet periods, migrations, or first publication setup.
**Fix:** Treat successful RSS/Atom parsing and feed-level metadata as validation. Article count should affect the initial article list, not feed validity.

### P3-M5. Updated bundled feed defaults are never merged after first launch
**Files:** `lib/services/storage_service.dart:25-31`, `lib/services/storage_service.dart:34-45`
**Issue:** On first launch, `_loadDefaultFeeds()` saves the bundled feed list into Hive. On every later launch, `loadFeeds()` returns the stored list and never reads `assets/feeds.json` again.
**Impact:** App updates that add, remove, or correct bundled feed sources will not reach existing users. A stale first-run snapshot becomes permanent unless storage is reset.
**Fix:** Version the feed catalog or merge bundled defaults by stable URL/id on startup while preserving user-enabled state, order, and custom feeds.

---

## LOW (Pass 3)

### P3-L1. Per-feed loading completion is not published until the slowest feed finishes
**Files:** `lib/providers/feed_provider.dart:69-78`
**Issue:** Each feed future updates `_articles` and `_loading`, but listeners are notified only after `Future.wait(futures)` completes.
**Impact:** Fast feeds remain visually stuck in loading state while one slow feed is still pending. Articles that already arrived do not render until the slowest request finishes.
**Fix:** Call `notifyListeners()` after each per-feed completion, or use a single global refresh indicator instead of per-feed spinners.

### P3-L2. Pull-to-refresh can be unavailable when content is shorter than the viewport
**Files:** `lib/screens/home_screen.dart:95-137`
**Issue:** `RefreshIndicator` wraps a `CustomScrollView` without `AlwaysScrollableScrollPhysics`. On screens where the feed content is shorter than the viewport, the scrollable may not overscroll, so pull-to-refresh cannot be triggered.
**Impact:** Users with few feeds or empty feeds may have no gesture path to refresh.
**Fix:** Add `physics: const AlwaysScrollableScrollPhysics()` to the `CustomScrollView`.

### P3-L3. Long feed names can overflow the source header row
**Files:** `lib/widgets/source_header.dart:24-44`
**Issue:** The feed name `Text` is placed directly in a `Row` after the favicon without `Expanded`, `maxLines`, or `overflow`.
**Impact:** Long custom feed names can cause a horizontal overflow in the feed header.
**Fix:** Wrap the `Text` in `Expanded` and use `maxLines: 1` with `TextOverflow.ellipsis`.

---

## False Positives Ruled Out (Pass 3)

| Candidate | Verdict | Reason |
|-----------|---------|--------|
| Add-feed dialog context shadowing | Not filed | Already covered by `P2-H2`. |
| WebView JavaScript and unsafe URL schemes | Not filed | Already covered by `C3` and `C4`. |
| Missing custom feed URL validation | Not filed | Already covered by `H2` and `H7`. |
| Duplicate feed URLs and feed-name collisions | Not filed | Already covered by `P2-C1` and `P2-M1`. |
| Unbounded HTTP body size | Not filed | Already covered by `P2-H4` and `M9`. |
| Empty favicon handling | Not filed | Already covered by `P2-M2`. |
| Bookmark equality by URL | Not filed | Already covered by `P2-L9`. |
| `TextEditingController` disposal in add-feed dialog | Not filed | Already covered by `P2-L10`. |
| `Boing Boing` feed currently returning 403/Cloudflare challenge | Not filed | Verified during this pass, but treated as third-party/feed-health volatility rather than a durable code bug. |

---

## Verification Notes (Pass 3)

- Read all Dart source files, `pubspec.yaml`, `analysis_options.yaml`, and `assets/feeds.json`.
- Used `rg` cross-checks against existing `AUDIT.md` to avoid duplicate findings.
- Spawned 3 sub-agents and manually reviewed their findings before filing.
- Attempted `flutter analyze` and `dart --version`, but neither `flutter` nor `dart` is available on PATH in this environment.
- Checked bundled feed URL reachability on 2026-05-29; only `Boing Boing` returned a Cloudflare/403 response, which was not filed as a code finding.

---

## Recommended Fix Order (Pass 3)

1. **P3-C1** - Fix the `isBookmarked` callback type so the app compiles.
2. **P3-H1** - Fix article truncation/expansion so `Show More` works.
3. **P3-M1** - Separate fetch failures from successful empty feeds to avoid stale content.
4. **P3-M2** - Decide the privacy model for private feed URLs and token redaction.
5. **P3-M3 + P3-M4** - Tighten Atom parsing and feed validation semantics.
6. **P3-M5** - Add a feed catalog migration/merge path.
7. **P3-L1 - P3-L3** - Improve loading responsiveness, refresh ergonomics, and long-name layout.

*Pass 3 complete: 10 new findings (1 critical, 1 high, 5 medium, 3 low). 50 previous + 10 new = 60 total issues identified across all passes.*

---

## Fix Progress - 2026-05-29

**Status:** First implementation batch started. Flutter/Dart tooling is still unavailable on PATH in this environment, so verification is currently limited to source inspection and targeted grep checks.

### Completed

| Finding | Status | Files Changed | Notes |
|---------|--------|---------------|-------|
| P3-C1 | Fixed | `lib/widgets/feed_section.dart` | `isBookmarked` is now typed as `bool Function(Article)`, matching how `HomeScreen` passes `provider.isBookmarked`. |
| C5 | Fixed | `lib/models/feed_source.dart`, `lib/providers/feed_provider.dart` | `FeedSource.enabled` and `FeedSource.order` are now immutable. Mutations now use `copyWith()`. |
| M8 | Partially fixed | `lib/models/feed_source.dart`, `lib/services/storage_service.dart` | `FeedSource.fromMap()` now rejects missing/empty `name` and `url`; storage skips malformed entries through guarded loading. |
| C1 | Partially fixed | `lib/services/storage_service.dart`, `lib/main.dart` | Hive init/openBox, JSON decode, default asset loading, and setting reads/writes now have error handling and debug logging. Corrupt boxes attempt delete/reopen recovery. |
| C2 | Fixed | `lib/providers/feed_provider.dart`, `lib/screens/home_screen.dart` | Provider init now has an error boundary, sets `_initialized` in `finally`, and exposes `errorMessage` for a visible home-screen banner. |
| H1 | Fixed | `lib/providers/feed_provider.dart`, `lib/screens/home_screen.dart`, `lib/screens/bookmarks_screen.dart`, `lib/screens/settings_screen.dart` | Feed/bookmark/theme persistence writes are now awaited by provider methods and screen callbacks. |
| P3-H1 | Fixed | `lib/providers/feed_provider.dart`, `lib/screens/home_screen.dart`, `lib/widgets/feed_section.dart` | `articlesForSource()` now returns the full article list by default; `FeedSection` computes preview/expanded display from the full list. |
| P2-C1 | Fixed | `lib/providers/feed_provider.dart`, `lib/utils/url_utils.dart` | Custom feed additions now normalize URLs and reject duplicates. |
| P2-M1 | Fixed | `lib/providers/feed_provider.dart` | Custom feed names now become unique by suffixing duplicate host-derived names. |
| P2-H5 | Fixed | `lib/providers/feed_provider.dart` | Enabled/disabled feed order is normalized after load/add/remove/toggle/reorder. |
| H2 + H7 | Fixed | `lib/providers/feed_provider.dart`, `lib/utils/url_utils.dart` | Custom RSS URLs now use `Uri.tryParse`, require `http`/`https`, require non-empty host, and reject `userInfo`. |
| C3 + C4 | Fixed | `lib/screens/article_screen.dart`, `lib/utils/url_utils.dart` | WebView now disables JavaScript, validates article URLs, and blocks unsafe navigation schemes. |
| H3 | Fixed | `lib/screens/article_screen.dart` | WebView now handles resource errors with an in-app error state and retry button. |
| M4 + P2-L2 | Fixed | `lib/screens/article_screen.dart` | “Open in browser” now uses `url_launcher` instead of being dead UI. |
| P2-H4 | Partially fixed | `lib/services/rss_service.dart` | RSS fetches now stream responses and reject bodies over 5 MB. No streaming XML parser yet. |
| H6 | Partially fixed | `lib/services/rss_service.dart`, `lib/providers/feed_provider.dart` | Silent catches were replaced with `debugPrint` logging in RSS/provider fetch paths. A typed result object is still pending. |
| P3-M3 | Fixed | `lib/services/rss_service.dart` | Atom parsing now prefers `rel == null` or `rel == alternate`, then falls back to first safe http/https link. |
| P3-M4 | Fixed | `lib/services/rss_service.dart` | Feed validation now treats successful RSS/Atom parsing as valid even if item count is zero. |
| P2-H2 | Fixed | `lib/screens/settings_screen.dart` | Add-feed dialog no longer shadows the outer context; loading and snackbar feedback use the screen context. |
| P3-L2 | Fixed | `lib/screens/home_screen.dart` | Feed scroll view now uses `AlwaysScrollableScrollPhysics` so pull-to-refresh works on short content. |
| P2-M2 + P3-L3 | Fixed | `lib/widgets/source_header.dart` | Empty favicon URLs now show fallback directly; long source names are ellipsized inside `Expanded`. |
| P2-M1 | Fixed | `lib/services/rss_service.dart` | HTTP fetch logic was consolidated behind `_fetchBody()`. |
| M3 | Partially fixed | `lib/services/rss_service.dart`, `lib/widgets/feed_section.dart` | Named constants added for feed timeout, max feed articles, response size cap, and preview count. Theme/layout constants remain. |

### Still Open

| Finding | Priority | Notes |
|---------|----------|-------|
| C6 | High | `FeedProvider` is still a large class. Deferred intentionally until the app compiles and core behavior is stable. |
| H5 | High | Services still use concrete classes. Deferred with C6 to avoid premature architecture churn. |
| P2-H1 + P2-M5 | High | `refreshAll()` has an `_isRefreshing` guard, and `toggleFeed()` awaits `_fetchForFeed()`. Per-feed cancellation/mutex is still not implemented. |
| P3-M1 | High | Fetch failures and successful empty feeds are still both represented as `[]` at provider boundaries. Needs a typed result object. |
| P3-M2 | Medium | URLs with `userInfo` are rejected and sensitive query params are redacted in Settings, but Hive encryption/secure storage is not implemented. |
| P3-M5 | Medium | Bundled feed defaults are still not versioned/merged after first launch. |
| P2-H3 | Medium | Root `Consumer<FeedProvider>` still wraps `MaterialApp`. Narrow rebuild optimization remains. |
| P2-M3 | Medium | `enabledFeeds` / `availableFeeds` still allocate new lists on each getter call. |
| P2-L1 | Low | `flutter_slidable` is still unused. Remove unless swipe actions are implemented. |
| P2-L3 | Low | `hive_generator` and `build_runner` are still unused. Remove unless switching to generated Hive adapters. |
| P2-L6 | Low | Bookmark lookup remains O(n) per tile. Can be optimized with a URL set. |
| P2-L8 | Low | `FeedSection` still materializes `visibleArticles` with `.toList()`. |
| P2-L9 | Low | Article equality still uses URL only. Decide whether cross-source dedup is desired. |
| L1 | Low | Theme colors remain inline. |
| L2 | Low | HTML stripping remains regex-based. |
| L3 | Low | UI state (`_expanded`, `_loading`) still lives in provider. Deferred with provider refactor. |

### Verification Performed

- Grep-confirmed no remaining direct assignments to `FeedSource.enabled` or `FeedSource.order` outside constructor defaults.
- Grep-confirmed no remaining `Uri.parse`, `JavaScriptMode.unrestricted`, or `catch (_)` patterns in `lib/`.
- Grep-confirmed `FeedSection.isBookmarked` now accepts the provider callback type.
- Grep-confirmed provider storage writes are awaited at provider call sites.

### Verification Blocked

- `flutter analyze`, `dart analyze`, and app build/run remain blocked because neither Flutter nor Dart is installed or available on PATH in this environment.
