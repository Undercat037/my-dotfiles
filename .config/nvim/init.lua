-- bootstrap lazy.nvim, LazyVim and your plugins
require("config.lazy")

-- Load matugen colorscheme integration after plugins are loaded
vim.api.nvim_create_autocmd("User", {
  pattern = "VeryLazy",
  callback = function()
    require("config.matugen")
  end,
})
