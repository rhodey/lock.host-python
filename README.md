# Lock.host-python
Lock.host python3 example, see: [lock.host](https://github.com/rhodey/lock.host)

This demonstration uses OpenAI to control a Solana wallet:
+ Unmodified OpenAI lib
+ Unmodified Solana solana-py lib
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
    "PCR0": "ebd96daf5983f237d8be138b35f763b08967d8f16d04875f63b3a8622b283543fe702a264c7a08e62a62c5758cc585ce",
    "PCR1": "4b4d5b3661b3efc12920900c80e126e4ce783c522de6c02a2a5bf7af3a2b9327b86776f188e4be1c1c404a129dbda493",
    "PCR2": "220d7a6934ca98d60150ddaa94fc3d1446e92517d49afa00814419f4e20734acd6f9edc1d99643a46b7e3c3f88e9045f"
  }
}
```

See that [run.yml](.github/workflows/run.yml) step "PCR" is testing that PCRs in this readme match the build

## Prod
+ In prod all TEE I/O passes through /dev/vsock
+ Think of /dev/vsock as a file handle
+ How to run:
```
just serve-alpine
just build-app
cp example.env .env
just run-app
just run-host
```

## Test
+ In test a container emulates a TEE
+ Uses two fifos /tmp/read /tmp/write to emulate vsock
+ How to run:
```
just serve-alpine
just build-test-app
cp example.env .env
just run-test-app
just run-test-host
just add-funds
just atsocat 8889 8888
just ask-funds 8889
...
addr = A7xYaa6PGwUFGYY5FYfMrZe6HJp5pSY7dBthdnPNbFE
sol = 0
json = {
  "signature": "5s4EUD6R8q9YobVSxC2ntnTdyKaZT1vduPdafKJCbwNnD1cGk6cDJ4Ha4T3gjqMWGLBGUPaSadCPyCYfxEev846t",
  "from": "DDWiwmkP5SiRExFmKSBWgfLNvDcq3B5eGXRvmvE6egGm",
  "to": "A7xYaa6PGwUFGYY5FYfMrZe6HJp5pSY7dBthdnPNbFE"
}
sol = 0.001
```

## Atsocat
The Lock.host runtime includes a utility named atsocat similar to [socat](https://linux.die.net/man/1/socat)

Atsocat listens on one port (8889) and forwards to a second port (8888)

Atsocat validates attestation documents and encrypts the session transparently

A better example would pass an `HTTPAdapter` to the `requests` library so python would not need atsocat

## Web
The webapp [IPFS-boot-choo](https://github.com/rhodey/IPFS-boot-choo) demonstrates lock.host in a client-to-server environment

The webapp when hitting dev (not prod) requires an HTTPS certificate to be installed with the OS

This is because of a combination of Lock.host using HTTP2 and IPFS-boot using a service worker

+ just mkcert
+ chrome > settings > privacy & security
+ security > manage certificates > authorities
+ import > ca.crt

## Apks
Modify apk/Dockerfile.fetch to include all apks then run:
```
just proxy-alpine
just fetch-alpine
```

## License
MIT
