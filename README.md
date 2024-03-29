# roks-openshift-ai-da
The repository holds the terraform code for the ROKS OpenShift AI Deployable Architecture

The goal of this Deployable Architecture is to quickly create an environment to get hands on with Red Hat OpenShift AI using a ROKS cluster in IBM Cloud. The DA itself will create a simple 1 zone cluster for the user if desired, or you can pre-create the cluster. The DA will then install the OpenShift AI stack.
<br/><br/>
As mentioned above, the cluster that will be created will be a single zone cluster. It will be created in the "1" zone in the region selected. A new VPC is created with a new default subnet created in the first zone. Attached to that subnet is a public gatway. The cluster is created in this new VPC.
<br/><br/>
You must provide the machine-type of the ROKS cluster worker node. This requires that you choose a machine-type that exists in the first zone in the region you select. For example, if you want to create a cluster with L4 GPUs, you must make sure you select a region that has an L4 GPU flavor in the first zone of the selected region. If for example you select the Toronto MZR, you can execute this command to see the list of flavors available in the first zone in the Toronto MZR:
<br/><br/>
```
ibmcloud ks flavors --provider vpc-gen2 --zone ca-tor-1
```
And you will see that there are 3 L4 flavors in that zone - gx3.16x80.l4, gx3.32x160.2l4, and gx3.64x320.4l4. You would supply one of these as the value for the machine-type input variable and provide ca-tor as the value for the region. Also ensure you understand the cost of 2 of these worker nodes by consulting the IBM Cloud portal.
<br/><br/>
You must also provide the name of an IBM Cloud Object Storage instance if you are creating a cluster. ROKS creates a bucket in this instance. This bucket is the storage that backs the cluster internal registry.
<br/><br/>
You may also pre-create a cluster of your own configuration and simply provide the name of the cluster and the region it resides in. The DA scripts will then just deploy the Red Hat OpenShift AI stack of operators into your existing cluster.
<br/><br/>
This DA can be a bit inconsistent as it relies on the fact that the cluster is in the proper state to repond to the installation of operators. The terraform will wait for the cluster to be ready with the Ingress in a ready state, but things like the OperatorHub and its pods must also be ready. Sometimes the Schematics workspace will fail due to the cluster not quite being ready even though the status says it is. Also, the last step in the installation is an attempt to show the Nvidia GPU Operator and the OpenShift AI operator pod status. These may not quite be done yet but the DA will finish. If the Schematics workspace fails, try running it again before jumping to bug investigation.

## Created Resources
If the user chooses to create a cluster, the following items will get created:
1. A resource group named ai-resource-group
2. A subnet named roks-gpu-subnet-1 in zone 1 of the chosen region in the resource group
3. A public gateway named roks-gpu-gateway-1 attached to the subnet in the resource group
4. A vpc named roks-gpu-vpc containing the above subnet and public gateway in the resource group
5. A single zone ROKS cluster in the created subnet and vpc with the user specified number of workers in the resource group. The cluster does not have logging, monitoring, secrets manager, or encryption attached at all. It will be publicly accessible.

This rest of the Terraform script will deploy the Operators necessary for the Red Hat OpenShift AI functionality to the new or existing ROKS cluster. The following Operators and their corresponding components are deployed.

1. Red Hat Pipelines Operator - Incorporate Tekton pipelines into your AI work
2. Red Hat Node Discovery Feature Operator
    - Node Discovery Feature instance - this instance actually does the work of labeling nodes
3. Nvidia GPU Operator
    - Cluster Policy instance - this instance installs the GPU stack of daemonsets and pods
4. Red Hat OpenShift AI Operator
    - OpenShift AI instance - this instance installs the components

## Required Inputs
This Terraform script works in two ways. You can pre-create your cluster and then use this Terraform to install the Opertors into your existing cluster. Or you can have the Terraform create a simple single zone cluster for you first and then it will apply the operators to that cluster.

## Required IAM access policies
You need the following permissions to run this module.

- IAM Services
  - **Kubernetes** service (to create and access a ROKS cluster)
      - `Administrator` platform access
      - `Manager` service access
  - **VPC Infrastructure** service (to create VPC resources)
      - `Administrator` platform access
      - `Manager` service access
  - **All Account Management** service (to create a resource group)
      - `Administrator` platform access
      - `Manager` service access

## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.3.0, <1.6.0 |
| <a name="requirement_helm"></a> [helm](#requirement\_helm) | >= 2.8.0 |
| <a name="requirement_ibm"></a> [ibm](#requirement\_ibm) | >= 1.59.0 |
| <a name="requirement_kubernetes"></a> [kubernetes](#requirement\_kubernetes) | >= 2.16.1 |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| ibmcloud_api_key | APIkey that's associated with the account to use | `string` | none | yes |
| cluster-name | Name of the target or new IBM Cloud OpenShift Cluster | `string` | none | yes |
| region | IBM Cloud region. Use 'ibmcloud regions' to get the list | `string` | none | yes |
| number-gpu-nodes | The number of GPU nodes expected to be found or to create in the cluster | `number` | none | yes |

### The following inputs are only required if you want Terraform to create a cluster. All below values must be provided if you want Terraform to create a cluster.

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| create-cluster | Set to true if you want a new cluster created. Set to false to use a pre-existing cluster. | `bool` | `false` | no |
| ocp-version | Major.minor version of the OCP cluster to provision | `string` | none | no |
| machine-type | Worker node machine type. Should be a GPU flavor. Use 'ibmcloud ks flavors --zone <zone>' to retrieve the list.| `string` | none | no |
| cos-instance | A pre-existing COS service instance where a bucket will be provisioned to back the ROKS internal registry | `string` | none | mo |

## Sample terraform.tfvars file

**NOTE:** If running Terraform yourself, pass in your `ibmcloud_api_key` in the environment variable `TF_VAR_ibmcloud_api_key`

```
cluster-name = "torgpu"
region = "ca-tor"
number-gpu-nodes = 2
# variables when creating a new cluster
create-cluster = true
ocp-version = "4.14"
machine-type = "gx3.16x80.l4"
cos-instance = "Cloud Object Storage-drs"
```

## How to Verify Your Cluster is Happy
You can run the following commands to check the health of your GPUs and OpenShift AI.

### Test that the GPU nodes were properly labled by the Node Feature Discovery operator
Check for the label `feature.node.kubernetes.io/pci-10de.present` on the GPU nodes.
```
$oc get nodes -L feature.node.kubernetes.io/pci-10de.present

NAME         STATUS   ROLES           AGE    VERSION            PCI-10DE.PRESENT
10.249.0.4   Ready    master,worker   141m   v1.27.10+28ed2d7   true
10.249.0.5   Ready    master,worker   141m   v1.27.10+28ed2d7   true
```

### Test the GPU Operator
Check the status of the pods in the `nvidia-gpu-operator` namespace. For the pods that have multiple versions of the same name, you should see the number of these pods be the same as the number of GPU worker nodes that you have. All of the pods should be `Running` with the exception of the `cuda-validator` pods that should be `Completed`.
```
$oc get pods -n nvidia-gpu-operator

NAME                                       READY   STATUS      RESTARTS   AGE
gpu-feature-discovery-r9hj2                1/1     Running     0          40m
gpu-feature-discovery-rw5l2                1/1     Running     0          40m
gpu-operator-c897f4b64-8xg84               1/1     Running     0          42m
nvidia-container-toolkit-daemonset-b9c9c   1/1     Running     0          40m
nvidia-container-toolkit-daemonset-v5tjk   1/1     Running     0          40m
nvidia-cuda-validator-rfzhr                0/1     Completed   0          37m
nvidia-cuda-validator-spvqg                0/1     Completed   0          35m
nvidia-dcgm-5m6d9                          1/1     Running     0          40m
nvidia-dcgm-exporter-hf5xj                 1/1     Running     0          40m
nvidia-dcgm-exporter-hfrcc                 1/1     Running     0          40m
nvidia-dcgm-fb47j                          1/1     Running     0          40m
nvidia-device-plugin-daemonset-c2bt4       1/1     Running     0          40m
nvidia-device-plugin-daemonset-pnlwg       1/1     Running     0          40m
nvidia-driver-daemonset-nxmjw              1/1     Running     0          41m
nvidia-driver-daemonset-t8jjn              1/1     Running     0          41m
nvidia-node-status-exporter-9dj9k          1/1     Running     0          41m
nvidia-node-status-exporter-t78km          1/1     Running     0          41m
nvidia-operator-validator-5rjk2            1/1     Running     0          40m
nvidia-operator-validator-8t6vc            1/1     Running     0          40m
```

Run these commands to deploy a simple CUDA VectorAdd sample, which adds two vectors together to ensure the GPUs have bootstrapped correctly.
```
$cat << EOF | oc create -f -

apiVersion: v1
kind: Pod
metadata:
  name: cuda-vectoradd
spec:
 restartPolicy: OnFailure
 containers:
 - name: cuda-vectoradd
   image: "nvidia/samples:vectoradd-cuda11.2.1"
   resources:
     limits:
       nvidia.com/gpu: 1
EOF

pod/cuda-vectoradd created

$oc logs cuda-vectoradd

[Vector addition of 50000 elements]
Copy input data from the host memory to the CUDA device
CUDA kernel launch with 196 blocks of 256 threads
Copy output data from the CUDA device to the host memory
Test PASSED
Done

$oc delete pod cuda-vectoradd

pod "cuda-vectoradd" deleted
```

### Check the status of the OpenShift AI pods

Check that the OpenShift AI pods are healthy. All of the pods (with the exception of the deprecated pod) should by `Running`. These pods will also vary if you have enabled other features of OpenShift AI outside of this deployable architecture.

```
$oc get pods -n redhat-ods-applications

NAME                                                              READY   STATUS      RESTARTS   AGE
data-science-pipelines-operator-controller-manager-799b75bmvkch   1/1     Running     0          119m
etcd-65c8cb4797-mvjmh                                             1/1     Running     0          119m
modelmesh-controller-869b44f89c-jv5cp                             1/1     Running     0          119m
modelmesh-controller-869b44f89c-m7txc                             1/1     Running     0          119m
modelmesh-controller-869b44f89c-nfrtp                             1/1     Running     0          119m
notebook-controller-deployment-76bfd4f8cf-mdflr                   1/1     Running     0          119m
odh-model-controller-6498f8b67c-2kmtr                             1/1     Running     0          119m
odh-model-controller-6498f8b67c-4fnzk                             1/1     Running     0          119m
odh-model-controller-6498f8b67c-b9vrb                             1/1     Running     0          119m
odh-notebook-controller-manager-799547f687-p9sgz                  1/1     Running     0          119m
remove-deprecated-monitoring-69rtn                                0/1     Completed   0          119m
rhods-dashboard-8bbc85997-72w5b                                   2/2     Running     0          119m
rhods-dashboard-8bbc85997-9f44t                                   2/2     Running     0          119m
rhods-dashboard-8bbc85997-jkwzl                                   2/2     Running     0          119m
rhods-dashboard-8bbc85997-x2knq                                   2/2     Running     0          119m
rhods-dashboard-8bbc85997-ztksv                                   2/2     Running     0          119m
```
