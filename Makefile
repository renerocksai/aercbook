.PHONY: all, releases

all:
	zig build

releases:
	./release-all.sh
