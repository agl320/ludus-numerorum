local Rules = {}
function Rules.ValidCode(code)
    return type(code) == "string" and #code == 4 and code:match("^[1-9]%d%d%d$") ~= nil
end
function Rules.IsEnemy(a, b)
    return a ~= nil and b ~= nil and a ~= b
end
function Rules.Winner(red, blue)
    if red == blue then return "DRAW" end
    return red > blue and "RED" or "BLUE"
end
function Rules.FrontVisible(dot, threshold)
    return dot > threshold
end
return Rules
