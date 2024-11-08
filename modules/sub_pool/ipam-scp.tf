# The following resources are added outside of
# https://github.com/aws-ia/terraform-aws-ipam/tree/v1.1.4
# https://registry.terraform.io/modules/aws-ia/ipam/aws/latest


locals {
  scp_enabled = try(length(var.pool_config.ram_share_principals), 0) > 0 && var.pool_config.create_scp
}

resource "aws_organizations_policy" "restrict_ipam_pools" {
  #This should get deployed to root account
  provider = aws.root

  for_each    = local.scp_enabled ? toset(var.pool_config.ram_share_principals) : []
  name        = "Restrict IPAM Pool ${var.implied_name} ${each.key}"
  description = "Restrict IPAM Pool #${each.key} ${var.implied_locale != "None" ? var.implied_locale : var.pool_config.locale}"

  content = jsonencode({
    "Version" : "2012-10-17"
    "Statement" : [
      {
        "Effect" : "Deny",
        "Action" : ["ec2:CreateVpc", "ec2:AssociateVpcCidrBlock"],
        "Resource" : "arn:aws:ec2:${var.implied_locale != "None" ? var.implied_locale : var.pool_config.locale}:*:vpc/*",

        "Condition" : {
          "StringNotEquals" : {
            "ec2:Ipv4IpamPoolId" : aws_vpc_ipam_pool.sub.id
          }
        }
      }
    ]
  })
}

resource "aws_organizations_policy_attachment" "restrict_ipam_pools_scp_target" {
  #This should get deployed to root account
  provider = aws.root

  for_each  = local.scp_enabled ? toset(var.pool_config.ram_share_principals) : []
  policy_id = aws_organizations_policy.restrict_ipam_pools[each.key].id
  target_id = each.key
}