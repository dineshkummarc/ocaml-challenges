all:
	make -C src all
	make -C src pack
	ocsigenserver -c ocsigen.xml

clean:
	make -C src clean