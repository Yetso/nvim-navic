-- Run from the repository root with Neovim 0.11+:
-- nvim --headless -u NONE -i NONE --cmd 'set rtp^=.' -l tests/attach.lua
local navic = require("nvim-navic")
local bufnr = vim.api.nvim_get_current_buf()
vim.api.nvim_buf_set_name(bufnr, vim.fn.tempname() .. ".ts")
local requests = 0
local callback
local client = {
	id = 1,
	name = "fake",
	server_capabilities = { documentSymbolProvider = true },
	request = function(_, _, _, handler)
		requests = requests + 1
		callback = handler
	end,
}

navic.attach(client, bufnr)
assert(requests == 1, "attach did not request symbols")

-- Events while the first response is pending must not send another request.
vim.api.nvim_exec_autocmds("BufEnter", { buffer = bufnr })
assert(requests == 1, "duplicate request while the first one is pending")

-- Without changes to the buffer, the answer is still up to date.
callback(nil, {})
vim.api.nvim_exec_autocmds("BufEnter", { buffer = bufnr })
assert(requests == 1, "re-requested symbols for an unchanged buffer")

-- After a change, symbols are requested again.
vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "const a = 1" })
vim.api.nvim_exec_autocmds("InsertLeave", { buffer = bufnr })
assert(requests == 2, "did not request symbols after a change")
print("PASS: attach sends one request until the buffer changes")
