---
name: kartikarora-swiftui
description: Implements the @kartikarora brand design system and production SwiftUI components for iOS, macOS, iPadOS, and watchOS apps. Defines Color tokens (dynamic light/dark palette), Typography (Albert Sans & JetBrains Mono), Spacing (8pt grid), Shapes/CornerRadii, and signature brand components (BrandButton, StatusBadge, ArtifactRow, CLICommandPill, StanceView, KeynoteRow, BrandStatement).
version: 2.0.0
last-updated: 2026-11-06
maintained-by: Kartik Arora (@kartikarora)
---

# @kartikarora Brand SwiftUI Component System (v2.0.0)

This skill provides the official **SwiftUI Design System & Production Components** for Apple platforms (iOS, macOS, iPadOS, watchOS, visionOS). It ensures all native UI automatically adheres to `@kartikarora` brand guidelines across colors, typography, shapes, spacing, and animations.

---

## ⚠️ Strict Mandates for AI Agents

1. **Brand Fidelity:** All views must use the semantic tokens defined in `Color.brand`, `Font.brand*`, `BrandSpacing`, and `BrandCornerRadius`. Never use raw hex colors or arbitrary padding.
2. **Dynamic Light & Dark Support:** Use `Color.brand` semantic tokens which automatically adapt between the light canvas (`#FFFFFF`) and the signature dark studio canvas (`#000000` pitch black).
3. **Typography Standard:** Use **Albert Sans** for display and body text, and **JetBrains Mono** for code, CLI snippets, and technical telemetry. Display headings must apply `-0.03em` tracking.
4. **8pt Spacing Grid:** Use `BrandSpacing` (`xxs: 4`, `xs: 8`, `sm: 16`, `md: 24`, `lg: 32`, `xl: 48`, `xxl: 64`, `xxxl: 96`) instead of hardcoded numbers.
5. **No Card Envelopes for Showcases:** Use the full-bleed `ArtifactRow` and `StanceView` layouts with hairline dividers (`Color.brand.rule`) rather than wrapping every element in a rounded card.
6. **Accessible Touch Targets:** Interactive controls must maintain a minimum 44×44pt tap target on iOS/iPadOS and support instant `:focus-visible` on macOS and iPadOS pointer interactions.
7. **Fast Fluid Motion:** Use standard iOS spring animations with fast response (`Animation.spring(response: 0.22, dampingFraction: 0.8)`).
8. **Brand Synchronization:** This skill derives directly from [`tokens/design-tokens.json`](../../tokens/design-tokens.json). Re-run `make tokens` whenever tokens are updated.

---

## 🎨 Semantic Token Mapping

| Web / SSOT Token | Light Hex | Dark Hex | SwiftUI Semantic Token | Usage |
| :--- | :--- | :--- | :--- | :--- |
| `--color-paper` | `#FFFFFF` | `#000000` | `Color.brand.canvas` | Base screen canvas background |
| `--color-paper-alt` | `#F6F8FA` | `#0A0A0A` | `Color.brand.surface` | Grouped containers, wells, sidebars |
| `--color-paper-sunken` | `#EAEEF2` | `#050505` | `Color.brand.surfaceSunken` | Code blocks, CLI pills |
| `--color-ink` | `#0D1117` | `#F0F4F8` | `Color.brand.ink` | Primary display headings and body text |
| `--color-ink-muted` | `#57606A` | `#8C9BA5` | `Color.brand.inkMuted` | Secondary text, subtitles, metadata |
| `--color-ink-faint` | `#8D96A0` | `#64748B` | `Color.brand.inkFaint` | Tertiary labels, disabled states |
| `--color-signal` | `#0066CC` | `#818CF8` | `Color.brand.signal` | Interactive accent (Precision Cobalt / Electric Indigo) |
| `--color-signal-hover` | `#0052A3` | `#A5B4FC` | `Color.brand.signalHover` | Pressed / hover state |
| `--color-signal-wash` | `10% Alpha` | `15% Alpha` | `Color.brand.signalWash` | Translucent background washes |
| `--color-rule` | `12% Black` | `8% White` | `Color.brand.rule` | Hairline dividers and borders |
| `--color-success` | `#2DA44E` | `#3FB950` | `Color.brand.success` | Status badges, passing tests |
| `--color-danger` | `#CF222E` | `#F85149` | `Color.brand.danger` | Error states, deprecation badges |
| `--color-warning` | `#BF8700` | `#D29922` | `Color.brand.warning` | Alerts, draft states |

---

## 📦 Component Library Reference

All components are located in [`references/Components.swift`](references/Components.swift):

### 1. `BrandButton`
High-contrast pill buttons (`.primary`, `.outline`, `.ghost`, `.small`, `.liquidGlass`):
```swift
BrandButton("Launch Platform", style: .primary) {
    launchURL()
}

// Apple-Grade Liquid Glass Button (refractive frosted glass with tactile spring)
BrandButton("Deploy Build", icon: "sparkles", style: .liquidGlass) {
    deploy()
}
```

### 2. Liquid Glass Surfaces (`.liquidGlass()`, `.liquidGlassPill()`)
Apply native Apple optical depth combining `.ultraThinMaterial`, specular beveled borders, and ambient light refraction:
```swift
// Any view or container to liquid glass
VStack(alignment: .leading, spacing: BrandSpacing.sm) {
    Text("Live Telemetry").font(.brandHeadline)
    Text("99.98% uptime across Sydney nodes").font(.brandBody)
}
.padding(BrandSpacing.md)
.liquidGlass(cornerRadius: BrandCornerRadius.lg)

// Full-round floating pill
HStack {
    Image(systemName: "circle.fill").foregroundColor(Color.brand.success)
    Text("Active Deployment")
}
.padding(.horizontal, BrandSpacing.sm)
.padding(.vertical, BrandSpacing.xs)
.liquidGlassPill()
```

### 3. `LiquidGlassCard` & `LiquidGlassPill`
Pre-built glassmorphic containers for floating panels and status bars:
```swift
LiquidGlassCard {
    Text("Frosted Glass Metric Card")
}

LiquidGlassPill {
    Text("Sydney · 120Hz")
}
```

### 2. `StatusBadge`
Translucent status indicators (`.win`, `.loss`, `.draft`, `.gde`):
```swift
StatusBadge("GDE Android", variant: .gde)
```

### 3. `ArtifactRow`
Full-bleed production software showcase with CLI pill and direct action:
```swift
ArtifactRow(
    tag: "Tooling / 2026",
    badge: "GraalVM Native",
    title: "Klaat",
    summary: "Native CLI compiler converting Google Docs into interactive codelabs.",
    cliCommand: "klaat compile --source ./spec.gdoc",
    actionTitle: "Launch codelab",
    action: { launchKlaat() }
)
```

### 4. `CLICommandPill`
Terminal command execution pill with one-tap copy:
```swift
CLICommandPill(command: "rocketflag.evaluate(\"dark_launch\")")
```

### 5. `StanceView`
Editorial architectural invariant presentation:
```swift
StanceView(
    title: "Declarative Compose Performance",
    bodyText: "UI is a pure reflection of state. Hoisting state cleanly guarantees steady 120Hz frame rates."
)
```

### 6. `KeynoteRow`
Symposium ledger item for conference presentations:
```swift
KeynoteRow(
    year: "2024",
    location: "Sydney",
    title: "High-Performance Multiplatform Runtimes",
    event: "Android Developer Conference",
    slidesURL: URL(string: "https://..."),
    videoURL: URL(string: "https://...")
)
```

---

## 🗂 Reference Implementation Files

- [`references/Color.swift`](references/Color.swift) &mdash; Color tokens with dynamic dark/light support
- [`references/Spacing.swift`](references/Spacing.swift) &mdash; 8pt spacing grid constants
- [`references/Shape.swift`](references/Shape.swift) &mdash; Corner radii and shape styles
- [`references/Typography.swift`](references/Typography.swift) &mdash; Font styles and text modifiers
- [`references/Components.swift`](references/Components.swift) &mdash; Complete SwiftUI component implementations
- [`references/Theme.swift`](references/Theme.swift) &mdash; Environment keys and view modifiers
