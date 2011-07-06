all: client

server: pokey.coffee server.coffee config.coffee
	coffee -o build -cw $^

client: pokey.coffee client.coffee
	coffee -o www/js -cw $^

build:
	mkdir build

run: build
	node build/server.js

clean:
	rm -rf -- build www/{pokey,client}.js
