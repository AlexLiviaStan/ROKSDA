variable "ibmcloud_api_key" {
  description = "APIkey that's associated with the account to use"
  type        = string
  sensitive   = true
  default     = null
}

variable "cluster-name" {
  type        = string
  description = "Name of the target or new IBM Cloud OpenShift Cluster"
}

variable "region" {
  type        = string
  description = "IBM Cloud region. Use 'ibmcloud regions' to get the list"
  validation {
    condition = anytrue([
      var.ocp_version == "au_syd",
      var.ocp_version == "br-sao",
      var.ocp_version == "ca-tor",
      var.ocp_version == "eu-de",
      var.ocp_version == "eu-es",
      var.ocp_version == "eu-gb",
      var.ocp_version == "jp-osa",
      var.ocp_version == "jp-tok",
      var.ocp_version == "us-east",
      var.ocp_version == "us-south"
    ])
    error_message = "The specified region is not one of the validated versions."
  }
}

variable "number-gpu-nodes" {
  type        = number
  description = "The number of GPU nodes expected to be found or to create in the cluster"
  default     = 2
}

variable "create-cluster" {
  type        = bool
  description = "If true, create the cluster"
  default     = false
}

variable "ocp-version" {
  type        = string
  description = "Major.minor version of the OCP cluster to provision"
  validation {
    condition = anytrue([
      var.ocp_version == "4.12",
      var.ocp_version == "4.13",
      var.ocp_version == "4.14"
    ])
    error_message = "The specified ocp_version is not one of the validated versions."
  }
}

variable "machine-type" {
  type        = string
  description = "Worker node machine type. Should be a GPU flavor. Use 'ibmcloud ks flavors --zone <zone>' to retrieve the list."
  default     = null
}

variable "cos-instance" {
  type        = string
  description = "COS instance where a bucket will be created to back ROKS internal registry"
  default     = null
}
