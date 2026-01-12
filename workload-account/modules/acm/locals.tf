locals {
  subject_alternative_names = concat(
    [
      "*.${var.domain_name}",
      "${var.domain_name}",
    ],
    var.extra_subject_alternative_names
  )
}
