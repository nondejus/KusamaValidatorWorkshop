#!/usr/bin/env bash

# Set input variables: Node Name, Telemetry URL, and DB URL
while getopts ":d:t:n:" opt; do
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
Description=Polkadot Validator

[Service]
ExecStart=/usr/bin/docker run --name kusama-validator -p 30333:30333 -p 9933:9933 -v /home/$USER/.local/share/polkadot:/polkadot/.local/share/polkadot parity/polkadot:latest --validator $NAME $TELEMETRY --pruning=archive --wasm-execution Compiled
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target" > kusama-validator.service
sudo mv kusama-validator.service /etc/systemd/system/
sudo systemctl enable kusama-validator.service
sleep 5s
sudo systemctl start kusama-validator.service


# Get the output of Rotate Keys
sleep 60s
sudo docker exec -i kusama-validator curl -H "Content-Type: application/json" -d '{"id":1, "jsonrpc":"2.0", "method": "author_rotateKeys", "params":[]}' http://localhost:9933 | sed 's/{.*result":"*\([0-9a-zA-Z]*\)"*,*.*}/\1/' > session_key