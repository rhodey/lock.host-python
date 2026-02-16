# Lock.host-python
Lock.host python example, see: [Lock.host](https://github.com/rhodey/lock.host)

This demonstration uses OpenAI to control a Solana wallet:
+ Unmodified OpenAI lib
+ Unmodified Solana lib
+ Hit /api/ask?message=your best joke&addr=abc123
+ OAI is asked "You are to decide if a joke is funny or not"
+ If so 0.001 SOL is sent to addr

## Build app
This is how PCR hashes are checked:
```
just serve-alpine
just build-app
...
{
  "Measurements": {
    "HashAlgorithm": "Sha384 { ... }",
    "PCR0": "f188729433e24aec9bbb3028f1763901aa8d5072dfbdf02133f63b1c880b10c73eed1004d4a2bd6fec9762827e3185d3",
    "PCR1": "4b4d5b3661b3efc12920900c80e126e4ce783c522de6c02a2a5bf7af3a2b9327b86776f188e4be1c1c404a129dbda493",
    "PCR2": "e118cd123343a76d52fc02319b82520da819d9b12c7d74593988ff244df646b43d3b73562a30365ad1c68340b386658d"
  }
}
```

See that [run.yml](.github/workflows/run.yml) is testing that PCRs in this readme match the build

## Test
+ In test a container emulates a TEE
+ Two fifos /tmp/read and /tmp/write emulate a vsock
```
just serve-alpine
just build-test-app make-test-fifos
cp example.env .env
docker compose up -d
just ask-funds
...
addr = A7xYaa6PGwUFGYY5FYfMrZe6HJp5pSY7dBthdnPNbFE
sol = 0.025
json = {
  "signature": "5s4EUD6R8q9YobVSxC2ntnTdyKaZT1vduPdafKJCbwNnD1cGk6cDJ4Ha4T3gjqMWGLBGUPaSadCPyCYfxEev846t",
  "from": "DDWiwmkP5SiRExFmKSBWgfLNvDcq3B5eGXRvmvE6egGm",
  "to": "A7xYaa6PGwUFGYY5FYfMrZe6HJp5pSY7dBthdnPNbFE"
}
sol = 0.026
(look inside python/ask-funds.py)
```

## Atsocat
The Lock.host runtime includes a utility named atsocat similar to [socat](https://linux.die.net/man/1/socat)

Atsocat listens on one local port and forwards to one remote port (see [docker-compose.yml](docker-compose.yml))

Atsocat validates attestation documents and encrypts the session transparently

ask-funds.py is using atsocat because I have yet to create an `HTTPAdapter` for the `requests` library

## Prod
+ In prod all I/O passes through /dev/vsock
```
just serve-alpine
just build-app
just run-app
cp example.env .env
just run-host
```

## Apks
Modify apk/Dockerfile.fetch to include all apks then run:
```
just proxy-alpine
just fetch-alpine
```

## License
MIT

hello@lock.host
