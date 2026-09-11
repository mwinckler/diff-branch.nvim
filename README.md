# diff-branch.nvim

Diff the current file against the same path on another Git branch, using
whatever [difftool](https://git-scm.com/docs/git-difftool) you have configured.
Built for [LazyVim](https://www.lazyvim.org/) (uses a Snacks float when
available; falls back to a split terminal).

## Requirements

- Neovim 0.11+
- `git`
- A configured Git difftool (`diff.tool`, or `merge.tool` as fallback)

## Configure a difftool

The plugin runs `git difftool --no-prompt <branch> -- <file>`. Set a tool in
`~/.gitconfig` (or the repo's config). Examples:

```ini
# difftastic (https://github.com/Wilfred/difftastic)
[diff]
    tool = difftastic
[difftool "difftastic"]
    cmd = difft "$LOCAL" "$REMOTE"

# meld
[diff]
    tool = meld

# VS Code
[diff]
    tool = vscode
```

`git difftool --tool-help` lists built-in tools available on your machine.

## Install (LazyVim / lazy.nvim)

Drop this in `lua/plugins/diff-branch.lua`:

```lua
return {
  {
    "mwinckler/diff-branch.nvim",
    event = "VeryLazy",
    opts = {
      default_branch = "master",
    },
  },
}
```

For a local checkout, use `dir` instead of the GitHub slug:

```lua
return {
  {
    name = "diff-branch.nvim",
    dir = vim.fn.expand("~/path/to/diff-branch.nvim"),
    event = "VeryLazy",
    opts = { default_branch = "master" },
  },
}
```

## Usage

- `:DiffBranch` — vs `default_branch` (`master` unless you change it)
- `:DiffBranch main` — vs another branch (tab-completes local and remote refs)
- `<leader>gF` — same as `:DiffBranch`

`q` closes the diff window. Unsaved buffer edits are not included; the diff is
the file on disk.

## Options

```lua
opts = {
  default_branch = "master",
  command = "DiffBranch", -- or false
  keymap = "<leader>gF", -- or false
}
```
