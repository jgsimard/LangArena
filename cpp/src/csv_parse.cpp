#include "csv_parse.hpp"
#include "helper.hpp"
#include "lazycsv.hpp"
#include <iomanip>
#include <sstream>
#include <string>
#include <vector>

CsvParse::CsvParse() : rows(config_val("rows")), result_val(0) {}

std::string CsvParse::name() const { return "CSV::Parse"; }

void CsvParse::prepare() {
  std::ostringstream ss;
  ss << std::fixed << std::setprecision(10);

  for (int i = 0; i < rows; i++) {
    char c = 'A' + (i % 26);
    double x = Helper::next_float();
    double z = Helper::next_float();
    double y = Helper::next_float();
    ss << '"' << "point " << c << "\\n, \"\"" << (i % 100) << "\"\"\"" << ','
       << x << ',' << ',' << z << ',' << '"' << '['
       << (i % 2 == 0 ? "true" : "false") << "\\n, " << (i % 100) << ']' << '"'
       << ',' << y << '\n';
  }

  data = ss.str();
}

void CsvParse::run(int iteration_id) {
  (void)iteration_id;
  lazycsv::parser<std::string_view, lazycsv::has_header<false>,
                  lazycsv::delimiter<','>, lazycsv::quote_char<'"'>>
      parser(data);

  std::vector<Point> points;

  for (const auto &row : parser) {
    auto cells = row.cells(1, 3, 5);

    double x = std::stod(std::string(cells[0].trimmed()));
    double z = std::stod(std::string(cells[2].trimmed()));
    double y = std::stod(std::string(cells[1].trimmed()));

    points.emplace_back(x, y, z);
  }

  if (points.empty())
    return;

  double x_sum = 0.0, y_sum = 0.0, z_sum = 0.0;
  for (const auto &p : points) {
    x_sum += p.x;
    y_sum += p.y;
    z_sum += p.z;
  }

  double len = static_cast<double>(points.size());
  double x_avg = x_sum / len;
  double y_avg = y_sum / len;
  double z_avg = z_sum / len;

  result_val += Helper::checksum_f64(x_avg) + Helper::checksum_f64(y_avg) +
                Helper::checksum_f64(z_avg);
}

uint32_t CsvParse::checksum() { return result_val + Helper::checksum(data); }