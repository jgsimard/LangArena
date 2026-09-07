#include "compress.hpp"
#include <algorithm>
#include <array>
#include <cstring>
#include <stdexcept>

std::vector<uint8_t> generate_test_data(int64_t size) {
  const char *pattern = "ABRACADABRA";
  size_t pattern_len = strlen(pattern);
  std::vector<uint8_t> data(static_cast<size_t>(size));

  for (int64_t i = 0; i < size; i++) {
    data[static_cast<size_t>(i)] = pattern[i % pattern_len];
  }

  return data;
}

BWTEncode::BWTEncode()
    : size_val(config_val("size")), bwt_result({}, 0), result_val(0) {}

std::string BWTEncode::name() const { return "Compress::BWTEncode"; }

void BWTEncode::prepare() { test_data = generate_test_data(size_val); }

BWTEncode::BWTResult
BWTEncode::bwt_transform(const std::vector<uint8_t> &input) {
  size_t n = input.size();
  if (n == 0)
    return BWTResult({}, 0);

  int32_t counts[256] = {0};
  for (uint8_t byte : input)
    counts[byte]++;

  int32_t positions[256] = {0};
  int32_t total = 0;
  for (int i = 0; i < 256; i++) {
    positions[i] = total;
    total += counts[i];
  }

  std::vector<size_t> sa(n);
  int32_t temp_counts[256] = {0};
  for (size_t i = 0; i < n; i++) {
    uint8_t byte = input[i];
    size_t pos = positions[byte] + temp_counts[byte];
    sa[pos] = i;
    temp_counts[byte]++;
  }

  if (n > 1) {
    std::vector<int32_t> rank(n, 0);
    int32_t current_rank = 0;
    uint8_t prev_char = input[sa[0]];

    for (size_t i = 0; i < n; i++) {
      size_t idx = sa[i];
      uint8_t curr_char = input[idx];
      if (curr_char != prev_char) {
        current_rank++;
        prev_char = curr_char;
      }
      rank[idx] = current_rank;
    }

    size_t k = 1;
    while (k < n) {
      std::vector<std::pair<int32_t, int32_t>> pairs(n);
      for (size_t i = 0; i < n; i++)
        pairs[i] = {rank[i], rank[(i + k) % n]};

      std::sort(sa.begin(), sa.end(), [&pairs](size_t a, size_t b) {
        const auto &pa = pairs[a];
        const auto &pb = pairs[b];
        return pa.first != pb.first ? pa.first < pb.first
                                    : pa.second < pb.second;
      });

      std::vector<int32_t> new_rank(n, 0);
      new_rank[sa[0]] = 0;
      for (size_t i = 1; i < n; i++)
        new_rank[sa[i]] =
            new_rank[sa[i - 1]] + (pairs[sa[i - 1]] != pairs[sa[i]] ? 1 : 0);

      rank = std::move(new_rank);
      k *= 2;
    }
  }

  std::vector<uint8_t> transformed(n);
  int32_t original_idx = 0;

  for (size_t i = 0; i < n; i++) {
    size_t suffix = sa[i];
    if (suffix == 0) {
      transformed[i] = input[n - 1];
      original_idx = static_cast<int32_t>(i);
    } else {
      transformed[i] = input[suffix - 1];
    }
  }

  return BWTResult(std::move(transformed), original_idx);
}

void BWTEncode::run(int iteration_id) {
  (void)iteration_id;
  bwt_result = bwt_transform(test_data);
  result_val += static_cast<uint32_t>(bwt_result.transformed.size());
}

uint32_t BWTEncode::checksum() { return result_val; }

BWTDecode::BWTDecode()
    : size_val(config_val("size")), bwt_result({}, 0), result_val(0) {}

std::string BWTDecode::name() const { return "Compress::BWTDecode"; }

void BWTDecode::prepare() {
  BWTEncode encoder;
  encoder.size_val = size_val;
  encoder.prepare();
  encoder.run(0);
  test_data = encoder.test_data;
  bwt_result = encoder.bwt_result;
}

std::vector<uint8_t>
BWTDecode::bwt_inverse(const BWTEncode::BWTResult &bwt_result) {
  const auto &bwt = bwt_result.transformed;
  size_t n = bwt.size();
  if (n == 0)
    return {};

  int32_t counts[256] = {0};
  for (uint8_t byte : bwt)
    counts[byte]++;

  int32_t positions[256] = {0};
  int32_t total = 0;
  for (int i = 0; i < 256; i++) {
    positions[i] = total;
    total += counts[i];
  }

  std::vector<size_t> next(n, 0);
  int32_t temp_counts[256] = {0};

  for (size_t i = 0; i < n; i++) {
    uint8_t byte = bwt[i];
    size_t pos = static_cast<size_t>(positions[byte] + temp_counts[byte]);
    next[pos] = i;
    temp_counts[byte]++;
  }

  std::vector<uint8_t> result(n);
  size_t idx = static_cast<size_t>(bwt_result.original_idx);

  for (size_t i = 0; i < n; i++) {
    idx = next[idx];
    result[i] = bwt[idx];
  }

  return result;
}

void BWTDecode::run(int iteration_id) {
  (void)iteration_id;
  inverted = bwt_inverse(bwt_result);
  result_val += static_cast<uint32_t>(inverted.size());
}

uint32_t BWTDecode::checksum() {
  if (inverted == test_data)
    result_val += 100000;
  return result_val;
}

HuffEncode::HuffEncode()
    : size_val(config_val("size")), encoded({}, 0, {}), result_val(0) {}

std::string HuffEncode::name() const { return "Compress::HuffEncode"; }

void HuffEncode::prepare() { test_data = generate_test_data(size_val); }

std::shared_ptr<HuffEncode::HuffmanNode>
HuffEncode::build_huffman_tree(const std::vector<int32_t> &frequencies) {
  std::vector<std::shared_ptr<HuffmanNode>> nodes;
  for (int i = 0; i < 256; i++)
    if (frequencies[i] > 0)
      nodes.push_back(std::make_shared<HuffmanNode>(frequencies[i],
                                                    static_cast<uint8_t>(i)));

  std::sort(nodes.begin(), nodes.end(), [](const auto &a, const auto &b) {
    return a->frequency < b->frequency;
  });

  if (nodes.size() == 1) {
    auto node = nodes[0];
    auto root = std::make_shared<HuffmanNode>(node->frequency, 0, false);
    root->left = node;
    root->right = std::make_shared<HuffmanNode>(0, 0);
    return root;
  }

  while (nodes.size() > 1) {
    auto left = nodes[0], right = nodes[1];
    nodes.erase(nodes.begin());
    nodes.erase(nodes.begin());
    auto parent = std::make_shared<HuffmanNode>(
        left->frequency + right->frequency, 0, false);
    parent->left = left;
    parent->right = right;
    auto pos = std::lower_bound(nodes.begin(), nodes.end(), parent,
                                [](const auto &n, const auto &p) {
                                  return n->frequency < p->frequency;
                                });
    nodes.insert(pos, parent);
  }
  return nodes[0];
}

void HuffEncode::build_huffman_codes(const std::shared_ptr<HuffmanNode> &node,
                                     int32_t code, int32_t length,
                                     HuffmanCodes &codes) {
  if (node->is_leaf) {
    if (length > 0 || node->byte_val != 0) {
      int idx = node->byte_val;
      codes.code_lengths[idx] = length;
      codes.codes[idx] = code;
    }
  } else {
    if (node->left)
      build_huffman_codes(node->left, code << 1, length + 1, codes);
    if (node->right)
      build_huffman_codes(node->right, (code << 1) | 1, length + 1, codes);
  }
}

HuffEncode::EncodedResult
HuffEncode::huffman_encode(const std::vector<uint8_t> &data,
                           const HuffmanCodes &codes,
                           const std::vector<int32_t> &frequencies) {
  std::vector<uint8_t> result;
  result.reserve(data.size() * 2);
  uint8_t current_byte = 0;
  int32_t bit_pos = 0, total_bits = 0;

  for (uint8_t byte : data) {
    int idx = byte;
    int32_t code = codes.codes[idx], length = codes.code_lengths[idx];
    for (int i = length - 1; i >= 0; i--) {
      if ((code & (1 << i)) != 0)
        current_byte |= 1 << (7 - bit_pos);
      bit_pos++;
      total_bits++;
      if (bit_pos == 8) {
        result.push_back(current_byte);
        current_byte = 0;
        bit_pos = 0;
      }
    }
  }
  if (bit_pos > 0)
    result.push_back(current_byte);
  return EncodedResult(std::move(result), total_bits, frequencies);
}

void HuffEncode::run(int iteration_id) {
  (void)iteration_id;
  std::vector<int32_t> frequencies(256, 0);
  for (uint8_t byte : test_data)
    frequencies[byte]++;
  auto tree = build_huffman_tree(frequencies);
  HuffmanCodes codes;
  build_huffman_codes(tree, 0, 0, codes);
  encoded = huffman_encode(test_data, codes, frequencies);
  result_val += static_cast<uint32_t>(encoded.data.size());
}

uint32_t HuffEncode::checksum() { return result_val; }

HuffDecode::HuffDecode()
    : size_val(config_val("size")), encoded({}, 0, {}), result_val(0) {}

std::string HuffDecode::name() const { return "Compress::HuffDecode"; }

void HuffDecode::prepare() {
  test_data = generate_test_data(size_val);
  HuffEncode encoder;
  encoder.size_val = size_val;
  encoder.prepare();
  encoder.run(0);
  encoded = encoder.encoded;
}

std::vector<uint8_t>
HuffDecode::huffman_decode(const std::vector<uint8_t> &encoded,
                           const std::shared_ptr<HuffEncode::HuffmanNode> &root,
                           int32_t bit_count) {
  std::vector<uint8_t> result(bit_count);
  size_t result_size = 0;
  const HuffEncode::HuffmanNode *current_node = root.get();
  int32_t bits_processed = 0;
  size_t byte_index = 0;

  while (bits_processed < bit_count && byte_index < encoded.size()) {
    uint8_t byte_val = encoded[byte_index++];
    for (int bit_pos = 7; bit_pos >= 0 && bits_processed < bit_count;
         bit_pos--) {
      bool bit = ((byte_val >> bit_pos) & 1) == 1;
      current_node = bit ? current_node->right.get() : current_node->left.get();
      bits_processed++;
      if (current_node->is_leaf) {
        result[result_size++] = current_node->byte_val;
        current_node = root.get();
      }
    }
  }
  result.resize(result_size);
  return result;
}

void HuffDecode::run(int iteration_id) {
  (void)iteration_id;
  auto tree = HuffEncode::build_huffman_tree(encoded.frequencies);
  decoded = huffman_decode(encoded.data, tree, encoded.bit_count);
  result_val += static_cast<uint32_t>(decoded.size());
}

uint32_t HuffDecode::checksum() {
  uint32_t res = result_val;
  if (decoded == test_data)
    res += 100000;
  return res;
}

ArithEncode::ArithEncode() { size_val = config_val("size"); }

std::string ArithEncode::name() const { return "Compress::ArithEncode"; }

void ArithEncode::prepare() { test_data = generate_test_data(size_val); }

ArithEncode::ArithFreqTable::ArithFreqTable(
    const std::vector<int32_t> &frequencies)
    : total(0), low(256, 0), high(256, 0) {
  for (int32_t f : frequencies)
    total += f;
  int32_t cum = 0;
  for (int i = 0; i < 256; i++) {
    low[i] = cum;
    cum += frequencies[i];
    high[i] = cum;
  }
}

void ArithEncode::BitOutputStream::write_bit(int32_t bit) {
  buffer = (buffer << 1) | (bit & 1);
  bit_pos++;
  bits_written++;
  if (bit_pos == 8) {
    bytes.push_back(buffer);
    buffer = 0;
    bit_pos = 0;
  }
}

std::vector<uint8_t> ArithEncode::BitOutputStream::flush() {
  if (bit_pos > 0) {
    buffer <<= (8 - bit_pos);
    bytes.push_back(buffer);
  }
  return bytes;
}

void ArithEncode::BitOutputStream::clear() {
  buffer = 0;
  bit_pos = 0;
  bytes.clear();
  bits_written = 0;
}

ArithEncode::ArithEncodedResult
ArithEncode::arith_encode(const std::vector<uint8_t> &data) {
  std::vector<int32_t> frequencies(256, 0);
  for (uint8_t byte : data)
    frequencies[byte]++;
  ArithFreqTable freq_table(frequencies);
  uint64_t low = 0, high = 0xFFFFFFFF;
  int32_t pending = 0;
  BitOutputStream output;

  for (uint8_t byte : data) {
    int32_t idx = byte;
    uint64_t range = high - low + 1;
    high = low + (range * freq_table.high[idx] / freq_table.total) - 1;
    low = low + (range * freq_table.low[idx] / freq_table.total);

    while (true) {
      if (high < 0x80000000) {
        output.write_bit(0);
        for (int i = 0; i < pending; i++)
          output.write_bit(1);
        pending = 0;
      } else if (low >= 0x80000000) {
        output.write_bit(1);
        for (int i = 0; i < pending; i++)
          output.write_bit(0);
        pending = 0;
        low -= 0x80000000;
        high -= 0x80000000;
      } else if (low >= 0x40000000 && high < 0xC0000000) {
        pending++;
        low -= 0x40000000;
        high -= 0x40000000;
      } else
        break;
      low <<= 1;
      high = (high << 1) | 1;
      high &= 0xFFFFFFFF;
    }
  }

  pending++;
  if (low < 0x40000000) {
    output.write_bit(0);
    for (int i = 0; i < pending; i++)
      output.write_bit(1);
  } else {
    output.write_bit(1);
    for (int i = 0; i < pending; i++)
      output.write_bit(0);
  }

  return ArithEncodedResult(output.flush(), output.get_bits_written(),
                            frequencies);
}

void ArithEncode::run(int iteration_id) {
  (void)iteration_id;
  encoded = arith_encode(test_data);
  result_val += static_cast<uint32_t>(encoded.data.size());
}

uint32_t ArithEncode::checksum() { return result_val; }

ArithDecode::ArithDecode() : size_val(config_val("size")), result_val(0) {}

std::string ArithDecode::name() const { return "Compress::ArithDecode"; }

void ArithDecode::prepare() {
  test_data = generate_test_data(size_val);
  ArithEncode encoder;
  encoder.size_val = size_val;
  encoder.prepare();
  encoder.run(0);
  encoded = encoder.encoded;
}

ArithDecode::BitInputStream::BitInputStream(const std::vector<uint8_t> &b)
    : bytes(b) {
  if (!bytes.empty())
    current_byte = bytes[0];
}

int32_t ArithDecode::BitInputStream::read_bit() {
  if (bit_pos == 8) {
    byte_pos++;
    bit_pos = 0;
    current_byte = byte_pos < bytes.size() ? bytes[byte_pos] : 0;
  }
  int32_t bit = (current_byte >> (7 - bit_pos)) & 1;
  bit_pos++;
  return bit;
}

std::vector<uint8_t>
ArithDecode::arith_decode(const ArithEncode::ArithEncodedResult &encoded) {
  const auto &frequencies = encoded.frequencies;
  int32_t total = 0;
  for (int32_t f : frequencies)
    total += f;
  int32_t data_size = total;

  std::array<int32_t, 256> low_table = {0}, high_table = {0};
  int32_t cum = 0;
  for (int i = 0; i < 256; i++) {
    low_table[i] = cum;
    cum += frequencies[i];
    high_table[i] = cum;
  }

  std::vector<uint8_t> result(data_size);
  BitInputStream input(encoded.data);

  uint64_t value = 0;
  for (int i = 0; i < 32; i++)
    value = (value << 1) | input.read_bit();

  uint64_t low = 0, high = 0xFFFFFFFF;

  for (int32_t j = 0; j < data_size; j++) {
    uint64_t range = high - low + 1;
    uint64_t scaled = ((value - low + 1) * total - 1) / range;

    auto it = std::upper_bound(high_table.begin(), high_table.end(), scaled);
    uint8_t symbol = std::distance(high_table.begin(), it);
    result[j] = symbol;

    high = low + (range * high_table[symbol] / total) - 1;
    low = low + (range * low_table[symbol] / total);

    while (true) {
      if (high < 0x80000000) {
      } else if (low >= 0x80000000) {
        value -= 0x80000000;
        low -= 0x80000000;
        high -= 0x80000000;
      } else if (low >= 0x40000000 && high < 0xC0000000) {
        value -= 0x40000000;
        low -= 0x40000000;
        high -= 0x40000000;
      } else
        break;
      low <<= 1;
      high = (high << 1) | 1;
      value = (value << 1) | input.read_bit();
    }
  }
  return result;
}

void ArithDecode::run(int iteration_id) {
  (void)iteration_id;
  decoded = arith_decode(encoded);
  result_val += static_cast<uint32_t>(decoded.size());
}

uint32_t ArithDecode::checksum() {
  if (decoded == test_data)
    result_val += 100000;
  return result_val;
}

LZWEncode::LZWEncode() : size_val(config_val("size")), result_val(0) {}

std::string LZWEncode::name() const { return "Compress::LZWEncode"; }

void LZWEncode::prepare() { test_data = generate_test_data(size_val); }

LZWEncode::LZWResult LZWEncode::lzw_encode(const std::vector<uint8_t> &input) {
  if (input.empty())
    return LZWResult();

  std::unordered_map<std::string, int32_t> dict;
  dict.reserve(4096);
  for (int i = 0; i < 256; i++)
    dict[std::string(1, static_cast<char>(i))] = i;

  int32_t next_code = 256;
  std::vector<uint8_t> result;
  result.reserve(input.size() * 2);
  std::string current(1, static_cast<char>(input[0]));

  for (size_t i = 1; i < input.size(); i++) {
    char next_char(static_cast<char>(input[i]));
    std::string new_str = current + next_char;
    if (dict.find(new_str) != dict.end()) {
      current = new_str;
    } else {
      int32_t code = dict[current];
      result.push_back((code >> 8) & 0xFF);
      result.push_back(code & 0xFF);
      dict[new_str] = next_code++;
      current = std::string(1, next_char);
    }
  }

  int32_t code = dict[current];
  result.push_back((code >> 8) & 0xFF);
  result.push_back(code & 0xFF);
  return LZWResult(result, next_code);
}

void LZWEncode::run(int iteration_id) {
  (void)iteration_id;
  encoded = lzw_encode(test_data);
  result_val += static_cast<uint32_t>(encoded.data.size());
}

uint32_t LZWEncode::checksum() { return result_val; }

LZWDecode::LZWDecode() : size_val(config_val("size")), result_val(0) {}

std::string LZWDecode::name() const { return "Compress::LZWDecode"; }

void LZWDecode::prepare() {
  test_data = generate_test_data(size_val);
  LZWEncode encoder;
  encoder.size_val = size_val;
  encoder.prepare();
  encoder.run(0);
  encoded = encoder.encoded;
}

std::vector<uint8_t>
LZWDecode::lzw_decode(const LZWEncode::LZWResult &encoded) {
  if (encoded.data.empty())
    return {};

  std::vector<std::string> dict;
  dict.reserve(4096);
  for (int i = 0; i < 256; i++)
    dict.emplace_back(1, static_cast<char>(i));

  std::vector<uint8_t> result;
  result.reserve(encoded.data.size() * 2);
  const auto &data = encoded.data;
  size_t pos = 0;

  uint16_t high = data[pos], low = data[pos + 1];
  int32_t old_code = (high << 8) | low;
  pos += 2;

  const std::string &old_str = dict[old_code];
  result.insert(result.end(), old_str.begin(), old_str.end());
  int32_t next_code = 256;

  while (pos < data.size()) {
    high = data[pos];
    low = data[pos + 1];
    int32_t new_code = (high << 8) | low;
    pos += 2;

    std::string new_str;
    if (new_code < static_cast<int32_t>(dict.size())) {
      new_str = dict[new_code];
    } else if (new_code == next_code) {
      new_str = dict[old_code] + dict[old_code][0];
    } else {
      return {};
    }

    result.insert(result.end(), new_str.begin(), new_str.end());
    dict.emplace_back(dict[old_code] + new_str[0]);
    next_code++;
    old_code = new_code;
  }
  return result;
}

void LZWDecode::run(int iteration_id) {
  (void)iteration_id;
  decoded = lzw_decode(encoded);
  result_val += static_cast<uint32_t>(decoded.size());
}

uint32_t LZWDecode::checksum() {
  if (decoded == test_data)
    result_val += 100000;
  return result_val;
}