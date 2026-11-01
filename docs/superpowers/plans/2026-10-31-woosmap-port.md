# Woosmap Port Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Produce `timeline-woosmap.html`, a copy of `timeline.html` that renders with the Woosmap Map JS API and makes no Google or Woosmap data API calls.

**Architecture:** One self-contained HTML file, as the original. Google map classes are swapped for their `woosmap.map` twins; the three places where Woosmap has no twin (pin glyphs, polyline arrow icons, deck.gl Google overlay) get small local replacements. Everything that fetched place data is deleted rather than stubbed.

**Tech Stack:** Woosmap Map JS API 1.4 (`sdk.woosmap.com/map/map.js`), deck.gl (standalone `Deck`), moment-timezone, tz-lookup, Chart.js. No build step. Checks run with `node --check` and `grep`.

**Spec:** `docs/superpowers/specs/2026-10-31-woosmap-port-design.md`

## Global Constraints

- The only external script hosts are cdnjs, jsdelivr, unpkg and `sdk.woosmap.com`. Any `fetch(` to another host is a defect.
- No `google.maps`, `googleapis.com`, `importLibrary`, `AdvancedMarkerElement`, `PinElement`, `new Place(`, `fetchFields` may remain.
- Click handlers read the coordinate from `e.latlng`. InfoWindows open with `open(map, anchor)`. Markers attach with `setMap(map)`, never `.map =`.
- `timeline.html` is not modified.
- No commit unless the owner asks; the owner's uncommitted local edit to `timeline.html` (a real Google key on line 22) must not be copied into the new file.

## Review Focus

1. A Takeout visit with no `name` must still render a marker titled by semantic type or "Visit". Pinned in Task 6.
2. Switching map theme after a day is loaded must keep every marker and polyline visible. Pinned in Task 3.
3. Selecting a path, then selecting another, must leave arrows only on the second. Pinned in Task 5.
4. The World View heatmap must stay aligned while panning and zooming (no zoom offset). Pinned in Task 8 browser check.
5. Loading a folder that contains `TimelinePlaceCache.json` must be ignored silently, not crash. Pinned in Task 6.

---

### Task 1: Scaffold and the check script

**Files:**
- Create: `timeline-woosmap.html` (copy of committed `timeline.html`, via `git show HEAD:timeline.html`)
- Create: `tools/check-woosmap.sh`

**Interfaces:**
- Produces: `tools/check-woosmap.sh` exits 0 only when the inline script parses under `node --check` and none of the forbidden patterns from Global Constraints appear.

- [ ] **Step 1: Write the check script.** It extracts every `<script>` body without `src` from `timeline-woosmap.html` into the scratchpad, runs `node --check` on each, then greps the file for the forbidden patterns and for `fetch(` targets outside the allowed hosts. Print each failing pattern with its line count.
- [ ] **Step 2: Run it; expected FAIL** listing `google.maps`, `importLibrary`, `googleapis.com`, `AdvancedMarkerElement`, `PinElement`, `new Place(`, `fetchFields`.

### Task 2: SDK loader and API key plumbing

**Files:**
- Modify: `timeline-woosmap.html` lines 1-31 (header comment, key fallback, script tags), 3331-3342 and 3607-3613 (key modal and settings copy), 4282-4300 and 4443-4620 (key resolution), 4554-4700 (loader, auth failure, `waitForGoogleMapsAuthCheck`), 10845-10865 (settings key buttons), 16175-16240 (startup).

**Interfaces:**
- Produces: `window.WOOSMAP_API_KEY` fallback; `getWoosmapApiKey(): string`; `resolveWoosmapApiKey(): Promise<{key, source}|null>`; `loadWoosmapSdk(apiKey): Promise<void>` that injects `https://sdk.woosmap.com/map/map.js?key=<key>&callback=__woosmapReady` and resolves when the callback fires, rejects on script `error`; `window.TIMELINE_VIEWER_CONFIG.woosmapApiKey` read from `timeline.local.js`; storage key `woosmapApiKey`.
- Consumes: nothing.

- [ ] **Step 1:** Replace `window.GOOGLE_MAPS_API_KEY = "..."` with `window.WOOSMAP_API_KEY = "YOUR_API_KEY"`; rename every `GOOGLE_MAPS_API_KEY`, `getGoogleMapsApiKey`, `resolveGoogleMapsApiKey`, `googleMapsApiKey` identifier; set `API_KEY_STORAGE_KEY = 'woosmapApiKey'`.
- [ ] **Step 2:** Delete `installGoogleMapsLoader`, `gm_authFailure`, `waitForGoogleMapsAuthCheck`; add `loadWoosmapSdk`. Keep `handleMapAuthFailure` (renamed) and call it when the script errors or `woosmap.map` is undefined after load.
- [ ] **Step 3:** Rewrite all user-facing copy that says "Google Maps API Key" to "Woosmap API Key"; help text points to `https://developers.woosmap.com/products/map-api/get-started/`. Title becomes "Timeline Viewer (Woosmap)".
- [ ] **Step 4:** In startup, after key resolution, `await loadWoosmapSdk(key)` then `await initMap()`.
- [ ] **Step 5:** Run `tools/check-woosmap.sh`; expected: `googleapis.com` and `importLibrary` counts drop by the loader's occurrences.

### Task 3: Map core, events, theme

**Files:**
- Modify: `timeline-woosmap.html` `initMap` (4698-4745), geolocation button (4745-4775), theme switch (11000-11035), every `google.maps.LatLng`, `LatLngBounds`, `event.addListener*`, `event.trigger`, `e.latLng` site listed by `grep -n "google\.maps\.\(LatLng\|LatLngBounds\|event\)\|e\.latLng"`.

**Interfaces:**
- Produces: `MAP_STYLES = { standard: [], dark: [...] }` module constant; `createMap(center, zoom): woosmap.map.Map` used by `initMap` and the theme switch; `reattachOverlays()` that calls `setMap(map)` on `markers`, `polylines`, `worldMarkers`, `tripMap*` arrays and `homeMapMarker`.
- Consumes: `loadWoosmapSdk` from Task 2.

- [ ] **Step 1:** `initMap` builds the map with `createMap({lat: 25.034170, lng: 121.564560}, 12)`; options: `styles: MAP_STYLES[currentMapTheme]`, `mapTypeControl: true`, `gestureHandling: 'greedy'`. Returns true when `map` exists.
- [ ] **Step 2:** Theme select handler: save setting, `map = createMap(map.getCenter(), map.getZoom())`, `reattachOverlays()`.
- [ ] **Step 3:** Mechanical swaps: `google.maps.LatLng` → `woosmap.map.LatLng`; `google.maps.LatLngBounds()` → `woosmap.map.LatLngBounds()`; `google.maps.event.X` → `woosmap.map.event.X`; `'tilesloaded'` → `'idle'`; `e.latLng` → `e.latlng` in the five trip-map handlers.
- [ ] **Step 4:** Geolocation button creates `new woosmap.map.Marker({position: pos, map})`.
- [ ] **Step 5:** Run the check script; `google.maps.LatLng|LatLngBounds|event` count is 0.

### Task 4: Markers and InfoWindows

**Files:**
- Modify: `timeline-woosmap.html` `renderBasicMarker` (5850-5908), the place marker in `fetchPlaceDetails` (6150-6240), `clearMap` (5455-5470), `addMarkerClickListener` (6402-6427), `addSidebarItemClickListener` (6447-6480), bounds helper (6883-6905), world pins (12128-12215), trip map (14875-15100, 15260-15290), home marker (15363-15415), `infoWindow.open({...})` sites (6416, 6470, 12210).

**Interfaces:**
- Produces: `makePinIcon(color: string, scale = 1): woosmap.map.Icon` returning `{url: 'data:image/svg+xml;utf8,...', scaledSize: {width, height}, anchor: {x, y}}` for a 24x34 teardrop pin; `renderVisitMarker(lat, lng, name, placeVisit, index): void` replacing both old renderers; `openInfoWindow(infoWindow, marker)` wrapper for `infoWindow.open(map, marker)`.
- Consumes: `createMap`, `reattachOverlays` from Task 3.

- [ ] **Step 1:** Add `makePinIcon`. Colours: visit red `#ce5140`, home `#28a745`, airport `#6f42c1`, world pin `#007bff`, trip start `#28a745`, trip end `#dc3545`.
- [ ] **Step 2:** Replace every `new AdvancedMarkerElement({...content})` and `new google.maps.Marker({...})` with `new woosmap.map.Marker({position, map, title, icon: makePinIcon(...)})`. Drop `animation: DROP`. Symbol-path circle markers on trip routes become `makePinIcon(color, 0.5)`.
- [ ] **Step 3:** Replace every `x.map = null` / `x.map = map` with `x.setMap(null)` / `x.setMap(map)`; `marker.map && marker.position` becomes `marker.getMap() && marker.getPosition()`; `map.setCenter(marker.position)` becomes `marker.getPosition()`.
- [ ] **Step 4:** Replace `infoWindow.open({ map, anchor: marker })` with `infoWindow.open(map, marker)`; `tripMapInfoWindow.setPosition(e.latlng); open(map)` keeps that order.
- [ ] **Step 5:** Run the check script; `AdvancedMarkerElement`, `PinElement`, `google.maps.Marker`, `google.maps.InfoWindow` counts are 0. Open the file in Chrome with a key and confirm markers click to open their InfoWindow.

### Task 5: Polylines, arrows, path editing

**Files:**
- Modify: `timeline-woosmap.html` `renderActivitySegment` (6244-6300), `selectPolyline`/`deselectPolyline` (6640-6680), `clearMap`, path edit (9740-9800), trip and home polylines (14880-14960, 15190-15330).

**Interfaces:**
- Produces: `arrowMarkers: woosmap.map.Marker[]` module array; `addDirectionArrows(polyline): void` placing one rotated arrow marker every 90 screen pixels along the path (use `map.getProjection` if available, else every Nth vertex with N = max(1, floor(path.length / 12))); `removeDirectionArrows(): void`; `computePathLengthMeters(path: {lat,lng}[]): number` haversine, Earth radius 6371008.8 m; `bearingDegrees(a, b): number`.
- Consumes: `makePinIcon` pattern from Task 4 for an `makeArrowIcon(): woosmap.map.Icon` (12x12 black chevron SVG).

- [ ] **Step 1:** `new google.maps.Polyline` → `new woosmap.map.Polyline` everywhere; remove the `icons:` options.
- [ ] **Step 2:** `selectPolyline` sets `strokeWeight: 7, zIndex: 1`, then `addDirectionArrows(polyline)`; `deselectPolyline` calls `removeDirectionArrows()` first. Arrow markers use `setRotation(bearing)`.
- [ ] **Step 3:** Path editor: `editable: true` stays; delete the `rightclick` vertex handler; on save use `computePathLengthMeters(newCoords)`.
- [ ] **Step 4:** Check script: `google.maps.Polyline|SymbolPath|googleGeometry` counts are 0. Browser: click a path, arrows appear; click another, only the second has arrows.

### Task 6: Remove Places, cache, counters, autocomplete, photos

**Files:**
- Modify: `timeline-woosmap.html`: DOM 3714-3732 (cache indicator, api controls), 4136-4146 (welcome place-cache section), 4220-4230 and 4381-4440 (`getPlaceStyle`, `placeDetailsCache`), 5220-5260 (counters), 5520-5560 and 5644-5740 (initial-load fetches), 5815-5845 and 5909-6060 (`fetchPlaceDetails`), 6064-6150 (`updateSidebarItem` icon logic), 6305-6400 (`fetchPhotoForInfoWindow`), 6796-6880 (`extractLocationDetails`, `convertPlaceToPlainObject`), 7490-7600 and 10525-10580 (autocomplete API), 8560-8605 (cache controls), 8700-8815 (cache file load), 11960-12120 (fetch-uncached), 12628-12665 (photo import geocoding), 13210-13225.

**Interfaces:**
- Produces: `getVisitName(item): string` returning `placeVisit.location.name || visit.topCandidate.name || semanticLabel(semanticType) || 'Visit'`; `getLocalSuggestions(query)` unchanged and now the only suggestion source.
- Consumes: `renderVisitMarker` from Task 4.

- [ ] **Step 1:** Delete the listed functions and DOM blocks. Every caller of `fetchPlaceDetails`/`fetchPlaceDetailsForInitialLoad` calls `renderVisitMarker(lat, lng, getVisitName(item), placeVisit, index)` directly. `placeDetailsCache` becomes a constant empty object only if a reader remains; otherwise delete it with its readers.
- [ ] **Step 2:** `getPlaceStyle(placeTypes, semanticType)` drops `isFetched`; unknown types map to `'other'`.
- [ ] **Step 3:** Search box: remove `getApiAutocompleteSuggestions`; `displayAutocompleteSuggestions` keeps only the local branch. Edit modal: replace the API search with local suggestions that fill `editPlaceName` only.
- [ ] **Step 4:** Photo import: `name = 'Photo Location'`, `placeId = null`, no fetch.
- [ ] **Step 5:** `readFilesFromDirectory` ignores `TimelinePlaceCache.json`.
- [ ] **Step 6:** Welcome text: replace the "Place Cache" section with one paragraph saying names come from the timeline file and nothing is fetched.
- [ ] **Step 7:** Check script: `new Place(`, `fetchFields`, `places.googleapis` counts 0 and no `fetch(` outside allowed hosts. Browser: load `sample_data/Semantic Location History`; sidebar shows "Times Square". Load a folder containing a dummy `TimelinePlaceCache.json`; no error.

### Task 7: World View and Summary trimming

**Files:**
- Modify: `timeline-woosmap.html` DOM 3455-3475, `renderWorldData` and `populateClickableList` (12128-12315), `applyWorldMapMode` (12390-12450), summary builders (7735-7775, 7800-7870, 7920-7925, 7978-7982, 8067-8071), trips city/country derivation (13210-13225 and `cachedPlacesLived` users).

**Interfaces:**
- Produces: `getWorldPoints(): {position: [lng, lat], weight: number}[]` built from every visit coordinate in `timelineData` (replaces the place-cache source used by `getGridCappedData`).
- Consumes: none.

- [ ] **Step 1:** Remove the Pins/Heatmap toggle and the countries, states, cities lists; World View always shows the heatmap. (Builder call: pins mode depended on city grouping.)
- [ ] **Step 2:** `getGridCappedData` reads from `getWorldPoints()`.
- [ ] **Step 3:** Summary: remove `cities`/`countries` sets and their three "Cities:/Countries:" lines.
- [ ] **Step 4:** Trips: where city/country came from the cache, use `getVisitName` for the stay label and leave flags empty.
- [ ] **Step 5:** Check script passes the grep stage. Browser: Summary view renders yearly bars; World view shows a heatmap.

### Task 8: Heatmap overlay on Woosmap

**Files:**
- Modify: `timeline-woosmap.html` 12395-12450 (overlay creation), 11840-11860 (teardown), `getDynamicHeatmapLayer` (12494).

**Interfaces:**
- Produces: `class WoosmapDeckOverlay { constructor(props); setMap(map|null); setProps(props); }` wrapping a `deck.Deck` on a canvas appended to `map.getDiv()` with `pointer-events: none`, `controller: false`, view state `{longitude, latitude, zoom, bearing: map.getHeading(), pitch: map.getTilt()}` refreshed on `bounds_changed`, plus a `ResizeObserver` on the div.
- Consumes: deck.gl global from unpkg.

- [ ] **Step 1:** Implement the class; `new deck.GoogleMapsOverlay(...)` → `new WoosmapDeckOverlay(...)`.
- [ ] **Step 2:** Browser: open World View, pan and zoom; hot spots stay over the visited cities. If offset by one zoom level, apply `zoom - 1` and note it in the class comment.

### Task 9: README and final verification

**Files:**
- Modify: `README.md` (new section "Woosmap variant")
- Run: `tools/check-woosmap.sh`

- [ ] **Step 1:** README section: what the variant is, that it needs a Woosmap public key, what it does not do (no place lookups, no countries or cities lists), and how to get a key.
- [ ] **Step 2:** Run the check script; expected `OK`.
- [ ] **Step 3:** Browser pass with a key: load each sample folder, open a day, click a marker and a path, switch theme, open Summary, Trips, World. Watch the Network tab: only CDN and `sdk.woosmap.com`/Woosmap tile hosts.
