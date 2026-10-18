from max.algorithm.backend.cpu import parallelize
from helper import Helper
from benchmark import Benchmark, Config


struct MatmulSingle(Benchmark, Movable):
    var n: Int
    var a: List[List[Float64]]
    var b: List[List[Float64]]
    var result: UInt32

    def __init__(out self, config: Config) raises:
        self.n = config.get_i64("Matmul::Single", "n")
        if self.n == 0:
            self.n = 100
        self.a = List[List[Float64]]()
        self.b = List[List[Float64]]()
        self.result = 0

    def class_name(self) -> String:
        return "Matmul::Single"

    def prepare(mut self, mut helper: Helper) raises:
        self.a = Self._matgen(self.n)
        self.b = Self._matgen(self.n)
        self.result = 0

    def run(mut self, iteration_id: Int, mut helper: Helper) raises:
        var c = Self._matmul_sequential(self.a, self.b, self.n)
        var center_value = c[self.n >> 1][self.n >> 1]

        self.result += Helper.checksum_f64(center_value)

    def checksum(mut self) -> UInt32:
        return self.result

    @staticmethod
    def _matgen(n: Int) -> List[List[Float64]]:
        var tmp = 1.0 / Float64(n) / Float64(n)
        var a = List[List[Float64]](capacity=n)

        for i in range(n):
            var row = List[Float64](unsafe_uninit_length=n)
            for j in range(n):
                row[j] = tmp * Float64(i - j) * Float64(i + j)
            a.append(row^)

        return a^

    @staticmethod
    def _transpose(b: List[List[Float64]], n: Int) -> List[List[Float64]]:
        var b_t = List[List[Float64]](capacity=n)
        for j in range(n):
            var row = List[Float64](unsafe_uninit_length=n)
            for i in range(n):
                row[i] = b[i][j]
            b_t.append(row^)
        return b_t^

    @staticmethod
    def _matmul_sequential(
        a: List[List[Float64]], b: List[List[Float64]], n: Int
    ) -> List[List[Float64]]:
        var b_t = MatmulSingle._transpose(b, n)
        var c = List[List[Float64]](capacity=n)

        for i in range(n):
            var row = List[Float64](unsafe_uninit_length=n)
            ref ai = a[i]

            for j in range(n):
                var s: Float64 = 0.0
                ref b_tj = b_t[j]

                for k in range(n):
                    s += ai[k] * b_tj[k]

                row[j] = s

            c.append(row^)

        return c^


struct MatmulParallel(Benchmark, Movable):
    var n: Int
    var a: List[List[Float64]]
    var b: List[List[Float64]]
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
        self.a = List[List[Float64]]()
        self.b = List[List[Float64]]()
        self.result = 0

    def class_name(self) -> String:
        return self.config_name

    def prepare(mut self, mut helper: Helper) raises:
        self.a = MatmulSingle._matgen(self.n)
        self.b = MatmulSingle._matgen(self.n)
        self.result = 0

    def run(mut self, iteration_id: Int, mut helper: Helper) raises:
        var c = Self._matmul_parallel(self.a, self.b, self.n, self.num_threads)
        var center_value = c[self.n >> 1][self.n >> 1]

        self.result += Helper.checksum_f64(center_value)

    def checksum(mut self) -> UInt32:
        return self.result

    @staticmethod
    def _matmul_parallel(
        a: List[List[Float64]], b: List[List[Float64]], n: Int, num_threads: Int
    ) -> List[List[Float64]]:
        var b_t = MatmulSingle._transpose(b, n)
        var c = List[List[Float64]](capacity=n)

        for _ in range(n):
            var row = List[Float64](unsafe_uninit_length=n)
            c.append(row^)

        var rows_per_worker = (n + num_threads - 1) // num_threads

        def compute_row(
            worker_id: Int,
        ) {imm a, imm b_t, mut c, imm n, imm rows_per_worker}:
            var start_row = worker_id * rows_per_worker
            var end_row = min(start_row + rows_per_worker, n)

            for i in range(start_row, end_row):
                for j in range(n):
                    var s: Float64 = 0.0
                    for k in range(n):
                        s += a[i][k] * b_t[j][k]
                    c[i][j] = s

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
