vim.api.nvim_set_keymap(
  "n",
  "<leader>jf",
  "<cmd>Ex<cr>",
  { noremap = true }
 )

-- Use <leader>y as a clipboard yank operator, so <leader>yiw copies the current word.
vim.api.nvim_set_keymap(
  "n",
  "<leader>y",
  "\"*y",
  { noremap = true }
 )

-- Copy the current file path, line, and column to the system clipboard.
local function copy_location()
  local buffer_name = vim.api.nvim_buf_get_name(0)

  if buffer_name == "" then
    vim.notify("Current buffer has no file name", vim.log.levels.WARN)
    return
  end

  local file = vim.fn.fnamemodify(buffer_name, ":.")
  local line = vim.fn.line(".")
  local column = vim.fn.col(".")
  local location = string.format("%s:%d:%d", file, line, column)

  vim.fn.setreg("+", location)
  vim.notify("Copied: " .. location)
end

vim.api.nvim_create_user_command("CopyLocation", copy_location, {
  desc = "Copy file:line:column to the system clipboard",
})

-- <leader>yl copies a reference such as path/to/file.lua:12:8.
vim.api.nvim_set_keymap(
  "n",
  "<leader>yl",
  "<cmd>CopyLocation<cr>",
  { noremap = true }
)

 vim.api.nvim_set_keymap("n", "<leader>s", [[:%s/\<<C-r><C-w>\>/<C-r><C-w>/gI<Left><Left><Left>]], { noremap = true })

-- harpoon
--
vim.api.nvim_set_keymap(
  "n",
  "<leader>hw",
  "<cmd>lua require('harpoon.ui').toggle_quick_menu()<cr>",
  { noremap = true }
)

vim.api.nvim_set_keymap(
  "n",
  "<leader>hh",
  "<cmd>lua require('harpoon.mark').add_file()<cr>",
  { noremap = true }
)

vim.api.nvim_set_keymap(
  "n",
  "<leader>jj",
  "<cmd>lua require('harpoon.ui').nav_file(1)<cr>",
  { noremap = true }
)

vim.api.nvim_set_keymap(
  "n",
  "<leader>kk",
  "<cmd>lua require('harpoon.ui').nav_file(2)<cr>",
  { noremap = true }
)

vim.api.nvim_set_keymap(
  "n",
  "<leader>ll",
  "<cmd>lua require('harpoon.ui').nav_file(3)<cr>",
  { noremap = true }
)

vim.api.nvim_set_keymap(
  "n",
  "<leader>;;",
  "<cmd>lua require('harpoon.ui').nav_file(4)<cr>",
  { noremap = true }
)
