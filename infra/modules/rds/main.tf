resource "aws_db_subnet_group" "this" {
  name       = "${var.name_prefix}-db-subnet-group"
  subnet_ids = var.database_subnet_ids

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-db-subnet-group"
  })
}

resource "aws_security_group" "database" {
  name        = "${var.name_prefix}-database-sg"
  description = "Controls inbound access to the ReleaseOps PostgreSQL database."
  vpc_id      = var.vpc_id

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-database-sg"
  })
}
resource "aws_security_group" "application" {
  name        = "${var.name_prefix}-application-sg"
  description = "Represents application workloads allowed to reach ReleaseOps PostgreSQL."
  vpc_id      = var.vpc_id

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-application-sg"
  })
}

resource "aws_vpc_security_group_ingress_rule" "postgres_from_application" {
  security_group_id            = aws_security_group.database.id
  referenced_security_group_id = aws_security_group.application.id
  ip_protocol                  = "tcp"
  from_port                    = 5432
  to_port                      = 5432

  description = "Allow PostgreSQL from ReleaseOps application workloads."
}
resource "aws_kms_key" "database" {
  description             = "KMS key for ReleaseOps database and database secret encryption."
  deletion_window_in_days = 7
  enable_key_rotation     = true

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-database-kms"
  })
}

resource "aws_kms_alias" "database" {
  name          = "alias/${var.name_prefix}-database"
  target_key_id = aws_kms_key.database.key_id
}

resource "aws_secretsmanager_secret" "database" {
  name                    = "${var.name_prefix}/database/master"
  description             = "Master database credentials for ReleaseOps PostgreSQL."
  kms_key_id              = aws_kms_key.database.arn
  recovery_window_in_days = var.db_secret_recovery_window_days

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-database-master-secret"
  })
}
resource "random_password" "database_master" {
  length           = 24
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "aws_secretsmanager_secret_version" "database" {
  secret_id = aws_secretsmanager_secret.database.id

  secret_string = jsonencode({
    username = var.db_master_username
    password = random_password.database_master.result
    database = var.db_name
  })
}
resource "aws_db_instance" "postgres" {
  identifier = "${var.name_prefix}-postgres"

  engine         = "postgres"
  engine_version = var.db_engine_version
  instance_class = var.db_instance_class

  allocated_storage = var.db_allocated_storage_gb
  storage_type      = "gp3"
  storage_encrypted = true
  kms_key_id        = aws_kms_key.database.arn

  db_name  = var.db_name
  username = var.db_master_username
  password = random_password.database_master.result

  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [aws_security_group.database.id]
  publicly_accessible    = false
  multi_az               = false

  backup_retention_period = var.db_backup_retention_days
  deletion_protection     = false
  skip_final_snapshot     = true

  auto_minor_version_upgrade = true
  apply_immediately          = true

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-postgres"
  })
}