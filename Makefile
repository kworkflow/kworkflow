PREFIX = ${DESTDIR}/usr
STDDIR = ${PREFIX}/share/kw
MANDIR = ${PREFIX}/share/man
ACDIR = ${PREFIX}/share/bash-completion/completions

all:
	@echo "kworkflow is a shell script program. Try \"make install\""

bash-autocomplete:
	@install -v -d ${ACDIR}
	@install -v -m 0755 -T src/bash_autocomplete.sh ${ACDIR}/kw

install: bash-autocomplete
	@install -v -d ${MANDIR}/man1
	rst2man < documentation/man/kw.rst > ${MANDIR}/man1/kw.1
	@install -v -d ${STDDIR}/src
	@install -v -d ${STDDIR}/sounds
	@install -v -d ${STDDIR}/etc
	@install -v -d ${STDDIR}/deploy_rules
	@install -v -m 0644 src/* ${STDDIR}/src
	@chmod 755 ${STDDIR}/src/kw.fish
	@rm -v ${STDDIR}/src/bash_autocomplete.sh
	@install -v -m 0644 sounds/* ${STDDIR}/sounds
	@install -v -m 0644 etc/* ${STDDIR}/etc
	@cp -vr deploy_rules ${STDDIR}/deploy_rules
	@install -v kw ${STDDIR}
	@ln -s ${STDDIR}/kw ${PREFIX}/bin/kw

remove-bash-autocomplete:
	@rm -vrf \
		${ACDIR}/kw

uninstall: remove-bash-autocomplete
	@rm -vrf \
		${STDDIR} \
		${MANDIR}/man1/kw.1 \
		${PREFIX}/bin/kw
clean:
	@rm -vrf \
		build/

.PHONY: build-man install uninstall
