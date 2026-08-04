--[[ Draw — competition single row ]]

local theme = require("common.theme")
local images = require("common.images")
local layout = require("common.layout")
local profile = require("common.api.profile")
local display_style = require("common.display_style")
local shared = require("common.draw.shared")
local helpers = require("common.draw.competition.helpers")
local card = require("common.draw.competition.card")
local status = require("common.draw.competition.status")
local time_block = require("common.draw.competition.time_block")

local M = {}

local AVATAR_ROW = 36
local TIER_ROW = 20

function M.draw_row(origin, entry, opts)
    theme.ensure_fonts()
    opts = opts or {}
    local row_h = opts.row_height or layout.ROW_H
    local content_w = opts.content_width or 200
    local row_id = opts.row_id or ("row_" .. tostring(entry.rank))
    local avatar_sz = math.min(opts.avatar_size or AVATAR_ROW, row_h - 2)
    local tier_sz = math.max(10, math.min(opts.tier_size or TIER_ROW, avatar_sz * 0.48))
    local name_fs = opts.name_fs or 13
    local car_fs = opts.car_fs or name_fs
    local rank_label_fs = opts.rank_label_fs or math.max(8, name_fs - 2)
    local gap = opts.text_gap or 3
    local line_gap = opts.text_line_gap or 1
    local row_alpha = opts.alpha or 1
    local row_size = vec2(content_w, row_h)
    local status_col_w = opts.status_col_w or 26
    local status_gap = opts.status_gap or 2
    local avatar_col_w = opts.avatar_col_w or (avatar_sz + 2)
    local avatar_identity_gap = opts.avatar_identity_gap or 8
    local time_col_w = opts.time_col_w or 108
    local inner_pad = opts.card_inner_pad or 4
    local identity_w = opts.identity_w or 80
    local border_style = opts.border_style or "gray"
    local card_radius = opts.card_radius or 8

    local is_self = entry.is_self == true
    local slot_index = opts.slot_index
    if slot_index == nil then
        slot_index = is_self and 1 or 0
    end

    if opts.no_input ~= true then
        ui.setCursor(origin)
        ui.invisibleButton(row_id, row_size)
    end

    local text_alpha = row_alpha
    card.draw_card(origin, row_size, text_alpha, card_radius)

    local cy = origin.y + row_h * 0.5
    local content_x = origin.x + inner_pad

    status.draw_status(origin, row_h, slot_index, is_self, {
        status_col_w = status_col_w,
        status_fs = opts.status_fs,
        you_fs = opts.you_fs,
        arrow_fs = opts.arrow_fs,
        card_inner_pad = inner_pad,
        alpha = text_alpha,
    })

    local avatar_x = content_x + status_col_w + status_gap
    shared.avatar_with_tier(
        vec2(avatar_x, cy - avatar_sz * 0.5),
        images.resolve_url(entry.name, entry.avatar_url),
        avatar_sz,
        profile.tier_for_display(entry),
        helpers.avatar_ring(slot_index, is_self, border_style),
        tier_sz,
        entry.frame_url
    )

    local identity_x = avatar_x + avatar_col_w + avatar_identity_gap
    local rank_text = "#" .. tostring(entry.rank or "?")
    local rank_color = is_self and theme.colors.accent or theme.colors.muted
    rank_color = helpers.text_color(rank_color, text_alpha)

    local name_text = theme.format_display_name(entry.display_name or entry.name)
    local car_text = theme.format_car_label(entry.car_name, entry.car_id)
    local name_col = helpers.text_color(theme.colors.white, text_alpha)
    local car_col = helpers.text_color(theme.colors.muted, text_alpha)

    name_text, name_fs = display_style.truncate_name(entry.display_style, name_text, name_fs, identity_w)

    ui.pushDWriteFont(theme.fonts.medium)
    car_text, car_fs = shared.truncate_text(car_text, theme.fonts.medium, car_fs, identity_w)
    ui.popDWriteFont()

    local text_block_h = rank_label_fs + 3 + name_fs + line_gap + car_fs
    local text_top = cy - text_block_h * 0.5

    ui.pushDWriteFont(theme.fonts.medium)
    ui.dwriteDrawText(rank_text, rank_label_fs, vec2(identity_x, text_top), rank_color)
    ui.popDWriteFont()

    display_style.draw_styled_name(entry.display_style, name_text, vec2(identity_x, text_top + rank_label_fs + 3), name_fs, name_col)

    ui.pushDWriteFont(theme.fonts.medium)
    ui.dwriteDrawText(
        car_text, car_fs,
        vec2(identity_x, text_top + rank_label_fs + 3 + name_fs + line_gap),
        car_col
    )
    ui.popDWriteFont()

    local time_x = origin.x + content_w - time_col_w - inner_pad
    local identity_right = identity_x + identity_w
    local sep_x = (identity_right + time_x) * 0.5
    local sep_inset = math.max(6, row_h * 0.14)
    ui.drawLine(
        vec2(sep_x, origin.y + sep_inset),
        vec2(sep_x, origin.y + row_h - sep_inset),
        rgbm(1, 1, 1, 0.18 * text_alpha),
        1
    )

    time_block.draw_time_block(vec2(time_x, origin.y), entry, {
        time_col_w = time_col_w,
        row_height = row_h,
        best_lap_label_fs = opts.best_lap_label_fs,
        time_fs = opts.time_fs,
        delta_fs = opts.delta_fs,
        delta_suffix_fs = opts.delta_suffix_fs,
        trailing_pad = opts.trailing_pad,
        alpha = text_alpha,
        player_lap_ms = opts.player_lap_ms,
    })
end

return M
