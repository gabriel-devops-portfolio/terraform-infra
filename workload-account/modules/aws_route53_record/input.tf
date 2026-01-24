
variable "zone_id" {
  description = "(Required) The ID of the hosted zone to contain this record."
  default     = ""
}

variable "name" {
  description = "(Required) The name of the record."
  default     = ""
}

variable "type" {
  description = "(Required) The record type. Valid values are A, AAAA, CAA, CNAME, DS, MX, NAPTR, NS, PTR, SOA, SPF, SRV and TXT."
  default     = "A"
}

variable "ttl" {
  description = "(Required for non-alias records) The TTL of the record."
  default     = "5"
}

variable "records" {
  type        = list(string)
  description = "(Required for non-alias records) A string list of records."
  default     = []
}
