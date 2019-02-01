provider "aws" {
#  access_key = "ACCESS_KEY_HERE" # use ~/.aws/credentials instead
#  secret_key = "SECRET_KEY_HERE"
  profile    = "${var.profile}"
  region     = "${var.region}"
}

resource "aws_vpc" "main" {
  cidr_block            = "${var.cidr}"
  enable_dns_hostnames  = true

  tags = {
    Name = "vpc-${var.lab}"
  }
}

resource "aws_internet_gateway" "main" {
  vpc_id = "${aws_vpc.main.id}"

  tags = {
    Name = "igw-${var.lab}"
  }
}

# subnet

resource "aws_subnet" "fe_a" {
  vpc_id = "${aws_vpc.main.id}"
  cidr_block = "10.1.0.0/24"
  availability_zone = "${var.region}a"

  tags = {
    Name = "net-${var.lab}-fe-a"
  }
}

resource "aws_subnet" "fe_b" {
  vpc_id = "${aws_vpc.main.id}"
  cidr_block = "10.1.1.0/24"
  availability_zone = "${var.region}b"

  tags = {
    Name = "net-${var.lab}-fe-b"
  }
}

resource "aws_subnet" "be_a" {
  vpc_id = "${aws_vpc.main.id}"
  cidr_block = "10.1.16.0/24"
  availability_zone = "${var.region}a"

  tags = {
    Name = "net-${var.lab}-be-a"
  }
}

resource "aws_subnet" "be_b" {
  vpc_id = "${aws_vpc.main.id}"
  cidr_block = "10.1.17.0/24"
  availability_zone = "${var.region}b"

  tags = {
    Name = "net-${var.lab}-be-b"
  }
}

# route table

resource "aws_route_table" "main" {
  vpc_id = "${aws_vpc.main.id}"

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.main.id}"
  }
}

resource "aws_route_table_association" "a" {
  subnet_id      = "${aws_subnet.fe_a.id}"
  route_table_id = "${aws_route_table.main.id}"
}
resource "aws_route_table_association" "b" {
  subnet_id      = "${aws_subnet.fe_b.id}"
  route_table_id = "${aws_route_table.main.id}"
}
resource "aws_route_table_association" "c" {
  subnet_id      = "${aws_subnet.be_a.id}"
  route_table_id = "${aws_route_table.main.id}"
}
resource "aws_route_table_association" "d" {
  subnet_id      = "${aws_subnet.be_b.id}"
  route_table_id = "${aws_route_table.main.id}"
}


# security groups

resource "aws_security_group" "admin_access" {
  vpc_id = "${aws_vpc.main.id}"
  name = "${var.lab}-admin"
  description = "Admin access"

  tags = {
    Name = "${var.lab}-admin"
  }

  ingress {
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = [ "${var.my_public_ip}" ]
  }

  ingress {
    from_port = 8
    to_port = -1
    protocol = "icmp"
    cidr_blocks = [ "${var.my_public_ip}" ]
  }
}

resource "aws_security_group" "frontend_access" {
  vpc_id = "${aws_vpc.main.id}"
  name = "${var.lab}-fe"
  description = "Frontend access"

  tags = {
    Name = "${var.lab}-fe"
  }
}

resource "aws_security_group" "backend_access" {
  vpc_id = "${aws_vpc.main.id}"
  name = "${var.lab}-be"
  description = "Allow public ICMP"

  tags = {
    Name = "${var.lab}-be"
  }

  ingress {
    from_port = -1
    to_port = 0
    protocol = 0
    security_groups = [ "${aws_security_group.frontend_access.id}" ]
  }
}

# instances

resource "aws_instance" "fe-a" {
  ami           = "${var.ami}"
  instance_type = "t2.micro"
  availability_zone = "${var.region}a"
  subnet_id = "${aws_subnet.fe_a.id}"
  vpc_security_group_ids = [ 
    "${aws_security_group.admin_access.id}", 
    "${aws_security_group.frontend_access.id}" 
  ]
  key_name = "${var.key_name}"
  associate_public_ip_address = true

  tags = {
    Name = "ins-${var.lab}-fe-a"
  }
}

resource "aws_instance" "fe-b" {
  ami           = "${var.ami}"
  instance_type = "t2.micro"
  availability_zone = "${var.region}b"
  subnet_id = "${aws_subnet.fe_b.id}"
  vpc_security_group_ids = [ 
    "${aws_security_group.admin_access.id}", 
    "${aws_security_group.frontend_access.id}" 
  ]
  key_name = "${var.key_name}"
  associate_public_ip_address = true

  tags = {
    Name = "ins-${var.lab}-fe-b"
  }
}

resource "aws_instance" "be-a" {
  ami           = "${var.ami}"
  instance_type = "t2.micro"
  availability_zone = "${var.region}a"
  subnet_id = "${aws_subnet.be_a.id}"
  vpc_security_group_ids = [ 
    "${aws_security_group.admin_access.id}", 
    "${aws_security_group.backend_access.id}"
  ]
  key_name = "${var.key_name}"
  associate_public_ip_address = true

  tags = {
    Name = "ins-${var.lab}-be-a"
  }
}

resource "aws_instance" "be-b" {
  ami           = "${var.ami}"
  instance_type = "t2.micro"
  availability_zone = "${var.region}b"
  subnet_id = "${aws_subnet.be_b.id}"
  vpc_security_group_ids = [ 
    "${aws_security_group.admin_access.id}", 
    "${aws_security_group.backend_access.id}"
  ]
  key_name = "${var.key_name}"
  associate_public_ip_address = true

  tags = {
    Name = "ins-${var.lab}-be-b"
  }
}
