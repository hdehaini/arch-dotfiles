-- Settings that only apply to the machine named "nebula". hyprland.lua
-- loads hosts/<hostname>.lua; a machine without a file just gets the
-- automatic defaults, so nothing here is needed for a new install.
--
-- Other machines get their own file automatically (bootstrap.sh creates
-- it, the first login fills in the screens; `<hostname> monitors save`
-- refreshes it). Every field is optional.

return {
    -- Monitors (same fields as hl.monitor; names from `hyprctl monitors`).
    -- The ORDER decides which block of workspace IDs each monitor gets
    -- (1st: 1-10, 2nd: 11-20, ...). SUPER+1..0 always means "workspace
    -- 1..10 on this monitor", so the order only changes internal IDs.
    -- Screens not listed here are set up automatically.
    -- Main (DP-3, 240Hz) in the middle, a 60Hz monitor on each side, and
    -- the 4K TV above the main one. The TV uses scale 2 (logical 1920x1080,
    -- so it sits exactly above DP-3 at y=-1080): text is readable from the
    -- couch, at the cost of a slightly softer wallpaper than native 4K.
    monitors = {
        -- monitors:begin
        { output = "DP-3", mode = "1920x1080@240", position = "0x0", scale = 1 },  -- Acer Technologies ED270 X
        { output = "HDMI-A-2", mode = "1920x1080@60", position = "1920x0", scale = 1 },  -- Samsung Electric Company S24E510C
        { output = "DP-2", mode = "1920x1080@60", position = "-1920x0", scale = 1 },  -- HP Inc. HP E24 G4
        { output = "HDMI-A-1", mode = "3840x2160@60", position = "0x-1080", scale = 2 },  -- RKU 100097811
        -- monitors:end
    },

    -- Environment variables only this machine needs.
    env = {
        -- Two GPUs (Radeon 610M in the CPU + RX 6700): run apps on the RX 6700.
        DRI_PRIME = "pci-0000_03_00_0",
    },

    -- Commands to run once at login, after the shared autostart.
    startup = {},

    -- Not handled here, but part of this machine's setup (outside the repo):
    --   /etc/systemd/system/force-yuv420.service forces YUV 4:2:0 on the TV
    --   (HDMI-A-1) as a kernel 7.2 amdgpu workaround:
    --     ExecStart=/bin/sh -c 'echo 1 > /sys/kernel/debug/dri/0000:03:00.0/HDMI-A-1/force_yuv420_output'
}
