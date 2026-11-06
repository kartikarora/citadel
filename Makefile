PREFIX ?= /usr/local
BINDIR ?= $(PREFIX)/bin

.PHONY: build install test clean

build:
	swift build -c release --product citadel
	swift build -c release --product ctdl

install: build
	mkdir -p $(BINDIR)
	install .build/release/citadel $(BINDIR)/citadel
	install .build/release/ctdl $(BINDIR)/ctdl
	@echo "🏰 Citadel successfully installed to $(BINDIR)/citadel and $(BINDIR)/ctdl"

clean:
	rm -rf .build
