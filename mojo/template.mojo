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
        self.text = Self._build_text(self.count, self.vars)

    def run(mut self, iteration_id: Int, mut helper: Helper) raises:
        var result = String(capacity_bytes=self.text.byte_length())
        var text_len = self.text.byte_length()
        var text = self.text[byte=0:text_len]
        var last_pos = 0

        for found in finditer_span[Self._PATTERN](text):
            var match_start = found.start()
            var match_end = found.end()

            result += text[byte=last_pos:match_start]

            var stripped = String(found.group_span(text, 1).strip())

            if stripped in self.vars:
                result += self.vars[stripped]

            last_pos = match_end

        result += text[byte=last_pos:text_len]

        self.rendered = result^
        self.checksum_val += UInt32(self.rendered.byte_length())

    def checksum(self) -> UInt32:
        return (
            self.checksum_val + Helper.checksum_string(self.rendered)
        ) & 0xFFFFFFFF

    @staticmethod
    def _prepare_template(count: Int, mut vars: Dict[String, String]):
        var first_names = List[String]()
        first_names.append("John")
        first_names.append("Jane")
        first_names.append("Bob")
        first_names.append("Alice")
        first_names.append("Charlie")
        first_names.append("Diana")
        first_names.append("Sarah")
        first_names.append("Mike")

        var last_names = List[String]()
        last_names.append("Smith")
        last_names.append("Johnson")
        last_names.append("Brown")
        last_names.append("Taylor")
        last_names.append("Wilson")
        last_names.append("Davis")
        last_names.append("Miller")
        last_names.append("Jones")

        var cities = List[String]()
        cities.append("New York")
        cities.append("Los Angeles")
        cities.append("Chicago")
        cities.append("Houston")
        cities.append("Phoenix")
        cities.append("San Francisco")

        vars["TITLE"] = "Template title"

        for i in range(count):
            vars["FIRST_NAME" + String(i)] = first_names[i % len(first_names)]
            vars["LAST_NAME" + String(i)] = last_names[i % len(last_names)]
            vars["CITY" + String(i)] = cities[i % len(cities)]

    @staticmethod
    def _build_text(count: Int, vars: Dict[String, String]) -> String:
        var lorem = (
            "Lorem {ipsum} dolor {sit} amet, consectetur adipiscing elit. Sed"
            " do eiusmod tempor incididunt ut labore {et} dolore magna aliqua. "
        )

        var text = "<html><body>"
        text += "<h1>{{TITLE}}</h1>"
        text += "<p>"
        text += lorem
        text += "</p>"
        text += "<table>"

        for i in range(count):
            if i % 3 == 0:
                text += "<!-- {comment} -->"
            text += "<tr>"
            text += "<td>{{ FIRST_NAME" + String(i) + " }}</td>"
            text += "<td>{{LAST_NAME" + String(i) + "}}</td>"
            text += "<td>{{  CITY" + String(i) + "  }}</td>"
            text += "<td>{balance: " + String(i % 100) + "}</td>"
            text += "</tr>\n"

        text += "</table>"
        text += "</body></html>"
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
        self.text = TemplateRegex._build_text(self.count, self.vars)

    def run(mut self, iteration_id: Int, mut helper: Helper) raises:
        var text = self.text
        var text_len = text.byte_length()
        var text_bytes = text.as_bytes()

        var builder = String(capacity_bytes=text_len * 2)

        var i = 0
        var chunk_start = 0

        while i < text_len:
            if (
                i + 1 < text_len
                and text_bytes[i] == 123
                and text_bytes[i + 1] == 123
            ):
                if chunk_start < i:
                    builder._iadd(text_bytes[chunk_start:i])

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

                    var val = self.vars.get(key)
                    if val:
                        builder._iadd(val[].as_bytes())

                    i = j + 2
                    chunk_start = i
                    continue

            i += 1

        if chunk_start < text_len:
            builder._iadd(text_bytes[chunk_start:text_len])

        self.rendered = builder
        self.checksum_val += UInt32(self.rendered.byte_length())

    def checksum(self) -> UInt32:
        return (
            self.checksum_val + Helper.checksum_string(self.rendered)
        ) & 0xFFFFFFFF
