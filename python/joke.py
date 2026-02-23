import os
import sys
import json
import base64
import asyncio
import requests
from solders.keypair import Keypair
from solders.signature import Signature
from solana.rpc.async_api import AsyncClient

# hit the api and ask oai for funds
async def main():
    # receiver
    sol_key = "i2kjqCXL4w8EWDBVRQDkxjEiqQ/QzTXl5BtHfc20mCgCVhgmb047mk0MElKivPt1xykE8XjEn7UVyUqS+yS/yQ=="
    sol_key = base64.b64decode(sol_key)
    sol_key = Keypair.from_bytes(sol_key)
    print(f"addr = {sol_key.pubkey()}")

    solana_env = os.environ["solana_environment"]
    sol_client = AsyncClient(solana_env)
    await sol_client.is_connected()

    # balance before ask
    balance = await sol_client.get_balance(sol_key.pubkey())
    balance = balance.value / 1_000_000_000
    print(f"sol = {balance}")

    # params
    joke = " ".join(sys.argv[2:])
    message = joke
    addr = str(sol_key.pubkey())
    params = {"message": message, "addr": addr}

    # send request
    api = sys.argv[1]
    api = f"{api}/api/joke"
    data = requests.get(api, params=params)
    data = data.json()
    pretty = json.dumps(data, indent=2)
    print(f"json = {pretty}")

    # no signature = no reward
    if "signature" not in data:
        return

    # balance after ask
    balance = await sol_client.get_balance(sol_key.pubkey())
    balance = balance.value / 1_000_000_000
    print(f"sol = {balance}")
    await sol_client.close()


if __name__ == "__main__":
    asyncio.run(main())
