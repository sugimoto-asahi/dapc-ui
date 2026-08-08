local FoldTreeNode = require("dapc-ui.FoldTreeNode")
local highlighter = require("dapc-ui.highlighter")

--- @class FoldData
--- @field node_id number Node id
--- @field fold_level number Level of fold
--- @field depth number Logical depth of fold
--- @field line dapc-ui.Line

--- @class FoldTree
--- @field root FoldTreeNode
--- @field indent string Indent characters for each additional logical depth
local FoldTree = {
	indent = " ",
}

--- Constructor
function FoldTree:new()
	-- The root node has an id of 0
	--- @type dapc-ui.Line
	local line = { text = "root", highlights = {} }

	local root = FoldTreeNode:new(0, line)
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

--- Update the display text for a node
--- @param id number Node to update
--- @param display dapc-ui.Line New display string
function FoldTree:update_display(id, display)
	self.root:update_display(id, display)
end

--- Calculate all the folds for a node
--- @param folds FoldData[] Output to write to
--- @param level number Current fold level
--- @param node FoldTreeNode
--- @note The output array FoldData[] is such that the first element is to
--- be displayed on the first row, the second element on the second row, etc.
--- That is, the output array is ordered.
function FoldTree:get_node(folds, level, node)
	--- @type FoldData
	local value = { node_id = node.id, line = node.line, depth = level, fold_level = level }
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
		local indent = string.rep(self.indent, data.depth)

		-- Inserting LINE at row 1 of an empty buffer will result in the
		-- LINE being at row 1, followed by an empty row (2 rows total)
		-- However, this "extra row" issue does not occur if the buffer already
		-- has lines in it, so we have to handle the first row as a special case.
		if row == 1 then
			highlighter.replace(buf, row, data.line, indent)
		else
			highlighter.insert(buf, row, data.line, indent)
		end
	end
end

--- Check if a fold node is open
--- @param id number Node to check
function FoldTree:get_is_open(id)
	return self.root:get_is_open(id)
end

--- Open a fold node
--- @param id number Node to open
function FoldTree:open_node(id)
	self.root:open(id)
end

--- Close a fold node
--- @param id number Node to close
function FoldTree:close_node(id)
	self.root:close(id)
end

return FoldTree
