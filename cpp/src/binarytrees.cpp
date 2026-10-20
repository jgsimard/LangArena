#include "binarytrees.hpp"

BinarytreesObj::TreeNode::TreeNode(int32_t item, int depth) : item(item) {
  if (depth > 0) {
    left = std::make_unique<TreeNode>(item - (1 << (depth - 1)), depth - 1);
    right = std::make_unique<TreeNode>(item + (1 << (depth - 1)), depth - 1);
  }
}

BinarytreesObj::BinarytreesObj() : n(config_val("depth")), result_val(0) {}

std::string BinarytreesObj::name() const { return "Binarytrees::Obj"; }

void BinarytreesObj::run(int iteration_id) {
  (void)iteration_id;
  TreeNode root(0, n);
  result_val += root.sum();
}

uint32_t BinarytreesObj::checksum() { return result_val; }

BinarytreesArena::BinarytreesArena() : n(config_val("depth")), result_val(0) {}

std::string BinarytreesArena::name() const { return "Binarytrees::Arena"; }

int32_t BinarytreesArena::build_tree(int32_t item, int32_t depth) {
  int32_t idx = static_cast<int32_t>(arena.size());
  arena.emplace_back(item);

  if (depth > 0) {
    int32_t left_idx = build_tree(item - (1 << (depth - 1)), depth - 1);
    int32_t right_idx = build_tree(item + (1 << (depth - 1)), depth - 1);
    auto &node = arena[idx];
    node.left = left_idx;
    node.right = right_idx;
  }

  return idx;
}

uint32_t BinarytreesArena::sum(int32_t idx) const {
  const auto &node = arena[idx];
  uint32_t total = static_cast<uint32_t>(node.item) + 1;

  if (node.left >= 0) {
    total += sum(node.left);
  }
  if (node.right >= 0) {
    total += sum(node.right);
  }

  return total;
}

void BinarytreesArena::run(int iteration_id) {
  (void)iteration_id;
  arena = std::vector<TreeNode>();
  build_tree(0, static_cast<int32_t>(n));
  result_val += sum(0);
}

uint32_t BinarytreesArena::checksum() { return result_val; }