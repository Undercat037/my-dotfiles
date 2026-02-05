rule = {
  matches = {
    {
      { "device.name", "equals", "alsa_card.pci-0000_01_00.1" }, -- AD107 (HDMI)
    },
  },
  apply_properties = {
    ["priority.driver"] = 100,
    ["priority.session"] = 100,
  },
}

table.insert(alsa_monitor.rules, rule)

rule = {
  matches = {
    {
      { "device.name", "matches", "alsa_card.pci-*" }, -- Ryzen HD Audio
      { "device.name", "!equals", "alsa_card.pci-0000_01_00.1" },
    },
  },
  apply_properties = {
    ["priority.driver"] = 1000,
    ["priority.session"] = 1000,
  },
}

table.insert(alsa_monitor.rules, rule)
