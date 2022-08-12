vim.opt.tabstop=4
vim.opt.shiftwidth=4
vim.opt.scrolloff=8
vim.opt.expandtab=true
vim.opt.ruler=true
vim.opt.number=true
vim.opt.relativenumber=true

vim.cmd 'colorscheme gruvbox'
vim.cmd 'highlight Normal ctermbg=none'
vim.cmd 'highlight NonText ctermbg=none'

vim.opt.guifont='Menlo Regular:h15'

vim.g.mapleader=' '

require('plugins')
require('keymap')
require('telescope')
require('autocomplete')
require('lsp')
-- require('linter')
require('prettier')
