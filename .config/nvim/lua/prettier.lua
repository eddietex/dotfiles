vim.api.nvim_create_autocmd("BufWritePre", {
    group = vim.api.nvim_create_augroup("prettier", { clear = true }),
    pattern = { "*.ts", "*.tsx", "*.js", "*.jsx" },
    callback = function(args)
        local bufnr = args.buf
        local prettier_client

        for _, client in ipairs(vim.lsp.get_clients({ bufnr = bufnr, name = "null-ls" })) do
            if client:supports_method("textDocument/formatting", bufnr) then
                prettier_client = client
                break
            end
        end

        if not prettier_client then
            return
        end

        vim.lsp.buf.format({
            bufnr = bufnr,
            async = false,
            timeout_ms = 1000,
            filter = function(client)
                return client.id == prettier_client.id
            end,
        })
    end,
})
