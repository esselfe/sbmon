
PREFIX := /usr/local
SYSCONFDIR := /etc/sway
USRCONFDIR := $(HOME)/.config/sway

.PHONY: default install uninstall

default:
	@echo "Usage: make { install | uninstall }"

install:
	@install -Dvm 755 sbmon.sh -t $(PREFIX)/bin/ || \
	  install -Dvm 755 sbmon.sh -t $(HOME)/bin/;
	@if [[ $$UID == 0 ]]; then \
	  [[ -f "$(SYSCONFDIR)/sbmon.conf" ]] || \
	    install -Dvm 644 sbmon.conf -t $(SYSCONFDIR)/; \
	else \
	  [[ -f "$(USRCONFDIR)/sbmon.conf" ]] || \
	    install -Dvm 644 sbmon.conf -t $(USRCONFDIR)/; \
	fi;

uninstall:
	@if [[ $$UID == 0 ]]; then \
	  rm -fv $(PREFIX)/bin/sbmon.sh; \
	  rm -fv $(SYSCONFDIR)/sbmon.conf; \
	else \
	  rm -fv $(PREFIX)/bin/sbmon.sh || \
	    rm -fv $(HOME)/bin/sbmon.sh; \
	  rm -fv $(USRCONFDIR)/sbmon.conf; \
	fi;

