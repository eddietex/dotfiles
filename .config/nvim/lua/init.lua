vim.g.mapleader=' '

require('plugins')

vim.opt.scrolloff=8
vim.opt.ruler=true
vim.opt.number=true
vim.opt.relativenumber=true
vim.opt.swapfile = false

vim.cmd 'colorscheme tokyonight'
vim.opt.background='dark'

vim.opt.guifont='Menlo Regular:h15'

require('keymap')
require('telescope-keymaps')
require('filetype-settings')
require('prettier')
