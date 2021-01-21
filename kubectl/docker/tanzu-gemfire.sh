
docker login registry.pivotal.io -u xxxx -p xxxxxxxxxxxx
docker pull registry.pivotal.io/tanzu-gemfire-for-kubernetes/gemfire-controller:1.0.0
docker pull registry.pivotal.io/tanzu-gemfire-for-kubernetes/gemfire-k8s:1.0.0
docker image ls
gcloud auth configure-docker
docker tag ec22db0a8ac0 gcr.io/vmware-ysung/tanzu-gemfire-for-kubernetes/gemfire-controller:1.0.0
docker push gcr.io/vmware-ysung/tanzu-gemfire-for-kubernetes/gemfire-controller:1.0.0
docker tag 7bb8fb781003 gcr.io/vmware-ysung/tanzu-gemfire-for-kubernetes/gemfire-k8s:1.0.0
docker push gcr.io/vmware-ysung/tanzu-gemfire-for-kubernetes/gemfire-k8s:1.0.0