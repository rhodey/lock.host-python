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
    "PCR0": "e6227931d1d846e84ba568a33fbab583d24ce6f016e465eb6735af6f65048fd583911979233d1f53784a7a28c612878f",
    "PCR1": "4b4d5b3661b3efc12920900c80e126e4ce783c522de6c02a2a5bf7af3a2b9327b86776f188e4be1c1c404a129dbda493",
    "PCR2": "8e2166ac3d0a5afcc2461eb4009b0dde9b600f9d7216c90c8c2ae2331912d82bb502ef1bbc5914f456ba8b7864b22562"
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
just ask-funds 'why did the worker quit his job at the recycling factory? because it was soda pressing.'
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
