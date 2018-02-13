#!/bin/bash

#cd rabbit_terraform
#terraform init
#terraform apply
#cd ..

sleep 1m


rabbitPubIps=(`jq -r '.modules[].outputs.public_ips.value[]' rabbit_terraform/terraform.tfstate | xargs`)
rabbitPvtIps=(`jq -r '.modules[].outputs.private_ips.value[]' rabbit_terraform/terraform.tfstate | xargs`)
#for ((i=0;i<3;i=i+1))
#do
#    echo "rabbitPubIps[$i]=${rabbitPubIps[$i]}"
#    echo "rabbitPvtIps[$i]=${rabbitPvtIps[$i]}"
#done

for i in {1..3};
do

    script="
    mkdir data
    echo "12345" > data/.erlang.cookie
    chmod 400 data/.erlang.cookie
    sudo docker run -d -h node-${i}.rabbit \\
    --add-host=node-1.rabbit:${rabbitPvtIps[0]}\\
    --add-host=node-2.rabbit:${rabbitPvtIps[1]} \\
    --add-host=node-3.rabbit:${rabbitPvtIps[2]} \\
    --name rabbit \\
    -p \"4369:4369\" \\
    -p \"5672:5672\" \\
    -p \"15672:15672\" \\
    -p \"25672:25672\" \\
    -p \"35197:35197\" \\
    -e \"RABBITMQ_USE_LONGNAME=true\" \\
    -e \"RABBITMQ_LOGS=/var/log/rabbitmq/rabbit.log\" \\
    -v /home/ubuntu/data:/var/lib/rabbitmq \\
    -v /home/ubuntu/data/logs:/var/log/rabbitmq \\
    rabbitmq:3.6.6-management"
#    echo "rabbitIps[$(($i-1))]=${rabbitIps[(($i-1))]}"
#    echo ${script}
    ssh -i .ssh/gitlab.pem -o StrictHostKeyChecking=no ubuntu@${rabbitPubIps[(($i-1))]} "echo -e '$script' > go.sh; sh go.sh"
done

robot --loglevel DEBUG rabbitmq_ha.robot