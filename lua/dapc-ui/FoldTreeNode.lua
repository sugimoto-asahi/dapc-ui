--- @class FoldTreeNode
--- @field id number Unique identifier
--- @field line dapc-ui.Line
--- @field node_type FoldTreeNodeType
--- @field child_map table<number, number> node id -> index of node in children
--- @field children FoldTreeNode[]

local FoldTreeNode = {
	children = {},
	child_map = {},
}

--- @enum FoldTreeNodeType
FoldTreeNode.TYPE = {
	LEAF = "leaf",
	INNER = "inner",
}

--- Constructor
--- @param id number Unique identifier
--- @param display dapc-ui.Line Display info for this node
function FoldTreeNode:new(id, display)
	--- @type FoldTreeNode
	local o = {
		id = id,
		line = display,
		node_type = FoldTreeNode.TYPE.LEAF, -- a new node is always a leaf
		children = {},
		child_map = {},
	}
	setmetatable(o, self)
	self.__index = self

	return o
end

--- Insert a node as a child of this node
--- @param id number Node id of node that should act as parent
--- @param node FoldTreeNode Node to insert
--- @note id must either be the id of this node, or one of its existing children
function FoldTreeNode:insert(id, node)
	if self.id == id then
		-- this is the node we want to insert at
		local last = #self.children
		table.insert(self.children, node)
		self.child_map[node.id] = last + 1

		-- if we are inserting at this node then naturally this node
		-- stops being a leaf
		self.node_type = FoldTreeNode.TYPE.INNER
	else
		-- the node we want to insert at is further down the tree,
		-- so we move towards it
		local target_node_idx = self.child_map[id]

		-- take note of which child node will act as ancestor of the node
		-- being inserted
		self.child_map[node.id] = id
		self.children[target_node_idx]:insert(id, node)
	end
end

--- Update the display text for a node
--- @param id number Node to update
--- @param display dapc-ui.Line New display string
function FoldTreeNode:update_display(id, display)
	if self.id == id then
		-- this is the node we want to insert at
		self.line = display
	else
		-- the node we want to insert at is further down the tree,
		-- so we move towards it
		local target_node_idx = self.child_map[id]
		self.children[target_node_idx]:update_display(id, display)
	end
end

return FoldTreeNode
