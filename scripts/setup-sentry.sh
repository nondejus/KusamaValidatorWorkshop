#!/usr/bin/env bash

# Set input variables: Node Name, Telemetry URL, Reserved Nodes, and DB URL
while getopts ":d:t:n:r:" opt; do
  case $opt in

    d)
      echo "DB URL set to: $OPTARG"
      DB=$OPTARG
      mkdir -p /home/$USER/.local/share/polkadot/chains/ksmcc3/db
      cd /home/$USER/.local/share/polkadot/chains/ksmcc3/
      echo "Downloading DB..."
      curl -o db.tar $DB
      echo "Injecting DB..."
      tar -xvf db.tar 
      echo "Removing db.tar..."
      rm db.tar
      ;;
    t)
      echo "Telemetry server set to: $OPTARG"
      TELEMETRY="--telemetry-url $OPTARG"
      ;;
    n)
      echo "Node name set to: $OPTARG"
      NAME="--name=$OPTARG"
      ;;
    r)
        echo "Reserved Nodes set to: $OPTARG"
        RESERVED="--reserved-nodes $OPTARG"
        ;;
    \?)
      echo "Invalid option: -$OPTARG" >&2
      exit 1
      ;;
    :)
      ;;
  esac
done


# Install Docker
echo "Installing Docker"

sudo apt-get update
curl -fsSL get.docker.com -o get-docker.sh
sh get-docker.sh


# Create polkadot directory and give it permissions
mkdir -p /home/$USER/.local/share/polkadot/
sudo chown -R 1000:1000 /home/$USER/.local/share/polkadot/


# Create systemd service and start service
echo "[Unit]
Description=Polkadot Sentry Node

[Service]
ExecStart=/usr/bin/docker run --name kusama-sentry -p 30333:30333 -p 9933:9933 -v /home/$USER/.local/share/polkadot:/polkadot/.local/share/polkadot parity/polkadot:latest --sentry $NAME $TELEMETRY --in-peers 100 --out-peers 100 --pruning=archive --wasm-execution Compiled
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target" > kusama-sentry.service
sudo mv kusama-sentry.service /etc/systemd/system/
sudo systemctl enable kusama-sentry.service
sleep 5s
sudo systemctl start kusama-sentry.service


# Get the output of Rotate Keys
sleep 60s
sudo docker exec -i kusama-sentry curl -H "Content-Type: application/json" -d '{"id":1, "jsonrpc":"2.0", "method": "system_networkState", "params":[]}' http://localhost:9933 | sed 's/{.*peerId":"*\([0-9a-zA-Z]*\)"*,*.*}/\1/' > peerId
cat peerId