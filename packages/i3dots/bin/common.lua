-- packages/i3dots/bin/common.lua
local common = {}

common.home = os.getenv("HOME")

-- ── Math ──────────────────────────────────────────────────────────────────────

function common.hex_darken(hex)
    local r = tonumber(hex:sub(1, 2), 16)
    local g = tonumber(hex:sub(3, 4), 16)
    local b = tonumber(hex:sub(5, 6), 16)
    return string.format("%02x%02x%02x",
        math.floor(r * 0.65),
        math.floor(g * 0.65),
        math.floor(b * 0.65))
end

-- ── I/O ───────────────────────────────────────────────────────────────────────

function common.path_exists(path)
    local f = io.open(path, "r")
    if f then f:close(); return true end
    return false
end

function common.read_file(path)
    local f = io.open(path, "r")
    if not f then return nil end
    local s = f:read("*a"); f:close()
    return s
end

function common.write_file(path, content)
    local f = io.open(path, "w")
    if f then f:write(content); f:close() end
end

-- ── Color persistence ─────────────────────────────────────────────────────────

function common.resolve_color(color_arg, persist_file)
    local color = color_arg or ""
    if color == "" then
        io.stderr:write("Especifica un color hex o --restore\n")
        return nil
    end
    if color == "--restore" then
        local s = common.read_file(persist_file)
        if not s then return nil end
        return s:gsub("%s+", "")
    end
    if not color:match("^[0-9a-fA-F]%x%x%x%x%x$") then
        io.stderr:write("Color hex inválido: " .. color .. "\n")
        return nil
    end
    common.write_file(persist_file, color)
    return color
end

function common.read_prev_color(persist_file)
    local s = common.read_file(persist_file)
    return s and s:gsub("%s+", "") or nil
end

-- ── Theme discovery ───────────────────────────────────────────────────────────

function common.detect_base_theme(settings_ini, base_file)
    local current_theme = ""
    local s = common.read_file(settings_ini)
    if s then
        -- simpler line-by-line
        for line in s:gmatch("[^\n]+") do
            local val = line:match("^gtk%-icon%-theme%-name%s*=%s*(.*)")
            if val then
                val = val:gsub('^"', ''):gsub('"$', ''):gsub("%s+$", "")
                current_theme = val
                break
            end
        end
    end

    if current_theme == "" then current_theme = "Papirus-Dark" end

    if not current_theme:find("%-Custom") then
        common.write_file(base_file, current_theme)
        return current_theme
    end

    local saved = common.read_file(base_file)
    if saved then
        saved = saved:gsub("%s+", "")
        if saved ~= "" then return saved end
    end
    return "Papirus-Dark"
end

function common.find_theme_dir(name)
    for _, base in ipairs({
        common.home .. "/.icons/",
        common.home .. "/.local/share/icons/",
        "/usr/share/icons/",
    }) do
        local path = base .. name
        if common.path_exists(path .. "/index.theme") then
            return path
        end
    end
    return nil
end

function common.load_theme_module(base_theme)
    local full = base_theme:lower()
    local ok, mod = pcall(require, full)
    if ok then return mod end

    local prefix = base_theme:match("^([^-]*)")
    if prefix then
        prefix = prefix:lower()
        if prefix ~= full then
            local ok2, mod2 = pcall(require, prefix)
            if ok2 then return mod2 end
        end
    end
    return nil
end

-- ── Variant detection ─────────────────────────────────────────────────────────

function common.detect_active_variant(xsettings_path)
    local s = common.read_file(xsettings_path)
    if s then
        local val = s:match('Net/ThemeName%s*"([^"]+)"')
        if val then
            if val:find("%-Custom%-A$") then return "A" end
            if val:find("%-Custom%-B$") then return "B" end
        end
    end
    return "B"  -- sin Custom activo → primer arranque → target será A
end

-- ── Theme cleanup ─────────────────────────────────────────────────────────────

-- Elimina variantes Custom inactivas y backups de otros temas.
-- keep_icon_theme  : e.g. "Papirus-Dark-Custom-A"
-- keep_widget_theme: e.g. "adw-gtk3-dark-Custom-A"
function common.cleanup_old_themes(keep_icon_theme, keep_widget_theme)
    local icon_prefix   = keep_icon_theme   and keep_icon_theme:match("^(.*%-Custom%-)[AB]$")   or keep_icon_theme
    local widget_prefix = keep_widget_theme and keep_widget_theme:match("^(.*%-Custom%-)[AB]$") or keep_widget_theme

    for _, dir in ipairs({ "/dev/shm", common.home .. "/.icons", common.home .. "/.themes" }) do
        local p = io.popen('find ' .. dir .. ' -maxdepth 1 -name "*-Custom*" 2>/dev/null')
        if p then
            for path in p:lines() do
                local name = path:match("([^/]+)$")
                if name then
                    local keep = false
                    if icon_prefix   and name:sub(1, #icon_prefix)   == icon_prefix   then keep = true end
                    if widget_prefix and name:sub(1, #widget_prefix) == widget_prefix then keep = true end
                    if not keep then os.execute("rm -rf " .. path) end
                end
            end
            p:close()
        end
    end
end

-- ── Icon backup ───────────────────────────────────────────────────────────────

function common.check_and_clean_backup(backup_dir, ram_dir, clean_pattern)
    if not clean_pattern then return end
    local p = io.popen('find ' .. backup_dir .. ' -name "' .. clean_pattern .. '" -print -quit 2>/dev/null')
    if p then
        local res = p:read("*a"); p:close()
        if res ~= "" then os.execute("rm -rf " .. ram_dir) end
    end
end

function common.create_backup(original_dir, backup_dir, exclusions, color_regex)
    local excl   = table.concat(exclusions, " ")
    local find_c = 'find -L . -type f -path "*/places/*" ' .. excl
    local grep_c = 'grep -lE "' .. color_regex .. '"'
    local cp_c   = 'xargs cp -a --parents -t ' .. backup_dir .. '/'
    os.execute('cd ' .. original_dir .. ' && ' .. find_c
        .. ' -print0 2>/dev/null | xargs -0 ' .. grep_c
        .. ' 2>/dev/null | ' .. cp_c .. ' 2>/dev/null')
end

function common.is_ram_populated(ram_dir)
    local p = io.popen("find " .. ram_dir .. " -name '*.svg' -print -quit 2>/dev/null")
    if not p then return false end
    local res = p:read("*a"); p:close()
    return res and res ~= ""
end

function common.copy_and_recolor(backup_dir, ram_dir, sed_exprs)
    os.execute("cp -rd --remove-destination " .. backup_dir .. "/. " .. ram_dir .. "/")

    local p = io.popen("find " .. ram_dir .. " -type f -name '*.svg' 2>/dev/null")
    if not p then return end
    for path in p:lines() do
        local s = common.read_file(path)
        if s then
            for _, expr in ipairs(sed_exprs) do
                s = s:gsub(expr[1], expr[2])
            end
            common.write_file(path, s)
        end
    end
    p:close()
end

function common.setup_index_theme(src, dest, custom_theme, base_theme)
    local s = common.read_file(src)
    if not s then
        io.stderr:write("Error abriendo index.theme: " .. src .. "\n")
        return
    end
    s = s:gsub("(Name%s*=%s*)[^\n]*",    "%1" .. custom_theme)
    s = s:gsub("(Inherits%s*=%s*)[^\n]*", "%1" .. base_theme .. ",hicolor")
    common.write_file(dest, s)
end

function common.update_icon_cache(dir)
    os.execute("gtk-update-icon-cache -f -q -t " .. dir .. " 2>/dev/null || true")
end

return common
