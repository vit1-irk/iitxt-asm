CC=gcc
CFLAGS+=-ggdb
INSTALL=install
INSTALL_DATA=$(INSTALL) -m 644
prefix=/usr
bindir=$(prefix)/bin
libdir=$(prefix)/lib
# docdir=$(prefix)/share/doc/iitxt-asm

all:
	${CC} ${CFLAGS} view.s -o view
	${CC} ${CFLAGS} write.s -o write
	${CC} ${CFLAGS} -shared b64.c -o b64
	${CC} ${CFLAGS} b64 send.s -o send -lcurl

clean:
	${RM} view write send

install:
	mkdir -p ${DESTDIR}${bindir}
	# mkdir -p ${DESTDIR}${docdir}
	# mkdir -p ${DESTDIR}/etc/xdg/iitxt-asm
	$(INSTALL) view write send ${DESTDIR}${bindir}
	$(INSTALL) b64 ${DESTDIR}${libdir}
	# $(INSTALL_DATA) README.md ${DESTDIR}${docdir}
	# $(INSTALL_DATA) config.default.cfg ${DESTDIR}/etc/xdg/iitxt-asm/

uninstall:
	rm ${DESTDIR}${bindir}/view
	rm ${DESTDIR}${bindir}/write
	rm ${DESTDIR}${bindir}/send
	rm ${DESTDIR}${libdir}/b64
	# rm ${DESTDIR}${docdir}/README.md
	# rmdir ${DESTDIR}${docdir}
	# rm ${DESTDIR}/etc/xdg/iitxt-asm/config.default.cfg
	# rmdir ${DESTDIR}/etc/xdg/iitxt-asm
