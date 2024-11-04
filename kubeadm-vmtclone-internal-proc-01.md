### kubeadm-vmt-clone  
#### Maintain/use VMWare VMs, VM templates to automate provisioning of VMs prepped for Kubernetes cluster provisioning    
#### Resources prep  
-  Procedures review full documentation, diagrams  
   kubeadm-vmtclone-deploy-proc-rvw-01.docx  
-  DevEnv clients  
   - New-VMK8sClusterNode1.ps1  
     PowerShell script  
   - [DevEnv]_vcentercredentials.xml  
     Secure, local only credentials file  
   - VMK8sOperationsConfig.json  
     Runtime configuration parameters, settings  
   - K8sNodeRequestList_or-cluster0X.txt 
     K8s node roles, naming, IP addresses  
-  vSphere vCenter  
   - OS image  
     Ubuntu live server ISO staged in sources datastore  
#### Brief procedures  
##### From vSphere vCenter    
-  Create, configure VM vmPreK8sUbuntu_20_04_6_v1_0  
   Ubuntu VM  
   OS prepped for k8s usage  
   No k8s components installed  
   VM notes refer to prep document  
-  Clone, configure VM vmK8sClusterNodeUbuntu_20_04_6_v1_0  
   Ubuntu VM  
   Clone to VM from VM vmPreK8sUbuntu_20_04_6_v1_0    
   k8s components installed  
   - containerd, kubelet, kubeadm, kubectl 
   VM template notes refer to prep document  
-  Clone VM vmK8sClusterNodeUbuntu_20_04_6_v1_0 to VM template vmtK8sClusterNodeUbuntu_20_04_6_v1_0  
   Ubuntu VM template  
   -  Used as basis for automated K8s cluster node provisioning  
-  Create VM customization specification UbuntuK8sClusterNodeSpec  
   VM name, NIC, DNS settings  
##### From DevEnv client    
-  Run New-VMK8sClusterNode1.ps1 script  
   K8s node VMs created  

#### Next steps  
