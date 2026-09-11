-- Copy to ~/.config/nvim/lua/plugins/diff-branch.lua
return {
  {
    "YOUR_GITHUB_USER/diff-branch.nvim",
    event = "VeryLazy",
    opts = {
      default_branch = "master", -- or "main"
    },
  },
}
