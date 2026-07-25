--- Retrieve a color from a highlight group
--- @param name string Name of highlight group
--- @param group "fg" | "bg" Part of highlight group to retrieve
--- @param namespace? number Namespace id of highlight group
local function get_highlight(name, group, namespace)
	local ns = namespace or 0
	local highlight = vim.api.nvim_get_hl(ns, { name = name })
	if group == "fg" then
		return highlight.fg
	elseif group == "bg" then
		return highlight.bg
	end
end
vim.api.nvim_set_hl(0, "DapcBreakpointSign", { link = "DiagnosticError" })
vim.api.nvim_set_hl(0, "DapcBreakpointLine", {})
vim.api.nvim_set_hl(0, "DapcCurrentLine", {
	bg = get_highlight("TabLineSel", "bg"),
})

vim.api.nvim_set_hl(0, "DapUIHeaderItem", { link = "Winbar" })
vim.api.nvim_set_hl(0, "DapUIHeaderItemSel", { link = "TabLineSel" })
vim.api.nvim_set_hl(0, "DapUIUpdatedVariable", { fg = get_highlight("ModeMsg", "fg") })

-- from treesitter-highlight-groups
vim.api.nvim_set_hl(0, "DapUIVariable", { link = "@variable" })

-- from highlight-groups
vim.api.nvim_set_hl(0, "DapUIType", { link = "Type" })
vim.api.nvim_set_hl(0, "DapUIName", { link = "Identifier" })
