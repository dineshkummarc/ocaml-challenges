MODULE = challenges
APP = challenges

include ../Makefile.config

SERVERFILES := misc.eliom config.eliom uid.eliom types.eliom services.eliom appl.eliom\
	         nutshell.eliom solution.eliom challenge.eliom persistency.eliom fallback.eliom\
	         oClosure_extra.eliom home.eliom

CLIENTFILES := home.eliom challenges.eliom

SERVERLIB := -package eliom.server,calendar,aws
CLIENTLIB := -package eliom.client

INCLUDES := 

EXTRADIRS = 

include ../Makefile.rules

$(STATICDIR)/$(APP).js: _build/client/${MODULE}.cmo
		${JS_OF_ELIOM} -jsopt -pretty -verbose ${CLIENTLIB} -o ../$@ $^

$(STATICDIR)/$(APP)_req.js: $(STATICDIR)/$(APP).js
	${OCAML} str.cma $(OCLOSUREDIR)/requirements.ml ../$^

$(STATICDIR)/$(APP)_oclosure.js: $(STATICDIR)/$(APP).js
	${OCLOSURE_REQ} ../$^

pack: $(STATICDIR)/$(APP).js $(STATICDIR)/$(APP)_oclosure.js 

install:
	$(OCAMLFIND) install frontend META _build/server/frontend.cmo _build/server/frontend.cmi
	install -d $(PREFIX)/var/www/cathedral

uninstall:
	$(OCAMLFIND) remove frontend
	$(OCAMLFIND) remove cathedral-common
