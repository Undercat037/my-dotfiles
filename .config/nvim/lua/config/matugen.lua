-- Matugen colorscheme integration
local M = {}

function M.source_matugen()
  local matugen_path = os.getenv("HOME") .. "/.config/nvim/matugen.lua"

  local file, err = io.open(matugen_path, "r")
  if err ~= nil then
    -- Fallback to a default colorscheme if matugen file doesn't exist
    vim.cmd("colorscheme habamax")
    vim.notify(
      "Matugen theme file not found. Using fallback colorscheme. Run matugen to generate colors!",
      vim.log.levels.INFO
    )
  else
    io.close(file)
    -- Safely load matugen colors with error handling
    local ok, error_msg = pcall(dofile, matugen_path)
    if not ok then
      vim.notify(
        "Error loading matugen theme: " .. error_msg .. "\nUsing fallback colorscheme.",
        vim.log.levels.WARN
      )
      vim.cmd("colorscheme habamax")
    end
  end
end

-- Main entrypoint for matugen reloads
function M.reload()
  M.source_matugen()

  -- If you use lualine, uncomment and adjust this line:
  -- require('lualine').setup({ options = { theme = 'base16' } })

  -- Additional highlight customizations on reload
  vim.api.nvim_set_hl(0, "Comment", { italic = true })
end

-- Register autocmd to listen for matugen updates via SIGUSR1
vim.api.nvim_create_autocmd("Signal", {
  pattern = "SIGUSR1",
  callback = M.reload,
})

-- Load matugen theme on startup
M.reload()

return M
