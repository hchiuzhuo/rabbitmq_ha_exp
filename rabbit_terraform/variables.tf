variable "key_path" {

}

variable "key_name" {

}

variable "cred" {

}

variable "user" {
  default = "ubuntu"
}

variable "tag" {
  default = "rabbit_x"
}

variable "home_dir" {
  default = "/home/ubuntu"
}

variable "instance_type" {
  default = "m3.medium"
}

variable "spot_price" {

}

variable subnet_id {

}

variable "vpc_security_group_ids" {

}

variable "ami" {

}

variable "regions" {
  
}
data "template_file" "user_data" {
  template = "${file("bootstrap/user_data.sh")}"
}