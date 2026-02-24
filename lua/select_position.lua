local M = {}

local r = require("regex")
local tbl = require("tbl")

function M.opt(opts)
    -- オプション
    local opts = opts or {}
    local marks = opts.marks or "aotnsiu-kwr,dhvcef.yl;gmjxzbpqAOTNSIU=KWR<DHVCEF>YL+GMJXZBPQ"
    local higroup = opts.higroup or "special"
    local character = opts.character or "/S"
    local ns_id = vim.api.nvim_create_namespace(opts.namespace or "select_position")

    local N = {} -- "M" の次の文字

    function N.mark_to_number(mark)
        return r.find("/V" .. mark)(marks) or math.huge
    end

    function N.get_positions(lines,start_line,start_column)
        local positions = {}
        local for_pairs = tbl.flip(tbl.pairs)
        for_pairs(lines)(function(key_val)
            local line = key_val[1] - 1
            local line_str = key_val[2]
            local utf_pos = vim.str_utf_pos(line_str)
            for_pairs(utf_pos)(function(key_val)
                local char = (function()
                    local char_start = key_val[2]
                    local next_utf_pos = utf_pos[key_val[1] + 1]
                    local char_end = next_utf_pos or (char_start + 1)
                    return string.sub(line_str,char_start,char_end - 1)
                end)()
                local column = key_val[2] - 1
                local pos = {
                    line + start_line,
                    column + start_column
                }

                if r.is(character)(char) then
                    table.insert(positions,pos)
                end
            end)
        end)
        return positions
    end

    local mark_table = vim.split(marks,"")
    function N.set_marks(buf,positions,fn)
        for k,v in pairs(positions) do
            local pos = positions[k]
            vim.api.nvim_buf_set_extmark(buf,ns_id,pos[1] - 1,pos[2],{
                virt_text_pos = "overlay",
                virt_text = {
                    { mark_table[fn(k)], higroup },
                },
            })
        end
    end

    function N.select(buf,start_line,end_line)
        local positions = N.get_positions(vim.api.nvim_buf_get_lines(buf,start_line,end_line,false),start_line + 1,0)

        -- マーク数の最適化 最初の塗り潰しと2番目の塗り潰しでマークが同じ数になるようにする
        local mark_len = math.ceil(math.sqrt(#positions)) -- マークの数を決める

        local function select_index()
            local char = vim.fn.getcharstr()
            vim.api.nvim_buf_clear_namespace(buf,ns_id,start_line,end_line)
            return N.mark_to_number(char)
        end

        local O = {}

        function O.section()
            N.set_marks(buf,positions,function(i) return math.floor((i - 1)/mark_len) + 1 end)
            vim.cmd.redraw()

            local selected_section = select_index()
            local section_len = math.ceil(#positions/mark_len)
            if selected_section <= section_len then
                return selected_section
            else
                return nil
            end
        end

        function O.position_from_section(section)
            local start_pos = (section - 1) * mark_len + 1

            local section_positions = vim.list_slice(positions,start_pos,start_pos + mark_len - 1)
            N.set_marks(buf,section_positions,function(i) return i end)
            vim.cmd.redraw()

            local selected_column = select_index()
            if selected_column <= mark_len then
                local selected_pos = start_pos + selected_column - 1
                return positions[selected_pos]
            else
                return nil
            end
        end

        function O.position()
            local section = O.section()
            if section then
                return O.position_from_section(section)
            else
                return nil
            end
        end

        return O
    end

    function N.set_cursor(win,set_win)
        win = win or 0
        local buf = vim.api.nvim_win_get_buf(win)
        local wininfo = vim.fn.getwininfo(win ~= 0 and win or vim.api.nvim_get_current_win())[1]
        local pos = N.select(buf,wininfo.topline - 1,wininfo.botline).position()
        if pos then
            vim.api.nvim_win_set_cursor(win,pos)
            if set_win then
                vim.api.nvim_set_current_win(win)
            end
        end
    end

    return N
end

return M
