local lazypath = vim.fn.stdpath('data') .. '/lazy/lazy.nvim'
if not vim.uv.fs_stat(lazypath) then
  vim.fn.system({
    'git',
    'clone',
    '--filter=blob:none',
    '--branch=stable',
    'https://github.com/folke/lazy.nvim.git',
    lazypath,
  })
end

vim.opt.rtp:prepend(lazypath)

require('lazy').setup({
  spec = {
    { 'pangloss/vim-javascript' },
    { 'leafgarland/typescript-vim' },
    { 'peitalin/vim-jsx-typescript' },
    { 'airblade/vim-gitgutter' },
    { 'folke/tokyonight.nvim', priority = 1000 },
    { 'nvim-lua/plenary.nvim' },
    {
      'nvim-telescope/telescope.nvim',
      tag = 'v0.2.1',
      dependencies = { 'nvim-lua/plenary.nvim' },
    },
    {
      'neovim/nvim-lspconfig',
      dependencies = { 'hrsh7th/cmp-nvim-lsp' },
      config = function()
        require('lsp')
      end,
    },
    {
      'hrsh7th/nvim-cmp',
      config = function()
        require('autocomplete')
      end,
    },
    { 'hrsh7th/cmp-nvim-lsp' },
    { 'L3MON4D3/LuaSnip' },
    { 'tpope/vim-fugitive' },
    { 'ThePrimeagen/harpoon' },
    {
      'nvim-treesitter/nvim-treesitter',
      build = ':TSUpdate',
      config = function()
        require('treesitter')
      end,
    },
    {
      'nvimtools/none-ls.nvim',
      dependencies = { 'nvimtools/none-ls-extras.nvim' },
      config = function()
        require('none-ls-config')
      end,
    },
    {
      'nvim-lualine/lualine.nvim',
      dependencies = { 'kyazdani42/nvim-web-devicons' },
      config = function()
        require('lualine-setup')
      end,
    },
  },
  defaults = {
    lazy = false,
  },
  lockfile = vim.fn.stdpath('config') .. '/lazy-lock.json',
})
