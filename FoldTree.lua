local FoldTreeNode = require("dapc-ui.FoldTreeNode")

--- @class FoldData
--- @field node_id number Node id
--- @field fold_level number Level of fold
--- @field depth number Logical depth of fold
--- @field display string Content to display within the fold

--- @class FoldTree
--- @field root FoldTreeNode
--- @field indent string Indent characters for each additional logical depth
local FoldTree = {
	indent = "  ",
}

--- Constructor
function FoldTree:new()
	-- The root node has an id of 0
	local root = FoldTreeNode:new(0, "root")
	local o = {
		root = root,
	}
	setmetatable(o, self)
	self.__index = self
	return o
end

--- Insert a new node
--- @param id number Id of to-be parent node. For the root node, specify 0
--- @param node FoldTreeNode
function FoldTree:insert(id, node)
	self.root:insert(id, node)
end

--- Calculate all the folds for a node
--- @param folds FoldData[] Output to write to
--- @param level number Current fold level
--- @param node FoldTreeNode
function FoldTree:get_node(folds, level, node)
	--- @type FoldData
	local value = { node_id = node.id, display = node.display, depth = level, fold_level = level }
	if node.node_type == FoldTreeNode.TYPE.INNER then
		value.fold_level = level + 1
	end

	if node.id ~= 0 then
		-- exclude recording the root
		table.insert(folds, value)
	end

	if node.node_type == FoldTreeNode.TYPE.LEAF then
		return
	end

	for index, child in ipairs(node.children) do
		FoldTree:get_node(folds, level + 1, child)
	end
end

--- Traverse the tree
--- @return FoldData[] folds
function FoldTree:get()
	local folds = {}
	FoldTree:get_node(folds, -1, self.root)

	return folds
end

--- Render the folds into a specified buffer.
--- This replaces any previous buffer contents.
--- @param buf number Buffer to render into
--- @param folds FoldData[]
function FoldTree:render(buf, folds)
	local fold_map = {}
	-- foldexpr is invoked by neovim as soon as the first nvim_set_lines
	-- is called, so the fold_map that foldexpr references should be set up
	-- before modifying the buffer
	for row, data in ipairs(folds) do
		fold_map[row] = data.fold_level
	end
	vim.g.fold_map = fold_map

	vim.api.nvim_buf_set_lines(buf, 0, -1, false, {}) -- empty the buffer
	for row, data in ipairs(folds) do
		row = row - 1 -- we want 0-indexed

		local line = string.rep(self.indent, data.depth) .. data.display
		if row == 0 then
			vim.api.nvim_buf_set_lines(buf, row, row + 1, false, { line })
		else
			vim.api.nvim_buf_set_lines(buf, row, row, false, { line })
		end
	end
end

return FoldTree
