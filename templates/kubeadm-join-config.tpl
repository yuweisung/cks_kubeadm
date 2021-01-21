apiVersion: kubeadm.k8s.io/v1beta2
kind: JoinConfiguration
discovery:
  bootstrapToken:
    apiServerEndpoint: ${master1_ip}:6443
    token: medium.howtok5678songce
    unsafeSkipCAVerification: true
nodeRegistration:
  criSocket: "/var/run/containerd/containerd.sock"
  kubeletExtraArgs:
    cloud-provider: "gce"
  taints: []