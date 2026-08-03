--[[ Layout — leaderboard (legacy Top 10) ]]

local M = {}

M.LEADERBOARD_NATIVE = vec2(1566, 2720)
M.LEADERBOARD_ASPECT = M.LEADERBOARD_NATIVE.x / M.LEADERBOARD_NATIVE.y

M.LEADERBOARD_DESIGN = {
    header_h = 204,
    header_pad_x = 48,
    header_gap = 20,
    title = "COMPETITION",
    title_fs = 108,
    meta_fs = 92,
    sep_h = 2,
    sep_margin_x = 40,
    sep_margin_bottom = 14,
}

function M.leaderboard_fit(win_size)
    local aspect = M.LEADERBOARD_ASPECT
    local draw_w, draw_h

    if win_size.x / win_size.y > aspect then
        draw_h = win_size.y
        draw_w = draw_h * aspect
    else
        draw_w = win_size.x
        draw_h = draw_w / aspect
    end

    local ox = (win_size.x - draw_w) * 0.5
    local oy = (win_size.y - draw_h) * 0.5
    return vec2(ox, oy), vec2(draw_w, draw_h)
end

function M.leaderboard_scale(panel_size)
    return panel_size.x / M.LEADERBOARD_NATIVE.x
end

function M.leaderboard_header_metrics(panel_size)
    local s = M.leaderboard_scale(panel_size)
    local d = M.LEADERBOARD_DESIGN
    return {
        header_h = d.header_h * s,
        header_pad_x = d.header_pad_x * s,
        header_gap = d.header_gap * s,
        title = d.title,
        title_fs = d.title_fs * s,
        meta_fs = d.meta_fs * s,
        sep_h = math.max(1, d.sep_h * s),
        sep_margin_x = d.sep_margin_x * s,
        sep_margin_bottom = d.sep_margin_bottom * s,
    }
end

return M
