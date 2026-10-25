from helper import Helper
from benchmark import Benchmark, Config


struct Words(Benchmark):
    var words: Int
    var word_len: Int
    var text: String
    var checksum_: UInt32

    def __init__(out self, config: Config) raises:
        self.words = config.get_i64("Etc::Words", "words")
        self.word_len = config.get_i64("Etc::Words", "word_len")
        self.text = ""
        self.checksum_ = 0

    def class_name(self) -> String:
        return "Etc::Words"

    def prepare(mut self, mut helper: Helper) raises:
        var chars = List[String]()
        for c in range(26):
            chars.append(String(chr(97 + c)))

        self.text = ""
        for i in range(self.words):
            var w_len = helper.next_int(self.word_len) + helper.next_int(3) + 3
            for _ in range(w_len):
                self.text += chars[helper.next_int(len(chars))]
            if i != self.words - 1:
                self.text += " "

    def run(mut self, iteration_id: Int, mut helper: Helper) raises:
        var frequencies = Dict[String, Int]()

        for word in self.text.split(" "):
            if word.byte_length() > 0:
                var word_str = String(word)
                frequencies[word_str] = frequencies.get(word_str).or_else(0) + 1

        var max_word = ""
        var max_count: Int = 0
        for item in frequencies.items():
            if item.value > max_count:
                max_count = item.value
                max_word = item.key

        self.checksum_ += UInt32(max_count)
        self.checksum_ += Helper.checksum_string(max_word)
        self.checksum_ += UInt32(len(frequencies))

    def checksum(mut self) -> UInt32:
        return self.checksum_
