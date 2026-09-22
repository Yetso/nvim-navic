-- Run from the repository root with Neovim 0.11+:
-- nvim --headless -u NONE -i NONE --cmd 'set rtp^=.' -l tests/request_symbol.lua
local lib = require("nvim-navic.lib")
local target = vim.api.nvim_create_buf(true, false)
vim.api.nvim_buf_set_name(target, vim.fn.tempname() .. ".ts")
local expected_uri = vim.uri_from_bufnr(target)
local requests = {}
local callback
local client = {
	request = function(_, method, params, handler, bufnr)
		assert(method == "textDocument/documentSymbol")
		assert(bufnr == target)
		requests[#requests + 1] = params.textDocument.uri
		callback = handler
	end,
}

-- Initial attachment can happen while an unnamed buffer is current.
assert(vim.api.nvim_get_current_buf() ~= target)
lib.request_symbol(target, function() end, client)
assert(requests[1] == expected_uri, "initial request used the current buffer")

-- A retry must keep targeting the original document after a buffer switch.
callback({ code = -32801 }, nil)
local other = vim.api.nvim_create_buf(true, false)
vim.api.nvim_buf_set_name(other, vim.fn.tempname() .. ".md")
vim.api.nvim_set_current_buf(other)
assert(vim.wait(2000, function()
	return #requests == 2
end), "retry did not run")
assert(requests[2] == expected_uri, "retry used the current buffer")

-- Keep ignoring unloaded/deleted buffers before resolving their URIs.
vim.api.nvim_buf_delete(target, { force = true })
lib.request_symbol(target, function() end, client)
assert(#requests == 2, "requested symbols for a deleted buffer")
print("PASS: symbol requests target the supplied buffer, including retries")
