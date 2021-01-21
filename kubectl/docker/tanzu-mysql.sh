docker login registry.pivotal.io -u xxxxxxxxxx -p xxxxxxxxxxxx
docker pull registry.pivotal.io/tanzu-mysql-for-kubernetes/tanzu-mysql-instance:0.1.0
docker tag d11231d90d60 gcr.io/vmware-ysung/tanzu-mysql-for-kubernetes/tanzu-mysql-instance:0.1.0
docker push gcr.io/vmware-ysung/tanzu-mysql-for-kubernetes/tanzu-mysql-instance:0.1.0
docker pull registry.pivotal.io/tanzu-mysql-for-kubernetes/tanzu-mysql-operator:0.1.0
docker tag aea4d9c2fcba gcr.io/vmware-ysung/tanzu-mysql-for-kubernetes/tanzu-mysql-operator:0.1.0
docker push  gcr.io/vmware-ysung/tanzu-mysql-for-kubernetes/tanzu-mysql-operator:0.1.0
helm chart pull registry.pivotal.io/tanzu-mysql-for-kubernetes/tanzu-mysql-operator-chart:0.1.0