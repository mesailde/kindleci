#!/bin/bash
mkdir -p sslkeys
cd sslkeys || exit $?
openssl genrsa -des3 -out server.enc.key -passout pass:qwerty123 1024 || exit $?
openssl rsa -in server.enc.key -out server.key -passin pass:qwerty123 || exit $?
openssl req -new -key server.key -out server.csr -subj '/' || exit $?
openssl x509 -req -days 3650 -in server.csr -signkey server.key -out server.crt || exit $?
