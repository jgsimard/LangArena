#pragma once

#include "benchmark.hpp"
#include <cstdint>
#include <memory>
#include <vector>

class BinarytreesObj : public Benchmark {
private:
  struct TreeNode {
    std::unique_ptr<TreeNode> left;
    std::unique_ptr<TreeNode> right;
    int32_t item;

    TreeNode(int32_t item, int depth = 0);

    uint32_t sum() const {
      uint32_t total = static_cast<uint32_t>(item) + 1;
      if (left)
        total += left->sum();
      if (right)
        total += right->sum();
      return total;
    }
  };

  int64_t n;
  uint32_t result_val;

public:
  BinarytreesObj();

  std::string name() const override;
  void run(int) override;
  uint32_t checksum() override;
};

class BinarytreesArena : public Benchmark {
private:
  struct TreeNode {
    int32_t item;
    int32_t left;
    int32_t right;

    TreeNode(int32_t item) : item(item), left(-1), right(-1) {}
  };

  std::vector<TreeNode> arena;
  int64_t n;
  uint32_t result_val;

  int32_t build_tree(int32_t item, int32_t depth);
  uint32_t sum(int32_t idx) const;

public:
  BinarytreesArena();

  std::string name() const override;
  void run(int) override;
  uint32_t checksum() override;
};