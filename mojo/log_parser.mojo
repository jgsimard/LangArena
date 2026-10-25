from moregex import Regex, count
from helper import Helper
from benchmark import Benchmark, Config


struct LogParser(Benchmark):
    comptime _PATTERNS = [
        Regex(r" [5][0-9]{2} | [4][0-9]{2} "),
        Regex(
            r"bot|crawler|scanner|spider|indexing|crawl|robot|spider",
            case_insensitive=True,
        ),
        Regex(r"etc/passwd|wp-admin|\.\./", case_insensitive=True),
        Regex(r"\d+\.\d+\.\d+\.35"),
        Regex(r'/api/[^ " ]+'),
        Regex(r"POST [^ ]* HTTP"),
        Regex(r"/login|/signin", case_insensitive=True),
        Regex(r"get|post|put", case_insensitive=True),
        Regex(r"[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}"),
        Regex(r'password=[^&\s"]+'),
        Regex(r'token=[^&\s"]+|api[_-]?key=[^&\s"]+'),
        Regex(r'session[_-]?id=[^&\s"]+'),
        Regex(r"\[\d+/\w+/\d+:1[3-7]:\d+:\d+ [+\-]\d+\]"),
    ]

    var lines_count: Int
    var log: String
    var _checksum: UInt32

    def __init__(out self, config: Config) raises:
        self.lines_count = config.get_i64("Etc::LogParser", "lines_count")
        self.log = ""
        self._checksum = 0

    def class_name(self) -> String:
        return "Etc::LogParser"

    def prepare(mut self, mut helper: Helper) raises:
        self.log = self._generate_log()

    def run(mut self, iteration_id: Int, mut helper: Helper) raises:
        comptime for pattern in Self._PATTERNS:
            self._checksum += UInt32(count[pattern](self.log))

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
