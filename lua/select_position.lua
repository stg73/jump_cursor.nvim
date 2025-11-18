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

            local s,e = r.find(".")(str)
            local char = string.sub(str,s,e)
            local rest = string.sub(str,e + 1)

            local char_byte = string.len(char) -- バイト数を取得する

            if char == "\n" then
                loop(line + 1,0,rest)
            else
                if not r.is(ignore)(char) then -- ジャンプできる文字であれば
                    table.insert(t,{ line, column }) -- その文字の位置(行 列)を格納
                end

                loop(line,column + char_byte,rest)
            end
        end

        loop(1,0,str)

        return t
    end

    function N.select_position(buf,s,e)
        local buf_content = table.concat(vim.api.nvim_buf_get_lines(buf,s,e,false),"\n")
        local pos_table = N.get_pos_table(buf_content)

        -- マーク数の最適化 最初の塗り潰しと2番目の塗り潰しでマークが同じ数になるようにする
        local mark_len = math.ceil(math.sqrt(#pos_table))
        marks = string.sub(marks,1,mark_len)

        local function loop(i)
            local mark = mark_table[math.floor((i - 1)/mark_len) + 1]

            if mark == nil then
                return
            end

            local pos = pos_table[i]
            vim.api.nvim_buf_set_extmark(buf,2,pos[1] - 1 + s,pos[2],{
                virt_text_pos = "overlay",
                virt_text = {
                    { mark, hl_group },
                },
            })

            if pos_table[i + 1] then
                loop(i + 1)
            end
        end

        loop(1)
        vim.cmd.redraw()

        local mark = vim.fn.getcharstr()
        vim.api.nvim_buf_clear_namespace(buf,2,s,e)
        local mark_index = r.find("/V" .. mark)(marks)
        if mark_index == nil then
            return
        end

        local pos_index = (mark_index - 1) * mark_len + 1
        if pos_table[pos_index] == nil then
            return
        end

        local function loop(i)
            local pos = pos_table[i + pos_index - 1]
            vim.api.nvim_buf_set_extmark(buf,2,pos[1] - 1 + s,pos[2],{
                virt_text_pos = "overlay",
                virt_text = {
                    { mark_table[i], hl_group },
                },
            })

            if i < mark_len and pos_table[i + pos_index] then
                loop(i + 1)
            end
        end

        loop(1)
        vim.cmd.redraw()

        local mark = vim.fn.getcharstr()
        vim.api.nvim_buf_clear_namespace(buf,2,s,e)
        local mark_index = r.find("/V" .. mark)(marks)
        if mark_index == nil then
            return
        end
        local pos_index = pos_index + mark_index - 1
        local pos = pos_table[pos_index]

        pos[1] = pos[1] + s
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
