package main

import (
	"encoding/csv"
	"fmt"
	"strconv"
	"strings"
)

type CsvParse struct {
	BaseBenchmark
	rows   int
	data   string
	result uint32
}

func (c *CsvParse) Name() string {
	return "CSV::Parse"
}

func (c *CsvParse) Prepare() {
	c.rows = int(c.ConfigVal("rows"))
	var sb strings.Builder

	for i := 0; i < c.rows; i++ {
		letter := rune('A' + (i % 26))
		x := NextFloat(1.0)
		z := NextFloat(1.0)
		y := NextFloat(1.0)

		sb.WriteString(fmt.Sprintf(`"point %c\n, ""%d""",`, letter, i%100))
		sb.WriteString(fmt.Sprintf("%.10f,", x))
		sb.WriteString(",")
		sb.WriteString(fmt.Sprintf("%.10f,", z))

		flag := "false"
		if i%2 == 0 {
			flag = "true"
		}
		sb.WriteString(fmt.Sprintf(`"[%s\n, %d]",`, flag, i%100))

		sb.WriteString(fmt.Sprintf("%.10f\n", y))
	}

	c.data = sb.String()
}

type Point struct {
	x, y, z float64
}

func (c *CsvParse) parsePoints(csvData string) []Point {
	reader := csv.NewReader(strings.NewReader(csvData))
	records, _ := reader.ReadAll()

	points := make([]Point, 0)

	for _, record := range records {
		x, _ := strconv.ParseFloat(record[1], 64)
		z, _ := strconv.ParseFloat(record[3], 64)
		y, _ := strconv.ParseFloat(record[5], 64)

		points = append(points, Point{x, y, z})
	}

	return points
}

func (c *CsvParse) Run(iteration_id int) {
	points := c.parsePoints(c.data)

	if len(points) == 0 {
		return
	}

	var xSum, ySum, zSum float64
	for _, p := range points {
		xSum += p.x
		ySum += p.y
		zSum += p.z
	}

	length := float64(len(points))
	xAvg := xSum / length
	yAvg := ySum / length
	zAvg := zSum / length

	c.result += ChecksumFloat64(xAvg) + ChecksumFloat64(yAvg) + ChecksumFloat64(zAvg)
}

func (c *CsvParse) Checksum() uint32 {
	return c.result + Checksum(c.data)
}
