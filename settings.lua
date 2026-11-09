data:extend({
  {
    type = "string-setting",
    name = "wp-tfar-mode",
    setting_type = "runtime-global",
    default_value = "pickup",
    allowed_values = {"pickup", "dodge"},
    order = "a"
  },
  {
    type = "bool-setting",
    name = "wp-tfar-message",
    setting_type = "runtime-per-user",
    default_value = true,
    order = "b"
  }
})
