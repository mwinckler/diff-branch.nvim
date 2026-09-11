local M = {}

local defaults = {
  --- Git ref used when `:DiffBranch` is called with no argument.
  default_branch = "master",
  --- User command name, or `false` to skip creating one.
  command = "DiffBranch",
  --- Normal-mode keymap, or `false` to skip creating one.
  keymap = "<leader>gF",
}

M.opts = vim.deepcopy(defaults)

--- Run git from `cwd` without a shell so paths/refs are not expanded.
local function git_run(cwd, args)
  local cmd = { "git", "-C", cwd }
  vim.list_extend(cmd, args)
  local out = vim.fn.systemlist(cmd)
  return vim.v.shell_error, out
end

local function git_ref_exists(root, ref)
  return git_run(root, { "rev-parse", "--verify", "--quiet", ref .. "^{commit}" }) == 0
end

--- Git's configured `diff.tool`, falling back to `merge.tool` the same way `git difftool` does.
local function configured_difftool(root)
  for _, key in ipairs({ "diff.tool", "merge.tool" }) do
    local _, out = git_run(root, { "config", "--get", key })
    if out[1] and out[1] ~= "" then
      return out[1]
    end
  end
  return nil
end

local function git_branch_complete(arglead)
  local abs = vim.api.nvim_buf_get_name(0)
  local dir = abs ~= "" and vim.fs.dirname(vim.fs.normalize(abs)) or (vim.uv.cwd() or ".")
  local refs = vim.fn.systemlist({
    "git",
    "-C",
    dir,
    "for-each-ref",
    "--format=%(refname:short)",
    "refs/heads",
    "refs/remotes",
  })
  if vim.v.shell_error ~= 0 then
    return {}
  end
  return vim.tbl_filter(function(ref)
    return vim.startswith(ref, arglead)
  end, refs)
end

local function show_diff(cmd, cwd)
  local snacks = rawget(_G, "Snacks")
  if snacks and snacks.terminal then
    local term_opts = {
      cwd = cwd,
      interactive = false,
      win = { position = "float" },
    }
    local existing = snacks.terminal.get(cmd, vim.tbl_extend("keep", { create = false }, term_opts))
    if existing then
      existing:close()
    end
    local term = snacks.terminal.open(cmd, term_opts)
    if not (term and term.buf) then
      return
    end
    vim.api.nvim_create_autocmd("TermClose", {
      buffer = term.buf,
      once = true,
      callback = function()
        vim.schedule(function()
          if term:win_valid() then
            pcall(vim.api.nvim_win_set_cursor, term.win, { 1, 0 })
          end
        end)
      end,
    })
    return
  end

  vim.cmd("botright split")
  vim.fn.termopen(cmd, { cwd = cwd })
  vim.keymap.set("n", "q", "<cmd>close<cr>", { buffer = true, silent = true })
end

--- Diff the current file against the same path on `branch` (defaults to setup `default_branch`).
function M.open(branch)
  branch = (branch and branch ~= "") and branch or M.opts.default_branch

  local abs = vim.fs.normalize(vim.api.nvim_buf_get_name(0))
  if abs == "" then
    vim.notify("No file in current buffer", vim.log.levels.ERROR)
    return
  end

  local err, toplevel = git_run(vim.fs.dirname(abs), { "rev-parse", "--show-toplevel" })
  if err ~= 0 or not toplevel[1] or toplevel[1] == "" then
    vim.notify("Not inside a git repository", vim.log.levels.ERROR)
    return
  end
  local root = vim.fs.normalize(toplevel[1])

  local rel = vim.fs.relpath(root, abs)
  if not rel then
    vim.notify("File is not inside the Git repository", vim.log.levels.ERROR)
    return
  end

  if not git_ref_exists(root, branch) then
    vim.notify(("Git ref '%s' not found"):format(branch), vim.log.levels.ERROR)
    return
  end

  local in_branch = git_run(root, { "cat-file", "-e", branch .. ":" .. rel }) == 0
  local tracked = git_run(root, { "ls-files", "--error-unmatch", "--", rel }) == 0
  if not in_branch and not tracked then
    vim.notify(("File is not tracked and does not exist on '%s'"):format(branch), vim.log.levels.ERROR)
    return
  end

  -- 0 = identical, 1 = different, anything else = git error.
  err = git_run(root, { "diff", "--quiet", "--exit-code", branch, "--", rel })
  if err == 0 then
    vim.notify(("No differences vs %s"):format(branch), vim.log.levels.INFO)
    return
  elseif err ~= 1 then
    vim.notify("git diff failed", vim.log.levels.ERROR)
    return
  end

  if not configured_difftool(root) then
    vim.notify(
      "No git difftool configured. Set diff.tool (see diff-branch.nvim README).",
      vim.log.levels.ERROR
    )
    return
  end

  if vim.bo.modified then
    vim.notify("Buffer has unsaved changes; diff uses the file on disk", vim.log.levels.WARN)
  end

  show_diff({
    "git",
    "--no-pager",
    "difftool",
    "--no-prompt",
    branch,
    "--",
    rel,
  }, root)
end

function M.setup(opts)
  M.opts = vim.tbl_deep_extend("force", vim.deepcopy(defaults), opts or {})
  if M._setup then
    return
  end
  M._setup = true

  if M.opts.command then
    vim.api.nvim_create_user_command(M.opts.command, function(cmd_opts)
      M.open(cmd_opts.args)
    end, {
      nargs = "?",
      complete = git_branch_complete,
      desc = "Diff current file against a Git branch using git difftool",
    })
  end

  if M.opts.keymap then
    vim.keymap.set("n", M.opts.keymap, function()
      M.open()
    end, { desc = "Diff File vs Branch (" .. M.opts.default_branch .. ")" })
  end
end

return M
