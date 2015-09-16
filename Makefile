
VER=latest

all: build push
build:
	docker build --no-cache=true -t datasets .
	docker tag -f datasets docker.sunet.se/datasets:$(VER)
update:
	docker build -t datasets .
	docker tag -f datasets docker.sunet.se/datasets:$(VER)
push:
	docker push docker.sunet.se/datasets:$(VER)
