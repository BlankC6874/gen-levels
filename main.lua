-- Text Adventure + Visual Dungeon Explorer
-- Based on Procedural Dungeon Generator (BSP)

function love.load()
    math.randomseed(os.time())
    
    love.window.setTitle("Text Adventure Dungeon")
    love.window.setMode(800, 600)

    GRID_DIM = 20
    MIN_LEAF_SIZE = 5
    MAX_DEPTH = 3
    ROOM_PADDING = 1
    MIN_ROOM_SIZE = 3

    WINDOW_SIZE = 600
    CELL_SIZE = WINDOW_SIZE / GRID_DIM

    colors = {
        background = {0.1, 0.1, 0.1},
        wall = {0.3, 0.3, 0.3},
        floor = {0.6, 0.6, 0.6},
        player = {1, 0.3, 0.3},
        grid_line = {0.2, 0.2, 0.2, 0.5}
    }

    generateDungeon()
    
    local firstRoom = dungeon.rooms[1]
    player = {
        x = firstRoom.center.x,
        y = firstRoom.center.y
    }

    message = "You awaken in a dark room."
end

function love.keypressed(key)
    local dirX, dirY = 0, 0

    if key == "w" then dirY = -1
    elseif key == "s" then dirY = 1
    elseif key == "a" then dirX = -1
    elseif key == "d" then dirX = 1
    elseif key == "r" then
        generateDungeon()
        local firstRoom = dungeon.rooms[1]
        player.x = firstRoom.center.x
        player.y = firstRoom.center.y
        message = "You are in a new dungeon."
        return
    elseif key == "escape" then
        love.event.quit()
    end

    local newX = player.x + dirX
    local newY = player.y + dirY
    if dungeon.grid[newY] and dungeon.grid[newY][newX] == 0 then
        player.x = newX
        player.y = newY
        message = describeLocation()
    else
        message = "You bump into a wall."
    end
end

function love.draw()
    love.graphics.setBackgroundColor(colors.background)

    for y = 1, GRID_DIM do
        for x = 1, GRID_DIM do
            local screenX = (x - 1) * CELL_SIZE
            local screenY = (y - 1) * CELL_SIZE

            if dungeon.grid[y][x] == 1 then
                love.graphics.setColor(colors.wall)
            else
                love.graphics.setColor(colors.floor)
            end

            love.graphics.rectangle("fill", screenX, screenY, CELL_SIZE, CELL_SIZE)
            love.graphics.setColor(colors.grid_line)
            love.graphics.rectangle("line", screenX, screenY, CELL_SIZE, CELL_SIZE)
        end
    end

    -- Draw player
    love.graphics.setColor(colors.player)
    love.graphics.rectangle("fill", (player.x - 1) * CELL_SIZE, (player.y - 1) * CELL_SIZE, CELL_SIZE, CELL_SIZE)

    -- Text Interface
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.printf("Location: (" .. player.x .. "," .. player.y .. ")", WINDOW_SIZE + 10, 10, 180)
    love.graphics.printf(message, WINDOW_SIZE + 10, 40, 180)
    love.graphics.printf("WASD = Move\nR = Regenerate\nESC = Quit", WINDOW_SIZE + 10, 100, 180)
end

function describeLocation()
    local desc = "You are in a passage. Exits: "
    local exits = ""
    if dungeon.grid[player.y - 1] and dungeon.grid[player.y - 1][player.x] == 0 then exits = exits .. "N " end
    if dungeon.grid[player.y + 1] and dungeon.grid[player.y + 1][player.x] == 0 then exits = exits .. "S " end
    if dungeon.grid[player.y][player.x - 1] == 0 then exits = exits .. "W " end
    if dungeon.grid[player.y][player.x + 1] == 0 then exits = exits .. "E " end
    return desc .. exits
end

-- Dungeon Generation Code
function generateDungeon()
    dungeon = {
        rooms = {},
        grid = {}
    }

    for y = 1, GRID_DIM do
        dungeon.grid[y] = {}
        for x = 1, GRID_DIM do
            dungeon.grid[y][x] = 1
        end
    end

    local rootNode = {
        x = 1, y = 1, width = GRID_DIM, height = GRID_DIM,
        children = {}, room = nil
    }

    local leaves = {}
    splitSpace(rootNode, 0, leaves)
    createRoomsInLeaves(leaves)
    connectRooms(rootNode)
end

function splitSpace(node, depth, leaves)
    if depth >= MAX_DEPTH or (node.width <= MIN_LEAF_SIZE * 2 and node.height <= MIN_LEAF_SIZE * 2) then
        table.insert(leaves, node)
        return true
    end

    local splitHorizontally = node.width > node.height and node.width > MIN_LEAF_SIZE * 2
    local splitVertically = node.height >= node.width and node.height > MIN_LEAF_SIZE * 2

    if not splitHorizontally and not splitVertically then
        table.insert(leaves, node)
        return true
    end

    local splitDirection
    if splitHorizontally and splitVertically then
        splitDirection = math.random() > 0.5 and "horizontal" or "vertical"
    elseif splitHorizontally then
        splitDirection = "horizontal"
    else
        splitDirection = "vertical"
    end

    local splitPoint
    if splitDirection == "horizontal" then
        splitPoint = math.random(MIN_LEAF_SIZE, node.width - MIN_LEAF_SIZE)
        node.children[1] = { x = node.x, y = node.y, width = splitPoint, height = node.height, children = {}, room = nil }
        node.children[2] = { x = node.x + splitPoint, y = node.y, width = node.width - splitPoint, height = node.height, children = {}, room = nil }
    else
        splitPoint = math.random(MIN_LEAF_SIZE, node.height - MIN_LEAF_SIZE)
        node.children[1] = { x = node.x, y = node.y, width = node.width, height = splitPoint, children = {}, room = nil }
        node.children[2] = { x = node.x, y = node.y + splitPoint, width = node.width, height = node.height - splitPoint, children = {}, room = nil }
    end

    splitSpace(node.children[1], depth + 1, leaves)
    splitSpace(node.children[2], depth + 1, leaves)
end

function createRoomsInLeaves(leaves)
    for _, leaf in ipairs(leaves) do
        local potentialW = leaf.width - ROOM_PADDING * 2
        local potentialH = leaf.height - ROOM_PADDING * 2

        if potentialW >= MIN_ROOM_SIZE and potentialH >= MIN_ROOM_SIZE then
            local roomW = math.random(MIN_ROOM_SIZE, potentialW)
            local roomH = math.random(MIN_ROOM_SIZE, potentialH)

            local roomX = leaf.x + ROOM_PADDING + math.random(0, potentialW - roomW)
            local roomY = leaf.y + ROOM_PADDING + math.random(0, potentialH - roomH)

            leaf.room = {
                x = roomX, y = roomY, width = roomW, height = roomH,
                center = { x = roomX + math.floor(roomW / 2), y = roomY + math.floor(roomH / 2) }
            }
            table.insert(dungeon.rooms, leaf.room)

            carveRect(roomX, roomY, roomW, roomH, 0)
        end
    end
end

function connectRooms(node)
    if #node.children ~= 2 then return end

    connectRooms(node.children[1])
    connectRooms(node.children[2])

    local room1 = getRandomRoomFromNode(node.children[1])
    local room2 = getRandomRoomFromNode(node.children[2])

    if room1 and room2 then
        createCorridor(room1.center.x, room1.center.y, room2.center.x, room2.center.y)
    end
end

function getRandomRoomFromNode(node)
    if node.room then return node.room end
    local rooms = {}
    local function findRooms(n)
        if n.room then
            table.insert(rooms, n.room)
        else
            for _, c in ipairs(n.children) do
                findRooms(c)
            end
        end
    end
    findRooms(node)
    return #rooms > 0 and rooms[math.random(#rooms)] or nil
end

function createCorridor(x1, y1, x2, y2)
    if math.random() > 0.5 then
        carveRect(math.min(x1, x2), y1, math.abs(x1 - x2) + 1, 1, 0)
        carveRect(x2, math.min(y1, y2), 1, math.abs(y1 - y2) + 1, 0)
    else
        carveRect(x1, math.min(y1, y2), 1, math.abs(y1 - y2) + 1, 0)
        carveRect(math.min(x1, x2), y2, math.abs(x1 - x2) + 1, 1, 0)
    end
end

function carveRect(startX, startY, width, height, tileType)
    for y = startY, startY + height - 1 do
        for x = startX, startX + width - 1 do
            if y >= 1 and y <= GRID_DIM and x >= 1 and x <= GRID_DIM then
                dungeon.grid[y][x] = tileType
            end
        end
    end
end
