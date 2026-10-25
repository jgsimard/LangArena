from std.python import Python, PythonObject
from helper import Helper
from benchmark import Benchmark, Config


struct LogParser(Benchmark):
    var lines_count: Int
    var log: String
    var _checksum: UInt32
    var compiled_patterns: PythonObject

    def __init__(out self, config: Config) raises:
        self.lines_count = config.get_i64("Etc::LogParser", "lines_count")
        self.log = ""
        self._checksum = 0
        self.compiled_patterns = PythonObject(None)

    def class_name(self) -> String:
        return "Etc::LogParser"

    def prepare(mut self, mut helper: Helper) raises:
        self.log = self._generate_log()

        var re = Python.import_module("re")
        var patterns = Python.list()
        patterns.append(
            Python.tuple("errors", re.compile(r" [5][0-9]{2} | [4][0-9]{2} "))
        )
        patterns.append(
            Python.tuple(
                "bots",
                re.compile(
                    r"bot|crawler|scanner|spider|indexing|crawl|robot|spider",
                    re.IGNORECASE,
                ),
            )
        )
        patterns.append(
            Python.tuple(
                "suspicious",
                re.compile(r"etc/passwd|wp-admin|\.\./", re.IGNORECASE),
            )
        )
        patterns.append(Python.tuple("ips", re.compile(r"\d+\.\d+\.\d+\.35")))
        patterns.append(Python.tuple("api_calls", re.compile(r'/api/[^ " ]+')))
        patterns.append(
            Python.tuple("post_requests", re.compile(r"POST [^ ]* HTTP"))
        )
        patterns.append(
            Python.tuple(
                "auth_attempts", re.compile(r"/login|/signin", re.IGNORECASE)
            )
        )
        patterns.append(
            Python.tuple("methods", re.compile(r"get|post|put", re.IGNORECASE))
        )
        patterns.append(
            Python.tuple(
                "emails",
                re.compile(r"[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}"),
            )
        )
        patterns.append(
            Python.tuple("passwords", re.compile(r'password=[^&\s"]+'))
        )
        patterns.append(
            Python.tuple(
                "tokens", re.compile(r'token=[^&\s"]+|api[_-]?key=[^&\s"]+')
            )
        )
        patterns.append(
            Python.tuple("sessions", re.compile(r'session[_-]?id=[^&\s"]+'))
        )
        patterns.append(
            Python.tuple(
                "peak_hours",
                re.compile(r"\[\d+/\w+/\d+:1[3-7]:\d+:\d+ [+\-]\d+\]"),
            )
        )

        self.compiled_patterns = patterns

    def run(mut self, iteration_id: Int, mut helper: Helper) raises:
        var patterns = self.compiled_patterns
        for i in range(Int(py=patterns.__len__())):
            var pair = patterns[i]
            var name = pair[0]
            var compiled = pair[1]

            var count = 0
            var iter = compiled.finditer(self.log)
            for _ in iter:
                count += 1
            self._checksum += UInt32(count)

    def checksum(self) -> UInt32:
        return self._checksum

    def _generate_log(self) -> String:
        var ips = List[String]()
        for i in range(1, 256):
            ips.append(String("192.168.1.", i))

        var methods = List[String]()
        methods.append("GET")
        methods.append("POST")
        methods.append("PUT")
        methods.append("DELETE")

        var paths = List[String]()
        paths.append("/index.html")
        paths.append("/api/users")
        paths.append("/admin")
        paths.append("/images/logo.png")
        paths.append("/etc/passwd")
        paths.append("/wp-admin/setup.php")

        var statuses = List[Int]()
        statuses.append(200)
        statuses.append(201)
        statuses.append(301)
        statuses.append(302)
        statuses.append(400)
        statuses.append(401)
        statuses.append(403)
        statuses.append(404)
        statuses.append(500)
        statuses.append(502)
        statuses.append(503)

        var agents = List[String]()
        agents.append("Mozilla/5.0")
        agents.append("Googlebot/2.1")
        agents.append("curl/7.68.0")
        agents.append("scanner/2.0")

        var users = List[String]()
        users.append("john")
        users.append("jane")
        users.append("alex")
        users.append("sarah")
        users.append("mike")
        users.append("anna")
        users.append("david")
        users.append("elena")

        var domains = List[String]()
        domains.append("example.com")
        domains.append("gmail.com")
        domains.append("yahoo.com")
        domains.append("hotmail.com")
        domains.append("company.org")
        domains.append("mail.ru")

        var log = ""
        for i in range(self.lines_count):
            log += ips[i % len(ips)]
            log += " - - ["
            log += String(i % 31)
            log += "/Oct/2023:"
            log += String(i % 60)
            log += ':55:36 +0000] "'
            log += methods[i % len(methods)]
            log += " "

            if i % 3 == 0:
                log += "/login?email="
                log += users[i % len(users)]
                log += String(i % 100)
                log += "@"
                log += domains[i % len(domains)]
                log += "&password=secret"
                log += String(i % 10000)
            elif i % 5 == 0:
                log += "/api/data?token="
                var token = "abcdef123456"
                for _ in range((i % 3) + 1):
                    log += token
            elif i % 7 == 0:
                log += "/user/profile?session_id=sess_"
                log += Self._to_hex(i * 12345)
            else:
                log += paths[i % len(paths)]

            log += ' HTTP/1.1" '
            log += String(statuses[i % len(statuses)])
            log += ' 2326 "http://'
            log += domains[i % len(domains)]
            log += '" "'
            log += agents[i % len(agents)]
            log += '"\n'

        return log

    @staticmethod
    def _to_hex(value: Int) -> String:
        if value == 0:
            return "0"

        var hex_chars = "0123456789abcdef"
        var result = ""
        var v = value

        while v > 0:
            var digit = v & 15
            result = String(hex_chars[byte=digit]) + result
            v >>= 4

        return result
