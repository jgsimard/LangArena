middle:
	mkdir -p target
	goose -O2 --standalone -o target/middle.c src/main.goose
	cc -O1 -w target/middle.c -o target/middle -lm -pthread

prod:
	mkdir -p target
	goose -O2 --standalone -o target/prod.c src/main.goose
	cc -O2 -w target/prod.c -o target/benchmark -lm -pthread

fast:
	mkdir -p target
	goose -O2 --standalone -o target/fast.c src/main.goose
	cc -O3 -w target/fast.c -o target/fast -lm -pthread

test:
	mkdir -p target
	goose --standalone -o target/test.c src/main.goose
	cc -w target/test.c -o target/test -lm -pthread

.PHONY: prod test fast middle
