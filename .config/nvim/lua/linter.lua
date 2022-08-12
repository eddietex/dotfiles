local eslint = require('lint')
eslint.linters_by_ft = {
  typescript = {'eslint'},
  typescriptreact = {'eslint'},
  javascript = {'eslint'},
  javascriptreact = {'eslint'}
}

vim.api.nvim_create_autocmd({ "BufWritePost", "BufEnter" }, {
    pattern = {"*.ts", "*.tsx", "*.js", "*.jsx"},
    callback = function()
        eslint.try_lint()
    end,
})
