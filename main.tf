variable "client_id" {
  type = "string"
  
}

provider "azurerm" {
  tenant_id       = "${local.tenant_id}"
  subscription_id = "${local.subscription_id}"
  client_id       = "${local.client_id}"
  client_secret   = "${local.client_secret}"
}

resource "azurerm_resource_group" "vm_resource_group" {
  location = "${local.location}"
  name     = "${local.resource_group_name}"
  
  tags {
    COSTCENTER = "0406"
  }
}

resource "azurerm_network_interface" "nic" {
  name                      = "${local.nic}"
  location                  = "${azurerm_resource_group.vm_resource_group.location}"
  resource_group_name       = "${azurerm_resource_group.vm_resource_group.name}"
  network_security_group_id = "/subscriptions/${local.subscription_id}/resourceGroups/${local.network_resource_group}/providers/Microsoft.Network/networkSecurityGroups/NSG-BlockInet"

  ip_configuration {
    name                          = "ipconfig1"
    subnet_id                     = "${data.azurerm_subnet.lb_subnet.id}"
    private_ip_address_allocation = "dynamic"
  }
}

resource "azurerm_storage_account" "diagstorageaccount" {
  name                     = "${local.diag_sa}"
  resource_group_name      = "${azurerm_resource_group.vm_resource_group.name}"
  location                 = "${azurerm_resource_group.vm_resource_group.location}"
  account_replication_type = "LRS"
  account_tier             = "Standard"
}

resource "azurerm_availability_set" "av_set" {
  name                         = "${local.av_set}"
  location                     = "${azurerm_resource_group.vm_resource_group.location}"
  resource_group_name          = "${azurerm_resource_group.vm_resource_group.name}"
  platform_fault_domain_count  = 2
  platform_update_domain_count = 5
  managed                      = true
}

resource "azurerm_virtual_machine" "vm" {
  name                  = "${local.vm_name}"
  location              = "${azurerm_resource_group.vm_resource_group.location}"
  resource_group_name   = "${azurerm_resource_group.vm_resource_group.name}"
  network_interface_ids = ["${azurerm_network_interface.nic.id}"]
  vm_size               = "Standard_DS1_v2"
  availability_set_id   = "${azurerm_availability_set.av_set.id}"

  storage_os_disk {
    name              = "${local.os_disk}"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }

  storage_data_disk {
    name              = "${local.data_disk}"
    caching           = "ReadOnly"
    create_option     = "Empty"
    managed_disk_type = "Standard_LRS"
    disk_size_gb      = 10
    lun               = 0
  }

  storage_image_reference {
    id = "${data.azurerm_image.custom.id}"
  }

  os_profile {
    computer_name  = "${local.vm_name}"
    admin_username = "${local.user_name}"
    admin_password = "${local.password}"
  }
  os_profile_linux_config {
    disable_password_authentication = false
  }
  boot_diagnostics {
    enabled     = "true"
    storage_uri = "${azurerm_storage_account.diagstorageaccount.primary_blob_endpoint}"
  }
  tags {
    AUTOMATION = "AutomationAccount:AzureAutomate_AutomationAsset:Schedules_AutoStart:n_AutoStop:y+weekdays@2000+sat@2000+sun@2000"
    COSTCENTER = "0406"
    DRTIER     = "Tier6"
    RUCODE     = "VPR006"
    SCHDBYPASS = "N"
    SLA        = "Bronze"
  }
}
