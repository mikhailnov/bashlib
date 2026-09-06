# Makefile for bashlib
# ----------------------------------------------------------------------
# bashlib
# Copyright (C) 2002-2005 darren chamberlain <dlc@sevenroot.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; version 2.
#
# This program is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111-1307
# USA
# ----------------------------------------------------------------------
# There is nothing to configure or build: bashlib calls no external
# tools, so the checked-out file is the finished library.
PREFIX ?= /usr/local
DESTDIR ?=
VERSION = 4

all:
	@echo "nothing to build; try 'make check' or 'make install'"

install:
	mkdir -p $(DESTDIR)$(PREFIX)/bin
	install -m 755 bashlib $(DESTDIR)$(PREFIX)/bin

check:
	./run_tests.sh

dist:
	mkdir bashlib-$(VERSION)
	cp bashlib Makefile INSTALL COPYING run_tests.sh bashlib-$(VERSION)/
	cp -r examples bashlib-$(VERSION)/
	cd bashlib-$(VERSION); ln -s INSTALL README
	tar cf bashlib-$(VERSION).tar bashlib-$(VERSION)
	gzip --best bashlib-$(VERSION).tar
	rm -rf bashlib-$(VERSION)

clean:
	rm -f bashlib-$(VERSION).tar bashlib-$(VERSION).tar.gz
