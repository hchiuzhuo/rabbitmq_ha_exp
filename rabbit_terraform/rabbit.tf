provider "aws" {
  version = "~> 1.5"
  region     = "${var.regions}"
}
resource "aws_spot_instance_request" "ec2" {
  ami           = "${var.ami}"
  instance_type = "${var.instance_type}"
  count = 3
  tags {
    Name = "MQ-${count.index}"
  }

  key_name = "${var.key_name}"
  subnet_id = "${var.subnet_id}"
  vpc_security_group_ids = ["${var.vpc_security_group_ids}"]

  spot_price = "${var.spot_price}"
  wait_for_fulfillment = true
  connection {
    host = "${self.public_dns}"
    user = "${var.user}"
    private_key = "${file("${var.key_path}")}"
  }
  provisioner "remote-exec" {
     inline = [
       "${data.template_file.user_data.rendered}",

     ]
  }
   timeouts {
    create = "60m"
    delete = "2h"
  }
}

output "public_ips" {
  value = "${aws_spot_instance_request.ec2.*.public_dns}"
}
output "private_ips" {
  value = "${aws_spot_instance_request.ec2.*.private_ip}"
}
