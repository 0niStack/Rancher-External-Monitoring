.PHONY: server-auth server-up cluster-secret cluster-install verify
server-auth:
	cd 01-server && ./gen-auth.sh
server-up: server-auth
	cd 01-server && docker compose up -d
cluster-secret:
	@echo "usage: ./02-cluster/create-secret.sh <user> <password>"
cluster-install:
	./02-cluster/install.sh
verify:
	./03-verify/verify.sh
