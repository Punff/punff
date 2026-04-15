BIN := punff-camera-manager

.PHONY: build run deps clean

deps:
	go mod tidy

build: deps
	go build -o $(BIN) .

run: build
	./$(BIN)

clean:
	rm -f $(BIN)
