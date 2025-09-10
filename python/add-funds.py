import os
import base64
import asyncio
from solders.keypair import Keypair
from solana.rpc.async_api import AsyncClient

# add funds to wallet for testing
async def main():
    # persistent keys arrive soon
    sol_key = "2oRZ/SaFEQRo+hyf4SrZS1W6yNVcovMwDPhGJ0nkGji1gNIodfEGlzzravS6oQbFngilk9fchPv8Cfl9Iqkkhg=="
    sol_key = base64.b64decode(sol_key)
    sol_key = Keypair.from_bytes(sol_key)
    print(f"addr = {sol_key.pubkey()}")

    solana_env = os.environ["solana_environment"]
    async with AsyncClient(solana_env) as sol_client:
        signature = await sol_client.request_airdrop(sol_key.pubkey(), 1_000_000_000)
        latest_blockhash = await sol_client.get_latest_blockhash()
        await sol_client.confirm_transaction(tx_sig=signature.value, last_valid_block_height=latest_blockhash.value.last_valid_block_height)
        balance = await sol_client.get_balance(sol_key.pubkey())
        balance = balance.value / 1_000_000_000
        print(f"sol = {balance}")


if __name__ == "__main__":
    asyncio.run(main())
