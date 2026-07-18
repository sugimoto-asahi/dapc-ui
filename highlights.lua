--- Retrieve a color from a highlight group
--- @param name string Name of highlight group
--- @param group "fg" | "bg" Part of highlight group to retrieve
local function get_highlight(name, group)
	local highlight = vim.api.nvim_get_hl(0, { name = name })
	if group == "fg" then
		return highlight.fg
	elseif group == "bg" then
		return highlight.bg
	end
end

vim.api.nvim_set_hl(0, "DapUIHeaderItem", { link = "Winbar" })
vim.api.nvim_set_hl(0, "DapUIHeaderItemSel", { link = "TabLineSel" })
vim.api.nvim_set_hl(0, "DapUIUpdatedVariable", { fg = get_highlight("ModeMsg", "fg") })
