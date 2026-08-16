resource "azurerm_storage_share" "fileshare" {
  name                 = var.share_name
  storage_account_name = var.storage_account_name
  quota                = var.quota
}

data "local_file" "files" {
  for_each = fileset(var.local_mount_dir, "**/*")
  filename = "${var.local_mount_dir}/${each.value}"
}

locals {
  normalized_mount_dir = replace(var.local_mount_dir, "\\", "/")
  normalized_files = {
    for f in data.local_file.files :
    f.filename => replace(f.filename, "\\", "/")
  }

  relative_dir_by_file = {
    for original, normalized in local.normalized_files :
    original => (
      replace(dirname(normalized), "\\", "/") == local.normalized_mount_dir
      ? ""
      : trimprefix(replace(dirname(normalized), "\\", "/"), "${local.normalized_mount_dir}/")
    )
  }

  directories = compact(distinct(sort([
    for original, relative_dir in local.relative_dir_by_file :
    relative_dir
    if relative_dir != "" && relative_dir != "."
  ])))

  root_files = {
    for f in data.local_file.files :
    f.filename => f
    if replace(dirname(local.normalized_files[f.filename]), "\\", "/") == local.normalized_mount_dir
  }

  subdir_files = {
    for f in data.local_file.files :
    f.filename => f
    if replace(dirname(local.normalized_files[f.filename]), "\\", "/") != local.normalized_mount_dir
  }
}

resource "azurerm_storage_share_directory" "directories" {
  for_each         = toset(local.directories)
  name             = each.value
  storage_share_id = azurerm_storage_share.fileshare.id
}

resource "azurerm_storage_share_file" "root_files" {
  for_each = local.root_files

  name             = basename(each.value.filename)
  storage_share_id = azurerm_storage_share.fileshare.id
  source           = each.value.filename
  depends_on       = [azurerm_storage_share_directory.directories]
}

resource "azurerm_storage_share_file" "subdir_files" {
  for_each = local.subdir_files

  name             = basename(each.value.filename)
  storage_share_id = azurerm_storage_share.fileshare.id
  source           = each.value.filename
  path             = local.relative_dir_by_file[each.value.filename]
  depends_on       = [azurerm_storage_share_directory.directories]
}


output "share_name" {
  value       = azurerm_storage_share.fileshare.name
  description = "The name of the file share"
}

output "share_id" {
  value       = azurerm_storage_share.fileshare.id
  description = "The ID of the file share"
}