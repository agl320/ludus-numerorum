-- Dot-matrix LED font for the visor numbers (5 x 7 dots per digit), shared by the server visor, the intro and the
-- loadout preview. Each lit dot is a round red LED with a soft halo, like a real LED sign.
local Font = {}
Font.Cols, Font.Rows = 5, 7
-- where the digit sits on each 192 x 288 visor cell canvas (px): as big as the cell allows while keeping a gap
-- between digits, so the number reads at a distance
Font.Box = {X = 42, Y = 48, W = 108, H = 192}
Font.Glyphs = {
    ["0"] = {"01110", "10001", "10011", "10101", "11001", "10001", "01110"},
    ["1"] = {"00100", "01100", "00100", "00100", "00100", "00100", "01110"},
    ["2"] = {"01110", "10001", "00001", "00010", "00100", "01000", "11111"},
    ["3"] = {"11111", "00010", "00100", "00010", "00001", "10001", "01110"},
    ["4"] = {"00010", "00110", "01010", "10010", "11111", "00010", "00010"},
    ["5"] = {"11111", "10000", "11110", "00001", "00001", "10001", "01110"},
    ["6"] = {"00110", "01000", "10000", "11110", "10001", "10001", "01110"},
    ["7"] = {"11111", "00001", "00010", "00100", "01000", "01000", "01000"},
    ["8"] = {"01110", "10001", "10001", "01110", "10001", "10001", "01110"},
    ["9"] = {"01110", "10001", "10001", "01111", "00001", "00010", "01100"},
    ["-"] = {"00000", "00000", "00000", "11111", "00000", "00000", "00000"}, -- closed eye (blink)
    ["O"] = {"01110", "10001", "10001", "10001", "10001", "10001", "01110"}, -- open eye (0__0 face; plain, no slash)
    ["_"] = {"00000", "00000", "00000", "00000", "00000", "00000", "11111"}, -- mouth of the 0__0 / X__X faces
    ["X"] = {"10001", "10001", "01010", "00100", "01010", "10001", "10001"}, -- dead eye (X__X)
    ["*"] = {"00000", "00100", "10101", "01110", "10101", "00100", "00000"}, -- masked (death cam)
}
-- lit dot centres for a character, in a 0..1 box (x right, y down)
function Font.Dots(char)
    local rows = Font.Glyphs[char]
    local out = {}
    if not rows then return out end
    for r, row in ipairs(rows) do
        for c = 1, #row do
            if string.sub(row, c, c) == "1" then
                table.insert(out, Vector2.new((c - 1) / (Font.Cols - 1), (r - 1) / (Font.Rows - 1)))
            end
        end
    end
    return out
end

local SCREEN_BLACK = Color3.fromRGB(16, 9, 10)
-- Draw `char` into a SurfaceGui (or any GuiObject) inside the glyph box {X, Y, W, H} (px).
-- brightness: the SurfaceGui's Brightness (the halo is pre-divided so it fades into the screen).
-- (trial) no "__" mouth on the 0__0 / X__X faces: the middle cells stay unlit (true brings it back)
local FACE_MOUTH = false
function Font.Draw(surface, char, color, brightness, glyph)
	if char == "_" and not FACE_MOUTH then char = " " end
    surface:ClearAllChildren()
    glyph = Font.Box
    -- a dark backing hides the old segment outlines printed on the visor's screen texture
    local back = Instance.new("Frame")
    back.Name = "Backing"; back.BorderSizePixel = 0; back.Position = UDim2.fromScale(0.08, 0); back.Size = UDim2.fromScale(0.84, 1)
    back.BackgroundColor3 = Color3.fromRGB(10, 6, 7); back.ZIndex = 0; back.Parent = surface
    color = color or Color3.fromRGB(255, 38, 48)
    local k = 1 / math.max(brightness or 1, 1)
    local pitch = math.min(glyph.W / (Font.Cols - 1), glyph.H / (Font.Rows - 1))
    local w, h = pitch * (Font.Cols - 1), pitch * (Font.Rows - 1)
    local x0, y0 = glyph.X + (glyph.W - w) / 2, glyph.Y + (glyph.H - h) / 2
    local halo = SCREEN_BLACK:Lerp(color, 0.4)
    halo = Color3.new(halo.R * k, halo.G * k, halo.B * k)
    local core = color:Lerp(Color3.new(1, 1, 1), 0.05)
    local function dot(p, size, c, z)
        local f = Instance.new("Frame")
        f.BorderSizePixel = 0
        f.AnchorPoint = Vector2.new(0.5, 0.5)
        f.Position = UDim2.fromOffset(p.X, p.Y)
        f.Size = UDim2.fromOffset(size, size)
        f.BackgroundColor3 = c
        f.ZIndex = z
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0.5, 0)
        corner.Parent = f
        f.Parent = surface
    end
    for _, d in ipairs(Font.Dots(char)) do
        local p = Vector2.new(x0 + d.X * w, y0 + d.Y * h)
        dot(p, pitch * 1.3, halo, 1)   -- soft halo (neighbouring halos join up, so strokes read as lines)
        dot(p, pitch * 0.92, core, 2)   -- the LED
    end
end

return Font
