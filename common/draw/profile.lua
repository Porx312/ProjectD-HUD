--[[ Draw — profile widget ]]

local theme = require("common.theme")
local layout = require("common.layout")
local profile = require("common.api.profile")
local display_style = require("common.display_style")
local images = require("common.images")
local shared = require("common.draw.shared")

local M = {}

local function profile_name_text(entry)
    return theme.format_display_name(entry.display_name or entry.name)
end

local function profile_car_name(entry)
    return theme.format_car_label(entry.car_name, entry.car_id)
end

local function profile_metrics_from_opts(opts)
    if opts.metrics ~= nil then return opts.metrics end
    local panel_size = opts.panel_size or layout.SIZE.profile
    return layout.profile_metrics(panel_size)
end

local function measure_text_column(entry, opts, m)
    local name_text = profile_name_text(entry)
    local car_name = profile_car_name(entry)
    local rank_str = entry.rank ~= nil and ("#" .. tostring(entry.rank) .. " ") or ""
    local car_mid = car_name .. " - "
    local time_str = theme.format_lap(entry.lap_ms or entry.last_lap_ms or entry.best_lap_ms)

    local name_sz = display_style.measure_styled_name(entry.display_style, name_text, m.name_fs)
    name_sz = select(1, name_sz) or vec2(0, m.name_fs)
    local sub_sz = shared.measure_dwrite(theme.fonts.medium, rank_str .. car_mid .. time_str, m.sub_fs)
    local tier_w = math.max(14, m.tier) + m.name_tier_gap
    local name_row_w = name_sz.x + tier_w
    local text_w = math.max(name_row_w, sub_sz.x)
    local text_h = name_sz.y + m.line_gap + sub_sz.y

    return text_w, text_h, name_text, rank_str, car_mid, time_str, name_sz, sub_sz
end

local function blend_toward_accent(base, pulse)
    if pulse == nil or pulse <= 0 then return base end
    local h = theme.colors.accent
    local t = pulse * pulse
    return rgbm(
        base.r + (h.r - base.r) * t,
        base.g + (h.g - base.g) * t,
        base.b + (h.b - base.b) * t,
        base.mult
    )
end

function M.profile_card(panel_o, panel_size, entry, opts)
    theme.ensure_fonts()
    opts = opts or {}
    local m = profile_metrics_from_opts(opts)
    local url = images.resolve_url(entry.name, entry.avatar_url)
    local pad = layout.CARD_EDGE_PAD
    local hl = opts.highlights or {}

    local text_w, text_h, name_text, rank_str, car_mid, time_str, name_sz, sub_sz =
        measure_text_column(entry, opts, m)

    local avatar_pos = vec2(panel_o.x + pad, panel_o.y + pad + layout.AVATAR_Y_EXTRA)
    local tx = panel_o.x + pad + m.avatar + m.avatar_gap
    local text_y = panel_o.y + (panel_size.y - text_h) * 0.5

    shared.avatar_with_frame(avatar_pos, url, entry.frame_url, m.avatar)

    display_style.draw_styled_name(entry.display_style, name_text, vec2(tx, text_y), m.name_fs)

    local tier_n = profile.tier_for_display(entry)
    local tier_x = tx + name_sz.x + m.name_tier_gap
    local name_center_y = text_y + name_sz.y * 0.5
    local tier_y = name_center_y - m.tier * 0.5
    local tier_sz = math.max(14, m.tier)

    if (hl.tier or 0) > 0 then
        local pad_h = 2
        ui.drawRectFilled(
            vec2(tier_x - pad_h, tier_y - pad_h),
            vec2(tier_x + tier_sz + pad_h, tier_y + tier_sz + pad_h),
            rgbm(0.35, 0.78, 1.0, 0.18 * hl.tier),
            3,
            layout.corners_all()
        )
    end
    shared.tier_badge(vec2(tier_x, tier_y), tier_n, tier_sz)

    local sub_y = text_y + name_sz.y + m.line_gap
    local sub_x = tx

    ui.pushDWriteFont(theme.fonts.medium)
    if rank_str ~= "" then
        ui.dwriteDrawText(rank_str, m.sub_fs, vec2(sub_x, sub_y), blend_toward_accent(theme.colors.white, hl.rank))
        sub_x = sub_x + shared.measure_text(theme.fonts.medium, rank_str, m.sub_fs)
    end
    ui.dwriteDrawText(car_mid, m.sub_fs, vec2(sub_x, sub_y), theme.colors.white)
    sub_x = sub_x + shared.measure_text(theme.fonts.medium, car_mid, m.sub_fs)
    ui.dwriteDrawText(time_str, m.sub_fs, vec2(sub_x, sub_y), blend_toward_accent(theme.colors.accent, hl.time))
    sub_x = sub_x + shared.measure_text(theme.fonts.medium, time_str, m.sub_fs)
    if images.draw_input_icon(
        vec2(sub_x + 4, sub_y + (m.sub_fs - 14) * 0.5),
        entry.input_type,
        math.max(12, math.min(14, m.sub_fs)),
        theme.colors.muted
    ) then
        sub_x = sub_x + 18
    end
    ui.popDWriteFont()
end

function M.profile_block(win_origin, win_size, entry, extra)
    extra = extra or {}
    local po, ps = layout.panel_fit(win_size)
    local panel_o = win_origin + po
    local opts = {
        show_rank_on_car = true,
        metrics = layout.profile_metrics(ps),
        highlights = extra.highlights,
    }
    M.profile_card(panel_o, ps, entry, opts)
end

return M
