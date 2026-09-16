local uv = vim.uv

local tab_filetypes = {
  "java",
  "javascript",
  "javascriptreact",
  "typescript",
  "typescriptreact",
}

local supported_filetypes = {
  "java",
  "javascript",
  "javascriptreact",
  "typescript",
  "typescriptreact",
  "groovy",
  "python",
  "lua",
  "swift",
  "json",
  "yaml",
  "yaml.docker-compose",
  "yaml.gitlab",
  "yaml.helm-values",
  "xml",
  "xsd",
  "xsl",
  "xslt",
  "svg",
  "graphql",
  "sql",
  "sh",
  "bash",
  "css",
  "less",
  "html",
}

local function benefitsolver_root(bufnr)
  local buffer_name = vim.api.nvim_buf_get_name(bufnr)
  if buffer_name == "" then
    return nil
  end

  local settings_file = vim.fs.find("settings.gradle", {
    path = vim.fs.dirname(buffer_name),
    upward = true,
    type = "file",
  })[1]

  if not settings_file then
    return nil
  end

  local root = vim.fs.dirname(settings_file)
  if uv.fs_stat(vim.fs.joinpath(root, "code-style", "java-format.xml")) then
    return root
  end

  return nil
end

vim.api.nvim_create_autocmd("FileType", {
  pattern = supported_filetypes,
  group = vim.api.nvim_create_augroup("benefitsolver_filetype_settings", { clear = true }),
  callback = function(args)
    if not benefitsolver_root(args.buf) then
      return
    end

    vim.opt_local.tabstop = 4
    vim.opt_local.shiftwidth = 4
    vim.opt_local.softtabstop = 4
    vim.opt_local.expandtab = not vim.tbl_contains(tab_filetypes, vim.bo[args.buf].filetype)
  end,
})
