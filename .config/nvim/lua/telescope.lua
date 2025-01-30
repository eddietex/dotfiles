vim.api.nvim_set_keymap(
  "n",
  "<leader>ff",
  "<cmd>Telescope find_files<cr>",
  { noremap = true }
 )

vim.api.nvim_set_keymap(
  "n",
  "<leader>fg",
  "<cmd>Telescope git_files<cr>",
  { noremap = true }
 )

vim.api.nvim_set_keymap(
  "n",
  "<leader>gr",
  "<cmd>Telescope live_grep<cr>",
  { noremap = true }
 )

vim.api.nvim_set_keymap(
  "n",
  "<leader>fb",
  "<cmd>Telescope buffers<cr>",
  { noremap = true }
 )

vim.api.nvim_set_keymap(
  "n",
  "<leader>fh",
  "<cmd>Telescope help_tags<cr>",
  { noremap = true }
 )

vim.api.nvim_set_keymap(
  "n",
  "<leader>fr",
  "<cmd>Telescope lsp_references<cr>",
  { noremap = true }
 )

