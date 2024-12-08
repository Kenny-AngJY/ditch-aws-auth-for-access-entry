### Creates a default (main) route table and default (main) NACL
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr_block
  enable_dns_hostnames = true
  tags = merge(
    var.default_tags,
    {
      Name = "terraform-vpc-${var.stack_name}"
    },
  )
}

resource "aws_internet_gateway" "internet-gw" {
  vpc_id = aws_vpc.main.id
  tags = merge(
    var.default_tags,
    {
      Name = "terraform-vpc-igw-${var.stack_name}"
    },
  )
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.internet-gw.id
  }
  tags = merge(
    var.default_tags,
    {
      Name = "custom-public-routetable-${var.stack_name}"
    },
  )
}

resource "aws_subnet" "public" {
  # If you do not explictly state which route table the subnet is associated with,
  # it will be associated with the default route table.
  count                   = length(var.list_of_azs)
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.list_of_public_cidr_range[count.index]
  availability_zone       = var.list_of_azs[count.index]
  map_public_ip_on_launch = true
  tags = merge(
    var.default_tags,
    {
      Name = format("terraform_public_%s", (count.index + 1))
    },
  )
}

resource "aws_route_table_association" "public" {
  count          = length(var.list_of_azs)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_subnet" "private" {
  # If you do not explictly state which route table the subnet is associated with,
  # it will be associated with the default route table.
  count                   = length(var.list_of_azs)
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.list_of_private_cidr_range[count.index]
  availability_zone       = var.list_of_azs[count.index]
  map_public_ip_on_launch = false
  tags = merge(
    var.default_tags,
    {
      Name = format("terraform_private_%s", (count.index + 1))
    },
  )
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id
  dynamic "route" {
    for_each = var.create_nat_gateway ? [1] : []
    content {
      cidr_block     = "0.0.0.0/0"
      nat_gateway_id = aws_nat_gateway.public[0].id
    }
  }
  # route {
  #   cidr_block     = "0.0.0.0/0"
  #   nat_gateway_id = aws_nat_gateway.public[0].id # What if nat gateway is not created?
  # }
  tags = merge(
    var.default_tags,
    {
      Name = "custom-private-routetable-${var.stack_name}"
    },
  )
}

resource "aws_eip" "nat_gw" {
  count      = var.create_nat_gateway ? 1 : 0
  domain     = "vpc"
  depends_on = [aws_internet_gateway.internet-gw]
}

resource "aws_nat_gateway" "public" {
  count         = var.create_nat_gateway ? 1 : 0
  allocation_id = aws_eip.nat_gw[0].id
  subnet_id     = aws_subnet.public[0].id

  tags = merge(
    var.default_tags,
    {
      Name = "NAT-GW-EKS-Fargate-${var.stack_name}"
    },
  )

  # To ensure proper ordering, it is recommended to add an explicit dependency
  # on the Internet Gateway for the VPC.
  depends_on = [aws_internet_gateway.internet-gw]
}

resource "aws_route_table_association" "private" {
  count          = length(var.list_of_azs)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}