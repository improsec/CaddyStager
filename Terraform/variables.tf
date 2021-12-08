#NFP Home ranges
variable OwnRange {
  type        = string
  default     = "X.X.X.X/24"
  description = "Own IP"
}

#OS Variables
variable OSPublisherUbuntu {
  type        = string
  default     = "canonical"
}

variable OSSKUUbuntu20 {
  type        = string
  default     = "20_04-lts"
}

variable OSOfferUbuntu20 {
  type        = string
  default     = "0001-com-ubuntu-server-focal"
}

variable OSVersion {
  type        = string
  default     = "latest"
}

#Azure Variables
variable AzureLocationWE {
  type        = string
  default     = "West Europe"
}

variable AzureLocationNE {
  type        = string
  default     = "North Europe"
}


variable AzureStorageAccountTier {
  type        = string
  default     = "Standard"
}

variable AzureStorageAccountReplicationType {
  type        = string
  default     = "LRS"
}

#VM Variables
variable VMSizeDS1v2 {
  type        = string
  default     = "Standard_DS1_v2"
}
variable VMSizeDS2v3 {
  type        = string
  default     = "Standard_DS2_v3"
}
variable VMSizeB1ms {
  type        = string
  default     = "Standard_B1ms"
}
variable VMDiskCaching {
  type        = string
  default     = "ReadWrite"
}
variable VMDiskStorageAccountType {
  type        = string
  default     = "Premium_LRS"
}

#Users
variable CobaltUsername {
    default = "cobalt"
    type    = string
}

variable CaddyUsername {
    default = "caddy"
    type    = string
}
