module benchmarks.csv_parse;

import benchmark;
import helper;
import std.array;
import std.conv;
import std.string;
import std.range;
import std.algorithm;
import mir.csv;

class CsvParse : Benchmark
{
private:
    int rows;
    string csvData;
    uint resultVal;

public:
    this()
    {
        resultVal = 0;
        rows = cast(int) configVal("rows");
    }

    override string className() const
    {
        return "CSV::Parse";
    }

    override void prepare()
    {
        auto app = appender!string();
        app.reserve(rows * 50);

        for (int i = 0; i < rows; i++)
        {
            char c = cast(char)('A' + (i % 26));
            double x = Helper.nextFloat(1.0);
            double z = Helper.nextFloat(1.0);
            double y = Helper.nextFloat(1.0);

            app.put(`"point ` ~ c ~ `\n, ""` ~ to!string(i % 100) ~ `""",`);
            app.put(format!"%.10f"(x) ~ ",");
            app.put(",");
            app.put(format!"%.10f"(z) ~ ",");
            app.put(`"[` ~ (i % 2 == 0 ? "true" : "false") ~ `\n, ` ~ to!string(i % 100) ~ `]",`);
            app.put(format!"%.10f"(y) ~ "\n");
        }

        csvData = app.data;
    }

    struct Point
    {
        double x, y, z;
    }

    override void run(int iterationId)
    {
        auto points = parsePoints(csvData);

        if (points.length == 0)
            return;

        double x_sum = 0.0, y_sum = 0.0, z_sum = 0.0;
        foreach (p; points)
        {
            x_sum += p.x;
            y_sum += p.y;
            z_sum += p.z;
        }

        size_t count = points.length;
        double x_avg = x_sum / count;
        double y_avg = y_sum / count;
        double z_avg = z_sum / count;

        resultVal += Helper.checksumF64(x_avg) + Helper.checksumF64(
                y_avg) + Helper.checksumF64(z_avg);
    }

    Point[] parsePoints(string csvData)
    {
        Point[] points;

        auto matrix = csvData.csvToStringMatrix();

        foreach (row; matrix)
        {

            if (row.length >= 6)
            {

                auto x = to!double(row[1]);
                auto z = to!double(row[3]);
                auto y = to!double(row[5]);
                points ~= Point(x, y, z);
            }
        }

        return points;
    }

    override uint checksum()
    {
        return resultVal + Helper.checksum(csvData);
    }
}
