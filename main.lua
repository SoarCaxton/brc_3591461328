local BRCMod = RegisterMod('Boss Rush Challenge', 1)
BRCMod.Version = '1.7.1'
local Blacklists = require('BRC_Blacklists')
for k,v in pairs(Blacklists) do
    BRCMod[k] = v
end
BRCMod.BOSSES = {
    [1] = {stage='stage 6', go='goto s.boss.1060',levelstage = LevelStage.STAGE3_2, name = 'Mom'},
    [2] = {stage='stage 8', go='goto s.boss.1080',levelstage = LevelStage.STAGE4_2, name = 'Mom\'s Heart'},
    [3] = {stage='stage 6c', go='goto s.boss.6030',levelstage = LevelStage.STAGE3_2, name = 'Mom (mausoleum)'},
    [4] = {stage='stage 6c', go='goto s.boss.6040',levelstage = LevelStage.STAGE3_2, name = 'Mom\'s Heart (mausoleum)'},
    [5] = {stage='stage 10a', go='goto s.boss.3380',levelstage = LevelStage.STAGE5, name = 'Isaac'},
    [6] = {stage='stage 10', go='goto s.boss.3600',levelstage = LevelStage.STAGE5, name = 'Satan'},
    [7] = {stage='stage 11a', go='goto s.boss.3390',levelstage = LevelStage.STAGE6, name = '???'},
    [8] = {stage='stage 11', go='goto s.boss.5130',levelstage = LevelStage.STAGE6, name = 'The Lamb'},
    [9] = {stage='stage 11', go='goto s.boss.5000',levelstage = LevelStage.STAGE6, name = 'Mega Satan'},
    [10] = {stage='stage 8c', go='goto x.boss.1',levelstage = LevelStage.STAGE4_2, name = 'Mother'},
    [11] = {stage='stage 11a', go='goto s.boss.1000', levelstage = LevelStage.STAGE6, name = 'Ultra Greed'},
    [12] = {stage='stage 9', go='goto x.boss.0',levelstage = LevelStage.STAGE4_3, name = 'Boss Room'},  --Hush
    [13] = {stage='stage 12', go='goto s.boss.3414',levelstage = LevelStage.STAGE7, name = 'Delirium'},
    [14] = {stage='stage 13', go=nil, levelstage = LevelStage.STAGE8, name = nil},  --Dogma&The Beast
}
BRCMod.ChallengeId = Isaac.GetChallengeIdByName('Boss Rush Challenge')
BRCMod.Challenge2Id = Isaac.GetChallengeIdByName('Boss Rush Challenge - No Q4 Items')
function BRCMod:LoadCallbacks()
    local challenge = Isaac.GetChallenge()
    if challenge ~= self.ChallengeId and challenge ~= self.Challenge2Id then return end
    if self.CallbacksLoaded then return end
    for callback, funcs in pairs(self.Callbacks) do
        for func, args in pairs(funcs) do
            self:AddCallback(callback, func, table.unpack(args))
        end
    end
    self.CallbacksLoaded = true
end
function BRCMod:UnloadCallbacks()
    if not self.CallbacksLoaded then return end
    for callback, funcs in pairs(self.Callbacks) do
        for func, args in pairs(funcs) do
            self:RemoveCallback(callback, func)
        end
    end
    self.CallbacksLoaded = false
end
function BRCMod:GetCurrentBossIndex()
    local level = Game():GetLevel()
    local stage = level:GetStage()
    local name = level:GetCurrentRoomDesc().Data.Name
    for index, boss in ipairs(self.BOSSES) do
        if boss.levelstage == stage and (not boss.name or boss.name == name) then
            return index
        end
    end
    return 0
end
function BRCMod:SpawnRandomItems()
    local room = Game():GetRoom()
    for i=1,room:GetGridSize() do
        local grid = room:GetGridEntity(i-1)
        if grid then
            local destroyed = grid:Destroy(true)
            if destroyed then
                room:RemoveGridEntity(i-1,0,false)
            end
        end
    end
    local roomCenter = room:GetCenterPos()
    local bossIndex = self:GetCurrentBossIndex()
    local x,y
    if bossIndex < 3 then
        x,y = 1, 3
    elseif bossIndex < 6 then
        x,y = 1, 1
    elseif bossIndex < 9 then
        x,y = 0, 2
    elseif bossIndex < 12 then
        x,y = 0, 1
    else
        x,y = 0, 0
    end
    for i=-x,x do
        for j=-y,y do
            local offset = 80*Vector(j, i)
            local item = Isaac.Spawn(EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_COLLECTIBLE, CollectibleType.COLLECTIBLE_NULL, roomCenter + offset, Vector.Zero, nil):ToPickup()
            item.OptionsPickupIndex = 1
        end
    end
end
function BRCMod:PostPickupInit(pickup)
    pickup.Wait = 60
end
function BRCMod:PostGameStarted(isContinued)
    local challenge = Isaac.GetChallenge()
    if challenge == self.ChallengeId or challenge == self.Challenge2Id then
        if not self.CallbacksLoaded then
            self:LoadCallbacks()
        end
        self:PostNewRoom()
    elseif self.CallbacksLoaded then
        self:UnloadCallbacks()
    end
end

function BRCMod:PreGameExit(shouldSave)
    if self.CallbacksLoaded then
        self:UnloadCallbacks()
    end
end
local lastBossIndex = 0
BRCMod.inTp = false
BRCMod.inBossFight = false
function BRCMod:PostNewRoom()
    local level = Game():GetLevel()
    level:DisableDevilRoom()
    local stage = level:GetStage()
    local roomDesc = level:GetCurrentRoomDesc()
    local room = level:GetCurrentRoom()
    if stage ~= LevelStage.STAGE8 then
        local door = roomDesc.Data.Doors
        for i=0,7 do
            if door&(1<<i)>0 then
                room:RemoveDoor(i)
            end
        end
    end
    local index = roomDesc.SafeGridIndex
    local name = roomDesc.Data.Name
    local bossIndex = self:GetCurrentBossIndex()
    if not self.inTp and not (index==level:GetStartingRoomIndex() and stage==LevelStage.STAGE1_1) and index ~= GridRooms.ROOM_DEBUG_IDX and stage ~= LevelStage.STAGE8 and name ~= 'Genesis Room' and name ~= 'Death Certificate' then
        if lastBossIndex > 0 then
            bossIndex = lastBossIndex
        else
            bossIndex = self:GetCurrentBossIndex()
        end
        bossIndex=math.max(1,bossIndex)
        local boss = self.BOSSES[bossIndex]
        if boss.go then
            local tmp_tp
            tmp_tp = function()
                if self.inCountDown then
                    self.countDown = math.huge
                end
                self.inTp = true
                if stage ~= boss.levelstage then
                    Isaac.ExecuteCommand(boss.stage)
                end
                Isaac.ExecuteCommand(boss.go)
                self.inBossFight = true
                self.inTp = false
                self:RemoveCallback(ModCallbacks.MC_POST_UPDATE, tmp_tp)
            end
            self:AddCallback(ModCallbacks.MC_POST_UPDATE, tmp_tp)
        end
        return
    end
    if name == 'Genesis Room'  then
        if self.inBossFight then
            Isaac.Spawn(EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_TAROTCARD, Card.CARD_FOOL, room:GetCenterPos(), Vector.Zero, nil)
        end
        if room:IsFirstVisit() then
            self.countDown = 3600
        end
        local light = Isaac.FindByType(EntityType.ENTITY_EFFECT, EffectVariant.HEAVEN_LIGHT_DOOR)
        for _, ml in ipairs(light) do
            ml:Remove()
        end
        for i=1,room:GetGridSize() do
            local grid = room:GetGridEntity(i-1)
            if grid and grid:GetType() == GridEntityType.GRID_TRAPDOOR then
                room:RemoveGridEntity(i-1,0,false)
            end
        end
    elseif name == 'Death Certificate' then
        local visited = false
        for i=0,168 do
            local deathRoomDesc = level:GetRoomByIdx(i)
            if deathRoomDesc.SafeGridIndex ~= index and deathRoomDesc.VisitedCount > 0 then
                visited = true
                break
            end
        end
        if not visited then
            self.countDown = 3600
        end
        return
    end
    if index == GridRooms.ROOM_DEBUG_IDX then
        lastBossIndex = self:GetCurrentBossIndex()
    end
end
BRCMod.inCountDown = false
BRCMod.countDown = 0
BRCMod.isButtonBackspaceTriggered = false
function BRCMod:CountDownToBoss()
    if self.inCountDown then return end
    self.inCountDown = true
    local current = self:GetCurrentBossIndex()
    if current == #self.BOSSES then
        self.inCountDown = false
        return
    end
    local nextBoss = self.BOSSES[current + 1]
    self.countDown = 1800
    local tmp_PostRender
    local tmp_PreGameExit
    tmp_PostRender = function()
        if self.countDown == math.huge then
            self.inCountDown = false
            BRCMod:RemoveCallback(ModCallbacks.MC_POST_RENDER,tmp_PostRender)
            BRCMod:RemoveCallback(ModCallbacks.MC_PRE_GAME_EXIT,tmp_PreGameExit)
            return
        end
        local text = tostring(math.ceil(self.countDown/60))
        local textWidth = Isaac.GetTextWidth(text)
        local textSize = 3
        local posX = Isaac.GetScreenWidth()/2
        local posY = Isaac.GetScreenHeight()/32
        Isaac.RenderScaledText(text, posX - textWidth*textSize/2, posY, textSize, textSize, 1, 1, 1, 1)
        text = 'Press Backspace to continue...'
        textWidth = Isaac.GetTextWidth(text)
        textSize = 1
        posY = posY + 30
        Isaac.RenderScaledText(text, posX - textWidth*textSize/2, posY, textSize, textSize, 1, 1, 1, 1)
        if self.isButtonBackspaceTriggered then
            self.countDown = 0
        end
        if self.countDown <= 0 then
            self.inTp = true
            Isaac.ExecuteCommand(nextBoss.stage)
            if nextBoss.go then
                Isaac.ExecuteCommand(nextBoss.go)
                self.inBossFight = true
            end
            self.inTp = false
            BRCMod:RemoveCallback(ModCallbacks.MC_POST_RENDER,tmp_PostRender)
            BRCMod:RemoveCallback(ModCallbacks.MC_PRE_GAME_EXIT,tmp_PreGameExit)
            BRCMod.inCountDown = false
        end
        if not Game():IsPaused() then
            self.countDown = self.countDown - 1
        end
    end
    tmp_PreGameExit = function()
        BRCMod:RemoveCallback(ModCallbacks.MC_POST_RENDER,tmp_PostRender)
        BRCMod:RemoveCallback(ModCallbacks.MC_PRE_GAME_EXIT,tmp_PreGameExit)
        BRCMod.inCountDown = false
    end
    BRCMod:AddCallback(ModCallbacks.MC_POST_RENDER, tmp_PostRender)
    BRCMod:AddCallback(ModCallbacks.MC_PRE_GAME_EXIT, tmp_PreGameExit)
end
BRCMod.startingItems = false
function BRCMod:SpawnStartingItems()
    local level = Game():GetLevel()
    if level:GetStage() == LevelStage.STAGE1_1 and level:GetCurrentRoom():IsFirstVisit() then
        self.inBossFight = false
        self.noQ34Items = false
        self.startingItems = true
        self:SpawnRandomItems()
        self.noQ34Items = false
        self.startingItems = false
    end
end
function BRCMod:ResumeGame(isContinued)
    self.inBossFight = not Game():GetRoom():IsClear()
end
function BRCMod:PreSpawnCleanAward(rng, spawnPos)
    if Game():GetLevel():GetStage() ~= LevelStage.STAGE8 then
        self.inBossFight = false
        self:SpawnRandomItems()
        for i=1,Game():GetNumPlayers() do
            local player = Isaac.GetPlayer(i-1)
            player:AddHearts(2)
            player:AddSoulHearts(2)
            player:DonateLuck(1)
        end
    end
    return true
end
function BRCMod:PostNPCRender(npc)
    local sprite = npc:GetSprite()
    if npc:Exists() and npc.Variant == 0 and sprite:GetAnimation() == 'Death' and sprite:GetFrame() >= 60 then
        npc:Remove()
        local trophy = Isaac.Spawn(EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_TROPHY, 0, Game():GetRoom():GetCenterPos(), Vector.Zero, npc)
        trophy:GetSprite():Play('Appear', true)
    end
end
function BRCMod:PostRender()
    local game = Game()
    self.isButtonBackspaceTriggered = false
    if not Game():IsPaused() then
        for i=1,game:GetNumPlayers() do
            if Input.IsButtonPressed(Keyboard.KEY_BACKSPACE, Isaac.GetPlayer(i-1).ControllerIndex) then
                self.isButtonBackspaceTriggered = true
                break
            end
        end
    end
    if not game:GetRoom():IsClear() then
        if not self.inBossFight then
            self.inBossFight = true
            self:PostNewRoom()
        end
    end
    if self.inCountDown or self.inBossFight then return end
    local stage = game:GetLevel():GetStage()
    if stage == LevelStage.STAGE1_1 then
        local text = 'Press Backspace to start.'
        local textWidth = Isaac.GetTextWidth(text)
        local textSize = 1
        local posX = Isaac.GetScreenWidth()/2
        local posY = Isaac.GetScreenHeight()/32
        Isaac.RenderScaledText(text, posX - textWidth*textSize/2, posY, textSize, textSize, 1, 1, 1, 1)
    end
    if stage ~= LevelStage.STAGE1_1 and stage ~= LevelStage.STAGE8 or self.isButtonBackspaceTriggered then
        self:CountDownToBoss()
    end
end
function BRCMod:RenderVersion()
    local text = 'BRC v'..self.Version
    local textWidth = Isaac.GetTextWidth(text)
    local textSize = 0.7
    local posX = Isaac.GetScreenWidth()/2
    local posY = Isaac.GetScreenHeight() - 15
    local r,g,b
    local challenge = Isaac.GetChallenge()
    if challenge == self.ChallengeId then
        r,g,b = 0,1,1
    elseif challenge == self.Challenge2Id then
        r,g,b = 1,0,0
    else
        return
    end
    Isaac.RenderScaledText(text, posX - textWidth*textSize/2, posY, textSize, textSize, r, g, b, 1)
end
function BRCMod:PostUpdate()
    local game = Game()
    local room = game:GetRoom()
    local level = game:GetLevel()
    local roomDesc = level:GetCurrentRoomDesc()
    local name = roomDesc.Data.Name
    if level:GetStage() == LevelStage.STAGE8 or name == 'Death Certificate' or self.inBossFight then return end
    local teleporter
    local firstFreeGridIndex = room:GetGridSize()
    local lastFreeGridIndex = -1
    for i=1,room:GetGridSize() do
        local grid = room:GetGridEntity(i-1)
        if grid then
            local type = grid:GetType()
            if type == GridEntityType.GRID_TELEPORTER then
                teleporter = grid
            elseif type == GridEntityType.GRID_STAIRS then
                room:RemoveGridEntity(i-1,0,false)
            end
        else
            firstFreeGridIndex = math.min(firstFreeGridIndex, i-1)
            lastFreeGridIndex = math.max(lastFreeGridIndex, i-1)
        end
    end
    if teleporter then
        if teleporter.State ~= 0 then
            self:CountDownToBoss()
            self.countDown = 0
        end
    else
        local firstFreePos = room:GetGridPosition(firstFreeGridIndex)
        local lastFreePos = room:GetGridPosition(lastFreeGridIndex)
        local selectFirst = true
        for i=1,game:GetNumPlayers() do
            local player = Isaac.GetPlayer(i-1)
            if (player.Position+player.PositionOffset):Distance(firstFreePos) <= 120 then
                selectFirst = false
                break
            end
        end
        local selectedPosition = selectFirst and firstFreePos or lastFreePos
        Isaac.GridSpawn(GridEntityType.GRID_TELEPORTER,0,selectedPosition,true).State=0
    end
end
function BRCMod:BlockQ4Items()
    local itemConfig = Isaac.GetItemConfig()
    local maxCollectibleIndex = itemConfig:GetCollectibles().Size-1
    local game = Game()
    local itemPool = game:GetItemPool()
    local challenge = Isaac.GetChallenge()
    local shouldBlock = false
    if challenge == self.ChallengeId then
        shouldBlock = false
    elseif challenge == self.Challenge2Id then
        shouldBlock = true
    else
        return
    end
    local q4ItemsNum = 0
    for i=1,game:GetNumPlayers() do
        if shouldBlock then
            break
        end
        local player = Isaac.GetPlayer(i-1)
        for j=1,maxCollectibleIndex do
            local collectible = itemConfig:GetCollectible(j)
            if collectible and player:HasCollectible(j,true) and collectible.Quality>=4 then
                q4ItemsNum = q4ItemsNum + 1
            end
            if q4ItemsNum >= 2 then
                shouldBlock = true
                break
            end
        end
    end
    if shouldBlock then
        for i=1,maxCollectibleIndex do
            local collectible = itemConfig:GetCollectible(i)
            if collectible and collectible.Quality>=4 then
                itemPool:AddRoomBlacklist(i)
            end
        end
    end
    return shouldBlock
end
function BRCMod:IsBlacklistedItem(collectible)
    for k,v in pairs(self.ItemBlacklist) do
        if v == collectible then
            return true
        end
    end
    return false
end
function BRCMod:PreGetCollectible(itemPoolType, decrease, seed)
    if self.startingItems then
        local itemConfig = Isaac.GetItemConfig()
        local maxCollectibleIndex = itemConfig:GetCollectibles().Size-1
        local itemPool = Game():GetItemPool()
        for i=1,maxCollectibleIndex do
            local collectible = itemConfig:GetCollectible(i)
            if collectible and collectible.Quality<self.startingItemsQualityThreshold then
                itemPool:AddRoomBlacklist(i)
            end
        end
    end
    self:BlockQ4Items()
end
BRCMod.startingItemsQualityThreshold = 3
function BRCMod:PostGetCollectible(selectedCollectible, itemPoolType, decrease, seed)
    local itemPool = Game():GetItemPool()
    if decrease then
        itemPool:RemoveCollectible(selectedCollectible)
    end
    local itemConfig = Isaac.GetItemConfig()
    local collectible = itemConfig:GetCollectible(selectedCollectible)
    if self.startingItems and collectible.Quality<self.startingItemsQualityThreshold then
        self.startingItemsQualityThreshold = self.startingItemsQualityThreshold - 1
        itemPool:ResetRoomBlacklist()
        return itemPool:GetCollectible(itemPoolType, decrease, seed)
    end
    self.startingItemsQualityThreshold = 3
    itemPool:ResetRoomBlacklist()
    if self:IsBlacklistedItem(selectedCollectible) then
        return itemPool:GetCollectible(itemPoolType, decrease, seed)
    end
end
function BRCMod:IsBlacklistedCard(card)
    for k,v in pairs(self.CardBlacklist) do
        if v == card then
            return true
        end
    end
    return false
end
function BRCMod:GetCard(rng, card, includePlayingCards, includeRunes, OnlyRunes)
    if self:IsBlacklistedCard(card) then
        return Game():GetItemPool():GetCard(rng:Next(), includePlayingCards, includeRunes, OnlyRunes)
    end
end
function BRCMod:PostPickupSelection(entityPickup, variant, subType)
    if variant == PickupVariant.PICKUP_TAROTCARD and Isaac.GetItemConfig():GetCard(subType):IsRune() and self:IsBlacklistedCard(subType) then
        local rng = Isaac.GetPlayer():GetCardRNG(subType)
        local newSubType = Game():GetItemPool():GetCard(rng:Next(), true, true, true)
        return {variant, newSubType}
    end
end
function BRCMod:IsBlacklistedPill(pill)
    for k,v in pairs(self.PillBlacklist) do
        if v == pill then
            return true
        end
    end
    return false
end
BRCMod.InGetPillColor = false
function BRCMod:GetPillColor(seed)
    if self.InGetPillColor then return end
    local itemPool = Game():GetItemPool()
    self.InGetPillColor = true
    local pillColor = itemPool:GetPill(seed)
    self.InGetPillColor = false
    local pillEffect = itemPool:GetPillEffect(pillColor)
    if self:IsBlacklistedPill(pillEffect) then
        local pillRNG = Isaac.GetPlayer():GetPillRNG(PillEffect.PILLEFFECT_NULL)
        return itemPool:GetPill(pillRNG:Next())
    end
end
function BRCMod:IsBlackListedTrinket(trinket)
    for k,v in pairs(self.TrinketBlacklist) do
        if v == trinket then
            return true
        end
    end
    return false
end
function BRCMod:GetTrinket(selectedTrinket, rng)
    if self:IsBlackListedTrinket(selectedTrinket) then
        local newTrinket = Game():GetItemPool():GetTrinket(false)
        return newTrinket
    end
end

BRCMod.CallbacksLoaded = false
BRCMod.Callbacks = {
    [ModCallbacks.MC_POST_GAME_STARTED] = {[BRCMod.ResumeGame]={}},
    [ModCallbacks.MC_POST_NEW_ROOM] = {[BRCMod.PostNewRoom]={}, [BRCMod.SpawnStartingItems]={}},
    [ModCallbacks.MC_PRE_SPAWN_CLEAN_AWARD] = {[BRCMod.PreSpawnCleanAward]={}},
    [ModCallbacks.MC_POST_PICKUP_INIT] = {[BRCMod.PostPickupInit]={PickupVariant.PICKUP_COLLECTIBLE}},
    [ModCallbacks.MC_POST_NPC_RENDER] = {[BRCMod.PostNPCRender]={EntityType.ENTITY_BEAST}},
    [ModCallbacks.MC_POST_RENDER] = {[BRCMod.PostRender]={}, [BRCMod.RenderVersion]={}},
    [ModCallbacks.MC_POST_UPDATE] = {[BRCMod.PostUpdate]={}},
    [ModCallbacks.MC_PRE_GET_COLLECTIBLE] = {[BRCMod.PreGetCollectible]={}},
    [ModCallbacks.MC_POST_GET_COLLECTIBLE] = {[BRCMod.PostGetCollectible]={}},
    [ModCallbacks.MC_GET_CARD] = {[BRCMod.GetCard]={}},
    [ModCallbacks.MC_POST_PICKUP_SELECTION] = {[BRCMod.PostPickupSelection]={}},
    [ModCallbacks.MC_GET_PILL_COLOR] = {[BRCMod.GetPillColor]={}},
    [ModCallbacks.MC_GET_TRINKET] = {[BRCMod.GetTrinket]={}}
}
BRCMod:AddCallback(ModCallbacks.MC_POST_GAME_STARTED, BRCMod.PostGameStarted)
for callback,funcs in pairs(BRCMod.Callbacks) do
    BRCMod:AddCallback(callback, BRCMod.LoadCallbacks)
end
BRCMod:AddCallback(ModCallbacks.MC_PRE_GAME_EXIT, BRCMod.PreGameExit)

BRC = {}
setmetatable(BRC, {
    __index = function(t,k)return BRCMod[k] end,
    __newindex = function()end,
    __tostring = function()return 'BRC - Boss Rush Challenge v'..BRCMod.Version..' - Keye3Tuido\n' end,
    __metatable = false
})

Isaac.ConsoleOutput(tostring(BRC))