PREFIX=/usr/local

PROG=sha

CFLAGS=-O
INSTALL=install

all: sha

sha: sha.c
	$(CC) $(CFLAGS) -o sha sha.c

sha-test: sha.c
	$(CC) $(CFLAGS) -DMEMTEST -o sha-test sha.c

check: sha-test
	./sha-test

install:
	$(INSTALL) -c -m 555 -s sha $(PREFIX)/bin
	$(INSTALL) -c -m 444 sha.1 $(PREFIX)/man/man1
	$(INSTALL) -c -m 444 sha_file.3 $(PREFIX)/man/man3

clean:
	rm -f sha sha-test
