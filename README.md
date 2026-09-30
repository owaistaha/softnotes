# SoftNotes — SwiftUI foundation

Home dashboard, floating tab bar and app shell recreated from the reference recording. iOS 17+, Xcode 16+, SwiftUI only, no dependencies.

## Setup

1. `brew install xcodegen`
2. `xcodegen generate` — builds `SoftNotes.xcodeproj` from `project.yml` (the project file is git-ignored; never hand-edit it).
3. Open `SoftNotes.xcodeproj` and run on an iPhone simulator (a ~393–402 pt Pro is closest to the reference). Every view file has its own `#Preview`.
4. For frame comparisons, put the recording at `Reference/reference-walkthrough.mov` (git-ignored).

## Structure

```
App/
  SoftNotesApp.swift         @main, forces light mode
  RootContainerView.swift    shell: canvas, tabs, tab bar, compose overlay, save choreography
DesignSystem/
  Theme.swift                palette, pastel tones, metrics, springs, type
  SoftSurface.swift          layered shadows, SoftSurface, pressable style, blur transitions, idle float
  StackedIconView.swift      the two-tile glass icon
Models/
  Note.swift                 Note, NoteIcon, icon library (12), samples, relative time
  NotesStore.swift           @Observable store
Features/
  Home/                      HomeView (publishes FolderFrameKey), FolderCard, RecentNotesSection
  TabBar/FloatingTabBar.swift  tab bar + PrimaryActionButton (FAB / Next)
  Saved/SavedView.swift
  Compose/ComposeFlowView.swift  compose flow shell (nav bar, step switch, Next button)
  Compose/ComposeDraft.swift     compose state (step, icon, text)
  Compose/IconPickerStep.swift   03 Pick an icon
  Compose/WriteStep.swift        04 Write a chit
  Compose/NoteCardView.swift     the paper card (pose + single-view content)
  Compose/KeyboardOverlapPadding.swift  iOS 26 keyboard safe-area fix
SoftNotesUITests/                UI tests + screenshot/video tooling (see CLAUDE.md)
scripts/                         ui-shots.sh, video-disc-track.py, video-ring-track.py, fab-morph-stats.py
```

## Design spec (measured from the recording)

| Token | Value |
|---|---|
| Canvas | `#F0F0F0` |
| Surface (cards) | `#FFFFFF` |
| Tab track | `#E7E6E8`, inner shadow |
| Ink / FAB | `#17161A` |
| Toggle on | `#E2DAFF` bg, `#7B6FE0` text; 116 × 46 pt, 40 pt knob |
| Pastels (back tile) | pink `#F77696`, blue `#5A9AF6`, lavender `#9E81F6`, orange `#FB9A4B`, green `#63C36C`, yellow `#FFBF55`, indigo `#837AF1` (calibrated to the reference picker) |
| Note paper | `#FFFDFA`, tag chip `#F5EFE5`; card 236×258 pt, −3° at rest, ×1.2 / −1.5° while typing |
| Progress arc | amber `#F5B74A` |
| Folder | 235 × 174 pt front (25 pt tab, flat top to 0.38 of width + 27 pt curve), back panel 221 pt, chips 48 pt, count bubble 46 pt |
| Rows | 16 pt screen inset (header text at 20), radius 20, ~58 pt tall, 6 pt gap, 40 pt icon 8 pt from the edge, title 16 pt medium |
| Tab bar | 73 pt tall, 31 pt side inset, 104 pt white pill, no outline; FAB 62 pt + 5 pt canvas halo, centred on the bar's top edge |
| Header | fixed English date "Tuesday, 28 September"; 46 pt search button centred on date + title |
| Glyphs | thin outline SF Symbols (non-`.fill`), regular weight |

## Motion already wired

- **Tab switch** — white pill slides via `matchedGeometryEffect`; inactive icon desaturates; content swaps with a blur-fade.
- **FAB → Next** — the `+` morphs into the compose flow's `→` button (shared `flowNamespace`); tab track drops away, Home recedes (scale 0.94 + blur).
- **Folder** — drag to tilt in 3D (springs back), chips parallax and idle-float, toggle opens/closes the front panel on a bottom hinge.
- **Save (Home side)** — folder opens → chip drops into the centre slot, count rolls 8 → 9, folder bounces, new row focus-pulls into Recent → toggle flips on. Success haptic.

## Reference choreography for the next step (05 Save → 06 Fold → 07 File it away)

Observed in the recording, roughly 3 s end to end:
1. Tap Next on the written card → nav/title fade out; the chosen icon rises and sits on the card's top edge.
2. The card's top half folds down over the bottom half (x-axis rotation with shading on the flap) → a half-height card.
3. Camera pushes toward the bottom: the folder rises into view, large; the folded card drops behind the front panel with a blur.
4. The icon lands in the centre chip slot; count 8 → 9; ~0.3 s later the toggle flips on.
5. Zoom out to Home; the new row slides in at the top of Recent.
