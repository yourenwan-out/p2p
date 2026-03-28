# Design System Document

## 1. Overview & Creative North Star: "The Mastermind’s Dossier"

This design system moves away from the flat, predictable grids of standard mobile apps to embrace the clandestine, high-stakes atmosphere of international espionage. Our Creative North Star is **"The Mastermind’s Dossier"**—a digital interface that feels like a collection of tactical intel layered on a high-tech terminal.

We achieve this through **Layered Intentionality**. Instead of separating content with rigid lines, we use depth, subtle tonal shifts, and "Glassmorphism" to create a sense of physical space. Elements overlap and breathe, utilizing the **Spacing Scale** to create a rhythmic, editorial flow. The experience should feel premium, bespoke, and authoritative, balancing the playful tension of a board game with the sophistication of a high-end digital product.

---

## 2. Colors & Signature Textures

The palette is a vibrant collision of deep oceanic blues and high-energy oranges and reds. 

*   **The "No-Line" Rule:** We do not use 1px solid borders to define sections. Layout boundaries are created exclusively through background color shifts. For example, a `surface_container_low` card should sit directly on a `surface` background. The contrast in value provides the boundary.
*   **Surface Hierarchy:** 
    *   **Base:** `surface` (#001429) for the primary application background.
    *   **Low Elevation:** `surface_container_low` (#001d36) for secondary content areas.
    *   **High Elevation:** `surface_container_highest` (#183655) for active play areas or interactive modules.
*   **The "Glass & Gradient" Rule:** Use `backdrop-blur` (12px–20px) combined with semi-transparent surface colors (e.g., `surface_bright` at 60% opacity) for floating modals and navigation bars.
*   **Signature Textures:** For primary action buttons and headers, use a linear gradient from `primary` (#ffb77a) to `primary_container` (#f28e26) at a 135-degree angle. This adds "soul" and a tactile, physical quality to the UI.

---

## 3. Typography: Editorial Authority

We use a high-contrast typographic scale to differentiate between "Intel" (UI labels) and "The Mission" (Game content).

*   **Display & Headlines:** Using **Space Grotesk**. This typeface provides a technical, slightly brutalist edge that feels like classified headings. Use `display-lg` for game-over states and `headline-md` for team names.
*   **Body & Titles:** Using **Manrope**. This is our workhorse font. It’s clean, highly legible on small screens, and provides a neutral balance to the aggressive headings.
*   **Labels:** Using **Plus Jakarta Sans**. Specifically for micro-copy and metadata.
*   **Editorial Intent:** Use intentional asymmetry—left-aligned headlines paired with right-aligned body copy—to break the "template" feel and guide the eye dynamically across the dossier.

---

## 4. Elevation & Depth: Tonal Layering

Shadows and borders are secondary to the concept of **Tonal Stacking**.

*   **The Layering Principle:** Depth is achieved by stacking `surface-container` tiers. A `surface_container_lowest` card placed on a `surface_container_low` section creates a natural "recessed" look.
*   **Ambient Shadows:** For "floating" elements like a Game Timer or Team Indicator, use an extra-diffused shadow: `box-shadow: 0 20px 40px rgba(0, 20, 41, 0.4);`. The shadow color is a dark tint of our `on_surface` color, never a flat black, to ensure it looks integrated into the atmosphere.
*   **The "Ghost Border" Fallback:** If a container requires further definition (e.g., in high-glare environments), use a "Ghost Border": `outline-variant` (#554336) at 15% opacity. Never use 100% opaque lines.
*   **Glassmorphism:** Apply to floating HUD elements (like the Timer). By letting the background card colors bleed through the blur, the UI feels deep and multi-dimensional.

---

## 5. Components

### Cards (The "Codename" Cards)
Cards must not have borders. Use `surface_variant` for neutral cards. Red team cards use a gradient of `tertiary_container` to `tertiary`. Blue team cards use `secondary_container` to `secondary`.
*   **Corner Radius:** Use `md` (0.75rem) for cards to maintain a tactile, "hand-held" feel.
*   **Padding:** Use `spacing.4` (1rem) for internal content.

### Buttons
*   **Primary:** Gradient of `primary` to `primary_container`. Text color `on_primary_container`. Shape: `full` (pill-shaped) for high-importance actions like "Give Clue."
*   **Secondary:** Ghost style using a `surface_bright` background with no border.
*   **Tertiary:** Text-only with an underline at 20% opacity of the font color.

### Team Indicators & Clear Timer
*   **Timer:** A floating glassmorphic circle in the top right. Uses `headline-sm` for the countdown. A circular progress ring uses the `primary` color to show remaining time.
*   **Team Score:** Use `surface_container_high` as a base. Red team scores are accented with `tertiary`; Blue with `secondary`. Use `title-lg` for the numeric value.

### Input Fields
*   Forgo the traditional "box." Use a `surface_container_lowest` background with a 2px bottom accent in `outline` (#a38d7c). When focused, the bottom accent transitions to `primary`.

### Lists & Content Rows
*   **Forbid Dividers:** Separate list items using `spacing.3` (0.75rem) of vertical white space or a subtle background toggle between `surface_container_low` and `surface_container_lowest`.

---

## 6. Do's and Don'ts

### Do:
*   **Do** use `spacing.8` (2rem) and `spacing.10` (2.5rem) to create distinct editorial sections.
*   **Do** overlap elements (e.g., a card slightly overhanging a section header) to create visual depth.
*   **Do** use `primary` (#ffb77a) for critical interaction points to ensure high contrast against the dark `surface`.

### Don't:
*   **Don't** use black (#000000) for shadows; use a dark blue tint from the `surface` palette.
*   **Don't** use 1px solid borders for layout containment.
*   **Don't** use more than three levels of nested containers. If you need more, use a full-screen transition or a modal overlay.
*   **Don't** center-align long passages of text. Keep game rules and instructions left-aligned for an editorial feel.