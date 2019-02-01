variable "region" {
  default = "ap-southeast-2"
}

variable "profile" {
  default = "lab01"
}

variable "cidr" { 
  default = "10.1.0.0/16" 
}

variable "lab" { 
  default = "terraform" 
}

variable "ami" { 
  default = "ami-07a3bd4944eb120a0" 
}

variable "key_name" { 
  default = "aws-lab00" 
}

variable "my_public_ip" {
  default = "128.66.0.1/32"
}
