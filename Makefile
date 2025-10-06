
PREFIX := /usr/local
SYSCONFDIR := /etc/sway
USRCONFDIR := $(HOME)/.config/sway

.PHONY: install uninstall

install:
	@install -Dvm 755 sbmon.sh -t $(PREFIX)/bin/
	@if [[ $$UID == 0 ]]; then \
	  [[ -f "$(SYSCONFDIR)/sbmon.conf" ]] || \
	    install -Dvm 644 sbmon.conf -t $(SYSCONFDIR)/; \
	else \
	  [[ -f "$(USRCONFDIR)/sbmon.conf" ]] || \
	    install -Dvm 644 sbmon.conf -t $(USRCONFDIR)/; \
	fi;

uninstall:
	@rm -v $(PREFIX)/bin/sbmon.sh
	@if [[ $$UID == 0 ]]; then \
	  rm -fv $(SYSCONFDIR)/sbmon.conf; \
	else \
	  rm -fv $(USRCONFDIR)/sbmon.conf; \
	fi;

