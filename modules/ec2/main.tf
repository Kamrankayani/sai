resource "aws_instance" "this" {
  count = var.instance_count
  
  ami                    = var.ami_id
  instance_type          = var.instance_type
  subnet_id              = var.subnet_id
  vpc_security_group_ids = var.security_group_ids
  key_name               = var.key_name
  
  # Dynamic user_data that sets unique hostname for each instance
   user_data = <<-EOT
              #!/bin/bash
              HOSTNAME="${var.instance_name}-${count.index + 1}"
              hostnamectl set-hostname $HOSTNAME
              echo "Hostname set to: $HOSTNAME"
              EOT
  
  root_block_device {
    volume_type = "gp3"
    volume_size = var.root_volume_size
    encrypted   = true
    
    tags = merge(
      {
        Name = "${var.instance_name}-${count.index + 1}-volume"
      },
      var.tags
    )
  }
  
  tags = merge(
    {
      Name        = "${var.instance_name}-${count.index + 1}"
      Environment = var.environment
    },
    var.tags
  )
}

resource "aws_eip" "this" {
  count    = var.instance_count
  instance = aws_instance.this[count.index].id
  domain   = "vpc"
  
  tags = merge(
    {
      Name = "${var.instance_name}-${count.index + 1}-eip"
    },
    var.tags
  )
}