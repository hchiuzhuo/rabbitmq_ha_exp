#!/bin/bash

rabbitPubIps=(`jq -r '.modules[].outputs.public_ips.value[]' rabbit_terraform/terraform.tfstate | xargs`)
rabbitPvtIps=(`jq -r '.modules[].outputs.private_ips.value[]' rabbit_terraform/terraform.tfstate | xargs`)

for i in {1..3};
do

    script="
    if [ -e data ]; then
        sudo rm -rf data
    fi
    sudo docker rm rabbit -f
    "
    ssh -i .ssh/gitlab.pem -o StrictHostKeyChecking=no ubuntu@${rabbitPubIps[(($i-1))]} "echo -e '$script' > stop.sh; sh stop.sh"
done