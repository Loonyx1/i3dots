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

-- Recolorea o enlaza todos los SVGs simbólicos de un directorio fuente al destino.
-- src_abs: path absoluto de la carpeta con los *-symbolic.svg
-- dst_abs: path absoluto del directorio destino (se crea si no existe)
-- sym_sed: tabla de expresiones { patron, reemplazo } o nil para enlace simbólico
local function recolor_symbolic_dir(src_abs, dst_abs, sym_sed)
    if not common.path_exists(src_abs) then return end
    os.execute("mkdir -p " .. dst_abs)

    local p = io.popen("find " .. src_abs .. " -maxdepth 1 -type f -name '*-symbolic.svg' 2>/dev/null")
    if not p then return end

    local ln_cmds = {}
    for path in p:lines() do
        local file = path:match("([^/]+)$")
        local name = file:match("^(.+)-symbolic%.svg$")
        if name then
            local dst = dst_abs .. "/" .. name .. ".svg"
            if sym_sed then
                local s = common.read_file(path)
                if s then
                    for _, expr in ipairs(sym_sed) do s = s:gsub(expr[1], expr[2]) end
                    common.write_file(dst, s)
                end
            else
                if not common.path_exists(dst) then
                    table.insert(ln_cmds, "ln -sfn " .. path .. " " .. dst)
                end
            end
        end
    end
    p:close()

    if #ln_cmds > 0 then
        os.execute(table.concat(ln_cmds, " && "))
    end
end

local function link_symbolic_icons(original_dir, ram_dir, disk_dir, sym_sed)
    -- Enlazar directorios 'symbolic' del original al ram_dir
    local p = io.popen("find " .. original_dir .. " -maxdepth 2 \\( -type d -o -type l \\) -name 'symbolic' 2>/dev/null")
    if p then
        for path in p:lines() do
            local rel = path:sub(#original_dir + 2)
            local dst = ram_dir .. "/" .. rel
            if not common.path_exists(dst) then
                os.execute("mkdir -p " .. (dst:match("^(.*)/") or "") .. " && ln -sfn " .. path .. " " .. dst)
            end
        end
        p:close()
    end

    local function ensure_disk_link(subdir)
        if not common.path_exists(disk_dir .. "/" .. subdir) and common.path_exists(ram_dir .. "/" .. subdir) then
            os.execute("ln -sfn " .. ram_dir .. "/" .. subdir .. " " .. disk_dir .. "/" .. subdir)
        end
    end

    local pi_sz = { "16x16", "22x22", "24x24" }
    local cd_sz = { "16", "22", "24" }

    for _, s in ipairs(pi_sz) do
        recolor_symbolic_dir(ram_dir .. "/" .. s .. "/symbolic/places",     ram_dir .. "/" .. s .. "/places",     sym_sed)
        recolor_symbolic_dir(ram_dir .. "/" .. s .. "/symbolic/categories", ram_dir .. "/" .. s .. "/categories", sym_sed)
        recolor_symbolic_dir(ram_dir .. "/" .. s .. "/symbolic/devices",    ram_dir .. "/" .. s .. "/devices",    sym_sed)
        recolor_symbolic_dir(ram_dir .. "/" .. s .. "/symbolic/apps",       ram_dir .. "/" .. s .. "/apps",       sym_sed)
        ensure_disk_link(s)
    end

    for _, s in ipairs(cd_sz) do
        recolor_symbolic_dir(ram_dir .. "/places/symbolic",     ram_dir .. "/places/" .. s,     sym_sed)
        recolor_symbolic_dir(ram_dir .. "/devices/symbolic",    ram_dir .. "/devices/" .. s,    sym_sed)
        recolor_symbolic_dir(ram_dir .. "/categories/symbolic", ram_dir .. "/categories/" .. s, sym_sed)
        recolor_symbolic_dir(ram_dir .. "/apps/symbolic",       ram_dir .. "/apps/" .. s,       sym_sed)
        -- Colloid: categories/{size}/*-symbolic.svg directos (no bajo symbolic/)
        recolor_symbolic_dir(original_dir .. "/categories/" .. s, ram_dir .. "/categories/" .. s, sym_sed)
    end

    -- Aliases: nombres de icono que algunos gestores de archivos usan pero Papirus no provee
    local icon_aliases = {
        { "applications-accessories", "applications-utilities" },
        { "preferences-desktop",      "preferences-system" },
    }
    for _, s in ipairs(pi_sz) do
        for _, alias in ipairs(icon_aliases) do
            local src = ram_dir .. "/" .. s .. "/categories/" .. alias[2] .. ".svg"
            local dst = ram_dir .. "/" .. s .. "/categories/" .. alias[1] .. ".svg"
            if common.path_exists(src) and not common.path_exists(dst) then
                os.execute("ln -sfn " .. src .. " " .. dst)
            end
        end
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

    local base_theme   = common.detect_base_theme(settings_ini, base_file)
    local original_dir = common.find_theme_dir(base_theme)
    if not original_dir then
        common.cleanup_old_themes("", "")
        os.exit(0)
    end

    -- Early exit: mismo color ya aplicado en RAM
    local active_variant    = common.detect_active_variant(xsettings_cfg)
    local active_icon_theme = base_theme .. "-Custom"
    if color == prev_color
        and common.is_ram_populated("/dev/shm/" .. active_icon_theme)
        and get_current_icon_theme(settings_ini) == active_icon_theme
    then
        gtk.apply(nil, nil)
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
    local sym_sed    = theme_mod.get_symbolic_sed_expressions and theme_mod.get_symbolic_sed_expressions(color) or nil

    if not common.is_ram_populated(ram_icon_dir) or not common.path_exists(physical_icon_dir .. "/index.theme") then
        os.execute("rm -rf " .. ram_icon_dir .. " " .. physical_icon_dir)
        os.execute("mkdir -p " .. ram_icon_dir .. " " .. physical_icon_dir)
        common.setup_index_theme(original_dir .. "/index.theme",
            physical_icon_dir .. "/index.theme", custom_icon_theme, base_theme)
        link_icon_subdirs(backup_dir, ram_icon_dir, physical_icon_dir)

        -- Clonación rápida (1.8ms) de la estructura de enlaces a la otra variante
        local other_variant  = (target_variant == "A") and "B" or "A"
        local other_ram_dir  = "/dev/shm/" .. base_theme .. "-Custom-" .. other_variant
        local other_phys_dir = common.home .. "/.icons/" .. base_theme .. "-Custom-" .. other_variant
        if not common.path_exists(other_ram_dir) then
            os.execute("cp -rd " .. ram_icon_dir .. " " .. other_ram_dir .. " 2>/dev/null")
            os.execute("mkdir -p " .. common.home .. "/.icons && ln -sfn " .. other_ram_dir .. " " .. other_phys_dir .. " 2>/dev/null")
        end
    end

    -- Actualizar glifos simbólicos de lugares y carpetas en RAM
    link_symbolic_icons(original_dir, ram_icon_dir, physical_icon_dir, sym_sed)

    -- Recolorear las carpetas en RAM
    common.copy_and_recolor(backup_dir, ram_icon_dir, sed_exprs)
    common.update_icon_cache(physical_icon_dir)

    -- ── FASE 3: señalizar iconos GTK listos (Alternar variante A/B para forzar recarga en GTK) ──────────────────────────────────
    gtk.apply(custom_icon_theme, nil)

    -- Liberar SVGs de la variante inactiva en RAM manteniendo su estructura de enlaces simbólicos
    local inactive_ram_dir = "/dev/shm/" .. base_theme .. "-Custom-" .. active_variant
    if common.path_exists(inactive_ram_dir) then
        os.execute("find " .. inactive_ram_dir .. " -type f -name '*.svg' -delete 2>/dev/null")
    end
end

main()
