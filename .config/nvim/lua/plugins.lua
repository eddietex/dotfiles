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
    { 'pangloss/vim-javascript', ft = { 'javascript', 'javascriptreact' } },
    { 'leafgarland/typescript-vim', ft = { 'typescript', 'typescriptreact' } },
    { 'peitalin/vim-jsx-typescript', ft = { 'javascriptreact', 'typescriptreact' } },
    { 'airblade/vim-gitgutter', event = { 'BufReadPost', 'BufNewFile' } },
    { 'folke/tokyonight.nvim', priority = 1000 },
    {
      'nvim-telescope/telescope.nvim',
      tag = 'v0.2.1',
      cmd = { 'Telescope' },
      dependencies = { 'nvim-lua/plenary.nvim' },
    },
    {
      'neovim/nvim-lspconfig',
      ft = {
        'java',
        'javascript',
        'javascriptreact',
        'typescript',
        'typescriptreact',
        'python',
        'lua',
        'swift',
        'xml',
        'xsd',
        'xsl',
        'xslt',
        'svg',
        'json',
        'yaml',
        'yaml.docker-compose',
        'yaml.gitlab',
        'yaml.helm-values',
        'graphql',
        'groovy',
      },
      dependencies = { 'hrsh7th/cmp-nvim-lsp' },
      config = function()
        require('lsp')
      end,
    },
    {
      'hrsh7th/nvim-cmp',
      event = 'InsertEnter',
      dependencies = { 'L3MON4D3/LuaSnip' },
      config = function()
        require('autocomplete')
      end,
    },
    {
      'tpope/vim-fugitive',
      cmd = {
        'Git',
        'Gdiffsplit',
        'Gvdiffsplit',
        'Gread',
        'Gwrite',
        'Ggrep',
        'GMove',
        'GRename',
        'GDelete',
        'GRemove',
        'GBrowse',
        'Gedit',
      },
    },
    {
      'ThePrimeagen/harpoon',
      keys = { '<leader>hw', '<leader>hh', '<leader>jj', '<leader>kk', '<leader>ll', '<leader>;;' },
    },
    {
      'nvim-treesitter/nvim-treesitter',
      ft = {
        'lua',
        'typescript',
        'typescriptreact',
        'javascript',
        'javascriptreact',
        'json',
        'help',
        'swift',
        'python',
        'java',
        'groovy',
        'graphql',
        'xml',
        'xsd',
        'xsl',
        'xslt',
        'svg',
        'yaml',
        'yaml.docker-compose',
        'yaml.gitlab',
        'yaml.helm-values',
        'bash',
        'sh',
        'sql',
        'css',
        'less',
        'html',
      },
      build = ':TSUpdate',
      config = function()
        require('treesitter')
      end,
    },
    {
      'nvimtools/none-ls.nvim',
      ft = { 'javascript', 'javascriptreact', 'typescript', 'typescriptreact' },
      dependencies = { 'nvimtools/none-ls-extras.nvim' },
      config = function()
        require('none-ls-config')
      end,
    },
    {
      'nvim-lualine/lualine.nvim',
      event = 'VeryLazy',
      dependencies = { 'kyazdani42/nvim-web-devicons' },
      config = function()
        require('lualine-setup')
      end,
    },
  },
  defaults = {
    lazy = true,
  },
  -- luarocks/hererocks isn't set up on this machine; none of these plugins
  -- need it, and leaving rocks enabled breaks require() for plugins that
  -- ship a .rockspec (e.g. telescope.nvim resolves to a boolean instead of
  -- its module table).
  rocks = {
    enabled = false,
  },
  lockfile = vim.fn.stdpath('config') .. '/lazy-lock.json',
})
