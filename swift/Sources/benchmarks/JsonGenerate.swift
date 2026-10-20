import Foundation

enum OptsTuple: Codable {
  case tuple(Int, Bool)

  init(from decoder: Decoder) throws {
    var c = try decoder.unkeyedContainer()
    let i = try c.decode(Int.self)
    let b = try c.decode(Bool.self)
    self = .tuple(i, b)
  }

  func encode(to encoder: Encoder) throws {
    var c = encoder.unkeyedContainer()
    switch self {
    case .tuple(let i, let b):
      try c.encode(i)
      try c.encode(b)
    }
  }
}

struct JsonCoordinate: Codable {
  let x: Double
  let y: Double
  let z: Double
  let name: String
  let opts: [String: OptsTuple]
}

struct JsonData: Codable {
  let coordinates: [JsonCoordinate]
  let info: String
}

final class JsonGenerate: BenchmarkProtocol {
  public var n: Int64 = 0
  private var data: JsonData
  private var text: String = ""
  private var resultVal: UInt32 = 0

  init() {

    self.data = JsonData(coordinates: [], info: "some info")
    self.n = configValue("coords") ?? 0
  }

  private func roundTo8(_ value: Double) -> Double {
    (value * 100_000_000.0).rounded() / 100_000_000.0
  }

  func prepare() {
    var coords: [JsonCoordinate] = []
    coords.reserveCapacity(Int(n))

    for _ in 0..<Int(n) {
      let x = roundTo8(Double(Helper.nextFloat()))
      let y = roundTo8(Double(Helper.nextFloat()))
      let z = roundTo8(Double(Helper.nextFloat()))
      let name =
        String(format: "%.7f", Helper.nextFloat()) + " " + String(Helper.nextInt(max: 10000))

      coords.append(
        JsonCoordinate(
          x: x,
          y: y,
          z: z,
          name: name,
          opts: ["1": .tuple(1, true)]
        ))
    }

    data = JsonData(coordinates: coords, info: "some info")
  }

  func run(iterationId: Int) {
    let encoder = JSONEncoder()
    if let jsonData = try? encoder.encode(data),
      let jsonString = String(data: jsonData, encoding: .utf8)
    {
      text = jsonString

      if text.hasPrefix("{\"") {
        resultVal &+= 1
      }
    }
  }

  var checksum: UInt32 {
    return resultVal
  }

  func name() -> String {
    return "Json::Generate"
  }

  func getResult() -> String {
    return text
  }
}
