local M = {}

local r = require("regex")

function M.opt(opts)
    -- オプション
    local opts = opts or {}
    local marks = opts.marks or "aotnsiu-kwr,dhvcef.yl;gmjxzbpqAOTNSIU=KWR<DHVCEF>YL+GMJXZBPQ"
    local hl_group = opts.hl_group or "special"
    local ignore = opts.ignore or "/s"

    local mark_table = vim.split(marks,"")
    local name_space = vim.api.nvim_create_namespace("jump_cursor")

    local N = {} -- "M" の次の文字

    -- ジャンプできる位置のリストを取得する
    function N.get_pos_table(str)
        local t = {}

        local function loop(line,column,str)
            if str == "" then
                return
            end

            local s,e = r.find(".")(str) -- string.findはマルチバイトに対応していない
            local char = string.sub(str,s,e)
            local rest = string.sub(str,e + 1)

            local char_byte = string.len(char) -- バイト数を取得する

            if char == "\n" then
                loop(line + 1,0,rest)
            else
                if not r.is(ignore)(char) then -- ジャンプできる文字であれば
                    table.insert(t,{ line, column }) -- その文字の位置(行と列)を格納
                end

                loop(line,column + char_byte,rest)
            end
        end

        loop(1,0,str)

        return t
    end

    function N.select_position(buf,start_line,end_line)
        local buf_content = table.concat(vim.api.nvim_buf_get_lines(buf,start_line,end_line,false),"\n")
        local pos_table = N.get_pos_table(buf_content)

        -- マーク数の最適化 最初の塗り潰しと2番目の塗り潰しでマークが同じ数になるようにする
        local mark_len = math.ceil(math.sqrt(#pos_table)) -- マークの数を決める
        marks = string.sub(marks,1,mark_len) -- その数に切り詰める

        local function loop(pos_idx)
            local mark = mark_table[math.floor((pos_idx - 1)/mark_len) + 1]

            if mark == nil then
                return
            end

            local pos = pos_table[pos_idx]
            vim.api.nvim_buf_set_extmark(buf,name_space,pos[1] - 1 + start_line,pos[2],{
                virt_text_pos = "overlay",
                virt_text = {
                    { mark, hl_group },
                },
            })

            if pos_table[pos_idx + 1] then
                loop(pos_idx + 1)
            end
        end

        loop(1)
        vim.cmd.redraw()

        local selected_mark = vim.fn.getcharstr()
        vim.api.nvim_buf_clear_namespace(buf,name_space,start_line,end_line)
        local selected_mark_idx = r.find("/V" .. selected_mark)(marks)
        if selected_mark_idx == nil then
            return nil
        end

        local selected_pos_idx = (selected_mark_idx - 1) * mark_len + 1
        if pos_table[selected_pos_idx] == nil then
            return nil
        end

        local function loop(pos_idx)
            local pos = pos_table[pos_idx + selected_pos_idx - 1]
            vim.api.nvim_buf_set_extmark(buf,name_space,pos[1] - 1 + start_line,pos[2],{
                virt_text_pos = "overlay",
                virt_text = {
                    { mark_table[pos_idx], hl_group },
                },
            })

            if pos_idx < mark_len and pos_table[pos_idx + selected_pos_idx] then
                loop(pos_idx + 1)
            end
        end

        loop(1)
        vim.cmd.redraw()

        local selected_mark = vim.fn.getcharstr()
        vim.api.nvim_buf_clear_namespace(buf,name_space,start_line,end_line)
        local selected_mark_idx = r.find("/V" .. selected_mark)(marks)
        if selected_mark_idx == nil then
            return nil
        end
        local selected_pos = selected_pos_idx + selected_mark_idx - 1
        local pos = pos_table[selected_pos]
        if pos == nil then
            return nil
        end

        pos[1] = pos[1] + start_line -- 行のずれを修正
        return pos
    end

    function N.jump()
        local pos = N.select_position(0,vim.fn.line("w0") - 1,vim.fn.line("w$"))
        if pos then
            vim.api.nvim_win_set_cursor(0,pos)
        end
    end

    return N
end

return M
