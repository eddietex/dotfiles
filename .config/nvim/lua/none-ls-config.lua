local null_ls = require("null-ls")
local null_ls_utils = require("null-ls.utils")

local prettier_config_root = null_ls_utils.cosmiconfig("prettier")
local eslint_config_root = null_ls_utils.cosmiconfig("eslint", "eslintConfig")
local javascript_filetypes = { "javascript", "javascriptreact", "typescript", "typescriptreact" }

local function find_config(config_root, bufname)
    local ok, root = pcall(config_root, bufname)
    if ok then
        return root
    end
    return nil
end

local function has_config(config_root, bufname)
    return find_config(config_root, bufname) ~= nil
end

local function has_local_executable(params, executable)
    if not params.bufname or params.bufname == "" then
        return false
    end

    local start_directory = vim.fn.fnamemodify(params.bufname, ":h")
    for ancestor in null_ls_utils.path.ancestors(start_directory) do
        local executable_path = vim.fs.joinpath(ancestor, "node_modules", ".bin", executable)
        if vim.fn.executable(executable_path) == 1 then
            return true
        end

        if params.root and ancestor == params.root then
            break
        end
    end

    return false
end

local function prettier_is_available(params)
    return has_config(prettier_config_root, params.bufname)
        and has_local_executable(params, "prettier")
end

local function eslint_is_available(params)
    return vim.fn.executable("eslint_d") == 1
        and has_config(eslint_config_root, params.bufname)
end

local function configured_root(bufname)
    return find_config(prettier_config_root, bufname)
        or find_config(eslint_config_root, bufname)
        or null_ls_utils.root_pattern(".git")(bufname)
end

local function should_attach(bufnr)
    local filetype = vim.bo[bufnr].filetype
    if not vim.tbl_contains(javascript_filetypes, filetype) then
        return false
    end

    local bufname = vim.api.nvim_buf_get_name(bufnr)
    if bufname == "" then
        return false
    end

    local params = {
        bufname = bufname,
        root = null_ls_utils.root_pattern(".git")(bufname),
    }
    return prettier_is_available(params) or eslint_is_available(params)
end

null_ls.setup({
    root_dir = configured_root,
    should_attach = should_attach,
    sources = {
        require("none-ls.diagnostics.eslint_d").with({
            filetypes = javascript_filetypes,
            runtime_condition = eslint_is_available,
        }), -- requires none-ls-extras.nvim
        null_ls.builtins.formatting.prettier.with({
            filetypes = javascript_filetypes,
            runtime_condition = prettier_is_available,
        }),
    },
})
