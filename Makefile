NAME := zfs-stats-exporter
PREFIX := /usr/local
SBINDIR := $(PREFIX)/sbin
SYSCONFDIR := /etc
UNITDIR := $(SYSCONFDIR)/systemd/system

ROOT_DIR := $(shell dirname $(realpath $(firstword $(MAKEFILE_LIST))))

$(NAME).service: $(NAME).service.in
	cd $(ROOT_DIR) && \
	cat $(NAME).service.in | \
	sed "s|@NAME@|$(NAME)|" | \
	sed "s|@PREFIX@|$(PREFIX)|" | \
	sed "s|@UNITDIR@|$(UNITDIR)|" | \
	sed "s|@SBINDIR@|$(SBINDIR)|" | \
	sed "s|@SYSCONFDIR@|$(SYSCONFDIR)|" \
	> $(NAME).service

.PHONY: install uninstall clean dist rpm srpm vendor

install: $(NAME).service
	cd $(ROOT_DIR) && install -D -m 0755 $(NAME) -T $(DESTDIR)$(SBINDIR)/$(NAME)
	cd $(ROOT_DIR) && install -D -m 0644 $(NAME).service -T $(DESTDIR)$(UNITDIR)/$(NAME).service
	cd $(ROOT_DIR) && install -D -m 0644 $(NAME).default -T $(DESTDIR)$(SYSCONFDIR)/default/$(NAME)
	echo Now please systemctl --system daemon-reload >&2

uninstall:
	rm -f $(DESTDIR)$(SBINDIR)/$(NAME)
	rm -f $(DESTDIR)$(UNITDIR)/$(NAME).service

clean:
	cd $(ROOT_DIR) && find -name '*~' -print0 | xargs -0r rm -fv && rm -fr *.tar.gz *.rpm *.service

dist: clean
	@which rpmspec || { echo 'rpmspec is not available.  Please install the rpm-build package with the command `dnf install rpm-build` to continue, then rerun this step.' ; exit 1 ; }
	cd $(ROOT_DIR) || exit $$? ; excludefrom= ; test -f .gitignore && excludefrom=--exclude-from=.gitignore ; DIR=`rpmspec -q --queryformat '%{name}-%{version}\n' *spec | head -1` && FILENAME="$$DIR.tar.gz" && tar cvzf "$$FILENAME" --exclude="$$FILENAME" --exclude=.git --exclude=.gitignore $$excludefrom --transform="s|^|$$DIR/|" --show-transformed *

srpm: dist
	@which rpmbuild || { echo 'rpmbuild is not available.  Please install the rpm-build package with the command `dnf install rpm-build` to continue, then rerun this step.' ; exit 1 ; }
	cd $(ROOT_DIR) || exit $$? ; rpmbuild --define "_srcrpmdir ." -ts `rpmspec -q --queryformat '%{name}-%{version}.tar.gz\n' *spec | head -1`

rpm: dist
	@which rpmbuild || { echo 'rpmbuild is not available.  Please install the rpm-build package with the command `dnf install rpm-build` to continue, then rerun this step.' ; exit 1 ; }
	cd $(ROOT_DIR) || exit $$? ; rpmbuild --define "_srcrpmdir ." --define "_rpmdir builddir.rpm" -ta `rpmspec -q --queryformat '%{name}-%{version}.tar.gz\n' *spec | head -1`
	cd $(ROOT_DIR) ; mv -f builddir.rpm/*/* . && rm -rf builddir.rpm
