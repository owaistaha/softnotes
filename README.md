# SoftNotes — SwiftUI foundation

Home dashboard, floating tab bar and app shell recreated from the reference recording. iOS 17+, Xcode 16+, SwiftUI only, no dependencies.

## Setup

1. Xcode → New Project → iOS App (SwiftUI, Swift). Name it `SoftNotes`, deployment target iOS 17.0.
2. Delete the generated `ContentView.swift` and `<Name>App.swift`.
3. Drag the `App`, `DesignSystem`, `Models` and `Features` folders into the project ("Create groups", add to target).
4. Run on an iPhone 15/16 simulator. Every view file has its own `#Preview`.

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
  Home/HomeView.swift        header + folder + recent; publishes FolderFrameKey
  Home/FolderCard.swift      3D folder, chips, count bubble, Notes toggle, FolderShape
  Home/RecentNotesSection.swift
  TabBar/FloatingTabBar.swift  tab bar + PrimaryActionButton (FAB / Next)
  Saved/SavedView.swift
  Compose/ComposeFlowView.swift  STUB — replaced in the next step
```

## Design spec (measured from the recording)

| Token | Value |
|---|---|
| Canvas | `#F0F0F0` |
| Surface (cards) | `#FFFFFF` |
| Tab track | `#E7E6E8`, inner shadow |
| Ink / FAB | `#17161A` |
| Toggle on | `#DCD4FF` bg, `#7B6FE0` text |
| Pastels (back tile) | pink `#FD84A6`, blue `#6CABFD`, lavender `#9087FD` (+ orange, green, yellow, indigo from the picker grid) |
| Note paper | `#FBF8EE` |
| Progress arc | amber `#F5B74A` |
| Folder | 248 × 186 pt front (26 pt tab), back panel 232 pt, chips 48 pt |
| Rows | radius 20, ~62 pt tall, 9 pt gap, 40 pt icon |
| Tab bar | 68 pt tall, 28 pt side inset, 104 pt white pill; FAB 58 pt + 5 pt ring, centred on the bar's top edge |

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
