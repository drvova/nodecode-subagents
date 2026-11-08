---
name: source-artwork-3d-animation
description: Reverse-engineer real vector or 2D character artwork and turn it into faithful, attached, loopable 3D animation for product pages, documentation, or media assets.
---

# Source Artwork to 3D Animation

## Purpose

Reconstruct an existing mascot, logo, or illustrated character from its real source asset, then build and verify a faithful 3D animation. Preserve the source identity; do not substitute an approximate redraw when the original geometry is available.

## Activate When

- A real website, app, or repository contains artwork that must be inspected and animated.
- A user wants a vector mark, sprite, or illustrated character converted into layered 3D motion.
- An existing animation looks flat, detached, mechanically hinged, or unlike the source.
- Documentation needs reproducible animated media plus a reduced-motion fallback.

## Required Workflow

1. **Inspect the rendered source.** Open the real page or asset, not only a screenshot. Locate the source in the DOM, network resources, repository, or export pipeline. Record its dimensions, coordinate system, colors, layers, cropping, and responsive variants.
2. **Reverse-engineer actual behavior.** Observe pointer, hover, idle, and scroll states. Determine whether motion comes from SVG path changes, CSS, JavaScript, canvas, video, or a 3D rig. Separate confirmed behavior from inference; never describe a 2D source as a downloaded 3D model.
3. **Preserve provenance and geometry.** Keep an unmodified source copy and record its URL or repository path. Retain path order, fills, transforms, and coordinate units. Use a standards-based parser for arbitrary SVG; use a narrow parser only when the source grammar is verified, and reject unsupported commands instead of silently dropping geometry.
4. **Choose a representation that fits the source.** Use layered extrusion for flat, color-separated art; use a mesh or deforming rig when the source needs curved volume or continuous deformation. Preserve the original silhouette, scale, and orientation. Avoid unnecessary remeshing or hand-redrawing.
5. **Build connected parts deliberately.** Partition only where the character can plausibly bend. Place pivots at observed attachment points. Keep shoulder, hip, or root geometry attached; overlap or deform joint geometry when independent rigid pieces would expose gaps. Do not classify anatomy using broad coordinate cuts without checking the resulting silhouette.
6. **Design a deterministic motion cycle.** Make the main action readable, then add restrained secondary motion such as body sway, breathing, gill or ear movement, and blinking. Use stable frame-based timing or the host framework's equivalent. Offset phases between paired parts; make the final frame return cleanly to the first.
7. **Compose for the delivery surface.** Use the existing project stack and its supported APIs. Match camera, lighting, background, scale, and crop to the source context. For GitHub Markdown, use a supported animated image and a static image for reduced-motion preference; do not rely on embedded interactive canvas or video behavior.
8. **Render, inspect, and refine.** Inspect the source beside representative output frames at final display size. Check the loop seam, joint roots, full stroke extremes, face, silhouette, occlusion, z-fighting, clipping, and color order. Repair the underlying partition or pivot before merely shrinking the animation until the defect is hidden.
9. **Make regeneration reproducible.** Check in source data, model/composition code, and the exact generation commands. Regenerate all affected GIFs, videos, stills, and previews after geometry or motion changes. Verify the rendered README or target page, including reduced-motion output and alt text.

## Tool Selection

Use the tools already supported by the project. Inspect their current documentation before relying on a renderer, geometry API, browser probe, or encoder. A browser inspector, SVG parser, mesh/3D framework, offline renderer, and media encoder are implementation choices—not required dependencies of this skill. Keep tool-specific commands in project scripts, not in this workflow.

## Deliverables

- A source asset or documented, reproducible extraction path.
- Structured geometry or a model source derived from that asset.
- A rig/composition with deterministic timing and connected joints.
- Final animated media and a still fallback when the destination needs one.
- Regeneration instructions and verified examples at key frames.

## Acceptance Checklist

- [ ] Dimensions, fills, layers, and distinctive silhouette trace back to inspected source evidence.
- [ ] Unsupported source geometry is detected, not silently omitted.
- [ ] Every moving part remains visually attached through its full stroke.
- [ ] The loop closes without a visible pose jump.
- [ ] The delivered format, crop, resolution, and file size suit the target surface.
- [ ] Reduced-motion and text alternatives are present where applicable.
- [ ] A clean regeneration reproduces the checked-in deliverables.
