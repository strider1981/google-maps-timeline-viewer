# Woosmap port of the timeline viewer — design

Date: 2026-10-31. Approved in chat by the project owner.

## Intent

Ship a variant of `timeline.html` that renders the same Google Maps Timeline data
with the Woosmap Map JS API and no Google key. Woosmap is used only to draw the
map. Every name, coordinate, path and statistic comes from the loaded timeline
file. No other network call is made, apart from the CDN libraries already in use.

## Goals

- `timeline-woosmap.html` next to the original; the original keeps working.
- Same features: file loading (Takeout, Android, iOS), timeline list, day and
  multi-day map view, travel-mode colours, direction arrows on a selected path,
  distance and duration stats, trips view, timezone detection (offline library),
  visit and route editing, KML export, photo GPS import, settings import/export,
  mobile layout, World View heatmap.
- Only one key: a Woosmap public key, prompted and remembered exactly as the
  Google key was.

## Non-goals and anti-goals

- No Woosmap Localities, Places, Geocoding or any data API. Any fetch to a
  non-CDN host is a defect.
- No Google Place Details, Places Autocomplete, Geocoding or Street View.
- No countries or cities lists in World View, no city or country counts in the
  Summary view: the data does not carry them.

## Decisions

- Visit title = `name` from the timeline object (Takeout `placeVisit.location.name`,
  on-device `visit.topCandidate.name`). Fallback: semantic type label (Home, Work)
  then "Visit".
- Place-name search box searches only names in loaded data.
- Removed wholesale: Place Details fetches and cache, API call counter,
  "Disable API" toggle, place-icon glyphs, Google photo fetch, place-cache
  file load/save, Google reverse geocoding for photo import.
- Map objects: `woosmap.map.Map`, `Marker` (SVG data-URL icon, label),
  `Polyline`, `InfoWindow`, `LatLng`, `LatLngBounds`, `event`. Click events read
  `e.latlng`. InfoWindow opens with `open(map, anchor)`. Markers attach with
  `setMap`, never a `.map` property.
- Direction arrows: Woosmap polylines have no `icons`, so selecting a path adds
  small rotated arrow markers along it; deselecting removes them.
- Route editing: `editable: true` polyline, path read back on save. Right-click
  vertex deletion is dropped (no such event in Woosmap).
- Path length on save: inline haversine over the path.
- Map theme: `styles` arrays for light and dark; switching recreates the map and
  reattaches overlays, the same pattern the Google version uses.
- Heatmap: deck.gl `Deck` on a canvas over the map container, view state synced
  from map center/zoom/heading/tilt on `bounds_changed`.
- Script tag: `https://sdk.woosmap.com/map/map.js?key=<key>&callback=initWoosmap`,
  injected at runtime once the key is known. Key resolution order and UI copy
  mirror the original, with Google wording replaced.

## Left to the builder

- Exact SVG pin shape and sizes.
- Light and dark style JSON.
- Wording of README section for the Woosmap variant.
