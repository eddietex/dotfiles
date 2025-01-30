local null_ls = require("null-ls")

null_ls.setup({
    sources = {
        null_ls.builtins.diagnostics.eslint_d.with({
            command = "eslint_d",  -- Ensure eslint_d is used
            diagnostics_format = '[eslint] #{m}\n(#{c})',
            extra_args = {}, -- Ensure no legacy options are being passed
        }),
    }
})

