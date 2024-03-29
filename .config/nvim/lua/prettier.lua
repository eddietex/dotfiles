vim.api.nvim_create_autocmd({ "BufWritePost" }, {
    group = vim.api.nvim_create_augroup("prettier", { clear = true }),
    pattern = { "*.ts", "*.tsx", "*.js", "*.jsx" },
    callback = function()
        local filePath = vim.api.nvim_buf_get_name(0)
        vim.api.nvim_exec(":!yarn prettier -w " .. filePath, true)
    end,
})
