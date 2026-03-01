# Lock.host-python (test)
Lock.host python example, see: [Lock.host](https://github.com/rhodey/lock.host)

This demonstration uses OpenAI to control a Solana wallet:
+ Unmodified OpenAI lib
+ Unmodified Solana lib
+ Hit /api/joke?message=your best joke&addr=abc123
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
    "PCR0": "25411de098dd21a83a252fcb64bb2a28d7a5fe26df1a820f59abb73222a91f6cc9605d376ca37838d297c4e0e5e187a7",
    "PCR1": "4b4d5b3661b3efc12920900c80e126e4ce783c522de6c02a2a5bf7af3a2b9327b86776f188e4be1c1c404a129dbda493",
    "PCR2": "ee5d87b4c5f0f5ab6b3a0abb79bfb161f52e455f6ab66e7f3c38e98e2cba710e63ae9bfd340a106535afaf9729886b4e"
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
just joke 'why did the worker quit his job at the recycling factory? because it was soda pressing.'
...
addr = A7xYaa6PGwUFGYY5FYfMrZe6HJp5pSY7dBthdnPNbFE
sol = 0.025
json = {
  "signature": "5kxUx3B3ZooxPCiLNQWGbRzKUb5weV7PBFgyakzbsCuZStFiMamNwyyUHXPhZqteKoyKgRNFMVR6oAkKhh745xHX",
  "from": "AkHqQ324DvygPxuhyYs9BTVG8b1BXzTnpbCxqG8zousm",
  "to": "A7xYaa6PGwUFGYY5FYfMrZe6HJp5pSY7dBthdnPNbFE",
  "thoughts": "The joke is a clever play on words, combining the concept of being 'so depressing' with 'soda pressing' related to recycling. It's humorous and lighthearted."
}
sol = 0.026
(look inside python/joke.py)
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
