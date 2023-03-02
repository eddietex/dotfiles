vim.api.nvim_set_keymap(
  "n",
  "<leader>jf",
  "<cmd>Ex<cr>",
  { noremap = true }
 )

vim.api.nvim_set_keymap(
  "n",
  "<leader>y",
  "\"*y",
  { noremap = true }
 )

 vim.api.nvim_set_keymap("n", "<leader>s", [[:%s/\<<C-r><C-w>\>/<C-r><C-w>/gI<Left><Left><Left>]], { noremap = true })

-- harpoon
--
vim.api.nvim_set_keymap(
  "n",
  "<leader>hw",
  "<cmd>lua require('harpoon.ui').toggle_quick_menu()<cr>)",
  { noremap = true }
 )

vim.api.nvim_set_keymap(
  "n",
  "<leader>hh",
  "<cmd>lua require('harpoon.mark').add_file()<cr>)",
  { noremap = true }
 )

vim.api.nvim_set_keymap(
  "n",
  "<leader>jj",
  "<cmd>lua require('harpoon.ui').nav_file(1)<cr>)",
  { noremap = true }
 )


vim.api.nvim_set_keymap(
  "n",
  "<leader>kk",
  "<cmd>lua require('harpoon.ui').nav_file(2)<cr>)",
  { noremap = true }
)

vim.api.nvim_set_keymap(
  "n",
  "<leader>ll",
  "<cmd>lua require('harpoon.ui').nav_file(3)<cr>)",
  { noremap = true }
)

vim.api.nvim_set_keymap(
  "n",
  "<leader>;;",
  "<cmd>lua require('harpoon.ui').nav_file(4)<cr>)",
  { noremap = true }
)
