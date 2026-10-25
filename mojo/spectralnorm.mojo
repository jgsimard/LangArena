from std.math import sqrt
from helper import Helper
from benchmark import Benchmark, Config


struct Spectralnorm(Benchmark):
    var size: Int
    var u: List[Float64]
    var v: List[Float64]
    var result: UInt32

    def __init__(out self, config: Config) raises:
        self.size = config.get_i64("CLBG::Spectralnorm", "size")
        self.u = List[Float64](length=self.size, fill=1.0)
        self.v = List[Float64](length=self.size, fill=1.0)
        self.result = 0

    def class_name(self) -> String:
        return "CLBG::Spectralnorm"

    def run(mut self, iteration_id: Int, mut helper: Helper) raises:
        self.v = Self.eval_AtA_times_u(self.u, self.size)
        self.u = Self.eval_AtA_times_u(self.v, self.size)

    def checksum(mut self) -> UInt32:
        var vBv: Float64 = 0.0
        var vv: Float64 = 0.0
        for i in range(self.size):
            vBv += self.u[i] * self.v[i]
            vv += self.v[i] * self.v[i]
        return Helper.checksum_f64(sqrt(vBv / vv))

    @staticmethod
    def eval_A(i: Int, j: Int) -> Float64:
        return 1.0 / Float64((i + j) * (i + j + 1) / 2 + i + 1)

    @staticmethod
    def eval_A_times_u(u: List[Float64], size: Int) -> List[Float64]:
        var result = List[Float64](capacity=size)
        for i in range(size):
            var v: Float64 = 0.0
            for j in range(size):
                v += Spectralnorm.eval_A(i, j) * u[j]
            result.append(v)
        return result^

    @staticmethod
    def eval_At_times_u(u: List[Float64], size: Int) -> List[Float64]:
        var result = List[Float64](capacity=size)
        for i in range(size):
            var v: Float64 = 0.0
            for j in range(size):
                v += Spectralnorm.eval_A(j, i) * u[j]
            result.append(v)
        return result^

    @staticmethod
    def eval_AtA_times_u(u: List[Float64], size: Int) -> List[Float64]:
        var tmp = Spectralnorm.eval_A_times_u(u, size)
        return Spectralnorm.eval_At_times_u(tmp, size)
