
# Go parameters
GOCMD=go
GOBUILD=$(GOCMD) build
GOCLEAN=$(GOCMD) clean
GOTEST=$(GOCMD) test
SET_SSL_CERT_BINARY_NAME=semp_set_ssl_cert
SET_SSL_CERT_BINARY_UNIX=$(SET_SSL_CERT_BINARY_NAME)_unix

all: test build build-linux
build: 
	$(GOBUILD) -o $(SET_SSL_CERT_BINARY_NAME).exe -v
test: 
	$(GOTEST) -v ./...
clean: 
	$(GOCLEAN)
	rm -f $(SET_SSL_CERT_BINARY_NAME)
	rm -f $(SET_SSL_CERT_BINARY_UNIX)
run:
	$(GOBUILD) -o $(SET_SSL_CERT_BINARY_NAME) -v ./...
	./$(SET_SSL_CERT_BINARY_NAME)

# Cross compilation
build-linux:
	CGO_ENABLED=0 GOOS=linux GOARCH=amd64 $(GOBUILD) -o $(SET_SSL_CERT_BINARY_UNIX) -v
