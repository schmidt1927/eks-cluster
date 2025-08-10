resource "aws_vpc" "this" {
  cidr_block           = var.cidr_block
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags = merge(local.tags, { Name = "${local.name_prefix}-vpc" })
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id
  tags   = merge(local.tags, { Name = "${local.name_prefix}-igw" })
}

# Create AZs & subnets
data "aws_availability_zones" "available" {}

locals {
  azs = slice(data.aws_availability_zones.available.names, 0, var.az_count)
}

resource "aws_subnet" "public" {
  for_each = { for idx, cidr in var.public_subnets : idx => { cidr = cidr, az = local.azs[idx] } }
  vpc_id                  = aws_vpc.this.id
  cidr_block              = each.value.cidr
  availability_zone       = each.value.az
  map_public_ip_on_launch = true
  tags = merge(local.tags, {
    Name                               = "${local.name_prefix}-public-${each.value.az}"
    "kubernetes.io/role/elb"           = "1"
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
    # Karpenter discovery tag – used by EC2NodeClass subnetSelector
    "karpenter.sh/discovery"           = local.cluster_name
  })
}

resource "aws_subnet" "private" {
  for_each = { for idx, cidr in var.private_subnets : idx => { cidr = cidr, az = local.azs[idx] } }
  vpc_id            = aws_vpc.this.id
  cidr_block        = each.value.cidr
  availability_zone = each.value.az
  tags = merge(local.tags, {
    Name                                    = "${local.name_prefix}-private-${each.value.az}"
    "kubernetes.io/role/internal-elb"       = "1"
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
    "karpenter.sh/discovery"                = local.cluster_name
  })
}

resource "aws_eip" "nat" {
  for_each = aws_subnet.public
  domain   = "vpc"
  tags     = merge(local.tags, { Name = "${local.name_prefix}-eip-${each.value.availability_zone}" })
}

resource "aws_nat_gateway" "this" {
  for_each      = aws_subnet.public
  allocation_id = aws_eip.nat[each.key].id
  subnet_id     = each.value.id
  tags          = merge(local.tags, { Name = "${local.name_prefix}-nat-${each.value.availability_zone}" })
  depends_on    = [aws_internet_gateway.this]
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id
  tags   = merge(local.tags, { Name = "${local.name_prefix}-public-rt" })
}

resource "aws_route" "public_inet" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.this.id
}

resource "aws_route_table_association" "public" {
  for_each       = aws_subnet.public
  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}

# One private RT per AZ paired with its NAT
resource "aws_route_table" "private" {
  for_each = aws_nat_gateway.this
  vpc_id   = aws_vpc.this.id
  tags     = merge(local.tags, { Name = "${local.name_prefix}-private-rt-${each.value.subnet_id}" })
}

resource "aws_route" "private_nat" {
  for_each               = aws_route_table.private
  route_table_id         = each.value.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.this[each.key].id
}

resource "aws_route_table_association" "private" {
  for_each       = aws_subnet.private
  subnet_id      = each.value.id
  # match by index key ("0","1",...) used for both public/private
  route_table_id = aws_route_table.private[each.key].id
}
