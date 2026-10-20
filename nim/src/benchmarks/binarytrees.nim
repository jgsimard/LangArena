import ../benchmark

type
  TreeNodeObj = ref object
    left, right: TreeNodeObj
    item: int32

proc newTreeNodeObj(item: int32, depth: int): TreeNodeObj =
  result = TreeNodeObj(item: item)
  if depth > 0:
    let shift = 1 shl (depth - 1)
    result.left = newTreeNodeObj(int32(item - shift), depth - 1)
    result.right = newTreeNodeObj(int32(item + shift), depth - 1)

{.push overflowChecks: off.}
proc sum(self: TreeNodeObj): int32 =
  var total = self.item + 1
  if not self.left.isNil:
    total += self.left.sum()
  if not self.right.isNil:
    total += self.right.sum()
  return total
{.pop.}

type
  BinarytreesObj* = ref object of Benchmark
    n: int64
    resultVal: uint32

proc newBinarytreesObj(): Benchmark =
  BinarytreesObj()

method name(self: BinarytreesObj): string = "Binarytrees::Obj"

method prepare(self: BinarytreesObj) =
  self.n = self.config_val("depth")
  self.resultVal = 0

method run(self: BinarytreesObj, iteration_id: int) =
  let tree = newTreeNodeObj(0, self.n.int)
  self.resultVal += uint32(tree.sum())

method checksum(self: BinarytreesObj): uint32 =
  self.resultVal

registerBenchmark("Binarytrees::Obj", newBinarytreesObj)

type
  TreeNodeArena = object
    item: int32
    left: int32
    right: int32

  TreeArena = object
    nodes: seq[TreeNodeArena]

proc build(self: var TreeArena, item: int32, depth: int32): int32 =
  let idx = int32(self.nodes.len)
  self.nodes.add(TreeNodeArena(item: item, left: -1, right: -1))

  if depth > 0:
    let shift = 1'i32 shl (depth - 1)
    let leftIdx = self.build(item - shift, depth - 1)
    let rightIdx = self.build(item + shift, depth - 1)
    self.nodes[idx].left = leftIdx
    self.nodes[idx].right = rightIdx

  return idx

{.push overflowChecks: off.}
proc sum(self: TreeArena, idx: int32): int32 =
  let node = self.nodes[idx]
  var total = node.item + 1

  if node.left >= 0:
    total += self.sum(node.left)
  if node.right >= 0:
    total += self.sum(node.right)

  return total
{.pop.}

type
  BinarytreesArena* = ref object of Benchmark
    n: int64
    resultVal: uint32
    arena: TreeArena

proc newBinarytreesArena(): Benchmark =
  result = BinarytreesArena()

method name(self: BinarytreesArena): string = "Binarytrees::Arena"

method prepare(self: BinarytreesArena) =
  self.n = self.config_val("depth")
  self.resultVal = 0
  self.arena.nodes = newSeq[TreeNodeArena]()

method run(self: BinarytreesArena, iteration_id: int) =
  self.arena.nodes.setLen(0)
  let rootIdx = self.arena.build(0, int32(self.n))
  self.resultVal += uint32(self.arena.sum(rootIdx))

method checksum(self: BinarytreesArena): uint32 =
  self.resultVal

registerBenchmark("Binarytrees::Arena", newBinarytreesArena)
{.used.}
