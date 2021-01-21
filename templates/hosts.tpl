[master]
%{ for index,ip in cks_master ~}
master-${index+1} ansible_host=${ip}
%{ endfor ~}
[worker]
%{ for index,ip in cks_worker ~}
worker-${index+1} ansible_host=${ip}
%{ endfor ~}