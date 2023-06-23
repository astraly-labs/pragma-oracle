.PHONY: build test coverage
cairo_files = $(shell find ./src ./tests -type f -name "*.cairo")

build: check
	$(MAKE) clean
	cd pragma && protostar build

build-mac: check
	$(MAKE) clean
	cd pragma && protostar build

build-devnet:
	docker build . --tag astraly-labs/pragma -f ./docker/devnet/Dockerfile

check:
	poetry lock --check

setup:
	poetry install
	curl --proto '=https' --tlsv1.2 -sSf https://docs.swmansion.com/scarb/install.sh | sh
	curl -L https://raw.githubusercontent.com/software-mansion/protostar/master/install.sh | bash

test: 
	cd pragma && protostar test

deploy: build
	poetry run python ./scripts/deploy_pragma.py

format:
	cd pragma && scarb fmt
	poetry run black scripts/.
	poetry run isort scripts/.
	poetry run autoflake . -r

format-check:
	cd pragma && scarb fmt --check
	poetry run autoflake . -r -cd

clean:
	rm -rf build
	mkdir build

format-mac:
	cd pragma && scarb fmt
