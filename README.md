# terraform-azurerm-application-gateway
Terraform module to create Azure Application gateway


Name | Description
---- | -----------
`dh_group`|The DH group used in IKE phase 1 for initial SA. Valid options are `DHGroup1`, `DHGroup14`, `DHGroup2`, `DHGroup2048`, `DHGroup24`, `ECP256`, `ECP384`, or `None`
`ike_encryption`|The IKE encryption algorithm. Valid options are `AES128`, `AES192`, `AES256`, `DES`, or `DES3`
`ike_integrity`|The IKE integrity algorithm. Valid options are `MD5`, `SHA1`, `SHA256`, or `SHA384`
`ipsec_encryption`|The IPSec encryption algorithm. Valid options are `AES128`, `AES192`, `AES256`, `DES`, `DES3`, `GCMAES128`, `GCMAES192`, `GCMAES256`, or `None`
`ipsec_integrity`|The IPSec integrity algorithm. Valid options are `GCMAES128`, `GCMAES192`, `GCMAES256`, `MD5`, `SHA1`, or `SHA256`
`pfs_group`|The DH group used in IKE phase 2 for new child SA. Valid options are `ECP256`, `ECP384`, `PFS1`, `PFS2`, `PFS2048`, `PFS24`, or `None`
`sa_datasize`|The IPSec SA payload size in KB. Must be at least `1024` KB. Defaults to `102400000` KB.
`sa_lifetime`|The IPSec SA lifetime in seconds. Must be at least `300` seconds. Defaults to `27000` seconds
| <td colspan=2> This is middle of table 12254458888888888888888888 |
`sa_datasize`|The IPSec SA payload size in KB. Must be at least `1024` KB. Defaults to `102400000` KB.
