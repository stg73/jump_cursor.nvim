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

    function N.mark_to_number(mark)
        return r.find("/V" .. mark)(marks) or math.huge
    end

    -- ジャンプできる位置のリストを取得する
    function N.get_pos_table(str,start)
        start = start or 0
        local t = {}

        local function loop(line,column,str)
            if str == "" then
                return
            end

            local s,e = r.find(".")(str) -- string.findはマルチバイトに対応していない
            local char = string.sub(str,s,e)
            local rest = string.sub(str,e + 1)

            if char == "\n" then
                loop(line + 1,0,rest)
            else
                if not r.is(ignore)(char) then -- ジャンプできる文字であれば
                    table.insert(t,{ line + start, column }) -- その文字の位置(行と列)を格納
                end

                loop(line,column + string.len(char),rest)
            end
        end

        loop(1,0,str)

        return t
    end

    function N.select_position(buf,start_line,end_line)
        local buf_content = table.concat(vim.api.nvim_buf_get_lines(buf,start_line,end_line,false),"\n")
        local pos_table = N.get_pos_table(buf_content,start_line)

        -- マーク数の最適化 最初の塗り潰しと2番目の塗り潰しでマークが同じ数になるようにする
        local mark_len = math.ceil(math.sqrt(#pos_table)) -- マークの数を決める

        local function select_section()
            local function loop(pos_idx)
                local pos = pos_table[pos_idx]
                vim.api.nvim_buf_set_extmark(buf,name_space,pos[1] - 1,pos[2],{
                    virt_text_pos = "overlay",
                    virt_text = {
                        { mark_table[math.floor((pos_idx - 1)/mark_len) + 1], hl_group },
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
            local selected_section = N.mark_to_number(selected_mark)

            local section_len = math.ceil(#pos_table/mark_len)
            if selected_section <= section_len then
                return selected_section
            else
                return nil
            end
        end

        local function select_position_from_section(section)
            local start_pos = (section - 1) * mark_len + 1

            local function loop(pos_idx)
                local pos = pos_table[pos_idx + start_pos - 1]

                if pos == nil then
                    return
                end

                vim.api.nvim_buf_set_extmark(buf,name_space,pos[1] - 1,pos[2],{
                    virt_text_pos = "overlay",
                    virt_text = {
                        { mark_table[pos_idx], hl_group },
                    },
                })

                if pos_idx < mark_len then
                    loop(pos_idx + 1)
                end
            end

            loop(1)
            vim.cmd.redraw()

            local selected_mark = vim.fn.getcharstr()
            vim.api.nvim_buf_clear_namespace(buf,name_space,start_line,end_line)
            local selected_column = N.mark_to_number(selected_mark)
            if selected_column <= mark_len then
                local selected_pos = start_pos + selected_column - 1
                return pos_table[selected_pos]
            else
                return nil
            end
        end

        local section = select_section()
        if section then
            return select_position_from_section(section)
        else
            return nil
        end
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
