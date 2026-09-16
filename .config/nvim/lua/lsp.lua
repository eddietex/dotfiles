local formatter_client_names = {
    jdtls = true,
    ['null-ls'] = true,
    lemminx = true,
    jsonls = true,
    yamlls = true,
}

local function format_buffer(bufnr, async)
    local formatter_client
    for _, client in ipairs(vim.lsp.get_clients({ bufnr = bufnr })) do
        if formatter_client_names[client.name]
            and client:supports_method('textDocument/formatting', bufnr) then
            formatter_client = client
            break
        end
    end

    if not formatter_client then
        return
    end

    vim.lsp.buf.format({
        async = async,
        bufnr = bufnr,
        filter = function(client)
            return client.id == formatter_client.id
        end,
    })
end

local set_mappings = function (bufnr)
    -- Mappings.
    -- See `:help vim.diagnostic.*` for documentation on any of the below functions
    local opts = { silent=true, buf=bufnr }
    vim.keymap.set('n', '<space>e', vim.diagnostic.open_float, opts)
    vim.keymap.set('n', '[d', function()
      vim.diagnostic.jump({ count = -1, on_jump = function(diagnostic)
        if diagnostic then
          vim.diagnostic.open_float()
        end
      end })
    end, opts)
    vim.keymap.set('n', ']d', function()
      vim.diagnostic.jump({ count = 1, on_jump = function(diagnostic)
        if diagnostic then
          vim.diagnostic.open_float()
        end
      end })
    end, opts)
    vim.keymap.set('n', '<space>q', vim.diagnostic.setloclist, opts)
    -- Mappings.
    -- See `:help vim.lsp.*` for documentation on any of the below functions
    vim.keymap.set('n', 'gD', vim.lsp.buf.declaration, opts)
    vim.keymap.set('n', 'gd', vim.lsp.buf.definition, opts)
    vim.keymap.set('n', 'K', vim.lsp.buf.hover, opts)
    vim.keymap.set('n', 'gi', vim.lsp.buf.implementation, opts)
    vim.keymap.set('n', '<C-k>', vim.lsp.buf.signature_help, opts)
    vim.keymap.set('n', '<space>wa', vim.lsp.buf.add_workspace_folder, opts)
    vim.keymap.set('n', '<space>wr', vim.lsp.buf.remove_workspace_folder, opts)
    vim.keymap.set('n', '<space>wl', function()
      print(vim.inspect(vim.lsp.buf.list_workspace_folders()))
    end, opts)
    vim.keymap.set('n', '<space>D', vim.lsp.buf.type_definition, opts)
    vim.keymap.set('n', '<space>rn', vim.lsp.buf.rename, opts)
    vim.keymap.set('n', '<space>ca', vim.lsp.buf.code_action, opts)
    vim.keymap.set('n', 'gr', vim.lsp.buf.references, opts)
    vim.keymap.set('n', '<space>f', function() format_buffer(bufnr, true) end, opts)

end

local get_on_attach = function()
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
    filetypes = { 'javascript', 'javascriptreact', 'typescript', 'typescriptreact' },
    on_attach = get_on_attach(),
    flags = lsp_flags,
    capabilities = capabilities,
    init_options = {
        preferences = {
            importModuleSpecifierPreference = 'non-relative',
        }
    }
})
vim.lsp.enable('ts_ls')

-- Python
vim.lsp.config('pyright', {
    filetypes = { 'python' },
    on_attach = get_on_attach(),
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

local function start_jdtls(dispatchers, config)
    local workspace_root = vim.fs.joinpath(
        vim.fn.stdpath('data'),
        'jdtls-workspaces',
        vim.fn.sha256(config.root_dir or vim.fn.getcwd())
    )
    vim.fn.mkdir(workspace_root, 'p')

    local command = vim.deepcopy(jdtls_cmd)
    vim.list_extend(command, { '-data', workspace_root })
    return vim.lsp.rpc.start(command, dispatchers)
end

local java8_home = '/Library/Java/JavaVirtualMachines/temurin-8.jdk/Contents/Home'
local java17_home = '/Library/Java/JavaVirtualMachines/temurin-17.jdk/Contents/Home'
local java26_home = '/opt/homebrew/opt/openjdk/libexec/openjdk.jdk/Contents/Home'
local java_runtimes = {}

local function add_java_runtime(name, path, is_default)
    if vim.fn.isdirectory(path) == 1 then
        table.insert(java_runtimes, {
            name = name,
            path = path,
            default = is_default,
        })
    end
end

add_java_runtime('JavaSE-1.8', java8_home, true)
add_java_runtime('JavaSE-17', java17_home, false)
add_java_runtime('JavaSE-26', java26_home, false)

local java_settings = {
    java = {
        configuration = {
            runtimes = java_runtimes,
        },
        import = {
            gradle = {
                enabled = true,
                wrapper = {
                    enabled = true,
                },
            },
        },
        signatureHelp = {
            enabled = true,
        },
        format = {
            settings = {
                profile = 'BSC Eclipse Format Java',
            },
        },
    },
}

if vim.fn.isdirectory(java8_home) == 1 then
    java_settings.java.import.gradle.java = {
        home = java8_home,
    }
end

local java_formatter = '/Users/eteixeira/Workspace/BenefitSolver/code-style/java-format.xml'
if vim.fn.filereadable(java_formatter) == 1 then
    java_settings.java.format.settings.url = vim.uri_from_fname(java_formatter)
end

vim.lsp.config('jdtls', {
    cmd = start_jdtls,
    filetypes = { 'java' },
    workspace_required = true,
    root_markers = {
        { 'gradlew', 'settings.gradle', 'settings.gradle.kts', '.git' },
        { 'build.gradle', 'build.gradle.kts', 'pom.xml', 'build.xml' },
    },
    on_attach = get_on_attach(),
    flags = lsp_flags,
    capabilities = capabilities,
    settings = java_settings,
})
vim.lsp.enable('jdtls')

-- Lua
vim.lsp.config('lua_ls', {
  filetypes = { 'lua' },
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
  on_attach = get_on_attach(),
})
vim.lsp.enable('lua_ls')

-- Swift
vim.lsp.config('sourcekit', {
  cmd = { "xcrun", "sourcekit-lsp" },
  filetypes = { 'swift' },
  on_attach = get_on_attach(),
  flags = lsp_flags,
  capabilities = capabilities,
})
vim.lsp.enable('sourcekit')

local optional_servers = {
    { name = 'lemminx', executable = 'lemminx' },
    { name = 'jsonls', executable = 'vscode-json-language-server' },
    { name = 'yamlls', executable = 'yaml-language-server' },
    { name = 'graphql', executable = 'graphql-lsp' },
    { name = 'gradle_ls', executable = 'gradle-language-server' },
    { name = 'groovyls', executable = 'groovy-language-server' },
}

for _, server in ipairs(optional_servers) do
    if vim.fn.executable(server.executable) == 1 then
        vim.lsp.enable(server.name)
    end
end
