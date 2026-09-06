from std.time import perf_counter_ns
from std.sys import argv
from std.utils.variant import Variant
from helper import Helper
from benchmark import Benchmark, Config
from binarytrees import BinarytreesObj, BinarytreesArena
from brainfuck_array import BrainfuckArray
from brainfuck_recursion import BrainfuckRecursion
from matmul import MatmulSingle, MatmulT4, MatmulT8, MatmulT16
from base64 import Base64Encode, Base64Decode
from fannkuchredux import Fannkuchredux
from spectralnorm import Spectralnorm
from mandelbrot import Mandelbrot
from nbody import Nbody
from distance import DistanceJaro, DistanceNGram
from maze import MazeGenerator, MazeBFS, MazeAStar
from buffer_hash import HashSHA256, HashCRC32
from graph_path import GraphBFS, GraphDFS, GraphAStar
from sort import SortQuick, SortMerge, SortSelf
from sieve import Sieve
from text_raytracer import TextRaytracer
from neural_net import NeuralNet
from cache_simulation import CacheSimulation
from game_of_life import GameOfLife
from words import Words
from calculator import CalculatorAst, CalculatorInterpreter
from compress import BWTEncode, BWTDecode, HuffEncode, HuffDecode
from compress import ArithEncode, ArithDecode, LZWEncode, LZWDecode
from csv import CsvParse
from log_parser import LogParser
from template import TemplateRegex, TemplateParse
from json import JsonGenerate, JsonParseDom, JsonParseMapping

comptime BenchVariant = Variant[
    BinarytreesObj,
    BinarytreesArena,
    BrainfuckArray,
    BrainfuckRecursion,
    MatmulSingle,
    MatmulT4,
    MatmulT8,
    MatmulT16,
    Base64Encode,
    Base64Decode,
    Fannkuchredux,
    Spectralnorm,
    Mandelbrot,
    Nbody,
    DistanceJaro,
    DistanceNGram,
    MazeGenerator,
    MazeBFS,
    MazeAStar,
    HashSHA256,
    HashCRC32,
    GraphBFS,
    GraphDFS,
    GraphAStar,
    SortQuick,
    SortMerge,
    SortSelf,
    Sieve,
    TextRaytracer,
    NeuralNet,
    CacheSimulation,
    GameOfLife,
    Words,
    CalculatorAst,
    CalculatorInterpreter,
    BWTEncode,
    BWTDecode,
    HuffEncode,
    HuffDecode,
    ArithEncode,
    ArithDecode,
    LZWEncode,
    LZWDecode,
    CsvParse,
    LogParser,
    TemplateRegex,
    TemplateParse,
    JsonGenerate,
    JsonParseDom,
    JsonParseMapping,
]


def create_benchmark(name: String, config: Config) raises -> BenchVariant:
    if name == "Binarytrees::Obj":
        return BenchVariant(BinarytreesObj(config))
    elif name == "Binarytrees::Arena":
        return BenchVariant(BinarytreesArena(config))
    elif name == "Brainfuck::Array":
        return BenchVariant(BrainfuckArray(config))
    elif name == "Brainfuck::Recursion":
        return BenchVariant(BrainfuckRecursion(config))
    elif name == "Matmul::Single":
        return BenchVariant(MatmulSingle(config))
    elif name == "Matmul::T4":
        return BenchVariant(MatmulT4(config))
    elif name == "Matmul::T8":
        return BenchVariant(MatmulT8(config))
    elif name == "Matmul::T16":
        return BenchVariant(MatmulT16(config))
    elif name == "Base64::Encode":
        return BenchVariant(Base64Encode(config))
    elif name == "Base64::Decode":
        return BenchVariant(Base64Decode(config))
    elif name == "CLBG::Fannkuchredux":
        return BenchVariant(Fannkuchredux(config))
    elif name == "CLBG::Spectralnorm":
        return BenchVariant(Spectralnorm(config))
    elif name == "CLBG::Mandelbrot":
        return BenchVariant(Mandelbrot(config))
    elif name == "CLBG::Nbody":
        return BenchVariant(Nbody(config))
    elif name == "Distance::Jaro":
        return BenchVariant(DistanceJaro(config))
    elif name == "Distance::NGram":
        return BenchVariant(DistanceNGram(config))
    elif name == "Maze::Generator":
        return BenchVariant(MazeGenerator(config))
    elif name == "Maze::BFS":
        return BenchVariant(MazeBFS(config))
    elif name == "Maze::AStar":
        return BenchVariant(MazeAStar(config))
    elif name == "Hash::SHA256":
        return BenchVariant(HashSHA256(config))
    elif name == "Hash::CRC32":
        return BenchVariant(HashCRC32(config))
    elif name == "Graph::BFS":
        return BenchVariant(GraphBFS(config))
    elif name == "Graph::DFS":
        return BenchVariant(GraphDFS(config))
    elif name == "Graph::AStar":
        return BenchVariant(GraphAStar(config))
    elif name == "Sort::Quick":
        return BenchVariant(SortQuick(config))
    elif name == "Sort::Merge":
        return BenchVariant(SortMerge(config))
    elif name == "Sort::Self":
        return BenchVariant(SortSelf(config))
    elif name == "Etc::Sieve":
        return BenchVariant(Sieve(config))
    elif name == "Etc::TextRaytracer":
        return BenchVariant(TextRaytracer(config))
    elif name == "Etc::NeuralNet":
        return BenchVariant(NeuralNet(config))
    elif name == "Etc::CacheSimulation":
        return BenchVariant(CacheSimulation(config))
    elif name == "Etc::GameOfLife":
        return BenchVariant(GameOfLife(config))
    elif name == "Etc::Words":
        return BenchVariant(Words(config))
    elif name == "Calculator::Ast":
        return BenchVariant(CalculatorAst(config))
    elif name == "Calculator::Interpreter":
        return BenchVariant(CalculatorInterpreter(config))
    elif name == "Compress::BWTEncode":
        return BenchVariant(BWTEncode(config))
    elif name == "Compress::BWTDecode":
        return BenchVariant(BWTDecode(config))
    elif name == "Compress::HuffEncode":
        return BenchVariant(HuffEncode(config))
    elif name == "Compress::HuffDecode":
        return BenchVariant(HuffDecode(config))
    elif name == "Compress::ArithEncode":
        return BenchVariant(ArithEncode(config))
    elif name == "Compress::ArithDecode":
        return BenchVariant(ArithDecode(config))
    elif name == "Compress::LZWEncode":
        return BenchVariant(LZWEncode(config))
    elif name == "Compress::LZWDecode":
        return BenchVariant(LZWDecode(config))
    elif name == "CSV::Parse":
        return BenchVariant(CsvParse(config))
    elif name == "Etc::LogParser":
        return BenchVariant(LogParser(config))
    elif name == "Template::Regex":
        return BenchVariant(TemplateRegex(config))
    elif name == "Template::Parse":
        return BenchVariant(TemplateParse(config))
    elif name == "Json::Generate":
        return BenchVariant(JsonGenerate(config))
    elif name == "Json::ParseDom":
        return BenchVariant(JsonParseDom(config))
    elif name == "Json::ParseMapping":
        return BenchVariant(JsonParseMapping(config))
    else:
        raise Error(String("Unknown benchmark: ", name))


def dispatch_bench(
    mut bench: BenchVariant,
    name: String,
    config: Config,
    mut helper: Helper,
    mut summary_time: Float64,
    mut ok: Int,
    mut fails: Int,
) raises:
    if bench.isa[BinarytreesObj]():
        run_single(
            name, bench[BinarytreesObj], config, helper, summary_time, ok, fails
        )
    elif bench.isa[BinarytreesArena]():
        run_single(
            name,
            bench[BinarytreesArena],
            config,
            helper,
            summary_time,
            ok,
            fails,
        )
    elif bench.isa[BrainfuckArray]():
        run_single(
            name, bench[BrainfuckArray], config, helper, summary_time, ok, fails
        )
    elif bench.isa[BrainfuckRecursion]():
        run_single(
            name,
            bench[BrainfuckRecursion],
            config,
            helper,
            summary_time,
            ok,
            fails,
        )
    elif bench.isa[MatmulSingle]():
        run_single(
            name, bench[MatmulSingle], config, helper, summary_time, ok, fails
        )
    elif bench.isa[MatmulT4]():
        run_single(
            name, bench[MatmulT4], config, helper, summary_time, ok, fails
        )
    elif bench.isa[MatmulT8]():
        run_single(
            name, bench[MatmulT8], config, helper, summary_time, ok, fails
        )
    elif bench.isa[MatmulT16]():
        run_single(
            name, bench[MatmulT16], config, helper, summary_time, ok, fails
        )
    elif bench.isa[Base64Encode]():
        run_single(
            name, bench[Base64Encode], config, helper, summary_time, ok, fails
        )
    elif bench.isa[Base64Decode]():
        run_single(
            name, bench[Base64Decode], config, helper, summary_time, ok, fails
        )
    elif bench.isa[Fannkuchredux]():
        run_single(
            name, bench[Fannkuchredux], config, helper, summary_time, ok, fails
        )
    elif bench.isa[Spectralnorm]():
        run_single(
            name, bench[Spectralnorm], config, helper, summary_time, ok, fails
        )
    elif bench.isa[Mandelbrot]():
        run_single(
            name, bench[Mandelbrot], config, helper, summary_time, ok, fails
        )
    elif bench.isa[Nbody]():
        run_single(name, bench[Nbody], config, helper, summary_time, ok, fails)
    elif bench.isa[DistanceJaro]():
        run_single(
            name, bench[DistanceJaro], config, helper, summary_time, ok, fails
        )
    elif bench.isa[DistanceNGram]():
        run_single(
            name, bench[DistanceNGram], config, helper, summary_time, ok, fails
        )
    elif bench.isa[MazeGenerator]():
        run_single(
            name, bench[MazeGenerator], config, helper, summary_time, ok, fails
        )
    elif bench.isa[MazeBFS]():
        run_single(
            name, bench[MazeBFS], config, helper, summary_time, ok, fails
        )
    elif bench.isa[MazeAStar]():
        run_single(
            name, bench[MazeAStar], config, helper, summary_time, ok, fails
        )
    elif bench.isa[HashSHA256]():
        run_single(
            name, bench[HashSHA256], config, helper, summary_time, ok, fails
        )
    elif bench.isa[HashCRC32]():
        run_single(
            name, bench[HashCRC32], config, helper, summary_time, ok, fails
        )
    elif bench.isa[GraphBFS]():
        run_single(
            name, bench[GraphBFS], config, helper, summary_time, ok, fails
        )
    elif bench.isa[GraphDFS]():
        run_single(
            name, bench[GraphDFS], config, helper, summary_time, ok, fails
        )
    elif bench.isa[GraphAStar]():
        run_single(
            name, bench[GraphAStar], config, helper, summary_time, ok, fails
        )
    elif bench.isa[SortQuick]():
        run_single(
            name, bench[SortQuick], config, helper, summary_time, ok, fails
        )
    elif bench.isa[SortMerge]():
        run_single(
            name, bench[SortMerge], config, helper, summary_time, ok, fails
        )
    elif bench.isa[SortSelf]():
        run_single(
            name, bench[SortSelf], config, helper, summary_time, ok, fails
        )
    elif bench.isa[Sieve]():
        run_single(name, bench[Sieve], config, helper, summary_time, ok, fails)
    elif bench.isa[TextRaytracer]():
        run_single(
            name, bench[TextRaytracer], config, helper, summary_time, ok, fails
        )
    elif bench.isa[NeuralNet]():
        run_single(
            name, bench[NeuralNet], config, helper, summary_time, ok, fails
        )
    elif bench.isa[CacheSimulation]():
        run_single(
            name,
            bench[CacheSimulation],
            config,
            helper,
            summary_time,
            ok,
            fails,
        )
    elif bench.isa[GameOfLife]():
        run_single(
            name, bench[GameOfLife], config, helper, summary_time, ok, fails
        )
    elif bench.isa[Words]():
        run_single(name, bench[Words], config, helper, summary_time, ok, fails)
    elif bench.isa[CalculatorAst]():
        run_single(
            name, bench[CalculatorAst], config, helper, summary_time, ok, fails
        )
    elif bench.isa[CalculatorInterpreter]():
        run_single(
            name,
            bench[CalculatorInterpreter],
            config,
            helper,
            summary_time,
            ok,
            fails,
        )
    elif bench.isa[BWTEncode]():
        run_single(
            name, bench[BWTEncode], config, helper, summary_time, ok, fails
        )
    elif bench.isa[BWTDecode]():
        run_single(
            name, bench[BWTDecode], config, helper, summary_time, ok, fails
        )
    elif bench.isa[HuffEncode]():
        run_single(
            name, bench[HuffEncode], config, helper, summary_time, ok, fails
        )
    elif bench.isa[HuffDecode]():
        run_single(
            name, bench[HuffDecode], config, helper, summary_time, ok, fails
        )
    elif bench.isa[ArithEncode]():
        run_single(
            name, bench[ArithEncode], config, helper, summary_time, ok, fails
        )
    elif bench.isa[ArithDecode]():
        run_single(
            name, bench[ArithDecode], config, helper, summary_time, ok, fails
        )
    elif bench.isa[LZWEncode]():
        run_single(
            name, bench[LZWEncode], config, helper, summary_time, ok, fails
        )
    elif bench.isa[LZWDecode]():
        run_single(
            name, bench[LZWDecode], config, helper, summary_time, ok, fails
        )
    elif bench.isa[CsvParse]():
        run_single(
            name, bench[CsvParse], config, helper, summary_time, ok, fails
        )
    elif bench.isa[LogParser]():
        run_single(
            name, bench[LogParser], config, helper, summary_time, ok, fails
        )
    elif bench.isa[TemplateRegex]():
        run_single(
            name, bench[TemplateRegex], config, helper, summary_time, ok, fails
        )
    elif bench.isa[TemplateParse]():
        run_single(
            name, bench[TemplateParse], config, helper, summary_time, ok, fails
        )
    elif bench.isa[JsonGenerate]():
        run_single(
            name, bench[JsonGenerate], config, helper, summary_time, ok, fails
        )
    elif bench.isa[JsonParseDom]():
        run_single(
            name, bench[JsonParseDom], config, helper, summary_time, ok, fails
        )
    elif bench.isa[JsonParseMapping]():
        run_single(
            name,
            bench[JsonParseMapping],
            config,
            helper,
            summary_time,
            ok,
            fails,
        )


def run_benchmarks(config: Config, single_bench: Optional[String]) raises:
    var summary_time: Float64 = 0.0
    var ok: Int = 0
    var fails: Int = 0
    var helper = Helper()

    for i in range(len(config.entries)):
        ref entry = config.entries[i]
        var bench_name = entry.name

        if single_bench:
            var target = single_bench[]
            if target.lower() not in bench_name.lower():
                continue

        var bench = create_benchmark(bench_name, config)
        dispatch_bench(
            bench, bench_name, config, helper, summary_time, ok, fails
        )

    print(
        String(
            "Summary: ",
            summary_time,
            "s, ",
            ok + fails,
            ", ",
            ok,
            ", ",
            fails,
        )
    )
    if fails > 0:
        raise Error("Benchmarks failed")


def run_single[
    BenchType: Benchmark
](
    name: String,
    mut bench: BenchType,
    config: Config,
    mut helper: Helper,
    mut summary_time: Float64,
    mut ok: Int,
    mut fails: Int,
) raises:
    helper.reset()
    bench.prepare(helper)
    var warmup_iters = bench.warmup_iterations(config)
    bench.warmup(warmup_iters, helper)
    helper.reset()

    var iters = bench.iterations(config)
    var t = perf_counter_ns()
    for i in range(iters):
        bench.run(i, helper)
    var time_delta = Float64(perf_counter_ns() - t) / 1_000_000_000.0

    var check = bench.checksum()
    var expect = bench.expected_checksum(config)

    var status: String
    if check == expect:
        status = "OK"
        ok += 1
    else:
        status = String("ERR[actual=", check, ", expected=", expect, "]")
        fails += 1

    print(String(name, ": ", status, " in ", time_delta, "s"))
    summary_time += time_delta


def main() raises:
    var args = argv()
    var argc = len(args)

    var config_path: String
    var single_bench: Optional[String] = Optional[String](None)

    if argc > 1:
        config_path = String(args[1])
    else:
        config_path = "./test.js"

    if argc > 2:
        single_bench = Optional[String](String(args[2]))

    with open("/tmp/recompile_marker", "w") as f:
        f.write("RECOMPILE_MARKER_0")
    var config = Config(config_path)
    run_benchmarks(config, single_bench)
