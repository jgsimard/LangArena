package main

type TreeNodeObj struct {
	left  *TreeNodeObj
	right *TreeNodeObj
	item  int32
}

func NewTreeNodeObj(item int32, depth int) *TreeNodeObj {
	node := &TreeNodeObj{item: item}
	if depth > 0 {
		shift := int32(1 << (depth - 1))
		node.left = NewTreeNodeObj(item-shift, depth-1)
		node.right = NewTreeNodeObj(item+shift, depth-1)
	}
	return node
}

func (t *TreeNodeObj) Sum() uint32 {
	total := uint32(t.item) + 1
	if t.left != nil {
		total += t.left.Sum()
	}
	if t.right != nil {
		total += t.right.Sum()
	}
	return total
}

type BinarytreesObj struct {
	BaseBenchmark
	n      int64
	result uint32
}

func (b *BinarytreesObj) Prepare() {
	b.n = b.ConfigVal("depth")
	b.result = 0
}

func (b *BinarytreesObj) Run(iteration_id int) {
	root := NewTreeNodeObj(0, int(b.n))
	b.result += root.Sum()

}

func (b *BinarytreesObj) Checksum() uint32 {
	return b.result
}

type TreeNodeArena struct {
	item  int32
	left  int32
	right int32
}

type TreeArena struct {
	nodes []TreeNodeArena
}

func (a *TreeArena) Build(item, depth int32) int32 {
	idx := int32(len(a.nodes))
	a.nodes = append(a.nodes, TreeNodeArena{item: item, left: -1, right: -1})

	if depth > 0 {
		shift := int32(1) << (depth - 1)
		leftIdx := a.Build(item-shift, depth-1)
		rightIdx := a.Build(item+shift, depth-1)
		node := &a.nodes[idx]
		node.left = leftIdx
		node.right = rightIdx
	}

	return idx
}

func (a *TreeArena) Sum(idx int32) uint32 {
	node := &a.nodes[idx]
	total := uint32(node.item) + 1

	if node.left >= 0 {
		total += a.Sum(node.left)
	}
	if node.right >= 0 {
		total += a.Sum(node.right)
	}

	return total
}

type BinarytreesArena struct {
	BaseBenchmark
	n      int64
	result uint32
	arena  TreeArena
}

func (b *BinarytreesArena) Prepare() {
	b.n = b.ConfigVal("depth")
	b.result = 0
	b.arena.nodes = make([]TreeNodeArena, 0)
}

func (b *BinarytreesArena) Run(iteration_id int) {
	b.arena.nodes = b.arena.nodes[:0]
	rootIdx := b.arena.Build(0, int32(b.n))
	b.result += b.arena.Sum(rootIdx)
}

func (b *BinarytreesArena) Checksum() uint32 {
	return b.result
}
