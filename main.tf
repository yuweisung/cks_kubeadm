provider "google" {
  credentials = file(var.gcp_profile.credentials)
  project     = var.gcp_profile.project
  region      = var.gcp_profile.region
  zone        = var.gcp_profile.zone
}

data "google_dns_managed_zone" "cks_public_zone" {
  name = var.gcp_public_dns_zone.zone_name
}

data "external" "myipaddr" {
  program = ["sh", "-c", "curl -s 'https://api.ipify.org?format=json'"]
}

resource "google_compute_address" "lb_ext_ip" {
  name = "lb-ext-ip"
}

resource "google_compute_network" "cks_network" {
  name                    = "cks-vpc"
  auto_create_subnetworks = false
  provisioner "local-exec" {
    when    = destroy
    command = "gcloud compute routes list --filter=\"name~'kubernetes*'\" --uri | xargs gcloud compute routes delete --quiet &&  gcloud compute firewall-rules list --filter=\"name~'k8s*'\" --uri | xargs gcloud compute firewall-rules delete --quiet&&gcloud compute disks list --filter=\"name~'kubernetes-dynamic-pvc*'\" --uri | xargs gcloud compute disks delete --quiet "
  }
}

resource "google_dns_managed_zone" "cks_private_zone" {
  name       = var.gcp_private_dns_zone.zone_name
  dns_name   = var.gcp_private_dns_zone.dns_name
  visibility = "private"
  private_visibility_config {
    networks {
      network_url = google_compute_network.cks_network.id
    }
  }
}

resource "google_compute_subnetwork" "cks_subnet" {
  name          = "cks-subnet"
  ip_cidr_range = var.vpc_subnet_cidr
  network       = google_compute_network.cks_network.name
}

resource "google_compute_firewall" "cks_allow_internal" {
  name    = "cks-allow-internal"
  network = google_compute_network.cks_network.name
  allow {
    protocol = "sctp"
  }
  allow {
    protocol = "ipip"
  }
  allow {
    protocol = "tcp"
  }
  allow {
    protocol = "udp"
  }
  allow {
    protocol = "icmp"
  }
  source_ranges = [var.vpc_subnet_cidr, var.k8s_pod_cidr]
  target_tags   = ["kubernetes"]
}

resource "google_compute_firewall" "cks_allow_external" {
  name    = "cks-allow-external"
  network = google_compute_network.cks_network.name
  allow {
    protocol = "icmp"
  }
  allow {
    protocol = "tcp"
    ports    = [22, 6443]
  }
  source_ranges = [lookup(data.external.myipaddr.result, "ip")]
  target_tags   = ["kubernetes"]
}

resource "google_compute_firewall" "cks_allow_nodeports_external" {
  name    = "cks-allow-nodeports"
  network = google_compute_network.cks_network.name
  allow {
    protocol = "tcp"
    ports    = ["30000-32767"]
  }
  source_ranges = [lookup(data.external.myipaddr.result, "ip")]
}

resource "google_dns_record_set" "cks_masters_external" {
  count = var.gcp_public_dns_zone.enabled ? 1 : 0
  name         = "cks.${data.google_dns_managed_zone.cks_public_zone.dns_name}"
  type         = "A"
  ttl          = 300
  managed_zone = data.google_dns_managed_zone.cks_public_zone.name
  rrdatas      = [google_compute_address.lb_ext_ip.address]
}

resource "google_compute_instance" "cks-masters" {
  count        = var.master_count
  name         = "cks-master${count.index + 1}"
  machine_type = var.gce_vm.instance_type
  hostname     = "cks-master${count.index + 1}.${trimsuffix(var.gcp_private_dns_zone.dns_name, ".")}"
  metadata = {
    ssh-keys = "${var.gce_vm.ssh_user}: ${file(var.gce_vm.ssh_pub)}"
  }
  boot_disk {
    auto_delete = true
    initialize_params {
      size  = var.gce_vm.boot_disk_size
      image = "${var.gce_vm.os_project}/${var.gce_vm.os_family}"
    }
  }
  network_interface {
    subnetwork = google_compute_subnetwork.cks_subnet.self_link
    network_ip = cidrhost(var.vpc_subnet_cidr, count.index + 11)
    access_config {
      nat_ip = google_compute_address.lb_ext_ip.address
    }
  }
  can_ip_forward = true
  tags           = ["kubernetes", "k8s", "controller"]
  service_account {
    scopes = ["compute-rw", "storage-full", "cloud-platform", "service-management", "service-control", "logging-write", "monitoring"]
  }
}

resource "google_compute_instance" "cks-workers" {
  count        = var.worker_count
  name         = "cks-worker${count.index + 1}"
  machine_type = var.gce_vm.instance_type
  hostname     = "cks-worker${count.index + 1}.${trimsuffix(var.gcp_private_dns_zone.dns_name, ".")}"
  metadata = {
    ssh-keys = "${var.gce_vm.ssh_user}: ${file(var.gce_vm.ssh_pub)}"
    pod-cidr = cidrsubnet(var.k8s_pod_cidr, 8, count.index + 101)
  }
  boot_disk {
    auto_delete = true
    initialize_params {
      size  = var.gce_vm.boot_disk_size
      image = "${var.gce_vm.os_project}/${var.gce_vm.os_family}"
    }
  }
  network_interface {
    subnetwork = google_compute_subnetwork.cks_subnet.self_link
    network_ip = cidrhost(var.vpc_subnet_cidr, count.index + 101)
    access_config {
    }
  }
  can_ip_forward = true
  tags           = ["kubernetes", "k8s", "worker"]
  service_account {
    scopes = ["compute-rw", "storage-full", "cloud-platform", "service-management", "service-control", "logging-write", "monitoring"]
  }
}

resource "google_dns_record_set" "cks_masters" {
  count        = var.master_count
  name         = "cks-master${count.index + 1}.${google_dns_managed_zone.cks_private_zone.dns_name}"
  type         = "A"
  ttl          = 300
  managed_zone = google_dns_managed_zone.cks_private_zone.name
  rrdatas      = [google_compute_instance.cks-masters[count.index].network_interface.0.network_ip]
}

resource "google_dns_record_set" "cks_workers" {
  count        = var.worker_count
  name         = "cks-worker${count.index + 1}.${google_dns_managed_zone.cks_private_zone.dns_name}"
  type         = "A"
  ttl          = 300
  managed_zone = google_dns_managed_zone.cks_private_zone.name
  rrdatas      = [google_compute_instance.cks-workers[count.index].network_interface.0.network_ip]
}

resource "local_file" "ansible_host" {
  content = templatefile("templates/hosts.tpl",
    {
      cks_master = google_compute_instance.cks-masters.*.network_interface.0.access_config.0.nat_ip
      cks_worker = google_compute_instance.cks-workers.*.network_interface.0.access_config.0.nat_ip
    }
  )
  filename = "${path.module}/hosts"
}

resource "local_file" "kubeadm_config" {
  content = templatefile("templates/kubeadm-config.tpl",
    {
      k8s_version          = var.k8s_version
      k8s_pod_cidr         = var.k8s_pod_cidr
      k8s_private_dns_name = trimsuffix(var.gcp_private_dns_zone.dns_name, ".")
      k8s_public_dns_name  = var.gcp_public_dns_zone.enabled ? trimsuffix("cks.${data.google_dns_managed_zone.cks_public_zone.dns_name}", ".") : "cks.kubernetes.local"
      api_public_ip        = google_compute_address.lb_ext_ip.address
    }
  )
  filename = "${path.module}/kubeadm/kubeadm.config"
}

resource "local_file" "cloud_config" {
  content = templatefile("templates/cloud-config.tpl",
    {
      gcp_project = var.gcp_profile.project
    }
  )
  filename = "${path.module}/kubeadm/cloud-config"
}

resource "null_resource" "ansible_playbook_os" {
  depends_on = [
    local_file.ansible_host,
    google_compute_instance.cks-masters,
    google_compute_instance.cks-workers,
  ]
  provisioner "local-exec" {
    command = "ansible-playbook os/main.yaml --extra-vars=\"k8s_ver=$version\""
    environment = {
      version = var.k8s_version
    }
  }
}

resource "null_resource" "ansible_playbook_kubeadm" {
  depends_on = [
    null_resource.ansible_playbook_os,
  ]
  provisioner "local-exec" {
    command = "ansible-playbook kubeadm/main.yaml"
  }
}

resource "null_resource" "ansible_playbook_kubectl" {
  depends_on = [
    null_resource.ansible_playbook_kubeadm,
  ]
  provisioner "local-exec" {
    command = "ansible-playbook kubectl/main.yaml --extra-vars=\"k8s_public_ip=$public_fqdn k8s_private_ip=$private_ip gcp_credential=$gcp_cred\""
    environment = {
      public_fqdn = var.gcp_public_dns_zone.enabled ? trimsuffix("cks.${data.google_dns_managed_zone.cks_public_zone.dns_name}", ".") : google_compute_address.lb_ext_ip.address
      private_ip  = google_compute_instance.cks-masters[0].network_interface.0.network_ip
      gcp_cred = var.gcp_profile.credentials
    }
  }
}

