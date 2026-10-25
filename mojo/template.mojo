from moregex import Regex, finditer_span
from helper import Helper
from benchmark import Benchmark, Config


struct TemplateRegex(Benchmark):
    comptime _PATTERN = Regex(r"\{\{(.*?)\}\}")

    var count: Int
    var text: String
    var rendered: String
    var checksum_val: UInt32
    var vars: Dict[String, String]

    def __init__(out self, config: Config) raises:
        self.count = config.get_i64("Template::Regex", "count")
        self.text = ""
        self.rendered = ""
        self.checksum_val = 0
        self.vars = Dict[String, String]()

    def class_name(self) -> String:
        return "Template::Regex"

    def prepare(mut self, mut helper: Helper) raises:
        self.vars = Dict[String, String]()
        Self._prepare_template(self.count, self.vars)
        self.text = Self._build_text(self.count)

    def run(mut self, iteration_id: Int, mut helper: Helper) raises:
        var text = self.text[byte = 0 : self.text.byte_length()]
        var rendered = String(capacity_bytes=text.byte_length())
        var cursor = 0

        for found in finditer_span[Self._PATTERN](text):
            rendered += text[byte = cursor : found.start()]
            var key = String(found.group_span(text, 1).strip())
            if key in self.vars:
                rendered += self.vars[key]
            cursor = found.end()

        rendered += text[byte = cursor : text.byte_length()]
        self.checksum_val += UInt32(rendered.byte_length())
        self.rendered = rendered^

    def checksum(self) -> UInt32:
        return (
            self.checksum_val + Helper.checksum_string(self.rendered)
        ) & 0xFFFFFFFF

    @staticmethod
    def _prepare_template(count: Int, mut vars: Dict[String, String]):
        var first_names = [
            "John",
            "Jane",
            "Bob",
            "Alice",
            "Charlie",
            "Diana",
            "Sarah",
            "Mike",
        ]

        var last_names = [
            "Smith",
            "Johnson",
            "Brown",
            "Taylor",
            "Wilson",
            "Davis",
            "Miller",
            "Jones",
        ]

        var cities = [
            "New York",
            "Los Angeles",
            "Chicago",
            "Houston",
            "Phoenix",
            "San Francisco",
        ]

        vars["TITLE"] = "Template title"

        for i in range(count):
            vars["FIRST_NAME" + String(i)] = first_names[i % len(first_names)]
            vars["LAST_NAME" + String(i)] = last_names[i % len(last_names)]
            vars["CITY" + String(i)] = cities[i % len(cities)]

    @staticmethod
    def _build_text(count: Int) -> String:
        var text = (
            "<html><body><h1>{{TITLE}}</h1><p>"
            "Lorem {ipsum} dolor {sit} amet, consectetur adipiscing elit. Sed"
            " do eiusmod tempor incididunt ut labore {et} dolore magna aliqua. "
            "</p><table>"
        )

        for i in range(count):
            if i % 3 == 0:
                text += "<!-- {comment} -->"
            text += String(
                t"<tr><td>{{{{ FIRST_NAME{i} }}}}</td>"
                t"<td>{{{{LAST_NAME{i}}}}}</td>"
                t"<td>{{{{  CITY{i}  }}}}</td>"
                t"<td>{{balance: {i % 100}}}</td></tr>\n"
            )

        text += "</table></body></html>"
        return text


struct TemplateParse(Benchmark):
    var count: Int
    var text: String
    var rendered: String
    var checksum_val: UInt32
    var vars: Dict[String, String]

    def __init__(out self, config: Config) raises:
        self.count = config.get_i64("Template::Parse", "count")
        self.text = ""
        self.rendered = ""
        self.checksum_val = 0
        self.vars = Dict[String, String]()

    def class_name(self) -> String:
        return "Template::Parse"

    def prepare(mut self, mut helper: Helper) raises:
        self.vars = Dict[String, String]()
        TemplateRegex._prepare_template(self.count, self.vars)
        self.text = TemplateRegex._build_text(self.count)

    def run(mut self, iteration_id: Int, mut helper: Helper) raises:
        var text_bytes = self.text.as_bytes()
        var text_len = len(text_bytes)

        var rendered = String(capacity_bytes=text_len)

        var i = 0
        var chunk_start = 0

        while i < text_len:
            if (
                i + 1 < text_len
                and text_bytes[i] == 123
                and text_bytes[i + 1] == 123
            ):
                if chunk_start < i:
                    rendered._iadd(text_bytes[chunk_start:i])

                var key_start = i + 2
                var j = key_start
                while j + 1 < text_len:
                    if text_bytes[j] == 125 and text_bytes[j + 1] == 125:
                        break
                    j += 1

                if j + 1 < text_len:
                    var key = String(
                        StringSpan(
                            unsafe_from_utf8=text_bytes[key_start:j]
                        ).strip()
                    )

                    if key in self.vars:
                        rendered._iadd(self.vars[key].as_bytes())

                    i = j + 2
                    chunk_start = i
                    continue

            i += 1

        if chunk_start < text_len:
            rendered._iadd(text_bytes[chunk_start:text_len])

        self.checksum_val += UInt32(rendered.byte_length())
        self.rendered = rendered^

    def checksum(self) -> UInt32:
        return (
            self.checksum_val + Helper.checksum_string(self.rendered)
        ) & 0xFFFFFFFF
