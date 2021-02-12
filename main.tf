resource "null_resource" "ansible_playbook_os" {

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
    command = "ansible-playbook kubectl/main.yaml"
  }
}