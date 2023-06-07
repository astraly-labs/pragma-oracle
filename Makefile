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

test: 
	cd pragma && protostar test

deploy: build
	poetry run python ./scripts/deploy_pragma.py

format:
	poetry run black scripts/.
	poetry run isort scripts/.
	poetry run autoflake . -r

format-check:
	poetry run autoflake . -r -cd

clean:
	rm -rf build
	mkdir build

format-mac:
	cairo-format src/**/*.cairo -i
