-- nvim-treesitter's `main` branch (installed here, since plugins.lua doesn't pin
-- a branch) dropped the old setup(ensure_installed/highlight) API. Parsers are
-- installed explicitly and highlighting is enabled per filetype instead.

local parsers = { "lua", "typescript", "tsx", "javascript", "json", "vimdoc", "swift", "python", "java" }

require('nvim-treesitter').install(parsers)

vim.api.nvim_create_autocmd('FileType', {
  pattern = { "lua", "typescript", "typescriptreact", "javascript", "json", "help", "swift", "python", "java" },
  callback = function()
    vim.treesitter.start()
  end,
})
