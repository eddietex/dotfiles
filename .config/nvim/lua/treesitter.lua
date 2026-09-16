-- nvim-treesitter's `main` branch (installed here, since plugins.lua doesn't pin
-- a branch) dropped the old setup(ensure_installed/highlight) API. Parsers are
-- installed explicitly and highlighting is enabled per filetype instead.

local parsers = {
  "bash",
  "css",
  "graphql",
  "groovy",
  "html",
  "java",
  "javascript",
  "json",
  "lua",
  "python",
  "sql",
  "swift",
  "tsx",
  "typescript",
  "vimdoc",
  "xml",
  "yaml",
}

vim.api.nvim_create_user_command('TSInstallBenefitSolver', function()
  require('nvim-treesitter').install(parsers, { summary = true })
end, {
  desc = 'Install Treesitter parsers used by BenefitSolver',
})

local parser_by_filetype = {
  ["bash"] = "bash",
  ["css"] = "css",
  ["graphql"] = "graphql",
  ["groovy"] = "groovy",
  ["help"] = "vimdoc",
  ["html"] = "html",
  ["java"] = "java",
  ["javascript"] = "javascript",
  ["javascriptreact"] = "javascript",
  ["json"] = "json",
  ["less"] = "css",
  ["lua"] = "lua",
  ["python"] = "python",
  ["sh"] = "bash",
  ["sql"] = "sql",
  ["svg"] = "xml",
  ["swift"] = "swift",
  ["typescript"] = "typescript",
  ["typescriptreact"] = "tsx",
  ["xsd"] = "xml",
  ["xml"] = "xml",
  ["xsl"] = "xml",
  ["xslt"] = "xml",
  ["yaml"] = "yaml",
  ["yaml.docker-compose"] = "yaml",
  ["yaml.gitlab"] = "yaml",
  ["yaml.helm-values"] = "yaml",
}

vim.api.nvim_create_autocmd('FileType', {
  pattern = vim.tbl_keys(parser_by_filetype),
  callback = function(args)
    local parser = parser_by_filetype[vim.bo[args.buf].filetype]
    if parser then
      pcall(vim.treesitter.start, args.buf, parser)
    end
  end,
})
