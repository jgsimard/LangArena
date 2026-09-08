module csv_bench;

import benchmark;
import helper;
import std::io;
import std::core::mem;
import std::core::string;

struct Point
{
	double x, y, z;
}

struct PointList
{
	Point* items;
	int count;
	int capacity;
}

fn void point_list_init(PointList* list)
{
	list.items = null;
	list.count = 0;
	list.capacity = 0;
}

fn int point_list_add(PointList* list, Point point)
{
	if (list.count >= list.capacity)
	{
		int new_capacity = list.capacity == 0 ? 16 : list.capacity * 2;
		Point* new_items = mem::realloc(list.items, (usz)new_capacity * Point::size);
		if (!new_items) return -1;
		list.items = new_items;
		list.capacity = new_capacity;
	}
	list.items[list.count++] = point;
	return 0;
}

fn void point_list_free(PointList* list)
{
	mem::free(list.items);
	list.items = null;
	list.count = 0;
	list.capacity = 0;
}

fn int parse_field_value(String field, double* value)
{
	if (field.len >= 2 && field[0] == '"' && field[^1] == '"')
	{
		field = field[1:field.len - 2];
	}
	*value = field.to_double() ?? 0;
	return 0;
}

fn int parse_points(String csv_data, PointList* points)
{
	int field_idx    = 0;
	usz field_start  = 0;
	bool in_quotes   = false;
	double[6] values = { 0, 0, 0, 0, 0, 0 };

	usz pos = 0;
	while (pos < csv_data.len)
	{
		char ch = csv_data[pos];

		if (ch == '"')
		{
			if (in_quotes && pos + 1 < csv_data.len && csv_data[pos + 1] == '"')
			{
				pos += 2;
				continue;
			}
			in_quotes = !in_quotes;
			pos++;
		}
		else if (ch == ',' && !in_quotes)
		{
			if (field_idx == 1 || field_idx == 3 || field_idx == 5)
			{
				String field = csv_data[field_start:pos - field_start];
				if (parse_field_value(field, &values[field_idx]) != 0)
				{
					return -1;
				}
			}
			field_idx++;
			field_start = pos + 1;
			pos++;
		}
		else if (ch == '\n' && !in_quotes)
		{
			if (field_idx < 6)
			{
				if (field_idx == 1 || field_idx == 3 || field_idx == 5)
				{
					String field = csv_data[field_start:pos - field_start];
					if (parse_field_value(field, &values[field_idx]) != 0)
					{
						return -1;
					}
				}
				field_idx++;
			}

			if (field_idx >= 6)
			{
				Point point = { values[1], values[5], values[3] };
				if (point_list_add(points, point) != 0)
				{
					return -1;
				}
			}

			field_idx = 0;
			field_start = pos + 1;
			pos++;
		}
		else
		{
			pos++;
		}
	}

	if (field_start < pos && field_idx > 0)
	{
		if (field_idx < 6)
		{
			if (field_idx == 1 || field_idx == 3 || field_idx == 5)
			{
				String field = csv_data[field_start:pos - field_start];
				if (parse_field_value(field, &values[field_idx]) != 0)
				{
					return -1;
				}
			}
			field_idx++;
		}

		if (field_idx >= 6)
		{
			Point point = { values[1], values[5], values[3] };
			if (point_list_add(points, point) != 0)
			{
				return -1;
			}
		}
	}

	return points.count;
}

struct CsvParseData
{
	String csv_data;
	uint result_val;
	long rows;
}

fn String generate_csv_for_parsing(long rows)
{
	DString buffer;
	buffer.init(mem, (usz)(rows * 100 + 1));
	defer buffer.free();

	for (long i = 0; i < rows; i++)
	{
		char c   = (char)('A' + (i % 26));
		double x = helper::helper_next_float(1.0);
		double z = helper::helper_next_float(1.0);
		double y = helper::helper_next_float(1.0);

		String bool_str = (i % 2 == 0) ? "true" : "false";

		String line = string::tformat(
			"\"point %c\\n, \"\"%d\"\"\",%.10f,,%.10f,\"[%s\\n, %d]\",%.10f\n",
			c,
			(int)(i % 100),
			x,
			z,
			bool_str,
			(int)(i % 100),
			y
		);
		buffer.append(line);
	}

	String result = buffer.str_view();
	char* copy    = mem::alloc_array(char, result.len + 1);
	mem::copy(copy, (char*)result, result.len);
	copy[result.len] = 0;
	return ((ZString)copy).str_view();
}

fn void csv_parse_prepare(Benchmark* self)
{
	CsvParseData* data = (CsvParseData*)self.data;
	data.rows = helper::helper_config_i64(self.name, "rows");
	data.csv_data = generate_csv_for_parsing(data.rows);
	data.result_val = 0;
}

fn void csv_parse_run(Benchmark* self, int iteration_id)
{
	CsvParseData* data = (CsvParseData*)self.data;
	if (data.csv_data.len == 0) return;

	PointList points;
	point_list_init(&points);

	int point_count = parse_points(data.csv_data, &points);

	if (point_count > 0)
	{
		double x_sum = 0;
		double y_sum = 0;
		double z_sum = 0;
		for (int i = 0; i < points.count; i++)
		{
			x_sum += points.items[i].x;
			y_sum += points.items[i].y;
			z_sum += points.items[i].z;
		}

		double len = (double)points.count;
		data.result_val += helper::helper_checksum_f64(
			x_sum / len
		) + helper::helper_checksum_f64(y_sum / len) + helper::helper_checksum_f64(z_sum / len);
	}

	point_list_free(&points);
}

fn uint csv_parse_checksum(Benchmark* self)
{
	CsvParseData* data = (CsvParseData*)self.data;
	return data.result_val + helper::helper_checksum_string(data.csv_data);
}

fn void csv_parse_cleanup(Benchmark* self)
{
	CsvParseData* data = (CsvParseData*)self.data;
	if (data.csv_data.ptr)
	{
		mem::free((void*)data.csv_data.ptr);
		data.csv_data = { };
	}
}

fn Benchmark* csv_parse_create() @cname("CsvParse_create") @export
{
	Benchmark* bench = benchmark::benchmark_create("CSV::Parse");

	CsvParseData* data = mem::new(CsvParseData);

	bench.data = data;
	bench.prepare = (PrepareFn)&csv_parse_prepare;
	bench.run = (RunFn)&csv_parse_run;
	bench.checksum = (ChecksumFn)&csv_parse_checksum;
	bench.cleanup = (CleanupFn)&csv_parse_cleanup;

	return bench;
}