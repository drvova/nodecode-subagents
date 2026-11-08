# Nodecode Subagents

<p align="center">
  <picture>
    <source media="(prefers-reduced-motion: reduce)" srcset="artwork/subagents-hero.png" />
    <img src="artwork/subagents-hero.gif" alt="The live Nodecode axolotl, built from its exact SVG geometry as a 3D extrusion, swimming with fluttering gills and out-of-phase limb strokes beside the subagents workflow." width="100%" />
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
    <img src="artwork/axolotl-setup.gif" alt="The source-derived axolotl swims beside the installation instructions, fluttering its gills as its limbs paddle." width="200" />
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
    <img src="artwork/axolotl-configure.gif" alt="The source-derived axolotl swims beside configuration instructions, with gills and limbs moving independently." width="200" />
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
    <img src="artwork/axolotl-eval-apis.gif" alt="The source-derived axolotl paddles through a seamless swim loop beside the eval API section." width="200" />
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
    <img src="artwork/axolotl-sessions.gif" alt="The source-derived axolotl turns and paddles through the sessions section, its gills fluttering with the swim cycle." width="200" />
  </picture>
</p>

A `task` request accepts `:name` and `:task` assignments and may include shared context, a common workspace, per-assignment workspaces, and an `:await` timeout. Child sessions inherit the parent's model selection, not its conversation; include the context they need explicitly.

Workers use the workspace paths you provide. Those directories are shared, not isolated worktrees. Give workers separate existing directories when they may edit the same files.

`agents` accepts `"list"`, `"wait"`, and `"stop"`. `irc` accepts `"join"`, `"send"`, `"inbox"`, `"history"`, `"wait"`, and `"roster"`; messages are stored on Nodecode Board. These are Lisp APIs called through the built-in eval, not separate provider-facing tools.

## Artwork

The live homepage header uses a 312 × 266 SVG; it does not expose a 3D model or animation asset. This artwork preserves the live vector's seven paths and 253 rectangles, extrudes the original palette into depth, and rigs its gills and paired limbs. The gills flutter twice per swim stroke, the limbs paddle out of phase, and the body rolls, breathes, and turns on a phase-closed loop.

From `artwork/`, regenerate the geometry, STL preview, animation loops, and reduced-motion stills with [RAEA](https://raea.io/install) and `ffmpeg` installed:

```powershell
python .\export-axolotl-stl.py
.\render-readme-mascot.ps1
```

The live vector source is [`nodecode-axolotl.svg`](artwork/media/nodecode-axolotl.svg); the source-derived model has an [interactive STL preview](artwork/media/nodecode-axolotl.stl). RAEA and ffmpeg are needed only to regenerate artwork, not to run this cell.

## License

MIT. See [LICENSE](LICENSE).

## Credits

Built for [Nodecode](https://github.com/nodecode-ai/nodecode), the agent environment at [nodecode.ai](https://nodecode.ai). This cell uses Nodecode's documented cell and eval APIs; it does not copy upstream code.
