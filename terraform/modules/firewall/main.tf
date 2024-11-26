terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "0.66.3"
    }
  }
}

resource "proxmox_virtual_environment_cluster_firewall" "example" {
  enabled = true

  ebtables      = true
  input_policy  = "DROP"
  output_policy = "ACCEPT"
  # log_ratelimit {
  #   enabled = false
  #   burst   = 10
  #   rate    = "5/second"
  # }
}

resource "proxmox_virtual_environment_cluster_firewall_security_group" "icmp" {
  name    = "${var.environment}-icmp"
  comment = "ICMP (ping) enabled hosts"

  rule {
    type    = "in"
    action  = "ACCEPT"
    comment = "Allow ICMP"
    proto   = "icmp"
    log     = "info"
    enabled = var.icmp_enabled
  }
}

resource "proxmox_virtual_environment_cluster_firewall_security_group" "ssh" {
  name    = "${var.environment}-ssh"
  comment = "SSH enabled hosts"

  rule {
    type    = "in"
    action  = "ACCEPT"
    comment = "Open SSH access"
    macro   = "SSH"
    log     = "info"
  }
}

resource "proxmox_virtual_environment_cluster_firewall_security_group" "http" {
  name    = "${var.environment}-http"
  comment = "HTTP servs"

  rule {
    type    = "in"
    action  = "ACCEPT"
    comment = "HTTP servs"
    macro   = "HTTP"
    log     = "info"
  }
}

resource "proxmox_virtual_environment_cluster_firewall_security_group" "https" {
  name    = "${var.environment}-https"
  comment = "HTTPS servs"

  rule {
    type    = "in"
    action  = "ACCEPT"
    comment = "HTTPS servs"
    macro   = "HTTPS"
    log     = "info"
  }
}

resource "proxmox_virtual_environment_cluster_firewall_security_group" "dns" {
  name    = "${var.environment}-dns"
  comment = "DNS servs"

  rule {
    type    = "in"
    action  = "ACCEPT"
    comment = "DNS servs"
    macro   = "DNS"
    log     = "info"
  }
}

