local packer = require('packer')
packer.startup(function(use)
    use 'wbthomason/packer.nvim'
    use 'pangloss/vim-javascript'
    use 'leafgarland/typescript-vim'
    use 'peitalin/vim-jsx-typescript'
    use 'drewtempelmeyer/palenight.vim'
    use 'airblade/vim-gitgutter'
    use 'gruvbox-community/gruvbox'
    use 'nvim-lua/plenary.nvim'
    use {
      'nvim-telescope/telescope.nvim', tag = '0.1.0',
      requires = { {'nvim-lua/plenary.nvim'} }
    }
    use 'neovim/nvim-lspconfig'
    use 'hrsh7th/nvim-cmp' -- Autocompletion plugin
    use 'hrsh7th/cmp-nvim-lsp' -- LSP source for nvim-cmp
    use 'L3MON4D3/LuaSnip'
    use 'mfussenegger/nvim-lint'
    use 'tpope/vim-fugitive'
    use 'ThePrimeagen/harpoon'
end)
