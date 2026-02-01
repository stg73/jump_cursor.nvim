local M = {}

local r = require("regex")

function M.opt(opts)
    -- オプション
    local opts = opts or {}
    local marks = opts.marks or "aotnsiu-kwr,dhvcef.yl;gmjxzbpqAOTNSIU=KWR<DHVCEF>YL+GMJXZBPQ"
    local higroup = opts.higroup or "special"
    local character = opts.character or "/S"
    local namespace = opts.namespace or "select_position"

    local N = {} -- "M" の次の文字

    function N.mark_to_number(mark)
        return r.find("/V" .. mark)(marks) or math.huge
    end

    -- ジャンプできる位置のリストを取得する
    function N.get_positions(str,start_line,start_column)
        local t = {}

        local function insert_positions(line,column,str)
            if str == "" then
                return
            end

            local s,e = r.find(".")(str) -- string.findはマルチバイトに対応していない
            local char = string.sub(str,s,e)
            local rest = string.sub(str,e + 1)

            if char == "\n" then
                insert_positions(line + 1,0,rest)
            else
                if r.is(character)(char) then -- ジャンプできる文字であれば
                    table.insert(t,{ line + start_line, column + start_column }) -- その文字の位置(行と列)を格納
                end

                insert_positions(line,column + string.len(char),rest)
            end
        end

        insert_positions(0,0,str)

        return t
    end

    do
        local mark_table = vim.split(marks,"")
        local ns_id = vim.api.nvim_create_namespace(namespace)

        function N.clear_namespace(buf,start_line,end_line)
            vim.api.nvim_buf_clear_namespace(buf,ns_id,start_line,end_line)
        end

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
    end

    function N.select(buf,start_line,end_line)
        local buf_content = table.concat(vim.api.nvim_buf_get_lines(buf,start_line,end_line,false),"\n")
        local positions = N.get_positions(buf_content,start_line + 1,0)

        -- マーク数の最適化 最初の塗り潰しと2番目の塗り潰しでマークが同じ数になるようにする
        local mark_len = math.ceil(math.sqrt(#positions)) -- マークの数を決める

        local O = {}

        function O.section()
            N.set_marks(buf,positions,function(i) return math.floor((i - 1)/mark_len) + 1 end)
            vim.cmd.redraw()

            local selected_section = N.mark_to_number(vim.fn.getcharstr())
            N.clear_namespace(buf,start_line,end_line)

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

            local selected_column = N.mark_to_number(vim.fn.getcharstr())
            N.clear_namespace(buf,start_line,end_line)
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
