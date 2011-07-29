MODULE = challenges
APP = challenges

include ../Makefile.config

SERVERFILES := types.eliom misc.eliom activity.eliom config.eliom uid.eliom services.eliom appl.eliom\
								nutshell.eliom solution.eliom challenge.eliom persistency.eliom cms.eliom\
								fallback.eliom oClosure_extra.eliom home.eliom backend.eliom\
								to_be_removed.eliom interpreter.eliom participate.eliom challenge_frontend.eliom

CLIENTFILES := types.eliom misc.eliom activity.eliom services.eliom nutshell.eliom solution.eliom challenge.eliom persistency.eliom cms.eliom fallback.eliom home.eliom backend.eliom challenge_client.eliom challenge_frontend.eliom participate.eliom

SERVERLIB := -package eliom.server,aws,yojson,wikicreole
CLIENTLIB := -package eliom.client,js_of_ocaml,js_of_ocaml.deriving

INCLUDES := 

EXTRADIRS = 

include ../Makefile.rules

$(STATICDIR)/$(APP).js: _build/client/${MODULE}.cmo
		${JS_OF_ELIOM}  -jsopt -pretty ${CLIENTLIB} -o ../$@ $^

$(STATICDIR)/$(APP)_req.js: $(STATICDIR)/$(APP).js
	${OCAML} str.cma $(OCLOSUREDIR)/requirements.ml ../$^

$(STATICDIR)/$(APP)_oclosure.js: $(STATICDIR)/$(APP).js
	${OCLOSURE_REQ} ../$^

pack: $(STATICDIR)/$(APP).js # $(STATICDIR)/$(APP)_oclosure.js 

install:
	$(OCAMLFIND) install frontend META _build/server/frontend.cmo _build/server/frontend.cmi
	install -d $(PREFIX)/var/www/cathedral

uninstall:
	$(OCAMLFIND) remove frontend
	$(OCAMLFIND) remove cathedral-common
