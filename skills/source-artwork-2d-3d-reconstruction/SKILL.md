---
name: source-artwork-2d-3d-reconstruction
description: Reverse-engineer existing artwork and animation, reproduce its 2D appearance and behavior faithfully, and build a source-faithful 3D version when requested.
---

# Source Artwork: Faithful 2D and 3D Reconstruction

## Purpose

Reconstruct a real logo, mascot, sprite, or character from inspected source evidence. Support a 2D reproduction, a 3D reconstruction, or both. Treat source geometry and observed behavior as the authority; do not replace them with a merely similar design.

## Activate When

- A user wants an existing website or product mascot recreated closely.
- The task includes both the original 2D animation and a 3D version.
- A screenshot looks simple but the real site may use hidden SVG, sprite, canvas, video, or 3D assets.
- A current reconstruction differs in silhouette, animation, proportions, color, or attachment.

## Fidelity Contract

Choose the requested output tracks: `2D`, `3D`, or `both`.

- **2D source available:** Preserve and reuse the actual vector paths, pixel cells, sprite frames, or decoded source data. Match its viewBox/canvas, dimensions, palette, frame timing, registration, interaction, crop, and responsive behavior. Do not substitute a redrawn approximation when the source is accessible.
- **Original 3D source available:** Recover and reuse the actual model, mesh, materials, camera, rig, animation curves, and scene settings where possible. Compare the rendered result under matching conditions.
- **Only 2D source available for a 3D request:** Match the observable 2D silhouette, palette, and motion. Depth, hidden surfaces, thickness, and unseen anatomy cannot be recovered exactly from a flat image; infer only what is needed, label those choices, and do not claim the hidden 3D is 1:1.
- **Exact pixels requested:** Use same-size captures and pixel/alpha comparison. Separate genuine geometry differences from browser, color-management, and renderer differences. State any unavoidable mismatch rather than calling a visual approximation pixel-identical.

## Required Workflow

1. **Capture the reference states.** Inspect the real page or source asset, not only a supplied still. Record viewport, device scale, background, crop, and dimensions. Capture idle, hover, focus, pointer, scroll, responsive, and reduced-motion states that affect the artwork.
2. **Find the source assets and runtime.** Inspect DOM, network resources, repository files, scripts, styles, source maps, model files, and metadata. Determine whether the visible result is SVG, raster frames, a packed cell grid, canvas, video, or 3D. Trace the playback loop, frame rate, event triggers, and stop behavior.
3. **Build an evidence map.** Record verified facts separately from inferences: original asset and source location; coordinates and palette; frame or model data; interaction and timing; rendering environment; unresolved details. A compiled frame format does not identify its authoring application. Never invent a tool, source model, or unseen 3D detail.
4. **Preserve and validate source data.** Keep an unmodified copy and provenance. Use a standards-compliant parser for general SVG/model formats. A narrow parser is acceptable only when the source grammar is verified and the parser rejects unsupported forms. For custom packed frames, inspect the decoder first, document dimensions and field encoding, validate bounds, and round-trip a sample before editing.
5. **Reproduce the 2D track.** Retain exact path order, fills, transforms, pixel grid, frame registration, and frame count. If only a rendered reference is recoverable, recreate at its native coordinates and palette, then compare overlays and silhouettes; do not imply this is the original source file. Preserve interaction timing and accessible pointer, keyboard-focus, and reduced-motion behavior.
6. **Build the 3D track.** Prefer recovered source meshes and rigs. If none exist, derive the visible form from the 2D geometry: extrude layered vectors or cells for flat art, or construct a mesh when curved volume is evidenced. Keep the front silhouette and color boundaries faithful. Place joints at actual attachment points; overlap or deform roots to prevent gaps. Explicitly list inferred depth, back surfaces, and rig choices.
7. **Match motion across tracks.** Reuse observed frame timing, key poses, loop length, direction, and interaction semantics. For 2D, render or select the correct source frame. For 3D, animate the source-faithful geometry with corresponding poses and contact points. Add secondary motion only when observed or clearly marked as an adaptation.
8. **Validate by comparison.** Render both versions at matched size, view, background, and time. Use image overlays, difference images, silhouette masks, bounding boxes, palette checks, and frame contact sheets as appropriate. Inspect the first/last loop frames, every key pose, maximum articulation, clipping, occlusion, z-fighting, and joint attachment. If an original 3D model exists, compare its geometry and render rather than relying on appearance alone.
9. **Deliver reproducibly.** Keep original assets, extraction/decoding code, source-derived model, animation code, generated media, and exact regeneration commands. For documentation surfaces, provide a supported animation format, a static reduced-motion fallback, and useful alt text. Verify the rendered target page or README.

## Tool Selection

Use tools and libraries already supported by the project; inspect their actual APIs and versions before implementation. Browser inspection, SVG/model parsers, pixel editors, 2D renderers, 3D frameworks, encoders, and comparison tools are interchangeable implementation choices, not dependencies of this skill. Keep tool-specific commands in project scripts and keep this workflow provider-agnostic.

## Deliverables

- Reference-state captures and a short evidence-versus-inference note.
- Preserved source assets or a reproducible extraction/decoding path.
- The requested 2D animation, 3D reconstruction, or both.
- Validation images or frame comparisons at matched conditions.
- Regeneration instructions and reduced-motion/accessibility assets where applicable.

## Acceptance Checklist

- [ ] The requested 2D/3D tracks are complete; no requested mode was silently substituted.
- [ ] Accessible 2D source geometry and animation data remain source-faithful.
- [ ] 3D claims distinguish recovered model data from inferred volume.
- [ ] Silhouette, palette, pose, timing, and interaction are checked against actual references.
- [ ] Moving geometry stays connected through its full articulation.
- [ ] Loop boundaries, reduced motion, and target rendering are verified.
- [ ] Rebuilding from checked-in sources reproduces the delivered results.
