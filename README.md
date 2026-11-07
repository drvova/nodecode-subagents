# Nodecode Subagents

An OMP-style Nodecode cell for parallel child sessions and IRC-style coordination on Nodecode's durable Board.

It registers three provider-facing tools:

- `task` starts detached worker sessions from explicit assignments.
- `agents` lists, waits for, or stops workers.
- `irc` joins the shared board, sends and reads messages, waits for replies, or lists members.

## Requirements

- Nodecode with local-cell loading enabled.
- Nodecode's `nodecode-board` cell installed and enabled. IRC coordination uses its durable board.

## Install

Clone this repository into Nodecode's local cells directory, then restart Nodecode or run `(restart-cells)`:

**PowerShell**

```powershell
git clone https://github.com/drvova/nodecode-subagents "$HOME\.nodecode\cells\nodecode-subagents"
```

**macOS / Linux**

```sh
git clone https://github.com/drvova/nodecode-subagents "$HOME/.nodecode/cells/nodecode-subagents"
```

Enable both cells in `~/.nodecode/config.jsonc`:

```jsonc
{
  "board": { "enabled": true },
  "subagents": {
    "enabled": true,
    "max_agents": 4,
    "budget_tokens": 300000,
    "budget_seconds": 3600
  }
}
```

`max_agents` accepts 1–5. Worker token and time budgets apply independently to each worker.

## Tool behavior

A `task` request contains one or more `{ "name", "task" }` assignments and may include a shared context, a common workspace, per-assignment workspaces, and an `await` timeout. Child sessions inherit the parent's model selection, not its conversation, so include the context they need explicitly.

Workers use the workspace paths you give them. Those directories are shared; the cell does not create isolated worktrees. Use separate existing directories for workers that may edit the same files.

`agents` accepts `op` values `list`, `wait`, or `stop`. `irc` accepts `join`, `send`, `inbox`, `history`, `wait`, or `roster`; messages are stored on Nodecode Board.

The tools are called by their provider-facing names. They are not Lisp functions to invoke from `eval`.

## License

MIT. See [LICENSE](LICENSE).
