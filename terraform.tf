data "aws_availability_zones" "available" {}

resource "aws_vpc" "main" {
 cidr_block = "10.0.0.0/16"

 tags = {
   Name = "main-vpc-eks"
 }
}

resource "aws_subnet" "public_subnet" {
 count                   = 2
 vpc_id                  = aws_vpc.main.id
 cidr_block              = cidrsubnet(aws_vpc.main.cidr_block, 8, count.index)
 availability_zone       = data.aws_availability_zones.available.names[count.index]
 map_public_ip_on_launch = true

 tags = {
   Name = "public-subnet-${count.index}"
 }
}

resource "aws_internet_gateway" "main" {
 vpc_id = aws_vpc.main.id

 tags = {
   Name = "main-igw"
 }
}

resource "aws_route_table" "public" {
 vpc_id = aws_vpc.main.id

 route {
   cidr_block = "0.0.0.0/0"
   gateway_id = aws_internet_gateway.main.id
 }

 tags = {
   Name = "main-route-table"
 }
}

resource "aws_route_table_association" "a" {
 count          = 2
 subnet_id      = aws_subnet.public_subnet.*.id[count.index]
 route_table_id = aws_route_table.public.id
}


module "eks" {
    source  = "terraform-aws-modules/eks/aws"
    version = "~> 21.0"

    name    = "ismael-cluster"
    kubernetes_version = "1.33"

    # Optional
    endpoint_public_access = true

    # Optional: Adds the current caller identity as an administrator via cluster access entry
    enable_cluster_creator_admin_permissions = true

    eks_managed_node_groups = {
    example = {
        instance_types = ["t3.small"]
        min_size       = 1
        max_size       = 3
        desired_size   = 1
    }
    }

    vpc_id     = aws_vpc.main.id
    subnet_ids = aws_subnet.public_subnet.*.id

    tags = {
        Environment = "dev"
        Terraform   = "true"
    }
}
