#!/bin/bash
set -xe
mkdir -p sslkeys log
cd sslkeys
openssl genrsa -des3 -out server.enc.key -passout pass:qwerty123 1024
openssl rsa -in server.enc.key -out server.key -passin pass:qwerty123
openssl req -new -key server.key -out server.csr -subj '/'
openssl x509 -req -days 3650 -in server.csr -signkey server.key -out server.crt
