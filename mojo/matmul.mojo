from max.algorithm.backend.cpu import parallelize
from layout import TileTensor, row_major
from helper import Helper
from benchmark import Benchmark, Config


struct _Matrix:
    var storage: List[Float64]
    var n: Int

    def __init__(out self, n: Int = 0):
        self.storage = List[Float64](unsafe_uninit_length=n * n)
        self.n = n

    def tensor(
        ref self,
    ) -> TileTensor[
        DType.float64,
        type_of(row_major(Int(0), Int(0))),
        origin_of(self.storage),
    ]:
        return {self.storage, row_major(self.n, self.n)}


struct MatmulSingle(Benchmark, Movable):
    var n: Int
    var a: _Matrix
    var b: _Matrix
    var result: UInt32

    def __init__(out self, config: Config) raises:
        self.n = config.get_i64("Matmul::Single", "n")
        if self.n == 0:
            self.n = 100
        self.a = _Matrix()
        self.b = _Matrix()
        self.result = 0

    def class_name(self) -> String:
        return "Matmul::Single"

    def prepare(mut self, mut helper: Helper) raises:
        self.a = Self._matgen(self.n)
        self.b = Self._matgen(self.n)
        self.result = 0

    def run(mut self, iteration_id: Int, mut helper: Helper) raises:
        var c = Self._matmul_sequential(self.a, self.b, self.n)
        var output = c.tensor()
        var center_value = output[self.n >> 1, self.n >> 1]

        self.result += Helper.checksum_f64(center_value)

    def checksum(mut self) -> UInt32:
        return self.result

    @staticmethod
    def _matgen(n: Int) -> _Matrix:
        var tmp = 1.0 / Float64(n) / Float64(n)
        var a = _Matrix(n)
        var tensor = a.tensor()

        for i in range(n):
            for j in range(n):
                tensor[i, j] = tmp * Float64(i - j) * Float64(i + j)

        return a^

    @staticmethod
    def _transpose(b: _Matrix, n: Int) -> _Matrix:
        var source = b.tensor()
        var b_t = _Matrix(n)
        var output = b_t.tensor()
        for j in range(n):
            for i in range(n):
                output[j, i] = source[i, j]
        return b_t^

    @staticmethod
    def _matmul_sequential(a: _Matrix, b: _Matrix, n: Int) -> _Matrix:
        var b_t = MatmulSingle._transpose(b, n)
        var c = _Matrix(n)
        var input_a = a.tensor()
        var input_b = b_t.tensor()
        var output = c.tensor()

        for i in range(n):
            for j in range(n):
                var s: Float64 = 0.0

                for k in range(n):
                    s += input_a[i, k] * input_b[j, k]

                output[i, j] = s

        return c^


struct MatmulParallel(Benchmark, Movable):
    var n: Int
    var a: _Matrix
    var b: _Matrix
    var result: UInt32
    var num_threads: Int
    var config_name: String

    def __init__(
        out self, config: Config, config_name: String, num_threads: Int
    ) raises:
        self.config_name = config_name
        self.num_threads = num_threads
        self.n = config.get_i64(config_name, "n")
        if self.n == 0:
            self.n = 100
        self.a = _Matrix()
        self.b = _Matrix()
        self.result = 0

    def class_name(self) -> String:
        return self.config_name

    def prepare(mut self, mut helper: Helper) raises:
        self.a = MatmulSingle._matgen(self.n)
        self.b = MatmulSingle._matgen(self.n)
        self.result = 0

    def run(mut self, iteration_id: Int, mut helper: Helper) raises:
        var c = Self._matmul_parallel(self.a, self.b, self.n, self.num_threads)
        var output = c.tensor()
        var center_value = output[self.n >> 1, self.n >> 1]

        self.result += Helper.checksum_f64(center_value)

    def checksum(mut self) -> UInt32:
        return self.result

    @staticmethod
    def _matmul_parallel(
        a: _Matrix, b: _Matrix, n: Int, num_threads: Int
    ) -> _Matrix:
        var b_t = MatmulSingle._transpose(b, n)
        var c = _Matrix(n)
        var input_a = a.tensor()
        var input_b = b_t.tensor()
        var output = c.tensor()

        var rows_per_worker = (n + num_threads - 1) // num_threads

        def compute_row(
            worker_id: Int,
        ) {imm input_a, imm input_b, mut output, imm n, imm rows_per_worker}:
            var start_row = worker_id * rows_per_worker
            var end_row = min(start_row + rows_per_worker, n)

            for i in range(start_row, end_row):
                for j in range(n):
                    var s: Float64 = 0.0
                    for k in range(n):
                        s += input_a[i, k] * input_b[j, k]
                    output[i, j] = s

        parallelize(compute_row, num_threads)
        return c^


struct MatmulT4(Benchmark, Movable):
    var impl: MatmulParallel

    def __init__(out self, config: Config) raises:
        self.impl = MatmulParallel(config, "Matmul::T4", 4)

    def class_name(self) -> String:
        return "Matmul::T4"

    def prepare(mut self, mut helper: Helper) raises:
        self.impl.prepare(helper)

    def run(mut self, iteration_id: Int, mut helper: Helper) raises:
        self.impl.run(iteration_id, helper)

    def checksum(mut self) -> UInt32:
        return self.impl.checksum()


struct MatmulT8(Benchmark, Movable):
    var impl: MatmulParallel

    def __init__(out self, config: Config) raises:
        self.impl = MatmulParallel(config, "Matmul::T8", 8)

    def class_name(self) -> String:
        return "Matmul::T8"

    def prepare(mut self, mut helper: Helper) raises:
        self.impl.prepare(helper)

    def run(mut self, iteration_id: Int, mut helper: Helper) raises:
        self.impl.run(iteration_id, helper)

    def checksum(mut self) -> UInt32:
        return self.impl.checksum()


struct MatmulT16(Benchmark, Movable):
    var impl: MatmulParallel

    def __init__(out self, config: Config) raises:
        self.impl = MatmulParallel(config, "Matmul::T16", 16)

    def class_name(self) -> String:
        return "Matmul::T16"

    def prepare(mut self, mut helper: Helper) raises:
        self.impl.prepare(helper)

    def run(mut self, iteration_id: Int, mut helper: Helper) raises:
        self.impl.run(iteration_id, helper)

    def checksum(mut self) -> UInt32:
        return self.impl.checksum()
