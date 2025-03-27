require('plugins')

vim.opt.tabstop=4
vim.opt.shiftwidth=4
vim.opt.scrolloff=8
vim.opt.expandtab=true
vim.opt.ruler=true
vim.opt.number=true
vim.opt.relativenumber=true
vim.opt.swapfile = false

vim.cmd 'colorscheme tokyonight'
vim.opt.background='dark'

vim.opt.guifont='Menlo Regular:h15'

vim.g.mapleader=' '

require('keymap')
require('telescope')
require('autocomplete')
require('lsp')
require('prettier')
require('none-ls-config')
require('treesitter')
require('lualine-setup')
