local M = {}

local r = require("regex")

function M.jump(opts) return function()
    local opts = opts or {}
    local marks = opts.marks or "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ,.<>-+=;:*[]{}@`\\_1234567890/^!\"#$%&'()?~|"
    local hl_group = opts.hl_group or "special"
    local ignore = opts.ignore or "/s"

    local mark_table = vim.split(marks,"")
    local name_space = vim.api.nvim_create_namespace("jump_cursor")

    -- 空行などを飛ばすため
    local function get_jumpable_line(lines)
        local t = {}

        local function loop(i)
            if not r.is("(" .. ignore .. ")*")(lines[i]) then -- ジャンプする行であれば
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
    local function get_jumpable_column(text)
        local t = {}

        local function loop(byte,str)
            -- string.match だとマルチバイトに対応できない
            local char = r.match(".")(str)
            local rest = r.match(".@<=(.+)")(str)
            local char_column = byte + 1
            local char_byte = string.len(char)

            if not r.is(ignore)(char) then -- 無視する文字でなければ
                table.insert(t,char_column)
            end

            if rest then
                loop(byte + char_byte,rest)
            end
        end

        loop(0,text)

        return t
    end

    local function get_column(line)
        local jumpable = get_jumpable_column(vim.fn.getline(line))
        local function loop(i)
            vim.api.nvim_buf_set_extmark(0,name_space,line - 1,jumpable[i] - 1,{
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
        vim.api.nvim_buf_clear_namespace(0,name_space,line - 1,line)
        local mark_index = r.find("/V" .. mark)(marks)
        local column = jumpable[mark_index]

        return column
    end

    local function get_line(s,e)
        local lines = vim.api.nvim_buf_get_lines(0,s - 1,e,false)
        local jumpable_line = get_jumpable_line(lines)
        local function loop_line(l)
            local jumpable = get_jumpable_column(lines[jumpable_line[l]])
            local function loop_column(c)
                vim.api.nvim_buf_set_extmark(0,name_space,jumpable_line[l] + s - 2,jumpable[c] - 1,{
                    virt_text_pos = "overlay",
                    virt_text = {
                        { mark_table[l], hl_group }
                    },
                })

                if mark_table[c + 1] and jumpable[c + 1] then
                    loop_column(c + 1)
                end
            end

            loop_column(1)

            if jumpable_line[l + 1] and mark_table[l + 1] then
                loop_line(l + 1)
            end
        end

        loop_line(1)
        vim.cmd.redraw()

        local mark = vim.fn.getcharstr()
        vim.api.nvim_buf_clear_namespace(0,name_space,s - 1,e)
        local mark_index = r.find("/V" .. mark)(marks)
        local line = jumpable_line[mark_index]

        if line then
            return line + s - 1
        end
    end

    local line = get_line(vim.fn.line("w0"),vim.fn.line("w$"))
    if line then
        local column = get_column(line)
        if column then
            vim.fn.cursor(line,column)
        end
    end
end end

return M
