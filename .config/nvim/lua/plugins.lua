local packer = require('packer')
packer.startup(function(use)
    use 'wbthomason/packer.nvim'
    use 'pangloss/vim-javascript'
    use 'leafgarland/typescript-vim'
    use 'peitalin/vim-jsx-typescript'
    use 'airblade/vim-gitgutter'
    use 'folke/tokyonight.nvim'
    use 'nvim-lua/plenary.nvim'
    use {
        'nvim-telescope/telescope.nvim', tag = '0.1.8',
        requires = { { 'nvim-lua/plenary.nvim' } }
    }
    use 'neovim/nvim-lspconfig'
    use 'hrsh7th/nvim-cmp' -- Autocompletion plugin
    use 'hrsh7th/cmp-nvim-lsp' -- LSP source for nvim-cmp
    use 'L3MON4D3/LuaSnip'
    -- use 'mfussenegger/nvim-lint'
    use 'tpope/vim-fugitive'
    use 'ThePrimeagen/harpoon'
    use {
        'nvim-treesitter/nvim-treesitter',
        run = ':TSUpdate'
    }
    use({
        "jose-elias-alvarez/null-ls.nvim",
        requires = { "nvim-lua/plenary.nvim" },
    })

    use {
        'nvim-lualine/lualine.nvim',
        requires = { 'kyazdani42/nvim-web-devicons', opt = true }
    }
end)
