if game.GameId ~= 6035872082 then return end
if not game:IsLoaded() then game.Loaded:Wait() end

local app = getgenv().meowlua
if type(app) ~= "table" then
    app = {}
    getgenv().meowlua = app
end
app.sigMap = app.sigMap or {}
app.sigSeen = app.sigSeen or {}
local versionKey = "51a7fbe4590c8b20d0775d79"
app.versionKey = versionKey

local library, themeManager, saveManager
local players = game:GetService("Players")
local player = players.LocalPlayer
local replicatedStorage = game:GetService("ReplicatedStorage")
local runService = game:GetService("RunService")
local workspace = game:GetService("Workspace")
local starterGui = game:GetService("StarterGui")
local zeroVector = Vector3.zero
local connectionRegistry = {}
local connectionRegistrySize = 0

local function sweepConnectionRegistry()
    for connection in pairs(connectionRegistry) do
        if not connection.Connected then
            connectionRegistry[connection] = nil
            connectionRegistrySize = connectionRegistrySize - 1
        end
    end
end

local function track(connection)
    if connection and not connectionRegistry[connection] then
        connectionRegistry[connection] = true
        connectionRegistrySize = connectionRegistrySize + 1
        if connectionRegistrySize % 128 == 0 then
            sweepConnectionRegistry()
        end
    end
    return connection
end

local function disconnect(connection)
    if connection then
        if connectionRegistry[connection] then
            connectionRegistry[connection] = nil
            connectionRegistrySize = connectionRegistrySize - 1
        end
        connection:Disconnect()
    end
    return nil
end

local function releaseAllConnections()
    for connection in pairs(connectionRegistry) do
        connectionRegistry[connection] = nil
        pcall(connection.Disconnect, connection)
    end
    connectionRegistrySize = 0
end

local function getMetaMethod(obj, name)
    local metatable = getrawmetatable(obj)
    return metatable and rawget(metatable, name)
end

local function setProperty(obj, key, value)
    if not obj then return false end
    local newIndex = getMetaMethod(obj, "__newindex")
    if newIndex then
        local ok = pcall(newIndex, obj, key, value)
        if ok then return true end
    end
    if sethiddenproperty then
        local ok = pcall(sethiddenproperty, obj, key, value)
        if ok then return true end
    end
    return pcall(function() obj[key] = value end)
end

app.voidWriting = false
app.voidFinalCFrame = nil
app.voidSyncRoot = nil

local function setCFrame(part, currentCFrame, linearVelocity, angularVelocity)
    if not part or not currentCFrame then return false end
    if part == app.voidSyncRoot then
        if app.voidWriting then
            app.voidFinalCFrame = currentCFrame
        else
            local syncCfg = app.config
            if syncCfg and syncCfg.voidSyncToRagebot and syncCfg.void and app.voidFinalCFrame then
                currentCFrame = app.voidFinalCFrame
                linearVelocity = zeroVector
                angularVelocity = zeroVector
            end
        end
    end
    if linearVelocity == true then
        linearVelocity = zeroVector
        angularVelocity = zeroVector
    end
    local ok = setProperty(part, "CFrame", currentCFrame)
    if linearVelocity ~= nil then
        ok = setProperty(part, "AssemblyLinearVelocity", linearVelocity) and ok
    end
    if angularVelocity ~= nil then
        ok = setProperty(part, "AssemblyAngularVelocity", angularVelocity) and ok
    end
    return ok
end

local function setVelocity(part, velocity)
    if not part then return false end
    local value = velocity or zeroVector
    local linearOk = setProperty(part, "AssemblyLinearVelocity", value)
    local angularOk = setProperty(part, "AssemblyAngularVelocity", value)
    return linearOk and angularOk
end

app.ncsRestoreCFrame = nil
app.ncsRestoreVelocity = nil
app.ncsRestoreAngular = nil
app.ncsRenderId = "__ncsDesync_render"
pcall(function() runService:UnbindFromRenderStep(app.ncsRenderId) end)
app.ncsOwners = {}

app.ncsCapture = function(root, keepVelocity)
    if not root then return end
    if app.ncsRestoreCFrame == nil then
        app.ncsRestoreCFrame = app.teleportationRestoreCFrame or root.CFrame
    end
    if keepVelocity and app.ncsRestoreVelocity == nil then
        app.ncsRestoreVelocity = root.AssemblyLinearVelocity
        app.ncsRestoreAngular = root.AssemblyAngularVelocity
    end
end

app.ncsMark = function(root)
    if not root then return end
    app.ncsMarkCFrame = root.CFrame
    app.ncsMarkVelocity = root.AssemblyLinearVelocity
end

app.ncsRestore = function()
    local saved = app.ncsRestoreCFrame
    local markCFrame = app.ncsMarkCFrame
    local markVelocity = app.ncsMarkVelocity
    app.ncsMarkCFrame = nil
    app.ncsMarkVelocity = nil
    local legacySaved = app.teleportationRestoreCFrame
    app.teleportationRestoreCFrame = nil
    if saved == nil then saved = legacySaved end
    local savedVelocity = app.ncsRestoreVelocity
    local savedAngular = app.ncsRestoreAngular
    app.ncsRestoreVelocity = nil
    app.ncsRestoreAngular = nil
    if saved then
        app.ncsRestoreCFrame = nil
        local root = app.getHumanoidRootPart(player)
        if root then
            local externalMove = false
            local externalVelocity = false
            if markCFrame then
                local markOk = pcall(function()
                    if (root.CFrame.Position - markCFrame.Position).Magnitude > 5 then
                        externalMove = true
                    end
                    if markVelocity and (root.AssemblyLinearVelocity - markVelocity).Magnitude > 1 then
                        externalVelocity = true
                    end
                end)
                if not markOk then
                    externalMove = false
                    externalVelocity = false
                end
            end
            if not externalMove then
                setProperty(root, "CFrame", saved)
                if savedVelocity and not externalVelocity then
                    setProperty(root, "AssemblyLinearVelocity", savedVelocity)
                end
                if savedAngular and not externalVelocity then
                    setProperty(root, "AssemblyAngularVelocity", savedAngular)
                end
            end
        end
    end
end

app.ncsBind = function(owner)
    local wasEmpty = next(app.ncsOwners) == nil
    app.ncsOwners[owner] = true
    if wasEmpty then
        pcall(function() runService:UnbindFromRenderStep(app.ncsRenderId) end)
        pcall(function()
            runService:BindToRenderStep(app.ncsRenderId, Enum.RenderPriority.First.Value, function()
                app.ncsRestore()
            end)
        end)
    end
end

app.ncsUnbind = function(owner)
    app.ncsOwners[owner] = nil
    if next(app.ncsOwners) == nil then
        pcall(function() runService:UnbindFromRenderStep(app.ncsRenderId) end)
        app.ncsRestore()
    end
end

do
    local previousGovernor = app.perfGovernor
    if previousGovernor and previousGovernor.conn then
        disconnect(previousGovernor.conn)
    end
    local governor = { ema = 1 / 60, base = 1 / 60, scale = 1, lastHeavy = 0 }
    app.perfGovernor = governor
    governor.conn = track(runService.Heartbeat:Connect(function(dt)
        if dt <= 0 then return end
        governor.ema = governor.ema + (dt - governor.ema) * 0.1
        if tick() - governor.lastHeavy > 0.25 then
            governor.base = math.clamp(governor.base + (governor.ema - governor.base) * 0.02, 1 / 360, 1 / 30)
            governor.scale = math.min(1, governor.scale + 0.05)
            return
        end
        local limit = governor.base * 1.25
        if governor.ema > limit then
            governor.scale = math.max(0.2, governor.scale * 0.85)
            if governor.scale <= 0.2 then
                governor.base = math.clamp(governor.base + (governor.ema - governor.base) * 0.005, 1 / 360, 1 / 30)
            end
        elseif governor.ema < limit * 0.92 then
            governor.scale = math.min(1, governor.scale * 1.04)
        end
    end))
end

local function requireOptionalModule(module)
    local ok, result = pcall(require, module)
    if ok then return result end
end

local function getCharacterInfo(targetPlayer)
    local rootPart = app.getHumanoidRootPart(targetPlayer)
    if not rootPart then return end
    local humanoid = targetPlayer.Character and targetPlayer.Character:FindFirstChildOfClass("Humanoid")
    if not humanoid or humanoid.Health <= 0 then return end
    return rootPart, humanoid
end

local function getEligibleEnemyCharacter(targetPlayer)
    if not targetPlayer or targetPlayer == player then return end
    local character = targetPlayer.Character
    if not character or character:FindFirstChildOfClass("ForceField") then return end
    local rootPart = character:FindFirstChild("HumanoidRootPart")
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not rootPart or not humanoid or humanoid.Health <= 0 then return end
    local localTeam = player.Team
    local targetTeam = targetPlayer.Team
    if localTeam ~= nil and targetTeam ~= nil and localTeam == targetTeam then return end
    return rootPart, humanoid
end

local function pickTarget(options)
    options = options or {}
    local originRoot = options.originRoot or app.getHumanoidRootPart(player)
    if not originRoot then return end
    local radius = options.searchRadius or (app.config and app.config.searchRadius) or math.huge
    local checkForceField = options.checkForceField == true
    local checkTeam = options.checkTeam == true
    local usePrediction = options.usePrediction == true
    local useHealthPenalty = options.useHealthPenalty == true
    local bestPlayer, bestCharacter, bestRoot, bestHead
    local bestScore = math.huge
    local myPosition = originRoot.Position
    local myTeam = player.Team
    for _, targetPlayer in ipairs(players:GetPlayers()) do
        if targetPlayer ~= player and targetPlayer.Character then
            local character = targetPlayer.Character
            local rootPart = character:FindFirstChild("HumanoidRootPart")
            local head = character:FindFirstChild("Head")
            local humanoid = character:FindFirstChildOfClass("Humanoid")
            local hasForceField = character:FindFirstChildOfClass("ForceField") ~= nil
            local differentTeam = myTeam == nil or targetPlayer.Team == nil or myTeam ~= targetPlayer.Team
            if rootPart and humanoid and humanoid.Health > 0
                and (not usePrediction or head)
                and (not checkForceField or not hasForceField)
                and (not checkTeam or differentTeam) then
                local distance = (myPosition - rootPart.Position).Magnitude
                if distance <= radius then
                    local score = distance
                    if usePrediction or useHealthPenalty then
                        local targetPosition = rootPart.Position
                        if usePrediction then
                            targetPosition = targetPosition + rootPart.AssemblyLinearVelocity * 0.1
                        end
                        local headDistance = head and (myPosition - head.Position).Magnitude or distance
                        local predictedDistance = (myPosition - targetPosition).Magnitude
                        score = headDistance * 0.6 + predictedDistance * 0.4
                        if useHealthPenalty then
                            score = score + math.clamp(humanoid.Health / (humanoid.MaxHealth + 1), 0, 1) * 200
                        end
                    end
                    if score < bestScore then
                        bestScore = score
                        bestPlayer = targetPlayer
                        bestCharacter = character
                        bestRoot = rootPart
                        bestHead = head
                    end
                end
            end
        end
    end
    return bestPlayer, bestCharacter, bestRoot, bestHead
end

local function setFallenHeight()
    return setProperty(workspace, "FallenPartsDestroyHeight", -math.huge)
end

local function findCombatTarget()
    return pickTarget({
        checkForceField = true,
        checkTeam = true,
        searchRadius = math.huge,
        usePrediction = true,
        useHealthPenalty = true,
    })
end

local K0 = "\0"
local K1 = "\1"
local K2 = "\2"
local K3 = "\3"
local K4 = "\4"
local K5 = "\5"

local manipulation = {}
manipulation.aimAboveOrigin = { [K0] = -9e37, [K1] = 0, [K2] = 0 }
manipulation.aimAboveEnd = { [K0] = 0, [K1] = -90000000, [K2] = 0 }
manipulation.aimBelowOrigin = { [K0] = -9e37, [K1] = 0, [K2] = 0 }
manipulation.aimBelowEnd = { [K0] = 0, [K1] = 90000000, [K2] = 0 }
manipulation.aimExtra = { [K0] = 0, [K1] = 1, [K2] = 0, [K3] = 0, [K4] = 0, [K5] = 0 }
manipulation.msEncA = { [K0] = -9e37, [K1] = 0, [K2] = 0, [K3] = -1.5707963267948966, [K4] = 3.1415926535897931, [K5] = 3.1415926535897931 }
manipulation.msEncB = { [K0] = 0, [K1] = -90000000, [K2] = 0, [K3] = -1.5707963267948966, [K4] = 3.1415926535897931, [K5] = 3.1415926535897931 }
manipulation.msEncC = { [K0] = -9e37, [K1] = 0, [K2] = 0, [K3] = 1.5707963267948966, [K4] = 3.1415926535897931, [K5] = 3.1415926535897931 }
manipulation.msEncD = { [K0] = 0, [K1] = 90000000, [K2] = 0, [K3] = 1.5707963267948966, [K4] = 3.1415926535897931, [K5] = 3.1415926535897931 }
manipulation.msRot = { [K0] = 0, [K1] = 1, [K2] = 0, [K3] = 0, [K4] = 0, [K5] = 0 }
manipulation.cleanEvent = Instance.new("RemoteEvent")
manipulation.nativeFire = manipulation.cleanEvent.FireServer

do
    local cloneOk, cloned = pcall(clonefunction, manipulation.cleanEvent.FireServer)
    if cloneOk and type(cloned) == "function" then
        manipulation.nativeFire = cloned
    end
end

function manipulation.itemObjectId(item)
    local ok, id = pcall(function() return item:Get("ObjectID") end)
    if ok and id then return id end
    local okData, data = pcall(rawget, item, "Data")
    if okData and type(data) == "table" then
        return rawget(data, "ObjectID")
    end
    return nil
end

function manipulation.itemInfo(item)
    local ok, info = pcall(rawget, item, "Info")
    if ok and type(info) == "table" then return info end
    return nil
end

function manipulation.itemName(item)
    local ok, name = pcall(function() return rawget(item, "Name") or rawget(item, "ItemName") end)
    if ok then return name end
    return nil
end

function manipulation.findFighter(controller, targetCharacter)
    if not controller or not targetCharacter then return nil end
    local okObjects, objects = pcall(function() return controller.Objects end)
    if not okObjects or type(objects) ~= "table" then return nil end
    local owner = players:GetPlayerFromCharacter(targetCharacter)
    for _, fighter in ipairs(objects) do
        local okMatch, matched = pcall(function()
            if owner ~= nil and rawget(fighter, "Player") == owner then
                return true
            end
            local entity = rawget(fighter, "Entity")
            local model = entity and rawget(entity, "Model")
            return model ~= nil and model == targetCharacter
        end)
        if okMatch and matched then
            return fighter
        end
    end
    return nil
end

function manipulation.isAbove(fighter)
    if not fighter then return true end
    local okObs, obs = pcall(function()
        return rawget(fighter, "itemObserver") or rawget(fighter, "ItemObserver")
    end)
    if not okObs or not obs then return true end
    local ok, result = pcall(function()
        local equipped = obs:GetEquippedItem()
        if equipped ~= nil and equipped.name == "Riot Shield" then
            local pitch = math.deg(fighter:GetCameraRotation().X)
            if 22 < pitch and pitch < 91 then
                return "Below"
            end
            return "Above"
        end
        for _, it in pairs(obs:GetItems()) do
            if it.name == "Riot Shield" then
                local pitch = math.deg(fighter:GetCameraRotation().X)
                if 315 < pitch and pitch < 360 or 0 < pitch and pitch < 91 then
                    return "Above"
                end
                return "Below"
            end
        end
        return "None"
    end)
    return not (ok and result == "Below")
end

function manipulation.patchEncoding(base, n33, yaw, roll)
    return { [K0] = base[K0], [K1] = base[K1], [K2] = base[K2], [K3] = n33, [K4] = yaw, [K5] = roll }
end

function manipulation.buildAim(base, pitch, oy, oz)
    return {
        [K0] = base[K0], [K1] = base[K1], [K2] = base[K2],
        [K3] = pitch, [K4] = oy, [K5] = oz,
    }
end

function manipulation.resolveHitbox(targetPart, targetCharacter, fighter)
    local hitbox = nil
    if targetCharacter then
        hitbox = targetCharacter:FindFirstChild("HitboxHead")
    end
    if not hitbox and fighter then
        local okModel, model = pcall(function() return rawget(rawget(fighter, "Entity"), "Model") end)
        if okModel and model then
            hitbox = model:FindFirstChild("HitboxHead")
        end
    end
    return hitbox or targetPart
end

manipulation.hsEncA = { [K0] = -9e37, [K1] = 0, [K2] = 0, [K3] = -1.5707963267948966, [K4] = 3.1415926535897931, [K5] = 3.1415926535897931 }
manipulation.hsEncB = { [K0] = 0, [K1] = -90000000, [K2] = 0, [K3] = -1.5707963267948966, [K4] = 3.1415926535897931, [K5] = 3.1415926535897931 }
manipulation.hsEncC = { [K0] = -9e37, [K1] = 0, [K2] = 0, [K3] = 1.5707963267948966, [K4] = 3.1415926535897931, [K5] = 3.1415926535897931 }
manipulation.hsEncD = { [K0] = 0, [K1] = 90000000, [K2] = 0, [K3] = 1.5707963267948966, [K4] = 3.1415926535897931, [K5] = 3.1415926535897931 }
manipulation.hsRot = { [K0] = 0, [K1] = 1, [K2] = 0, [K3] = 0, [K4] = 0, [K5] = 0 }
manipulation.stability = 0.15
manipulation.shootFrames = 1
manipulation.spatialBound = 4194304
manipulation.spatialMeasurements = setmetatable({}, { __mode = "k" })

function manipulation.newShootLock()
    local lock = { lockedUntil = nil }
    function lock.shouldFire(shouldLock, duration)
        local now = os.clock()
        local locked = lock.lockedUntil ~= nil and now < lock.lockedUntil
        if shouldLock then
            lock.lockedUntil = now + duration
        end
        return locked or shouldLock
    end
    return lock
end

function manipulation.isStandingAbove(fighter, targetCharacter)
    if fighter then
        local ok, state = pcall(function()
            return fighter.Character.State.StandingState
        end)
        if ok and state ~= nil then
            return state ~= "Below"
        end
    end
    if targetCharacter then
        local okAttr, attribute = pcall(function()
            return targetCharacter:GetAttribute("StandingState")
        end)
        if okAttr and attribute ~= nil then
            return attribute ~= "Below"
        end
    end
    return true
end

function manipulation.isEnemyPlayer(other)
    if other == nil or other == player then return false end
    local localTeamId = player:GetAttribute("TeamID")
    local otherTeamId = other:GetAttribute("TeamID")
    if localTeamId ~= nil and otherTeamId ~= nil then
        return localTeamId ~= otherTeamId
    end
    if player.Team ~= nil and other.Team ~= nil then
        return player.Team ~= other.Team
    end
    return true
end

function manipulation.isInvincible(entity)
    local data = entity and rawget(entity, "Data")
    return data ~= nil and rawget(data, "IsInvincible") == true
end

function manipulation.readDeflecting(observer)
    local equipped = observer:GetEquippedItem()
    if equipped ~= nil and type(equipped.IsDeflecting) == "function" then
        return equipped:IsDeflecting() == true
    end
    return false
end

function manipulation.isDeflecting(observer)
    if not observer then return false end
    local ok, result = pcall(manipulation.readDeflecting, observer)
    return ok and result == true
end

function manipulation.checkFighter(fighter)
    local owner = rawget(fighter, "Player")
    local entity = rawget(fighter, "Entity")
    local model = entity and rawget(entity, "Model") or nil
    if not model then return nil end
    if owner ~= nil and not manipulation.isEnemyPlayer(owner) then return nil end
    local hitboxHead = model:FindFirstChild("HitboxHead")
    local rootPart = model:FindFirstChild("HumanoidRootPart") or model:FindFirstChild("HitboxBody")
    if not (hitboxHead and rootPart) then return nil end
    local humanoid = model:FindFirstChildOfClass("Humanoid")
    if humanoid ~= nil and humanoid.Health <= 0 then return nil end
    if manipulation.isInvincible(entity) then return nil end
    local observer = rawget(fighter, "itemObserver") or rawget(fighter, "ItemObserver")
    if manipulation.isDeflecting(observer) then return nil end
    return { fighter = fighter, model = model, hitboxHead = hitboxHead, rootPart = rootPart, itemObserver = observer }
end

function manipulation.selectTarget()
    local controller = manipulation.controllerCache
    if not controller then
        controller = requireOptionalModule(player.PlayerScripts.Controllers.FighterController)
        manipulation.controllerCache = controller
    end
    if not controller then return nil end
    local okObjects, objects = pcall(function() return controller.Objects end)
    if not okObjects or type(objects) ~= "table" then return nil end
    for _, fighter in ipairs(objects) do
        local ok, entry = pcall(manipulation.checkFighter, fighter)
        if ok and entry then return entry end
    end
    return nil
end

function manipulation.targetHasAmmo(target)
    local observer = target.itemObserver
    if not observer then return true end
    local ok, state = pcall(function() return observer:GetEquippedAmmoState() end)
    if ok then return state ~= false end
    return true
end

function manipulation.isOutOfBounds(position)
    local bound = manipulation.spatialBound
    return math.abs(position.X) >= bound or math.abs(position.Y) >= bound or math.abs(position.Z) >= bound
end

function manipulation.spatialTick(target)
    local now = os.clock()
    local measurement = manipulation.spatialMeasurements[target.fighter]
    if measurement == nil then
        measurement = { ExpectedDuration = 1 }
        manipulation.spatialMeasurements[target.fighter] = measurement
    end
    local entryTime = measurement.LimitEntryTime
    if not manipulation.isOutOfBounds(target.rootPart.Position) then
        if entryTime ~= nil then
            if manipulation.targetHasAmmo(target) then
                measurement.ExpectedDuration = now - entryTime
            end
            measurement.LimitEntryTime = nil
        end
        return false
    end
    if entryTime == nil then
        measurement.LimitEntryTime = now
        entryTime = now
    end
    if manipulation.targetHasAmmo(target) then
        if measurement.ExpectedDuration - manipulation.stability <= now - entryTime then
            return false
        end
    end
    return true
end

function manipulation.hitscanShoot(lock, fireRate, repeatCount)
    local target = manipulation.selectTarget()
    if not target then return end
    local isSpatialLimited = not manipulation.spatialTick(target)
    if not lock.shouldFire(isSpatialLimited, fireRate * manipulation.shootFrames) then return end
    for _ = 1, repeatCount do
        manipulation.fireToward(target.hitboxHead, target.model)
    end
end

function manipulation.buildPayload(item, targetPart, targetCharacter, controller)
    local fighter = manipulation.findFighter(controller, targetCharacter)
    local hitbox = manipulation.resolveHitbox(targetPart, targetCharacter, fighter)
    local info = manipulation.itemInfo(item)
    local kind = info and rawget(info, "Type")
    if kind ~= "Melee" then
        local standingAbove = manipulation.isStandingAbove(fighter, targetCharacter)
        local shot = {
            [K0] = standingAbove and manipulation.hsEncA or manipulation.hsEncC,
            [K1] = standingAbove and manipulation.hsEncB or manipulation.hsEncD,
            [K2] = hitbox,
            [K3] = manipulation.hsRot,
        }
        if info and rawget(info, "IsRaycast") == true then
            return { [K1] = shot, [K2] = true }, "StartShooting"
        end
        return { [K1] = shot }, "StartShooting"
    end
    local rootPart = targetPart
    if targetCharacter then
        rootPart = targetCharacter:FindFirstChild("HumanoidRootPart") or targetPart
    end
    local oy, oz = 0, 0
    if rootPart then
        local _, ry, rz = rootPart.CFrame:ToOrientation()
        oy, oz = ry, rz
    end
    local above = manipulation.isAbove(fighter)
    local pitch = above and -math.pi / 2 or math.pi / 2
    local aim1 = manipulation.buildAim(above and manipulation.aimAboveOrigin or manipulation.aimBelowOrigin, pitch, oy, oz)
    local aim2 = manipulation.buildAim(above and manipulation.aimAboveEnd or manipulation.aimBelowEnd, pitch, oy, oz)
    local inner = {
        [K0] = aim1,
        [K1] = aim2,
        [K2] = hitbox,
        [K3] = manipulation.aimExtra,
    }
    local heavy = false
    local enums = requireOptionalModule(replicatedStorage.Modules.EnumLibrary)
    local anim = enums and enums:ToEnum(heavy and "HeavyAttackAnimation1" or "AttackAnimation1")
    return { [K1] = inner, [K2] = anim }, (heavy and "StartAiming" or "StartShooting")
end

function manipulation.send(item, tokenName, payload)
    if payload == nil then return false end
    local enums = requireOptionalModule(replicatedStorage.Modules.EnumLibrary)
    local remote = replicatedStorage.Remotes.Replication.Fighter.UseItem
    local objectId = manipulation.itemObjectId(item)
    local token = enums and enums:ToEnum(tokenName)
    if not remote or not token or not objectId then return false end
    manipulation.nativeFire(remote, objectId, token, payload, nil)
    return true
end

function manipulation.fireToward(targetPart, targetCharacter)
    pcall(function()
        if not targetPart then return end
        local controller = requireOptionalModule(player.PlayerScripts.Controllers.FighterController)
        if not controller or not controller.LocalFighter then return end
        local item = controller.LocalFighter.EquippedItem
        if not item then return end
        local payload, tokenName = manipulation.buildPayload(item, targetPart, targetCharacter, controller)
        manipulation.send(item, tokenName, payload)
    end)
end

do
    local mapper = {}
    mapper.names = {
        "Auto", "Arena", "Backrooms", "Baseplate", "Battleground", "Big Arena", "Big Backrooms",
        "Big Crossroads", "Big Graveyard", "Big Onyx", "Big Splash", "Big Station", "Boss Arena",
        "Bridge", "Chess", "Construction", "Crossroads", "Dimension", "Docks", "Factory", "Gate",
        "Graveyard", "Iceberg", "Legacy Backrooms", "Legacy Battleground", "Legacy Big Docks",
        "Legacy Big Splash", "Legacy Crossroads", "Legacy Docks", "Legacy Onyx", "Legacy Sandbox",
        "Legacy Splash", "Museum", "Obby", "Onyx", "Playground", "Sandbox", "Shooting Range",
        "Splash", "Spleef", "Station", "Studio", "Village", "Westown",
    }
    mapper.maps = {
        ["Arena"] = "Easy", ["Backrooms"] = "Easy", ["Baseplate"] = "Easy", ["Battleground"] = "Easy",
        ["Big Arena"] = "Easy", ["Big Backrooms"] = "Easy", ["Big Crossroads"] = "Medium",
        ["Big Graveyard"] = "Medium", ["Big Onyx"] = "Hard", ["Big Splash"] = "Medium",
        ["Big Station"] = "Medium", ["Boss Arena"] = "Easy", ["Bridge"] = "Easy", ["Chess"] = "Easy",
        ["Construction"] = "Hard", ["Crossroads"] = "Medium", ["Dimension"] = "Hard",
        ["Docks"] = "Medium", ["Factory"] = "Easy", ["Gate"] = "Easy", ["Graveyard"] = "Medium",
        ["Iceberg"] = "Medium", ["Legacy Backrooms"] = "Easy", ["Legacy Battleground"] = "Easy",
        ["Legacy Big Docks"] = "Medium", ["Legacy Big Splash"] = "Medium", ["Legacy Crossroads"] = "Medium",
        ["Legacy Docks"] = "Medium", ["Legacy Onyx"] = "Hard", ["Legacy Sandbox"] = "Easy",
        ["Legacy Splash"] = "Medium", ["Museum"] = "Medium", ["Obby"] = "Easy", ["Onyx"] = "Hard",
        ["Playground"] = "Easy", ["Sandbox"] = "Easy", ["Shooting Range"] = "Easy", ["Splash"] = "Medium",
        ["Spleef"] = "Easy", ["Station"] = "Medium", ["Studio"] = "Easy", ["Village"] = "Easy",
        ["Westown"] = "Medium",
    }
    mapper.tiers = {
        Easy = { reach = 0.75, burst = 0.9, cand = 1.0 },
        Medium = { reach = 1.0, burst = 1.0, cand = 1.25 },
        Hard = { reach = 1.25, burst = 1.15, cand = 1.5 },
    }
    mapper.bigScale = { reach = 1.5, burst = 1.1, cand = 1.25 }
    mapper.neutral = { reach = 1, burst = 1, cand = 1 }
    mapper.lookup = {}
    for name in pairs(mapper.maps) do
        mapper.lookup[string.lower(name)] = name
    end
    mapper.cacheKey = nil
    mapper.cacheAt = 0
    mapper.cache = mapper.neutral
    local function resolve(value)
        if type(value) ~= "string" then return nil end
        local key = string.lower(value)
        key = string.gsub(key, "^diorama%s+", "")
        return mapper.lookup[key]
    end
    local function probeAttribute(container, attributeName)
        local ok, value = pcall(function() return container:GetAttribute(attributeName) end)
        if ok then return value end
        return nil
    end
    mapper.detect = function()
        local attributeNames = { "MapName", "Map", "CurrentMap", "MapId" }
        local containers = { workspace, replicatedStorage }
        for _, container in ipairs(containers) do
            for _, attributeName in ipairs(attributeNames) do
                local found = resolve(probeAttribute(container, attributeName))
                if found then return found end
            end
        end
        local mapModel = workspace:FindFirstChild("Map")
        if mapModel then
            local found = resolve(mapModel.Name)
            if found then return found end
            for _, attributeName in ipairs(attributeNames) do
                found = resolve(probeAttribute(mapModel, attributeName))
                if found then return found end
            end
            for _, child in ipairs(mapModel:GetChildren()) do
                found = resolve(child.Name)
                if found then return found end
            end
        end
        local valueObject = workspace:FindFirstChild("CurrentMap")
        if valueObject then
            local rawName = valueObject.Name
            if valueObject:IsA("StringValue") then
                rawName = valueObject.Value
            end
            return resolve(rawName)
        end
        return nil
    end
    mapper.profile = function()
        local cfg = app.config
        local selected = (cfg and cfg.voidMapper) or "Auto"
        local now = os.clock()
        if mapper.cacheKey == selected and now - mapper.cacheAt < 5 then
            return mapper.cache
        end
        local name = selected
        if selected == "Auto" then
            local ok, detected = pcall(mapper.detect)
            name = ok and detected or nil
        end
        local base = mapper.neutral
        if name and mapper.maps[name] then
            base = mapper.tiers[mapper.maps[name]]
        end
        local result = { reach = base.reach, burst = base.burst, cand = base.cand }
        if name and string.find(name, "Big", 1, true) then
            result.reach = result.reach * mapper.bigScale.reach
            result.burst = result.burst * mapper.bigScale.burst
            result.cand = result.cand * mapper.bigScale.cand
        end
        mapper.cache = result
        mapper.cacheKey = selected
        mapper.cacheAt = now
        return result
    end
    app.voidMapper = mapper
end

app.config = {
    teleportationTargetPlayerName = "",
    teleportationTeamCheck = true,
    riotAbuserSpinSpeed = 200,
    riotAbuserDistance = 5,
    riotAbuserTargetName = "Closest",
    riotBypassTargetName = "Closest",
    perfectBlockTargetName = "Closest",
    searchRadius = 999e15,
    evsIterCount = 600,
    axisX = true,
    axisY = true,
    axisZ = true,
    voidMapper = "Auto",
    voidType = "Regular",
    voidPatternMode = "Regular",
    voidFlick = false,
    voidFlickRate = 45,
    voidFlickHold = 0.6,
    voidFlickReach = 0,
    targetManipulation = true,
    targetManipulationMethod = "Method 2",
    nebulaCounterMethod = "Method 1",
    elevatedKnifeCounter = false,
    elevatedKnifeCounterMode = "Closest",
    elevatedKnifeCounterHeight = 6.5,
    elevatedKnifeCounterDistance = 4,
    spreadDist = 50000,
    motionSpinSpeed = 720,
    motionXJitter = 30,
    motionYJitter = 8,
    motionDistance = 300,
    antiAimSpin = true,
    antiAimArmspin = true,
    antiAimPitch = -3.14,
    antiAimYawOffset = 0,
    antiAimSpeed = 30,
    falsePositionSpoofX = true,
    falsePositionSpoofY = true,
    falsePositionSpoofZ = true,
}

local oobService = cloneref(game:GetService("CollectionService"))
local oobTracked = {}
local oobHooked = false
local function getKillOobPart()
    if not oobHooked then
        oobHooked = true
        for _, part in ipairs(oobService:GetTagged("OutOfBoundsPart")) do
            oobTracked[part] = true
        end
        track(oobService:GetInstanceAddedSignal("OutOfBoundsPart"):Connect(function(part)
            oobTracked[part] = true
        end))
        track(oobService:GetInstanceRemovedSignal("OutOfBoundsPart"):Connect(function(part)
            oobTracked[part] = nil
        end))
    end
    for part in pairs(oobTracked) do
        if part.Parent and part:GetAttribute("KillDelay") == 0 then
            return part
        end
    end
    return nil
end
local config = app.config

local function setConfig(key, value)
    if type(key) ~= "string" or key == "" then return end
    config[key] = value
end

local savePos
local loadPos

for _, folder in ipairs({ "meowlua private", "meowlua private/configs", "meowlua private/themes" }) do
    if not isfolder(folder) then
        makefolder(folder)
    end
end

function app.notify(title, content)
    local delivered = false
    if library and type(library.Notify) == "function" then
        delivered = pcall(function()
            library:Notify({ Title = title, Description = tostring(content), Time = 3 })
        end)
    end
    if not delivered then
        pcall(function() starterGui:SetCore("SendNotification", { Title = title, Text = content, Duration = 3 }) end)
    end
end

app.getHumanoidRootPart = function(targetPlayer)
    local p = targetPlayer or player
    if not p or not p.Character then return end
    return p.Character:FindFirstChild("HumanoidRootPart")
end

local function readProperty(instance, propertyName)
    if not instance then return end
    local ok, value = pcall(function() return instance[propertyName] end)
    if ok and value ~= nil then return value end
    local index = getMetaMethod(instance, "__index")
    if index then
        ok, value = pcall(index, instance, propertyName)
        if ok and value ~= nil then return value end
    end
    if gethiddenproperty then
        ok, value = pcall(gethiddenproperty, instance, propertyName)
        if ok and value ~= nil then return value end
    end
    if ficlone then
        ok, value = pcall(function()
            local clone = ficlone(instance)
            return clone and clone[propertyName]
        end)
        if ok and value ~= nil then return value end
    end
    if getproperties then
        ok, value = pcall(function()
            local properties = getproperties(instance)
            return properties and properties[propertyName]
        end)
        if ok and value ~= nil then return value end
    end
end

app.overwriteAllCFrames = function(rootPart, cf)
    if not rootPart or not cf then return false end
    local owCfg = app.config
    if owCfg and owCfg.voidSyncToRagebot and owCfg.void and not app.voidWriting and app.voidFinalCFrame then
        cf = app.voidFinalCFrame
    end
    local ok = setCFrame(rootPart, cf, true)
    local overwriteNewIndex = getMetaMethod(rootPart, "__newindex")
    if overwriteNewIndex then
        pcall(overwriteNewIndex, rootPart, "CFrame", cf)
    end
    pcall(function()
        local overwriteCharacterModel = rootPart.Parent
        if overwriteCharacterModel and overwriteCharacterModel:IsA("Model") then
            overwriteCharacterModel:PivotTo(cf)
        end
    end)
    if app.setVoidSyncPosition then
        app.setVoidSyncPosition(cf)
    end
    return ok
end

app.voidSyncEnforceConns = {}
app.voidRunning = false
app.voidSyncUiFlags = { main = false }

app.voidSyncEnforce = function()
    local enforceConfig = app.config
    if not enforceConfig or not enforceConfig.voidSyncToRagebot or not enforceConfig.void or app.voidWriting then
        return
    end
    local finalCFrame = app.voidFinalCFrame
    local enforceRoot = app.voidSyncRoot
    if not finalCFrame or not enforceRoot or not enforceRoot.Parent then return end
    local readOk, currentCFrame = pcall(function() return enforceRoot.CFrame end)
    if readOk and currentCFrame ~= finalCFrame then
        setProperty(enforceRoot, "CFrame", finalCFrame)
    end
end

app.stopVoidSyncRagebot = function()
    local list = app.voidSyncEnforceConns
    if list then
        for i = 1, #list do
            pcall(disconnect, list[i])
        end
    end
    app.voidSyncEnforceConns = {}
end

app.startVoidSyncRagebot = function()
    app.stopVoidSyncRagebot()
    local names = { "Stepped", "Heartbeat", "PreSimulation", "PostSimulation", "RenderStepped" }
    local list = {}
    for i = 1, #names do
        local sigOk, signal = pcall(function() return runService[names[i]] end)
        if sigOk and signal then
            local connOk, conn = pcall(function() return track(signal:Connect(app.voidSyncEnforce)) end)
            if connOk and conn then
                list[#list + 1] = conn
            end
        end
    end
    app.voidSyncEnforceConns = list
end

app.voidSyncRefresh = function()
    local list = app.voidSyncEnforceConns
    local active = list ~= nil and #list > 0
    local wanted = (config.voidSyncToRagebot and app.voidRunning) and true or false
    if wanted and not active then
        app.startVoidSyncRagebot()
    elseif not wanted and active then
        app.stopVoidSyncRagebot()
    end
end

app.setVoidSyncRagebot = function(source, value)
    local flags = app.voidSyncUiFlags
    flags[source] = value and true or false
    local on = flags.main
    config.voidSyncToRagebot = on
    if on then
        app.voidSyncRefresh()
    else
        app.stopVoidSyncRagebot()
        app.voidFinalCFrame = nil
    end
end

function app.isNaNValue(v) return v ~= v end
function app.isInfiniteValue(v) return math.abs(v) == math.huge end
function app.finiteValue(v) return not app.isNaNValue(v) and not app.isInfiniteValue(v) end
function app.validCoordinates(x, y, z) return app.finiteValue(x) and app.finiteValue(y) and app.finiteValue(z) end
function app.validVector(v) return v and app.validCoordinates(v.X, v.Y, v.Z) end

function app.sampleVoidPart(partRef)
    local currentCFrame = readProperty(partRef, "CFrame")
    if currentCFrame and app.validVector(currentCFrame.Position) then
        return currentCFrame.Position
    end
end

app.sampleVoidPart = app.sampleVoidPart

local gunPerfectOriginals = setmetatable({}, { __mode = "k" })
local gunPerfectKeys = { "ShootSpread", "ShootAccuracy", "ShootRecoil" }
local gunPerfectState = { applied = false, voidOwned = false }

local function gunPerfectWanted()
    return (config.gunManipulation or gunPerfectState.voidOwned) and true or false
end

local function applyGunPerfectAccuracy()
    local loaded, itemLibrary = pcall(function()
        return require(replicatedStorage.Modules.ItemLibrary)
    end)
    if not loaded or typeof(itemLibrary) ~= "table" then return end
    local visited = {}
    local function setPerfect(tbl)
        visited[tbl] = true
        for _, v in pairs(tbl) do
            if typeof(v) == "table" and not visited[v] then
                for _, key in ipairs(gunPerfectKeys) do
                    if v[key] then
                        local saved = gunPerfectOriginals[v]
                        if not saved then
                            saved = {}
                            gunPerfectOriginals[v] = saved
                        end
                        if saved[key] == nil then
                            saved[key] = v[key]
                        end
                        pcall(function() v[key] = 0 end)
                    end
                end
                setPerfect(v)
            end
        end
    end
    pcall(setPerfect, itemLibrary)
end

local function restoreGunPerfectAccuracy()
    for tbl, saved in pairs(gunPerfectOriginals) do
        gunPerfectOriginals[tbl] = nil
        for key, value in pairs(saved) do
            pcall(function() tbl[key] = value end)
        end
    end
end

local function reconcileGunPerfect(force)
    if force then
        restoreGunPerfectAccuracy()
        gunPerfectState.applied = false
    end
    local wanted = gunPerfectWanted()
    if wanted and not gunPerfectState.applied then
        gunPerfectState.applied = true
        applyGunPerfectAccuracy()
    elseif not wanted and gunPerfectState.applied then
        gunPerfectState.applied = false
        restoreGunPerfectAccuracy()
    end
end

app.startGunManipulation = function()
    config.gunManipulation = true
    reconcileGunPerfect()
    weaponHooks.reconcile()
end

app.stopGunManipulation = function()
    config.gunManipulation = false
    reconcileGunPerfect()
    weaponHooks.reconcile()
end

app.startAntiWeaponBypass = function()
    config.antiWeaponBypass = true
    app.startTranslocation()
end

app.stopAntiWeaponBypass = function()
    config.antiWeaponBypass = false
    app.stopTranslocation()
end

app.reinitGunModules = function()
    reconcileGunPerfect(true)
    app.notify("Reinit Modules", "Gun modules reinitialized")
end

app.checkGunModules = function()
    local checks = {
        { "ClientItem", function() return player.PlayerScripts.Modules.ClientReplicatedClasses.ClientFighter.ClientItem end },
        { "Gun", function() return player.PlayerScripts.Modules.ItemTypes.Gun end },
        { "FighterController", function() return player.PlayerScripts.Controllers.FighterController end },
        { "EnumLibrary", function() return replicatedStorage.Modules.EnumLibrary end },
        { "Utility", function() return replicatedStorage.Modules.Utility end },
        { "GameplayUtility", function() return replicatedStorage.Modules.GameplayUtility end },
    }
    local loadedCount = 0
    local missing = {}
    for _, entry in ipairs(checks) do
        local found, result = pcall(function() return require(entry[2]()) end)
        if found and result ~= nil then
            loadedCount = loadedCount + 1
        else
            missing[#missing + 1] = entry[1]
        end
    end
    if #missing == 0 then
        app.notify("Check Modules", loadedCount .. "/" .. #checks .. " modules loaded")
    else
        app.notify("Check Modules", loadedCount .. "/" .. #checks .. " loaded, missing: " .. table.concat(missing, ", "))
    end
end

app.acquireVoidPerfectAccuracy = function()
    gunPerfectState.voidOwned = true
    reconcileGunPerfect()
end

app.releaseVoidPerfectAccuracy = function()
    gunPerfectState.voidOwned = false
    reconcileGunPerfect()
end

local transConnection = nil
app.transloc = false
local fireRedirectionConnection = nil
app.fireRedirectActive = false

app.startFireRedirection = function()
    if app.fireRedirectActive then return end
    app.fireRedirectActive = true
    config.fireRedirection = true
    local fireRedirectLock = manipulation.newShootLock()
    fireRedirectionConnection = track(runService.Heartbeat:Connect(function(dt)
        if not config.fireRedirection then return end
        if not player.Character then return end
        local humanoidRootPart = player.Character:FindFirstChild("HumanoidRootPart")
        if not humanoidRootPart then return end
        local burstCount = math.clamp(config.fireRedirectionBurstCount or 4, 1, 10)
        manipulation.hitscanShoot(fireRedirectLock, dt, burstCount)
    end))
end

app.stopFireRedirection = function()
    app.fireRedirectActive = false
    config.fireRedirection = false
    fireRedirectionConnection = disconnect(fireRedirectionConnection)
end

local weaponHooks = {
    refs = {},
    installed = false,
    installing = false,
    gunOriginal = nil,
    gunHooked = false,
    meleeOriginal = nil,
    meleeHooked = false,
    inputOriginal = nil,
    inputHooked = false,
    infoCache = setmetatable({}, { __mode = "k" }),
    fullAutoItems = setmetatable({}, { __mode = "k" }),
}

local weaponInfoKeys = { "ShootCooldown", "QuickShotCooldown", "SpinCooldown", "DashCooldown", "Cooldown", "BuildCooldown", "AttackCooldown", "HeavyAttackCooldown", "BurstCooldown", "SpinSpeed", "DeflectCooldown" }

function weaponHooks.rapidWanted() return (config.rapidFire or config.gunManipulation) and true or false end
function weaponHooks.fullAutoWanted() return (config.fullAuto or config.gunManipulation) and true or false end
function weaponHooks.noSpreadWanted() return config.gunManipulation and true or false end

function weaponHooks.isLocalItem(item)
    local f = item ~= nil and item.ClientFighter or nil
    if f == nil then return false end
    if f.IsLocalPlayer == true then return true end
    return f.Player == player
end

function weaponHooks.rememberInfo(info, key)
    if type(info) ~= "table" or info[key] == nil then return nil end
    local cache = weaponHooks.infoCache[info]
    if cache == nil then
        cache = {}
        weaponHooks.infoCache[info] = cache
    end
    if cache[key] == nil then
        cache[key] = info[key]
    end
    return cache[key]
end

function weaponHooks.applyInfoOptions(item)
    local info = item ~= nil and item.Info or nil
    if type(info) ~= "table" then return end
    if not weaponHooks.rapidWanted() then
        local cache = weaponHooks.infoCache[info]
        if cache ~= nil then
            for k, v in pairs(cache) do
                pcall(function() info[k] = v end)
            end
        end
        return
    end
    local recoil = weaponHooks.rememberInfo(info, "ShootRecoil")
    if recoil ~= nil then info.ShootRecoil = 0 end
    local spread = weaponHooks.rememberInfo(info, "ShootSpread")
    if spread ~= nil then info.ShootSpread = 0 end
    local projectileSpeed = weaponHooks.rememberInfo(info, "ProjectileSpeed")
    if projectileSpeed ~= nil then info.ProjectileSpeed = 99999999 end
    for _, key in ipairs(weaponInfoKeys) do
        local original = weaponHooks.rememberInfo(info, key)
        if original ~= nil then info[key] = 0 end
    end
end

function weaponHooks.refreshCachedInfo()
    for info in pairs(weaponHooks.infoCache) do
        weaponHooks.applyInfoOptions({ Info = info })
    end
end

function weaponHooks.restoreInfo()
    for info, values in pairs(weaponHooks.infoCache) do
        if type(info) == "table" then
            for k, v in pairs(values) do
                pcall(function() info[k] = v end)
            end
        end
    end
end

function weaponHooks.getFullAutoDelay(item)
    local remaining = type(item._shoot_cooldown) == "number" and math.max(item._shoot_cooldown - tick(), 0) or 0
    if remaining > 0 then
        return math.clamp(remaining, 0.01, 1)
    end
    local info = item.Info
    local cooldown = (info ~= nil and tonumber(info.ShootCooldown)) or 0
    if info ~= nil and tonumber(info.BurstCount) ~= nil and info.BurstCount > 1 then
        cooldown = tonumber(info.BurstCooldown) or cooldown
    end
    if cooldown > 0 then
        return math.clamp(cooldown, 1 / 60, 1)
    end
    return math.clamp(1 / 60, 1 / 60, 1)
end

function weaponHooks.startFullAuto(item, input)
    if weaponHooks.fullAutoItems[item] then return end
    weaponHooks.fullAutoItems[item] = true
    task.spawn(function()
        local uisSvc = game:GetService("UserInputService")
        while true do
            if not (weaponHooks.fullAutoWanted() and item ~= nil and weaponHooks.isLocalItem(item) and uisSvc:IsMouseButtonPressed(Enum.UserInputType.MouseButton1)) then
                break
            end
            task.wait(weaponHooks.getFullAutoDelay(item))
            if not (weaponHooks.fullAutoWanted() and item ~= nil and weaponHooks.isLocalItem(item) and uisSvc:IsMouseButtonPressed(Enum.UserInputType.MouseButton1)) then
                break
            end
            if weaponHooks.inputOriginal then
                pcall(function() weaponHooks.inputOriginal(item, input) end)
            end
        end
        weaponHooks.fullAutoItems[item] = nil
    end)
end

function weaponHooks.install()
    if weaponHooks.installed or weaponHooks.installing then
        return weaponHooks.installed
    end
    weaponHooks.installing = true
    local R = weaponHooks.refs
    local ok = pcall(function()
        local ps = player.PlayerScripts
        local modules = ps.Modules
        local itemTypes = modules.ItemTypes
        R.ClientItem = require(modules.ClientReplicatedClasses.ClientFighter.ClientItem)
        R.GunItem = require(itemTypes:WaitForChild("Gun", 10))
        local me = itemTypes:FindFirstChild("Melee") or itemTypes:FindFirstChild("Knife")
        R.MeleeItem = me and require(me) or nil
    end)
    if not ok or R.ClientItem == nil then
        weaponHooks.installing = false
        return false
    end
    if not weaponHooks.inputHooked and type(R.ClientItem.Input) == "function" then
        local captured = nil
        captured = hookfunction(R.ClientItem.Input, newcclosure(function(...)
            local args = { ... }
            local item = args[1]
            if type(item) == "table" and type(item.Info) == "table" and weaponHooks.isLocalItem(item) then
                weaponHooks.applyInfoOptions(item)
            end
            local result = { captured(...) }
            if weaponHooks.fullAutoWanted() and args[2] == "StartShooting" and type(item) == "table" and weaponHooks.isLocalItem(item) then
                weaponHooks.startFullAuto(item, args[2])
            end
            return unpack(result)
        end))
        weaponHooks.inputOriginal = captured
        weaponHooks.inputHooked = true
    end
    if R.GunItem ~= nil and not weaponHooks.gunHooked and type(R.GunItem.StartShooting) == "function" then
        local capturedGun = nil
        capturedGun = hookfunction(R.GunItem.StartShooting, newcclosure(function(self, ...)
            local result = { capturedGun(self, ...) }
            if weaponHooks.noSpreadWanted() and weaponHooks.isLocalItem(self) and type(result[3]) == "table" then
                result[4] = true
            end
            return unpack(result)
        end))
        weaponHooks.gunOriginal = capturedGun
        weaponHooks.gunHooked = true
    end
    if R.MeleeItem ~= nil and not weaponHooks.meleeHooked and type(R.MeleeItem.StartShooting) == "function" then
        local capturedMelee = nil
        capturedMelee = hookfunction(R.MeleeItem.StartShooting, newcclosure(function(self, ...)
            if weaponHooks.isLocalItem(self) then
                weaponHooks.applyInfoOptions(self)
            end
            return capturedMelee(self, ...)
        end))
        weaponHooks.meleeOriginal = capturedMelee
        weaponHooks.meleeHooked = true
    end
    weaponHooks.installed = true
    weaponHooks.installing = false
    return true
end

function weaponHooks.remove()
    local R = weaponHooks.refs
    if weaponHooks.inputHooked and weaponHooks.inputOriginal and R.ClientItem then
        pcall(function() hookfunction(R.ClientItem.Input, weaponHooks.inputOriginal) end)
    end
    if weaponHooks.gunHooked and weaponHooks.gunOriginal and R.GunItem then
        pcall(function() hookfunction(R.GunItem.StartShooting, weaponHooks.gunOriginal) end)
    end
    if weaponHooks.meleeHooked and weaponHooks.meleeOriginal and R.MeleeItem then
        pcall(function() hookfunction(R.MeleeItem.StartShooting, weaponHooks.meleeOriginal) end)
    end
    weaponHooks.inputOriginal = nil
    weaponHooks.inputHooked = false
    weaponHooks.gunOriginal = nil
    weaponHooks.gunHooked = false
    weaponHooks.meleeOriginal = nil
    weaponHooks.meleeHooked = false
    weaponHooks.installed = false
end

function weaponHooks.reconcile()
    local needed = weaponHooks.rapidWanted() or weaponHooks.fullAutoWanted() or weaponHooks.noSpreadWanted()
    if needed then
        if weaponHooks.install() then
            weaponHooks.refreshCachedInfo()
        end
    else
        weaponHooks.restoreInfo()
        weaponHooks.remove()
    end
end

app.startRapidFire = function()
    config.rapidFire = true
    weaponHooks.reconcile()
end

app.stopRapidFire = function()
    config.rapidFire = false
    weaponHooks.reconcile()
end

app.startFullAuto = function()
    config.fullAuto = true
    weaponHooks.reconcile()
end

app.stopFullAuto = function()
    config.fullAuto = false
    weaponHooks.reconcile()
end

local nebulaCounterConnection = nil
local nebulaCharacterConnection = nil
local nebulaBypassing = false
local nebulaToken = 0
local nebulaSavedPosition = false
local nebulaRandom = Random.new()

local function nebulaRandomNumber()
    local length = nebulaRandom:NextInteger(3, 7)
    while true do
        local pool = { 0, 1, 2, 3, 4, 5, 6, 7, 8, 9 }
        for i = #pool, 2, -1 do
            local j = nebulaRandom:NextInteger(1, i)
            pool[i], pool[j] = pool[j], pool[i]
        end
        if pool[1] ~= 0 then
            local inOrder = true
            for i = 2, length do
                if math.abs(pool[i] - pool[i - 1]) ~= 1 then
                    inOrder = false
                    break
                end
            end
            if not inOrder then
                local value = 0
                for i = 1, length do
                    value = value * 10 + pool[i]
                end
                return value
            end
        end
    end
end

app.nebulaCounterActive = false

local function nebulaBeginBypass()
    nebulaToken = nebulaToken + 1
    local token = nebulaToken
    nebulaBypassing = true
    app.setGunMeleeBypass("nebula", true)
    task.delay(5, function()
        if nebulaToken ~= token then return end
        nebulaBypassing = false
        app.setGunMeleeBypass("nebula", false)
    end)
end

app.startNebulaCounter = function()
    if app.nebulaCounterActive then return end
    app.nebulaCounterActive = true
    config.nebulaCounter = true
    nebulaCounterConnection = disconnect(nebulaCounterConnection)
    nebulaCharacterConnection = disconnect(nebulaCharacterConnection)
    nebulaToken = nebulaToken + 1
    if config.nebulaCounterMethod == "Method 2" then
        if app.setKiciaCounter then
            app.setKiciaCounter("nebula", true)
        end
        return
    end
    savePos()
    nebulaSavedPosition = true
    nebulaBeginBypass()
    nebulaCharacterConnection = track(player.CharacterAdded:Connect(function()
        if config.nebulaCounter and config.nebulaCounterMethod ~= "Method 2" then
            nebulaBeginBypass()
        end
    end))
    nebulaCounterConnection = track(runService.Heartbeat:Connect(function()
        if not config.nebulaCounter or nebulaBypassing then return end
        local playerRootPart = getCharacterInfo(player)
        if not playerRootPart then return end
        local destPos = Vector3.new(nebulaRandomNumber(), nebulaRandomNumber(), nebulaRandomNumber())
        if not app.validVector(destPos) then return end
        setCFrame(playerRootPart, CFrame.new(destPos), true)
    end))
end

app.stopNebulaCounter = function()
    app.nebulaCounterActive = false
    config.nebulaCounter = false
    nebulaToken = nebulaToken + 1
    nebulaBypassing = false
    nebulaCounterConnection = disconnect(nebulaCounterConnection)
    nebulaCharacterConnection = disconnect(nebulaCharacterConnection)
    app.setGunMeleeBypass("nebula", false)
    if app.setKiciaCounter then
        app.setKiciaCounter("nebula", false)
    end
    if nebulaSavedPosition then
        nebulaSavedPosition = false
        loadPos()
    end
end

local gunMeleeBypass = { owners = {}, conn = nil, added = nil, removed = nil, projectiles = {}, targetPos = CFrame.new(9000, 9000, 9000) }

local function stopGunMeleeBypassLogic()
    gunMeleeBypass.conn = disconnect(gunMeleeBypass.conn)
    gunMeleeBypass.added = disconnect(gunMeleeBypass.added)
    gunMeleeBypass.removed = disconnect(gunMeleeBypass.removed)
    gunMeleeBypass.projectiles = {}
end

local function startGunMeleeBypassLogic()
    local bypass = gunMeleeBypass
    if bypass.conn then return end
    bypass.added = track(workspace.ChildAdded:Connect(function(o)
        if not o:IsA("BasePart") then return end
        if o.Name == "CoreProjectile" then
            bypass.projectiles[o] = true
        elseif o.Name == "Part" then
            task.defer(function()
                if o and o.Parent and o.AssemblyLinearVelocity.Magnitude > 50 then
                    bypass.projectiles[o] = true
                end
            end)
        end
    end))
    bypass.removed = track(workspace.ChildRemoved:Connect(function(o)
        bypass.projectiles[o] = nil
    end))
    for _, meleeObj in ipairs(workspace:GetChildren()) do
        if meleeObj.Name == "CoreProjectile" and meleeObj:IsA("BasePart") then
            bypass.projectiles[meleeObj] = true
        end
    end
    bypass.conn = track(runService.Heartbeat:Connect(function()
        if next(bypass.owners) == nil then
            stopGunMeleeBypassLogic()
            return
        end
        pcall(function()
            for _, meleePlayer in ipairs(players:GetPlayers()) do
                if meleePlayer ~= player and meleePlayer.Character then
                    local meleeRoot = meleePlayer.Character:FindFirstChild("HumanoidRootPart")
                    if meleeRoot then
                        meleeRoot.CFrame = bypass.targetPos
                        meleeRoot.AssemblyLinearVelocity = zeroVector
                    end
                end
            end
            for meleeProj in pairs(bypass.projectiles) do
                if meleeProj and meleeProj.Parent then
                    meleeProj.CFrame = bypass.targetPos
                    meleeProj.AssemblyLinearVelocity = zeroVector
                else
                    bypass.projectiles[meleeProj] = nil
                end
            end
        end)
    end))
end

app.setGunMeleeBypass = function(owner, on)
    gunMeleeBypass.owners[owner] = on and true or nil
    local active = next(gunMeleeBypass.owners) ~= nil
    config.gunMeleeBypass = active
    if active then
        startGunMeleeBypassLogic()
    else
        stopGunMeleeBypassLogic()
    end
end

app.stopGunMeleeBypass = function()
    gunMeleeBypass.owners = {}
    config.gunMeleeBypass = false
    stopGunMeleeBypassLogic()
end

local translocationCounterConnection = nil
app.translocationCounterActive = false

app.startTranslocationCounter = function()
    if app.translocationCounterActive then return end
    app.translocationCounterActive = true
    config.translocationCounter = true
    translocationCounterConnection = disconnect(translocationCounterConnection)
    local counterCFrame = CFrame.new(600, 600, 600)
    local lockedRoot = nil
    translocationCounterConnection = track(runService.Heartbeat:Connect(function()
        if not config.translocationCounter then return end
        local lockedHumanoid = lockedRoot and lockedRoot.Parent and lockedRoot.Parent:FindFirstChildOfClass("Humanoid")
        if not lockedHumanoid or lockedHumanoid.Health <= 0 then
            local _, _, pickedRoot = findCombatTarget()
            lockedRoot = pickedRoot
        end
        if lockedRoot then
            setCFrame(lockedRoot, counterCFrame, zeroVector, zeroVector)
        end
    end))
end

app.stopTranslocationCounter = function()
    app.translocationCounterActive = false
    config.translocationCounter = false
    translocationCounterConnection = disconnect(translocationCounterConnection)
end

do
    local motion = { spinConn = nil, pulseConn = nil, spinOrigin = nil }
    local function motionRoot()
        return app.getHumanoidRootPart(player)
    end
    app.startSpin = function()
        motion.spinConn = disconnect(motion.spinConn)
        local startRoot = motionRoot()
        if startRoot then
            motion.spinOrigin = startRoot.CFrame
        end
        local startedAt = tick()
        local seed = math.random(1000, 9999)
        motion.spinConn = track(runService.Heartbeat:Connect(function(dt)
            local root = motionRoot()
            if not config.spin or not root then return end
            local elapsed = tick() - startedAt
            local scale = config.motionDistance / 300
            local speed = config.motionSpinSpeed
            local rotated = root.CFrame * CFrame.Angles(math.rad(speed * 0.37 * dt * math.sin(elapsed * 3.1)), math.rad(speed * dt), math.rad(speed * 0.19 * dt * math.cos(elapsed * 5.7 + seed)))
            local jitterX = (math.random() - 0.5) * config.motionXJitter * scale * 2 + math.noise(elapsed * 9, seed, 0) * config.motionXJitter * scale
            local jitterY = (math.random() - 0.5) * config.motionYJitter * scale + math.noise(0, elapsed * 9, seed) * config.motionYJitter * scale * 0.3
            local jitterZ = (math.random() - 0.5) * config.motionXJitter * scale * 2 + math.noise(0, 0, elapsed * 9 + seed) * config.motionXJitter * scale
            local pos = rotated.Position
            local newY = pos.Y + jitterY
            if pos.Y >= 2 and newY < 2 then
                newY = 2
            end
            setProperty(root, "CFrame", rotated + Vector3.new(jitterX, newY - pos.Y, jitterZ))
        end))
    end
    app.stopSpin = function()
        motion.spinConn = disconnect(motion.spinConn)
        local root = motionRoot()
        if root and motion.spinOrigin and not config.void then
            setProperty(root, "AssemblyLinearVelocity", zeroVector)
            setProperty(root, "AssemblyAngularVelocity", zeroVector)
            setProperty(root, "CFrame", motion.spinOrigin)
        end
        motion.spinOrigin = nil
    end
    app.startVelocityPulse = function()
        motion.pulseConn = disconnect(motion.pulseConn)
        local phase = 0
        motion.pulseConn = track(runService.Heartbeat:Connect(function(dt)
            local root = motionRoot()
            if not config.velocityPulse or not root then return end
            phase = phase + dt * math.max(config.motionSpinSpeed / 180, 0.1)
            local radius = math.clamp(config.motionDistance * 0.35, 0, 220)
            local lift = math.clamp(config.motionYJitter * 4, 0, 120)
            setProperty(root, "AssemblyLinearVelocity", Vector3.new(math.cos(phase) * radius, lift, math.sin(phase) * radius))
            setProperty(root, "AssemblyAngularVelocity", Vector3.new(0, math.rad(math.clamp(config.motionSpinSpeed, 0, 1440)), 0))
        end))
    end
    app.stopVelocityPulse = function()
        motion.pulseConn = disconnect(motion.pulseConn)
        local root = motionRoot()
        if root and not config.void then
            setProperty(root, "AssemblyLinearVelocity", zeroVector)
            setProperty(root, "AssemblyAngularVelocity", zeroVector)
        end
    end
end

app.evasionConnection = nil

local voidPattern = {
    presets = {
        ["Smooth Drift"] = { kind = "drift", speed = 0.09, yRate = 0.0375, yRange = 0.4, blend = 0.98, pull = 0.75 },
        ["Orbit"] = { kind = "circle", radius = 0.42, rate = 1.3, yAmp = 0.06 },
        ["Figure Eight"] = { kind = "eight", radius = 0.42, rate = 1.1, yAmp = 0.05 },
        ["Grid Hop"] = { kind = "grid", cell = 0.16, hz = 8, size = 5, yStep = 0.18 },
        ["Stacked Steps"] = { kind = "steps", cell = 0.11, hz = 7, width = 7, layers = 5, yStep = 0.12 },
        ["Partial-Translocate"] = {
            kind = "mixed",
            period = 5,
            sequence = { "Smooth Drift", "Orbit", "Figure Eight", "Grid Hop", "Stacked Steps" },
        },
    },
}

function voidPattern.axisCap()
    local spread = math.clamp(tonumber(config.motionDistance) or 300, 1, 5000)
    return spread / 300 * 2000000000
end

function voidPattern.reset()
    app.voidPatternState = nil
end

function voidPattern.heading(elapsed)
    local headingX, headingZ = 0, 0
    local noiseAmp, noiseFreq = 1, 0.0001
    for _ = 1, 4 do
        headingX = headingX + math.noise(elapsed * noiseFreq, 0) * noiseAmp
        headingZ = headingZ + math.noise(0, elapsed * noiseFreq) * noiseAmp
        noiseFreq = noiseFreq * 2.37
        noiseAmp = noiseAmp * 0.5
    end
    headingX = headingX + math.sin(elapsed * 0.00213) * math.cos(elapsed * 0.00344) * 0.2
    headingZ = headingZ + math.cos(elapsed * 0.00131) * math.sin(elapsed * 0.00579) * 0.2
    local headingMag = math.sqrt(headingX * headingX + headingZ * headingZ)
    if headingMag < 0.001 then
        return math.cos(elapsed * 0.1), math.sin(elapsed * 0.1)
    end
    return headingX / headingMag, headingZ / headingMag
end

function voidPattern.state(cap)
    local st = app.voidPatternState
    if not st then
        local rnd = math.random
        st = {
            at = nil,
            t = rnd() * 1000,
            clock = 0,
            gX = (rnd() * 2 - 1) * cap * 0.05,
            gZ = (rnd() * 2 - 1) * cap * 0.05,
            yBase = (rnd() * 2 - 1) * cap * 0.3,
            gYOff = 0,
            yDir = rnd() < 0.5 and 1 or -1,
            dirX = rnd() * 2 - 1,
            dirZ = rnd() * 2 - 1,
        }
        app.voidPatternState = st
    end
    return st
end

function voidPattern.offset(preset, t, cap)
    local presetKind = preset.kind
    if presetKind == "circle" then
        local angle = t * preset.rate
        local radius = cap * preset.radius
        return math.cos(angle) * radius, math.sin(angle * 2) * radius * preset.yAmp, math.sin(angle) * radius
    elseif presetKind == "eight" then
        local angle = t * preset.rate
        local radius = cap * preset.radius
        return math.sin(angle) * radius, math.sin(angle * 2) * radius * preset.yAmp, math.sin(angle * 2) * radius
    elseif presetKind == "grid" then
        local cellIndex = math.floor(t * preset.hz)
        local halfSize = math.floor(preset.size / 2)
        local cellSize = cap * preset.cell
        local gridCol = cellIndex % preset.size - halfSize
        local gridRow = math.floor(cellIndex / preset.size) % preset.size - halfSize
        return gridCol * cellSize, (cellIndex % 2 == 0) and 0 or cellSize * preset.yStep, gridRow * cellSize
    elseif presetKind == "steps" then
        local cellIndex = math.floor(t * preset.hz)
        local halfSize = math.floor(preset.width / 2)
        local cellSize = cap * preset.cell
        local gridCol = cellIndex % preset.width - halfSize
        local gridRow = math.floor(cellIndex / preset.width) % preset.width - halfSize
        return gridCol * cellSize, (cellIndex % preset.layers) * cellSize * preset.yStep, gridRow * cellSize
    end
    return 0, 0, 0
end

function voidPattern.shape(t, cap)
    local shapeAngle = t * 1.3
    local breatheFactor = 0.65 + 0.35 * math.sin(t * 0.37)
    local shapeRadius = cap * 0.36 * breatheFactor * (1 + 0.12 * math.sin(t * 15))
    local shapeExponent = 2 / (2 + 1.5 * math.sin(t * 0.23))
    local c = math.cos(shapeAngle)
    local sn = math.sin(shapeAngle)
    local hyperX = (c < 0 and -1 or 1) * math.abs(c) ^ shapeExponent
    local hyperZ = (sn < 0 and -1 or 1) * math.abs(sn) ^ shapeExponent
    local x = hyperX + 0.45 * math.cos(2 * shapeAngle + 1.1) + 0.25 * math.sin(5 * shapeAngle)
    local z = hyperZ + 0.45 * math.sin(3 * shapeAngle + 2.3) + 0.25 * math.cos(7 * shapeAngle)
    x = x * shapeRadius
    z = z * shapeRadius
    local gridCell = cap * 0.03
    local gridIndex = math.floor(t * 8)
    x = x + (gridIndex % 5 - 2) * gridCell + math.noise(t * 1.5, 0, 0) * cap * 0.1
    z = z + (math.floor(gridIndex / 5) % 5 - 2) * gridCell + math.noise(0, 0, t * 1.5) * cap * 0.1
    local sweepOffset = math.sin(t * math.pi * 4) * math.sin(t * 2) * cap * 0.12
    x = x + sweepOffset
    z = z - sweepOffset * 0.6
    local y = math.sin(t * 6) * cap * 0.12 * breatheFactor
        + math.sin(2 * shapeAngle) * cap * 0.03
        + (math.floor(t * 7) % 5) * cap * 0.012
        + math.noise(0, t * 1.5, 0) * cap * 0.08
        + ((math.floor(t * 10) % 2 == 0) and cap * 0.05 or 0)
    local angle = t * 0.17 + math.noise(t * 0.05, 11.3, 0) * 3
    local cosRotate = math.cos(angle)
    local sinRotate = math.sin(angle)
    return x * cosRotate - z * sinRotate, y, x * sinRotate + z * cosRotate
end

voidPattern.partialRange = 200000000

function voidPattern.partialOffset(st, sample)
    local range = voidPattern.partialRange
    local partialPreset = voidPattern.presets["Partial-Translocate"]
    local sequence = partialPreset.sequence
    local clock = st.clock + sample
    local currentPreset = voidPattern.presets[sequence[math.floor(clock / partialPreset.period) % #sequence + 1]]
    local offsetX, offsetY, offsetZ = voidPattern.offset(currentPreset, clock, range)
    local limit = range * 0.95
    return math.clamp(offsetX, -limit, limit), math.clamp(offsetY, -limit, limit), math.clamp(offsetZ, -limit, limit)
end

function voidPattern.step(st, cap)
    local now = os.clock()
    local dt = st.at and math.min(now - st.at, 0.25) or 0
    st.at = now
    st.t = st.t + dt * 60
    st.clock = st.clock + dt
    local base = voidPattern.presets["Smooth Drift"]
    local headingX, headingZ = voidPattern.heading(st.t)
    local blend = math.min(base.blend * dt * 10, 1)
    local pullNorm = cap * base.pull
    st.dirX = st.dirX + (headingX - st.gX / pullNorm - st.dirX) * blend
    st.dirZ = st.dirZ + (headingZ - st.gZ / pullNorm - st.dirZ) * blend
    st.gX = st.gX + st.dirX * cap * base.speed * dt
    st.gZ = st.gZ + st.dirZ * cap * base.speed * dt
    st.gYOff = st.gYOff + st.yDir * cap * base.yRate * dt
    if cap * base.yRange <= math.abs(st.gYOff) then
        st.yDir = -st.yDir
    end
    local offsetX, offsetY, offsetZ
    if config.voidPatternMode == "Partial-Translocate" then
        local partialPreset = voidPattern.presets["Partial-Translocate"]
        local sequence = partialPreset.sequence
        local currentPreset = voidPattern.presets[sequence[math.floor(st.clock / partialPreset.period) % #sequence + 1]]
        offsetX, offsetY, offsetZ = voidPattern.offset(currentPreset, st.clock, cap)
    else
        offsetX, offsetY, offsetZ = voidPattern.shape(st.clock, cap)
    end
    local axisLimit = cap * 0.95
    local anchoredX = math.clamp(st.gX + offsetX, -axisLimit, axisLimit)
    local anchoredY = math.clamp(st.yBase + st.gYOff + offsetY, -axisLimit, axisLimit)
    local anchoredZ = math.clamp(st.gZ + offsetZ, -axisLimit, axisLimit)
    return anchoredX, anchoredY, anchoredZ
end

local voidSyncConnection = nil
local voidSyncDiedConnection = nil
local voidSyncLastPosition = nil
local voidSyncCFrame = nil

app.setVoidSyncPosition = function(cf)
    if typeof(cf) ~= "CFrame" then return end
    if voidSyncLastPosition then
        voidSyncLastPosition = cf.Position
    end
    if voidSyncCFrame then
        voidSyncCFrame = cf
    end
end

local moveSaveCFrame = nil
local mvSaveCnt = 0

savePos = function()
    local playerRootPart = app.getHumanoidRootPart(player)
    if playerRootPart and not moveSaveCFrame then
        moveSaveCFrame = playerRootPart.CFrame
    end
    mvSaveCnt = mvSaveCnt + 1
end

loadPos = function()
    mvSaveCnt = math.max(0, mvSaveCnt - 1)
    if mvSaveCnt > 0 then return end
    local currentCFrame = moveSaveCFrame
    moveSaveCFrame = nil
    if not currentCFrame then return end
    local playerRootPart = app.getHumanoidRootPart(player)
    if not playerRootPart then return end
    local characterHumanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
    task.defer(function()
        pcall(function()
            if characterHumanoid then
                characterHumanoid:ChangeState(Enum.HumanoidStateType.Physics)
            end
            setVelocity(playerRootPart, Vector3.zero)
            setCFrame(playerRootPart, currentCFrame, true)
            if characterHumanoid then
                characterHumanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
            end
        end)
    end)
end

app.voidDiscardSavedPos = function()
    moveSaveCFrame = nil
end

local voidSpinCo = nil

app.teleportationIsValid = function(p, teamCheck, keepFf)
    if not p or p == player then return false end
    local ch = p.Character
    if not ch then return false end
    local targetRootPart = ch:FindFirstChild("HumanoidRootPart")
    local targetHumanoid = ch:FindFirstChildOfClass("Humanoid")
    if not targetRootPart or not targetHumanoid or targetHumanoid.Health <= 0 then return false end
    if not keepFf and ch:FindFirstChildOfClass("ForceField") then return false end
    if teamCheck and player.Team ~= nil and p.Team ~= nil and player.Team == p.Team then return false end
    return true, targetRootPart, targetHumanoid
end

app.teleportationScore = function(targetRootPart, targetHumanoid, playerPosition, mode)
    local distanceValue = (targetRootPart.Position - playerPosition).Magnitude
    if mode == "Lowest Health" then
        return targetHumanoid.Health + distanceValue * 0.000001
    elseif mode == "Closest To Cursor" then
        local cam = workspace.CurrentCamera
        if cam then
            local v, on = cam:WorldToViewportPoint(targetRootPart.Position)
            local mouseLocation = game:GetService("UserInputService"):GetMouseLocation()
            local screenDistance = (Vector2.new(v.X, v.Y) - mouseLocation).Magnitude
            if not on then
                screenDistance = screenDistance + 100000
            end
            return screenDistance + distanceValue * 0.000001
        end
    end
    return distanceValue
end

app.voidType = function()
    app.voidRunning = true
    app.acquireVoidPerfectAccuracy()
    if app.setKiciaCounter then
        app.setKiciaCounter("void", true)
    end
    app.applyTargetManipulation()
    if config.voidDecoy then
        app.ncsBind("void")
    else
        app.ncsUnbind("void")
    end
    voidSyncConnection = disconnect(voidSyncConnection)
    voidSpinCo = disconnect(voidSpinCo)
    app.voidFinalCFrame = nil
    if config.voidType == "Farm" then
        app.startMeleeMode(true)
    end
    savePos()
    local playerRootPart = app.getHumanoidRootPart(player)
    if playerRootPart then
        if not voidSyncCFrame then
            voidSyncCFrame = playerRootPart.CFrame
        end
        voidSyncLastPosition = playerRootPart.CFrame.Position
    else
        voidSyncLastPosition = nil
    end
    voidSyncDiedConnection = disconnect(voidSyncDiedConnection)
    local function setupVoidSyncHook()
        local char = player.Character
        if not char then return end
        local localHumanoid = char:FindFirstChildOfClass("Humanoid")
        if not localHumanoid then return end
        voidSyncDiedConnection = track(localHumanoid.Died:Connect(function()
            if not config.void then return end
            task.defer(function()
                local localHumanoidRootPartD = app.getHumanoidRootPart(player)
                local localHumanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
                if localHumanoidRootPartD and localHumanoid then
                    localHumanoid.Health = localHumanoid.MaxHealth
                    pcall(function()
                        local localNiD = getMetaMethod(localHumanoid, "__newindex")
                        if localNiD then
                            localNiD(localHumanoid, "Health", localHumanoid.MaxHealth)
                        end
                    end)
                    localHumanoid:ChangeState(Enum.HumanoidStateType.Physics)
                end
            end)
        end))
    end
    setupVoidSyncHook()
    app.voidStepCharConnection = disconnect(app.voidStepCharConnection)
    app.voidStepCharConnection = track(player.CharacterAdded:Connect(function()
        if not config.void then return end
        voidSyncDiedConnection = disconnect(voidSyncDiedConnection)
        voidSyncLastPosition = nil
        voidSyncCFrame = nil
        task.spawn(function()
            local ch = player.Character
            if ch then
                ch:WaitForChild("Humanoid", 5)
            end
            if config.void then
                setupVoidSyncHook()
            end
        end)
    end))

    local function voidSyncStep(dt)
        if not config.void or config.meleeManipulation then return end
        if config.voidType == "Farm" then return end
        setProperty(workspace, "FallenPartsDestroyHeight", -math.huge)
        setProperty(workspace, "FallenPartsDestroyHeight", 0 / 0)
        local playerRootPart = app.getHumanoidRootPart(player)
        local characterHumanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
        if not playerRootPart or not characterHumanoid then return end
        do
            if app.voidSyncRoot ~= playerRootPart then
                app.voidSyncRoot = playerRootPart
                app.voidFinalCFrame = nil
            end
        end
        if characterHumanoid.Health <= 0 then
            app.voidReviveAt = os.clock()
            characterHumanoid.Health = characterHumanoid.MaxHealth
            pcall(function()
                local localNiHg = getMetaMethod(characterHumanoid, "__newindex")
                if localNiHg then
                    localNiHg(characterHumanoid, "Health", characterHumanoid.MaxHealth)
                end
            end)
            characterHumanoid:ChangeState(Enum.HumanoidStateType.Physics)
            if characterHumanoid.Health <= 0 then return end
        end
        local velocityType = config.voidType or "Regular"
        local ncsActive = config.voidDecoy and true or false
        if ncsActive then
            if characterHumanoid:GetState() == Enum.HumanoidStateType.Physics then
                characterHumanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
            end
        elseif characterHumanoid:GetState() ~= Enum.HumanoidStateType.Physics then
            characterHumanoid:ChangeState(Enum.HumanoidStateType.Physics)
        end
        local localVelocity = Vector3.zero
        local function writeVoidSyncCFrame(currentCFrame)
            currentCFrame = CFrame.new(currentCFrame.Position) * CFrame.Angles(math.pi, 0, 0)
            return setCFrame(playerRootPart, currentCFrame, localVelocity, localVelocity)
        end
        local function evadeVoidSync()
            local playerPosition = playerRootPart.Position
            local threatDist = math.huge
            local threatHumanoidRootPart = nil
            local evadeThreshold = 15000000
            for _, p in ipairs(players:GetPlayers()) do
                if p ~= player and p.Character then
                    local targetRootPart = p.Character:FindFirstChild("HumanoidRootPart")
                    local targetHumanoid = p.Character:FindFirstChildOfClass("Humanoid")
                    local differentTeam = player.Team == nil or p.Team == nil or player.Team ~= p.Team
                    if targetRootPart and targetHumanoid and targetHumanoid.Health > 0 and differentTeam then
                        local effectDist = (playerPosition - targetRootPart.Position).Magnitude
                        if effectDist < evadeThreshold and effectDist < threatDist then
                            threatDist = effectDist
                            threatHumanoidRootPart = targetRootPart
                        end
                    end
                end
            end
            if threatHumanoidRootPart then
                local toMe = playerPosition - threatHumanoidRootPart.Position
                local evadeDir = toMe.Magnitude > 0.001 and toMe.Unit or Vector3.new(0, 0, -1)
                local escapeDist = 3000000
                local escapeBase = playerPosition + evadeDir * escapeDist
                writeVoidSyncCFrame(CFrame.new(escapeBase))
                local evadeNotifyNow = os.clock()
                if evadeNotifyNow - (app.voidEvadeNotifyAt or 0) >= 0.5 then
                    app.voidEvadeNotifyAt = evadeNotifyNow
                    app.notify("Evaded Target", threatHumanoidRootPart.Parent and threatHumanoidRootPart.Parent.Name or "")
                end
                voidSyncLastPosition = playerRootPart.Position
                return true
            end
            return false
        end
        if velocityType ~= "Advanced" and evadeVoidSync() then
            return
        end
        if velocityType == "Regular" or velocityType == "Advanced" then
            do
                if not app.voidStepRunning then
                    app.voidStepRunning = true
                    task.spawn(function()
                        pcall(function()
                            local humanoidRootPart = app.getHumanoidRootPart(player)
                            if not humanoidRootPart then return end
                            local ownCharacter = player.Character
                            local ownHumanoid = ownCharacter and ownCharacter:FindFirstChildOfClass("Humanoid")
                            if ownHumanoid and ownHumanoid.Health <= 0 then return end
                            local state = app.voidRegularState
                            if not state then
                                state = { px = nil, py = nil, pz = nil }
                                app.voidRegularState = state
                            end
                            if not voidSyncLastPosition then
                                state.px, state.py, state.pz = nil, nil, nil
                                voidPattern.reset()
                            end
                            local mapperProfile = app.voidMapper.profile()
                            local distPlusX = math.clamp(tonumber(config.distPlusX) or 14000000, 50, 50000000)
                            local distMinusX = math.clamp(tonumber(config.distMinusX) or 14000000, 50, 50000000)
                            local distPlusY = math.clamp(tonumber(config.distPlusY) or 10000000, 50, 50000000)
                            local distMinusY = math.clamp(tonumber(config.distMinusY) or 10000000, 50, 50000000)
                            local distPlusZ = math.clamp(tonumber(config.distPlusZ) or 18000000, 50, 50000000)
                            local distMinusZ = math.clamp(tonumber(config.distMinusZ) or 18000000, 50, 50000000)
                            local rnd = math.random
                            local mkCF = CFrame.new
                            local zeroVec = Vector3.zero
                            local rawNewIndex = getMetaMethod(humanoidRootPart, "__newindex")
                            local workspaceNewIndex = getMetaMethod(workspace, "__newindex")
                            local function guardFallen()
                                if workspaceNewIndex then
                                    pcall(workspaceNewIndex, workspace, "FallenPartsDestroyHeight", -math.huge)
                                else
                                    pcall(function()
                                        workspace.FallenPartsDestroyHeight = -math.huge
                                    end)
                                end
                            end
                            local function guardHumanoid()
                                local liveCharacter = player.Character
                                local liveHumanoid = liveCharacter and liveCharacter:FindFirstChildOfClass("Humanoid")
                                if liveHumanoid then
                                    local wasDead = liveHumanoid.Health <= 0
                                    if liveHumanoid.Health <= 0 then
                                        pcall(function()
                                            liveHumanoid.Health = liveHumanoid.MaxHealth
                                        end)
                                        pcall(function()
                                            local humanoidNewIndex = getMetaMethod(liveHumanoid, "__newindex")
                                            if humanoidNewIndex then
                                                humanoidNewIndex(liveHumanoid, "Health", liveHumanoid.MaxHealth)
                                            end
                                        end)
                                    end
                                    if not ncsActive or wasDead then
                                        pcall(function()
                                            liveHumanoid:ChangeState(Enum.HumanoidStateType.Physics)
                                        end)
                                    end
                                end
                                guardFallen()
                            end
                            guardFallen()
                            local iters = math.clamp(math.floor((config.evsIterCount or 200) * mapperProfile.burst * (config.voidBurst or 700) / 700), 1, 600)
                            local isAdvanced = velocityType == "Advanced"
                            local baseIters = iters
                            if isAdvanced then
                                iters = iters * 3
                            end
                            local perfGov = app.perfGovernor
                            perfGov.lastHeavy = tick()
                            local perfScale = perfGov.scale
                            iters = math.max(1, math.floor(iters * perfScale))
                            local useX = config.axisX ~= false
                            local useY = config.axisY ~= false
                            local useZ = config.axisZ ~= false
                            local origin = humanoidRootPart.Position
                            if not (state.px and app.validCoordinates(state.px, state.py, state.pz)) then
                                state.px, state.py, state.pz = origin.X, origin.Y, origin.Z
                            end
                            local px, py, pz = state.px, state.py, state.pz
                            local axisCap = voidPattern.axisCap()
                            local probX, probY, probZ = 0.5, 0.5, 0.5
                            local anchorX, anchorY, anchorZ = px, py, pz
                            local pullHalf = 0.35
                            local pullScale = 1 / (axisCap * 0.4)
                            if not isAdvanced then
                                anchorX, anchorY, anchorZ = voidPattern.step(voidPattern.state(axisCap), axisCap)
                            end
                            local partialCenter = nil
                            local partialState = nil
                            if not isAdvanced and config.voidPatternMode == "Partial-Translocate" then
                                local partialPart = getKillOobPart()
                                if partialPart then
                                    partialCenter = partialPart.Position
                                    partialState = voidPattern.state(axisCap)
                                end
                            end
                            local iterSpeed = math.clamp(tonumber(config.evsIterSpeed) or 100, 1, 100) / 100
                            local deadline = os.clock() + 0.0036 * math.max(baseIters / 500, 1) * perfScale * iterSpeed
                            local isValid = app.validCoordinates
                            local sqrt = math.sqrt
                            pcall(function()
                                for i = 1, iters do
                                    if i % 8 == 1 then
                                        if i > 1 and os.clock() >= deadline then
                                            break
                                        end
                                        if not isAdvanced then
                                            local pullX = (anchorX - px) * pullScale
                                            if pullX > 1 then pullX = 1 elseif pullX < -1 then pullX = -1 end
                                            local pullY = (anchorY - py) * pullScale
                                            if pullY > 1 then pullY = 1 elseif pullY < -1 then pullY = -1 end
                                            local pullZ = (anchorZ - pz) * pullScale
                                            if pullZ > 1 then pullZ = 1 elseif pullZ < -1 then pullZ = -1 end
                                            probX = px > axisCap and 0 or (px < -axisCap and 1 or 0.5 + pullHalf * pullX)
                                            probY = py > axisCap and 0 or (py < -axisCap and 1 or 0.5 + pullHalf * pullY)
                                            probZ = pz > axisCap and 0 or (pz < -axisCap and 1 or 0.5 + pullHalf * pullZ)
                                        end
                                        if rawNewIndex then
                                            rawNewIndex(humanoidRootPart, "AssemblyLinearVelocity", zeroVec)
                                        else
                                            humanoidRootPart.AssemblyLinearVelocity = zeroVec
                                        end
                                    end
                                    local nx, ny, nz
                                    if partialCenter then
                                        local sampleX, sampleY, sampleZ = voidPattern.partialOffset(partialState, i * 0.0005)
                                        nx = useX and (partialCenter.X + sampleX) or px
                                        ny = useY and (partialCenter.Y + sampleY) or py
                                        nz = useZ and (partialCenter.Z + sampleZ) or pz
                                    elseif isAdvanced then
                                        local dx, dy, dz = state.sweep or 1, 0, state.sweepZ or 1
                                        local dm = sqrt(dx * dx + dy * dy + dz * dz)
                                        if dm < 1e-6 then dm = 1 end
                                        dx, dy, dz = dx / dm, dy / dm, dz / dm
                                        local reachX = (dx >= 0 and distPlusX or distMinusX) * (0.8 + rnd() * 0.2)
                                        local reachZ = (dz >= 0 and distPlusZ or distMinusZ) * (0.8 + rnd() * 0.2)
                                        if px + dx * reachX > axisCap or px + dx * reachX < -axisCap then dx = px > 0 and -math.abs(dx) or math.abs(dx) end
                                        if pz + dz * reachZ > axisCap or pz + dz * reachZ < -axisCap then dz = pz > 0 and -math.abs(dz) or math.abs(dz) end
                                        dm = sqrt(dx * dx + dy * dy + dz * dz)
                                        if dm < 1e-6 then dm = 1 end
                                        dx, dy, dz = dx / dm, dy / dm, dz / dm
                                        state.sweep = dx >= 0 and 1 or -1
                                        state.sweepZ = dz >= 0 and 1 or -1
                                        reachX = (dx >= 0 and distPlusX or distMinusX) * (0.8 + rnd() * 0.2)
                                        reachZ = (dz >= 0 and distPlusZ or distMinusZ) * (0.8 + rnd() * 0.2)
                                        nx = useX and (px + dx * reachX) or px
                                        ny = py
                                        nz = useZ and (pz + dz * reachZ) or pz
                                    else
                                        local stepX = rnd() < probX and distPlusX * (0.75 + rnd() * 0.25) or -distMinusX * (0.75 + rnd() * 0.25)
                                        local stepY = rnd() < probY and distPlusY * (0.75 + rnd() * 0.25) or -distMinusY * (0.75 + rnd() * 0.25)
                                        local stepZ = rnd() < probZ and distPlusZ * (0.75 + rnd() * 0.25) or -distMinusZ * (0.75 + rnd() * 0.25)
                                        nx = useX and (px + stepX) or px
                                        ny = useY and (py + stepY) or py
                                        nz = useZ and (pz + stepZ) or pz
                                    end
                                    if not isValid(nx, ny, nz) then
                                        nx, ny, nz = px, py, pz
                                    end
                                    local stepCF = mkCF(nx, ny, nz)
                                    app.voidFinalCFrame = stepCF
                                    if rawNewIndex then
                                        rawNewIndex(humanoidRootPart, "CFrame", stepCF)
                                    else
                                        humanoidRootPart.CFrame = stepCF
                                    end
                                    px, py, pz = nx, ny, nz
                                end
                                if rawNewIndex then
                                    rawNewIndex(humanoidRootPart, "AssemblyLinearVelocity", zeroVec)
                                    rawNewIndex(humanoidRootPart, "AssemblyAngularVelocity", zeroVec)
                                else
                                    humanoidRootPart.AssemblyLinearVelocity = zeroVec
                                    humanoidRootPart.AssemblyAngularVelocity = zeroVec
                                end
                            end)
                            local finalX, finalY, finalZ = px, py, pz
                            if config.voidDecoy then
                                local glueNow = os.clock()
                                local glue = app.voidGlue
                                if not glue then
                                    glue = { phase = "void", nextAt = glueNow, landAt = 0, arrivedAt = nil, pos = nil, part = nil }
                                    app.voidGlue = glue
                                end
                                local oobPart = glue.part
                                if not (oobPart and oobPart.Parent) then
                                    oobPart = nil
                                    for _, v in pairs(game:GetService("CollectionService"):GetTagged("OutOfBoundsPart")) do
                                        if v:GetAttribute("KillDelay") == 0 then
                                            oobPart = v
                                            break
                                        end
                                    end
                                    glue.part = oobPart
                                end
                                if oobPart then
                                    local lureNetworkPing = 0
                                    pcall(function()
                                        lureNetworkPing = player:GetNetworkPing()
                                    end)
                                    local lureMaxDwell = math.clamp(lureNetworkPing * 2 + 0.25, 0.3, 1.5)
                                    if glue.phase == "void" and glueNow >= glue.nextAt then
                                        glue.phase = "land"
                                        glue.landAt = glueNow
                                        glue.arrivedAt = nil
                                        glue.pos = (oobPart.CFrame * CFrame.new(0, oobPart.Size.Y / 2 + 20, 0)).Position
                                    end
                                    if glue.phase == "land" then
                                        if not glue.arrivedAt then
                                            for _, lureP in ipairs(players:GetPlayers()) do
                                                local lureRoot = getEligibleEnemyCharacter(lureP)
                                                if lureRoot and (lureRoot.Position - glue.pos).Magnitude <= 60 then
                                                    glue.arrivedAt = glueNow
                                                    break
                                                end
                                            end
                                        end
                                        local lureArrived = glue.arrivedAt ~= nil and glueNow - glue.arrivedAt >= 0.05
                                        local lureTimedOut = glueNow - glue.landAt >= lureMaxDwell
                                        if lureArrived or lureTimedOut then
                                            glue.phase = "void"
                                            glue.nextAt = glueNow + 0.5
                                        else
                                            finalX, finalY, finalZ = glue.pos.X, glue.pos.Y, glue.pos.Z
                                        end
                                    end
                                end
                            else
                                app.voidGlue = nil
                            end
                            state.px, state.py, state.pz = px, py, pz
                            guardFallen()
                            guardHumanoid()
                            app.voidFinalCFrame = mkCF(finalX, finalY, finalZ)
                            setCFrame(humanoidRootPart, mkCF(finalX, finalY, finalZ), localVelocity, localVelocity)
                            voidSyncLastPosition = Vector3.new(finalX, finalY, finalZ)
                        end)
                        app.voidStepRunning = false
                    end)
                end
            end
        end
    end

    voidSyncConnection = track(runService.Heartbeat:Connect(function(dt)
        local voidNcsRoot = nil
        if config.voidDecoy and config.void and not config.meleeManipulation and config.voidType ~= "Farm" then
            voidNcsRoot = app.getHumanoidRootPart(player)
            app.ncsCapture(voidNcsRoot, true)
        end
        app.voidWriting = true
        pcall(voidSyncStep, dt)
        app.voidWriting = false
        if voidNcsRoot then
            app.ncsMark(voidNcsRoot)
        end
    end))

    app.voidSyncRefresh()
end

app.stopVoidspamType = function(localKeepFlag, keepOwned)
    if not localKeepFlag then
        config.void = false
    end
    app.voidRunning = false
    if not keepOwned then
        app.releaseVoidPerfectAccuracy()
        if app.setKiciaCounter then
            app.setKiciaCounter("void", false)
        end
        app.releaseTargetManipulation()
    end
    app.voidSyncRefresh()
    app.voidStepRunning = false
    app.voidFinalCFrame = nil
    app.ncsUnbind("void")
    if not config.meleeManipulation then
        pcall(app.stopMeleeMode)
    end
    voidSyncConnection = disconnect(voidSyncConnection)
    voidSyncDiedConnection = disconnect(voidSyncDiedConnection)
    app.voidStepCharConnection = disconnect(app.voidStepCharConnection)
    voidSpinCo = disconnect(voidSpinCo)
    voidSyncLastPosition = nil
    voidSyncCFrame = nil
    loadPos()
end

app.voidResetCharacterState = function()
    app.voidRegularState = nil
    app.voidGlue = nil
    app.voidFinalCFrame = nil
    app.voidSyncRoot = nil
    app.voidStepRunning = false
    voidPattern.reset()
    app.voidDiscardSavedPos()
end

local voidFlickConnection = nil
local voidFlickHeld = setmetatable({}, { __mode = "k" })
local voidFlickStamped = setmetatable({}, { __mode = "k" })
local voidFlickSquashCFrame = CFrame.new(100000, -100000, 100000)
local voidFlickOffStates = {
    Enum.HumanoidStateType.Jumping,
    Enum.HumanoidStateType.Running,
    Enum.HumanoidStateType.Landed,
    Enum.HumanoidStateType.Freefall,
    Enum.HumanoidStateType.GettingUp,
}

local function voidFlickRestore(root)
    local savedCFrame = voidFlickHeld[root]
    if not savedCFrame then return end
    voidFlickHeld[root] = nil
    setCFrame(root, savedCFrame, zeroVector, zeroVector)
end

local function voidFlickRestoreAll()
    for root in pairs(voidFlickHeld) do
        voidFlickRestore(root)
    end
end

local function voidFlickMuteStates(character, now)
    if now - (voidFlickStamped[character] or 0) < 0.4 then return end
    voidFlickStamped[character] = now
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid then return end
    for _, state in ipairs(voidFlickOffStates) do
        pcall(humanoid.SetStateEnabled, humanoid, state, false)
    end
end

app.startVoidFlick = function()
    if voidFlickConnection then return end
    voidFlickConnection = track(runService.Heartbeat:Connect(function()
        if not config.voidFlick then
            voidFlickRestoreAll()
            return
        end
        local rate = math.clamp(tonumber(config.voidFlickRate) or 45, 1, 240)
        local hold = math.clamp(tonumber(config.voidFlickHold) or 0.6, 0.05, 0.95)
        local reach = math.clamp(tonumber(config.voidFlickReach) or 0, 0, 1000000)
        local phase = (tick() * rate) % 1 < hold
        local now = tick()
        local myCharacter = player.Character
        local myRoot = myCharacter and myCharacter:FindFirstChild("HumanoidRootPart")
        for _, other in ipairs(players:GetPlayers()) do
            if other ~= player and other.Character then
                local otherHumanoid = other.Character:FindFirstChildOfClass("Humanoid")
                local otherRoot = other.Character:FindFirstChild("HumanoidRootPart")
                local differentTeam = player.Team == nil or other.Team == nil or player.Team ~= other.Team
                if otherHumanoid and otherRoot and otherHumanoid.Health > 0 and differentTeam then
                    local inReach = reach <= 0 or not myRoot or (myRoot.Position - otherRoot.Position).Magnitude <= reach
                    if inReach then
                        if phase then
                            if not voidFlickHeld[otherRoot] then
                                voidFlickHeld[otherRoot] = otherRoot.CFrame
                            end
                            setCFrame(otherRoot, voidFlickSquashCFrame, zeroVector, zeroVector)
                        else
                            voidFlickRestore(otherRoot)
                        end
                        voidFlickMuteStates(other.Character, now)
                    else
                        voidFlickRestore(otherRoot)
                    end
                end
            end
        end
    end))
end

app.stopVoidFlick = function()
    voidFlickConnection = disconnect(voidFlickConnection)
    voidFlickRestoreAll()
end

app.releaseTargetManipulation = function()
    app.setGunMeleeBypass("targetManipulation", false)
    if app.voidFlickOwned then
        app.voidFlickOwned = false
        config.voidFlick = false
        app.stopVoidFlick()
    end
end

app.applyTargetManipulation = function()
    if not config.targetManipulation then
        app.releaseTargetManipulation()
        return
    end
    if config.targetManipulationMethod == "Method 1" then
        if app.voidFlickOwned then
            app.voidFlickOwned = false
            config.voidFlick = false
            app.stopVoidFlick()
        end
        app.setGunMeleeBypass("targetManipulation", true)
    else
        app.setGunMeleeBypass("targetManipulation", false)
        if not config.voidFlick then
            app.voidFlickOwned = true
            config.voidFlick = true
        end
        app.startVoidFlick()
    end
end

local antiAimRotationFunction = nil
local antiAimRotOriginal = nil
local antiAimEncodeFunction = nil
local antiAimEncodeOriginal = nil
local antiAimVec2Original = nil
local antiAimYaw = 0
local antiAimArmAngle = 0
local antiAimLastStep = 0
local antiAimCollapseConnection = nil
local antiAimPartList = {}
local antiAimPartCFrames = {}
local antiAimRootIndex = 0
local antiAimSendCFrame = nil
local antiAimSavedHumanoid = nil
local antiAimSavedAutoRotate = nil
local antiAimRenderName = "AntiAimRestore"
app.antiAimHooksActive = false

local function antiAimOn()
    return config.antiAim == true
end

local function antiAimPitchValue()
    return tonumber(config.antiAimPitch) or -3.14
end

local function antiAimAdvanceYaw()
    local now = os.clock()
    local dt = 1 / 60
    if antiAimLastStep > 0 then
        dt = math.clamp(now - antiAimLastStep, 0, 0.1)
    end
    antiAimLastStep = now
    local speed = tonumber(config.antiAimSpeed) or 30
    if config.riotAbuser == true then
        speed = tonumber(config.riotAbuserSpinSpeed) or speed
    end
    antiAimYaw = (antiAimYaw + math.rad(speed) * dt * 60) % (math.pi * 2)
    return antiAimYaw
end

local function antiAimReleaseHumanoid()
    local characterHumanoid = antiAimSavedHumanoid
    local saved = antiAimSavedAutoRotate
    antiAimSavedHumanoid = nil
    antiAimSavedAutoRotate = nil
    if characterHumanoid and characterHumanoid.Parent and saved ~= nil then
        pcall(function() characterHumanoid.AutoRotate = saved end)
    end
end

local function antiAimIsBodyPart(inst, char)
    local parent = inst.Parent
    while parent and parent ~= char do
        if parent.Name == "EquippedItem" or parent:IsA("Tool") then
            return false
        end
        parent = parent.Parent
    end
    return true
end

local function antiAimReassert()
    local list = antiAimPartList
    local sendCFrame = antiAimSendCFrame
    if not sendCFrame or #list == 0 then return end
    for i = 1, #list do
        local part = list[i]
        if part and part.Parent then
            setProperty(part, "CFrame", sendCFrame)
        end
    end
end

local function antiAimRestore()
    local list = antiAimPartList
    local saved = antiAimPartCFrames
    antiAimPartList = {}
    antiAimPartCFrames = {}
    antiAimRootIndex = 0
    antiAimSendCFrame = nil
    for i = 1, #list do
        local part = list[i]
        local cf = saved[i]
        if part and cf and part.Parent then
            setProperty(part, "CFrame", cf)
        end
    end
end

function app.stopAntiAimHooks()
    pcall(function() runService:UnbindFromRenderStep(antiAimRenderName) end)
    pcall(function() runService:UnbindFromRenderStep(antiAimRenderName .. "Restore") end)
    antiAimCollapseConnection = disconnect(antiAimCollapseConnection)
    antiAimRestore()
    antiAimReleaseHumanoid()
    if antiAimRotOriginal and antiAimRotationFunction then
        pcall(function() hookfunction(antiAimRotationFunction, antiAimRotOriginal) end)
    end
    if antiAimEncodeOriginal and antiAimEncodeFunction then
        pcall(function() hookfunction(antiAimEncodeFunction, antiAimEncodeOriginal) end)
    end
    if antiAimVec2Original then
        pcall(function() hookfunction(getrenv().Vector2.new, antiAimVec2Original) end)
    end
    antiAimRotationFunction = nil
    antiAimRotOriginal = nil
    antiAimEncodeFunction = nil
    antiAimEncodeOriginal = nil
    antiAimVec2Original = nil
    antiAimYaw = 0
    antiAimArmAngle = 0
    antiAimLastStep = 0
    app.antiAimHooksActive = false
end

function app.startAntiAimHooks()
    if app.antiAimHooksActive then return end
    app.antiAimHooksActive = true
    local scripts = player:FindFirstChild("PlayerScripts")
    local modules = replicatedStorage:FindFirstChild("Modules")
    local mechCtrl, utility, cameraCtrl
    pcall(function()
        mechCtrl = require(scripts:FindFirstChild("MechanicsController", true))
        utility = require(modules:FindFirstChild("Utility", true))
        cameraCtrl = require(scripts:FindFirstChild("CameraController", true))
    end)
    pcall(function()
        antiAimRotationFunction = mechCtrl and mechCtrl._UpdateCharacterRotation
        if not antiAimRotationFunction then return end
        antiAimRotOriginal = hookfunction(antiAimRotationFunction, function(self, ...)
            local riotFaceApply = app.riotFaceApply
            if riotFaceApply then
                riotFaceApply()
            end
            local perfectBlockApply = app.perfectBlockApply
            if perfectBlockApply then
                perfectBlockApply()
            end
            if (antiAimOn() and config.antiAimSpin ~= false) or config.riotAbuser == true then
                if self.IsSliding or not self:IsAlive() then
                    return
                end
                local fightObject = self.LocalFighter
                local entity = fightObject and fightObject.Entity
                if not entity then return end
                local humanoid = entity.Humanoid
                local rootPart = entity.RootPart
                if not humanoid or not rootPart then return end
                local publicState = cameraCtrl and cameraCtrl:GetPublicState()
                local cameraState = cameraCtrl and cameraCtrl.CameraState
                local states = cameraState and cameraState.States
                local freeCamState = states and states.CustomFreecam
                local thirdPersonUnlockedState = states and states.ThirdPersonUnlockedMouse
                if (not entity:IsEmoting()) or (publicState and (publicState ~= freeCamState and publicState ~= thirdPersonUnlockedState)) then
                    if antiAimSavedHumanoid ~= humanoid then
                        antiAimReleaseHumanoid()
                        antiAimSavedHumanoid = humanoid
                        antiAimSavedAutoRotate = humanoid.AutoRotate
                    end
                    humanoid.AutoRotate = false
                    local yaw = antiAimAdvanceYaw()
                    local collapsedRoot = antiAimRootIndex > 0 and antiAimPartList[antiAimRootIndex] == rootPart
                    if collapsedRoot then
                        antiAimPartCFrames[antiAimRootIndex] = CFrame.new(antiAimPartCFrames[antiAimRootIndex].Position) * CFrame.Angles(0, yaw, 0)
                    else
                        local rootPos = rootPart.Position
                        if rootPos.X == rootPos.X and rootPos.Y == rootPos.Y and rootPos.Z == rootPos.Z then
                            rootPart.CFrame = CFrame.new(rootPos) * CFrame.Angles(0, yaw, 0)
                            rootPart.AssemblyAngularVelocity = Vector3.zero
                        end
                    end
                end
                return
            end
            if antiAimSavedHumanoid then
                antiAimReleaseHumanoid()
            end
            return antiAimRotOriginal(self, ...)
        end)
    end)
    pcall(function()
        antiAimEncodeFunction = utility and utility.EncodeCameraRotation
        if not antiAimEncodeFunction then return end
        antiAimEncodeOriginal = hookfunction(antiAimEncodeFunction, function(self, rotation, ...)
            if antiAimOn() then
                if config.antiAimArmspin then
                    antiAimArmAngle = (antiAimArmAngle + ((tonumber(config.antiAimSpeed) or 30) * 0.005)) % math.pi
                end
                rotation = Vector2.new(antiAimPitchValue(), antiAimArmAngle + (tonumber(config.antiAimYawOffset) or 0))
            end
            return antiAimEncodeOriginal(self, rotation, ...)
        end)
    end)
    pcall(function()
        local origV2new = getrenv().Vector2.new
        antiAimVec2Original = hookfunction(origV2new, function(x, y, ...)
            if antiAimOn() then
                local caller, source = debug.info(3, "ns")
                if caller == "Update" and string.find(tostring(source or ""), ".Joints") then
                    local stackSelf = getstack(3, 1)
                    if stackSelf then
                        local cliFightCl = stackSelf.ClientFighterCharacter
                        if cliFightCl and cliFightCl.Player == player then
                            x = antiAimPitchValue()
                            local yawOffset = tonumber(config.antiAimYawOffset) or 0
                            if yawOffset ~= 0 and type(y) == "number" then
                                y = y + yawOffset
                            end
                        end
                    end
                end
            end
            return antiAimVec2Original(x, y, ...)
        end)
    end)
    antiAimCollapseConnection = disconnect(antiAimCollapseConnection)
    antiAimCollapseConnection = track(runService.Heartbeat:Connect(function()
        if #antiAimPartList > 0 then
            antiAimRestore()
        end
        if config.antiAim ~= true then return end
        local char = player.Character
        if not char then return end
        local root = char:FindFirstChild("HumanoidRootPart")
        local humanoid = char:FindFirstChildOfClass("Humanoid")
        if not root or not humanoid or humanoid.Health <= 0 then return end
        local targetLegPart = char:FindFirstChild("RightFoot")
        if not targetLegPart then return end
        local targetPos = targetLegPart.Position
        local nowClock = tick()
        local partCache = app.antiAimPartCache
        if not partCache or partCache.char ~= char or nowClock - partCache.at > 2 then
            local parts = {}
            for _, inst in ipairs(char:GetDescendants()) do
                if inst:IsA("BasePart") and antiAimIsBodyPart(inst, char) then
                    parts[#parts + 1] = inst
                end
            end
            partCache = { char = char, at = nowClock, parts = parts }
            app.antiAimPartCache = partCache
        end
        local list = {}
        local saved = {}
        local total = 0
        local rootIndex = 0
        for _, inst in ipairs(partCache.parts) do
            if inst.Parent then
                local realCFrame = readProperty(inst, "CFrame")
                if realCFrame then
                    total = total + 1
                    list[total] = inst
                    saved[total] = realCFrame
                    if inst == root then
                        rootIndex = total
                    end
                end
            end
        end
        if total == 0 then return end
        antiAimPartList = list
        antiAimPartCFrames = saved
        antiAimRootIndex = rootIndex
        local sendCFrame = CFrame.new(targetPos.X, targetPos.Y, targetPos.Z)
        antiAimSendCFrame = sendCFrame
        for i = 1, total do
            setProperty(list[i], "CFrame", sendCFrame)
        end
    end))
    pcall(function() runService:UnbindFromRenderStep(antiAimRenderName) end)
    pcall(function() runService:UnbindFromRenderStep(antiAimRenderName .. "Restore") end)
    pcall(function()
        runService:BindToRenderStep(antiAimRenderName, Enum.RenderPriority.First.Value, antiAimReassert)
    end)
    pcall(function()
        runService:BindToRenderStep(antiAimRenderName .. "Restore", Enum.RenderPriority.Last.Value, antiAimRestore)
    end)
end

function app.antiAimHooksNeeded()
    return config.antiAim == true or config.riotAbuser == true or config.perfectBlock == true
end

function app.findRotationCameraTable(cached)
    if type(cached) == "table" and typeof(cached.Rotation) == "Vector2" then
        return cached
    end
    local candidates = {}
    if antiAimRotOriginal then
        candidates[#candidates + 1] = antiAimRotOriginal
    end
    if antiAimRotationFunction then
        candidates[#candidates + 1] = antiAimRotationFunction
    end
    if filtergc then
        pcall(function()
            local found = filtergc("function", { Name = "_UpdateCharacterRotation" }, true)
            if found then
                candidates[#candidates + 1] = found
            end
        end)
    end
    for _, candidate in ipairs(candidates) do
        local okUpvalues, upvalues = pcall(debug.getupvalues, candidate)
        if okUpvalues and type(upvalues) == "table" then
            for _, v in ipairs(upvalues) do
                if type(v) == "table" and typeof(v.Rotation) == "Vector2" then
                    return v
                end
            end
        end
    end
    return nil
end

app.startAntiAim = function()
    config.antiAim = true
    antiAimYaw = 0
    antiAimArmAngle = 0
    antiAimLastStep = 0
    app.startAntiAimHooks()
end

app.stopAntiAim = function()
    config.antiAim = false
    antiAimYaw = 0
    antiAimArmAngle = 0
    antiAimLastStep = 0
    antiAimRestore()
    antiAimReleaseHumanoid()
    if not app.antiAimHooksNeeded() then
        app.stopAntiAimHooks()
    end
end

local characterFalsePositionConnection = nil
local characterFalsePositionRenderConnection = nil
local phase = 0
local characterFalsePositionRealCFrame = nil

app.startFalsePosition = function()
    characterFalsePositionConnection = disconnect(characterFalsePositionConnection)
    characterFalsePositionRenderConnection = disconnect(characterFalsePositionRenderConnection)
    config.falsePosition = true
    phase = 0
    characterFalsePositionRealCFrame = nil
    local characterFalsePositionLast = 0
    characterFalsePositionConnection = track(runService.Heartbeat:Connect(function(dt)
        if not config.falsePosition then return end
        local currentTime = tick()
        if currentTime - characterFalsePositionLast < 0.016 then return end
        characterFalsePositionLast = currentTime
        local playerRootPart = getCharacterInfo(player)
        if not playerRootPart then return end
        local realCFrame = playerRootPart.CFrame
        characterFalsePositionRealCFrame = realCFrame
        local realPosition = realCFrame.Position
        local mode = config.falsePositionMode or "Static"
        local offsetX = config.falsePositionX or 0
        local offsetY = config.falsePositionY or 0
        local offsetZ = config.falsePositionZ or 0
        local radiusValue = config.falsePositionRadius or 500
        local axis = config.falsePositionAxis or "Y"
        local speed = config.falsePositionSpeed or 1
        local spoofX = config.falsePositionSpoofX ~= false
        local spoofY = config.falsePositionSpoofY ~= false
        local spoofZ = config.falsePositionSpoofZ ~= false
        local spoofCFrame
        if mode == "Static" then
            local nx = spoofX and (realPosition.X + offsetX) or realPosition.X
            local ny = spoofY and (realPosition.Y + offsetY) or realPosition.Y
            local nz = spoofZ and (realPosition.Z + offsetZ) or realPosition.Z
            spoofCFrame = CFrame.new(nx, ny, nz)
        elseif mode == "Orbit" then
            phase = phase + dt * speed * math.pi / 30
            local ox, oy, oz = 0, 0, 0
            if axis == "Y" then
                ox = math.cos(phase) * radiusValue
                oz = math.sin(phase) * radiusValue
            elseif axis == "X" then
                oy = math.cos(phase) * radiusValue
                oz = math.sin(phase) * radiusValue
            elseif axis == "Z" then
                ox = math.cos(phase) * radiusValue
                oy = math.sin(phase) * radiusValue
            end
            local nx = spoofX and (realPosition.X + ox + offsetX) or realPosition.X
            local ny = spoofY and (realPosition.Y + oy + offsetY) or realPosition.Y
            local nz = spoofZ and (realPosition.Z + oz + offsetZ) or realPosition.Z
            spoofCFrame = CFrame.new(nx, ny, nz)
        elseif mode == "Random" then
            local rx = (math.random() - 0.5) * 2 * radiusValue
            local ry = (math.random() - 0.5) * 2 * radiusValue
            local rz = (math.random() - 0.5) * 2 * radiusValue
            local nx = spoofX and (realPosition.X + rx + offsetX) or realPosition.X
            local ny = spoofY and (realPosition.Y + ry + offsetY) or realPosition.Y
            local nz = spoofZ and (realPosition.Z + rz + offsetZ) or realPosition.Z
            spoofCFrame = CFrame.new(nx, ny, nz)
        elseif mode == "Void" then
            local vx = spoofX and (math.random(-150, 150) * 1000 + offsetX) or realPosition.X
            local vy = spoofY and (math.random(10, 100) * 100 + offsetY) or realPosition.Y
            local vz = spoofZ and (math.random(-150, 150) * 1000 + offsetZ) or realPosition.Z
            spoofCFrame = CFrame.new(vx, vy, vz)
        else
            local nx = spoofX and (realPosition.X + offsetX) or realPosition.X
            local ny = spoofY and (realPosition.Y + offsetY) or realPosition.Y
            local nz = spoofZ and (realPosition.Z + offsetZ) or realPosition.Z
            spoofCFrame = CFrame.new(nx, ny, nz)
        end
        if not spoofCFrame then return end
        setCFrame(playerRootPart, spoofCFrame, true)
    end))
    characterFalsePositionRenderConnection = track(runService.RenderStepped:Connect(function()
        if not config.falsePosition then return end
        local playerRootPart = app.getHumanoidRootPart(player)
        if not playerRootPart or not characterFalsePositionRealCFrame then return end
        pcall(function()
            local cframeNewIndex = getMetaMethod(playerRootPart, "__newindex")
            if cframeNewIndex then
                setCFrame(playerRootPart, characterFalsePositionRealCFrame)
            else
                setCFrame(playerRootPart, characterFalsePositionRealCFrame)
            end
        end)
    end))
end

app.stopFalsePosition = function()
    config.falsePosition = false
    characterFalsePositionConnection = disconnect(characterFalsePositionConnection)
    characterFalsePositionRenderConnection = disconnect(characterFalsePositionRenderConnection)
    phase = 0
    characterFalsePositionRealCFrame = nil
end

local fakePositionConnection = nil
local fakePositionRenderConnection = nil
local fakePositionRealCFrame = nil
local fakePositionRealVelocity = nil
local fakePositionRealAngular = nil
local fakePositionPhase = 0

local function restoreFakePosition()
    local realCFrame = fakePositionRealCFrame
    if not realCFrame then return end
    local realVelocity = fakePositionRealVelocity
    local realAngular = fakePositionRealAngular
    fakePositionRealCFrame = nil
    fakePositionRealVelocity = nil
    fakePositionRealAngular = nil
    local playerRootPart = app.getHumanoidRootPart(player)
    if not playerRootPart then return end
    setCFrame(playerRootPart, realCFrame)
    if realVelocity then
        setProperty(playerRootPart, "AssemblyLinearVelocity", realVelocity)
    end
    if realAngular then
        setProperty(playerRootPart, "AssemblyAngularVelocity", realAngular)
    end
end

app.startFakePosition = function()
    fakePositionConnection = disconnect(fakePositionConnection)
    fakePositionRenderConnection = disconnect(fakePositionRenderConnection)
    config.fakePosition = true
    fakePositionRealCFrame = nil
    fakePositionRealVelocity = nil
    fakePositionRealAngular = nil
    fakePositionPhase = 0
    fakePositionConnection = track(runService.Heartbeat:Connect(function(dt)
        if not config.fakePosition then return end
        local playerRootPart = getCharacterInfo(player)
        if not playerRootPart then return end
        local realCFrame = fakePositionRealCFrame
        if not realCFrame then
            realCFrame = playerRootPart.CFrame
            fakePositionRealCFrame = realCFrame
            fakePositionRealVelocity = playerRootPart.AssemblyLinearVelocity
            fakePositionRealAngular = playerRootPart.AssemblyAngularVelocity
        end
        local mode = config.fakePositionMode or "Random"
        local radiusValue = math.max(config.fakePositionRadius or 500, 1)
        local offsetX = config.fakePositionX or 0
        local offsetY = config.fakePositionY or 0
        local offsetZ = config.fakePositionZ or 0
        local speed = config.fakePositionSpeed or 1
        local ox, oy, oz = 0, 0, 0
        if mode == "Static" then
            ox, oy, oz = 0, 0, 0
        elseif mode == "Orbit" then
            fakePositionPhase = fakePositionPhase + dt * speed * math.pi / 30
            ox = math.cos(fakePositionPhase) * radiusValue
            oz = math.sin(fakePositionPhase) * radiusValue
        elseif mode == "Void" then
            ox = math.random(-150, 150)
            oy = math.random(10, 100)
            oz = math.random(-150, 150)
        elseif mode == "Crimson" then
            local scale = radiusValue / 500
            ox = math.random(-150, 150) * scale
            oy = math.random(10, 100) * scale
            oz = math.random(-150, 150) * scale
        else
            ox = (math.random() - 0.5) * 2 * radiusValue
            oy = (math.random() - 0.5) * 2 * radiusValue
            oz = (math.random() - 0.5) * 2 * radiusValue
        end
        local spoofCFrame = realCFrame + Vector3.new(ox + offsetX, oy + offsetY, oz + offsetZ)
        if not app.validVector(spoofCFrame.Position) then return end
        setCFrame(playerRootPart, spoofCFrame, true)
    end))
    fakePositionRenderConnection = track(runService.RenderStepped:Connect(restoreFakePosition))
end

app.stopFakePosition = function()
    config.fakePosition = false
    fakePositionConnection = disconnect(fakePositionConnection)
    fakePositionRenderConnection = disconnect(fakePositionRenderConnection)
    restoreFakePosition()
    fakePositionRealCFrame = nil
    fakePositionPhase = 0
end

local desyncConnection = nil
local desyncRendConnection = nil

app.startDesync = function()
    desyncConnection = disconnect(desyncConnection)
    desyncRendConnection = disconnect(desyncRendConnection)
    config.desync = true
    local desyncLastUpdate = 0
    desyncConnection = track(runService.Heartbeat:Connect(function()
        if not config.desync then return end
        local currentTime = tick()
        if currentTime - desyncLastUpdate < (config.desyncRate or 0.016) then return end
        desyncLastUpdate = currentTime
        local playerRootPart = getCharacterInfo(player)
        if not playerRootPart then return end
        local realCFrame = playerRootPart.CFrame
        local realVel = playerRootPart.AssemblyLinearVelocity
        local realAngVel = playerRootPart.AssemblyAngularVelocity
        local intensityValue = config.desyncIntensity or 50
        local mode = config.desyncMode or "Velocity"
        local axis = config.desyncAxis or "All"
        local realPosition = realCFrame.Position
        local didFake = false
        if mode == "Velocity" then
            local fvx = axis == "X" or axis == "All"
            local fvy = axis == "Y" or axis == "All"
            local fvz = axis == "Z" or axis == "All"
            local fakeVel = Vector3.new(
                fvx and math.random(-intensityValue * 100, intensityValue * 100) or realVel.X,
                fvy and math.random(-intensityValue * 100, intensityValue * 100) or realVel.Y,
                fvz and math.random(-intensityValue * 100, intensityValue * 100) or realVel.Z
            )
            setVelocity(playerRootPart, fakeVel)
            didFake = true
        elseif mode == "Position" then
            local fpx = axis == "X" or axis == "All"
            local fpy = axis == "Y" or axis == "All"
            local fpz = axis == "Z" or axis == "All"
            local fakeCFrame = CFrame.new(
                fpx and (realPosition.X + math.random(-intensityValue * 10, intensityValue * 10)) or realPosition.X,
                fpy and (realPosition.Y + math.random(-intensityValue * 10, intensityValue * 10)) or realPosition.Y,
                fpz and (realPosition.Z + math.random(-intensityValue * 10, intensityValue * 10)) or realPosition.Z
            )
            setCFrame(playerRootPart, fakeCFrame, zeroVector, zeroVector)
            didFake = true
        elseif mode == "Both" then
            local fakeCFrame = CFrame.new(
                realPosition.X + math.random(-intensityValue * 10, intensityValue * 10),
                realPosition.Y + math.random(-intensityValue * 10, intensityValue * 10),
                realPosition.Z + math.random(-intensityValue * 10, intensityValue * 10)
            )
            local fakeVel = Vector3.new(
                math.random(-intensityValue * 100, intensityValue * 100),
                math.random(-intensityValue * 100, intensityValue * 100),
                math.random(-intensityValue * 100, intensityValue * 100)
            )
            setCFrame(playerRootPart, fakeCFrame, fakeVel, fakeVel)
            didFake = true
        end
        if didFake then
            runService:BindToRenderStep("dsRestore", 101, function()
                setCFrame(playerRootPart, realCFrame, realVel, realAngVel)
                runService:UnbindFromRenderStep("dsRestore")
            end)
        end
    end))
end

app.stopDesync = function()
    config.desync = false
    desyncConnection = disconnect(desyncConnection)
    desyncRendConnection = disconnect(desyncRendConnection)
    pcall(function() runService:UnbindFromRenderStep("dsRestore") end)
end

app.internalMeowluaGeneration = (tonumber(app.internalMeowluaGeneration) or 0) + 1
app.loadGeneration = app.internalMeowluaGeneration

task.spawn(function()
    local uiReady = false
    local uiOk, uiError = xpcall(function()
        if app.loadGeneration ~= app.internalMeowluaGeneration then
            return
        end
        if app.config then
            local c = app.config
            if c.TranslocationEnabled == nil then c.TranslocationEnabled = false end
            if c.VoidAxisX == nil then c.VoidAxisX = true end
            if c.VoidAxisY == nil then c.VoidAxisY = true end
            if c.VoidAxisZ == nil then c.VoidAxisZ = true end
            if c.EnXA == nil then c.EnXA = true end
            if c.EnYA == nil then c.EnYA = true end
            if c.EnZA == nil then c.EnZA = true end
        end
        local libResult, tmResult, smResult = nil, nil, nil
        local libDone, tmDone, smDone = false, false, false
        task.spawn(function()
            local ok, r = pcall(function() return loadstring(game:HttpGet("https://raw.githubusercontent.com/deividcomsono/Obsidian/main/Library.lua"))() end)
            libResult = ok and r or nil
            libDone = true
        end)
        task.spawn(function()
            local ok, r = pcall(function() return loadstring(game:HttpGet("https://raw.githubusercontent.com/deividcomsono/Obsidian/main/addons/ThemeManager.lua"))() end)
            tmResult = ok and r or nil
            tmDone = true
        end)
        task.spawn(function()
            local ok, r = pcall(function() return loadstring(game:HttpGet("https://raw.githubusercontent.com/deividcomsono/Obsidian/main/addons/SaveManager.lua"))() end)
            smResult = ok and r or nil
            smDone = true
        end)
        local fetchDeadline = tick() + 30
        while (not libDone or not tmDone or not smDone) and tick() < fetchDeadline do
            task.wait(0.05)
        end
        if not libResult then
            local loadError = "UI library returned nil or fetch failed"
            warn("[meowlua] UI library failed to load: " .. loadError)
            error("[meowlua] UI library failed to load: " .. loadError)
        end
        library = libResult
        if tmResult then themeManager = tmResult end
        if smResult then saveManager = smResult end
        if not themeManager then
            warn("[meowlua] ThemeManager failed to load; continuing without theme presets")
            themeManager = {
                SetLibrary = function() end,
                SetFolder = function() end,
                ApplyToTab = function() end,
            }
        end
        if not saveManager then
            warn("[meowlua] SaveManager failed to load; continuing without config saving/loading")
            saveManager = {
                SetLibrary = function() end,
                IgnoreThemeSettings = function() end,
                SetIgnoreIndexes = function() end,
                SetFolder = function() end,
                BuildConfigSection = function() end,
                Load = function() return false, "SaveManager unavailable" end,
                LoadAutoloadConfig = function() end,
            }
        end

        local window = library:CreateWindow({
            Title = "meowlua private v4.0", Footer = "discord.gg/meowwc", Center = true, AutoShow = true, TabPadding = 8, MenuFadeTime = 0,
        })

        local tabs = {
            movement = window:AddTab("Movement", "footprints"),
            aggression = window:AddTab("Aggression", "sword"),
            defense = window:AddTab("Defense", "shield"),
            ragebot = window:AddTab("Ragebot", "crosshair"),
            systems = window:AddTab("Systems", "cpu"),
            character = window:AddTab("Character", "user"),
            settings = window:AddTab("Settings", "wrench"),
        }
        task.wait()
        app.localEvasionActive = false
        local evasionConnection = nil
        local evasionRand = Random.new()

        function app.evasionRingPoint(anchor, minRad, maxRad)
            local angle = evasionRand:NextNumber(0, 2 * math.pi)
            local radiusValue = evasionRand:NextNumber(minRad, maxRad)
            return CFrame.new(anchor + Vector3.new(math.cos(angle) * radiusValue, 0, math.sin(angle) * radiusValue))
                * CFrame.fromOrientation(
                    evasionRand:NextNumber(0, 2 * math.pi),
                    evasionRand:NextNumber(0, 2 * math.pi),
                    evasionRand:NextNumber(0, 2 * math.pi)
                )
        end

        function app.evasionScatterFar(position)
            local baseRad = config.evasionRadiusMin or 100
            local maxRad = config.evasionRadiusMax or 150
            local n = baseRad + baseRad * ((maxRad / baseRad) - 1)
            local ring = app.evasionRingPoint(position, baseRad, n)
            local ringPosition = ring.Position
            local x2, y2, z = ringPosition.X, ringPosition.Y, ringPosition.Z
            local pick = evasionRand:NextInteger(1, 3)
            if pick == 1 then x2 = 1073741824
            elseif pick == 2 then y2 = 1073741824
            else z = 1073741824 end
            return ring - ringPosition + Vector3.new(x2, y2, z)
        end

        function app.getServerCFrame(playerRootPart)
            local clientCFrame = playerRootPart.CFrame
            local currentCFrame = app.evasionScatterFar(clientCFrame.Position)
            return CFrame.new(currentCFrame.Position)
        end

        local evasionCamRem = nil
        local evasionStateRem = nil

        function app.findEvasionChild(root, ...)
            local node = root
            for _, name in ipairs({ ... }) do
                if not node then return end
                node = node:FindFirstChild(name)
            end
            return node
        end

        function app.getRemoteCamera()
            if evasionCamRem and evasionCamRem.Parent then
                return evasionCamRem
            end
            local r = app.findEvasionChild(game:GetService("ReplicatedStorage"), "Remotes", "Replication", "Fighter", "CameraRotation")
            if r and r:IsA("RemoteEvent") then
                evasionCamRem = r
            end
            return evasionCamRem
        end

        function app.getRemoteEvasionState()
            if evasionStateRem and evasionStateRem.Parent then
                return evasionStateRem
            end
            local r = app.findEvasionChild(game:GetService("ReplicatedStorage"), "Remotes", "Replication", "Fighter", "UpdateState")
            if r and r:IsA("RemoteEvent") then
                evasionStateRem = r
            end
            return evasionStateRem
        end

        local evasionCacheEnu = nil

        function app.encodeEvasionValue(name)
            if not evasionCacheEnu then
                local mod = app.findEvasionChild(game:GetService("ReplicatedStorage"), "Modules", "EnumLibrary")
                if mod then
                    local callSucceeded, lib = pcall(require, mod)
                    if callSucceeded and type(lib) == "table" then
                        evasionCacheEnu = lib
                    end
                end
            end
            if not evasionCacheEnu then return end
            local callSucceeded, token = pcall(evasionCacheEnu.ToEnum, evasionCacheEnu, name)
            return callSucceeded and token or nil
        end

        function app.encodeAngleByte(n)
            if n == n then
                return utf8.char(math.clamp(math.floor(n % (2 * math.pi) / math.pi / 2 * 256 + 0.5), 0, 255))
            end
            return utf8.char(0)
        end

        function app.encodeEvasionAngles(pitch, yaw)
            return app.encodeAngleByte(math.rad(pitch)) .. app.encodeAngleByte(math.rad(yaw))
        end

        local evasionOldCFrame = nil
        local evasionServerCFrame = nil
        app.evasionRenderId = "__evasion_render"

        function app.evasionRenderRestore()
            if evasionOldCFrame then
                local playerRootPart = app.getHumanoidRootPart(player)
                if playerRootPart then
                    setCFrame(playerRootPart, evasionOldCFrame)
                end
                evasionOldCFrame = nil
            end
        end

        function app.evasionApplyDesync(playerRootPart)
            if not evasionServerCFrame then return end
            evasionOldCFrame = playerRootPart.CFrame
            setCFrame(playerRootPart, evasionServerCFrame, true)
        end

        function app.evasionSendViewAngles()
            local remote = app.getRemoteCamera()
            if not remote then return end
            local pitch = 90
            local yaw = evasionRand:NextNumber(0, 360)
            local encoded = app.encodeEvasionAngles(pitch, yaw)
            pcall(function() remote:FireServer(encoded, nil) end)
        end

        function app.forceEvasionCrouch(on)
            local remote = app.getRemoteEvasionState()
            if not remote then return end
            local token = app.encodeEvasionValue("IsCrouching")
            if not token then return end
            pcall(function() remote:FireServer(token, on, nil) end)
        end

        app.startEvasion = function()
            if app.localEvasionActive then return end
            app.localEvasionActive = true
            config.evasion = true
            evasionServerCFrame = nil
            evasionOldCFrame = nil
            pcall(function()
                runService:BindToRenderStep(app.evasionRenderId, Enum.RenderPriority.First.Value, app.evasionRenderRestore)
            end)
            local localEvLast = 0
            evasionConnection = track(runService.Heartbeat:Connect(function()
                if not config.evasion then return end
                local currentTime = tick()
                if currentTime - localEvLast < 0.016 then return end
                localEvLast = currentTime
                local playerRootPart = getCharacterInfo(player)
                if not playerRootPart then return end
                local newSrvCFrame = app.getServerCFrame(playerRootPart)
                if newSrvCFrame then
                    evasionServerCFrame = newSrvCFrame
                    app.evasionApplyDesync(playerRootPart)
                end
                app.evasionSendViewAngles()
                app.forceEvasionCrouch(true)
            end))
        end

        app.stopEvasion = function()
            app.localEvasionActive = false
            config.evasion = false
            evasionConnection = disconnect(evasionConnection)
            pcall(function() runService:UnbindFromRenderStep(app.evasionRenderId) end)
            evasionServerCFrame = nil
            evasionOldCFrame = nil
            app.forceEvasionCrouch(false)
            local playerRootPart = app.getHumanoidRootPart(player)
            if playerRootPart then
                setVelocity(playerRootPart, Vector3.zero)
            end
        end

        app.internalState = { undergroundBypassConnection = nil, undergroundBypassActive = false }
        local undergroundBypassGround = setmetatable({}, { __mode = "k" })
        local undergroundBypassRayParams = RaycastParams.new()
        undergroundBypassRayParams.FilterType = Enum.RaycastFilterType.Exclude
        undergroundBypassRayParams.IgnoreWater = true

        local function undergroundBypassFinite(v)
            return v and v.X == v.X and v.Y == v.Y and v.Z == v.Z and math.abs(v.X) < 1e9 and math.abs(v.Y) < 1e9 and math.abs(v.Z) < 1e9
        end

        local function undergroundBypassResolve(target, targetRootPart, head)
            local entry = undergroundBypassGround[target]
            if not entry then
                entry = { lastGroundY = nil }
                undergroundBypassGround[target] = entry
            end
            local rawPos = targetRootPart.Position
            local headPart = head or targetRootPart
            local rawHead = headPart.Position
            if not (undergroundBypassFinite(rawPos) and undergroundBypassFinite(rawHead)) then
                return rawHead
            end
            undergroundBypassRayParams.FilterDescendantsInstances = { target.Character, workspace.CurrentCamera }
            local hit = workspace:Raycast(rawPos + Vector3.new(0, 20, 0), Vector3.new(0, -150, 0), undergroundBypassRayParams)
            if hit then
                entry.lastGroundY = hit.Position.Y + 3.0
            end
            local floorY = entry.lastGroundY
            if floorY and (rawPos.Y < floorY - 4.2 or rawPos.Y < -50) then
                local hOff = rawHead.Y - rawPos.Y
                return Vector3.new(rawHead.X, floorY + hOff, rawHead.Z)
            end
            return rawHead
        end

        app.startUndergroundBypass = function()
            if app.internalState.undergroundBypassActive then return end
            app.internalState.undergroundBypassActive = true
            config.undergroundBypass = true
            app.bindTeleportationRestore()
            local upperBodyLast = 0
            app.internalState.undergroundBypassConnection = track(runService.Heartbeat:Connect(function()
                if not config.undergroundBypass then return end
                local currentTime = tick()
                if currentTime - upperBodyLast < (1 / 256) then return end
                upperBodyLast = currentTime
                local playerRootPart = app.getHumanoidRootPart(player)
                if not playerRootPart then return end
                local myHumanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
                if not myHumanoid or myHumanoid.Health <= 0 then return end
                local target = select(1, pickTarget({ checkForceField = false, searchRadius = 20 }))
                if not target or not target.Character then
                    app.destroyTeleportationConstraint()
                    return
                end
                local targetRootPart = target.Character:FindFirstChild("HumanoidRootPart")
                local head = target.Character:FindFirstChild("Head")
                if not targetRootPart then
                    app.destroyTeleportationConstraint()
                    return
                end
                local firePart = head or targetRootPart
                local resolvedHead = undergroundBypassResolve(target, targetRootPart, head)
                if not app.validVector(resolvedHead) then return end
                local overrideCFrame = CFrame.new(resolvedHead.X, resolvedHead.Y + 5, resolvedHead.Z)
                pcall(app.buildTeleportationConstraint, playerRootPart, firePart, overrideCFrame)
                if myHumanoid:GetState() ~= Enum.HumanoidStateType.Physics then
                    myHumanoid:ChangeState(Enum.HumanoidStateType.Physics)
                end
                manipulation.fireToward(firePart, target.Character)
            end))
            config.fireRedirection = true
            app.startFireRedirection()
        end

        app.stopUndergroundBypass = function()
            app.internalState.undergroundBypassActive = false
            config.undergroundBypass = false
            app.internalState.undergroundBypassConnection = disconnect(app.internalState.undergroundBypassConnection)
            app.destroyTeleportationConstraint()
            if not config.teleportation then
                app.unbindTeleportationRestore()
            end
            pcall(app.stopFireRedirection)
        end

        local env = setmetatable({}, {
            __index = function(_, k)
                return app[k]
            end,
        })

        local featureRegistry = {
            { "teleportation", "startTeleportation", "stopTeleportation" },
            { "translocationCounter", "startTranslocationCounter", "stopTranslocationCounter" },
            { "underground", "startUnderground", "stopUnderground" },
            { "fireRedirection", "startFireRedirection", "stopFireRedirection" },
            { "rapidFire", "startRapidFire", "stopRapidFire" },
            { "fullAuto", "startFullAuto", "stopFullAuto" },
            { "riotBypass", "startRiotBypass", "stopRiotBypass" },
            { "wallbang", "startWallbang", "stopWallbang" },
            { "nebulaCounter", "startNebulaCounter", "stopNebulaCounter" },
            { "elevatedKnifeCounter", "startElevatedKnifeCounter", "stopElevatedKnifeCounter" },
            { "gunManipulation", "startGunManipulation", "stopGunManipulation" },
            { "evasion", "startEvasion", "stopEvasion" },
            { "undergroundBypass", "startUndergroundBypass", "stopUndergroundBypass" },
            { "antiSubspace", "startAntiSubspace", "stopAntiSubspace" },
            { "riotAbuser", "startRiotAbuser", "stopRiotAbuser" },
            { "perfectBlock", "startPerfectBlock", "stopPerfectBlock" },
            { "spin", "startSpin", "stopSpin" },
            { "velocityPulse", "startVelocityPulse", "stopVelocityPulse" },
        }

        app.unloadAll = function()
            app.meowluaLoaded = false
            app.meowluaLoading = false
            app.internalMeowluaGeneration = (tonumber(app.internalMeowluaGeneration) or 0) + 1
            if app.config then
                app.config.void = false
                app.config.teleportation = false
            end
            local stops = {
                "stopVoidspamType", "stopTeleportation",
                "stopMeleeManipulation", "stopUnderground", "stopEvasion",
                "stopUndergroundBypass",
                "stopAntiAim",
                "stopFalsePosition", "stopFakePosition", "stopDesync",
                "stopFireRedirection", "stopRapidFire", "stopFullAuto", "stopRiotBypass", "stopWallbang", "stopNebulaCounter", "stopElevatedKnifeCounter", "stopGunMeleeBypass",
                "stopVoidSyncRagebot", "stopBuiltInRagebot", "stopDesyncCounter",
                "stopAntiSubspace",
                "stopMeleeMode", "stopTranslocation", "stopProfileSpoof", "stopRiotAbuser", "stopPerfectBlock",
                "stopAntiWeaponBypass", "stopSpin", "stopVelocityPulse",
            }
            local stopped = {}
            for i = 1, #stops do
                stopped[stops[i]] = true
                local stop = env[stops[i]]
                if stop then
                    pcall(stop)
                end
            end
            for _, state in ipairs(featureRegistry) do
                local stop = not stopped[state[3]] and env[state[3]]
                if stop then
                    pcall(stop)
                end
            end
            releaseAllConnections()
            pcall(function() library:Unload() end)
            if app.destroyXyzOverlay then
                pcall(app.destroyXyzOverlay)
            end
        end

        task.wait()
        app.internalUi = app.internalUi or {}
        local ui = app.internalUi
        ui.voidMainTabbox = tabs.movement:AddLeftTabbox()
        ui.leftVoid = ui.voidMainTabbox:AddTab("Void")
        ui.custVoid = ui.leftVoid
        local xyzGui, xyzConnection, xyzValues

        function app.buildXyzOverlay()
            if config.voidShowCoordinates == false then return end
            if xyzGui and xyzGui.Parent then return end
            local sg = Instance.new("ScreenGui")
            sg.Name = "MeowluaXYZOverlay"
            sg.ResetOnSpawn = false
            sg.DisplayOrder = 9999
            local coreOk = pcall(function() sg.Parent = game:GetService("CoreGui") end)
            if not coreOk then
                sg.Parent = player:WaitForChild("PlayerGui")
            end
            xyzGui = sg
            local panel = Instance.new("Frame")
            panel.Size = UDim2.new(0, 170, 0, 96)
            panel.Position = UDim2.new(0, 14, 0.5, -48)
            panel.BackgroundColor3 = Color3.fromRGB(18, 18, 20)
            panel.BackgroundTransparency = 0.08
            panel.BorderSizePixel = 0
            panel.Parent = sg
            local panelCorner = Instance.new("UICorner")
            panelCorner.CornerRadius = UDim.new(0, 7)
            panelCorner.Parent = panel
            local panelStroke = Instance.new("UIStroke")
            panelStroke.Color = Color3.fromRGB(60, 60, 65)
            panelStroke.Thickness = 1
            panelStroke.Transparency = 0.3
            panelStroke.Parent = panel
            local hdr = Instance.new("Frame")
            hdr.Size = UDim2.new(1, 0, 0, 26)
            hdr.BackgroundTransparency = 1
            hdr.Parent = panel
            local dot = Instance.new("Frame")
            dot.Size = UDim2.new(0, 7, 0, 7)
            dot.Position = UDim2.new(0, 10, 0.5, -3)
            dot.BackgroundColor3 = Color3.fromRGB(210, 55, 55)
            dot.BorderSizePixel = 0
            dot.Parent = hdr
            local dotCorner = Instance.new("UICorner")
            dotCorner.CornerRadius = UDim.new(1, 0)
            dotCorner.Parent = dot
            local ttl = Instance.new("TextLabel")
            ttl.Size = UDim2.new(0, 80, 1, 0)
            ttl.Position = UDim2.new(0, 23, 0, 0)
            ttl.BackgroundTransparency = 1
            ttl.Text = "meowlua"
            ttl.TextColor3 = Color3.fromRGB(220, 220, 225)
            ttl.Font = Enum.Font.GothamBold
            ttl.TextSize = 12
            ttl.TextXAlignment = Enum.TextXAlignment.Left
            ttl.Parent = hdr
            local badge = Instance.new("TextLabel")
            badge.Size = UDim2.new(0, 48, 0, 16)
            badge.Position = UDim2.new(1, -54, 0.5, -8)
            badge.BackgroundColor3 = Color3.fromRGB(38, 38, 42)
            badge.Text = "PRIVATE"
            badge.TextColor3 = Color3.fromRGB(160, 160, 168)
            badge.Font = Enum.Font.GothamBold
            badge.TextSize = 9
            badge.BorderSizePixel = 0
            badge.Parent = hdr
            local bdc = Instance.new("UICorner")
            bdc.CornerRadius = UDim.new(0, 4)
            bdc.Parent = badge
            local bds = Instance.new("UIStroke")
            bds.Color = Color3.fromRGB(70, 70, 76)
            bds.Thickness = 1
            bds.Parent = badge
            local sep = Instance.new("Frame")
            sep.Size = UDim2.new(1, -16, 0, 1)
            sep.Position = UDim2.new(0, 8, 0, 27)
            sep.BackgroundColor3 = Color3.fromRGB(55, 55, 60)
            sep.BorderSizePixel = 0
            sep.Parent = panel
            xyzValues = {}
            for i, axis in ipairs({ "X", "Y", "Z" }) do
                local y2 = 30 + (i - 1) * 20
                local al = Instance.new("TextLabel")
                al.Size = UDim2.new(0, 18, 0, 18)
                al.Position = UDim2.new(0, 10, 0, y2)
                al.BackgroundTransparency = 1
                al.Text = axis
                al.TextColor3 = Color3.fromRGB(120, 120, 130)
                al.Font = Enum.Font.GothamBold
                al.TextSize = 12
                al.TextXAlignment = Enum.TextXAlignment.Left
                al.Parent = panel
                local vl = Instance.new("TextLabel")
                vl.Size = UDim2.new(1, -30, 0, 18)
                vl.Position = UDim2.new(0, 14, 0, y2)
                vl.BackgroundTransparency = 1
                vl.Text = "0"
                vl.TextColor3 = Color3.fromRGB(230, 230, 235)
                vl.Font = Enum.Font.Gotham
                vl.TextSize = 12
                vl.TextXAlignment = Enum.TextXAlignment.Right
                vl.Parent = panel
                xyzValues[axis] = vl
            end
            local function formatNum(v)
                local s = tostring(math.floor(v + 0.5))
                local k
                repeat s, k = string.gsub(s, "^(-?%d+)(%d%d%d)", "%1,%2") until k == 0
                return s
            end
            local xyzAccum = 0
            local xyzShown = { X = "", Y = "", Z = "" }
            local function xyzSet(axis, text)
                if xyzShown[axis] ~= text then
                    xyzShown[axis] = text
                    xyzValues[axis].Text = text
                end
            end
            xyzConnection = track(runService.Heartbeat:Connect(function(dt)
                xyzAccum = xyzAccum + dt
                if xyzAccum < 0.016 then return end
                xyzAccum = 0
                local currentCFrame = nil
                if config.void and app.voidFinalCFrame then
                    currentCFrame = app.voidFinalCFrame
                else
                    local char = player.Character
                    local playerRootPart = char and char:FindFirstChild("HumanoidRootPart")
                    currentCFrame = playerRootPart and playerRootPart.CFrame
                end
                if currentCFrame then
                    local p = currentCFrame.Position
                    xyzSet("X", formatNum(p.X))
                    xyzSet("Y", formatNum(p.Y))
                    xyzSet("Z", formatNum(p.Z))
                else
                    xyzSet("X", "-")
                    xyzSet("Y", "-")
                    xyzSet("Z", "-")
                end
            end))
        end

        function app.destroyXyzOverlay()
            xyzConnection = disconnect(xyzConnection)
            if xyzGui then
                xyzGui:Destroy()
                xyzGui = nil
            end
        end

        app.destroyXyzOverlay = app.destroyXyzOverlay

        function app.maybeDestroyXyz()
            if not config.void then
                app.destroyXyzOverlay()
            end
        end

        app.voidShouldRun = function()
            return (config.void and not config.meleeManipulation) and true or false
        end

        app.voidReconcile = function(restart)
            if app.voidShouldRun() then
                if app.voidRunning and restart then
                    app.stopVoidspamType(true, true)
                end
                if restart or not app.voidRunning then
                    app.voidType()
                end
                app.buildXyzOverlay()
            else
                if app.voidRunning then
                    app.stopVoidspamType(true)
                end
                app.destroyXyzOverlay()
            end
        end

        task.wait()
        ui.leftVoid:AddToggle("vsEn", { Text = "Void", Default = false, Tooltip = "disable ur script's evasion method for better hvh performance such as ue's voidspam for example." }):OnChanged(function(v) config.void = v
            app.voidReconcile(false)
        end)

        ui.voidTypeDropdown = ui.leftVoid:AddDropdown("vsTypeSel", { Text = "Void Mode", Default = 1, Values = { "Regular", "Farm", "Advanced" } })
        ui.voidPatternDropdown = ui.leftVoid:AddDropdown("vsPatternSel", { Text = "Pattern", Default = 1, Values = { "Regular", "Partial-Translocate" } })

        ui.voidPatternDropdown:OnChanged(function(v)
            config.voidPatternMode = v
            voidPattern.reset()
        end)

        ui.voidStatusLabel = ui.leftVoid:AddLabel("status: off")

        app.voidStatusText = function()
            if not config.void then return "status: off" end
            if config.meleeManipulation then return "status: paused (melee manipulation)" end
            if not app.voidRunning then return "status: starting" end
            local char = player.Character
            local root = char and char:FindFirstChild("HumanoidRootPart")
            local humanoid = char and char:FindFirstChildOfClass("Humanoid")
            if not root or not humanoid then return "status: waiting for character" end
            local now = os.clock()
            if humanoid.Health <= 0 or (app.voidReviveAt and now - app.voidReviveAt < 0.6) then
                return "status: reviving"
            end
            local text = "voiding"
            local glue = app.voidGlue
            if config.voidDecoy and glue and glue.phase == "land" then
                text = "decoy landing"
            end
            if app.kiciaCounterOwned then
                text = text .. " + secret method"
            end
            return "status: " .. text
        end

        local voidStatusShown = nil
        local voidStatusAccum = 0
        track(runService.Heartbeat:Connect(function(dt)
            voidStatusAccum = voidStatusAccum + dt
            if voidStatusAccum < 0.1 then return end
            voidStatusAccum = 0
            local text = app.voidStatusText()
            if text ~= voidStatusShown then
                voidStatusShown = text
                pcall(function() ui.voidStatusLabel:SetText(text) end)
            end
        end))

        ui.leftVoid:AddToggle("vsShowCoordsTog", { Text = "Show Coordinates", Default = true }):OnChanged(function(v)
            config.voidShowCoordinates = v
            if v then
                if app.voidShouldRun() then
                    app.buildXyzOverlay()
                end
            else
                app.destroyXyzOverlay()
            end
        end)

        ui.leftVoid:AddDropdown("voidMapperSel", { Text = "Mapper", Default = "Auto", Values = app.voidMapper.names }):OnChanged(function(v)
            setConfig("voidMapper", v)
            app.voidMapper.cacheKey = nil
            app.voidMapper.cacheAt = 0
        end)

        ui.leftVoid:AddToggle("vsSyncRagebotTog", { Text = "Sync To Ragebot", Default = false }):OnChanged(function(v)
            app.setVoidSyncRagebot("main", v)
        end)

        ui.leftVoid:AddToggle("vsTargetManipTog", { Text = "Target Manipulation", Default = true }):OnChanged(function(v)
            setConfig("targetManipulation", v)
            if app.voidRunning then
                app.applyTargetManipulation()
            end
        end)

        ui.leftVoid:AddDropdown("vsTargetManipMethodDd", { Text = "Method", Default = "Method 2", Values = { "Method 1", "Method 2" } }):OnChanged(function(v)
            setConfig("targetManipulationMethod", v)
            if app.voidRunning and config.targetManipulation then
                app.applyTargetManipulation()
            end
        end)

        ui.leftVoid:AddSlider("evsIterCountSl", { Text = "Iteration Count", Default = 600, Min = 1, Max = 600, Rounding = 0 }):OnChanged(function(v) config.evsIterCount = math.clamp(v, 1, 600) end)
        ui.leftVoid:AddSlider("evsIterSpeedSl", { Text = "Iteration Speed", Default = 100, Min = 1, Max = 100, Rounding = 0 }):OnChanged(function(v) config.evsIterSpeed = math.clamp(v, 1, 100) end)
        task.wait()
        ui.voidMotionBox = tabs.movement:AddRightGroupbox("Motion")

        ui.voidMotionBox:AddToggle("vsSpinTog", { Text = "Spin", Default = false }):OnChanged(function(v)
            config.spin = v
            if v then
                app.startSpin()
            else
                app.stopSpin()
            end
        end)

        ui.voidMotionBox:AddToggle("vsVelocityPulseTog", { Text = "Velocity Pulse", Default = false }):OnChanged(function(v)
            config.velocityPulse = v
            if v then
                app.startVelocityPulse()
            else
                app.stopVelocityPulse()
            end
        end)

        ui.motionSpinSpeedSlider = ui.voidMotionBox:AddSlider("vsMotionSpinSpeedSl", { Text = "Spin Speed", Default = 720, Min = 0, Max = 3000000, Rounding = 0 })
        ui.motionSpinSpeedSlider:OnChanged(function(v) config.motionSpinSpeed = v end)
        ui.motionXJitterSlider = ui.voidMotionBox:AddSlider("vsMotionXJitterSl", { Text = "Horizontal Jitter", Default = 30, Min = 0, Max = 120, Rounding = 0 })
        ui.motionXJitterSlider:OnChanged(function(v) config.motionXJitter = v end)
        ui.motionYJitterSlider = ui.voidMotionBox:AddSlider("vsMotionYJitterSl", { Text = "Vertical Jitter", Default = 8, Min = 0, Max = 60, Rounding = 0 })
        ui.motionYJitterSlider:OnChanged(function(v) config.motionYJitter = v end)
        ui.motionDistanceSlider = ui.voidMotionBox:AddSlider("vsMotionSpreadSl", { Text = "Spread Distance", Default = 300, Min = 1, Max = 5000, Rounding = 0 })
        ui.motionDistanceSlider:OnChanged(function(v) config.motionDistance = v end)

        do
            local distanceSliders = {}
            local distanceDefaults = { X = 14000000, Y = 10000000, Z = 18000000 }
            local function addDistanceSlider(id, text, key, axis)
                local default = distanceDefaults[axis]
                config[key] = default
                local slider = ui.voidMotionBox:AddSlider(id, { Text = text, Default = default, Min = 50, Max = 50000000, Rounding = 0 })
                distanceSliders[key] = slider
                slider:OnChanged(function(v)
                    config[key] = v
                end)
            end
            addDistanceSlider("vsDistXPosSl", "X+ Distance", "distPlusX", "X")
            addDistanceSlider("vsDistXNegSl", "X- Distance", "distMinusX", "X")
            addDistanceSlider("vsDistYPosSl", "Y+ Distance", "distPlusY", "Y")
            addDistanceSlider("vsDistYNegSl", "Y- Distance", "distMinusY", "Y")
            addDistanceSlider("vsDistZPosSl", "Z+ Distance", "distPlusZ", "Z")
            addDistanceSlider("vsDistZNegSl", "Z- Distance", "distMinusZ", "Z")
            ui.voidMotionBox:AddButton("Sync Distances", function()
                local axes = { { "distPlusX", "distMinusX", "X" }, { "distPlusY", "distMinusY", "Y" }, { "distPlusZ", "distMinusZ", "Z" } }
                for _, pair in ipairs(axes) do
                    local fallback = distanceDefaults[pair[3]]
                    local widest = math.max(tonumber(config[pair[1]]) or fallback, tonumber(config[pair[2]]) or fallback)
                    for i = 1, 2 do
                        local key = pair[i]
                        config[key] = widest
                        local slider = distanceSliders[key]
                        if slider then
                            pcall(function() slider:SetValue(widest) end)
                        end
                    end
                end
                app.notify("Distances", "Distances synced.")
            end)
            ui.voidMotionBox:AddButton("Reset Distances", function()
                local limitKeys = { { "distPlusX", "X" }, { "distMinusX", "X" }, { "distPlusY", "Y" }, { "distMinusY", "Y" }, { "distPlusZ", "Z" }, { "distMinusZ", "Z" } }
                for _, pair in ipairs(limitKeys) do
                    local value = distanceDefaults[pair[2]]
                    config[pair[1]] = value
                    local slider = distanceSliders[pair[1]]
                    if slider then
                        pcall(function() slider:SetValue(value) end)
                    end
                end
                app.notify("Distances", "Distances reset.")
            end)
        end

        function app.updateVoidSyncVisibility(mode)
            local isRegular = mode == "Regular"
            pcall(function() ui.voidPatternDropdown:SetVisible(isRegular) end)
        end

        app.updateVoidSyncVisibility(config.voidType or "Regular")
        ui.voidTypeDropdown:OnChanged(function(v)
            config.voidType = v
            app.updateVoidSyncVisibility(v)
            app.voidReconcile(true)
        end)

        task.wait()
        task.wait()

        ui.leftVoid:AddToggle("vsDecoyTog", { Text = "Decoy Landing", Default = false, Tooltip = "lands 20 studs above the oob area just long enough for teleporting users to arrive, then returns to voiding." }):OnChanged(function(v)
            setConfig("voidDecoy", v)
            if config.void then
                if v then
                    app.ncsBind("void")
                else
                    app.ncsUnbind("void")
                end
            end
        end)

        task.wait()
        ui.voidDecoyLabel = ui.leftVoid:AddLabel("disable ur ragebot")
        task.wait()
        ui.randomizerSeedInput = ui.leftVoid:AddInput("randSeedIn", { Text = "Seeds", Default = "", Placeholder = "Enter seed...", Numeric = false, Finished = false })
        ui.randomizerSeedInput:OnChanged(function(v) setConfig("randSeed", v) end)
        ui.leftVoid:AddDropdown("randMode1", { Text = "Randomizer Mode", Default = 1, Values = { "Random", "Uniform", "Weighted", "Radial", "Axial", "Spiral", "Chaos" } }):OnChanged(function(v) setConfig("randMode", v) end)
        ui.leftVoid:AddSlider("randRouteCount", { Text = "Route Count", Default = 128, Min = 16, Max = 512, Rounding = 0 }):OnChanged(function(v) setConfig("randomizerRouteCount", v) end)
        ui.leftVoid:AddSlider("randCandMul", { Text = "Candidates", Default = 6, Min = 2, Max = 16, Rounding = 0 }):OnChanged(function(v) setConfig("randomizerCandMul", v) end)

        ui.leftVoid:AddButton("Random Seed", function()
            local chars = "abcdefghijklmnopqrstuvwxyz0123456789"
            local entropy = math.floor(tick() * 1000) + math.floor((os.clock and os.clock() or 0) * 1000000) + math.random(1, 1000000000)
            local state = app.lcg(entropy % 2147483646 + 1)
            local seed = ""
            for i = 1, 16 do
                state = app.lcg(state)
                local idx = math.floor(app.lcgFloat(state) * #chars) + 1
                seed = seed .. chars:sub(idx, idx)
            end
            config.randSeed = seed
            pcall(function() ui.randomizerSeedInput:SetValue(seed) end)
        end)

        function app.lcg(s)
            s = math.floor(math.abs(s)) % 2147483647
            if s == 0 then s = 1 end
            return (s * 48271) % 2147483647
        end

        function app.lcgFloat(s)
            return (math.floor(math.abs(s)) % 2147483647) / 2147483647
        end

        function app.hashSeedString(str, salt)
            str = tostring(str or "") .. "|" .. tostring(salt or "")
            local h = 1779033703
            local g = 1013904223
            for i = 1, #str do
                local b = string.byte(str, i)
                h = (h * 48271 + b * 7919 + i) % 2147483647
                g = (g * 69621 + b * 104729 + h) % 2147483647
            end
            local x = (h + g * 31 + #str) % 2147483647
            if x == 0 then x = 1 end
            for _ = 1, 8 do
                x = (x * 48271) % 2147483647
            end
            return x
        end

        function app.lcgSequence(s)
            local s1 = app.lcg(s)
            local s2 = app.lcg(s1)
            local s3 = app.lcg(s2)
            local s4 = app.lcg(s3)
            return s4, app.lcgFloat(s1), app.lcgFloat(s2), app.lcgFloat(s3), app.lcgFloat(s4)
        end

        local transThreshold = 110000
        app.teleportationMinStepDistance = 80000

        function app.scoreRouteCandidate(cx, cy, cz, prevX, prevY, prevZ, route, routeLen, predX, predY, predZ)
            local score = 0
            local dx = cx - prevX
            local dy = cy - prevY
            local dz = cz - prevZ
            local stepDist = math.sqrt(dx * dx + dy * dy + dz * dz)
            if stepDist < app.teleportationMinStepDistance then
                return -1e9
            end
            if predX then
                local px = cx - predX
                local py = cy - predY
                local pz = cz - predZ
                local predDist = math.sqrt(px * px + py * py + pz * pz)
                local predSafe = 55000000 * 5.5
                if predDist < predSafe then
                    score = score - (predSafe - predDist) * 3.0
                else
                    score = score + math.min((predDist - predSafe) / predSafe, 1) * 60
                end
            end
            local mag = math.sqrt(cx * cx + cy * cy + cz * cz)
            if mag < transThreshold then
                score = score - ((transThreshold - mag) / transThreshold) * 200
            else
                score = score + math.min((mag - transThreshold) / transThreshold, 1) * 40
            end
            local absY = math.abs(cy)
            if absY > 50000 then
                score = score + math.min(absY / 500000, 1) * 60
            end
            local stepNorm = stepDist / math.max(mag, 1)
            score = score + math.min(stepNorm, 1) * 50
            if routeLen > 0 then
                local prev2X = route[routeLen][1]
                local prev2Y = route[routeLen][2]
                local prev2Z = route[routeLen][3]
                local v1x = prevX - prev2X
                local v1y = prevY - prev2Y
                local v1z = prevZ - prev2Z
                local v1m = math.sqrt(v1x * v1x + v1y * v1y + v1z * v1z)
                local v2x = cx - prevX
                local v2y = cy - prevY
                local v2z = cz - prevZ
                local v2m = math.sqrt(v2x * v2x + v2y * v2y + v2z * v2z)
                if v1m > 0 and v2m > 0 then
                    local dot = (v1x * v2x + v1y * v2y + v1z * v2z) / (v1m * v2m)
                    score = score + (1 - math.abs(dot)) * 80
                end
            end
            local minSep = math.huge
            local checkN = math.min(routeLen, 12)
            local checkStart = routeLen - checkN + 1
            for i = checkStart, routeLen do
                if route[i] then
                    local ex = cx - route[i][1]
                    local ey = cy - route[i][2]
                    local ez = cz - route[i][3]
                    local sep = math.sqrt(ex * ex + ey * ey + ez * ez)
                    if sep < minSep then
                        minSep = sep
                    end
                end
            end
            if minSep ~= math.huge then
                score = score + math.min(minSep / transThreshold, 2) * 70
            end
            local pmag = math.sqrt(prevX * prevX + prevY * prevY + prevZ * prevZ)
            if pmag > 0 and mag > 0 then
                local pdx = prevX / pmag
                local pdy = prevY / pmag
                local pdz = prevZ / pmag
                local ndx = cx / mag
                local ndy = cy / mag
                local ndz = cz / mag
                local dirDot = pdx * ndx + pdy * ndy + pdz * ndz
                score = score + (1 - math.max(dirDot, 0)) * 55
            end
            return score
        end

        function app.buildSeedRoutes(seedStr, mode, count, spread)
            local s = app.hashSeedString(seedStr, mode)
            for _ = 1, 16 do s = app.lcg(s) end
            local n = math.max(count or 128, 16)
            local seedStepMin = 17500000
            local seedStepSpan = 1000000
            local candMul = math.max(config.randomizerCandMul or 6, 2)
            local route = {}
            local startState, sx, sy, sz = app.lcgSequence(s)
            s = startState
            local prevX = (sx - 0.5) * seedStepMin * 0.1
            local prevY = (sy - 0.5) * seedStepMin * 0.1
            local prevZ = (sz - 0.5) * seedStepMin * 0.1
            local seedVelX, seedVelY, seedVelZ = 0, 0, 0
            for i = 1, n do
                local bestScore = -1e18
                local bestX, bestY, bestZ = prevX, prevY + seedStepMin * 0.5, prevZ
                local seedPredT = 0.008 + app.lcgFloat(s) * (0.08 - 0.008)
                local predX = prevX + seedVelX * seedPredT
                local predY = prevY + seedVelY * seedPredT
                local predZ = prevZ + seedVelZ * seedPredT
                for _ = 1, candMul do
                    local ns, f1, f2, f3, _ = app.lcgSequence(s)
                    s = ns
                    local dist = seedStepMin + app.lcgFloat(ns) * seedStepSpan
                    local dx = f1 * 2 - 1
                    local dy = f2 * 2 - 1
                    local dz = f3 * 2 - 1
                    local dlen = math.sqrt(dx * dx + dy * dy + dz * dz)
                    if dlen < 1e-6 then dlen = 1 end
                    local cx = prevX + (dx / dlen) * dist
                    local cy = prevY + (dy / dlen) * dist
                    local cz = prevZ + (dz / dlen) * dist
                    local scoreValue = app.scoreRouteCandidate(cx, cy, cz, prevX, prevY, prevZ, route, i - 1, predX, predY, predZ)
                    if scoreValue > bestScore then
                        bestScore = scoreValue
                        bestX = cx
                        bestY = cy
                        bestZ = cz
                    end
                end
                seedVelX = seedVelX + (bestX - prevX - seedVelX) * 0.25
                seedVelY = seedVelY + (bestY - prevY - seedVelY) * 0.25
                seedVelZ = seedVelZ + (bestZ - prevZ - seedVelZ) * 0.25
                route[i] = { bestX, bestY, bestZ }
                prevX = bestX
                prevY = bestY
                prevZ = bestZ
            end
            local out = {}
            for i = 1, n do
                out[i] = Vector3.new(route[i][1], route[i][2], route[i][3])
            end
            return out
        end

        function app.resetSeedCursor(state)
            app.internalSeedStep = 0
        end

        app.internalSeedRoutes = app.internalSeedRoutes or {}

        if not app.internalSeedStep then
            app.resetSeedCursor(1)
        end

        ui.leftVoid:AddButton("Generate Seed", function()
            local seed = config.randSeed or ""
            if seed == "" then return end
            local mode = config.randMode or "Random"
            local count = config.randomizerRouteCount or 128
            local spread = math.max(config.spreadDist or 500000, 1)
            local routes = app.buildSeedRoutes(seed, mode, count, spread)
            app.internalSeedRoutes = routes
            app.resetSeedCursor(app.hashSeedString(seed, "cursor"))
            app.notify("Seed Routes", "Optimized " .. #routes .. " routes (" .. mode .. ")")
        end)

        ui.leftVoid:AddButton("Clear Seed", function()
            app.internalSeedRoutes = {}
            app.resetSeedCursor(1)
        end)

        task.wait()
        task.wait()
        task.wait()

        function app.getGlueCFrame(targetCharacter, anchorPart, useHitbox, extraY, extraZ)
            local fighter = nil
            pcall(function()
                local controller = requireOptionalModule(player.PlayerScripts.Controllers.FighterController)
                if controller and targetCharacter then
                    fighter = manipulation.findFighter(controller, targetCharacter)
                end
            end)
            local above = manipulation.isAbove(fighter)
            local head = anchorPart
            if useHitbox then
                head = manipulation.resolveHitbox(anchorPart, targetCharacter, fighter)
            end
            if not head then return nil end
            local okCf, headCFrame = pcall(function() return head.CFrame end)
            if not okCf or not headCFrame or not app.validVector(headCFrame.Position) then
                return nil
            end
            local baseOffset = above and Vector3.new(0, -0.7, 0.05) or Vector3.new(0, -3.85, 0.05)
            local offset = baseOffset + Vector3.new(0, extraY or 0, extraZ or 0)
            if above then
                return headCFrame + offset
            end
            local headPosition = headCFrame.Position
            local fromPosition = headPosition + offset
            local forward = Vector3.new(headPosition.X - fromPosition.X, 0, headPosition.Z - fromPosition.Z)
            if forward.Magnitude < 0.001 then
                forward = Vector3.new(0, 0, -1)
            end
            return CFrame.lookAt(fromPosition, fromPosition + forward, Vector3.new(0, -1, 0))
        end

        local teleportationConnection = nil
        local teleportationActive = false
        local teleportationTargetCache = nil
        local teleportationTargetRootPart = nil
        local teleportationTargetHead = nil
        local teleportationTargetDirty = true
        app.teleportationTargetLast = 0
        local teleportationConnections = {}
        local teleportationBoundRootPart = nil
        local teleportationBoundTarget = nil

        function app.destroyTeleportationConstraint()
            teleportationBoundRootPart = nil
            teleportationBoundTarget = nil
        end

        function app.buildTeleportationConstraint(playerRootPart, targetPart, overrideCFrame)
            app.destroyTeleportationConstraint()
            local okParent, targetCharacter = pcall(function() return targetPart.Parent end)
            if not okParent then return end
            local useHitbox = (config.teleportationAttachMode or "Head") == "Head"
            local snapCFrame = overrideCFrame or app.getGlueCFrame(targetCharacter, targetPart, useHitbox, config.teleportationHeight or 0, config.teleportationDist or 0)
            if not snapCFrame or not app.validVector(snapCFrame.Position) then return end
            local snaps = math.clamp(config.teleportationSnapCount or 3, 1, 8)
            for _ = 1, snaps do
                setCFrame(playerRootPart, snapCFrame)
            end
            teleportationBoundRootPart = playerRootPart
            teleportationBoundTarget = targetPart
        end

        function app.getTeleportationAttachPart(char)
            if not char then return end
            local mode = config.teleportationAttachMode or "Head"
            if mode == "HRP" then
                return char:FindFirstChild("HumanoidRootPart")
            end
            local partRef = char:FindFirstChild(mode)
            if partRef then return partRef end
            return char:FindFirstChild("HumanoidRootPart")
        end

        function app.resolveTeleportationTarget()
            local currentTime = tick()
            local teamCheck = config.teleportationTeamCheck ~= false
            local cacheTtl = (teleportationTargetCache ~= nil) and 0.033 or 0
            if not teleportationTargetDirty and (currentTime - app.teleportationTargetLast) < cacheTtl then
                if teleportationTargetCache and app.teleportationIsValid(teleportationTargetCache, teamCheck) then
                    return teleportationTargetCache, teleportationTargetRootPart, teleportationTargetHead
                end
            end
            teleportationTargetDirty = false
            app.teleportationTargetLast = currentTime
            local playerRootPart = app.getHumanoidRootPart(player)
            if not playerRootPart then
                teleportationTargetCache = nil
                teleportationTargetRootPart = nil
                teleportationTargetHead = nil
                return nil
            end
            local teleportationTargetName = config.teleportationTargetPlayerName
            local named = teleportationTargetName ~= nil and teleportationTargetName ~= "" and teleportationTargetName ~= "Closest"
            local picked, pickedHumanoidRootPart = nil, nil
            if named then
                local namedPlayer = players:FindFirstChild(teleportationTargetName)
                local callSucceeded, sHumanoidRootPart = app.teleportationIsValid(namedPlayer, teamCheck)
                if callSucceeded then
                    picked = namedPlayer
                    pickedHumanoidRootPart = sHumanoidRootPart
                end
            end
            if not picked then
                local mode = config.teleportationPriority or "Closest"
                local playerPosition = playerRootPart.Position
                local bestS = math.huge
                for _, p in ipairs(players:GetPlayers()) do
                    local callSucceeded, targetRootPart, targetHumanoid = app.teleportationIsValid(p, teamCheck)
                    if callSucceeded then
                        local scoreValue = app.teleportationScore(targetRootPart, targetHumanoid, playerPosition, mode)
                        if scoreValue < bestS then
                            bestS = scoreValue
                            picked = p
                            pickedHumanoidRootPart = targetRootPart
                        end
                    end
                end
            end
            teleportationTargetCache = picked
            teleportationTargetRootPart = pickedHumanoidRootPart
            teleportationTargetHead = picked and app.getTeleportationAttachPart(picked.Character) or nil
            return teleportationTargetCache, teleportationTargetRootPart, teleportationTargetHead
        end

        app.teleportationRestoreCFrame = nil

        function app.teleportationRenderRestore()
            app.ncsRestore()
        end

        function app.bindTeleportationRestore()
            app.ncsBind("teleportation")
        end

        function app.unbindTeleportationRestore()
            app.ncsUnbind("teleportation")
            app.ncsRestore()
        end

        app.startTeleportation = function()
            if teleportationActive then return end
            teleportationActive = true
            config.teleportation = true
            teleportationTargetCache = nil
            teleportationTargetRootPart = nil
            teleportationTargetHead = nil
            teleportationTargetDirty = true
            for _, p in ipairs(players:GetPlayers()) do
                local c = track(p.CharacterAdded:Connect(function() teleportationTargetDirty = true end))
                local characterRemovingConnection = track(p.CharacterRemoving:Connect(function() teleportationTargetDirty = true end))
                table.insert(teleportationConnections, c)
                table.insert(teleportationConnections, characterRemovingConnection)
            end
            local teleportationPlayerAddedConnection = track(players.PlayerAdded:Connect(function(p)
                teleportationTargetDirty = true
                local c = track(p.CharacterAdded:Connect(function() teleportationTargetDirty = true end))
                local characterRemovingConnection = track(p.CharacterRemoving:Connect(function() teleportationTargetDirty = true end))
                table.insert(teleportationConnections, c)
                table.insert(teleportationConnections, characterRemovingConnection)
            end))
            local teleportationPlayerRemovingConnection = track(players.PlayerRemoving:Connect(function() teleportationTargetDirty = true end))
            table.insert(teleportationConnections, teleportationPlayerAddedConnection)
            table.insert(teleportationConnections, teleportationPlayerRemovingConnection)
            local teleportationHbLast = 0
            teleportationConnection = track(runService.Heartbeat:Connect(function()
                if not config.teleportation then return end
                local currentTime = tick()
                if currentTime - teleportationHbLast < 0.016 then return end
                teleportationHbLast = currentTime
                local playerRootPart = app.getHumanoidRootPart(player)
                if not playerRootPart then return end
                local characterHumanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
                if not characterHumanoid or characterHumanoid.Health <= 0 then
                    app.destroyTeleportationConstraint()
                    return
                end
                local _, targetRootPart, head = app.resolveTeleportationTarget()
                local targetPart = head or targetRootPart
                if not targetPart then
                    app.destroyTeleportationConstraint()
                    return
                end
                pcall(app.buildTeleportationConstraint, playerRootPart, targetPart)
            end))
        end

        app.stopTeleportation = function()
            config.teleportation = false
            teleportationActive = false
            teleportationConnection = disconnect(teleportationConnection)
            for _, connection in ipairs(teleportationConnections) do
                disconnect(connection)
            end
            teleportationConnections = {}
            teleportationTargetCache = nil
            teleportationTargetRootPart = nil
            teleportationTargetHead = nil
            teleportationTargetDirty = true
            app.destroyTeleportationConstraint()
            app.unbindTeleportationRestore()
        end

        local meleeModeState = { active = false, conn = nil, cleanup = nil, lastTargetWorld = nil }
        app.meleeModeRenderId = "__meleeModeState_render"

        app.startMeleeMode = function(farmMode)
            if meleeModeState.active then return end
            meleeModeState.active = true
            local cfg = {
                stability = 0.15,
                shootFrames = 1,
                baseRadius = 100,
                radiusFactor = 0.5,
                anchorFromCharacter = false,
            }
            local slotNames = { [3] = "Melee" }
            local randomGen = Random.new()
            local TAU = 6.2831853071795862
            local HALF_PI = 1.5707963267948966
            local FAR = 1073741824
            local SPATIAL_BOUND = 4194304
            local OFFSET_ABOVE = Vector3.new(0, -0.7, 0.05)
            local OFFSET_BELOW = Vector3.new(0, -3.85, 0.05)
            local originalFallenHeight = workspace.FallenPartsDestroyHeight
            pcall(function() workspace.FallenPartsDestroyHeight = 0 / 0 end)
            local function slotEnabled(slot)
                if slot == "Melee" then
                    return config.meleeManipulation and true or false
                end
                return false
            end
            local function itemType(item)
                local info = rawget(item, "Info")
                return info and rawget(info, "Type") or nil
            end
            local function itemIsEquipped(item)
                return rawget(item, "IsEquipped") and true or false
            end
            local useItemRemote = nil
            local function resolveUseItem()
                if useItemRemote and useItemRemote.Parent then
                    return useItemRemote
                end
                local folder = app.findEvasionChild(replicatedStorage, "Remotes", "Replication", "Fighter")
                local remote = folder and folder:FindFirstChild("UseItem")
                if remote and remote:IsA("RemoteEvent") then
                    useItemRemote = remote
                end
                return useItemRemote
            end
            local function fire(tokenName, objectId, payload)
                local remote = resolveUseItem()
                local tok = app.encodeEvasionValue(tokenName)
                if not remote or not tok or not objectId then return false end
                manipulation.nativeFire(remote, objectId, tok, payload, nil)
                return true
            end
            local function fireMelee(tokenName, animName, objectId, a, b, head, extra)
                local anim = app.encodeEvasionValue(animName)
                if not anim then return end
                fire(tokenName, objectId, { [K1] = { [K0] = a, [K1] = b, [K2] = head, [K3] = extra }, [K2] = anim })
            end
            local function equipItem(item, index)
                if itemIsEquipped(item) then return end
                local clientFighter = rawget(item, "ClientFighter")
                if clientFighter and index and type(clientFighter.EquipItem) == "function" then
                    pcall(function() clientFighter:EquipItem(index) end)
                end
            end
            local crouchForced = false
            local function applyForcedCrouch(on)
                local tok = app.encodeEvasionValue("IsCrouching")
                local remote = app.getRemoteEvasionState()
                if tok == nil or not remote then return end
                if on then
                    if crouchForced then return end
                    crouchForced = true
                    manipulation.nativeFire(remote, tok, true, nil)
                else
                    if not crouchForced then return end
                    crouchForced = false
                    manipulation.nativeFire(remote, tok, false, nil)
                end
            end
            local lastAngleSent = nil
            local lastAngleTime = 0
            local function sendViewAngles(basePitch, angles)
                local remote = app.getRemoteCamera()
                if not remote then return end
                local pitch = basePitch
                local yaw = 0
                if angles ~= nil then
                    pitch = angles.Pitch
                    yaw = angles.Yaw
                else
                    local cam = workspace.CurrentCamera
                    if cam then
                        local _, camYaw = cam.CFrame:ToOrientation()
                        yaw = math.deg(camYaw)
                    end
                end
                local encoded = app.encodeEvasionAngles(pitch, yaw)
                local now = os.clock()
                if encoded == lastAngleSent and now - lastAngleTime < 0.25 then
                    return
                end
                lastAngleSent = encoded
                lastAngleTime = now
                manipulation.nativeFire(remote, encoded, nil)
            end
            local oldCFrame = nil
            local function renderRestore()
                if oldCFrame then
                    local root = app.getHumanoidRootPart(player)
                    if root then
                        setCFrame(root, oldCFrame)
                    end
                    oldCFrame = nil
                end
            end
            local function applyServerCFrame(root, cf)
                if cf == nil then return end
                if oldCFrame == nil then
                    oldCFrame = root.CFrame
                end
                setCFrame(root, cf, true)
            end
            pcall(function() runService:UnbindFromRenderStep(app.meleeModeRenderId) end)
            pcall(function()
                runService:BindToRenderStep(app.meleeModeRenderId, Enum.RenderPriority.First.Value, renderRestore)
            end)
            local function getController()
                local ok, controller = pcall(function()
                    return requireOptionalModule(player.PlayerScripts.Controllers.FighterController)
                end)
                if ok and type(controller) == "table" then
                    return controller
                end
                return nil
            end
            local function getLocalFighter()
                local controller = getController()
                if not controller then return nil end
                local ok, localFighter = pcall(function() return controller.LocalFighter end)
                if ok then return localFighter end
                return nil
            end
            local function isEnemyPlayer(p)
                if p == nil or p == player then return false end
                local localTeamId = player:GetAttribute("TeamID")
                local theirTeamId = p:GetAttribute("TeamID")
                if localTeamId ~= nil and theirTeamId ~= nil then
                    return localTeamId ~= theirTeamId
                end
                if player.Team ~= nil and p.Team ~= nil then
                    return player.Team ~= p.Team
                end
                return true
            end
            local function isInvincible(entity)
                local data = entity and rawget(entity, "Data")
                return data ~= nil and rawget(data, "IsInvincible") == true
            end
            local function isDeflecting(obs)
                if not obs then return false end
                local ok, result = pcall(function()
                    local equipped = obs:GetEquippedItem()
                    if equipped ~= nil and type(equipped.IsDeflecting) == "function" then
                        return equipped:IsDeflecting() == true
                    end
                    return false
                end)
                return ok and result == true
            end
            local function collectEnemies()
                local out = {}
                local controller = getController()
                if not controller then return out end
                local okObjects, objects = pcall(function() return controller.Objects end)
                if not okObjects or type(objects) ~= "table" then return out end
                for _, fighter in ipairs(objects) do
                    local ok, entry = pcall(function()
                        local p = rawget(fighter, "Player")
                        local entity = rawget(fighter, "Entity")
                        local model = entity and rawget(entity, "Model") or nil
                        if not model then return nil end
                        if p ~= nil and not isEnemyPlayer(p) then return nil end
                        local hitboxHead = model:FindFirstChild("HitboxHead")
                        local rootPart = model:FindFirstChild("HumanoidRootPart") or model:FindFirstChild("HitboxBody")
                        if not (hitboxHead and rootPart) then return nil end
                        local humanoid = model:FindFirstChildOfClass("Humanoid")
                        return {
                            fighter = fighter,
                            entity = entity,
                            model = model,
                            hitboxHead = hitboxHead,
                            rootPart = rootPart,
                            itemObserver = rawget(fighter, "itemObserver") or rawget(fighter, "ItemObserver"),
                            alive = humanoid == nil or humanoid.Health > 0,
                            invincible = isInvincible(entity),
                        }
                    end)
                    if ok and entry then
                        out[#out + 1] = entry
                    end
                end
                return out
            end
            local function selectTarget()
                local enemies = collectEnemies()
                for _, entry in ipairs(enemies) do
                    if entry.alive and not entry.invincible and not isDeflecting(entry.itemObserver) then
                        return entry
                    end
                end
                return nil
            end
            local function getAction(fighter)
                if not fighter then return nil end
                local items = rawget(fighter, "Items")
                if type(items) ~= "table" then return nil end
                for slotKey, item in next, items do
                    local slot = slotNames[slotKey]
                    if type(item) == "table" and slot ~= nil and slotEnabled(slot) then
                        local kind = { item = item, index = slotKey, itemType = itemType(item) }
                        if itemIsEquipped(item) then
                            kind.type = "Attack"
                        else
                            kind.type = "Swap"
                        end
                        return kind
                    end
                end
                return nil
            end
            local measurements = {}
            local function equippedHasAmmo(target)
                local obs = target.itemObserver
                if not obs then return true end
                local ok, state = pcall(function() return obs:GetEquippedAmmoState() end)
                if ok then return state ~= false end
                return true
            end
            local function outOfBounds(pos)
                return math.abs(pos.X) >= SPATIAL_BOUND or math.abs(pos.Y) >= SPATIAL_BOUND or math.abs(pos.Z) >= SPATIAL_BOUND
            end
            local function spatialTick(target)
                local now = os.clock()
                local key = target.fighter or target
                local measurement = measurements[key]
                if measurement == nil then
                    measurement = { ExpectedDuration = 1 }
                    measurements[key] = measurement
                end
                local entryTime = measurement.LimitEntryTime
                if not outOfBounds(target.rootPart.Position) then
                    if entryTime ~= nil then
                        if equippedHasAmmo(target) then
                            measurement.ExpectedDuration = now - entryTime
                        end
                        measurement.LimitEntryTime = nil
                    end
                    return false
                end
                if entryTime == nil then
                    measurement.LimitEntryTime = now
                    entryTime = now
                end
                if equippedHasAmmo(target) then
                    if measurement.ExpectedDuration - cfg.stability <= now - entryTime then
                        return false
                    end
                end
                return true
            end
            local function newShootLock()
                local lock = { lockedUntil = nil }
                function lock.shouldFire(shouldLock, duration)
                    local now = os.clock()
                    local locked = lock.lockedUntil ~= nil and now < lock.lockedUntil
                    if shouldLock then
                        lock.lockedUntil = now + duration
                    end
                    return locked or shouldLock
                end
                function lock.reset()
                    lock.lockedUntil = nil
                end
                return lock
            end
            local meleeLock = newShootLock()
            local meleeWindowUntil = -1
            local meleeCooldown = -1
            local function lookAtFlat(from, to)
                local n = to - from
                local forward = Vector3.new(n.X, 0, n.Z)
                if forward.Magnitude < 0.001 then
                    forward = Vector3.new(0, 0, -1)
                end
                return CFrame.lookAt(from, from + forward, Vector3.new(0, -1, 0))
            end
            local function glueCFrame(target, above)
                local head = target.hitboxHead
                local offset = above and OFFSET_ABOVE or OFFSET_BELOW
                local glued = head.CFrame
                if above then
                    return glued + offset
                end
                return lookAtFlat(glued.Position + offset, head.Position)
            end
            local function randomEvasionCFrame(anchorPos, minRadius, maxRadius)
                local angle = randomGen:NextNumber(0, TAU)
                local radius = randomGen:NextNumber(minRadius, maxRadius)
                local base = CFrame.new(anchorPos + Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius))
                return base * CFrame.fromOrientation(
                    randomGen:NextNumber(0, TAU),
                    randomGen:NextNumber(0, TAU),
                    randomGen:NextNumber(0, TAU)
                )
            end
            local function randomEvasion(rootCFrame)
                local baseRadius = cfg.baseRadius
                local maxRadius = baseRadius + baseRadius * cfg.radiusFactor
                local pos = rootCFrame.Position
                local anchor = cfg.anchorFromCharacter and pos or Vector3.new(0, pos.Y, 0)
                local targetCFrame = randomEvasionCFrame(anchor, baseRadius, maxRadius)
                local targetPos = targetCFrame.Position
                local x, y, z = targetPos.X, targetPos.Y, targetPos.Z
                local axis = randomGen:NextInteger(1, 3)
                if axis == 1 then
                    x = FAR
                elseif axis == 2 then
                    y = FAR
                else
                    z = FAR
                end
                return targetCFrame - targetPos + Vector3.new(x, y, z)
            end
            local function evadePlan(rootCFrame)
                return { cframe = randomEvasion(rootCFrame) }
            end
            local function planMelee(dt, target, item, canFire)
                local head = target.hitboxHead
                local above = manipulation.isAbove(target.fighter)
                local aimCFrame = glueCFrame(target, above)
                local pitch, yaw, roll = target.rootPart.CFrame:ToOrientation()
                local n33 = above and -HALF_PI or HALF_PI
                local encA = manipulation.patchEncoding(above and manipulation.msEncA or manipulation.msEncC, n33, yaw, roll)
                local encB = manipulation.patchEncoding(above and manipulation.msEncB or manipulation.msEncD, n33, yaw, roll)
                local viewAngles = { Pitch = math.deg(pitch), Yaw = math.deg(yaw) }
                local objectId = manipulation.itemObjectId(item)
                local now = os.clock()
                if now < meleeWindowUntil then
                    return aimCFrame, viewAngles, function()
                        fireMelee("StartAiming", "HeavyAttackAnimation1", objectId, encA, encB, head, manipulation.msRot)
                    end
                end
                if not meleeLock.shouldFire(canFire, dt * cfg.shootFrames) then
                    return CFrame.new(math.random(-10000000, -100000), math.random(5000, 10000), math.random(-10000000, -100000)), nil, nil
                end
                if now < meleeCooldown then
                    return CFrame.new(math.random(-10000000, -100000), math.random(5000, 10000), math.random(-10000000, -100000)), nil, nil
                end
                if manipulation.itemName(item) == "Knife" then
                    meleeWindowUntil = now + 0.625
                    meleeCooldown = now + 1.25
                    return aimCFrame, viewAngles, function()
                        fireMelee("StartAiming", "HeavyAttackAnimation1", objectId, encA, encB, head, manipulation.msRot)
                    end
                end
                return aimCFrame, nil, function()
                    fireMelee("StartShooting", "AttackAnimation1", objectId, encA, encB, head, manipulation.msRot)
                end
            end
            local function makePlan(dt, fighter, action, target, rootCFrame)
                if farmMode then
                    return evadePlan(rootCFrame)
                end
                local canFire = target ~= nil and not spatialTick(target)
                if action == nil then
                    return evadePlan(rootCFrame)
                end
                if action.type == "Swap" then
                    local plan = evadePlan(rootCFrame)
                    local item = action.item
                    local index = action.index
                    plan.action = function() equipItem(item, index) end
                    return plan
                end
                if target == nil then
                    return evadePlan(rootCFrame)
                end
                if action.itemType == "Melee" then
                    local aimCFrame, angles, act = planMelee(dt, target, action.item, canFire)
                    return { cframe = aimCFrame, viewAngles = angles, action = act, skipDefense = true, forceCrouch = true }
                end
                return {}
            end
            local lastDefensiveAngles = nil
            local function applyPlan(plan, target, root)
                local cf = plan.cframe
                if cf == nil or target == nil or plan.skipDefense then
                    applyServerCFrame(root, cf)
                    sendViewAngles(20, plan.viewAngles)
                    return
                end
                applyServerCFrame(root, cf)
                if plan.aimPose or plan.defendInPlace then
                    lastDefensiveAngles = nil
                end
                sendViewAngles(9, plan.viewAngles or lastDefensiveAngles)
            end
            local function resetState()
                meleeModeState.lastTargetWorld = nil
                lastDefensiveAngles = nil
                applyForcedCrouch(false)
                meleeWindowUntil = -1
                meleeCooldown = -1
                meleeLock.reset()
                renderRestore()
                sendViewAngles(20, nil)
            end
            local lastUpdate = 0
            meleeModeState.conn = track(runService.Heartbeat:Connect(function(dt)
                if not meleeModeState.active then return end
                local currentTime = tick()
                local elapsed = currentTime - lastUpdate
                if elapsed < 0.016 then return end
                lastUpdate = currentTime
                local fighter = getLocalFighter()
                local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
                if fighter == nil or root == nil then
                    resetState()
                    return
                end
                local rootCFrame = root.CFrame
                if config.meleeManipulation then
                    app.internalMeleeManipulationRealCFrame = rootCFrame
                end
                local action = getAction(fighter)
                local target = selectTarget()
                meleeModeState.lastTargetWorld = target ~= nil and target.rootPart.Position or nil
                local plan = makePlan(elapsed, fighter, action, target, rootCFrame)
                applyPlan(plan, target, root)
                applyForcedCrouch(plan.forceCrouch == true)
                if plan.action ~= nil then
                    plan.action()
                end
            end))
            meleeModeState.cleanup = function()
                meleeModeState.conn = disconnect(meleeModeState.conn)
                pcall(function() runService:UnbindFromRenderStep(app.meleeModeRenderId) end)
                renderRestore()
                applyForcedCrouch(false)
                meleeModeState.lastTargetWorld = nil
                pcall(function() workspace.FallenPartsDestroyHeight = originalFallenHeight end)
            end
        end

        app.stopMeleeMode = function()
            meleeModeState.active = false
            meleeModeState.conn = disconnect(meleeModeState.conn)
            local cleanup = meleeModeState.cleanup
            meleeModeState.cleanup = nil
            if cleanup then
                pcall(cleanup)
            end
        end

        task.wait()
        task.wait()
        ui.boxTeleportation = tabs.aggression:AddLeftGroupbox("Teleportation")

        ui.boxTeleportation:AddToggle("teleportationEn", { Text = "Teleportation", Default = false }):OnChanged(function(v)
            if v then
                config.teleportation = true
                app.startTeleportation()
            else
                app.stopTeleportation()
            end
        end)

        ui.boxTeleportation:AddSlider("teleportationDistSl", { Text = "Distance", Default = 0, Min = 0, Max = 100, Rounding = 0 }):OnChanged(function(v)
            config.teleportationDist = v
            if teleportationActive and teleportationBoundRootPart and teleportationBoundTarget then
                pcall(app.buildTeleportationConstraint, teleportationBoundRootPart, teleportationBoundTarget)
            end
        end)

        ui.boxTeleportation:AddSlider("teleportationHeightSl", { Text = "Height", Default = 0, Min = -50, Max = 50, Rounding = 0 }):OnChanged(function(v)
            config.teleportationHeight = v
            if teleportationActive and teleportationBoundRootPart and teleportationBoundTarget then
                pcall(app.buildTeleportationConstraint, teleportationBoundRootPart, teleportationBoundTarget)
            end
        end)

        function app.getPlayerList()
            local names = { "Closest" }
            for _, p in ipairs(players:GetPlayers()) do
                if p ~= player then
                    table.insert(names, p.Name)
                end
            end
            return names
        end

        ui.teleportationTargetDrop = ui.boxTeleportation:AddDropdown("teleportationTargetSel", {
            Text = "Target Player",
            Default = 1,
            Values = app.getPlayerList(),
        })

        ui.teleportationTargetDrop:OnChanged(function(v) setConfig("teleportationTargetPlayerName", v) end)

        track(players.PlayerAdded:Connect(function()
            pcall(function() ui.teleportationTargetDrop:SetValues(app.getPlayerList()) end)
        end))

        track(players.PlayerRemoving:Connect(function()
            task.wait(0.1)
            pcall(function() ui.teleportationTargetDrop:SetValues(app.getPlayerList()) end)
        end))

        ui.boxTeleportation:AddSlider("teleportationSnapCountSl", { Text = "Snap Count", Default = 3, Min = 1, Max = 8, Rounding = 0 }):OnChanged(function(v) setConfig("teleportationSnapCount", v) end)
        ui.boxTeleportation:AddDropdown("teleportationAttachModeSel", { Text = "TP Part", Default = 1, Values = { "Head", "HRP", "Torso", "UpperTorso", "LowerTorso", "Left Arm", "Right Arm", "Left Leg", "Right Leg", "LeftUpperArm", "LeftLowerArm", "LeftHand", "RightUpperArm", "RightLowerArm", "RightHand", "LeftUpperLeg", "LeftLowerLeg", "LeftFoot", "RightUpperLeg", "RightLowerLeg", "RightFoot" } }):OnChanged(function(v)
            config.teleportationAttachMode = v
            if teleportationActive then
                teleportationTargetDirty = true
            end
        end)

        ui.boxTeleportation:AddToggle("teleportationTeamCheckTog", { Text = "Team Check", Default = true }):OnChanged(function(v)
            config.teleportationTeamCheck = v
            if teleportationActive then
                teleportationTargetDirty = true
            end
        end)

        ui.boxTeleportation:AddDropdown("teleportationPrioritySel", {
            Text = "Target Priority", Default = 1, Values = { "Closest", "Lowest Health", "Closest To Cursor" }
        }):OnChanged(function(v)
            config.teleportationPriority = v
            if teleportationActive then
                teleportationTargetDirty = true
            end
        end)

        do
            local riotBypassConn = nil
            local riotBypassActive = false
            local function riotBypassFlat(targetRoot)
                local look = targetRoot.CFrame.LookVector
                local flat = Vector3.new(look.X, 0, look.Z)
                if flat.Magnitude < 0.001 then
                    return Vector3.new(0, 0, -1)
                end
                return flat.Unit
            end
            local function riotBypassFighter(targetCharacter)
                local ok, controller = pcall(function() return requireOptionalModule(player.PlayerScripts.Controllers.FighterController) end)
                if not ok or type(controller) ~= "table" then return nil end
                return manipulation.findFighter(controller, targetCharacter)
            end
            local function riotBypassHasShield(targetCharacter)
                local fighter = riotBypassFighter(targetCharacter)
                if not fighter then return false end
                local obs = rawget(fighter, "itemObserver") or rawget(fighter, "ItemObserver")
                if not obs then return false end
                local ok, equipped = pcall(function() return obs:GetEquippedItem() end)
                if not ok or not equipped then return false end
                return equipped.name == "Riot Shield" or equipped.Name == "Riot Shield"
            end
            local function riotBypassStep()
                if not config.riotBypass then
                    riotBypassConn = disconnect(riotBypassConn)
                    app.destroyTeleportationConstraint()
                    return
                end
                local myRoot = app.getHumanoidRootPart(player)
                if not myRoot then return end
                local myHumanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
                if not myHumanoid or myHumanoid.Health <= 0 then return end
                local playerPosition = myRoot.Position
                local pickedRoot, pickedCharacter = nil, nil
                local targetName = config.riotBypassTargetName or "Closest"
                if targetName ~= "" and targetName ~= "Closest" then
                    local namedPlayer = players:FindFirstChild(targetName)
                    local callSucceeded, targetRootPart = app.teleportationIsValid(namedPlayer, false)
                    if callSucceeded and targetRootPart and riotBypassHasShield(namedPlayer.Character) then
                        pickedRoot = targetRootPart
                        pickedCharacter = namedPlayer.Character
                    end
                end
                if not pickedRoot then
                    local bestScore = math.huge
                    for _, p in ipairs(players:GetPlayers()) do
                        local callSucceeded, targetRootPart, targetHumanoid = app.teleportationIsValid(p, true)
                        if callSucceeded and riotBypassHasShield(p.Character) then
                            local scoreValue = app.teleportationScore(targetRootPart, targetHumanoid, playerPosition, "Closest")
                            if scoreValue < bestScore then
                                bestScore = scoreValue
                                pickedRoot = targetRootPart
                                pickedCharacter = p.Character
                            end
                        end
                    end
                end
                if not pickedRoot then
                    app.destroyTeleportationConstraint()
                    return
                end
                local head = pickedCharacter:FindFirstChild("Head") or pickedRoot
                local headPos = head.Position
                local flat = riotBypassFlat(pickedRoot)
                local distance = tonumber(config.riotBypassDistance) or 3.5
                local extraY = tonumber(config.riotBypassHeight) or 1.5
                local rearOrigin = headPos - (flat * math.max(distance * 0.55, 3.5)) + Vector3.new(0, 1.5 + extraY, 0)
                if not app.validVector(rearOrigin) then return end
                local overrideCFrame = CFrame.lookAt(rearOrigin, headPos)
                pcall(app.buildTeleportationConstraint, myRoot, head, overrideCFrame)
            end
            app.startRiotBypass = function()
                if riotBypassActive then return end
                riotBypassActive = true
                config.riotBypass = true
                app.bindTeleportationRestore()
                riotBypassConn = disconnect(riotBypassConn)
                riotBypassConn = track(runService.Heartbeat:Connect(function()
                    pcall(riotBypassStep)
                end))
                config.fireRedirection = true
                app.startFireRedirection()
            end
            app.stopRiotBypass = function()
                riotBypassActive = false
                config.riotBypass = false
                riotBypassConn = disconnect(riotBypassConn)
                app.destroyTeleportationConstraint()
                if not config.teleportation then
                    app.unbindTeleportationRestore()
                end
                pcall(app.stopFireRedirection)
            end
        end

        do
            local elevatedKnifeConn = nil
            local elevatedKnifeActive = false
            local function elevatedKnifeFlat(targetRoot)
                local look = targetRoot.CFrame.LookVector
                local flat = Vector3.new(look.X, 0, look.Z)
                if flat.Magnitude < 0.001 then
                    return Vector3.new(0, 0, -1)
                end
                return flat.Unit
            end
            local function elevatedKnifeFighter(targetCharacter)
                local ok, controller = pcall(function() return requireOptionalModule(player.PlayerScripts.Controllers.FighterController) end)
                if not ok or type(controller) ~= "table" then return nil end
                return manipulation.findFighter(controller, targetCharacter)
            end
            local function elevatedKnifeHasKnife(targetCharacter)
                local fighter = elevatedKnifeFighter(targetCharacter)
                if not fighter then return false end
                local obs = rawget(fighter, "itemObserver") or rawget(fighter, "ItemObserver")
                if not obs then return false end
                local ok, equipped = pcall(function() return obs:GetEquippedItem() end)
                if not ok or not equipped then return false end
                local itemName = equipped.name or equipped.Name
                return itemName ~= nil and itemName ~= "Riot Shield" and itemName ~= "Gun"
            end
            local function elevatedKnifeStep()
                if not config.elevatedKnifeCounter then
                    elevatedKnifeConn = disconnect(elevatedKnifeConn)
                    app.destroyTeleportationConstraint()
                    return
                end
                local myRoot = app.getHumanoidRootPart(player)
                if not myRoot then return end
                local myHumanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
                if not myHumanoid or myHumanoid.Health <= 0 then return end
                local mode = config.elevatedKnifeCounterMode or "Closest"
                local playerPosition = myRoot.Position
                local bestScore = math.huge
                local pickedRoot, pickedCharacter = nil, nil
                for _, p in ipairs(players:GetPlayers()) do
                    local callSucceeded, targetRootPart, targetHumanoid = app.teleportationIsValid(p, true)
                    if callSucceeded and elevatedKnifeHasKnife(p.Character) then
                        local scoreValue = app.teleportationScore(targetRootPart, targetHumanoid, playerPosition, mode)
                        if scoreValue < bestScore then
                            bestScore = scoreValue
                            pickedRoot = targetRootPart
                            pickedCharacter = p.Character
                        end
                    end
                end
                if not pickedRoot then
                    app.destroyTeleportationConstraint()
                    return
                end
                local head = pickedCharacter:FindFirstChild("Head") or pickedRoot
                local headPos = head.Position
                local flat = elevatedKnifeFlat(pickedRoot)
                local distance = tonumber(config.elevatedKnifeCounterDistance) or 4
                local extraY = tonumber(config.elevatedKnifeCounterHeight) or 6.5
                local elevatedOrigin = headPos - (flat * math.max(distance * 0.55, 3.5)) + Vector3.new(0, 2 + extraY, 0)
                if not app.validVector(elevatedOrigin) then return end
                local overrideCFrame = CFrame.lookAt(elevatedOrigin, headPos)
                pcall(app.buildTeleportationConstraint, myRoot, head, overrideCFrame)
            end
            app.startElevatedKnifeCounter = function()
                if elevatedKnifeActive then return end
                elevatedKnifeActive = true
                config.elevatedKnifeCounter = true
                app.bindTeleportationRestore()
                elevatedKnifeConn = disconnect(elevatedKnifeConn)
                elevatedKnifeConn = track(runService.Heartbeat:Connect(function()
                    pcall(elevatedKnifeStep)
                end))
                config.fireRedirection = true
                app.startFireRedirection()
            end
            app.stopElevatedKnifeCounter = function()
                elevatedKnifeActive = false
                config.elevatedKnifeCounter = false
                elevatedKnifeConn = disconnect(elevatedKnifeConn)
                app.destroyTeleportationConstraint()
                if not config.teleportation then
                    app.unbindTeleportationRestore()
                end
                pcall(app.stopFireRedirection)
            end
        end

        ui.boxMeleeBypass = tabs.aggression:AddLeftGroupbox("Bypasses")

        ui.boxMeleeBypass:AddToggle("wbGunMeleeBypassEn", { Text = "Gun/Melee Bypass", Default = false }):OnChanged(function(v)
            app.setGunMeleeBypass("main", v)
        end)

        ui.gunMeleeBypassLabel = ui.boxMeleeBypass:AddLabel("disable ur evasion")

        ui.boxMeleeBypass:AddToggle("wbTranslocationCounterEn", { Text = "Translocation Counter", Default = false }):OnChanged(function(v)
            config.translocationCounter = v
            if v then
                app.startTranslocationCounter()
            else
                app.stopTranslocationCounter()
            end
        end)

        ui.translocationCounterLabel = ui.boxMeleeBypass:AddLabel("disable ur evasion")

        ui.boxMeleeBypass:AddToggle("wbAntiWeaponBypassEn", { Text = "Anti Weapon Bypass", Default = false }):OnChanged(function(v)
            config.antiWeaponBypass = v
            if v then
                app.startAntiWeaponBypass()
            else
                app.stopAntiWeaponBypass()
            end
        end)

        ui.antiWeaponBypassLabel = ui.boxMeleeBypass:AddLabel("disable ur evasion")

        ui.boxMeleeBypass:AddToggle("wbFlickControlEn", { Text = "Flick Control", Default = false, Tooltip = "hit most of ur shots" }):OnChanged(function(v)
            app.voidFlickOwned = false
            setConfig("voidFlick", v)
            if v then
                app.startVoidFlick()
            else
                app.stopVoidFlick()
            end
        end)

        ui.flickControlLabel = ui.boxMeleeBypass:AddLabel("disable ur evasion")

        ui.boxWeaponBypass = ui.boxMeleeBypass
        ui.boxMods = tabs.aggression:AddRightGroupbox("Mods")

        ui.boxMods:AddToggle("modsFireRedirectEn", { Text = "Fire Redirection", Default = false }):OnChanged(function(v)
            config.fireRedirection = v
            if v then
                app.startFireRedirection() else app.stopFireRedirection()
            end
        end)

        ui.boxMods:AddToggle("modsRapidFireEn", { Text = "Rapid Fire", Default = false }):OnChanged(function(v)
            config.rapidFire = v
            if v then
                app.startRapidFire() else app.stopRapidFire()
            end
        end)

        ui.boxMods:AddToggle("modsFullAutoEn", { Text = "Full Auto", Default = false }):OnChanged(function(v)
            config.fullAuto = v
            if v then
                app.startFullAuto() else app.stopFullAuto()
            end
        end)

        do
            local builtInRagebotUseItem = replicatedStorage.Remotes.Replication.Fighter.UseItem
            local builtInRagebotUpdateRotation = nil
            pcall(function()
                builtInRagebotUpdateRotation = replicatedStorage.Remotes.Replication.Fighter:FindFirstChild('UpdateRotation') or replicatedStorage.Remotes:FindFirstChild('UpdateRotation', true)
            end)
            local BUILT_IN_RAGEBOT_SETTLE, BUILT_IN_RAGEBOT_HOLD = 0.05, 1
            local BUILT_IN_RAGEBOT_EYE, BUILT_IN_RAGEBOT_CROUCHED_EYE = 1.75, 0.25
            local BUILT_IN_RAGEBOT_VOID, BUILT_IN_RAGEBOT_HEIGHT = 1000000, 2 ^ 20
            local BUILT_IN_RAGEBOT_CAMERA, BUILT_IN_RAGEBOT_MUZZLE, BUILT_IN_RAGEBOT_HIT_PART, BUILT_IN_RAGEBOT_HIT_OFFSET = '\0', '\1', '\2', '\3'
            local BUILT_IN_RAGEBOT_PACKED = { '\0', '\1', '\2', '\3', '\4', '\5' }
            local BUILT_IN_RAGEBOT_SCATTER = 0.1
            local BUILT_IN_RAGEBOT_TAU = 2 * math.pi
            local BUILT_IN_RAGEBOT_GAP = 2
            local BUILT_IN_RAGEBOT_CONE = math.cos(math.rad(60))
            local BUILT_IN_RAGEBOT_TRACK_REACH = 16
            local BUILT_IN_RAGEBOT_LIFT, BUILT_IN_RAGEBOT_CEILING = 6000, 40000
            local BUILT_IN_RAGEBOT_HOP_EVERY, BUILT_IN_RAGEBOT_HOP_MIN, BUILT_IN_RAGEBOT_HOP_MAX = 4, 1000, 2000

            local builtInRagebotState = {
                active = false,
                counterActive = false,
                report = nil,
                real = nil,
                attacks = nil,
                priority = { players = {}, current = nil },
                unjoin = nil,
                counter = nil,
            }

            local builtInRagebotSettings = {
                active = false,
                voidSpam = true,
                voidHide = 0.25,
                voidAttack = 0.1,
                shootAttempts = 1,
                mode = 'gun',
                primary = true,
                swapWhenEmpty = false,
                autoPrioritize = false,
                notify = true,
                join = { attackers = true, ['voided players'] = true },
            }

            local builtInRagebotCounterSettings = {
                active = false,
                mode = 'ue',
                enemiesOnly = true,
                aliveOnly = true,
                voidSpeed = 3000,
                engine = { flySpeed = 15000, zigAmplitude = 400, zigFrequency = 8, cycle = 0.05, flyTime = 0.025, depth = 6, boost = 100000, boostEvery = 0.6, spread = 30 },
                bots = { on = true, stay = 0.35, gap = 0.5, lead = 6 },
                legits = { on = true, stay = 0.35, gap = 0.5, lead = 6, delay = 3, max = 1, priority = 'lowest health' },
            }

            local builtInRagebotParams = RaycastParams.new()
            builtInRagebotParams.FilterType = Enum.RaycastFilterType.Exclude
            local builtInRagebotToSpawn

            local function builtInRagebotLog(message)
                warn('[rage] ' .. tostring(message))
            end

            local function builtInRagebotSetIdentity(value)
                if type(setthreadidentity) == 'function' then
                    pcall(setthreadidentity, value)
                end
            end

            local function builtInRagebotRoot()
                local character = player.Character
                return character and character:FindFirstChild('HumanoidRootPart')
            end

            local builtInRagebotControllerCache = nil

            local function builtInRagebotController()
                local cached = builtInRagebotControllerCache
                if cached then return cached end
                local controller = requireOptionalModule(player.PlayerScripts.Controllers.FighterController)
                if controller then
                    builtInRagebotControllerCache = controller
                end
                return controller
            end

            local builtInRagebotSpectateCache = nil

            local function builtInRagebotDuel()
                if not builtInRagebotSpectateCache then
                    builtInRagebotSpectateCache = requireOptionalModule(player.PlayerScripts.Controllers.SpectateController)
                end
                local current = builtInRagebotSpectateCache and builtInRagebotSpectateCache.CurrentDuelSubject
                if type(current) ~= 'table' then return nil end
                return current
            end

            local function builtInRagebotEnums()
                return requireOptionalModule(replicatedStorage.Modules.EnumLibrary)
            end

            local function builtInRagebotAlive(fighter)
                if type(fighter) ~= 'table' or type(fighter.Items) ~= 'table' or #fighter.Items == 0 then
                    return false
                end
                local character = player.Character
                local humanoid = character and character:FindFirstChildOfClass('Humanoid')
                return humanoid ~= nil and humanoid.Health > 0
            end

            local function builtInRagebotInvincible(fighter)
                local entity = fighter and fighter.Entity
                if type(entity) ~= 'table' then return true end
                if entity._invincibility_visual then return true end
                local data = rawget(entity, 'Data')
                return data ~= nil and rawget(data, 'IsInvincible') == true
            end

            local function builtInRagebotDeflecting(fighter)
                local item = fighter and fighter.EquippedItem
                if type(item) ~= 'table' then return false end
                return item._deflect_hash ~= nil and type(item._attack_cooldown) == 'number' and tick() < item._attack_cooldown
            end

            local function builtInRagebotClear(from, to)
                return workspace:Raycast(from, to - from, builtInRagebotParams) == nil
            end

            local function builtInRagebotReplicate(root)
                builtInRagebotSetIdentity(8)
                if type(sethiddenproperty) == 'function' and root then
                    pcall(sethiddenproperty, root, 'PhysicsRepRootPart', workspace.Terrain)
                end
            end

            local function builtInRagebotSetReport(status, target)
                builtInRagebotState.report = status and { status = status, target = target } or nil
            end

            local function builtInRagebotPack(frame)
                local x, y, z = frame:ToOrientation()
                local position = frame.Position
                local values = { position.X, position.Y, position.Z, x, y, z }
                local packed = {}
                for index, key in ipairs(BUILT_IN_RAGEBOT_PACKED) do
                    packed[key] = values[index]
                end
                return packed
            end

            local function builtInRagebotUnpack(packed)
                if type(packed) ~= 'table' then return nil end
                local values = table.create(6)
                for index, key in ipairs(BUILT_IN_RAGEBOT_PACKED) do
                    local value = packed[key]
                    if type(value) ~= 'number' then return nil end
                    values[index] = value
                end
                return CFrame.new(values[1], values[2], values[3]) * CFrame.fromOrientation(values[4], values[5], values[6])
            end

            local function builtInRagebotScatter()
                return CFrame.new(math.random() * BUILT_IN_RAGEBOT_SCATTER, math.random() * BUILT_IN_RAGEBOT_SCATTER, math.random() * BUILT_IN_RAGEBOT_SCATTER)
            end

            local function builtInRagebotAim(cameraData, part, manipulationData)
                if type(cameraData) ~= 'table' then return end
                local camera, muzzle = builtInRagebotUnpack(cameraData[BUILT_IN_RAGEBOT_CAMERA]), builtInRagebotUnpack(cameraData[BUILT_IN_RAGEBOT_MUZZLE])
                if not camera or not muzzle then return end
                local offset = CFrame.new(Random.new():NextUnitVector() * BUILT_IN_RAGEBOT_SCATTER)
                if manipulationData then
                    camera = CFrame.new(manipulationData.origin) * camera.Rotation
                    muzzle = CFrame.new(manipulationData.origin) * muzzle.Rotation
                    if manipulationData.hitOffset then
                        offset = CFrame.new(manipulationData.hitOffset)
                    end
                else
                    camera = CFrame.lookAt(camera.Position, part.Position)
                    muzzle = CFrame.lookAt(muzzle.Position, part.Position)
                end
                cameraData[BUILT_IN_RAGEBOT_CAMERA] = builtInRagebotPack(camera)
                cameraData[BUILT_IN_RAGEBOT_MUZZLE] = builtInRagebotPack(muzzle)
                cameraData[BUILT_IN_RAGEBOT_HIT_OFFSET] = builtInRagebotPack(offset)
                cameraData[BUILT_IN_RAGEBOT_HIT_PART] = part
            end

            local function builtInRagebotSwingData(aimCFrame, part)
                return {
                    ['\0'] = builtInRagebotPack(aimCFrame),
                    ['\1'] = builtInRagebotPack(aimCFrame + Vector3.one * 0.01),
                    ['\2'] = part,
                    ['\3'] = builtInRagebotPack(builtInRagebotScatter()),
                }
            end

            local function builtInRagebotSwingAnimation(item, heavy)
                local kind = heavy and 'HeavyAttack' or 'Attack'
                local viewModel = item.ViewModel
                if not viewModel then return nil end
                local count = #viewModel:GetAnimationKeys(kind)
                if count == 0 then return nil end
                if heavy then
                    item._heavy_attack_num = (item._heavy_attack_num or 0) % count + 1
                    return string.format('%s%s', kind, item._heavy_attack_num)
                end
                item._attack_num = (item._attack_num or 0) % count + 1
                return string.format('%s%s', kind, item._attack_num)
            end

            local function builtInRagebotSwingSend(enums, item, aimCFrame, part, heavy)
                local animation = builtInRagebotSwingAnimation(item, heavy)
                if not animation then return false end
                builtInRagebotUseItem:FireServer(item:Get('ObjectID'), enums:ToEnum(heavy and 'StartAiming' or 'StartShooting'), {
                    ['\1'] = builtInRagebotSwingData(aimCFrame, part),
                    ['\2'] = enums:ToEnum(animation),
                }, nil)
                return true
            end

            local function builtInRagebotTurn(angle)
                return utf8.char(math.clamp(math.floor(angle % BUILT_IN_RAGEBOT_TAU / math.pi / 2 * 256 + 0.5), 0, 255))
            end

            local function builtInRagebotEncodePose(pitch, yaw)
                return builtInRagebotTurn(pitch) .. builtInRagebotTurn(yaw)
            end

            local builtInRagebotPipeline = {
                active = false, users = 0, holding = false, release = nil,
                loop = nil, storageIndex = nil, utilityIndex = nil,
                originalStorage = nil, originalUtility = nil,
            }

            local function builtInRagebotPipelineTeardown()
                if not builtInRagebotPipeline.active then return end
                builtInRagebotPipeline.active = false
                builtInRagebotPipeline.holding = false
                if builtInRagebotPipeline.release then
                    pcall(task.cancel, builtInRagebotPipeline.release)
                    builtInRagebotPipeline.release = nil
                end
                if builtInRagebotPipeline.loop then
                    pcall(debug.setupvalue, builtInRagebotPipeline.loop, builtInRagebotPipeline.storageIndex, builtInRagebotPipeline.originalStorage)
                    pcall(debug.setupvalue, builtInRagebotPipeline.loop, builtInRagebotPipeline.utilityIndex, builtInRagebotPipeline.originalUtility)
                end
                builtInRagebotPipeline.loop = nil
            end

            local function builtInRagebotPipelineBuild()
                if builtInRagebotPipeline.active then return true end
                local controller = builtInRagebotController()
                local loop = controller and controller._CameraReplicationLoop
                if type(loop) ~= 'function' then return false end
                local utility = requireOptionalModule(replicatedStorage.Modules.Utility)
                if not utility then return false end
                local encode = utility.EncodeCameraRotation
                if type(encode) ~= 'function' then return false end
                local ok, upvalues = pcall(debug.getupvalues, loop)
                if not ok or type(upvalues) ~= 'table' then return false end
                local storageIndex, utilityIndex
                for index, value in ipairs(upvalues) do
                    if value == replicatedStorage then
                        storageIndex = index
                    end
                    if value == utility then
                        utilityIndex = index
                    end
                end
                if not storageIndex or not utilityIndex then return false end
                local swallow
                local swallowing = setmetatable({}, {
                    __index = function() return swallow end,
                    __call = function() return swallow end,
                    __newindex = function() end,
                    __tostring = function() return 'ReplicatedStorage' end,
                    __metatable = 'The metatable is locked',
                })
                swallow = swallowing
                local storageStandIn = setmetatable({}, {
                    __index = function(_, key)
                        if builtInRagebotPipeline.holding then
                            return swallowing
                        end
                        return replicatedStorage[key]
                    end,
                    __tostring = function() return 'ReplicatedStorage' end,
                    __metatable = 'The metatable is locked',
                })
                local utilityStandIn = setmetatable({}, { __index = utility })
                utilityStandIn.EncodeCameraRotation = function(_, rotation, ...)
                    if builtInRagebotState.report ~= nil then
                        return '\0\0'
                    end
                    return encode(utility, rotation, ...)
                end
                local storageOk = pcall(debug.setupvalue, loop, storageIndex, storageStandIn)
                local utilityOk = pcall(debug.setupvalue, loop, utilityIndex, utilityStandIn)
                if not storageOk or not utilityOk then
                    pcall(debug.setupvalue, loop, storageIndex, replicatedStorage)
                    pcall(debug.setupvalue, loop, utilityIndex, utility)
                    return false
                end
                builtInRagebotPipeline.active = true
                builtInRagebotPipeline.loop = loop
                builtInRagebotPipeline.storageIndex, builtInRagebotPipeline.utilityIndex = storageIndex, utilityIndex
                builtInRagebotPipeline.originalStorage, builtInRagebotPipeline.originalUtility = replicatedStorage, utility
                return true
            end

            local function builtInRagebotHoldSend(encoded)
                if not builtInRagebotPipeline.active then return end
                local remote = builtInRagebotUpdateRotation
                if not remote then return end
                pcall(function()
                    remote:FireServer(encoded, nil)
                end)
                builtInRagebotPipeline.holding = true
                if builtInRagebotPipeline.release then
                    pcall(task.cancel, builtInRagebotPipeline.release)
                end
                builtInRagebotPipeline.release = task.delay(BUILT_IN_RAGEBOT_HOLD, function()
                    builtInRagebotPipeline.holding = false
                    builtInRagebotPipeline.release = nil
                end)
            end

            local function builtInRagebotPipelineAcquire()
                builtInRagebotPipeline.users = builtInRagebotPipeline.users + 1
                builtInRagebotPipelineBuild()
            end

            local function builtInRagebotPipelineRelease()
                builtInRagebotPipeline.users = math.max(0, builtInRagebotPipeline.users - 1)
                if builtInRagebotPipeline.users == 0 then
                    builtInRagebotPipelineTeardown()
                end
            end

            local builtInRagebotDesync = { active = false, members = {}, real = nil, root = nil, conn = nil, users = 0, name = '__builtInRagebotRestore' }

            local function builtInRagebotDesyncJoin(order, propose, idle)
                local member = { order = order, propose = propose, idle = idle }
                table.insert(builtInRagebotDesync.members, member)
                table.sort(builtInRagebotDesync.members, function(a, b)
                    return a.order < b.order
                end)
                return function()
                    local at = table.find(builtInRagebotDesync.members, member)
                    if at then
                        table.remove(builtInRagebotDesync.members, at)
                    end
                end
            end

            local function builtInRagebotDesyncStep(dt)
                local root = builtInRagebotRoot()
                local controller = builtInRagebotController()
                if not root or not builtInRagebotAlive(controller and controller.LocalFighter) then
                    builtInRagebotDesync.real, builtInRagebotDesync.root = nil, nil
                    for _, member in pairs(builtInRagebotDesync.members) do
                        if member.idle then
                            pcall(member.idle)
                        end
                    end
                    return
                end
                local real = readProperty(root, 'CFrame')
                if not real then return end
                builtInRagebotDesync.root, builtInRagebotDesync.real = root, real
                for _, member in pairs(builtInRagebotDesync.members) do
                    local ok, server = pcall(member.propose, real, root, dt)
                    if not ok then
                        root.CFrame = real
                        builtInRagebotLog('desync member failed: ' .. tostring(server))
                    elseif server then
                        root.CFrame = server
                        return
                    else
                        real = readProperty(root, 'CFrame')
                        builtInRagebotDesync.real = real
                    end
                end
                builtInRagebotDesync.real = nil
            end

            local function builtInRagebotDesyncAcquire()
                builtInRagebotDesync.users = builtInRagebotDesync.users + 1
                if builtInRagebotDesync.active then return end
                builtInRagebotDesync.active = true
                pcall(function() runService:UnbindFromRenderStep(builtInRagebotDesync.name) end)
                pcall(function()
                    runService:BindToRenderStep(builtInRagebotDesync.name, Enum.RenderPriority.Camera.Value - 1, function()
                        local root, real = builtInRagebotDesync.root, builtInRagebotDesync.real
                        if root and real and root.Parent then
                            root.CFrame = real
                        end
                    end)
                end)
                builtInRagebotDesync.conn = track(runService.Heartbeat:Connect(builtInRagebotDesyncStep))
            end

            local function builtInRagebotDesyncRelease()
                builtInRagebotDesync.users = math.max(0, builtInRagebotDesync.users - 1)
                if builtInRagebotDesync.users > 0 then return end
                builtInRagebotDesync.active = false
                builtInRagebotDesync.conn = disconnect(builtInRagebotDesync.conn)
                builtInRagebotDesync.real, builtInRagebotDesync.root = nil, nil
                pcall(function() runService:UnbindFromRenderStep(builtInRagebotDesync.name) end)
            end

            local function builtInRagebotCandidate(other, dueler)
                if other == player or type(dueler) ~= 'table' or dueler._is_ally then return nil end
                local character = other.Character
                local humanoid = character and character:FindFirstChildOfClass('Humanoid')
                if not character or not humanoid or humanoid.Health <= 0 then return nil end
                local root = character:FindFirstChild('HumanoidRootPart')
                local distance = (root and root:IsA('BasePart') and root.Position.Magnitude) or math.huge
                if not (distance < BUILT_IN_RAGEBOT_VOID) then return nil end
                local head = character:FindFirstChild('HitboxHead')
                local fighter = dueler.ClientFighter
                if not head or not head:IsA('BasePart') or not fighter or builtInRagebotInvincible(fighter) then return nil end
                if builtInRagebotDeflecting(fighter) then return nil end
                if not (head.Position.Magnitude < BUILT_IN_RAGEBOT_VOID) then return nil end
                return { part = head, character = character, fighter = fighter, name = other.Name, health = humanoid.Health }
            end

            local function builtInRagebotPrioritize(other)
                if other == player or table.find(builtInRagebotState.priority.players, other) then return end
                table.insert(builtInRagebotState.priority.players, other)
                pcall(function()
                    other.AncestryChanged:Once(function()
                        local at = table.find(builtInRagebotState.priority.players, other)
                        if at then
                            table.remove(builtInRagebotState.priority.players, at)
                        end
                    end)
                end)
                if builtInRagebotSettings.notify then
                    app.notify('Built-In Ragebot', 'Added ' .. tostring(other.Name) .. ' to priority')
                end
            end

            local function builtInRagebotPick(duelers, reachable)
                local checked, rejected = {}, {}
                local function available(other, dueler)
                    if rejected[other] then return nil end
                    local target = checked[other] or builtInRagebotCandidate(other, dueler)
                    if target and (not reachable or checked[other] or reachable(target)) then
                        checked[other] = target
                        return target
                    end
                    rejected[other] = true
                    return nil
                end
                if builtInRagebotSettings.autoPrioritize then
                    if builtInRagebotSettings.join['voided players'] then
                        for other, dueler in pairs(duelers) do
                            local character = other.Character
                            local root = character and character:FindFirstChild('HumanoidRootPart')
                            if other ~= player and not dueler._is_ally and root and root:IsA('BasePart') and root.Position.Magnitude > BUILT_IN_RAGEBOT_VOID then
                                builtInRagebotPrioritize(other)
                            end
                        end
                    end
                    for _, other in pairs(builtInRagebotState.priority.players) do
                        local dueler = duelers[other]
                        local target = dueler and available(other, dueler)
                        if target then
                            builtInRagebotState.priority.current = other
                            return target
                        end
                    end
                end
                local current = builtInRagebotState.priority.current
                local currentDueler = current and duelers[current]
                local held = current and currentDueler and available(current, currentDueler)
                if held then return held end
                local best, selected = nil, nil
                for other, dueler in pairs(duelers) do
                    local target = available(other, dueler)
                    if target and (not best or target.health < best.health or (target.health == best.health and target.name < best.name)) then
                        best, selected = target, other
                    end
                end
                builtInRagebotState.priority.current = selected
                return best
            end

            local builtInRagebotOrigins = {}
            function builtInRagebotOrigins.gun(target, preferred, eye, held)
                if held and (held.Position - target).Magnitude <= BUILT_IN_RAGEBOT_TRACK_REACH and builtInRagebotClear(held.Position + eye, target) then
                    return held
                end
                if builtInRagebotClear(preferred + eye, target) then
                    return CFrame.new(preferred)
                end
                for _, offset in ipairs({
                    Vector3.new(3, 1, 0),
                    Vector3.new(-3, 1, 0),
                    Vector3.new(0, 1, 3),
                    Vector3.new(0, 1, -3),
                    Vector3.new(3, 3, 3),
                    Vector3.new(-3, 3, -3),
                }) do
                    local position = target + offset
                    if builtInRagebotClear(position + eye, target) then
                        return CFrame.new(position)
                    end
                end
                return nil
            end

            local builtInRagebotAtk = {}
            function builtInRagebotAtk.new()
                return {
                    server = nil, meleeAt = tick(), swingAt = tick(), physicsAt = tick(),
                    shotAt = tick(), spamAt = tick(), hiding = false, burstAt = nil, burstAmmo = nil,
                    attackPose = nil, attackTarget = nil, attackItem = nil, attackMode = nil,
                    attackPosition = nil, poseFired = false, equipItem = nil, equipAt = 0,
                    reloadItem = nil, reloadAt = 0,
                }
            end
            local function builtInRagebotDetach(attacks)
                attacks.attackPose, attacks.attackTarget, attacks.attackItem = nil, nil, nil
                attacks.attackMode, attacks.attackPosition, attacks.burstAt = nil, nil, nil
                attacks.burstAmmo = nil
                attacks.poseFired = false
            end
            function builtInRagebotAtk.reset(attacks)
                builtInRagebotDetach(attacks)
                attacks.hiding, attacks.spamAt = false, tick()
                attacks.equipItem, attacks.reloadItem, attacks.equipAt, attacks.reloadAt = nil, nil, 0, 0
            end
            local function builtInRagebotSpamming(attacks)
                if not builtInRagebotSettings.voidSpam then
                    attacks.hiding, attacks.spamAt, attacks.burstAt = false, tick(), nil
                    return false
                end
                local now = tick()
                local item, ammo, started = attacks.attackItem, attacks.burstAmmo, attacks.burstAt
                local confirmed = item and ammo and started and (item.Data.Ammo or ammo) < ammo and (item.Info.ShootCooldown or 0) > builtInRagebotSettings.voidAttack and now >= started + BUILT_IN_RAGEBOT_SETTLE
                if attacks.hiding then
                    if now >= attacks.spamAt then
                        attacks.hiding = false
                    end
                elseif confirmed or (attacks.burstAt and now >= attacks.burstAt + math.max(builtInRagebotSettings.voidAttack, BUILT_IN_RAGEBOT_SETTLE)) or (not attacks.attackPose and now >= attacks.spamAt) then
                    attacks.hiding = true
                    attacks.spamAt = now + builtInRagebotSettings.voidHide
                end
                return attacks.hiding
            end
            local function builtInRagebotHideCFrame()
                local position = builtInRagebotState.real
                if position and position.Magnitude < BUILT_IN_RAGEBOT_HEIGHT then
                    return CFrame.new(position.X, BUILT_IN_RAGEBOT_HEIGHT, position.Z)
                end
                return CFrame.new(0, BUILT_IN_RAGEBOT_HEIGHT, 0)
            end
            local function builtInRagebotPlace(attacks, root, at)
                attacks.server = at
                if at then
                    root.CFrame = at
                end
                builtInRagebotReplicate(root)
            end
            local function builtInRagebotSettle(attacks, root)
                builtInRagebotDetach(attacks)
                attacks.physicsAt = tick() + BUILT_IN_RAGEBOT_SETTLE
                builtInRagebotPlace(attacks, root, builtInRagebotHideCFrame())
            end
            local function builtInRagebotAttach(attacks, root, item, target, mode, pose)
                local held, position = attacks.attackPose, attacks.attackPosition
                local reuse = mode == 'gun' and attacks.attackMode == mode and attacks.attackItem == item and held == pose
                local changed = not held or (attacks.attackTarget ~= target.part and not reuse) or attacks.attackItem ~= item or attacks.attackMode ~= mode or not position or (mode == 'gun' and held ~= pose)
                local moved = mode ~= 'gun' and position and (target.part.Position - position).Magnitude > 2
                if changed or (moved and attacks.poseFired) then
                    held = pose
                    attacks.attackPose, attacks.attackTarget, attacks.attackItem = held, target.part, item
                    attacks.attackMode, attacks.attackPosition = mode, target.part.Position
                    attacks.poseFired = false
                    if changed then
                        attacks.burstAt, attacks.burstAmmo = nil, nil
                    end
                    local ping = 0
                    pcall(function()
                        ping = player:GetNetworkPing()
                    end)
                    attacks.physicsAt = tick() + math.max(BUILT_IN_RAGEBOT_SETTLE, ping * 2 + 1 / 30)
                end
                attacks.attackTarget = target.part
                local published = held
                if not published then return nil, false end
                builtInRagebotPlace(attacks, root, published)
                return published, tick() >= attacks.physicsAt
            end
            local function builtInRagebotBeginBurst(attacks, now)
                attacks.poseFired = true
                if not attacks.burstAt then
                    attacks.burstAt = now
                    attacks.burstAmmo = attacks.attackItem and attacks.attackItem.Data.Ammo
                end
            end
            local function builtInRagebotEquip(attacks, fighter, item)
                local now = tick()
                if attacks.equipItem == item and now < attacks.equipAt then return end
                attacks.equipItem, attacks.equipAt = item, now + 0.25
                task.spawn(fighter.EquipItem, fighter, item.Data.ItemIndex)
            end
            function builtInRagebotAtk.knife(attacks, fighter, root, item, target)
                if fighter.EquippedItem ~= item then
                    builtInRagebotEquip(attacks, fighter, item)
                    builtInRagebotSettle(attacks, root)
                    return 'void...'
                end
                if not target or tick() < (item._equip_cooldown or 0) then
                    builtInRagebotSettle(attacks, root)
                    return 'void...'
                end
                if builtInRagebotSpamming(attacks) then
                    builtInRagebotSettle(attacks, root)
                    return 'void spamming...'
                end
                local enums = builtInRagebotEnums()
                if not enums then return 'void...' end
                local now = tick()
                local facing = (type(target.fighter.GetRotationCFrame) == 'function' and CFrame.new(target.part.Position) * target.fighter:GetRotationCFrame()) or target.part.CFrame
                local behind = facing * CFrame.new(0, 0, 3)
                local previous = attacks.attackPose
                local pose, ready = builtInRagebotAttach(attacks, root, item, target, 'knife', behind)
                if not pose then return 'void...' end
                local aim = CFrame.lookAt(pose.Position, target.part.Position)
                if previous ~= pose or (ready and now >= attacks.swingAt) then
                    local pitch, yaw = aim:ToOrientation()
                    builtInRagebotHoldSend(builtInRagebotEncodePose(pitch, yaw))
                end
                if ready and now >= attacks.swingAt then
                    if not builtInRagebotSwingSend(enums, item, aim, target.part, true) then
                        builtInRagebotSettle(attacks, root)
                        return 'invalid knife animation... (void)'
                    end
                    attacks.swingAt = now + 1 / 60
                    builtInRagebotBeginBurst(attacks, now)
                end
                return ready and string.format('backstabbing %s...', tostring(target.name)) or string.format('attaching %s...', tostring(target.name))
            end
            function builtInRagebotAtk.melee(attacks, fighter, root, item, target)
                local function wait()
                    builtInRagebotSettle(attacks, root)
                    attacks.meleeAt = tick() + BUILT_IN_RAGEBOT_SETTLE
                end
                if fighter.EquippedItem ~= item then
                    builtInRagebotEquip(attacks, fighter, item)
                    wait()
                    return 'void...'
                end
                if not target then
                    wait()
                    return 'void...'
                end
                if tick() < (item._equip_cooldown or 0) then
                    wait()
                    return 'void...'
                end
                if builtInRagebotSpamming(attacks) then
                    wait()
                    return 'void spamming...'
                end
                local enums = builtInRagebotEnums()
                if not enums then return 'void...' end
                local now = tick()
                local function around()
                    local position = target.part.Position
                    local from = position + Random.new():NextUnitVector() * 3
                    return CFrame.new(from, position)
                end
                local pose, ready = builtInRagebotAttach(attacks, root, item, target, 'melee', around())
                if not pose then return 'void...' end
                local aim = CFrame.lookAt(pose.Position, target.part.Position)
                if ready and now >= attacks.meleeAt and now >= attacks.swingAt then
                    if not builtInRagebotSwingSend(enums, item, aim, target.part, false) then
                        wait()
                        return 'invalid melee animation... (void)'
                    end
                    attacks.swingAt = now + 1 / 60
                    builtInRagebotBeginBurst(attacks, now)
                end
                return ready and string.format('attacking %s...', tostring(target.name)) or string.format('attaching %s...', tostring(target.name))
            end
            local function builtInRagebotAmmunition(item)
                if (item.Data.Ammo or 0) > 0 then
                    return true, false
                end
                return false, (item.Data.AmmoReserve or 0) == 0
            end
            local function builtInRagebotReload(attacks, item)
                local now = tick()
                if attacks.reloadItem == item and now < attacks.reloadAt then return end
                attacks.reloadItem, attacks.reloadAt = item, now + 0.25
                local enums = builtInRagebotEnums()
                if not enums then return end
                local results = { item:StartReloading() }
                if table.remove(results, 1) ~= true then return end
                local action = table.remove(results, 1)
                if type(action) ~= 'string' then return end
                local arguments = {}
                for index, value in pairs(results) do
                    arguments[utf8.char(index)] = value
                end
                builtInRagebotUseItem:FireServer(item:Get('ObjectID'), enums:ToEnum(action), arguments, nil)
            end
            local function builtInRagebotChooseGun(guns)
                local first, last, step = 1, #guns, 1
                if not builtInRagebotSettings.primary then
                    first, last, step = #guns, 1, -1
                end
                local chosen = nil
                for index = first, last, step do
                    local item = guns[index]
                    local loaded, empty = builtInRagebotAmmunition(item)
                    local candidate = { item = item, loaded = loaded, empty = empty }
                    if loaded or not empty then
                        local reloading = tick() < (item._reload_cooldown or 0)
                        local threads = item._reload_threads
                        if item.Info.ReloadType == 'Segmented' and type(threads) == 'table' then
                            local active = threads[#threads]
                            reloading = reloading or (active ~= nil and coroutine.status(active) ~= 'dead')
                        end
                        if not builtInRagebotSettings.swapWhenEmpty or (loaded and not reloading) then
                            return candidate
                        end
                        chosen = chosen or candidate
                    end
                end
                return chosen
            end
            local function builtInRagebotShoot(enums, item, target, aim, attempts)
                for _ = 1, attempts do
                    local arguments = {
                        ['\1'] = {
                            ['\0'] = builtInRagebotPack(aim),
                            ['\1'] = builtInRagebotPack(aim),
                            ['\2'] = target.part,
                            ['\3'] = builtInRagebotPack(builtInRagebotScatter()),
                        },
                        ['\2'] = true,
                    }
                    if item.Name == 'Revolver' then
                        arguments['\3'] = true
                    end
                    builtInRagebotUseItem:FireServer(item:Get('ObjectID'), enums:ToEnum('StartShooting'), arguments, nil)
                end
            end
            function builtInRagebotAtk.gun(attacks, fighter, root, guns, target, status)
                local chosen = builtInRagebotChooseGun(guns)
                if not chosen then
                    builtInRagebotSettle(attacks, root)
                    return 'no usable item(s)... (void)'
                end
                local item = chosen.item
                if fighter.EquippedItem ~= item then
                    builtInRagebotEquip(attacks, fighter, item)
                    builtInRagebotSettle(attacks, root)
                    return 'void...'
                end
                if item.Info.ReloadType == 'Segmented' then
                    local threads = item._reload_threads
                    local thread = threads and threads[#threads]
                    if thread and coroutine.status(thread) ~= 'dead' then
                        builtInRagebotSettle(attacks, root)
                        return 'reloading...'
                    end
                end
                local now = tick()
                if now < (item._equip_cooldown or 0) then
                    builtInRagebotSettle(attacks, root)
                    return 'void...'
                end
                if now < (item._reload_cooldown or 0) then
                    builtInRagebotSettle(attacks, root)
                    return 'reloading...'
                end
                if status ~= 'RoundStarted' then
                    builtInRagebotSettle(attacks, root)
                    return 'void...'
                end
                if not chosen.loaded and not chosen.empty then
                    builtInRagebotReload(attacks, item)
                    builtInRagebotSettle(attacks, root)
                    return 'reloading...'
                end
                if not target then
                    builtInRagebotSettle(attacks, root)
                    return 'void...'
                end
                if builtInRagebotSpamming(attacks) then
                    builtInRagebotSettle(attacks, root)
                    return 'void spamming...'
                end
                local enums = builtInRagebotEnums()
                if not enums then return 'void...' end
                local position = target.part.Position
                local above = position + Vector3.new(0, 3, 0)
                local eye = Vector3.new(0, (fighter:IsCrouching() and BUILT_IN_RAGEBOT_CROUCHED_EYE or BUILT_IN_RAGEBOT_EYE), 0)
                local hasShield = type(target.fighter.EquippedItem) == 'table' and target.fighter.EquippedItem.Name == 'Riot Shield'
                local held = (attacks.attackMode == 'gun' and attacks.attackItem == item and not hasShield) and attacks.attackPose or nil
                local route = (held and not attacks.poseFired and attacks.attackTarget == target.part and builtInRagebotClear(held.Position + eye, position) and held)
                    or builtInRagebotOrigins.gun(position, above, eye, held)
                if not route then
                    builtInRagebotSettle(attacks, root)
                    return string.format('blocked %s... (void)', tostring(target.name))
                end
                local pose, ready = builtInRagebotAttach(attacks, root, item, target, 'gun', route)
                if not pose then return 'void...' end
                local aim = CFrame.lookAt(pose.Position + eye, position)
                if ready and now >= attacks.shotAt then
                    attacks.shotAt = now + 1 / 120
                    builtInRagebotBeginBurst(attacks, now)
                    builtInRagebotShoot(enums, item, target, aim, builtInRagebotSettings.shootAttempts)
                end
                return ready and string.format('killing %s...', tostring(target.name)) or string.format('attaching %s...', tostring(target.name))
            end
            function builtInRagebotAtk.cycle(attacks, fighter, root, target, status, deltaTime)
                attacks.server = nil
                local mode = builtInRagebotSettings.mode
                local guns, chosen = {}, nil
                for _, item in pairs(fighter.Items) do
                    if item.Info and item.Info.Type == 'Gun' then
                        table.insert(guns, item)
                    elseif mode == 'knife' and item.Name == 'Knife' then
                        chosen = item
                        break
                    elseif mode == 'melee' and item.Info and item.Info.Type == 'Melee' then
                        chosen = item
                        break
                    end
                end
                local doing
                if chosen and mode == 'knife' then
                    doing = builtInRagebotAtk.knife(attacks, fighter, root, chosen, target)
                elseif chosen then
                    doing = builtInRagebotAtk.melee(attacks, fighter, root, chosen, target)
                elseif #guns > 0 then
                    doing = builtInRagebotAtk.gun(attacks, fighter, root, guns, target, status)
                else
                    doing = 'invalid weapons for ragebot'
                end
                return attacks.server, doing
            end
            local function builtInRagebotPropose(realCFrame, root, dt)
                if not builtInRagebotState.active or builtInRagebotState.counterActive then
                    builtInRagebotSetReport(nil)
                    return nil
                end
                local fighter = builtInRagebotController() and builtInRagebotController().LocalFighter
                if type(fighter) ~= 'table' then
                    builtInRagebotSetReport(nil)
                    return nil
                end
                builtInRagebotState.real = realCFrame.Position
                local current = builtInRagebotDuel()
                local status = current and type(current.Data) == 'table' and current.Data.Status or nil
                local duelers = current and current._duelers_by_player
                local excluded = {}
                if player.Character then
                    table.insert(excluded, player.Character)
                end
                if type(duelers) == 'table' then
                    for other in pairs(duelers) do
                        if other.Character then
                            table.insert(excluded, other.Character)
                        end
                    end
                end
                local camera = workspace.CurrentCamera
                if camera then
                    table.insert(excluded, camera)
                end
                builtInRagebotParams.FilterDescendantsInstances = excluded
                local function reachable(checked)
                    if builtInRagebotSettings.mode ~= 'gun' then
                        return true
                    end
                    local position = checked.part.Position
                    local eye = Vector3.new(0, fighter:IsCrouching() and BUILT_IN_RAGEBOT_CROUCHED_EYE or BUILT_IN_RAGEBOT_EYE, 0)
                    return builtInRagebotOrigins.gun(position, position + Vector3.new(0, 3, 0), eye, builtInRagebotState.attacks and builtInRagebotState.attacks.attackPose) ~= nil
                end
                local target = (status == 'RoundStarted' and type(duelers) == 'table') and builtInRagebotPick(duelers, reachable) or nil
                local server, doing = builtInRagebotAtk.cycle(builtInRagebotState.attacks, fighter, root, target, status, dt)
                builtInRagebotSetReport(doing, target and target.part or nil)
                return server
            end
            local BUILT_IN_RAGEBOT_RAGER = { SPEED = 400, JUMP = 20, HOVER = 12, HOVER_DRIFT = 0.2, HOVER_TIME = 0.5, THRESHOLD = 4, WINDOW = 3, MEMORY = 15 }
            local function builtInRagebotWatchNew()
                local ground = RaycastParams.new()
                ground.FilterType = Enum.RaycastFilterType.Exclude
                return { seen = {}, signs = {}, flagged = {}, ground = ground, box = nil, spawned = {}, last = {} }
            end
            local function builtInRagebotRagerSign(watch, other, now, points)
                local signs = watch.signs[other]
                if not signs then
                    signs = {}
                    watch.signs[other] = signs
                end
                table.insert(signs, { at = now, points = points })
                while signs[1] and now - signs[1].at > BUILT_IN_RAGEBOT_RAGER.WINDOW do
                    table.remove(signs, 1)
                end
                local total = 0
                for _, entry in pairs(signs) do
                    total = total + entry.points
                end
                if total >= BUILT_IN_RAGEBOT_RAGER.THRESHOLD then
                    watch.flagged[other] = now
                end
            end
            local function builtInRagebotRagerObserve(watch, other, sample)
                local now = sample.now
                local last = watch.seen[other]
                local seen = { x = sample.x, y = sample.y, z = sample.z, at = now, still = nil }
                watch.seen[other] = seen
                if sample.grace then return end
                if sample.outside then
                    builtInRagebotRagerSign(watch, other, now, BUILT_IN_RAGEBOT_RAGER.THRESHOLD)
                end
                if not last or now <= last.at then return end
                local dx, dy, dz = sample.x - last.x, sample.y - last.y, sample.z - last.z
                local distance = math.sqrt(dx * dx + dy * dy + dz * dz)
                if distance >= BUILT_IN_RAGEBOT_RAGER.JUMP and distance / (now - last.at) > BUILT_IN_RAGEBOT_RAGER.SPEED then
                    builtInRagebotRagerSign(watch, other, now, sample.nearMe and 2 or 1)
                    return
                end
                local height = sample.height
                if height and height >= BUILT_IN_RAGEBOT_RAGER.HOVER and math.abs(dy) <= BUILT_IN_RAGEBOT_RAGER.HOVER_DRIFT then
                    local since = last.still or last.at
                    if now - since >= BUILT_IN_RAGEBOT_RAGER.HOVER_TIME then
                        builtInRagebotRagerSign(watch, other, now, 1)
                        seen.still = now
                    else
                        seen.still = since
                    end
                end
            end
            local function builtInRagebotRagerIs(watch, other, now)
                local at = watch.flagged[other]
                return at ~= nil and now - at <= BUILT_IN_RAGEBOT_RAGER.MEMORY
            end
            local function builtInRagebotWatchBarriers(watch, duel)
                local map = type(duel.Map) == 'table' and duel.Map.Model
                local folder = typeof(map) == 'Instance' and map:FindFirstChild('Barriers')
                if not folder then return nil, nil end
                local held = watch.box
                if held and held.map == map then
                    return held.low, held.high
                end
                local low, high = Vector3.one * math.huge, -Vector3.one * math.huge
                for _, part in pairs(folder:GetChildren()) do
                    if part:IsA('BasePart') then
                        local half = part.Size / 2
                        low = low:Min(part.Position - half)
                        high = high:Max(part.Position + half)
                    end
                end
                if low.X > high.X then return nil, nil end
                watch.box = { map = map, low = low, high = high }
                return low, high
            end
            local function builtInRagebotWatchUpdate(watch, me, duel, mine)
                local list = {}
                local duelers = type(duel) == 'table' and duel._duelers_by_player
                if type(duelers) ~= 'table' then return list end
                local now = tick()
                local started = type(duel.Data) == 'table' and duel.Data.Status == 'RoundStarted'
                local low, high = builtInRagebotWatchBarriers(watch, duel)
                local characters = {}
                for other in pairs(duelers) do
                    if other.Character then
                        table.insert(characters, other.Character)
                    end
                end
                watch.ground.FilterDescendantsInstances = characters
                for other, dueler in pairs(duelers) do
                    local character = other.Character
                    local humanoid = character and character:FindFirstChildOfClass('Humanoid')
                    local root = character and character:FindFirstChild('HumanoidRootPart')
                    if other ~= me and character and type(dueler) == 'table' and humanoid and root and root:IsA('BasePart') then
                        local ally = dueler._is_ally == true
                        local position = root.Position
                        local health = humanoid.Health
                        local outside = position.Magnitude >= BUILT_IN_RAGEBOT_VOID
                        if low and high then
                            outside = outside or (position - position:Max(low):Min(high)).Magnitude > 100
                        end
                        if not ally and health > 0 then
                            local held = watch.spawned[other]
                            local life = (held and held.character == character) and held or nil
                            if not life then
                                life = { character = character, at = now }
                                watch.spawned[other] = life
                                watch.seen[other] = nil
                            end
                            local born = life.at
                            local hit = workspace:Raycast(position, Vector3.new(0, -200, 0), watch.ground)
                            builtInRagebotRagerObserve(watch, other, {
                                x = position.X, y = position.Y, z = position.Z, now = now,
                                outside = outside, nearMe = (position - mine).Magnitude <= 8,
                                height = hit and (position.Y - hit.Position.Y) or 200,
                                grace = not started or now - born < 1.5,
                            })
                        end
                        local seen = watch.last[other]
                        local velocity = root.AssemblyLinearVelocity
                        if seen and now - seen.at > 0.005 then
                            local moved = (position - seen.position) / (now - seen.at)
                            if moved.Magnitude <= 200 and moved.Magnitude > velocity.Magnitude then
                                velocity = moved
                            end
                        end
                        if not seen or now - seen.at > 0.005 then
                            watch.last[other] = { position = position, at = now }
                        end
                        local head = character:FindFirstChild('HitboxHead') or character:FindFirstChild('HitboxBody')
                        table.insert(list, {
                            player = other, name = other.Name, character = character, root = root,
                            part = (head and head:IsA('BasePart') and head) or root,
                            position = position, velocity = velocity,
                            distance = (position - mine).Magnitude, health = health, ally = ally,
                            rager = not ally and builtInRagebotRagerIs(watch, other, now), inside = not outside,
                        })
                    end
                end
                return list
            end
            local BUILT_IN_RAGEBOT_MOST_FLYING = 0.95
            local function builtInRagebotBlinkNew()
                return { started = nil, fly = { x = 0, y = 0, z = 0 }, boostAt = 0, cycle = nil, stop = nil, spot = nil, from = nil }
            end
            local function builtInRagebotBlinkReset(blink)
                blink.started, blink.cycle, blink.stop, blink.spot, blink.from = nil, nil, nil, nil, nil
            end
            local function builtInRagebotBlinkPick(blink, spots, engine, random)
                local index = math.clamp(math.floor(random() * #spots) + 1, 1, #spots)
                if index == blink.spot and #spots > 1 then
                    index = index % #spots + 1
                end
                blink.spot = index
                local spot = spots[index]
                local angle = random() * math.pi * 2
                local distance = math.sqrt(random()) * engine.spread
                return { x = spot.x + math.cos(angle) * distance, y = spot.floor - engine.depth, z = spot.z + math.sin(angle) * distance, flying = false }
            end
            local function builtInRagebotBlinkPose(blink, now, delta, from, spots, random, engine)
                if not blink.started then
                    blink.started = now
                    blink.from = { x = from.x, y = from.y, z = from.z }
                    blink.fly = { x = from.x, y = from.y, z = from.z }
                    blink.boostAt = now + engine.boostEvery
                end
                local started = blink.started or now
                local home = blink.from or from
                local fly = blink.fly
                fly.y = fly.y + engine.flySpeed * delta
                if now >= blink.boostAt then
                    fly.y = fly.y + engine.boost
                    blink.boostAt = now + engine.boostEvery
                end
                local length = math.max(engine.cycle, 0.005)
                local elapsed = now - started
                local cycle = math.floor(elapsed / length)
                local phase = elapsed / length - cycle
                local share = math.min(engine.flyTime / length, BUILT_IN_RAGEBOT_MOST_FLYING)
                if phase < share or (spots and #spots == 0) then
                    return { x = fly.x + math.cos(now * engine.zigFrequency) * engine.zigAmplitude, y = fly.y, z = fly.z, flying = true }
                end
                if not spots then
                    return { x = home.x, y = home.y - engine.depth, z = home.z, flying = false }
                end
                local stop = blink.stop
                if not stop or blink.cycle ~= cycle then
                    stop = builtInRagebotBlinkPick(blink, spots, engine, random)
                    blink.stop, blink.cycle = stop, cycle
                end
                return stop
            end
            local builtInRagebotCounter = { HOP_EVERY = BUILT_IN_RAGEBOT_HOP_EVERY, CEILING = BUILT_IN_RAGEBOT_CEILING }
            function builtInRagebotCounter.new()
                return {
                    life = false, born = 0, hopAt = 0, mode = nil, last = nil,
                    blink = builtInRagebotBlinkNew(), drop = nil, nextDrop = 0, anchor = nil, unjoin = nil,
                }
            end
            local function builtInRagebotCounterOver(counter, forget)
                if forget then
                    counter.anchor = nil
                end
                if counter.life then
                    pcall(builtInRagebotToSpawn)
                end
                counter.life = false
                counter.last = nil
                counter.drop = nil
                counter.nextDrop = 0
                builtInRagebotBlinkReset(counter.blink)
            end
            local function builtInRagebotAllowed(opponent)
                return (not builtInRagebotCounterSettings.enemiesOnly or not opponent.ally) and (not builtInRagebotCounterSettings.aliveOnly or opponent.health > 0)
            end
            local function builtInRagebotFirst(list, priority, random)
                if #list == 0 then
                    return nil
                elseif priority == 'random' then
                    return list[math.clamp(math.floor(random() * #list) + 1, 1, #list)]
                end
                local best = list[1]
                for index = 2, #list do
                    local other = list[index]
                    local better
                    if priority == 'a to z' then
                        better = other.name < best.name
                    elseif priority == 'z to a' then
                        better = other.name > best.name
                    else
                        better = other.health < best.health
                    end
                    if better then
                        best = other
                    end
                end
                return best
            end
            local function builtInRagebotChoose(counter, opponents, now, random)
                local bots, legits = {}, {}
                for _, opponent in pairs(opponents) do
                    if opponent.health > 0 and opponent.inside and builtInRagebotAllowed(opponent) then
                        table.insert(opponent.rager and bots or legits, opponent)
                    end
                end
                local priority = builtInRagebotCounterSettings.legits.priority
                if builtInRagebotCounterSettings.bots.on and #bots > 0 then
                    return builtInRagebotFirst(bots, priority, random), builtInRagebotCounterSettings.bots
                end
                local legit = builtInRagebotCounterSettings.legits
                if legit.on and #legits > 0 and #legits <= legit.max and now - counter.born >= legit.delay then
                    return builtInRagebotFirst(legits, priority, random), legit
                end
                return nil, nil
            end
            local function builtInRagebotCounterStep(counter, deps)
                local settings = builtInRagebotCounterSettings
                if not settings.active then
                    if counter.life then
                        deps.rescue(counter.anchor)
                    end
                    builtInRagebotCounterOver(counter, true)
                    return nil
                end
                local fighter = deps.fighter()
                local root = fighter and deps.root()
                if not fighter or not root then
                    builtInRagebotCounterOver(counter, true)
                    return 'counter: no character...'
                end
                if counter.mode ~= settings.mode then
                    if counter.life then
                        deps.rescue(counter.anchor)
                    end
                    builtInRagebotCounterOver(counter, false)
                    counter.mode = settings.mode
                end
                local anchor = counter.anchor
                if not anchor then
                    anchor = deps.position(root)
                    counter.anchor = anchor
                end
                local from = anchor
                local now = deps.now()
                local delta = counter.last and (now - counter.last) or 0
                counter.last = now
                if not counter.life then
                    counter.born = now
                end
                local name = settings.mode
                local status
                local target = nil
                local fresh = false
                if settings.mode == 'solix' or settings.mode == 'kicia' then
                    counter.life = true
                    local spots = settings.mode == 'solix' and deps.spots() or nil
                    local pose = builtInRagebotBlinkPose(counter.blink, now, delta, from, spots, deps.random, settings.engine)
                    deps.place(root, pose)
                    status = string.format('%s: at %s...', tostring(name), tostring(math.floor(pose.y)))
                else
                    local opponents = deps.opponents(root)
                    local drop = counter.drop
                    if drop and now >= drop.ends then
                        counter.drop, counter.nextDrop = nil, drop.ends + drop.gap
                        drop = nil
                        deps.lift(root, from)
                    end
                    if drop then
                        for _, opponent in pairs(opponents) do
                            if opponent.name == drop.name and opponent.health > 0 and opponent.inside and builtInRagebotAllowed(opponent) then
                                target = opponent
                            end
                        end
                        if not target then
                            counter.drop, counter.nextDrop = nil, now
                            deps.lift(root, from)
                        end
                    elseif counter.life and now >= counter.nextDrop then
                        local chosen, group = builtInRagebotChoose(counter, opponents, now, deps.random)
                        if chosen and group then
                            target = chosen
                            fresh = true
                            counter.drop = { name = chosen.name, ends = now + group.stay, gap = group.gap, lead = group.lead }
                        end
                    end
                    local dropping = counter.drop
                    if target and dropping then
                        deps.drop(root, target, dropping.lead)
                        if fresh then
                            deps.replicate(root)
                        end
                        status = string.format('%s: dropping on %s...', tostring(name), tostring(target.name))
                    else
                        if not counter.life then
                            counter.life = true
                            counter.hopAt = now + BUILT_IN_RAGEBOT_HOP_EVERY
                            deps.lift(root, from)
                        elseif deps.height(root) > BUILT_IN_RAGEBOT_CEILING then
                            deps.lift(root, from)
                        elseif now >= counter.hopAt then
                            counter.hopAt = now + BUILT_IN_RAGEBOT_HOP_EVERY
                            deps.hop(root)
                        end
                        deps.rise(root, settings.voidSpeed)
                        status = string.format('%s: climbing...', tostring(name))
                    end
                end
                return status
            end
            local function builtInRagebotCounterResolve()
                local fighters = builtInRagebotController()
                if not fighters then return nil end
                local random = Random.new()
                local watch = builtInRagebotWatchNew()
                local opponentsCache = {}
                local opponentsCacheAt = 0
                local function root()
                    local part = builtInRagebotRoot()
                    return part and part:IsA('BasePart') and part or nil
                end
                return {
                    now = tick,
                    fighter = function()
                        local fighter = fighters.LocalFighter
                        return builtInRagebotAlive(fighter) and fighter or nil
                    end,
                    root = root,
                    opponents = function(part)
                        local now = tick()
                        if now - opponentsCacheAt >= 0.05 then
                            opponentsCacheAt = now
                            opponentsCache = builtInRagebotWatchUpdate(watch, player, builtInRagebotDuel(), part.Position)
                        end
                        return opponentsCache
                    end,
                    height = function(part)
                        return part.Position.Y
                    end,
                    lift = function(part, anchor)
                        part.CFrame = CFrame.new(anchor.x, anchor.y + BUILT_IN_RAGEBOT_LIFT, anchor.z) * part.CFrame.Rotation
                    end,
                    hop = function(part)
                        local angle = random:NextNumber(0, math.pi * 2)
                        local distance = random:NextNumber(BUILT_IN_RAGEBOT_HOP_MIN, BUILT_IN_RAGEBOT_HOP_MAX)
                        part.CFrame = part.CFrame + Vector3.new(math.cos(angle) * distance, 0, math.sin(angle) * distance)
                    end,
                    rise = function(part, speed)
                        part.AssemblyLinearVelocity = Vector3.new(0, speed, 0)
                    end,
                    drop = function(part, opponent, lead)
                        local position = opponent.position
                        local moving = opponent.velocity * Vector3.new(1, 0, 1)
                        local at = position + (moving.Magnitude > 1 and moving.Unit * lead or Vector3.zero)
                        part.CFrame = CFrame.new(at) * part.CFrame.Rotation
                        part.AssemblyLinearVelocity = Vector3.zero
                    end,
                    rescue = function(anchor)
                        local part = root()
                        if part and anchor then
                            part.AssemblyLinearVelocity = Vector3.zero
                            part.CFrame = CFrame.new(anchor.x, anchor.y + 3, anchor.z)
                        else
                            builtInRagebotToSpawn()
                        end
                    end,
                    replicate = builtInRagebotReplicate,
                    position = function(part)
                        local position = part.Position
                        return { x = position.X, y = position.Y, z = position.Z }
                    end,
                    spots = function()
                        local duel = builtInRagebotDuel()
                        local map = duel and type(duel.Map) == 'table' and duel.Map.Model
                        local folder = typeof(map) == 'Instance' and map:FindFirstChild('Spawns')
                        local spots = {}
                        if folder then
                            for _, part in pairs(folder:GetDescendants()) do
                                if part:IsA('BasePart') then
                                    local position = part.Position
                                    table.insert(spots, { x = position.X, z = position.Z, floor = position.Y - part.Size.Y / 2 })
                                end
                            end
                        end
                        return spots
                    end,
                    place = function(part, pose)
                        local pitch = pose.flying and (-math.pi / 2) or (math.pi / 2)
                        part.CFrame = CFrame.new(pose.x, pose.y, pose.z) * CFrame.Angles(pitch, 0, 0)
                        part.AssemblyLinearVelocity = Vector3.zero
                    end,
                    random = function()
                        return random:NextNumber()
                    end,
                    heartbeat = runService.Heartbeat,
                    join = function(frame)
                        return builtInRagebotDesyncJoin(1.5, function()
                            frame()
                            return nil
                        end, frame)
                    end,
                }
            end
            function builtInRagebotToSpawn()
                local character = player.Character
                local part = character and character:FindFirstChild('HumanoidRootPart')
                if not part or not part:IsA('BasePart') then return end
                local duel = builtInRagebotDuel()
                local map = duel and type(duel.Map) == 'table' and duel.Map.Model
                local folder = typeof(map) == 'Instance' and map:FindFirstChild('Spawns')
                if not folder then return end
                for _, spawn in pairs(folder:GetDescendants()) do
                    if spawn:IsA('BasePart') then
                        part.AssemblyLinearVelocity = Vector3.zero
                        part.CFrame = CFrame.new(spawn.Position + Vector3.new(0, 3, 0))
                        return
                    end
                end
            end
            app.builtInRagebotRescue = builtInRagebotToSpawn
            app.startBuiltInRagebot = function()
                if builtInRagebotState.active then return end
                builtInRagebotState.active = true
                builtInRagebotSettings.active = true
                builtInRagebotState.attacks = builtInRagebotAtk.new()
                builtInRagebotState.priority.current = nil
                builtInRagebotPipelineAcquire()
                builtInRagebotDesyncAcquire()
                builtInRagebotState.unjoin = builtInRagebotDesyncJoin(1, builtInRagebotPropose, function()
                    if builtInRagebotState.attacks then
                        builtInRagebotAtk.reset(builtInRagebotState.attacks)
                    end
                    builtInRagebotSetReport(nil)
                end)
            end
            app.stopBuiltInRagebot = function()
                if not builtInRagebotState.active then return end
                builtInRagebotState.active = false
                builtInRagebotSettings.active = false
                if builtInRagebotState.attacks then
                    builtInRagebotAtk.reset(builtInRagebotState.attacks)
                end
                builtInRagebotState.priority.current = nil
                builtInRagebotSetReport(nil)
                if builtInRagebotState.unjoin then
                    builtInRagebotState.unjoin()
                    builtInRagebotState.unjoin = nil
                end
                builtInRagebotDesyncRelease()
                builtInRagebotPipelineRelease()
            end
            app.startDesyncCounter = function()
                if builtInRagebotState.counterActive then return end
                builtInRagebotState.counterActive = true
                builtInRagebotCounterSettings.active = true
                builtInRagebotPipelineAcquire()
                builtInRagebotDesyncAcquire()
                local counter = builtInRagebotCounter.new()
                builtInRagebotState.counter = counter
                local deps = builtInRagebotCounterResolve()
                if not deps then return end
                counter.unjoin = deps.join(function()
                    local status = builtInRagebotCounterStep(counter, deps)
                    if status ~= nil then
                        builtInRagebotSetReport(status, nil)
                    end
                end)
            end
            app.stopDesyncCounter = function()
                if not builtInRagebotState.counterActive then return end
                builtInRagebotState.counterActive = false
                builtInRagebotCounterSettings.active = false
                local counter = builtInRagebotState.counter
                builtInRagebotState.counter = nil
                if counter then
                    if counter.unjoin then
                        counter.unjoin()
                    end
                    builtInRagebotCounterOver(counter, true)
                end
                builtInRagebotSetReport(nil)
                builtInRagebotDesyncRelease()
                builtInRagebotPipelineRelease()
            end
            local builtInRagebotStatusLabel = nil
            local builtInRagebotStatusText = nil
            ui.boxBuiltInRagebot = tabs.ragebot:AddLeftGroupbox("Built-In Ragebot")
            ui.builtInRagebotToggle = ui.boxBuiltInRagebot:AddToggle("builtInRagebotEn", {
                Text = "Built-In Ragebot",
                Default = false,
            })
            ui.builtInRagebotStatus = ui.boxBuiltInRagebot:AddLabel("status: idle")
            builtInRagebotStatusLabel = ui.builtInRagebotStatus
            ui.builtInRagebotVoidSpamToggle = ui.boxBuiltInRagebot:AddToggle("builtInRagebotVoidSpamEn", { Text = "Void Spam", Default = true })
            ui.builtInRagebotHideSlider = ui.boxBuiltInRagebot:AddSlider("builtInRagebotHideSl", { Text = "Hide", Default = 0.25, Min = 0.01, Max = 1, Rounding = 2 })
            ui.builtInRagebotAttackSlider = ui.boxBuiltInRagebot:AddSlider("builtInRagebotAttackSl", { Text = "Attack", Default = 0.1, Min = 0.01, Max = 1, Rounding = 2 })
            ui.builtInRagebotAttemptsSlider = ui.boxBuiltInRagebot:AddSlider("builtInRagebotAttemptsSl", { Text = "Shoot Attempts", Default = 1, Min = 1, Max = 2, Rounding = 0 })
            ui.builtInRagebotModeDropdown = ui.boxBuiltInRagebot:AddDropdown("builtInRagebotModeDd", { Text = "Attack Mode", Default = "gun", Values = { "gun", "knife", "melee" } })
            ui.builtInRagebotWeaponDropdown = ui.boxBuiltInRagebot:AddDropdown("builtInRagebotWeaponDd", { Text = "Preferred Weapon", Default = "primary", Values = { "primary", "secondary" } })
            ui.builtInRagebotSwapEmptyToggle = ui.boxBuiltInRagebot:AddToggle("builtInRagebotSwapEmptyEn", { Text = "Swap Weapons When Empty", Default = false })
            ui.builtInRagebotAutoPrioToggle = ui.boxBuiltInRagebot:AddToggle("builtInRagebotAutoPrioEn", { Text = "Auto Prioritize", Default = false })
            ui.builtInRagebotPrioNotifyToggle = ui.boxBuiltInRagebot:AddToggle("builtInRagebotPrioNotifyEn", { Text = "Priority Notification", Default = true })
            ui.builtInRagebotPrioJoinDropdown = ui.boxBuiltInRagebot:AddDropdown("builtInRagebotPrioJoinDd", { Text = "Auto Priority", Default = { "attackers", "voided players" }, Values = { "attackers", "voided players" }, Multi = true })
            ui.builtInRagebotToggle:OnChanged(function(v)
                config.builtInRagebot = v
                builtInRagebotSettings.active = v
                if v then
                    app.startBuiltInRagebot()
                else
                    app.stopBuiltInRagebot()
                end
            end)
            ui.builtInRagebotVoidSpamToggle:OnChanged(function(v)
                builtInRagebotSettings.voidSpam = v
                pcall(function() ui.builtInRagebotHideSlider:SetVisible(v) end)
                pcall(function() ui.builtInRagebotAttackSlider:SetVisible(v) end)
            end)
            ui.builtInRagebotHideSlider:OnChanged(function(v) builtInRagebotSettings.voidHide = v end)
            ui.builtInRagebotAttackSlider:OnChanged(function(v) builtInRagebotSettings.voidAttack = v end)
            ui.builtInRagebotAttemptsSlider:OnChanged(function(v) builtInRagebotSettings.shootAttempts = math.clamp(v, 1, 2) end)
            ui.builtInRagebotModeDropdown:OnChanged(function(v) builtInRagebotSettings.mode = v or 'gun' end)
            ui.builtInRagebotWeaponDropdown:OnChanged(function(v) builtInRagebotSettings.primary = v ~= 'secondary' end)
            ui.builtInRagebotSwapEmptyToggle:OnChanged(function(v) builtInRagebotSettings.swapWhenEmpty = v end)
            ui.builtInRagebotAutoPrioToggle:OnChanged(function(v)
                builtInRagebotSettings.autoPrioritize = v
                pcall(function() ui.builtInRagebotPrioNotifyToggle:SetVisible(v) end)
                pcall(function() ui.builtInRagebotPrioJoinDropdown:SetVisible(v) end)
            end)
            ui.builtInRagebotPrioNotifyToggle:OnChanged(function(v) builtInRagebotSettings.notify = v end)
            ui.builtInRagebotPrioJoinDropdown:OnChanged(function(v)
                builtInRagebotSettings.join = {}
                if type(v) == 'table' then
                    for name in pairs(v) do
                        builtInRagebotSettings.join[name] = true
                    end
                end
            end)
            local builtInRagebotCounterToggles = {}
            local builtInRagebotCounterOn = { kicia = false, solix = false }
            local builtInRagebotCounterOwners = {}
            local function builtInRagebotCounterRefresh()
                local toggled = builtInRagebotCounterOn.kicia or builtInRagebotCounterOn.solix
                config.builtInRagebotCounter = toggled
                app.kiciaCounterOwned = builtInRagebotCounterOwners.void and not builtInRagebotCounterOn.solix
                if toggled or next(builtInRagebotCounterOwners) ~= nil then
                    builtInRagebotCounterSettings.mode = builtInRagebotCounterOn.solix and "solix" or "kicia"
                    app.startDesyncCounter()
                else
                    app.stopDesyncCounter()
                end
            end
            app.setKiciaCounter = function(owner, value)
                builtInRagebotCounterOwners[owner] = value and true or nil
                builtInRagebotCounterRefresh()
            end
            local function builtInRagebotCounterSelect(mode, value)
                builtInRagebotCounterOn[mode] = value and true or false
                if value then
                    for other, toggle in pairs(builtInRagebotCounterToggles) do
                        if other ~= mode and builtInRagebotCounterOn[other] then
                            pcall(function() toggle:SetValue(false) end)
                        end
                    end
                end
                builtInRagebotCounterRefresh()
            end
            builtInRagebotCounterToggles.kicia = ui.boxMods:AddToggle("builtInRagebotKiciaCounterEn", {
                Text = "Kicia Counter",
                Default = false,
            })
            ui.builtInRagebotKiciaCounterLabel = ui.boxMods:AddLabel("disable ur evasion")
            builtInRagebotCounterToggles.solix = ui.boxMods:AddToggle("builtInRagebotSolixCounterEn", {
                Text = "Solix Counter",
                Default = false,
            })
            ui.builtInRagebotSolixCounterLabel = ui.boxMods:AddLabel("disable ur evasion")
            ui.builtInRagebotCounterBotsToggle = ui.boxMods:AddToggle("builtInRagebotCounterBotsEn", { Text = "Attack Ragebots", Default = true })
            ui.builtInRagebotCounterLegitsToggle = ui.boxMods:AddToggle("builtInRagebotCounterLegitsEn", { Text = "Attack Legits", Default = true })
            ui.boxMods:AddButton("Original Position", function()
                pcall(builtInRagebotToSpawn)
            end)
            builtInRagebotCounterToggles.kicia:OnChanged(function(v) builtInRagebotCounterSelect("kicia", v) end)
            builtInRagebotCounterToggles.solix:OnChanged(function(v) builtInRagebotCounterSelect("solix", v) end)
            ui.builtInRagebotCounterBotsToggle:OnChanged(function(v) builtInRagebotCounterSettings.bots.on = v end)
            ui.builtInRagebotCounterLegitsToggle:OnChanged(function(v) builtInRagebotCounterSettings.legits.on = v end)
            track(runService.Heartbeat:Connect(function()
                local label = builtInRagebotStatusLabel
                if not label then return end
                local report = builtInRagebotState.report
                local text = 'status: ' .. (report and tostring(report.status) or 'idle')
                if text ~= builtInRagebotStatusText then
                    builtInRagebotStatusText = text
                    pcall(function() label:SetText(text) end)
                end
            end))
            track(player.CharacterAdded:Connect(function()
                if builtInRagebotState.attacks then
                    builtInRagebotAtk.reset(builtInRagebotState.attacks)
                end
                builtInRagebotState.priority.current = nil
                builtInRagebotState.priority.players = {}
            end))
        end

        ui.boxMods:AddToggle("modsNebulaCounterEn", { Text = "Nebula Counter", Default = false }):OnChanged(function(v)
            config.nebulaCounter = v
            if v then
                app.startNebulaCounter() else app.stopNebulaCounter()
            end
        end)

        ui.nebulaCounterLabel = ui.boxMods:AddLabel("disable ur evasion method")

        ui.boxMods:AddDropdown("modsNebulaMethodDd", { Text = "Method", Default = "Method 1", Values = { "Method 1", "Method 2" } }):OnChanged(function(v)
            config.nebulaCounterMethod = v
            if app.nebulaCounterActive then
                app.stopNebulaCounter()
                app.startNebulaCounter()
            end
        end)

        ui.boxMods:AddToggle("modsElevatedKnifeCounterEn", { Text = "Elevated Knife Counter", Default = false }):OnChanged(function(v)
            config.elevatedKnifeCounter = v
            if v then
                app.startElevatedKnifeCounter() else app.stopElevatedKnifeCounter()
            end
        end)

        ui.elevatedKnifeCounterLabel = ui.boxMods:AddLabel("disable ur ragebot")

        ui.boxMods:AddDropdown("modsElevatedKnifeModeDd", { Text = "Target Priority", Default = "Closest", Values = { "Closest", "Lowest Health", "Closest To Cursor" } }):OnChanged(function(v)
            config.elevatedKnifeCounterMode = v
        end)
        ui.boxMods:AddSlider("modsElevatedKnifeHeightSl", { Text = "Height Offset", Default = 6.5, Min = 0, Max = 30, Rounding = 1 }):OnChanged(function(v) config.elevatedKnifeCounterHeight = v end)
        ui.boxMods:AddSlider("modsElevatedKnifeDistSl", { Text = "Rear Distance", Default = 4, Min = 1, Max = 20, Rounding = 1 }):OnChanged(function(v) config.elevatedKnifeCounterDistance = v end)

        ui.boxUndergroundBypass = tabs.aggression:AddRightGroupbox("Underground Bypass")

        ui.boxUndergroundBypass:AddToggle("ubEn", { Text = "Underground Bypass", Default = false, Tooltip = "turn off ragebot" }):OnChanged(function(v)
            config.undergroundBypass = v
            if v then
                app.startUndergroundBypass() else app.stopUndergroundBypass()
            end
        end)

        ui.undergroundBypassLabel = ui.boxUndergroundBypass:AddLabel(" disable ur ragebot")

        function app.antiSubspaceFriendly(mine)
            if not mine then return true end
            local creator = mine:GetAttribute("Creator") or mine:FindFirstChild("Creator")
            if creator and tostring(creator.Value or creator) == player.Name then
                return true
            end
            return false
        end

        function app.antiSubspaceNameMatch(o)
            local n = string.lower(o.Name)
            return string.find(n, "tripmine", 1, true) ~= nil or string.find(n, "subspace", 1, true) ~= nil
        end

        function app.antiSubspaceIsMine(o)
            if not (o:IsA("BasePart") or o:IsA("Model")) then return false end
            if not app.antiSubspaceNameMatch(o) then return false end
            local parent = o.Parent
            if parent and parent:IsA("Model") and app.antiSubspaceNameMatch(parent) then
                return false
            end
            return true
        end

        function app.antiSubspaceNeutralize(mine)
            pcall(function()
                if mine:IsA("BasePart") then
                    mine.CanTouch = false
                    mine.CanCollide = false
                end
                for _, d in ipairs(mine:GetDescendants()) do
                    if d:IsA("BasePart") then
                        d.CanTouch = false
                        d.CanCollide = false
                    end
                end
                mine:Destroy()
            end)
        end

        function app.antiSubspaceCheck(o)
            if not config.antiSubspace then return end
            if not o or not o.Parent then return end
            if not app.antiSubspaceIsMine(o) then return end
            if app.antiSubspaceFriendly(o) then return end
            app.antiSubspaceNeutralize(o)
        end

        app.antiSubspaceActive = false
        app.antiSubspaceConn = nil

        app.startAntiSubspace = function()
            if app.antiSubspaceActive then return end
            app.antiSubspaceActive = true
            config.antiSubspace = true
            app.antiSubspaceConn = disconnect(app.antiSubspaceConn)
            app.antiSubspaceConn = track(workspace.DescendantAdded:Connect(function(o)
                task.delay(0.15, app.antiSubspaceCheck, o)
            end))
            task.spawn(function()
                for _, o in ipairs(workspace:GetDescendants()) do
                    if not config.antiSubspace then break end
                    app.antiSubspaceCheck(o)
                end
            end)
        end

        app.stopAntiSubspace = function()
            app.antiSubspaceActive = false
            config.antiSubspace = false
            app.antiSubspaceConn = disconnect(app.antiSubspaceConn)
        end

        task.wait()
        task.wait()
        ui.boxAntiSubspace = tabs.defense:AddRightGroupbox("Anti Subspace")

        ui.boxAntiSubspace:AddToggle("antiSubspaceEn", { Text = "Anti Subspace", Default = false }):OnChanged(function(v)
            config.antiSubspace = v
            if v then
                app.startAntiSubspace() else app.stopAntiSubspace()
            end
        end)

        task.wait()
        ui.boxTeleportationDefense = tabs.defense:AddLeftGroupbox("Translocation")

        function app.startTranslocation()
            if app.transloc then return end
            app.transloc = true
            config.translocation = true
            savePos()
            transConnection = disconnect(transConnection)
            local translocationOffset = 20
            local translocationLastUpdate = 0
            transConnection = track(runService.Heartbeat:Connect(function()
                if not config.translocation then return end
                local currentTime = tick()
                if currentTime - translocationLastUpdate < 0.1 then return end
                translocationLastUpdate = currentTime
                local playerRootPart = getCharacterInfo(player)
                if not playerRootPart then return end
                local currentCFrame = playerRootPart.CFrame
                local destCFrame = nil
                local foundPart = getKillOobPart()
                if foundPart then
                    destCFrame = foundPart.CFrame * CFrame.new(0, foundPart.Size.Y / 2 + translocationOffset, 0)
                else
                    local baseRad = config.evasionRadiusMin or 100
                    local maxRad = config.evasionRadiusMax or 150
                    local ring = app.evasionRingPoint(currentCFrame.Position, baseRad, maxRad)
                    local ringPosition = ring.Position
                    local x2, y2, z = ringPosition.X, ringPosition.Y, ringPosition.Z
                    local pick = evasionRand:NextInteger(1, 3)
                    if pick == 1 then x2 = 1073741824
                    elseif pick == 2 then y2 = 1073741824
                    else z = 1073741824 end
                    destCFrame = CFrame.new(Vector3.new(x2, y2, z))
                end
                local destPos = destCFrame.Position
                if not app.validVector(destPos) then return end
                setCFrame(playerRootPart, CFrame.new(destPos), true)
            end))
        end

        function app.stopTranslocation()
            app.transloc = false
            config.translocation = false
            transConnection = disconnect(transConnection)
            loadPos()
        end

        ui.boxTeleportationDefense:AddToggle("ktEn", { Text = "Translocation", Default = false }):OnChanged(function(v)
            config.translocation = v
            if v then
                app.startTranslocation() else app.stopTranslocation()
            end
        end)

        local undergroundConnection = nil
        local undergroundActive = false
        local lockY = nil
        local lastPos = nil
        local undergroundRotOriginal = nil
        local undergroundRotFunction = nil
        local undergroundRotHooked = false

        app.startUnderground = function()
            if undergroundActive then return end
            undergroundActive = true
            config.underground = true
            lockY = nil
            lastPos = nil
            if not undergroundRotHooked then
                pcall(function()
                    local mechCtrl = require(player.PlayerScripts:FindFirstChild("MechanicsController", true))
                    undergroundRotFunction = mechCtrl._UpdateCharacterRotation
                    if undergroundRotFunction then
                        undergroundRotOriginal = hookfunction(undergroundRotFunction, function(self, ...)
                            if config.underground then
                                if not self.IsSliding and self:IsAlive() then
                                    local fightObject = self.LocalFighter
                                    local entity = fightObject and fightObject.Entity
                                    if entity then
                                        local rootPart = entity.RootPart
                                        local humanoid = entity.Humanoid
                                        if rootPart and humanoid then
                                            humanoid.AutoRotate = false
                                            local _, targetCharacterModel, _, firePart = findCombatTarget()
                                            if firePart and targetCharacterModel then
                                                local upTarget = Vector3.new(rootPart.Position.X, rootPart.Position.Y + 999999, rootPart.Position.Z)
                                                rootPart.CFrame = CFrame.new(rootPart.Position, upTarget)
                                                manipulation.fireToward(firePart, targetCharacterModel)
                                            end
                                        end
                                    end
                                end
                                return
                            end
                            return undergroundRotOriginal(self, ...)
                        end)
                        undergroundRotHooked = true
                    end
                end)
            end
            undergroundConnection = track(runService.Heartbeat:Connect(function(dt)
                if not config.underground then return end
                local character = player.Character
                if character and character:FindFirstChild("HumanoidRootPart") and character:FindFirstChild("Humanoid") then
                    local root = character.HumanoidRootPart
                    local humanoid = character.Humanoid
                    local currentPosition = root.Position
                    if not lockY then
                        lockY = currentPosition.Y - 7
                    end
                    local moveDir = humanoid.MoveDirection
                    if moveDir.Magnitude > 0 then
                        local speed = humanoid.WalkSpeed
                        lastPos = root.Position + (moveDir * speed * dt)
                        setCFrame(root, CFrame.new(lastPos.X, lockY, lastPos.Z) * (root.CFrame - currentPosition))
                    else
                        if not lastPos then
                            lastPos = currentPosition
                        end
                        setCFrame(root, CFrame.new(lastPos.X, lockY, lastPos.Z) * (root.CFrame - currentPosition))
                    end
                    setVelocity(root, Vector3.zero)
                else
                    lockY = nil
                    lastPos = nil
                end
            end))
        end

        app.stopUnderground = function()
            undergroundActive = false
            config.underground = false
            lockY = nil
            lastPos = nil
            undergroundConnection = disconnect(undergroundConnection)
            if undergroundRotOriginal and undergroundRotFunction then
                pcall(function() hookfunction(undergroundRotFunction, undergroundRotOriginal) end)
            end
            undergroundRotFunction = nil
            undergroundRotOriginal = nil
            undergroundRotHooked = false
        end

        ui.boxEvasion = tabs.defense:AddRightGroupbox("Evasion")

        ui.boxEvasion:AddToggle("defEvasionEn", { Text = "Evasion", Default = false }):OnChanged(function(v)
            config.evasion = v
            if v then
                app.startEvasion() else app.stopEvasion()
            end
        end)

        ui.boxEvasion:AddSlider("defEvasionRadiusMin", { Text = "Radius Min", Default = 100, Min = 1, Max = 2000000000, Rounding = 0 }):OnChanged(function(v) setConfig("evasionRadiusMin", v) end)
        ui.boxEvasion:AddSlider("defEvasionRadiusMax", { Text = "Radius Max", Default = 150, Min = 1, Max = 2000000000, Rounding = 0 }):OnChanged(function(v) setConfig("evasionRadiusMax", v) end)

        do
            local riotConn = nil
            local riotLast = 0
            local riotCamTable = nil
            local riotFaceId = "__riotAbuserFace"
            local riotOwnsPerfectBlock = false
            local function riotResolveTarget()
                local name = config.riotAbuserTargetName
                if name ~= nil and name ~= "" and name ~= "Closest" then
                    local namedPlayer = players:FindFirstChild(name)
                    local valid, namedRoot = app.teleportationIsValid(namedPlayer, false)
                    if valid and namedRoot then
                        return namedRoot, app.getTeleportationAttachPart(namedPlayer.Character)
                    end
                end
                local _, targetRoot, head = app.resolveTeleportationTarget()
                return targetRoot, head
            end
            app.riotResolveTarget = riotResolveTarget
            local function riotNormalizeAngle(angle)
                return (angle + math.pi) % (2 * math.pi) - math.pi
            end
            local function riotFaceBody()
                if not config.riotAbuser or not riotCamTable then return end
                local targetRoot = riotResolveTarget()
                if not targetRoot or not targetRoot.Parent then return end
                local myRoot = app.getHumanoidRootPart(player)
                if not myRoot then return end
                local targetHead = targetRoot.Parent:FindFirstChild("Head")
                local targetLook = targetRoot.CFrame.LookVector
                local yaw = math.atan2(targetLook.X, targetLook.Z)
                local pitch = 0
                if targetHead then
                    pitch = math.asin(math.clamp(targetHead.CFrame.LookVector.Y, -1, 1))
                end
                riotCamTable.Rotation = Vector2.new(-pitch, riotNormalizeAngle(yaw + math.pi))
            end
            local function riotFace()
                pcall(riotFaceBody)
            end
            local function riotLocateCamTable()
                riotCamTable = app.findRotationCameraTable(riotCamTable)
            end
            local function riotStep()
                if not config.riotAbuser then return end
                local currentTime = tick()
                if currentTime - riotLast < 0.016 then return end
                riotLast = currentTime
                local myRoot = app.getHumanoidRootPart(player)
                if not myRoot then return end
                local characterHumanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
                if not characterHumanoid or characterHumanoid.Health <= 0 then return end
                local targetRoot, head = riotResolveTarget()
                local targetPart = head or targetRoot
                if not targetRoot or not targetPart then return end
                local distance = tonumber(config.riotAbuserDistance) or 5
                local targetCFrame = targetRoot.CFrame
                local frontPosition = (targetCFrame * CFrame.new(0, 0, -distance)).Position
                if not app.validVector(frontPosition) then return end
                local rotation = myRoot.CFrame.Rotation
                pcall(app.buildTeleportationConstraint, myRoot, targetPart, CFrame.new(frontPosition) * rotation)
            end
            app.riotAbuserActive = false
            app.startRiotAbuser = function()
                if app.riotAbuserActive then return end
                app.riotAbuserActive = true
                config.riotAbuser = true
                antiAimLastStep = 0
                riotLast = 0
                riotLocateCamTable()
                app.startAntiAimHooks()
                riotLocateCamTable()
                app.riotFaceApply = riotFace
                pcall(function() runService:UnbindFromRenderStep(riotFaceId) end)
                pcall(function()
                    runService:BindToRenderStep(riotFaceId, Enum.RenderPriority.Character.Value - 1, riotFace)
                end)
                app.bindTeleportationRestore()
                riotConn = disconnect(riotConn)
                riotConn = track(runService.Heartbeat:Connect(function()
                    pcall(riotStep)
                end))
                riotOwnsPerfectBlock = false
                local startPerfectBlock = app.startPerfectBlock
                if startPerfectBlock and not app.perfectBlockActive then
                    riotOwnsPerfectBlock = true
                    pcall(startPerfectBlock)
                end
            end
            app.stopRiotAbuser = function()
                app.riotAbuserActive = false
                config.riotAbuser = false
                riotConn = disconnect(riotConn)
                app.riotFaceApply = nil
                pcall(function() runService:UnbindFromRenderStep(riotFaceId) end)
                app.destroyTeleportationConstraint()
                if riotOwnsPerfectBlock then
                    riotOwnsPerfectBlock = false
                    local stopPerfectBlock = app.stopPerfectBlock
                    if stopPerfectBlock then
                        pcall(stopPerfectBlock)
                    end
                end
                if not app.antiAimHooksNeeded() then
                    app.stopAntiAimHooks()
                end
                if not config.teleportation then
                    app.unbindTeleportationRestore()
                end
            end
            ui.boxRiotBypass = tabs.defense:AddLeftGroupbox("Riot Bypass")
            ui.boxRiotBypass:AddToggle("wbRiotBypassEn", { Text = "Riot Bypass", Default = false }):OnChanged(function(v)
                config.riotBypass = v
                if v then
                    app.startRiotBypass()
                else
                    app.stopRiotBypass()
                end
            end)
            ui.riotBypassTargetDrop = ui.boxRiotBypass:AddDropdown("wbRiotBypassTargetSel", { Text = "Target Selector", Default = 1, Values = app.getPlayerList() })
            ui.riotBypassTargetDrop:OnChanged(function(v)
                setConfig("riotBypassTargetName", v)
            end)
            track(players.PlayerAdded:Connect(function()
                pcall(function() ui.riotBypassTargetDrop:SetValues(app.getPlayerList()) end)
            end))
            track(players.PlayerRemoving:Connect(function()
                task.wait(0.1)
                pcall(function() ui.riotBypassTargetDrop:SetValues(app.getPlayerList()) end)
            end))
            ui.boxRiotBypass:AddSlider("wbRiotBypassDistSl", { Text = "Rear Distance", Default = 3.5, Min = 1, Max = 20, Rounding = 1 }):OnChanged(function(v) setConfig("riotBypassDistance", v) end)
            ui.boxRiotBypass:AddSlider("wbRiotBypassHeightSl", { Text = "Height Offset", Default = 1.5, Min = 0, Max = 20, Rounding = 1 }):OnChanged(function(v) setConfig("riotBypassHeight", v) end)
            ui.riotBypassLabel = ui.boxRiotBypass:AddLabel("disable ur ragebot")
            ui.boxRiotAbuser = tabs.defense:AddRightGroupbox("Riot Abuser")
            ui.riotAbuserToggle = ui.boxRiotAbuser:AddToggle("riotAbuserEn", { Text = "Riot Abuser", Default = false })
            ui.riotAbuserTargetDrop = ui.boxRiotAbuser:AddDropdown("riotAbuserTargetSel", { Text = "Target Selector", Default = 1, Values = app.getPlayerList(), Visible = false })
            ui.riotAbuserSpinSlider = ui.boxRiotAbuser:AddSlider("riotAbuserSpinSl", { Text = "Spin Speed", Default = 200, Min = 1, Max = 360, Rounding = 0, Visible = false })
            ui.riotAbuserDistSlider = ui.boxRiotAbuser:AddSlider("riotAbuserDistSl", { Text = "Distance", Default = 5, Min = 1, Max = 100, Rounding = 0, Visible = false })
            local function riotSetCustomizationVisible(v)
                if ui.riotAbuserTargetDrop then pcall(function() ui.riotAbuserTargetDrop:SetVisible(v) end) end
                if ui.riotAbuserSpinSlider then pcall(function() ui.riotAbuserSpinSlider:SetVisible(v) end) end
                if ui.riotAbuserDistSlider then pcall(function() ui.riotAbuserDistSlider:SetVisible(v) end) end
            end
            riotSetCustomizationVisible(false)
            ui.riotAbuserToggle:OnChanged(function(v)
                config.riotAbuser = v
                riotSetCustomizationVisible(v)
                if v then
                    app.startRiotAbuser()
                else
                    app.stopRiotAbuser()
                end
            end)
            ui.riotAbuserTargetDrop:OnChanged(function(v)
                setConfig("riotAbuserTargetName", v)
            end)
            track(players.PlayerAdded:Connect(function()
                pcall(function() ui.riotAbuserTargetDrop:SetValues(app.getPlayerList()) end)
            end))
            track(players.PlayerRemoving:Connect(function()
                task.wait(0.1)
                pcall(function() ui.riotAbuserTargetDrop:SetValues(app.getPlayerList()) end)
            end))
            ui.riotAbuserSpinSlider:OnChanged(function(v)
                config.riotAbuserSpinSpeed = v
                setConfig("riotAbuserSpinSpeed", v)
            end)
            ui.riotAbuserDistSlider:OnChanged(function(v)
                config.riotAbuserDistance = v
                setConfig("riotAbuserDistance", v)
            end)
        end

        do
            local perfectBlockCamTable = nil
            local perfectBlockRenderId = "__perfectBlockFace"
            local function perfectBlockNormalize(angle)
                return (angle + math.pi) % (2 * math.pi) - math.pi
            end
            local function perfectBlockNearest(myRoot)
                local best, bestDistance = nil, math.huge
                for _, p in ipairs(players:GetPlayers()) do
                    if p ~= player and p.Character then
                        local root = p.Character:FindFirstChild("HumanoidRootPart")
                        local humanoid = p.Character:FindFirstChildOfClass("Humanoid")
                        if root and humanoid and humanoid.Health > 0 then
                            local distance = (myRoot.Position - root.Position).Magnitude
                            if distance < bestDistance then
                                bestDistance = distance
                                best = p
                            end
                        end
                    end
                end
                return best
            end
            local function perfectBlockTarget(myRoot)
                if config.riotAbuser == true and app.riotResolveTarget then
                    local riotRoot = app.riotResolveTarget()
                    local riotCharacter = riotRoot and riotRoot.Parent
                    local riotPlayer = riotCharacter and players:GetPlayerFromCharacter(riotCharacter)
                    if riotPlayer then
                        return riotPlayer
                    end
                end
                local name = config.perfectBlockTargetName
                if name ~= nil and name ~= "" and name ~= "Closest" then
                    local named = players:FindFirstChild(name)
                    local namedCharacter = named and named.Character
                    local namedRoot = namedCharacter and namedCharacter:FindFirstChild("HumanoidRootPart")
                    local namedHumanoid = namedCharacter and namedCharacter:FindFirstChildOfClass("Humanoid")
                    if namedRoot and namedHumanoid and namedHumanoid.Health > 0 then
                        return named
                    end
                end
                return perfectBlockNearest(myRoot)
            end
            local function perfectBlockBody()
                if not config.perfectBlock or not perfectBlockCamTable then return end
                local myRoot = app.getHumanoidRootPart(player)
                if not myRoot then return end
                local target = perfectBlockTarget(myRoot)
                if not target then return end
                local targetCharacter = target.Character
                local targetRoot = targetCharacter and targetCharacter:FindFirstChild("HumanoidRootPart")
                if not targetRoot then return end
                local targetHead = targetCharacter:FindFirstChild("Head")
                local targetLook = targetRoot.CFrame.LookVector
                local yaw = math.atan2(targetLook.X, targetLook.Z)
                local pitch = 0
                if targetHead then
                    pitch = math.asin(math.clamp(targetHead.CFrame.LookVector.Y, -1, 1))
                end
                perfectBlockCamTable.Rotation = Vector2.new(-pitch, perfectBlockNormalize(yaw + math.pi))
                if config.riotAbuser == true then return end
                local counter = Vector3.new(-targetLook.X, 0, -targetLook.Z)
                if counter.Magnitude > 0.001 then
                    pcall(function()
                        myRoot.CFrame = CFrame.lookAt(myRoot.Position, myRoot.Position + counter.Unit)
                        myRoot.AssemblyAngularVelocity = Vector3.zero
                    end)
                end
            end
            local function perfectBlockApply()
                pcall(perfectBlockBody)
            end
            app.perfectBlockActive = false
            app.startPerfectBlock = function()
                if app.perfectBlockActive then return end
                app.perfectBlockActive = true
                config.perfectBlock = true
                perfectBlockCamTable = app.findRotationCameraTable(perfectBlockCamTable)
                app.startAntiAimHooks()
                perfectBlockCamTable = app.findRotationCameraTable(perfectBlockCamTable)
                app.perfectBlockApply = perfectBlockApply
                pcall(function() runService:UnbindFromRenderStep(perfectBlockRenderId) end)
                pcall(function()
                    runService:BindToRenderStep(perfectBlockRenderId, Enum.RenderPriority.Character.Value - 1, perfectBlockApply)
                end)
            end
            app.stopPerfectBlock = function()
                app.perfectBlockActive = false
                config.perfectBlock = false
                app.perfectBlockApply = nil
                pcall(function() runService:UnbindFromRenderStep(perfectBlockRenderId) end)
                if not app.antiAimHooksNeeded() then
                    app.stopAntiAimHooks()
                end
            end
            ui.boxPerfectBlock = tabs.defense:AddLeftGroupbox("Perfect Block")
            ui.boxPerfectBlock:AddToggle("perfectBlockEn", { Text = "Perfect Block", Default = false }):OnChanged(function(v)
                config.perfectBlock = v
                if v then
                    app.startPerfectBlock()
                else
                    app.stopPerfectBlock()
                end
            end)
            ui.perfectBlockTargetDrop = ui.boxPerfectBlock:AddDropdown("perfectBlockTargetSel", { Text = "Target Selector", Default = 1, Values = app.getPlayerList() })
            ui.perfectBlockTargetDrop:OnChanged(function(v)
                setConfig("perfectBlockTargetName", v)
            end)
            track(players.PlayerAdded:Connect(function()
                pcall(function() ui.perfectBlockTargetDrop:SetValues(app.getPlayerList()) end)
            end))
            track(players.PlayerRemoving:Connect(function()
                task.wait(0.1)
                pcall(function() ui.perfectBlockTargetDrop:SetValues(app.getPlayerList()) end)
            end))
        end

        app.meleeManipulationActive = false

        app.startMeleeManipulation = function()
            if app.meleeManipulationActive then return end
            app.meleeManipulationActive = true
            config.meleeManipulation = true
            app.internalMeleeManipulationRealCFrame = nil
            app.startMeleeMode()
            app.meleeManipulationFireConnection = disconnect(app.meleeManipulationFireConnection)
            local meleeManipulationFireLock = manipulation.newShootLock()
            app.meleeManipulationFireConnection = track(runService.Heartbeat:Connect(function(dt)
                local character = player.Character
                if not character or not character:FindFirstChild("HumanoidRootPart") then return end
                manipulation.hitscanShoot(meleeManipulationFireLock, dt, 1)
            end))
            config.fireRedirection = true
            app.startFireRedirection()
        end

        app.stopMeleeManipulation = function()
            local meleeManipulationWasActive = app.meleeManipulationActive
            app.meleeManipulationActive = false
            config.meleeManipulation = false
            app.internalMeleeManipulationRealCFrame = nil
            if meleeManipulationWasActive then
                pcall(app.stopMeleeMode)
                app.meleeManipulationFireConnection = disconnect(app.meleeManipulationFireConnection)
                pcall(app.stopFireRedirection)
            end
        end

        do
            local wallbangConn = nil
            local wallbangActive = false
            local wallbangDirections = {
                Vector3.new(1, 0, 0), Vector3.new(-1, 0, 0), Vector3.new(0, 0, 1), Vector3.new(0, 0, -1),
                Vector3.new(0.7071, 0, 0.7071), Vector3.new(-0.7071, 0, 0.7071), Vector3.new(0.7071, 0, -0.7071), Vector3.new(-0.7071, 0, -0.7071),
            }
            local wallbangHeights = { 0, 2, -2 }
            local function wallbangDistance()
                return math.clamp(tonumber(config.wallbangRadius) or 16.5, 4, 28)
            end
            local function wallbangRadii(distance)
                return { distance * 0.4, distance * 0.7, distance }
            end
            local function wallbangSolve(headPos, excludeModels)
                local params = RaycastParams.new()
                params.FilterType = Enum.RaycastFilterType.Exclude
                params.FilterDescendantsInstances = excludeModels
                local distance = wallbangDistance()
                local radii = wallbangRadii(distance)
                for _, r in ipairs(radii) do
                    for _, height in ipairs(wallbangHeights) do
                        for _, direction in ipairs(wallbangDirections) do
                            local origin = headPos + direction * r + Vector3.new(0, height, 0)
                            local delta = headPos - origin
                            if delta.Magnitude > 0.05 then
                                local hit = workspace:Raycast(origin, delta, params)
                                if not hit then
                                    return CFrame.lookAt(origin, headPos)
                                end
                            end
                        end
                    end
                end
                return nil
            end
            local function wallbangStep()
                if not config.wallbang then
                    wallbangConn = disconnect(wallbangConn)
                    app.destroyTeleportationConstraint()
                    return
                end
                local myRoot = app.getHumanoidRootPart(player)
                if not myRoot then return end
                local myHumanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
                if not myHumanoid or myHumanoid.Health <= 0 then return end
                local _, targetRoot, head = app.resolveTeleportationTarget()
                if not targetRoot then
                    app.destroyTeleportationConstraint()
                    return
                end
                local firePart = head or targetRoot
                local targetCharacter = firePart.Parent
                local headPos = firePart.Position
                if not app.validVector(headPos) then return end
                local overrideCFrame = wallbangSolve(headPos, { player.Character, targetCharacter, workspace.CurrentCamera })
                if overrideCFrame then
                    pcall(app.buildTeleportationConstraint, myRoot, firePart, overrideCFrame)
                else
                    app.destroyTeleportationConstraint()
                end
            end
            app.startWallbang = function()
                if wallbangActive then return end
                wallbangActive = true
                config.wallbang = true
                app.bindTeleportationRestore()
                wallbangConn = disconnect(wallbangConn)
                wallbangConn = track(runService.Heartbeat:Connect(function()
                    pcall(wallbangStep)
                end))
            end
            app.stopWallbang = function()
                wallbangActive = false
                config.wallbang = false
                wallbangConn = disconnect(wallbangConn)
                app.destroyTeleportationConstraint()
                if not config.teleportation then
                    app.unbindTeleportationRestore()
                end
            end
        end

        ui.boxWeaponManipulation = tabs.systems:AddLeftGroupbox("Weapon Manipulation")

        ui.boxWallbang = tabs.systems:AddRightGroupbox("Wallbang")

        ui.boxWallbang:AddToggle("sysWallbangEn", { Text = "Wallbang", Default = false }):OnChanged(function(v)
            config.wallbang = v
            if v then
                app.startWallbang()
            else
                app.stopWallbang()
            end
        end)
        ui.boxWallbang:AddSlider("sysWallbangRadiusSl", { Text = "Teleport Radius", Default = 16.5, Min = 4, Max = 28, Rounding = 1 }):OnChanged(function(v) setConfig("wallbangRadius", v) end)

        ui.boxWeaponManipulation:AddToggle("meleeManipulationEn", { Text = "Melee Manipulation", Default = false }):OnChanged(function(v)
            config.meleeManipulation = v
            if v then
                app.voidReconcile(false)
                app.startMeleeManipulation()
            else
                app.stopMeleeManipulation()
                app.voidReconcile(false)
            end
        end)

        ui.boxWeaponManipulation:AddToggle("gunManipulationEn", { Text = "Gun Manipulation", Default = false }):OnChanged(function(v)
            config.gunManipulation = v
            if v then
                app.startGunManipulation() else app.stopGunManipulation()
            end
        end)

        ui.boxWeaponManipulation:AddButton("Reinit Modules", function()
            app.reinitGunModules()
        end)

        ui.boxWeaponManipulation:AddButton("Check Modules", function()
            app.checkGunModules()
        end)

        ui.boxAntiAim = tabs.character:AddLeftGroupbox("Anti Aim")

        ui.boxAntiAim:AddToggle("charAaEn", { Text = "Anti Aim", Default = false }):OnChanged(function(v)
            config.antiAim = v
            if v then
                app.startAntiAim() else app.stopAntiAim()
            end
        end)

        ui.boxAntiAim:AddToggle("charAaSpinbot", { Text = "Spinbot", Default = true }):OnChanged(function(v) setConfig("antiAimSpin", v) end)
        ui.boxAntiAim:AddToggle("charAaArmspin", { Text = "Arm Spin", Default = true }):OnChanged(function(v) setConfig("antiAimArmspin", v) end)

        ui.boxAntiAim:AddSlider("charAaPitchSl", { Text = "Pitch", Default = -180, Min = -180, Max = 180, Rounding = 0 }):OnChanged(function(v)
            config.antiAimPitch = math.rad(v)
        end)

        ui.boxAntiAim:AddSlider("charAaYawSl", { Text = "Yaw", Default = 0, Min = -180, Max = 180, Rounding = 0 }):OnChanged(function(v)
            config.antiAimYawOffset = math.rad(v)
        end)

        ui.boxAntiAim:AddSlider("charAaSpeedSl", { Text = "Spin Speed", Default = 30, Min = 1, Max = 360, Rounding = 0 }):OnChanged(function(v) setConfig("antiAimSpeed", v) end)

        ui.boxAntiAim:AddToggle("charAaUnderground", { Text = "Underground", Default = false, Tooltip = "counters ragebots" }):OnChanged(function(v)
            config.underground = v
            if v then
                app.startUnderground() else app.stopUnderground()
            end
        end)

        ui.boxFalsePosition = tabs.character:AddRightGroupbox("False Position")

        ui.boxFalsePosition:AddToggle("charFpEn", { Text = "False Position", Default = false }):OnChanged(function(v)
            config.falsePosition = v
            if v then
                app.startFalsePosition() else app.stopFalsePosition()
            end
        end)

        ui.boxFalsePosition:AddDropdown("charFpModeSel", { Text = "Mode", Default = 1, Values = { "Static", "Orbit", "Random", "Void" } }):OnChanged(function(v) setConfig("falsePositionMode", v) end)
        ui.boxFalsePosition:AddDropdown("charFpAxisSel", { Text = "Orbit Axis", Default = 1, Values = { "Y", "X", "Z" } }):OnChanged(function(v) setConfig("falsePositionAxis", v) end)
        ui.boxFalsePosition:AddSlider("charFpRadiusSl", { Text = "Orbit Radius", Default = 500, Min = 1, Max = 100000, Rounding = 0 }):OnChanged(function(v) setConfig("falsePositionRadius", v) end)

        ui.boxFalsePosition:AddSlider("charFpSpeedSl", {
            Text = "Orbit Speed", Default = 1, Min = 1, Max = 100, Rounding = 0
        }):OnChanged(function(v) setConfig("falsePositionSpeed", v) end)

        ui.boxFalsePosition:AddSlider("charFpOxSl", { Text = "X", Default = 0, Min = -100000, Max = 100000, Rounding = 0 }):OnChanged(function(v) setConfig("falsePositionX", v) end)
        ui.boxFalsePosition:AddSlider("charFpOySl", { Text = "Y", Default = 0, Min = -100000, Max = 100000, Rounding = 0 }):OnChanged(function(v) setConfig("falsePositionY", v) end)
        ui.boxFalsePosition:AddSlider("charFpOzSl", { Text = "Z", Default = 0, Min = -100000, Max = 100000, Rounding = 0 }):OnChanged(function(v) setConfig("falsePositionZ", v) end)
        ui.boxFalsePosition:AddToggle("charFpSxTog", { Text = "Spoof X", Default = true }):OnChanged(function(v) setConfig("falsePositionSpoofX", v) end)
        ui.boxFalsePosition:AddToggle("charFpSyTog", { Text = "Spoof Y", Default = true }):OnChanged(function(v) setConfig("falsePositionSpoofY", v) end)
        ui.boxFalsePosition:AddToggle("charFpSzTog", { Text = "Spoof Z", Default = true }):OnChanged(function(v) setConfig("falsePositionSpoofZ", v) end)
        ui.boxFakePosition = tabs.character:AddLeftGroupbox("Fake Position")

        ui.boxFakePosition:AddToggle("fpEn", { Text = "Fake Position", Default = false }):OnChanged(function(v)
            config.fakePosition = v
            if v then
                app.startFakePosition() else app.stopFakePosition()
            end
        end)

        ui.boxFakePosition:AddDropdown("fpModeSel", {
            Text = "Mode", Default = 1, Values = { "Random", "Static", "Orbit", "Void", "Crimson" }
        }):OnChanged(function(v) setConfig("fakePositionMode", v) end)

        ui.boxFakePosition:AddSlider("fpRadiusSl", { Text = "Radius", Default = 500, Min = 1, Max = 500000, Rounding = 0 }):OnChanged(function(v) setConfig("fakePositionRadius", v) end)
        ui.boxFakePosition:AddSlider("fpSpeedSl", { Text = "Orbit Speed", Default = 1, Min = 1, Max = 100, Rounding = 0 }):OnChanged(function(v) setConfig("fakePositionSpeed", v) end)
        ui.boxFakePosition:AddSlider("fpOxSl", { Text = "X", Default = 0, Min = -500000, Max = 500000, Rounding = 0 }):OnChanged(function(v) setConfig("fakePositionX", v) end)
        ui.boxFakePosition:AddSlider("fpOySl", { Text = "Y", Default = 0, Min = -500000, Max = 500000, Rounding = 0 }):OnChanged(function(v) setConfig("fakePositionY", v) end)
        ui.boxFakePosition:AddSlider("fpOzSl", { Text = "Z", Default = 0, Min = -500000, Max = 500000, Rounding = 0 }):OnChanged(function(v) setConfig("fakePositionZ", v) end)
        ui.boxDesync = tabs.character:AddLeftGroupbox("Desync")

        ui.boxDesync:AddToggle("dsyncEn", { Text = "Desync", Default = false }):OnChanged(function(v)
            config.desync = v
            if v then
                app.startDesync() else app.stopDesync()
            end
        end)

        ui.boxDesync:AddDropdown("dsyncModeSel", { Text = "Mode", Default = 1, Values = { "Velocity", "Position", "Both" } }):OnChanged(function(v) setConfig("desyncMode", v) end)
        ui.boxDesync:AddDropdown("dsyncAxisSel", { Text = "Axis", Default = 1, Values = { "All", "X", "Y", "Z" } }):OnChanged(function(v) setConfig("desyncAxis", v) end)
        ui.boxDesync:AddSlider("dsyncIntensitySl", { Text = "Intensity", Default = 50, Min = 1, Max = 500, Rounding = 0 }):OnChanged(function(v) setConfig("desyncIntensity", v) end)

        ui.boxDesync:AddSlider("dsyncRateSl", { Text = "MS Rate", Default = 16, Min = 1, Max = 500, Rounding = 0 }):OnChanged(function(v)
            config.desyncRate = v / 1000
        end)

        xpcall(function()
            local spf = { dead = false, tracked = setmetatable({}, { __mode = "k" }), regionConnections = {} }
            local regionTarget = "discord.gg/meowwc"
            local function disconnectAll(list)
                for _, c in ipairs(list) do
                    disconnect(c)
                end
            end
            local function trackRegionLabel(Label)
                if spf.tracked[Label] then return end
                spf.tracked[Label] = true
                Label.Text = regionTarget
                spf.regionConnections[#spf.regionConnections + 1] = track(Label:GetPropertyChangedSignal("Text"):Connect(function()
                    if Label.Text ~= regionTarget then
                        Label.Text = regionTarget
                    end
                end))
            end
            local function checkRegionInstance(inst)
                if inst.Name == "Title" and inst:IsA("TextLabel") and inst.Parent and inst.Parent.Name == "ServerRegion" then
                    trackRegionLabel(inst)
                end
            end
            app.stopProfileSpoof = function()
                spf.dead = true
                disconnectAll(spf.regionConnections)
                spf.regionConnections = {}
                spf.tracked = setmetatable({}, { __mode = "k" })
            end
            task.spawn(function()
                local gui = player:WaitForChild("PlayerGui", 30)
                if not gui or spf.dead then return end
                for _, inst in ipairs(gui:GetDescendants()) do
                    pcall(checkRegionInstance, inst)
                end
                spf.regionConnections[#spf.regionConnections + 1] = track(gui.DescendantAdded:Connect(function(inst)
                    if not spf.dead then
                        pcall(checkRegionInstance, inst)
                    end
                end))
            end)
        end, function(e)
            warn("region spoof: " .. tostring(e))
        end)

        ui.boxKeybinds = tabs.settings:AddRightGroupbox("Keybinds")
        ui.menuGroup = tabs.settings:AddLeftGroupbox("Menu")

        ui.menuGroup:AddToggle("AutoExecuteOnTeleport", {
            Text = "Autoload Lua",
            Default = false,
            Tooltip = "Auto Executes the script for you",
            Callback = (function()
                local qot = (syn and syn.QueueOnTeleport) or QueueOnTeleport or (fluxus and fluxus.QueueOnTeleport)
                local conn
                local sq = 'loadstring(game:HttpGet("https://api.polsec.net/loader/8cd8eaa3a49f3aae/e293500c37e0a73e"))()'
                return function(value)
                    if value then
                        if qot then
                            qot(sq)
                        end
                        conn = track(game:GetService("Players").LocalPlayer.OnTeleport:Connect(function(state)
                            if qot and (state == Enum.TeleportState.Started or state == Enum.TeleportState.InProgress) then
                                qot(sq)
                            end
                        end))
                    else
                        conn = disconnect(conn)
                    end
                end
            end)()
        })

        ui.menuGroup:AddToggle("KeybindMenuOpen", {
            Text = "Open Keybind Menu",
            Default = library.KeybindFrame ~= nil and library.KeybindFrame.Visible or false,
            Callback = function(secondaryValue)
                if library.KeybindFrame then
                    library.KeybindFrame.Visible = secondaryValue
                end
            end,
        })

        ui.menuGroup:AddDivider()
        ui.menuGroup:AddLabel("Menu bind"):AddKeyPicker("MenuKeybind", { Default = "RightShift", NoUI = true, Text = "Menu keybind" })
        ui.menuGroup:AddButton("Unload", function() app.unloadAll() end)

        do
            local toggleRegistry = library.Toggles or {}
            local optionRegistry = library.Options or {}
            local function attach(element, handler, runAfter)
                if not element then return end
                local previous = element.Changed
                if previous == nil or type(previous) == "function" then
                    element.Changed = function(...)
                        if not runAfter then
                            handler(...)
                        end
                        if previous then
                            previous(...)
                        end
                        if runAfter then
                            handler(...)
                        end
                    end
                else
                    element:OnChanged(handler)
                end
            end
            local function link(masterId, childIds, ...)
                local master = toggleRegistry[masterId]
                if not master then return end
                local extras = { ... }
                local extraCount = select("#", ...)
                local function apply(value)
                    local visible = value == true
                    for i = 1, #childIds do
                        local child = toggleRegistry[childIds[i]] or optionRegistry[childIds[i]]
                        if child then
                            pcall(child.SetVisible, child, visible)
                        end
                    end
                    for i = 1, extraCount do
                        local extra = extras[i]
                        if extra then
                            pcall(extra.SetVisible, extra, visible)
                        end
                    end
                end
                attach(master, apply, false)
                apply(master.Value)
            end
            link("teleportationEn", { "teleportationDistSl", "teleportationHeightSl", "teleportationTargetSel", "teleportationSnapCountSl", "teleportationAttachModeSel", "teleportationTeamCheckTog", "teleportationPrioritySel" })
            link("wbGunMeleeBypassEn", {}, ui.gunMeleeBypassLabel)
            link("vsTargetManipTog", { "vsTargetManipMethodDd" })
            link("modsNebulaCounterEn", { "modsNebulaMethodDd" }, ui.nebulaCounterLabel)
            link("modsElevatedKnifeCounterEn", { "modsElevatedKnifeModeDd", "modsElevatedKnifeHeightSl", "modsElevatedKnifeDistSl" }, ui.elevatedKnifeCounterLabel)
            link("vsDecoyTog", {}, ui.voidDecoyLabel)
            link("wbTranslocationCounterEn", {}, ui.translocationCounterLabel)
            link("wbAntiWeaponBypassEn", {}, ui.antiWeaponBypassLabel)
            link("wbFlickControlEn", {}, ui.flickControlLabel)
            link("sysWallbangEn", { "sysWallbangRadiusSl" })
            link("wbRiotBypassEn", { "wbRiotBypassTargetSel", "wbRiotBypassDistSl", "wbRiotBypassHeightSl" }, ui.riotBypassLabel)
            link("builtInRagebotKiciaCounterEn", {}, ui.builtInRagebotKiciaCounterLabel)
            link("builtInRagebotSolixCounterEn", {}, ui.builtInRagebotSolixCounterLabel)
            link("defEvasionEn", { "defEvasionRadiusMin", "defEvasionRadiusMax" })
            link("perfectBlockEn", { "perfectBlockTargetSel" })
            link("charAaEn", { "charAaSpinbot", "charAaArmspin", "charAaPitchSl", "charAaYawSl", "charAaSpeedSl", "charAaUnderground" })
            link("charFpEn", { "charFpModeSel", "charFpAxisSel", "charFpRadiusSl", "charFpSpeedSl", "charFpOxSl", "charFpOySl", "charFpOzSl", "charFpSxTog", "charFpSyTog", "charFpSzTog" })
            link("fpEn", { "fpModeSel", "fpRadiusSl", "fpSpeedSl", "fpOxSl", "fpOySl", "fpOzSl" })
            link("dsyncEn", { "dsyncModeSel", "dsyncAxisSel", "dsyncIntensitySl", "dsyncRateSl" })
        end

        library.ToggleKeybind = (library.Options or {}).MenuKeybind
        themeManager:SetLibrary(library)
        saveManager:SetLibrary(library)
        saveManager:IgnoreThemeSettings()
        saveManager:SetIgnoreIndexes({ "MenuKeybind" })
        themeManager:SetFolder("meowlua private/themes")
        saveManager:SetFolder("meowlua private/configs")
        themeManager:ApplyToTab(tabs.settings)
        saveManager:BuildConfigSection(tabs.settings)
        app.saveManagerOriginalLoadConfig = saveManager.LoadConfig

        saveManager.LoadConfig = function(self2, ...)
            local callSucceeded, err = app.saveManagerOriginalLoadConfig(self2, ...)
            task.defer(function()
                app.voidReconcile(true)
                if config.translocation then
                    app.startTranslocation()
                else
                    app.stopTranslocation()
                end
                for _, state in ipairs(featureRegistry) do
                    local handler = env[config[state[1]] and state[2] or state[3]]
                    if handler then
                        pcall(handler)
                    end
                end
                if config.meleeManipulation then
                    app.startMeleeManipulation()
                else
                    app.stopMeleeManipulation()
                end
            end)
            return callSucceeded, err
        end

        track(player.CharacterAdded:Connect(function()
            task.wait(0.3)
            if app.loadGeneration ~= app.internalMeowluaGeneration then
                return
            end
            app.destroyTeleportationConstraint()
            teleportationTargetDirty = true
            teleportationTargetCache = nil
            teleportationTargetRootPart = nil
            teleportationTargetHead = nil
            app.voidResetCharacterState()
            app.voidReconcile(true)
            if config.teleportation then
                task.wait(0.2)
                teleportationTargetDirty = true
            end
        end))

        pcall(saveManager.LoadAutoloadConfig, saveManager)
        uiReady = true
    end, function(message) return tostring(message) end)

    if app.loadGeneration == app.internalMeowluaGeneration then
        app.meowluaLoading = false
        app.meowluaLoaded = uiOk and uiReady
        if not uiOk then
            warn("[meowlua] UI initialization failed: " .. tostring(uiError))
        end
    end
end)

return true