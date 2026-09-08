from std.python import Python
from helper import Helper
from benchmark import Benchmark, Config


struct CsvPoint(Copyable):
    var x: Float64
    var y: Float64
    var z: Float64

    def __init__(out self, x: Float64, y: Float64, z: Float64):
        self.x = x
        self.y = y
        self.z = z


struct CsvParse(Benchmark, Movable):
    var rows: Int
    var _checksum: UInt32
    var data: String

    def __init__(out self, config: Config) raises:
        self.rows = config.get_i64("CSV::Parse", "rows")
        self._checksum = 0
        self.data = ""

    def class_name(self) -> String:
        return "CSV::Parse"

    def prepare(mut self, mut helper: Helper) raises:
        self.data = ""
        for i in range(self.rows):
            var c = chr(65 + (i % 26))
            var x = helper.next_float()
            var z = helper.next_float()
            var y = helper.next_float()

            self.data += '"'
            self.data += "point "
            self.data += c
            self.data += '\\n, ""'
            self.data += String(i % 100)
            self.data += '"""'
            self.data += ","
            self.data += Self._format_f64(x)
            self.data += ","
            self.data += ","
            self.data += Self._format_f64(z)
            self.data += ","
            self.data += '"'
            self.data += "["
            self.data += "true" if i % 2 == 0 else "false"
            self.data += "\\n, "
            self.data += String(i % 100)
            self.data += "]"
            self.data += '"'
            self.data += ","
            self.data += Self._format_f64(y)
            self.data += "\n"

    def run(mut self, iteration_id: Int, mut helper: Helper) raises:
        var csv_mod = Python.import_module("csv")
        var io_mod = Python.import_module("io")
        var builtins = Python.import_module("builtins")

        var reader = csv_mod.reader(io_mod.StringIO(self.data))
        var rows_list = builtins.list(reader)

        var points = List[CsvPoint]()

        for i in range(Int(py=rows_list.__len__())):
            var row = rows_list[i]
            var row_len = Int(py=row.__len__())
            if row_len >= 6:
                var x = atof(StringSlice(String(py=row[1])))
                var z = atof(StringSlice(String(py=row[3])))
                var y = atof(StringSlice(String(py=row[5])))

                points.append(CsvPoint(x, y, z))

        if len(points) == 0:
            return

        var x_sum: Float64 = 0.0
        var y_sum: Float64 = 0.0
        var z_sum: Float64 = 0.0

        for point in points:
            x_sum += point.x
            y_sum += point.y
            z_sum += point.z

        var count = len(points)
        var x_avg = x_sum / Float64(count)
        var y_avg = y_sum / Float64(count)
        var z_avg = z_sum / Float64(count)

        self._checksum = self._checksum + Helper.checksum_f64(x_avg)
        self._checksum = self._checksum + Helper.checksum_f64(y_avg)
        self._checksum = self._checksum + Helper.checksum_f64(z_avg)

    def checksum(self) -> UInt32:
        return self._checksum + Helper.checksum_string(self.data)

    @staticmethod
    def _format_f64(v: Float64) -> String:
        var result = ""
        var val = v
        if val < 0:
            result += "-"
            val = -val
        var int_part = Int(val)
        result += String(int_part)
        result += "."
        var frac_scaled = Int((val - Float64(int_part)) * 10000000000.0 + 0.5)
        var fs = String(frac_scaled)
        while fs.byte_length() < 10:
            fs = "0" + fs
        result += fs
        return result
