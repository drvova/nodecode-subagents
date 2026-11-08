# Nodecode Subagents

<p align="center">
  <picture>
    <source media="(prefers-reduced-motion: reduce)" srcset="artwork/subagents-hero.png" />
    <img src="artwork/subagents-hero.gif" alt="The source-derived axolotl banks through a layered 3D swim cycle, with independent gill fanning, out-of-phase paddles, body breathing and a quick blink beside the subagents workflow." width="100%" />
  </picture>
</p>

<p align="center">
  <a href="#install">Install</a> ·
  <a href="#configure">Configure</a> ·
  <a href="#eval-apis">Eval APIs</a> ·
  <a href="#sessions-and-coordination">Sessions and coordination</a>
</p>

An OMP-style Nodecode cell for parallel child sessions and IRC-style coordination on Nodecode's durable Board. Nodecode's built-in `eval` is the sole model tool; this cell adds reusable Lisp APIs, not provider-facing tools.

## Install

<p align="right">
  <picture>
    <source media="(prefers-reduced-motion: reduce)" srcset="artwork/media/axolotl-setup-still.png" />
    <img src="artwork/axolotl-setup.gif" alt="A source-derived 3D axolotl swims beside the installation steps, fanning its gills, paddling its limbs and blinking briefly." width="200" />
  </picture>
</p>

Clone this repository into Nodecode's local cells directory, then restart Nodecode or run `(restart-cells)`:

**Windows · PowerShell**

```powershell
git clone https://github.com/drvova/nodecode-subagents "$HOME\.nodecode\cells\nodecode-subagents"
```

**macOS · Linux**

```sh
git clone https://github.com/drvova/nodecode-subagents "$HOME/.nodecode/cells/nodecode-subagents"
```

Nodecode must have local-cell loading enabled. Install and enable the `nodecode-board` cell as well; it provides the durable board used for coordination.

## Configure

<p align="right">
  <picture>
    <source media="(prefers-reduced-motion: reduce)" srcset="artwork/media/axolotl-configure-still.png" />
    <img src="artwork/axolotl-configure.gif" alt="The source-derived axolotl turns and paddles beside configuration instructions, its gills and limbs moving independently." width="200" />
  </picture>
</p>

Enable both cells in `~/.nodecode/config.jsonc`:

```jsonc
{
  "board": { "enabled": true },
  "subagents": {
    "enabled": true,
    "max_agents": 4
  }
}
```

`max_agents` accepts 1–5 and controls concurrency only. This cell adds no per-worker or team-wide token/time ceiling and does not override Nodecode's turn-budget policy. Workers inherit the parent's model selection; Nodecode and the selected provider/model remain responsible for their own limits.

When upgrading from 0.1.x, remove `budget_tokens` and `budget_seconds` from `~/.nodecode/config.jsonc`; the cell no longer reads them.

## Eval APIs

<p align="right">
  <picture>
    <source media="(prefers-reduced-motion: reduce)" srcset="artwork/media/axolotl-eval-apis-still.png" />
    <img src="artwork/axolotl-eval-apis.gif" alt="A source-derived 3D axolotl swims through a seamless loop beside the eval API section, with a quick blink and independently moving gills." width="200" />
  </picture>
</p>

The cell exports `subagents:task`, `subagents:agents`, and `subagents:irc`. Call them as Common Lisp forms through Nodecode's built-in `eval`:

```lisp
(subagents:task '((:name "worker" :task "Inspect the parser and report findings."))
                :context "The goal is to identify parsing edge cases.")
(subagents:agents "list")
(subagents:irc "send" :message "I found an edge case in the parser.")
```

`task` has signature `(task tasks &key (context "") (workspace "") (team-id "") (await nil) (timeout-seconds 60))`; each assignment is a plist with `:name`, `:task`, and optional `:workspace`.

`agents` has signature `(agents op &key (team-id "") (agent "") (timeout-seconds 60))`. `op` is `"list"`, `"wait"`, or `"stop"`.

`irc` has signature `(irc op &key (team-id "") (to "all") (message "") (reply-to "") (from "") (after -1) (limit 25) (timeout-seconds 30) (await-reply nil))`. `op` is `"join"`, `"send"`, `"inbox"`, `"history"`, `"wait"`, or `"roster"`.

## Sessions and coordination

<p align="right">
  <picture>
    <source media="(prefers-reduced-motion: reduce)" srcset="artwork/media/axolotl-sessions-still.png" />
    <img src="artwork/axolotl-sessions.gif" alt="The source-derived axolotl rolls through a swim cycle beside the sessions section, fanning its gills and paddling its limbs." width="200" />
  </picture>
</p>

A `task` request accepts `:name` and `:task` assignments and may include shared context, a common workspace, per-assignment workspaces, and an `:await` timeout. Child sessions inherit the parent's model selection, not its conversation; include the context they need explicitly.

Workers use the workspace paths you provide. Those directories are shared, not isolated worktrees. Give workers separate existing directories when they may edit the same files.

`agents` accepts `"list"`, `"wait"`, and `"stop"`. `irc` accepts `"join"`, `"send"`, `"inbox"`, `"history"`, `"wait"`, and `"roster"`; messages are stored on Nodecode Board. These are Lisp APIs called through the built-in eval, not separate provider-facing tools.

## Artwork

The [Foresight Labs](https://foresight-labs.eu/) mark is a 312 × 266 pixel-art SVG with seven color paths and 253 rectangular cells, not a 3D model. Its compiled React/Next.js bundle stores the animation as 24 frames on a 39 × 28 cell grid, packed as base64 data; a runtime decoder turns each frame into SVG paths and advances them at 12 fps on hover or focus. I couldn't find public source or metadata identifying the drawing/animation app, so I don't claim one. This README model is a source-geometry 3D reinterpretation, not their 2D player.

### How the source artwork became a 3D animation

1. **Inspect the real asset.** The SVG markup and rendered header were compared directly, recording the `viewBox`, path order, fills, and hover behavior instead of tracing a screenshot or guessing at a 3D model.
2. **Preserve and parse its geometry.** [`nodecode-axolotl.svg`](artwork/media/nodecode-axolotl.svg) is the editable source. [`export-axolotl-stl.py`](artwork/export-axolotl-stl.py) parses its closed rectangular path cells, retains each fill and coordinate, and writes [`axo-pixels.json`](artwork/axo-pixels.json) plus an STL preview. Unsupported path commands fail the export rather than silently changing the silhouette.
3. **Extrude the original layers.** [`axolotl-model.tsx`](artwork/axolotl-model.tsx) turns each rectangle into a RAEA cross-section, unions cells within each animated part, then extrudes the colored layers with small depth offsets. The original SVG coordinate system stays intact, so the 3D relief keeps the source proportions and pixel edges.
4. **Rig around real attachments.** Source cells are grouped into body, gills, eyes, and limb sections. Pivots sit at the limb roots; the shoulder rows stay with the torso while the lower sections paddle, preventing the legs from pulling away. Gills move independently with offset phases.
5. **Build a deterministic swim cycle.** [`axolotl-3d.tsx`](artwork/axolotl-3d.tsx) creates four 96-frame, 24-fps section loops with different phases and views. [`readme-hero.tsx`](artwork/readme-hero.tsx) reuses the same model in a six-second hero. Frame-based body drift, yaw, pitch, roll, breathing, gill/limb strokes, and a brief blink create secondary motion without changing the mascot design.
6. **Render for GitHub.** [`render-readme-mascot.ps1`](artwork/render-readme-mascot.ps1) renders each RAEA composition to video and a representative PNG still; FFmpeg converts the video to a looping, palette-optimized GIF. The README's `<picture>` elements serve the stills when reduced motion is preferred.
7. **Check the actual frames.** Inspect the stills, limb roots, stroke extremes, and loop seam at display size; compare the silhouette to the SVG; then verify both the GIF and reduced-motion PNG in the rendered README.

The [portable 2D frame-animation skill](skills/source-artwork-2d-animation/SKILL.md) and [portable 3D-animation skill](skills/source-artwork-3d-animation/SKILL.md) generalize these workflows across projects and toolchains. Copy either folder into an agent's supported skills directory to reuse it elsewhere.

### Regenerate the artwork

From `artwork/`, regenerate the rectangle data, STL preview, animation loops, and reduced-motion stills with [RAEA](https://raea.io/install) and `ffmpeg` installed:

```powershell
python .\export-axolotl-stl.py
.\render-readme-mascot.ps1
```

RAEA and FFmpeg are needed only to regenerate the artwork, not to run this cell. The source-derived model also has an [interactive STL preview](artwork/media/nodecode-axolotl.stl).

## License

MIT. See [LICENSE](LICENSE).

## Credits

Built for [Nodecode](https://github.com/nodecode-ai/nodecode), the agent environment at [nodecode.ai](https://nodecode.ai). This cell uses Nodecode's documented cell and eval APIs; it does not copy upstream code.
