# Teku Private Network Compose Stack

Start a Ethereum 2 private network using Java based ethereum client Besu and ethereum 2 client Teku. This repository
aims to provide a good starting point to setup a Eth2 private network.


#Pre-requisite
- docker
- docker-compose


# Start stack

Start the the stack with command and watch the logs for teku container to observe the validator key registration.

`docker-compose up -d`

Stack starts Besu and Teku clients. As part of the Teku client startup entrypoint.sh script, it generates keys and
register validators by depositing 32Eth to the smart contract configured in genesis block.
Once the registration completes, teku client starts with generated validators. 

# Stop stack

Stop the stack with command `docker-compose down`

# TODO:
- Add monitoring
