#!/usr/bin/env lua

-- Resolver directorio del script para require() relativo
local script_path = debug.getinfo(1).source:match("@(.*)")
if script_path then
    local h = io.popen("readlink -f " .. script_path .. " 2>/dev/null")
    if h then
        local real = h:read("*a"):gsub("%s+$", ""); h:close()
        local dir  = real:match("(.*)/")
        if dir then package.path = dir .. "/?.lua;" .. package.path end
    end
end

local common = require("common")
local gtk    = require("gtk")
local qt     = require("qt")

-- ── Helpers locales (no son utilidades genéricas) ─────────────────────────────

local function read_ini_value(settings_ini, key)
    local s = common.read_file(settings_ini)
    if not s then return nil end
    for line in s:gmatch("[^\n]+") do
        local val = line:match("^" .. key .. "%s*=%s*(.*)")
        if val then return val:gsub('^"', ''):gsub('"$', ''):gsub("%s+$", "") end
    end
    return nil
end

local function get_current_icon_theme(settings_ini)
    return read_ini_value(settings_ini, "gtk%-icon%-theme%-name") or ""
end

local function get_widget_base(settings_ini)
    local v = read_ini_value(settings_ini, "gtk%-theme%-name") or "adw-gtk3-dark"
    return v:gsub("%-Custom%-[AB]$", ""):gsub("%-Custom$", "")
end

local function link_icon_subdirs(backup_dir, ram_dir, disk_dir)
    os.execute("mkdir -p " .. ram_dir)
    local p = io.popen("find " .. backup_dir .. " -maxdepth 1 -mindepth 1 -type d 2>/dev/null")
    if p then
        for line in p:lines() do
            local name = line:match("([^/]+)$")
            if name then
                os.execute("mkdir -p "  .. ram_dir  .. "/" .. name)
                os.execute("ln -sfn "   .. ram_dir  .. "/" .. name .. " " .. disk_dir .. "/" .. name)
            end
        end
        p:close()
    end
end

-- ── Main ──────────────────────────────────────────────────────────────────────

local function main()
    local persist_file  = common.home .. "/.config/i3/last_icon_color"
    local settings_ini  = common.home .. "/.config/gtk-3.0/settings.ini"
    local base_file     = common.home .. "/.config/i3/icon_theme.base"
    local xsettings_cfg = common.home .. "/.config/xsettingsd/xsettingsd.conf"

    local prev_color = common.read_prev_color(persist_file)
    local color      = common.resolve_color(arg[1], persist_file)
    if not color then os.exit(1) end

    local base_theme   = common.detect_base_theme(settings_ini, base_file)
    local original_dir = common.find_theme_dir(base_theme)
    if not original_dir then
        common.cleanup_old_themes("", "")
        os.exit(0)
    end

    -- Early exit: mismo color ya aplicado en RAM
    local active_variant    = common.detect_active_variant(xsettings_cfg)
    local active_icon_theme = base_theme .. "-Custom-" .. active_variant
    if color == prev_color
        and common.is_ram_populated("/dev/shm/" .. active_icon_theme)
        and get_current_icon_theme(settings_ini) == active_icon_theme
    then
        os.exit(0)
    end

    local theme_mod = common.load_theme_module(base_theme)
    if not theme_mod then
        common.cleanup_old_themes("", "")
        gtk.apply(base_theme, "adw-gtk3-dark")
        qt.apply(base_theme)
        os.exit(0)
    end

    local target_variant      = (active_variant == "A") and "B" or "A"
    local widget_base         = get_widget_base(settings_ini)
    local custom_icon_theme   = base_theme  .. "-Custom-" .. target_variant
    local custom_widget_theme = widget_base .. "-Custom-" .. target_variant
    local ram_icon_dir        = "/dev/shm/" .. custom_icon_theme
    local backup_dir          = "/dev/shm/" .. base_theme .. "-Custom-backup"
    local physical_icon_dir   = common.home .. "/.icons/" .. custom_icon_theme

    -- ── FASE 1: widget theme y señal Qt inmediatos ───────────────────────────
    common.cleanup_old_themes(custom_icon_theme, custom_widget_theme)
    gtk.setup_theme_variant(widget_base, target_variant)
    gtk.apply(nil, custom_widget_theme)
    qt.apply(custom_icon_theme)

    -- ── FASE 2: backup + recoloreo de SVGs ───────────────────────────────────
    common.check_and_clean_backup(backup_dir, ram_icon_dir, theme_mod.backup_clean_pattern)
    if not common.path_exists(backup_dir) then
        os.execute("mkdir -p " .. backup_dir)
        common.create_backup(original_dir, backup_dir, theme_mod.find_exclusions, theme_mod.color_regex)
    end

    local dark_color = common.hex_darken(color)
    local sed_exprs  = theme_mod.get_sed_expressions(color, dark_color)

    if not common.path_exists(physical_icon_dir .. "/icon-theme.cache") then
        -- Primera vez: crear estructura en disco + enlaces a RAM
        os.execute("rm -rf " .. physical_icon_dir)
        os.execute("mkdir -p " .. physical_icon_dir)
        common.setup_index_theme(original_dir .. "/index.theme",
            physical_icon_dir .. "/index.theme", custom_icon_theme, base_theme)
        link_icon_subdirs(backup_dir, ram_icon_dir, physical_icon_dir)
        common.copy_and_recolor(backup_dir, ram_icon_dir, sed_exprs)
        common.update_icon_cache(physical_icon_dir)
    else
        -- Subsiguientes: solo repoblar RAM si es necesario
        if not common.is_ram_populated(ram_icon_dir) or color ~= prev_color then
            os.execute("rm -rf " .. ram_icon_dir)
            os.execute("mkdir -p " .. ram_icon_dir)
            common.copy_and_recolor(backup_dir, ram_icon_dir, sed_exprs)
        end
    end

    -- ── FASE 3: señalizar iconos GTK listos ──────────────────────────────────
    gtk.apply(custom_icon_theme, nil)

    -- Liberar RAM de variante de icono inactiva
    -- (widget theme vive en disco, no en RAM)
    os.execute("rm -rf /dev/shm/" .. base_theme  .. "-Custom-" .. active_variant)
end

main()
