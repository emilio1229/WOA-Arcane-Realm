# Arcane Realm asset brief templates

Use these as working templates. Fill known details from the repository; ask only when a missing decision would materially change the result.

## Single asset
- **Asset ID:**
- **Name/category:**
- **Purpose/gameplay context:**
- **Scene/region/screen:**
- **Camera/viewing distance:**
- **Target dimensions/aspect ratio:**
- **Format/transparency/pivot:**
- **Animation states and timing:**
- **Palette/materials/lighting:**
- **Style references and approved neighboring assets:**
- **Performance/accessibility requirements:**
- **Source/license/attribution:**
- **Dependencies/integration points:**
- **Acceptance criteria:**

## Asset family
- **Family name and shared visual rules:**
- **Required members and stable IDs:**
- **Shared scale/perspective/palette/material language:**
- **Allowed variations:**
- **Animation/state coverage:**
- **Common atlas or loading strategy:**
- **Dependencies and intended scene:**
- **Acceptance criteria for consistency:**

## Visual audit report
1. Scope inspected and commit/ref.
2. Existing inventory by category and status.
3. Original/integrated/procedural/placeholder classification.
4. Quality issues with file/scene evidence.
5. Missing asset families.
6. Risks: renderer, licensing, performance, mobile readability.
7. Prioritized improvements and rationale.
8. Proposed first batch.
9. Validation commands/results.
10. Unverified areas and next actions.

## Asset prompt construction
Prompts should describe:
- Subject and exact intended use in the game.
- Camera angle/perspective and silhouette.
- Composition and safe margins.
- Materials, lighting, palette, and level of detail.
- Background/alpha requirements.
- Consistency anchors from approved Arcane Realm assets.
- Exact dimensions/aspect ratio and sprite-sheet grid if relevant.
- Explicit exclusions: text, logos, watermarks, extra limbs, clipped silhouettes, unwanted background, inconsistent frame sizes, or invented UI lettering.

Do not put essential geometry, readable labels, or required interactive behavior solely into an image-generation prompt. Build those as actual game/UI elements.
