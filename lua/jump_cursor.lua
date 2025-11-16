local M = {}

local r = require("regex")

function M.opt(opts)
    -- オプション
    local opts = opts or {}
    local marks = opts.marks or "aotnsiu-kwr,dhvcef.yl;gmjxzbpqAOTNSIU=KWR<DHVCEF>YL+GMJXZBPQ:*[]{}@`\\_1234567890/^!\"#$%&'()?~|"
    local hl_group = opts.hl_group or "special"
    local ignore = opts.ignore or "/s"

    local mark_table = vim.split(marks,"")
    local name_space = vim.api.nvim_create_namespace("jump_cursor")

    local N = {} -- "M" の次の文字

    function N.get_jumpable_line(lines)
        local t = {}

        local function loop(i)
            if not r.is("(" .. ignore .. ")*")(lines[i]) then -- ジャンプできる列がある行であれば
                table.insert(t,i)
            end

            if lines[i + 1] then
                loop(i + 1)
            end
        end

        loop(1)

        return t
    end

    -- nvim_buf_set_extmark()はバイト指定なのでそれに合わせてバイト数で取得する
    function N.get_jumpable_column(text)
        local t = {}

        local function loop(byte,str)
            -- string.find はマルチバイトに対応していない
            local s,e = r.find(".")(str)
            local char = string.sub(str,s,e)
            local rest = string.sub(str,e + 1)

            local char_column = byte + 1
            local char_byte = string.len(char) -- バイト数を取得する

            if not r.is(ignore)(char) then -- ジャンプできる文字であれば
                table.insert(t,char_column)
            end

            if rest ~= "" then
                loop(byte + char_byte,rest)
            end
        end

        loop(0,text)

        return t
    end

    function N.select_column(buf,line)
        local jumpable = N.get_jumpable_column(vim.api.nvim_buf_get_lines(buf,line - 1,line,false)[1])
        local function loop(i)
            vim.api.nvim_buf_set_extmark(buf,name_space,line - 1,jumpable[i] - 1,{
                virt_text_pos = "overlay",
                virt_text = {
                    { mark_table[i], hl_group }
                },
            })

            if mark_table[i + 1] and jumpable[i + 1] then
                loop(i + 1)
            end
        end

        loop(1)
        vim.cmd.redraw()

        local mark = vim.fn.getcharstr()
        vim.api.nvim_buf_clear_namespace(buf,name_space,line - 1,line)
        local mark_index = r.find("/V" .. mark)(marks)
        local column = jumpable[mark_index]

        return column
    end

    function N.select_line(buf,s,e)
        local lines = vim.api.nvim_buf_get_lines(buf,s - 1,e,false)
        local jumpable_line = N.get_jumpable_line(lines)
        local function loop_line(l)
            local jumpable = N.get_jumpable_column(lines[jumpable_line[l]])
            local function loop_column(c)
                vim.api.nvim_buf_set_extmark(buf,name_space,jumpable_line[l] + s - 2,jumpable[c] - 1,{
                    virt_text_pos = "overlay",
                    virt_text = {
                        { mark_table[l], hl_group }
                    },
                })

                if mark_table[c + 1] and jumpable[c + 1] then
                    loop_column(c + 1)
                end
            end

            loop_column(1) -- 行をハイライトする

            if jumpable_line[l + 1] and mark_table[l + 1] then
                loop_line(l + 1)
            end
        end

        loop_line(1) -- 複数行をハイライトする
        vim.cmd.redraw()

        local mark = vim.fn.getcharstr()
        vim.api.nvim_buf_clear_namespace(buf,name_space,s - 1,e)
        local mark_index = r.find("/V" .. mark)(marks)
        local line = jumpable_line[mark_index]

        if line then
            return line + s - 1
        end
    end

    function N.select_position(buf,s,e)
        local line = N.select_line(buf,s,e)
        if line then
            local column = N.select_column(buf,line)
            if column then
                return { line, column }
            else
                return nil
            end
        else
            return nil
        end
    end

    function N.jump()
        local pos = N.select_position(0,vim.fn.line("w0"),vim.fn.line("w$"))
        if pos then
            vim.fn.cursor(pos)
        end
    end

    return N
end

return M
