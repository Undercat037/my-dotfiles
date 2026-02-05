return {
  "lervag/vimtex",
  lazy = false,
  ft = { "tex", "bib" },
  config = function()
    -- Set the PDF viewer (zathura is recommended for Linux)
    vim.g.vimtex_view_method = "zathura"

    -- Or use general method which will auto-detect available viewers
    -- vim.g.vimtex_view_method = "general"

    -- Compiler settings
    vim.g.vimtex_compiler_method = "latexmk"

    -- Enable quickfix auto-open on warnings/errors
    vim.g.vimtex_quickfix_mode = 1

    -- Disable overfull/underfull \hbox and all package warnings
    vim.g.vimtex_quickfix_ignore_filters = {
      'Overfull',
      'Underfull',
    }

    -- Enable folding
    vim.g.vimtex_fold_enabled = 1

    -- Disable concealment (optional - hides LaTeX syntax for cleaner look)
    vim.g.vimtex_syntax_conceal_disable = 1

    -- Enable completion
    vim.g.vimtex_complete_enabled = 1

    -- Compilation settings
    vim.g.vimtex_compiler_latexmk = {
      build_dir = '',
      callback = 1,
      continuous = 1,
      executable = 'latexmk',
      options = {
        '-pdf',
        '-verbose',
        '-file-line-error',
        '-synctex=1',
        '-interaction=nonstopmode',
      },
    }
  end,
}
