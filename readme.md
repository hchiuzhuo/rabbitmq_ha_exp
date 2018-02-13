# Rabbitmq HA experiments

## 1. Goal
This project is an integration test demo for testing rabbitmq high availability (HA).
In this project, we will go through several HA test scenarios and to learn how to establish an HA message queue.
Furthermore, this project is a prototype for showing how to run an integration test suit automatically.
We will cover how to automatically create ec2 from aws, deploy rabbitmq, and run test scripts. We will leverage this project to learning how to achieve the purpose of infra-as-code.

## 2. Environment Preparation
```
    |---------------|
   Rabbit_1       Rabbit_2
```
Initially, we will have the basic message queue structure with 2 rabbit node connect to each other. This cluster should achieved the following requirements.

1. Rabbit_1 and Rabbit_2 can talk to each other through mqtt.
2. Rabbit clients communicate with message queue. Each rabbit is a docker service that runs on an ec2 instance.
3. Rabbit_1 and Rabbit_2 have identical queue meta. (mirrored queues set up by HA policy)

## 3. Machine Provision

In this project, we leverage terraform, v0.10.8, as the machine provision tool. Details can be referred to folder, rabbit_terraform.

Terraform ref. <br>
https://blog.gruntwork.io/an-introduction-to-terraform-f17df9c6d180
https://blog.gruntwork.io/terraform-tips-tricks-loops-if-statements-and-gotchas-f739bbae55f9
https://www.terraform.io/

#### 3.1 Single Machine

In this project, machines' spec has to be aws ec2 t2.micro at least. Because rabbitmq requires ports, 4369, 5672, 15672, 25672, and 35197, make sure the security group inbound rule covers these ports.

When terraform instantiate an ec2, the default os is Ubuntu Server 16.04 LTS. We will install the latest docker on ec2, which is described in rabbit_terraform/bootstrap/user_data.sh

#### 3.2 Cluster

In this project, we instantiate 3 single machines in default. Two of them will be connected into a cluster and the other is for running HA tests. Three machines' specs are identical. Details can be referred to rabbit_terraform/rabbit.rf.

Commands to instantiate the cluster is described as below.

```bash
cd rabbit_terraform
terraform init
terraform apply
```
Command to delete the cluster is described as below.

```bash
terraform destroy
```


## 4. Rabbitmq Deployment
In this project, we leverage docker to deploy rabbitmq service. Some projects leverage docker-compose to set up 1 rabbitmq cluster in one machine; however, in this project, we prefer to mimic the actual scenario. The actual scenario is to glue multiple rabbitmq machines into one cluster, such as openstack message queue (https://docs.openstack.org/ha-guide/shared-messaging.html).

Rabbitmq docker deployment ref.
http://josuelima.github.io/docker/rabbitmq/cluster/2017/04/19/setting-up-a-rabbitmq-cluster-on-docker.html

#### 4.1 Single machine

Deploy a rabbitmq service on a single machine is simple. We use the official rabbitmq docker image, rabbitmq:3.6.6-management, as our rabbitmq service. Remember to replace #rabbit_1_private_ip, #rabbit_2_private_ip, and #rabbit_3_private_ip with your actual ip settings.

By ssh into any machine and run with the following script, you should be able to instantiate a rabbitmq docker container, named rabbit, on your machine.

    sudo docker run -d -h node-${i}.rabbit \\
    --add-host=node-1.rabbit:#rabbit_1_private_ip\\
    --add-host=node-2.rabbit:#rabbit_2_private_ip \\
    --add-host=node-3.rabbit:#rabbit_3_private_ip\\
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

#### 4.2 cluster

Rabbitmq is born to be easily established as a cluster. By ssh into one machine, e.g. rabbit_2, and run several commands, you should be able to see the cluster info on the rabbitmq web page, http://public_ip:15672.

```
ssh into   ${rabbit_2}
Execute Command    sudo docker exec rabbit rabbitmqctl stop_app
Execute Command    sudo docker exec rabbit rabbitmqctl join_cluster rabbit@${added_node_hostname}
Execute Command    sudo docker exec rabbit rabbitmqctl start_app
Execute Command    sudo docker exec rabbit rabbitmqctl set_policy ha-all '^(?!amq\.).*' '{"ha-mode": "all"}'
Close Connection
```

A successful view of cluster can be viewed from the GUI.

![rabbitmq_cluster](./img/rabbitmq_cluster.png)

## 5. HA Cluster Test cases
Given the basic message queue structure defined in sec.2, we design several tests to establish an HA message queue cluster.

Before we run test cases, we have to set up a test environment. In this project, we have provide some scripts to expedite the whole process. We leverage docker as our test environment. This docker container has to install several python library, defined in requirements.txt. Details about this docker container can be referred at dockerfile. Because some test cases requires ssh into ec2, be sure to mount your aws pem key folder, .ssh, to this container.

Because we leverage ec2 as our test machine, we need to set pem key place. Related file includes
- activateRabbit.sh
- cleanRabbit.sh
- rabbit_terraform/variables.tf
Remember to replace your pemkey in those files.

```
# instantiate ec2 instances, sec.3
cd rabbit_terraform
terraform init
terraform apply
cd ..

# create test environment docker image
docker build -t rabbitmq_ha_exp .

# instantiate test environment docker container
docker run -t -d --name rabbit \
-v /Users/cherylchiu/Dev/python/rabbitmq_ha_exp:/usr/src/app \
-v /Users/cherylchiu/.ssh:/usr/src/app/.ssh \
-v /Users/cherylchiu/.aws:/root/.aws \              # mount .aws only if running on local machine
rabbitmq_ha_exp

# provision machine
docker exec -i rabbit bash -c "cd rabbit_terraform; cd rabbit_terraform; terraform init; terraform apply -var 'subnet_id=$your_subnet_id' -var 'vpc_security_group_ids=$your_security' -var 'key_path=$yourpempath' -var 'key_name=$yourkey' -var 'cred=$yourcred'  "

# deploy rabbitmq services to ec2 instances, sec 4
docker exec -i rabbit /bin/bash activateRabbit.sh

# run single test case
docker exec -i rabbit robot --loglevel DEBUG -t "Test SSH Connection" rabbitmq_ha.robot

# run whole test suite
docker exec -i rabbit robot --loglevel DEBUG rabbitmq_ha.robot

# destroy rabbitmq services on ec2 instances
docker exec -i rabbit /bin/bash cleanRabbit.sh

# destroy ec2 instances.
docker exec -i rabbit bash -c 'cd rabbit_terraform; terraform destroy -force'
```

We leverage robot framework to define our test scenarios.
All these information can be found at rabbitmq_ha.robot.
Initially, we will form a HA rabbitmq cluster with 2 rabbit nodes, as described in sec.2.
Details can be referred to rabbitmq_ha.robot *Prepare test init cluster.*

#### 5.1 Test ssh Connection

* Scenario: Given 3 ec2 instances, we can ssh into each machine and execute “echo connect to rabbit_n” messages.
* Steps: Manually ssh in or run by robot test case, *Test SSH Connection.*
* Expected Results: 3 machines can correctly reply message “connect to rabbit_n”

#### 5.2 Test AMQP Connection

* Scenario: Given 3 rabbitmq nodes, we can see the connection to each node is open.
* Steps:
    * Run by robot test case, *Test AMQP Connection*.
    * Manually run *sudo docker exec rabbit rabbitmqctl status.*
* Expected Results: Connections can be established to 3 nodes.

#### 5.3 Test Rabbitmq Message Pub Sub

* Scenario: Givne a cluster with 2 rabbitmq nodes, we can validate the function of pub to rabbit_1 and consume from rabbit_2 is correct.
* Steps:
    * Run by robot test case, *Test Rabbitmq Message Pub Sub. *
* Manually Run:
    * ref. https://www.rabbitmq.com/tutorials/tutorial-one-python.html

        ```
        # create a sender.py
        #!/usr/bin/env python
        import pika

        connection = pika.BlockingConnection(pika.ConnectionParameters(
               host='54.238.233.214'))
        channel = connection.channel()

        channel.queue_declare(queue='hello')

        channel.basic_publish(exchange='',
                              routing_key='hello',
                              body='Hello World!')
        print(" [x] Sent 'Hello World!'")
        connection.close()

        -----------------------------------------------------------------------------------
        #create a receive .py
        #!/usr/bin/env python
        import pika

        def callback(ch, method, properties, body):
            print(" [x] Received %r" % body)

        connection =pika.BlockingConnection(pika.ConnectionParameters(
               host='54.238.233.214'))
        channel = connection.channel()

        channel.basic_consume(callback,
                              queue='hello',
                              no_ack=True)
        print(' [*] Waiting for messages. To exit press CTRL+C')
        channel.start_consuming()

        # open receiver terminal

        Cheryls-MacBook-Air:rabbitmq_ha_exp cherylchiu$ python receive.py
         [*] Waiting for messages. To exit press CTRL+C

        # open sender terminal

        Cheryls-MacBook-Air:rabbitmq_ha_exp cherylchiu$ python send.py
         [x] Sent 'Hello World!'

        # check receiver terminal

        Cheryls-MacBook-Air:rabbitmq_ha_exp cherylchiu$ python receive.py
         [*] Waiting for messages. To exit press CTRL+C
         [x] Received b'Hello World!'
        ```

* Expected Results: Message publish to rabbit_1 can be consumed by rabbit_2.

#### 5.4 Test Rabbitmq HA
* Scenario: Given rabbit_1 and rabbit_2 alive nodes, we can validate the rabbitmq HA policy, mirror queue, is set up correctly.
* Steps:
    * Run by robot test case, *Test SSH Connection.*
    * Manually Run.
        ```
        Publish message, "Test Rabbitmq HA", to rabbit_1 with topic "TestRabbitHA".
        SSH into rabbit_1 and terminate rabbit_1 service.
        Subscribe message from rabbit_2 with topic "TestRabbitHA"
        ```
* Expected Results: Message, “Test Rabbitmq HA” should be received from rabbit_2 even rabbit_1 is not alive.

#### 5.5 Test Scalability

* Scenario: Given a rabbitmq cluster with 2 nodes, rabbit_1 and rabbit_2, we add a new node, rabbit_3, into the cluster to form a three-node cluster.
* Steps:
    * Run by robot test case, *Test scalability.*
    * Manually Run.
        ```
            rabbit3$ rabbitmqctl stop_app
            rabbit3$ rabbitmqctl join_cluster rabbit@node-2.rabbit
            rabbit3$ rabbitmqctl start_app
        ```
* Expected Results: Message published to rabbit_3 can be received either from Rabbit_1 or Rabbit_2.

#### 5.6 Test Fault tolerance

* Scenario: Given a 3-node cluster, we intentionally destroy rabbit_3. We can validate if one node is destroyed from cluster, the cluster still provides normal service.
* Steps:
    * Run by robot test case, *Test fault tolerance.*
    * Manually Run:
        ```
        Publish message to rabbit_3.
        rabbit3$ rabbitmqctl stop_app.
        Subscribe message from rabbit_2.
        Publish message to rabbit_1.
        Subscribe message from rabbit_2
        ```
* Expected Results
    * Message published to Rabbit_3 is still can be consumed.
    * The 2-node cluster should still be able to provide service.
    * From Rabbit_1 and Rabbit_2 GUI, we can view Rabbit_3 shows fail.

#### 5.7 Test fail recovery
* Scenario: Given a 2-node cluster with losing connection to rabbit_3, we fix Rabbit_3 and add Rabbit_3 back.
* Steps
    * Run by robot test case, *Test fail recovery.*
    * Manually Run:
        ```
        rabbit1$ rabbitmqctl -n rabbit@node-1.rabbit forget_cluster_node rabbit@node-3.rabbit
        Publish msg to rabbit_1 and receive msg from rabbit_2.
        rabbit3$ rabbitmqctl reset
        rabbit3$ rabbitmqctl join_cluster rabbit@rabbit1
        rabbit3$ rabbitmqctl start_app
        Publish msg to rabbit_3 and receive msg from rabbit_2.
        ```
* Expected Results
    * When we set forget node_3 from cluster, we still can run pub/sub service on the remaining nodes.
    * From rabbit_1 and rabbit_2 GUI, we will no longer view rabbit_3.
    * When we add node_3 back to cluster, the node_3 can provide service immediately.

#### 5.8 Test Cluster upgrade
* Scenario
    * Given a 2-node cluster, we turn-off cluster in the order of Rabbit_2 and Rabbit_1 and restart node in the order of Rabbit_1 and Rabbit_2.
* Steps
    * Run by robot test case, *Test cluster upgrade**.*
    * Manually Run:
        ```
        Rabbit_1$ rabbitmqctl stop
        Rabbit_2$ rabbitmqctl stop
        Rabbit_2$ rabbitmqctl start
        Rabbit_1$ rabbitmqctl start
        ```
#### 5.9 Test cluster randomly failed
* Expected Results
    * The 2-node cluster should be able to provide service.
* Scenario
    * Given a 2-node cluster, we turn-off cluster in the order of Rabbit_2 and Rabbit_1 and restart node in the order of Rabbit_2 and Rabbit_1.
    * Recover the cluster back to healthy state.
* Steps
    * Run by robot test case, *Test cluster randomly failed**.*
    * Manually Run:
        ```
        Rabbit_1$ rabbitmqctl stop
        Rabbit_2$ rabbitmqctl stop
        Rabbit_1$ rabbitmqctl force_reset
        Rabbit_1$ rabbitmqctl start_app
        Rabbit_2$ rabbitmqctl force_reset
        Rabbit_2$ rabbitmqctl join_cluster rabbit@node-1.rabbit
        Rabbit_2$ rabbitmqctl start rabbit
        Rabbit_2$ sudo docker set_policy ha-all '^(?!amq\.).*' '{"ha-mode": "all"}'
        Publish message to rabbit_1 and receive message from rabbit_2
        ```

* Expected Results
    * The 2-node cluster should be able to provide service.

* Note!! This test case may cause message queue's data missing eventhough we have set HA policy.




<!--
### 6. Complete run script
```bash

docker build -t rabbitmq_ha_exp .

docker run -t -d --name rabbit \
-v /Users/cherylchiu/Dev/python/rabbitmq_ha_exp:/usr/src/app \
-v /Users/cherylchiu/.ssh:/usr/src/app/.ssh \
-v /Users/cherylchiu/.aws:/usr/src/app/.aws \
rabbitmq_ha_exp

docker run -t -d --name rabbit \
-v /Users/cherylchiu/Dev/python/rabbitmq_ha_exp:/usr/src/app \
-v /Users/cherylchiu/.ssh:/usr/src/app/.ssh \
-v /Users/cherylchiu/.aws:/root/.aws \
rabbitmq_ha_exp

docker exec -i rabbit bash -c "cd rabbit_terraform; cd rabbit_terraform; terraform init; terraform apply "
- docker run -t -d --name rabbit -v /home/ec2-user/rabbitmq_ha_exp:/usr/src/app -v /home/ec2-user/.ssh:/usr/src/app/.ssh rabbitmq_ha_exp

cd rabbit_terraform
terraform init
terraform apply
cd ..

docker exec -it rabbit . activateRabbit.sh
docker exec -it rabbit robot --loglevel DEBUG -t "Test SSH Connection" rabbitmq_ha.robot
docker exec -it rabbit robot --loglevel DEBUG rabbitmq_ha.robot
docker exec -it rabbit . cleanRabbit.sh

terraform destroy

# deploy rabbitmq services to ec2 instances, sec 4
docker exec -i rabbit /bin/bash activateRabbit.sh


# run single test case
docker exec -i rabbit robot --loglevel DEBUG -t "Test SSH Connection" rabbitmq_ha.robot

# run whole test suite
docker exec -i rabbit robot --loglevel DEBUG rabbitmq_ha.robot

# destroy rabbitmq services on ec2 instances
docker exec -i rabbit /bin/bash cleanRabbit.sh

# destroy ec2 instances.
docker exec -i rabbit bash -c 'cd rabbit_terraform; terraform destroy -force'
```
-->