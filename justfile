sudo := "$(docker info > /dev/null 2>&1 || echo 'sudo')"
certs := "$(cat cert.key > /dev/null 2>&1 && echo '-v ./cert.key:/runtime/cert.key -v ./cert.crt:/runtime/cert.crt')"

#########################
## Reproducible builds ##
#########################

serve-alpine:
    python3 -m http.server -d apk/ 8082

build-app:
    {{sudo}} docker buildx build --platform="linux/amd64" -f Dockerfile.nitro -t build-app .
    {{sudo}} docker rm -f build-app > /dev/null  2>&1 || true
    {{sudo}} docker run --platform="linux/amd64" --name build-app -v /var/run/docker.sock:/var/run/docker.sock build-app
    mkdir -p dist
    {{sudo}} docker cp build-app:/workspace/app.eif ./dist/ || true
    {{sudo}} docker cp build-app:/workspace/app.pcr ./dist/ || true
    {{sudo}} docker rm -f build-app > /dev/null  2>&1 || true

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
    sudo multipass exec myvm -- sh /tmp/docker.sh
    sudo multipass exec myvm -- bash -c "cp -r ~/base ~/basee"
    sudo multipass exec myvm -- bash -c "cp -r ~/app ~/appp"
    sudo multipass exec myvm -- bash -c "cd ~/basee && just serve-alpine" &
    sudo multipass exec myvm -- bash -c "cd ~/basee && just build-runtime"
    sudo multipass exec myvm -- bash -c "cd ~/appp && just serve-alpine" &
    sudo multipass exec myvm -- bash -c "cd ~/appp && just build-app"
    mkdir -p dist
    sudo multipass exec myvm -- sudo cp /home/ubuntu/appp/dist/app.eif /home/ubuntu/app/dist/
    sudo multipass exec myvm -- sudo cp /home/ubuntu/appp/dist/app.pcr /home/ubuntu/app/dist/
    sudo multipass exec myvm -- sudo chmod 666 /home/ubuntu/app/dist/app.eif
    sudo multipass exec myvm -- sudo chmod 666 /home/ubuntu/app/dist/app.pcr
    sudo multipass delete --purge myvm


#############
## Testing ##
#############

build-test-app:
    {{sudo}} docker buildx build --platform="linux/amd64" --build-arg PROD=false -f Dockerfile.app -t test-app .

make-test-net:
    {{sudo}} docker network create lockhost-net > /dev/null 2>&1 || true

make-test-fifos:
    mkfifo /tmp/read > /dev/null 2>&1 || true
    mkfifo /tmp/write > /dev/null 2>&1 || true

run-test-host:
    just make-test-net
    just make-test-fifos
    {{sudo}} docker run --rm -it --platform="linux/amd64" --name lockhost-host -v /tmp/read:/tmp/read -v /tmp/write:/tmp/write --network lockhost-net -p 8888:8888 --env-file .env lockhost-host 8888

run-test-app:
    just make-test-fifos
    {{sudo}} docker run --rm -it --cap-add NET_ADMIN --platform="linux/amd64" -v /tmp/read:/tmp/write -v /tmp/write:/tmp/read {{certs}} --env-file .env test-app

add-funds:
    {{sudo}} docker run --rm --platform="linux/amd64" --entrypoint /app/add-funds.sh --env-file .env test-app

atsocat listen port:
    {{sudo}} docker run --rm -it --platform="linux/amd64" --name atsocat --entrypoint /runtime/atsocat.sh --network lockhost-net -p {{listen}}:{{listen}} lockhost-runtime {{listen}} lockhost-host {{port}}

ask-funds listen:
    {{sudo}} docker run --rm --platform="linux/amd64" --entrypoint /app/ask-funds.sh --network lockhost-net --env-file .env test-app http://atsocat:{{listen}}

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
    just make-test-net
    sudo docker run --rm -it --platform="linux/amd64" --privileged --name lockhost-host -v /dev/vsock:/dev/vsock --network lockhost-net -p 8888:8888 --env-file .env -e PROD=true lockhost-host 8888

run-app:
    sudo nitro-cli run-enclave --cpu-count 2 --memory 4096 --enclave-cid 16 --eif-path dist/app.eif

run-app-debug:
    sudo nitro-cli run-enclave --cpu-count 2 --memory 4096 --enclave-cid 16 --eif-path dist/app.eif --debug-mode

nitro-logs enclave-id:
    sudo nitro-cli console --enclave-id {{enclave-id}}

nitro-rm enclave-id:
    sudo nitro-cli terminate-enclave --enclave-id {{enclave-id}}
