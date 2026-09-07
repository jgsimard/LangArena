package main

import (
	"bytes"
	"slices"
	"sort"
)

func generateTestData(size int64) []byte {
	pattern := []byte("ABRACADABRA")
	data := make([]byte, size)
	patternLen := int64(len(pattern))

	for i := int64(0); i < size; i++ {
		data[i] = pattern[i%patternLen]
	}

	return data
}

type BWTResult struct {
	transformed []byte
	originalIdx int
}

type BWTEncode struct {
	BaseBenchmark
	sizeVal   int64
	testData  []byte
	bwtResult BWTResult
	resultVal uint32
}

func (b *BWTEncode) Name() string {
	return "Compress::BWTEncode"
}

func (b *BWTEncode) Prepare() {
	b.sizeVal = b.ConfigVal("size")
	b.testData = generateTestData(b.sizeVal)
	b.resultVal = 0
}

func (b *BWTEncode) Run(iterationId int) {
	b.bwtResult = b.bwtTransform(b.testData)
	b.resultVal += uint32(len(b.bwtResult.transformed))
}

func (b *BWTEncode) Checksum() uint32 {
	return b.resultVal
}

func (b *BWTEncode) bwtTransform(input []byte) BWTResult {
	n := len(input)
	if n == 0 {
		return BWTResult{[]byte{}, 0}
	}

	counts := [256]int{}
	for i := 0; i < n; i++ {
		counts[input[i]]++
	}

	positions := [256]int{}
	total := 0
	for i := 0; i < 256; i++ {
		positions[i] = total
		total += counts[i]
		counts[i] = 0
	}

	sa := make([]int, n)
	for i := 0; i < n; i++ {
		byteVal := input[i]
		pos := positions[byteVal] + counts[byteVal]
		sa[pos] = i
		counts[byteVal]++
	}

	if n > 1 {
		rank := make([]int, n)
		currentRank := 0
		prevChar := input[sa[0]]

		for i := 0; i < n; i++ {
			idx := sa[i]
			currChar := input[idx]
			if currChar != prevChar {
				currentRank++
				prevChar = currChar
			}
			rank[idx] = currentRank
		}

		k := 1
		for k < n {

			sort.Slice(sa, func(i, j int) bool {
				a, b := sa[i], sa[j]
				ra, rb := rank[a], rank[b]
				if ra != rb {
					return ra < rb
				}
				return rank[(a+k)%n] < rank[(b+k)%n]
			})

			newRank := make([]int, n)
			newRank[sa[0]] = 0
			for i := 1; i < n; i++ {
				prevIdx := sa[i-1]
				currIdx := sa[i]
				if rank[prevIdx] == rank[currIdx] &&
					rank[(prevIdx+k)%n] == rank[(currIdx+k)%n] {
					newRank[currIdx] = newRank[prevIdx]
				} else {
					newRank[currIdx] = newRank[prevIdx] + 1
				}
			}

			rank = newRank
			k *= 2
		}
	}

	transformed := make([]byte, n)
	originalIdx := 0

	for i, suffix := range sa {
		if suffix == 0 {
			transformed[i] = input[n-1]
			originalIdx = i
		} else {
			transformed[i] = input[suffix-1]
		}
	}

	return BWTResult{transformed, originalIdx}
}

type BWTDecode struct {
	BaseBenchmark
	sizeVal   int64
	testData  []byte
	inverted  []byte
	bwtResult BWTResult
	resultVal uint32
}

func (b *BWTDecode) Name() string {
	return "Compress::BWTDecode"
}

func (b *BWTDecode) Prepare() {
	b.sizeVal = b.ConfigVal("size")
	encoder := &BWTEncode{BaseBenchmark: BaseBenchmark{className: "Compress::BWTDecode"}}
	encoder.Prepare()
	encoder.Run(0)
	b.testData = encoder.testData
	b.bwtResult = encoder.bwtResult
	b.resultVal = 0
}

func (b *BWTDecode) Run(iterationId int) {
	b.inverted = b.bwtInverse(b.bwtResult)
	b.resultVal += uint32(len(b.inverted))
}

func (b *BWTDecode) Checksum() uint32 {
	res := b.resultVal
	if bytes.Equal(b.inverted, b.testData) {
		res += 100000
	}
	return res
}

func (b *BWTDecode) bwtInverse(bwtResult BWTResult) []byte {
	bwt := bwtResult.transformed
	n := len(bwt)

	if n == 0 {
		return []byte{}
	}

	counts := [256]int{}
	for _, b := range bwt {
		counts[b]++
	}

	positions := [256]int{}
	total := 0
	for i := 0; i < 256; i++ {
		positions[i] = total
		total += counts[i]
	}

	next := make([]int, n)
	tempCounts := [256]int{}

	for i, b := range bwt {
		byteIdx := int(b)
		pos := positions[byteIdx] + tempCounts[byteIdx]
		next[pos] = i
		tempCounts[byteIdx]++
	}

	result := make([]byte, n)
	idx := bwtResult.originalIdx

	for i := 0; i < n; i++ {
		idx = next[idx]
		result[i] = bwt[idx]
	}

	return result
}

type HuffmanNode struct {
	frequency int
	byteVal   byte
	isLeaf    bool
	left      *HuffmanNode
	right     *HuffmanNode
}

type HuffmanCodes struct {
	codeLengths [256]int
	codes       [256]int
}

type EncodedResult struct {
	data        []byte
	bitCount    int
	frequencies [256]int
}

type HuffEncode struct {
	BaseBenchmark
	sizeVal   int64
	testData  []byte
	encoded   EncodedResult
	resultVal uint32
}

func (h *HuffEncode) Name() string {
	return "Compress::HuffEncode"
}

func (h *HuffEncode) Prepare() {
	h.sizeVal = h.ConfigVal("size")
	if h.sizeVal == 0 {
		h.sizeVal = 1000
	}
	h.testData = generateTestData(h.sizeVal)
	h.resultVal = 0
}

func buildHuffmanTree(frequencies *[256]int) *HuffmanNode {
	nodes := make([]*HuffmanNode, 0)

	for i := 0; i < 256; i++ {
		if frequencies[i] > 0 {
			nodes = append(nodes, &HuffmanNode{
				frequency: frequencies[i],
				byteVal:   byte(i),
				isLeaf:    true,
				left:      nil,
				right:     nil,
			})
		}
	}

	sort.Slice(nodes, func(i, j int) bool {
		return nodes[i].frequency < nodes[j].frequency
	})

	if len(nodes) == 1 {
		node := nodes[0]
		root := &HuffmanNode{
			frequency: node.frequency,
			byteVal:   0,
			isLeaf:    false,
			left:      node,
			right: &HuffmanNode{
				frequency: 0,
				byteVal:   0,
				isLeaf:    true,
			},
		}
		return root
	}

	for len(nodes) > 1 {
		left := nodes[0]
		right := nodes[1]
		nodes = nodes[2:]

		parent := &HuffmanNode{
			frequency: left.frequency + right.frequency,
			byteVal:   0,
			isLeaf:    false,
			left:      left,
			right:     right,
		}

		pos := sort.Search(len(nodes), func(i int) bool {
			return nodes[i].frequency >= parent.frequency
		})

		if pos == len(nodes) {
			nodes = append(nodes, parent)
		} else {
			nodes = append(nodes, nil)
			copy(nodes[pos+1:], nodes[pos:])
			nodes[pos] = parent
		}
	}

	return nodes[0]
}

func buildHuffmanCodes(node *HuffmanNode, code int, length int, codes *HuffmanCodes) {
	if node == nil {
		return
	}

	if node.isLeaf {
		if length > 0 || node.byteVal != 0 {
			idx := int(node.byteVal)
			codes.codeLengths[idx] = length
			codes.codes[idx] = code
		}
	} else {
		if node.left != nil {
			buildHuffmanCodes(node.left, code<<1, length+1, codes)
		}
		if node.right != nil {
			buildHuffmanCodes(node.right, (code<<1)|1, length+1, codes)
		}
	}
}

func (h *HuffEncode) huffmanEncode(data []byte, codes *HuffmanCodes) EncodedResult {
	result := make([]byte, 0, len(data)*2)
	currentByte := byte(0)
	bitPos := 0
	totalBits := 0

	for _, b := range data {
		idx := int(b)
		code := codes.codes[idx]
		length := codes.codeLengths[idx]

		if length <= 0 {
			continue
		}

		for i := length - 1; i >= 0; i-- {
			if (code & (1 << i)) != 0 {
				currentByte |= 1 << (7 - bitPos)
			}
			bitPos++
			totalBits++

			if bitPos == 8 {
				result = append(result, currentByte)
				currentByte = 0
				bitPos = 0
			}
		}
	}

	if bitPos > 0 {
		result = append(result, currentByte)
	}

	return EncodedResult{
		data:     result,
		bitCount: totalBits,
	}
}

func (h *HuffEncode) Run(iterationId int) {
	var frequencies [256]int
	for _, b := range h.testData {
		frequencies[b]++
	}

	tree := buildHuffmanTree(&frequencies)

	var codes HuffmanCodes
	buildHuffmanCodes(tree, 0, 0, &codes)

	encoded := h.huffmanEncode(h.testData, &codes)
	encoded.frequencies = frequencies
	h.encoded = encoded

	h.resultVal += uint32(len(encoded.data))
}

func (h *HuffEncode) Checksum() uint32 {
	return h.resultVal
}

type HuffDecode struct {
	BaseBenchmark
	sizeVal   int64
	testData  []byte
	decoded   []byte
	encoded   EncodedResult
	resultVal uint32
}

func (h *HuffDecode) Name() string {
	return "Compress::HuffDecode"
}

func (h *HuffDecode) huffmanDecode(encoded []byte, root *HuffmanNode, bitCount int) []byte {
	if root == nil || len(encoded) == 0 {
		return []byte{}
	}

	result := make([]byte, bitCount)
	resultSize := 0

	currentNode := root
	bitsProcessed := 0
	byteIndex := 0

	for bitsProcessed < bitCount && byteIndex < len(encoded) {
		byteVal := encoded[byteIndex]
		byteIndex++

		for bitPos := 7; bitPos >= 0 && bitsProcessed < bitCount; bitPos-- {
			bit := ((byteVal >> bitPos) & 1) == 1
			bitsProcessed++

			if bit {
				currentNode = currentNode.right
			} else {
				currentNode = currentNode.left
			}

			if currentNode.isLeaf {
				result[resultSize] = currentNode.byteVal
				resultSize++
				currentNode = root
			}
		}
	}

	return result[:resultSize]
}

func (h *HuffDecode) Prepare() {
	h.sizeVal = h.ConfigVal("size")
	h.testData = generateTestData(h.sizeVal)
	h.resultVal = 0

	encoder := &HuffEncode{}
	encoder.sizeVal = h.sizeVal
	encoder.testData = h.testData
	encoder.Run(0)
	h.encoded = encoder.encoded
}

func (h *HuffDecode) Run(iterationId int) {
	tree := buildHuffmanTree(&h.encoded.frequencies)
	h.decoded = h.huffmanDecode(h.encoded.data, tree, h.encoded.bitCount)
	h.resultVal += uint32(len(h.decoded))
}

func (h *HuffDecode) Checksum() uint32 {
	res := h.resultVal
	if len(h.decoded) == len(h.testData) {
		equal := true
		for i := 0; i < len(h.decoded); i++ {
			if h.decoded[i] != h.testData[i] {
				equal = false
				break
			}
		}
		if equal {
			res += 100000
		}
	}
	return res
}

type ArithFreqTable struct {
	total int
	low   [256]int
	high  [256]int
}

func NewArithFreqTable(frequencies [256]int) *ArithFreqTable {
	ft := &ArithFreqTable{total: 0}

	for _, f := range frequencies {
		ft.total += f
	}

	cum := 0
	for i := 0; i < 256; i++ {
		ft.low[i] = cum
		cum += frequencies[i]
		ft.high[i] = cum
	}

	return ft
}

type BitOutputStream struct {
	buffer      int
	bitPos      int
	bytes       []byte
	bitsWritten int
}

func NewBitOutputStream() *BitOutputStream {
	return &BitOutputStream{
		buffer:      0,
		bitPos:      0,
		bytes:       make([]byte, 0, 1024),
		bitsWritten: 0,
	}
}

func (b *BitOutputStream) WriteBit(bit int) {
	b.buffer = (b.buffer << 1) | (bit & 1)
	b.bitPos++
	b.bitsWritten++

	if b.bitPos == 8 {
		b.bytes = append(b.bytes, byte(b.buffer))
		b.buffer = 0
		b.bitPos = 0
	}
}

func (b *BitOutputStream) Flush() []byte {
	if b.bitPos > 0 {
		b.buffer <<= (8 - b.bitPos)
		b.bytes = append(b.bytes, byte(b.buffer))
	}
	return b.bytes
}

type ArithEncodedResult struct {
	data        []byte
	bitCount    int
	frequencies [256]int
}

type ArithEncode struct {
	BaseBenchmark
	sizeVal   int64
	testData  []byte
	encoded   ArithEncodedResult
	resultVal uint32
}

func (a *ArithEncode) Name() string {
	return "Compress::ArithEncode"
}

func (a *ArithEncode) Prepare() {
	a.sizeVal = a.ConfigVal("size")
	a.testData = generateTestData(a.sizeVal)
	a.resultVal = 0
}

func (a *ArithEncode) Run(iterationId int) {
	a.encoded = a.arithEncode(a.testData)
	a.resultVal += uint32(len(a.encoded.data))
}

func (a *ArithEncode) Checksum() uint32 {
	return a.resultVal
}

func (a *ArithEncode) arithEncode(data []byte) ArithEncodedResult {
	frequencies := [256]int{}
	for _, b := range data {
		frequencies[b]++
	}

	freqTable := NewArithFreqTable(frequencies)

	low := uint64(0)
	high := uint64(0xFFFFFFFF)
	pending := 0
	output := NewBitOutputStream()

	for _, b := range data {
		idx := int(b)
		range_ := high - low + 1

		high = low + (range_ * uint64(freqTable.high[idx]) / uint64(freqTable.total)) - 1
		low = low + (range_ * uint64(freqTable.low[idx]) / uint64(freqTable.total))

		for {
			if high < 0x80000000 {
				output.WriteBit(0)
				for i := 0; i < pending; i++ {
					output.WriteBit(1)
				}
				pending = 0
			} else if low >= 0x80000000 {
				output.WriteBit(1)
				for i := 0; i < pending; i++ {
					output.WriteBit(0)
				}
				pending = 0
				low -= 0x80000000
				high -= 0x80000000
			} else if low >= 0x40000000 && high < 0xC0000000 {
				pending++
				low -= 0x40000000
				high -= 0x40000000
			} else {
				break
			}

			low <<= 1
			high = (high << 1) | 1
			high &= 0xFFFFFFFF
		}
	}

	pending++
	if low < 0x40000000 {
		output.WriteBit(0)
		for i := 0; i < pending; i++ {
			output.WriteBit(1)
		}
	} else {
		output.WriteBit(1)
		for i := 0; i < pending; i++ {
			output.WriteBit(0)
		}
	}

	return ArithEncodedResult{
		data:        output.Flush(),
		bitCount:    output.bitsWritten,
		frequencies: frequencies,
	}
}

type BitInputStream struct {
	bytes       []byte
	bytePos     int
	bitPos      int
	currentByte byte
}

func NewBitInputStream(bytes []byte) *BitInputStream {
	current := byte(0)
	if len(bytes) > 0 {
		current = bytes[0]
	}
	return &BitInputStream{
		bytes:       bytes,
		bytePos:     0,
		bitPos:      0,
		currentByte: current,
	}
}

func (b *BitInputStream) ReadBit() int {
	if b.bitPos == 8 {
		b.bytePos++
		b.bitPos = 0
		if b.bytePos < len(b.bytes) {
			b.currentByte = b.bytes[b.bytePos]
		} else {
			b.currentByte = 0
		}
	}

	bit := int((b.currentByte >> (7 - b.bitPos)) & 1)
	b.bitPos++
	return bit
}

type ArithDecode struct {
	BaseBenchmark
	sizeVal   int64
	testData  []byte
	decoded   []byte
	encoded   ArithEncodedResult
	resultVal uint32
}

func (a *ArithDecode) Name() string {
	return "Compress::ArithDecode"
}

func (a *ArithDecode) Prepare() {
	a.sizeVal = a.ConfigVal("size")
	encoder := &ArithEncode{BaseBenchmark: BaseBenchmark{className: "Compress::ArithDecode"}}
	encoder.Prepare()
	encoder.Run(0)
	a.testData = encoder.testData
	a.encoded = encoder.encoded
	a.resultVal = 0
}

func (a *ArithDecode) Run(iterationId int) {
	a.decoded = a.arithDecode(a.encoded)
	a.resultVal += uint32(len(a.decoded))
}

func (a *ArithDecode) Checksum() uint32 {
	res := a.resultVal
	if bytes.Equal(a.decoded, a.testData) {
		res += 100000
	}
	return res
}

func (a *ArithDecode) arithDecode(encoded ArithEncodedResult) []byte {
	frequencies := encoded.frequencies
	total := 0
	for _, f := range frequencies {
		total += f
	}
	dataSize := total

	lowTable := [256]int{}
	highTable := [256]int{}
	cum := 0
	for i := 0; i < 256; i++ {
		lowTable[i] = cum
		cum += frequencies[i]
		highTable[i] = cum
	}

	result := make([]byte, dataSize)
	input := NewBitInputStream(encoded.data)

	value := uint64(0)
	for i := 0; i < 32; i++ {
		value = (value << 1) | uint64(input.ReadBit())
	}

	low := uint64(0)
	high := uint64(0xFFFFFFFF)

	for j := 0; j < dataSize; j++ {
		range_ := high - low + 1
		scaled := ((value-low+1)*uint64(total) - 1) / range_

		symbol, found := slices.BinarySearch(highTable[:], int(scaled))
		if found {
			symbol++
		}
		result[j] = byte(symbol)

		high = low + (range_ * uint64(highTable[symbol]) / uint64(total)) - 1
		low = low + (range_ * uint64(lowTable[symbol]) / uint64(total))

		for {
			if high < 0x80000000 {

			} else if low >= 0x80000000 {
				value -= 0x80000000
				low -= 0x80000000
				high -= 0x80000000
			} else if low >= 0x40000000 && high < 0xC0000000 {
				value -= 0x40000000
				low -= 0x40000000
				high -= 0x40000000
			} else {
				break
			}

			low <<= 1
			high = (high << 1) | 1
			value = (value << 1) | uint64(input.ReadBit())
		}
	}

	return result
}

type LZWResult struct {
	data     []byte
	dictSize int
}

type LZWEncode struct {
	BaseBenchmark
	sizeVal   int64
	testData  []byte
	encoded   LZWResult
	resultVal uint32
}

func (l *LZWEncode) Name() string {
	return "Compress::LZWEncode"
}

func (l *LZWEncode) Prepare() {
	l.sizeVal = l.ConfigVal("size")
	l.testData = generateTestData(l.sizeVal)
	l.resultVal = 0
}

func (l *LZWEncode) Run(iterationId int) {
	l.encoded = l.lzwEncode(l.testData)
	l.resultVal += uint32(len(l.encoded.data))
}

func (l *LZWEncode) Checksum() uint32 {
	return l.resultVal
}

func (l *LZWEncode) lzwEncode(input []byte) LZWResult {
	if len(input) == 0 {
		return LZWResult{[]byte{}, 256}
	}

	dict := make(map[string]int, 4096)
	for i := 0; i < 256; i++ {
		dict[string([]byte{byte(i)})] = i
	}

	nextCode := 256
	result := make([]byte, 0, len(input)*2)

	current := string([]byte{input[0]})

	for i := 1; i < len(input); i++ {
		nextChar := string([]byte{input[i]})
		newStr := current + nextChar

		if _, ok := dict[newStr]; ok {
			current = newStr
		} else {
			code := dict[current]
			result = append(result, byte((code>>8)&0xFF))
			result = append(result, byte(code&0xFF))

			dict[newStr] = nextCode
			nextCode++
			current = nextChar
		}
	}

	code := dict[current]
	result = append(result, byte((code>>8)&0xFF))
	result = append(result, byte(code&0xFF))

	return LZWResult{result, nextCode}
}

type LZWDecode struct {
	BaseBenchmark
	sizeVal   int64
	testData  []byte
	decoded   []byte
	encoded   LZWResult
	resultVal uint32
}

func (l *LZWDecode) Name() string {
	return "Compress::LZWDecode"
}

func (l *LZWDecode) Prepare() {
	l.sizeVal = l.ConfigVal("size")
	encoder := &LZWEncode{BaseBenchmark: BaseBenchmark{className: "Compress::LZWDecode"}}
	encoder.Prepare()
	encoder.Run(0)
	l.testData = encoder.testData
	l.encoded = encoder.encoded
	l.resultVal = 0
}

func (l *LZWDecode) Run(iterationId int) {
	l.decoded = l.lzwDecode(l.encoded)
	l.resultVal += uint32(len(l.decoded))
}

func (l *LZWDecode) Checksum() uint32 {
	res := l.resultVal
	if bytes.Equal(l.decoded, l.testData) {
		res += 100000
	}
	return res
}

func (l *LZWDecode) lzwDecode(encoded LZWResult) []byte {
	if len(encoded.data) == 0 {
		return []byte{}
	}

	dict := make([]string, 256, 4096)
	for i := 0; i < 256; i++ {
		dict[i] = string(byte(i))
	}

	data := encoded.data
	result := make([]byte, 0, len(data)*2)
	pos := 0

	oldCode := int(data[pos])<<8 | int(data[pos+1])
	pos += 2

	oldStr := dict[oldCode]
	result = append(result, oldStr...)

	nextCode := 256

	for pos < len(data) {

		newCode := int(data[pos])<<8 | int(data[pos+1])
		pos += 2

		var newStr string
		if newCode < nextCode {
			newStr = dict[newCode]
		} else if newCode == nextCode {

			newStr = oldStr + string(oldStr[0])
		} else {
			return []byte{}
		}

		result = append(result, newStr...)

		dict = append(dict, oldStr+string(newStr[0]))
		nextCode++

		oldStr = newStr
	}

	return result
}
