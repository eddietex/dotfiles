local set_mappings = function (bufnr)
    -- Mappings.
    -- See `:help vim.diagnostic.*` for documentation on any of the below functions
    local opts = { noremap=true, silent=true }
    vim.keymap.set('n', '<space>e', vim.diagnostic.open_float, opts)
    vim.keymap.set('n', '[d', vim.diagnostic.goto_prev, opts)
    vim.keymap.set('n', ']d', vim.diagnostic.goto_next, opts)
    vim.keymap.set('n', '<space>q', vim.diagnostic.setloclist, opts)


      -- Mappings.
      -- See `:help vim.lsp.*` for documentation on any of the below functions
      local bufopts = { noremap=true, silent=true, buffer=bufnr }
      vim.keymap.set('n', 'gD', vim.lsp.buf.declaration, bufopts)
      vim.keymap.set('n', 'gd', vim.lsp.buf.definition, bufopts)
      vim.keymap.set('n', 'K', vim.lsp.buf.hover, bufopts)
      vim.keymap.set('n', 'gi', vim.lsp.buf.implementation, bufopts)
      vim.keymap.set('n', '<C-k>', vim.lsp.buf.signature_help, bufopts)
      vim.keymap.set('n', '<space>wa', vim.lsp.buf.add_workspace_folder, bufopts)
      vim.keymap.set('n', '<space>wr', vim.lsp.buf.remove_workspace_folder, bufopts)
      vim.keymap.set('n', '<space>wl', function()
        print(vim.inspect(vim.lsp.buf.list_workspace_folders()))
      end, bufopts)
      vim.keymap.set('n', '<space>D', vim.lsp.buf.type_definition, bufopts)
      vim.keymap.set('n', '<space>rn', vim.lsp.buf.rename, bufopts)
      vim.keymap.set('n', '<space>ca', vim.lsp.buf.code_action, bufopts)
      vim.keymap.set('n', 'gr', vim.lsp.buf.references, bufopts)
      vim.keymap.set('n', '<space>f', function() vim.lsp.buf.format({ async = true }) end, bufopts)

end

local get_on_attach = function(filetype)
    return function(client, bufnr)
        set_mappings(bufnr)
    end
end

local lsp_flags = {
  -- This is the default in Nvim 0.7+
  debounce_text_changes = 150,
}

local capabilities = vim.lsp.protocol.make_client_capabilities()
capabilities = require('cmp_nvim_lsp').default_capabilities(capabilities)

-- Typescript

vim.lsp.config('ts_ls', {
    on_attach = get_on_attach('typescript'),
    flags = lsp_flags,
    capabilities = capabilities,
    -- this doesnt seem to be working. play with it
    settings = {
        preferences = {
            importModuleSpecifier = 'non-relative',
        }
    }
})
vim.lsp.enable('ts_ls')

-- Python
vim.lsp.config('pyright', {
    on_attach = get_on_attach('python'),
    flags = lsp_flags,
    capabilities = capabilities,
})
vim.lsp.enable('pyright')

-- Java
local jdtls_java = '/opt/homebrew/opt/openjdk/bin/java'
local jdtls_cmd = { 'jdtls' }
if vim.fn.executable(jdtls_java) == 1 then
    jdtls_cmd = { 'jdtls', '--java-executable', jdtls_java }
end

vim.lsp.config('jdtls', {
    cmd = jdtls_cmd,
    on_attach = get_on_attach('java'),
    flags = lsp_flags,
    capabilities = capabilities,
})
vim.lsp.enable('jdtls')

-- Lua
vim.lsp.config('lua_ls', {
  capabilities = capabilities,
  settings = {
    Lua = {
      runtime = {
        -- Tell the language server which version of Lua you're using (most likely LuaJIT in the case of Neovim)
        version = 'LuaJIT',
      },
      diagnostics = {
        -- Get the language server to recognize the `vim` global
        globals = {'vim'},
      },
      workspace = {
        -- Make the server aware of Neovim runtime files
        library = vim.api.nvim_get_runtime_file("", true),
      },
      -- Do not send telemetry data containing a randomized but unique identifier
      telemetry = {
        enable = false,
      },
    },
  },
  on_attach = get_on_attach('lua'),
})
vim.lsp.enable('lua_ls')

-- Swift
vim.lsp.config('sourcekit', {
  cmd = { "xcrun", "sourcekit-lsp" },
  on_attach = get_on_attach('swift'),
  flags = lsp_flags,
  capabilities = capabilities,
})
vim.lsp.enable('sourcekit')
