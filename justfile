sudo := "$(docker info > /dev/null 2>&1 || echo 'sudo')"
certs := "$(cat cert.key > /dev/null 2>&1 && echo '-v ./cert.key:/runtime/cert.key -v ./cert.crt:/runtime/cert.crt')"

#########################
## Reproducible builds ##
#########################

serve-alpine:
    python3 -m http.server -d apk/ 8082

build-app:
    {{sudo}} docker buildx build --platform="linux/amd64" -f Dockerfile.nitro -t lockhost-python-build-app .
    {{sudo}} docker rm -f lockhost-python-build-app > /dev/null  2>&1 || true
    {{sudo}} docker run --platform="linux/amd64" --name lockhost-python-build-app -v /var/run/docker.sock:/var/run/docker.sock lockhost-python-build-app
    mkdir -p dist
    {{sudo}} docker cp lockhost-python-build-app:/workspace/app.eif ./dist/ || true
    {{sudo}} docker cp lockhost-python-build-app:/workspace/app.pcr ./dist/ || true
    {{sudo}} docker rm -f lockhost-python-build-app > /dev/null  2>&1 || true

build-app-vm:
    sudo multipass delete --purge myvm > /dev/null  2>&1 || true
    sudo snap install multipass
    sudo snap restart multipass.multipassd
    sleep 5
    sudo multipass find --force-update
    sudo multipass launch 24.04 --name myvm --cpus 2 --memory 4G --disk 32G
    sudo multipass stop myvm
    sudo multipass mount -t native ../lock.host myvm:/home/ubuntu/base
    sudo multipass mount -t native ./ myvm:/home/ubuntu/app
    sudo multipass start myvm
    sudo multipass exec myvm -- sudo apt install -y just
    sudo multipass exec myvm -- bash -c "curl -fsSL https://get.docker.com -o /tmp/docker.sh"
    sudo multipass exec myvm -- VERSION=28.3.3 sh /tmp/docker.sh
    sudo multipass exec myvm -- bash -c "cp -r ~/base ~/basee"
    sudo multipass exec myvm -- bash -c "cp -r ~/app ~/appp"
    sudo multipass exec myvm -- bash -c "cd ~/basee && just serve-alpine" &
    sudo multipass exec myvm -- bash -c "cd ~/basee && just build-runtime"
    sudo multipass exec myvm -- bash -c "cd ~/appp && just serve-alpine" &
    sudo multipass exec myvm -- bash -c "cd ~/appp && just build-app"
    mkdir -p dist
    sudo multipass exec myvm -- sudo cp /home/ubuntu/appp/dist/app.pcr /home/ubuntu/app/dist/
    sudo multipass exec myvm -- sudo chmod 666 /home/ubuntu/app/dist/app.pcr
    sudo multipass delete --purge myvm


#############
## Testing ##
#############

make-test-fifos:
    mkfifo /tmp/read > /dev/null 2>&1 || true
    mkfifo /tmp/write > /dev/null 2>&1 || true

make-test-net:
    {{sudo}} docker network create locknet --driver bridge --subnet 172.77.0.0/16 --gateway 172.77.0.1 > /dev/null 2>&1 || true

build-test-app:
    just make-test-fifos
    just make-test-net
    {{sudo}} docker buildx build --platform="linux/amd64" --build-arg PROD=false -f Dockerfile.app -t lockhost-python-test-app .

add-funds:
    {{sudo}} docker run --rm --entrypoint /app/add-funds.sh --env-file .env lockhost-python-test-app

ask-funds:
    {{sudo}} docker run --rm --entrypoint /app/ask-funds.sh --network locknet --env-file .env lockhost-python-test-app http://atsocat:8889

mkcert:
    echo "authorityKeyIdentifier=keyid,issuer" > domains.ext
    echo "basicConstraints=CA:FALSE" >> domains.ext
    echo "keyUsage = digitalSignature, nonRepudiation, keyEncipherment, dataEncipherment" >> domains.ext
    echo "subjectAltName = @alt_names" >> domains.ext
    echo "[alt_names]" >> domains.ext
    echo "DNS.1 = localhost" >> domains.ext
    openssl req -x509 -nodes -new -sha256 -days 1024 -newkey rsa:2048 -keyout ca.key -out ca.pem -subj "/C=US/CN=Lock-Host-CA"
    openssl x509 -outform pem -in ca.pem -out ca.crt
    openssl req -new -nodes -newkey rsa:2048 -keyout cert.key -out cert.csr -subj "/C=US/ST=YourState/L=YourCity/O=Example-Certificates/CN=localhost"
    openssl x509 -req -sha256 -days 1024 -in cert.csr -CA ca.pem -CAkey ca.key -CAcreateserial -extfile domains.ext -out cert.crt
    rm ca.key ca.pem ca.srl cert.csr domains.ext


#########################
## Allow update alpine ##
#########################

proxy-alpine:
    cd ../lock.host && just build-proxy-alpine
    {{sudo}} docker run --rm -it -v ./apk:/root/apk -p 8080:8080 lockhost-proxy-alpine

fetch-alpine:
    {{sudo}} docker buildx build --platform="linux/amd64" -f apk/Dockerfile.fetch -t lockhost-fetch-alpine .


##########
## Prod ##
##########

run-host:
    sudo docker run --rm -it --privileged --name lockhost-host -v /dev/vsock:/dev/vsock -p 8888:8888 --env-file .env -e PROD=true lockhost-host 8888

run-app:
    sudo nitro-cli run-enclave --cpu-count 2 --memory 4096 --enclave-cid 16 --eif-path dist/app.eif

run-app-debug:
    sudo nitro-cli run-enclave --cpu-count 2 --memory 4096 --enclave-cid 16 --eif-path dist/app.eif --debug-mode

atsocat listen target:
    {{sudo}} docker run --rm -it --entrypoint /runtime/atsocat.sh -p {{listen}}:{{listen}} lockhost-host {{listen}} {{target}}

nitro:
    sudo nitro-cli describe-enclaves

eid := "$(just nitro | jq -r '.[0].EnclaveID')"

nitro-logs:
    sudo nitro-cli console --enclave-id {{eid}}

nitro-rm:
    sudo nitro-cli terminate-enclave --enclave-id {{eid}}
