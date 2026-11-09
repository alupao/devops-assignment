variable "ami_id" {
  description = "AMI shared by all five instances."
  type        = string
}

variable "subnet_id" {
  description = "Subnet all five instances are launched into."
  type        = string
}

variable "security_group_ids" {
  description = "Security groups attached to all five instances."
  type        = list(string)
}

variable "instances" {
  description = "Five named instances; the parent module supplies the key-pair names, AMI and network."
  type = map(object({
    instance_type    = string
    root_volume_type = string
    root_volume_size = number
    root_iops        = optional(number)
    key_name         = string
    environment      = string
    owner            = string
    protected        = optional(bool, false)
  }))

  validation {
    condition     = length(var.instances) == 5
    error_message = "Exactly five instances are required."
  }

  validation {
    condition = alltrue([
      for attribute in ["instance_type", "root_volume_type", "root_volume_size", "key_name"] :
      length(distinct([for instance in values(var.instances) : instance[attribute]])) == 5
    ])
    error_message = "Instance types, root volume types, sizes and key pairs must all be distinct."
  }

  validation {
    condition = alltrue([for name, instance in var.instances : try(
      trimspace(name) != "" && trimspace(instance.instance_type) != "" &&
      trimspace(instance.key_name) != "" && trimspace(instance.environment) != "" &&
      trimspace(instance.owner) != "", false
    )])
    error_message = "Names, instance types, key pairs, Environment, and Owner must be nonempty."
  }

  validation {
    condition     = length([for instance in values(var.instances) : instance if instance.protected]) == 1
    error_message = "Exactly one instance must be protected."
  }

  validation {
    condition = alltrue([for instance in values(var.instances) : try(
      contains(["standard", "gp2", "gp3", "io1", "io2"], instance.root_volume_type) &&
      instance.root_volume_size == floor(instance.root_volume_size) &&
      instance.root_volume_size >= (contains(["io1", "io2"], instance.root_volume_type) ? 4 : 1) &&
      instance.root_volume_size <= (instance.root_volume_type == "standard" ? 1024 : 16384), false
    )])
    error_message = "Use a supported boot volume type and an integral size: standard 1–1024 GiB, gp2/gp3 1–16384, io1/io2 4–16384."
  }

  validation {
    condition = alltrue([for instance in values(var.instances) :
      instance.root_volume_type != "io1" ? true : try(
        instance.root_iops == floor(instance.root_iops) && instance.root_iops >= 100 &&
        instance.root_iops <= 64000 && instance.root_iops <= instance.root_volume_size * 50, false
      )
    ])
    error_message = "io1 requires integral IOPS from 100 to 64000, at most 50 IOPS/GiB."
  }

  validation {
    condition = alltrue([for instance in values(var.instances) :
      instance.root_volume_type != "io2" ? true : try(
        instance.root_iops == floor(instance.root_iops) && instance.root_iops >= 100 &&
        instance.root_iops <= 64000 && instance.root_iops <= instance.root_volume_size * 500, false
      )
    ])
    error_message = "io2 requires integral IOPS from 100 to 64000, at most 500 IOPS/GiB (conservative module limits)."
  }

  validation {
    condition = alltrue([for instance in values(var.instances) :
      contains(["io1", "io2"], instance.root_volume_type) || instance.root_iops == null
    ])
    error_message = "Omit root_iops for standard, gp2, and gp3; this module uses their defaults."
  }
}
