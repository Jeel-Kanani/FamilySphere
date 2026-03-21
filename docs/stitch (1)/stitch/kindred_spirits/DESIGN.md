# Design System Document: The Digital Keepsake

## 1. Overview & Creative North Star
**Creative North Star: "The Living Scrapbook"**

This design system rejects the cold, utilitarian nature of standard messaging apps in favor of a "Living Scrapbook" aesthetic. We are not just building a utility for communication; we are crafting a digital home for family legacies. 

To move beyond the "template" look of modern chat apps, this system prioritizes **Tonal Depth** over lines and **Organic Asymmetry** over rigid grids. We achieve an editorial, high-end feel by using generous white space (breathing room), sophisticated typography scaling, and layered surfaces that feel like stacked sheets of fine, heavy-weight paper. Every interaction should feel soft, intentional, and emotionally resonant.

---

### 2. Colors: The Warmth of Home
Our palette is rooted in domestic comfort. We move away from pure whites and harsh blacks, opting instead for a "Cream and Charcoal" foundation that reduces eye strain and feels timeless.

*   **The "No-Line" Rule:** 1px solid borders are strictly prohibited for sectioning or containment. Boundaries are defined exclusively through background shifts (e.g., a `surface-container-low` card resting on a `surface` background).
*   **Surface Hierarchy & Nesting:** Use the surface-container tiers to create organic depth. 
    *   *Base:* `surface` (#fbf9f4)
    *   *Raised Content:* `surface-container-low` (#f5f4ee)
    *   *Interaction Points:* `surface-container-highest` (#e3e3db)
*   **The "Glass & Gradient" Rule:** Floating elements (like navigation bars or top headers) should utilize Glassmorphism. Use `surface` at 80% opacity with a `20px` backdrop-blur to allow family photos to peek through the interface.
*   **Signature Textures:** For primary Action Buttons, use a subtle linear gradient from `primary` (#00639f) to `primary-container` (#8dc6ff) at a 45-degree angle. This adds a "jewel-like" depth that a flat color cannot achieve.

---

### 3. Typography: Editorial Clarity
We pair two distinct typefaces to balance the "Friendly" and the "Premium."

*   **Display & Headlines (Plus Jakarta Sans):** Used for large-scale emotional moments (e.g., "Good morning, Grandma"). Its modern, geometric curves feel premium and intentional.
    *   *headline-lg:* 2rem, tight letter-spacing (-0.02em).
*   **Titles & Body (Be Vietnam Pro):** A highly legible, warm sans-serif that handles long-form family stories and quick chats with equal grace.
    *   *body-lg:* 1rem, generous line-height (1.6) to ensure readability for all generations.
*   **Hierarchy Note:** Use `on-surface-variant` (#5e605a) for timestamps and secondary labels to create a soft contrast that doesn't compete with the primary message content.

---

### 4. Elevation & Depth: Tonal Layering
Traditional shadows are a last resort. We communicate "upwards" movement through light.

*   **The Layering Principle:** To lift a card, do not add a shadow. Instead, shift the background from `surface-container` to `surface-container-lowest` (#ffffff). The natural contrast creates a "haptic" visual lift.
*   **Ambient Shadows:** When a floating modal is required, use a "Tinted Ambient Shadow." 
    *   *Value:* `0px 12px 32px`
    *   *Color:* `on-surface` (#31332e) at **4% opacity**.
*   **Ghost Borders:** If an edge must be defined (e.g., inside a photo grid), use `outline-variant` (#b2b2ab) at **15% opacity**. Never use 100% opacity.
*   **Corner Radii:** Our signature look is defined by "The Soft Curve."
    *   Standard Cards: `1.5rem (24px)`
    *   Input Fields/Buttons: `full (9999px)`
    *   Messaging Bubbles: `1rem (16px)` with an asymmetric `2px` radius on the tail-side.

---

### 5. Components: Soft & Intentional

#### Memory-Highlight Cards (Media)
Forbid standard square crops. Use a `lg` (2rem) radius. Media cards should have no borders; instead, they use a `surface-container-high` background as a placeholder to ensure the layout feels "filled" even before the image loads.

#### Buttons
*   **Primary:** Gradient-filled (Primary to Primary-Container), `full` rounded corners, `body-lg` bold text.
*   **Secondary:** `surface-container-highest` background with `on-surface` text. No border.
*   **Tertiary:** Transparent background, `primary` colored text, no underline.

#### Messaging Inputs
Use a floating pill-shape (`full` radius). The background should be `surface-container-low`. Forbid the use of a "Send" icon button that feels like a weapon; use a soft `secondary` (#286c34) circular button with a paper-plane or heart icon to emphasize emotional connection.

#### Lists & Threads
**Strictly no dividers.** Separate family members or chat threads using `spacing-6` (2rem) of vertical white space. Use `title-md` for names and `body-sm` for the "last seen" or preview text.

#### The "Sphere" Interaction Chip
For filtering memories (e.g., "Last Summer," "Christmas 2023"), use `surface-container-highest` chips with `sm` (0.5rem) rounded corners. When active, transition to `primary` with a soft white text.

---

### 6. Do’s and Don'ts

#### Do:
*   **Embrace Asymmetry:** In media galleries, alternate between `2:3` and `1:1` aspect ratios to create a scrapbook feel.
*   **Use Generous Spacing:** Stick to the `16` (5.5rem) and `20` (7rem) tokens for section margins. The app should feel "un-cramped."
*   **Prioritize Accessibility:** Ensure text on `pastel blue` or `soft green` surfaces always uses the `on-primary-container` or `on-secondary-container` tokens for high-contrast legibility.

#### Don't:
*   **No Hard Edges:** Never use a corner radius smaller than `0.5rem` (8px). 
*   **No "Pure" Grey:** Never use #000000 or neutral greys. Every shadow and neutral must be warmed by the `on-surface` (#31332e) charcoal tone.
*   **No Standard Lists:** Avoid the "WhatsApp" list look where every row is identical. Vary font weights and background tints to guide the eye to what's new.