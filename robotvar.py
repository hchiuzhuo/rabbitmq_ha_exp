import json
with open('rabbit_terraform/terraform.tfstate') as data_file:
    data = json.load(data_file)
rabbit_hosts = data["modules"][0]["outputs"]["public_ips"]["value"]

rabbit_1_host = rabbit_hosts[0]
rabbit_2_host = rabbit_hosts[1]
rabbit_3_host = rabbit_hosts[2]