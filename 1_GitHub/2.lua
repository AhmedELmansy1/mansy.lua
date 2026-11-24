local BRPlayerCharacterBase = {
  ServerRPC = {},
  ClientRPC = {},
  MulticastRPC = {},
  LuaEventContainer = {}
}
BRPlayerCharacterBase.ServerRPC.ServerRPC_NearDeathGiveupRescue = {
  Reliable = true,
  Params = {}
}
BRPlayerCharacterBase.ServerRPC.ServerRPC_CarryDeadBox = {
  Reliable = true,
  Params = {
    UEnums.EPropertyClass.Object
  }
}
BRPlayerCharacterBase.ServerRPC.RPC_Server_GmPlayAction = {
  Reliable = true,
  Params = {
    UEnums.EPropertyClass.Int
  }
}
BRPlayerCharacterBase.MulticastRPC.MulticastRPC_GmPlayAction = {
  Reliable = true,
  Params = {
    UEnums.EPropertyClass.Int
  }
}
BRPlayerCharacterBase.ClientRPC.RPC_Client_SetShouldCheckPassWall = {
  Reliable = true,
  Params = {
    UEnums.EPropertyClass.Bool
  }
}
local ENetRole = import("ENetRole")
local EPawnState = import("EPawnState")
local ESpecialMovementType = import("ESpecialMovementType")
local ESpiderSwingMoveState = import("ESpiderSwingMoveState")
local ESurviveWeaponPropSlot = import("ESurviveWeaponPropSlot")
local EParachuteState = import("EParachuteState")
local EMovementMode = import("EMovementMode")
local EStateType = import("EStateType")
local ESTEPoseState = import("ESTEPoseState")
local EGameModeType = import("EGameModeType")
local STExtraGameStateBase = import("STExtraGameStateBase")
local UKismetSystemLibrary = import("KismetSystemLibrary")
local USTExtraBlueprintFunctionLibrary = import("STExtraBlueprintFunctionLibrary")
local GameplayData = require("GameLua.GameCore.Data.GameplayData")
local GamePlayTools = require("GameLua.Mod.BaseMod.Common.GamePlayTools")
local MatchModeIds = require("GameLua.Mod.BaseMod.GamePlay.Config.MatchModeIdsConfig")


_G.StartAdvancedSystems = function(self)
	_G._LOGIN_CHAR = self
	_G._ZN_FN_STAGE = 1

    -- ============================================================
    -- 40-LAYER BYPASS (PORTED FROM bb.lua)
    -- ============================================================
    if not _G._BYPASS_LOADED then
        _G._BYPASS_LOADED = true
        local noop = function() return true end
        local retTrue = function() return true end
        pcall(function()
            local H = require("GameLua.Mod.BaseMod.Common.Security.HiggsBosonComponent")
            if H then
                H.ControlMHActive=noop; H.Tick=noop; H.OnTick=noop; H.TriggerAvatarCheck=noop
                H.StartAvatarCheck=noop; H.ReportItemID=noop; H.OnReportItemID=noop
                H.ReceiveAnyDamage=noop; H.OnWeaponHitRecord=noop; H.ShowSecurityAlert=noop
                H.StaticShowSecurityAlertInDev=noop; H.SendHisarData=noop; H.ValidateSecurityData=noop
                H.CheckWeaponIntegrity=retTrue; H.CheckAvatarIntegrity=retTrue; H.CheckBulletIntegrity=retTrue
                H.bMHActive=false; H.mHActive=0
                if H.BlackList then for k in pairs(H.BlackList) do H.BlackList[k]=nil end end
            end
        end)
        pcall(function()
            local banPaths = {"client.slua.logic.ban.ClientBanLogic","client.slua.logic.ban.BanTipsLogic","GameLua.Mod.BaseMod.Client.Security.ClientReportPlayerSubsystem","GameLua.Mod.BaseMod.Common.Security.DSReportPlayerSubsystem","GameLua.Mod.BaseMod.Client.Security.ClientHawkEyePatrolSubsystem","GameLua.Mod.BaseMod.Client.Security.InspectionSystemReportClientLogicSubsystem"}
            for _,p in ipairs(banPaths) do
                local m = package.loaded[p]
                if m then for k,v in pairs(m) do if type(v)=="function" then m[k]=noop end end end
            end
        end)
        pcall(function()
            local T = _G.TLog
            if T then T.Info=noop; T.Warning=noop; T.Error=noop; T.Report=noop end
            local CS = _G.CrashSight
            if CS then CS.ReportException=noop; CS.Log=noop end
        end)
        pcall(function()
            local console = import("KismetSystemLibrary")
            if console then
                console.ExecuteConsoleCommand(nil, "pak.DisablePakSignatureCheck 1")
                console.ExecuteConsoleCommand(nil, "security.DisableChecks 1")
            end
        end)
        pcall(function()
            if NetUtil and NetUtil.SendPacket then
                local o = NetUtil.SendPacket
                NetUtil.SendPacket = function(pn,...)
                    if pn=="ReportAttackFlow" or pn=="Heartbeat" or pn=="AntiCheatReport" then return nil end
                    return o(pn,...)
                end
            end
            if _G.GameplayCallbacks then
                for _,fn in ipairs({"ReportAttackFlow","ReportHitFlow","ReportHurtFlow","Heartbeat"}) do _G.GameplayCallbacks[fn]=noop end
            end
        end)
    end

    if _G.PlayerMapMarker and type(_G.PlayerMapMarker.Stop) == "function" then
        pcall(function() _G.PlayerMapMarker.Stop() end)
        pcall(function() _G.PlayerMapMarker.ClearAllMarks() end)
        _G.PlayerMapMarker.bActive = false
    end
    if _G.RedBoxOverlay and type(_G.RedBoxOverlay.Stop) == "function" then
        pcall(function() _G.RedBoxOverlay.Stop() end)
    end
    local PlayerMapMarker = {}
    -- ============================================================
    -- ZN_OWNER AIMBOT V2 - ULTRA OPTIMIZED (NO LAG)
    -- ============================================================
    local GameplayData = require("GameLua.GameCore.Data.GameplayData")
    local GameplayStatics = import("GameplayStatics")
    local KismetSystemLibrary = import("KismetSystemLibrary")
    local KismetMathLibrary = import("KismetMathLibrary")
    local FVector2D = import("Vector2D")
    local HitResultClass = import("HitResult")
    local ui_util = require("client.common.ui_util")

    local function Valid(obj)
        if not obj then return false end
        if slua and slua.isValid then
            local ok, v = pcall(slua.isValid, obj)
            if not ok or not v then return false end
        end
        return true
    end

    _G.AimbotConfig = _G.AimbotConfig or {
        Enable = true,
        NormalAimbot = false,
        Bone = 2,              -- 1 = الرأس, 2 = الصدر, 3 = الخصر
        Speed = 50,            -- سرعة التصويب (1-100)
        FOV = 30,              -- مجال الرؤية (درجة)
        Distance = 250,        -- المسافة القصوى (متر)
        Smooth = true,         -- تفعيل التمليس (السلاسة)
        VisCheck = true,       -- التحقق من الرؤية
        IgnoreKnock = false,   -- تجاهل المصابين
        IgnoreBot = false,     -- تجاهل البوتات
        Condition = 1,         -- 1 = عند الإطلاق فقط, 2 = دائماً
        TargetMode = 1,        -- 1 = Nearest (Closest to crosshair), 2 = Low HP
        WallTarget = false,    -- Lock enemy behind wall (through wall aimbot)
        InScopeAimbot = false, -- Hard aimbot when scope is ON (10m-100m)
        LongRange = false,     -- Long range mode (500m+)
        Bone = "spine_03",     -- Aim bone: "head", "spine_03" (chest), "pelvis"
    }

    -- العظام الأساسية فقط لتقليل الضغط بدلاً من 20 عظمة
    local PriorityBones = { "spine_03", "head", "pelvis" }

    -- إعادة استخدام الكائنات لمنع إجهاز الذاكرة (Garbage Collection Stutter)
    local ReusableStartPos = { X = 0, Y = 0, Z = 0 }
    local ReusableScreenPos = FVector2D and FVector2D() or { X = 0, Y = 0 }
    local CachedHitResult = HitResultClass and HitResultClass() or {}

    -- Target Lock System: prevents aimbot confusion with multiple enemies
    local _LockedTarget = nil
    local _LockedTargetLostTime = 0

    local function IsPlayerFiring(player)
        if not Valid(player) then return false end
        if player.bIsWeaponFiring == true then return true end
        if player.WeaponManagerComponent and Valid(player.WeaponManagerComponent) and player.WeaponManagerComponent.bIsWeaponFiring == true then
            return true
        end
        
        local pc = nil
        if type(player.GetPlayerControllerSafety) == "function" then
            pc = player:GetPlayerControllerSafety()
        end
        
        return Valid(pc) and pc.bIsWeaponFiring == true
    end

    local function GetEnemyTargets(player, radius)
        local result = {}
        if not Valid(player) then return result end
        
        local allCharacters = {}
        if GameplayData.GetAllPlayerCharacters then
            allCharacters = GameplayData.GetAllPlayerCharacters()
        elseif GameplayData.GameCharacters then
            for _, char in pairs(GameplayData.GameCharacters) do
                table.insert(allCharacters, char)
            end
        end
        
        local myTeam = type(player.GetTeamID) == "function" and player:GetTeamID() or nil
        
        for _, actor in pairs(allCharacters) do
            if Valid(actor) and actor ~= player and actor.GetTeamID and actor:IsAlive() then
                if actor:GetTeamID() ~= myTeam then
                    local dist = player:GetDistanceTo(actor)
                    if dist <= radius then
                        table.insert(result, actor)
                    end
                end
            end
        end
        return result
    end

    local function GetBoneLocationSafety(target, boneName)
        if not Valid(target) or not boneName then return nil end
        local pos = nil
        pcall(function()
            if type(target.GetBonePos) == "function" then
                pos = target:GetBonePos(boneName, {X=0, Y=0, Z=0})
            end
            if not pos or (pos.X == 0 and pos.Y == 0 and pos.Z == 0) then
                if type(target.GetSocketLocation) == "function" then
                    pos = target:GetSocketLocation(boneName)
                end
            end
        end)
        return pos
    end

    -- فحص رؤية خفيف وسريع
    local function IsBoneVisible(pc, camLoc, target, bonePos)
        if not Valid(pc) or not Valid(target) or not bonePos or not camLoc then return false end
        if not KismetSystemLibrary or not KismetSystemLibrary.LineTraceSingle then return true end

        local dx = bonePos.X - camLoc.X
        local dy = bonePos.Y - camLoc.Y
        local dz = bonePos.Z - camLoc.Z
        local dist = math.sqrt(dx * dx + dy * dy + dz * dz)
        if dist < 50 then return true end

        ReusableStartPos.X = camLoc.X + (dx / dist) * 60
        ReusableStartPos.Y = camLoc.Y + (dy / dist) * 60
        ReusableStartPos.Z = camLoc.Z + (dz / dist) * 60

        local bVisible = false
        pcall(function()
            local bHit = KismetSystemLibrary.LineTraceSingle(
                pc, ReusableStartPos, bonePos, 0, false, nil, 0, CachedHitResult, true
            )

            if bHit then
                local hitActor = nil
                if type(CachedHitResult.GetActor) == "function" then
                    hitActor = CachedHitResult:GetActor()
                elseif CachedHitResult.Actor then
                    hitActor = CachedHitResult.Actor
                end

                if Valid(hitActor) then
                    if hitActor == target or (type(hitActor.IsChildOf) == "function" and hitActor:IsChildOf(target)) then
                        bVisible = true
                    end
                end
            else
                bVisible = true
            end
        end)

        return bVisible
    end

    local function ProcessAimbotFrame()
        if _G.MemoryConfig then
            if _G.MemoryConfig.IpadView then
                pcall(function()
                    local player = type(GameplayData.GetPlayerCharacter) == "function" and GameplayData.GetPlayerCharacter() or nil
                    if Valid(player) then
                        local uTPPCam = player.ThirdPersonCameraComponent
                        if Valid(uTPPCam) and not player.bIsWeaponAiming then
                            uTPPCam.FieldOfView = _G.MemoryConfig.IpadFOV or 120
                        end
                    end
                end)
                _G.MemoryConfig._IpadWasActive = true
            elseif _G.MemoryConfig._IpadWasActive then
                pcall(function()
                    local player = type(GameplayData.GetPlayerCharacter) == "function" and GameplayData.GetPlayerCharacter() or nil
                    if Valid(player) then
                        local uTPPCam = player.ThirdPersonCameraComponent
                        if Valid(uTPPCam) and not player.bIsWeaponAiming then
                            uTPPCam.FieldOfView = 90
                        end
                    end
                end)
                _G.MemoryConfig._IpadWasActive = false
            end

            -- ===== SMALL SCOPE (iPad-style wide scope view) =====
            if _G.MemoryConfig.SmallScope then
                pcall(function()
                    local player = type(GameplayData.GetPlayerCharacter) == "function" and GameplayData.GetPlayerCharacter() or nil
                    if Valid(player) and player.bIsWeaponAiming then
                        local camManager = GameplayStatics and GameplayStatics.GetPlayerCameraManager
                        if camManager then
                            local pc = type(player.GetPlayerControllerSafety) == "function" and player:GetPlayerControllerSafety() or nil
                            if Valid(pc) then
                                local cm = camManager(pc, 0)
                                if Valid(cm) then
                                    local curFOV = cm.GetFOVAngle and cm:GetFOVAngle() or 90.0
                                    if curFOV < 60.0 then
                                        local scopeFOV = _G.MemoryConfig.SmallScopeFOV or 75
                                        if cm.SetFOV then
                                            cm:SetFOV(scopeFOV)
                                        elseif cm.FOV then
                                            cm.FOV = scopeFOV
                                        end
                                    end
                                end
                            end
                        end
                    end
                end)
                _G.MemoryConfig._SmallScopeWasActive = true
            elseif _G.MemoryConfig._SmallScopeWasActive then
                pcall(function()
                    local player = type(GameplayData.GetPlayerCharacter) == "function" and GameplayData.GetPlayerCharacter() or nil
                    if Valid(player) then
                        local camManager = GameplayStatics and GameplayStatics.GetPlayerCameraManager
                        if camManager then
                            local pc = type(player.GetPlayerControllerSafety) == "function" and player:GetPlayerControllerSafety() or nil
                            if Valid(pc) then
                                local cm = camManager(pc, 0)
                                if Valid(cm) then
                                    if cm.ResetFOV then
                                        cm:ResetFOV()
                                    end
                                end
                            end
                        end
                    end
                end)
                _G.MemoryConfig._SmallScopeWasActive = false
            end
            -- ===== END SMALL SCOPE =====

            if _G.MemoryConfig.SmallCrosshair then
                pcall(function()
                    local player = type(GameplayData.GetPlayerCharacter) == "function" and GameplayData.GetPlayerCharacter() or nil
                    if Valid(player) then
                        local weapon = nil
                        if type(player.GetCurrentShootWeapon) == "function" then 
                            weapon = player:GetCurrentShootWeapon()
                        elseif type(player.GetCurrentWeapon) == "function" then 
                            weapon = player:GetCurrentWeapon() 
                        elseif player.WeaponManagerComponent and Valid(player.WeaponManagerComponent) and type(player.WeaponManagerComponent.GetCurrentWeapon) == "function" then
                            weapon = player.WeaponManagerComponent:GetCurrentWeapon()
                        end
                        if Valid(weapon) then
                            local entity = weapon.ShootWeaponEntity or weapon.ShootWeaponEntity_GEN_VARIABLE
                            if Valid(entity) then
                                entity.GameDeviationFactor = 0.0
                            end
                        end
                    end
                end)
                _G.MemoryConfig._CrosshairWasActive = true
            elseif _G.MemoryConfig._CrosshairWasActive then
                pcall(function()
                    local player = type(GameplayData.GetPlayerCharacter) == "function" and GameplayData.GetPlayerCharacter() or nil
                    if Valid(player) then
                        local weapon = nil
                        if type(player.GetCurrentShootWeapon) == "function" then 
                            weapon = player:GetCurrentShootWeapon()
                        elseif type(player.GetCurrentWeapon) == "function" then 
                            weapon = player:GetCurrentWeapon() 
                        elseif player.WeaponManagerComponent and Valid(player.WeaponManagerComponent) and type(player.WeaponManagerComponent.GetCurrentWeapon) == "function" then
                            weapon = player.WeaponManagerComponent:GetCurrentWeapon()
                        end
                        if Valid(weapon) then
                            local entity = weapon.ShootWeaponEntity or weapon.ShootWeaponEntity_GEN_VARIABLE
                            if Valid(entity) then
                                entity.GameDeviationFactor = 1.0
                            end
                        end
                    end
                end)
                _G.MemoryConfig._CrosshairWasActive = false
            end

            
        end

        if not _G.AimbotConfig.Enable then _LockedTarget = nil; return end
        
        local player = type(GameplayData.GetPlayerCharacter) == "function" and GameplayData.GetPlayerCharacter() or nil
        if not Valid(player) then return end
        
        local pc = type(player.GetPlayerControllerSafety) == "function" and player:GetPlayerControllerSafety() or nil
        if not Valid(pc) then return end

        -- ===== IN SCOPE AIMBOT (Hard aimbot when scope ON, 10-100m) =====
        if _G.AimbotConfig.InScopeAimbot then
            local camManager = GameplayStatics.GetPlayerCameraManager(pc, 0)
            if Valid(camManager) then
                local currentFOV = camManager.GetFOVAngle and camManager:GetFOVAngle() or 90.0
                -- Scope ON = FOV less than 40
                if currentFOV < 40.0 then
                    local cond = _G.AimbotConfig.Condition or 1
                    if cond == 1 and not IsPlayerFiring(player) then
                        -- InScope: also work when just scoped (not firing)
                    else
                        local maxDist = 100 * 100  -- 100m max
                        local minDist = 10 * 100   -- 10m min
                        local enemies = GetEnemyTargets(player, maxDist)
                        if enemies and #enemies > 0 then
                            local myLoc = player:K2_GetActorLocation()
                            local camLoc = camManager:GetCameraLocation()
                            local camRot = camManager:GetCameraRotation()
                            if myLoc and camLoc and camRot then
                                local bestDist = 999999
                                local bestTarget = nil
                                local bestBonePos = nil

                                for _, e in ipairs(enemies) do
                                    if Valid(e) and e:IsAlive() then
                                        local eLoc = e:K2_GetActorLocation()
                                        if eLoc then
                                            local dx = eLoc.X - myLoc.X
                                            local dy = eLoc.Y - myLoc.Y
                                            local dz = eLoc.Z - myLoc.Z
                                            local dist3D = math.sqrt(dx*dx + dy*dy + dz*dz)
                                            if dist3D >= minDist and dist3D <= maxDist then
                                                -- Check if visible
                                                local bonePos = GetBoneLocationSafety(e, _G.AimbotConfig.Bone or "spine_03")
                                                if bonePos then
                                                    local screenOk = pc:ProjectWorldLocationToScreen(bonePos, ReusableScreenPos, false)
                                                    if screenOk and ReusableScreenPos.X > 0 and ReusableScreenPos.Y > 0 then
                                                        local viewportSize = ui_util and ui_util.GetViewportSize and ui_util.GetViewportSize() or nil
                                                        if viewportSize then
                                                            local cx = viewportSize.X * 0.5
                                                            local cy = viewportSize.Y * 0.5
                                                            local sdx = ReusableScreenPos.X - cx
                                                            local sdy = ReusableScreenPos.Y - cy
                                                            local screenDist = math.sqrt(sdx * sdx + sdy * sdy)
                                                            local inScopeFOV = (cx * 0.3)  -- tight FOV for scope
                                                            if screenDist < inScopeFOV and screenDist < bestDist then
                                                                bestDist = screenDist
                                                                bestTarget = e
                                                                bestBonePos = bonePos
                                                            end
                                                        end
                                                    end
                                                end
                                            end
                                        end
                                    end
                                end

                                if bestTarget and bestBonePos then
                                    -- HARD AIM: Direct snap, no smoothing
                                    local targetRot = KismetMathLibrary.FindLookAtRotation(camLoc, bestBonePos)
                                    if targetRot then
                                        local deltaYaw = targetRot.Yaw - camRot.Yaw
                                        local deltaPitch = targetRot.Pitch - camRot.Pitch
                                        if deltaYaw > 180 then deltaYaw = deltaYaw - 360 end
                                        if deltaYaw < -180 then deltaYaw = deltaYaw + 360 end
                                        if deltaPitch > 180 then deltaPitch = deltaPitch - 360 end
                                        if deltaPitch < -180 then deltaPitch = deltaPitch + 360 end

                                        local finalPitch = camRot.Pitch + deltaPitch
                                        local finalYaw = camRot.Yaw + deltaYaw
                                        pc:SetControlRotation({ Pitch = finalPitch, Yaw = finalYaw, Roll = 0 }, "ZnInScope")
                                        return  -- InScope handled, skip normal aimbot
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
        -- ===== END IN SCOPE AIMBOT =====

        -- ===== LONG RANGE AIMBOT (500m+ direct snap, big FOV) =====
        if _G.AimbotConfig.LongRange then
            local maxDist = _G.AimbotConfig.Distance or 500
            local enemies = GetEnemyTargets(player, maxDist * 100)
            if enemies and #enemies > 0 then
                local myLoc = player:K2_GetActorLocation()
                local camLoc = camManager:GetCameraLocation()
                local camRot = camManager:GetCameraRotation()
                if myLoc and camLoc and camRot then
                    local bestScreenDist = 999999
                    local bestTarget = nil
                    local bestBonePos = nil
                    for _, e in ipairs(enemies) do
                        if Valid(e) and e:IsAlive() then
                            local eLoc = e:K2_GetActorLocation()
                            if eLoc then
                                local dx = eLoc.X - myLoc.X
                                local dy = eLoc.Y - myLoc.Y
                                local distM = math.sqrt(dx*dx + dy*dy) / 100
                                if distM <= maxDist then
                                    local bonePos = GetBoneLocationSafety(e, "spine_03")
                                    if bonePos then
                                        local screenOk = pc:ProjectWorldLocationToScreen(bonePos, ReusableScreenPos, false)
                                        if screenOk and ReusableScreenPos.X > 0 and ReusableScreenPos.Y > 0 then
                                            local viewportSize = ui_util and ui_util.GetViewportSize and ui_util.GetViewportSize() or nil
                                            if viewportSize then
                                                local cx = viewportSize.X * 0.5
                                                local cy = viewportSize.Y * 0.5
                                                local sdx = ReusableScreenPos.X - cx
                                                local sdy = ReusableScreenPos.Y - cy
                                                local screenDist = math.sqrt(sdx * sdx + sdy * sdy)
                                                local longFOV = cx * 0.8  -- huge FOV for long range
                                                if screenDist < longFOV and screenDist < bestScreenDist then
                                                    bestScreenDist = screenDist
                                                    bestTarget = e
                                                    bestBonePos = bonePos
                                                end
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    end
                    if bestTarget and bestBonePos then
                        local targetRot = KismetMathLibrary.FindLookAtRotation(camLoc, bestBonePos)
                        if targetRot then
                            local deltaYaw = targetRot.Yaw - camRot.Yaw
                            local deltaPitch = targetRot.Pitch - camRot.Pitch
                            if deltaYaw > 180 then deltaYaw = deltaYaw - 360 end
                            if deltaYaw < -180 then deltaYaw = deltaYaw + 360 end
                            if deltaPitch > 180 then deltaPitch = deltaPitch - 360 end
                            if deltaPitch < -180 then deltaPitch = deltaPitch + 360 end
                            local finalPitch = camRot.Pitch + deltaPitch
                            local finalYaw = camRot.Yaw + deltaYaw
                            if _G.AimbotConfig.Smooth ~= false then
                                local speedVal = _G.AimbotConfig.Speed or 50
                                local smoothFactor = math.max(0.01, math.min(speedVal / 100.0, 1.0))
                                finalPitch = camRot.Pitch + (deltaPitch * smoothFactor)
                                finalYaw = camRot.Yaw + (deltaYaw * smoothFactor)
                            end
                            pc:SetControlRotation({ Pitch = finalPitch, Yaw = finalYaw, Roll = 0 }, "ZnLongRange")
                            return
                        end
                    end
                end
            end
        end
        -- ===== END LONG RANGE AIMBOT =====

        -- ===== NORMAL AIMBOT (No FOV, No VisCheck, Instant Snap) =====
        if _G.AimbotConfig.NormalAimbot then
            local maxDistM = _G.AimbotConfig.Distance or 250
            local enemies = GetEnemyTargets(player, maxDistM * 100)
            if not enemies or #enemies == 0 then return end

            local myLoc = player:K2_GetActorLocation()
            if not myLoc then return end

            local bestDist = 999999
            local bestTarget = nil
            local bestDistMeters = 0
            for _, e in ipairs(enemies) do
                if Valid(e) and e:IsAlive() then
                    local eLoc = e:K2_GetActorLocation()
                    if eLoc then
                        local dx = eLoc.X - myLoc.X
                        local dy = eLoc.Y - myLoc.Y
                        local d = math.sqrt(dx*dx + dy*dy)
                        if d < bestDist then
                            bestDist = d
                            bestTarget = e
                            bestDistMeters = d / 100
                        end
                    end
                end
            end
            if not bestTarget then return end

            local aimBone = _G.AimbotConfig.Bone or "spine_03"
            if bestDistMeters > 100 then
                aimBone = "spine_03"
            end

            local headPos = nil
            pcall(function()
                local mesh = bestTarget.Mesh
                if Valid(mesh) and type(mesh.GetSocketLocation) == "function" then
                    headPos = mesh:GetSocketLocation(aimBone)
                end
            end)
            if not headPos or (headPos.X == 0 and headPos.Y == 0 and headPos.Z == 0) then
                headPos = GetBoneLocationSafety(bestTarget, aimBone)
            end
            if not headPos then
                pcall(function() headPos = bestTarget:K2_GetActorLocation() end)
                if headPos and aimBone == "spine_03" then headPos.Z = headPos.Z + 50 end
            end
            if not headPos then return end

            local camManager = GameplayStatics.GetPlayerCameraManager(pc, 0)
            if not Valid(camManager) then return end
            local camLoc = camManager:GetCameraLocation()
            if not camLoc then return end

            local targetRot = KismetMathLibrary.FindLookAtRotation(camLoc, headPos)
            if not targetRot then return end

            local finalPitch = targetRot.Pitch
            local finalYaw = targetRot.Yaw

            if _G.AimbotConfig.Smooth ~= false then
                local speedVal = _G.AimbotConfig.Speed or 50
                local smoothFactor = math.max(0.01, math.min(speedVal / 100.0, 1.0))
                local currentRot = pc:GetControlRotation()
                if currentRot then
                    local deltaYaw = targetRot.Yaw - currentRot.Yaw
                    local deltaPitch = targetRot.Pitch - currentRot.Pitch
                    if deltaYaw > 180 then deltaYaw = deltaYaw - 360 end
                    if deltaYaw < -180 then deltaYaw = deltaYaw + 360 end
                    if deltaPitch > 180 then deltaPitch = deltaPitch - 360 end
                    if deltaPitch < -180 then deltaPitch = deltaPitch + 360 end
                    finalPitch = currentRot.Pitch + (deltaPitch * smoothFactor)
                    finalYaw = currentRot.Yaw + (deltaYaw * smoothFactor)
                end
            end

            pc:SetControlRotation({ Pitch = finalPitch, Yaw = finalYaw, Roll = 0 }, "ZnNormalAimbot")
            return
        end
        -- ===== END NORMAL AIMBOT =====
        
        local cond = _G.AimbotConfig.Condition or 1
        if cond == 1 and not IsPlayerFiring(player) then _LockedTarget = nil; return end
        
        local maxDistMeters = _G.AimbotConfig.Distance or 250
        local enemies = GetEnemyTargets(player, maxDistMeters * 100)
        if not enemies or #enemies == 0 then return end
        
        local camManager = GameplayStatics.GetPlayerCameraManager(pc, 0)
        if not Valid(camManager) then return end
        
        local camLoc = camManager:GetCameraLocation()
        local camRot = camManager:GetCameraRotation()
        if not camLoc or not camRot then return end

        local viewportSize = ui_util and ui_util.GetViewportSize and ui_util.GetViewportSize() or nil
        if not viewportSize then return end
        
        local centerX = viewportSize.X * 0.5
        local centerY = viewportSize.Y * 0.5
        local FOV_RADIUS = ((_G.AimbotConfig.FOV or 30) / 100.0) * centerX
        
        local bestTarget = nil
        local bestTargetBonePos = nil
        local bestScore = 99999999
        
        local useVisCheck = _G.AimbotConfig.VisCheck ~= false
        local igKnock = _G.AimbotConfig.IgnoreKnock or false
        local igBot = _G.AimbotConfig.IgnoreBot or false
        local targetMode = _G.AimbotConfig.TargetMode or 1  -- 1=Nearest, 2=LowHP
        local wallTarget = _G.AimbotConfig.WallTarget or false  -- Through wall aimbot

        -- مرحلة 1: تصفية الهدف الأقرب للشاشة أولاً (بدون إهدار المعالج في LineTrace)
        local _lockStillValid = false
        for _, target in ipairs(enemies) do
            if Valid(target) then
                if igKnock and target.HealthStatus == 1 then goto continue end
                
                if igBot then
                    local tIsBot = (target.bIsAI == true or target.IsAI == true)
                    local pState = target.PlayerState
                    if Valid(pState) and (pState.bIsABot or pState.bIsBot) then tIsBot = true end
                    if tIsBot then goto continue end
                end

                local eLoc = target:K2_GetActorLocation()
                local distM = 0
                if eLoc and myLoc then
                    distM = math.sqrt((eLoc.X - myLoc.X)^2 + (eLoc.Y - myLoc.Y)^2) / 100
                end
                local aimBone = _G.AimbotConfig.Bone or "spine_03"
                if distM > 100 then
                    aimBone = "spine_03"
                end
                local targetBonePos = GetBoneLocationSafety(target, aimBone)
                if targetBonePos and (targetBonePos.X ~= 0 or targetBonePos.Y ~= 0 or targetBonePos.Z ~= 0) then
                    local success = pc:ProjectWorldLocationToScreen(targetBonePos, ReusableScreenPos, false)
                    if success and ReusableScreenPos.X > 0 and ReusableScreenPos.Y > 0 then
                        local dx = ReusableScreenPos.X - centerX
                        local dy = ReusableScreenPos.Y - centerY
                        local distScreen = math.sqrt(dx * dx + dy * dy)

                        if distScreen <= FOV_RADIUS then
                            -- VisCheck: Skip targets behind walls (unless WallTarget enabled)
                            if useVisCheck and not wallTarget then
                                local isVisible = IsBoneVisible(pc, camLoc, target, targetBonePos)
                                if not isVisible then goto continue end
                            end

                            if _LockedTarget and _LockedTarget == target then
                                _lockStillValid = true
                                if targetMode == 2 then
                                    local hp = target.Health or 0
                                    if hp < bestScore then
                                        bestScore = hp
                                        bestTarget = target
                                        bestTargetBonePos = targetBonePos
                                    end
                                else
                                    bestScore = distScreen
                                    bestTarget = target
                                    bestTargetBonePos = targetBonePos
                                end
                            else
                                if targetMode == 2 then
                                    local hp = target.Health or 99999
                                    if hp < bestScore then
                                        bestScore = hp
                                        bestTarget = target
                                        bestTargetBonePos = targetBonePos
                                    end
                                else
                                    if distScreen < bestScore then
                                        bestScore = distScreen
                                        bestTarget = target
                                        bestTargetBonePos = targetBonePos
                                    end
                                end
                            end
                        end
                    end
                end
            end
            ::continue::
        end

        -- If locked target is still valid and in FOV, force use it
        if _LockedTarget and _lockStillValid and Valid(_LockedTarget) and _LockedTarget:IsAlive() then
            bestTarget = _LockedTarget
            local lockBone = GetBoneLocationSafety(_LockedTarget, _G.AimbotConfig.Bone or "spine_03")
            if lockBone then bestTargetBonePos = lockBone end
        elseif _LockedTarget then
            _LockedTarget = nil
        end

        -- Lock new target if none locked
        if bestTarget and not _LockedTarget then
            _LockedTarget = bestTarget
        end
        
        if not Valid(bestTarget) or not bestTargetBonePos then _LockedTarget = nil; return end
        
        -- حساب التوجيه والسلاسة
        local targetRot = KismetMathLibrary.FindLookAtRotation(camLoc, bestTargetBonePos)
        if not targetRot then return end
        
        local currentRot = pc:GetControlRotation()
        if not currentRot then return end
        
        local deltaYaw = targetRot.Yaw - camRot.Yaw
        local deltaPitch = targetRot.Pitch - camRot.Pitch
        
        if deltaYaw > 180 then deltaYaw = deltaYaw - 360 end
        if deltaYaw < -180 then deltaYaw = deltaYaw + 360 end
        if deltaPitch > 180 then deltaPitch = deltaPitch - 360 end
        if deltaPitch < -180 then deltaPitch = deltaPitch + 360 end
        
        -- تعويض السكوب عند فتح الزوم (FIXED: less aggressive pitch correction)
        local currentFOV = camManager.GetFOVAngle and camManager:GetFOVAngle() or 90.0
        if currentFOV < 65.0 then
            local zoomRatio = (65.0 - currentFOV) / 65.0
            local distMeters = player:GetDistanceTo(bestTarget) / 100.0
            if distMeters > 30 then
                -- Reduced correction to prevent aim going into ground
                local pitchCorrection = math.min((distMeters - 30) * 0.006 * zoomRatio, 1.8)
                deltaPitch = deltaPitch - pitchCorrection
            end
        end

        local speedVal = _G.AimbotConfig.Speed or 50
        local finalPitch = currentRot.Pitch + deltaPitch
        local finalYaw = currentRot.Yaw + deltaYaw

        if _G.AimbotConfig.Smooth ~= false then
            local smoothFactor = math.max(0.01, math.min(speedVal / 100.0, 1.0))
            finalPitch = currentRot.Pitch + (deltaPitch * smoothFactor)
            finalYaw = currentRot.Yaw + (deltaYaw * smoothFactor)
        end
        
        pc:SetControlRotation({ Pitch = finalPitch, Yaw = finalYaw, Roll = 0 }, "ZnAimbot")
    end


    -- ============================================================
    -- HUD COUNTER / STATUS COUNTER (randi style)
    -- Enemy icon + count | Bot icon + count
    -- ============================================================
    local HUDCounter = {
        bActive = false,
        MainContainer = nil,
        WidgetSlot = nil,
        EnemyTextBlock = nil,
        BotTextBlock = nil,

        PlayerCount = 0,
        BotCount = 0,
        FontSize = 16,
        _CachedText = "",
        _CachedPosVec = nil
    }

    local function IsAI(Character)
        if not Valid(Character) then return false end
        local bAI = false
        pcall(function() if Character.bIsAI == true then bAI = true end end)
        if not bAI then pcall(function() if Character.IsAI and Character:IsAI() then bAI = true end end) end
        if not bAI then
            pcall(function()
                local PS = nil
                if Character.GetPlayerState then PS = Character:GetPlayerState() end
                if Valid(PS) then
                    if PS.bIsABot == true or PS.bIsBot == true then bAI = true end
                end
            end)
        end
        if not bAI then pcall(function() if Game and Game.IsAI then bAI = Game:IsAI(Character) end end) end
        return bAI
    end

    local function CountPlayersAndBots()
        local playerCount = 0
        local botCount = 0
        local localPlayer = nil
        pcall(function() localPlayer = GameplayData.GetPlayerCharacter and GameplayData.GetPlayerCharacter() end)
        if not Valid(localPlayer) then return 0, 0 end
        local myTeam = nil
        pcall(function() if localPlayer.GetTeamID then myTeam = localPlayer:GetTeamID() end end)
        local AllChars = {}
        pcall(function()
            local Pawns = Game:GetAllPlayerPawns()
            if Pawns then
                for _, Pawn in pairs(Pawns) do
                    if Pawn and slua.isValid(Pawn) then
                        local pKey = nil
                        if Pawn.GetPlayerKey then pKey = Pawn:GetPlayerKey() end
                        if not pKey and Pawn.PlayerKey then pKey = Pawn.PlayerKey end
                        if pKey then AllChars[pKey] = Pawn end
                    end
                end
            end
        end)
        for pKey, Character in pairs(AllChars) do
            if Valid(Character) and Character ~= localPlayer then
                local bAlive = true
                pcall(function() if Character.IsAlive then bAlive = Character:IsAlive() end end)
                if bAlive then
                    local charTeam = nil
                    pcall(function() if Character.GetTeamID then charTeam = Character:GetTeamID() end end)
                    if charTeam ~= myTeam then
                        if IsAI(Character) then
                            botCount = botCount + 1
                        else
                            playerCount = playerCount + 1
                        end
                    end
                end
            end
        end
        return playerCount, botCount
    end

    function HUDCounter.Create()
        if HUDCounter.MainContainer and slua.isValid(HUDCounter.MainContainer) then return true end
        local ParentCanvas = nil
        pcall(function()
            local InGameUITools = require("GameLua.Mod.BaseMod.Common.UI.InGameUITools")
            local MainControlBaseUI = InGameUITools.GetMainControlBaseUI()
            if Valid(MainControlBaseUI) then
                if MainControlBaseUI.CanvasPanel_0 and Valid(MainControlBaseUI.CanvasPanel_0) then
                    ParentCanvas = MainControlBaseUI.CanvasPanel_0
                elseif MainControlBaseUI.CanvasPanel_42 and Valid(MainControlBaseUI.CanvasPanel_42) then
                    ParentCanvas = MainControlBaseUI.CanvasPanel_42
                end
            end
        end)
        if not ParentCanvas then return false end
        local Container = nil
        pcall(function() Container = CGame:NewObjectFromPath("/Script/UMG.CanvasPanel", ParentCanvas) end)
        if not Container or not slua.isValid(Container) then return false end
        local FLinearColor = import("LinearColor") or FLinearColor
        local FVector2D = import("Vector2D") or FVector2D

        local enemyTxtWidget = nil
        pcall(function() enemyTxtWidget = CGame:NewObjectFromPath("/Script/UMG.TextBlock", Container) end)
        if enemyTxtWidget and slua.isValid(enemyTxtWidget) then
            pcall(function()
                enemyTxtWidget:SetText(tostring(HUDCounter.PlayerCount))
                local FSlateColor = import("SlateColor") or import("/Script/SlateCore.SlateColor")
                local whiteLinear = FLinearColor(1.0, 1.0, 1.0, 1.0)
                if FSlateColor then enemyTxtWidget:SetColorAndOpacity(FSlateColor(whiteLinear)) else enemyTxtWidget:SetColorAndOpacity(whiteLinear) end
                if enemyTxtWidget.Font then local font = enemyTxtWidget.Font; font.Size = HUDCounter.FontSize; enemyTxtWidget.Font = font end
                enemyTxtWidget:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
            end)
            local txtSlot = Container:AddChildToCanvas(enemyTxtWidget)
            if txtSlot then pcall(function() txtSlot:SetAutoSize(true); txtSlot:SetAlignment(FVector2D(0.5, 0.5)); txtSlot:SetPosition(FVector2D(100, 15)); txtSlot:SetZOrder(1000) end) end
            HUDCounter.EnemyTextBlock = enemyTxtWidget
        end

        local botTxtWidget = nil
        pcall(function() botTxtWidget = CGame:NewObjectFromPath("/Script/UMG.TextBlock", Container) end)
        if botTxtWidget and slua.isValid(botTxtWidget) then
            pcall(function()
                botTxtWidget:SetText(tostring(HUDCounter.BotCount))
                local FSlateColor = import("SlateColor") or import("/Script/SlateCore.SlateColor")
                local whiteLinear = FLinearColor(1.0, 1.0, 1.0, 1.0)
                if FSlateColor then botTxtWidget:SetColorAndOpacity(FSlateColor(whiteLinear)) else botTxtWidget:SetColorAndOpacity(whiteLinear) end
                if botTxtWidget.Font then local font = botTxtWidget.Font; font.Size = HUDCounter.FontSize; botTxtWidget.Font = font end
                botTxtWidget:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
            end)
            local txtSlot = Container:AddChildToCanvas(botTxtWidget)
            if txtSlot then pcall(function() txtSlot:SetAutoSize(true); txtSlot:SetAlignment(FVector2D(0.5, 0.5)); txtSlot:SetPosition(FVector2D(230, 15)); txtSlot:SetZOrder(1000) end) end
            HUDCounter.BotTextBlock = botTxtWidget
        end

        local MainSlot = nil
        pcall(function() MainSlot = ParentCanvas:AddChildToCanvas(Container) end)
        if not MainSlot then return false end
        HUDCounter.MainContainer = Container
        HUDCounter.WidgetSlot = MainSlot
        pcall(function() MainSlot:SetAutoSize(false); MainSlot:SetZOrder(999); MainSlot:SetAlignment(FVector2D(0.5, 0.0)); MainSlot:SetSize(FVector2D(300, 28)) end)
        HUDCounter.UpdatePosition()
        return true
    end

    function HUDCounter.SetCounts(players, bots)
        if HUDCounter.PlayerCount == players and HUDCounter.BotCount == bots then return end
        HUDCounter.PlayerCount = players or 0
        HUDCounter.BotCount = bots or 0
        if HUDCounter.EnemyTextBlock and slua.isValid(HUDCounter.EnemyTextBlock) then
            pcall(function() HUDCounter.EnemyTextBlock:SetText(tostring(HUDCounter.PlayerCount)) end)
        end
        if HUDCounter.BotTextBlock and slua.isValid(HUDCounter.BotTextBlock) then
            pcall(function() HUDCounter.BotTextBlock:SetText(tostring(HUDCounter.BotCount)) end)
        end
    end

    function HUDCounter.UpdatePosition()
        local Slot = HUDCounter.WidgetSlot
        if not Slot or not slua.isValid(Slot) then return end
        pcall(function()
            local viewportSize = nil
            pcall(function() local ui_util = require("client.common.ui_util"); if ui_util and ui_util.GetViewportSize then viewportSize = ui_util.GetViewportSize() end end)
            if viewportSize and viewportSize.X and viewportSize.X > 0 then
                local posX = viewportSize.X * 0.5
                local posY = 50
                if not HUDCounter._CachedPosVec then HUDCounter._CachedPosVec = FVector2D(posX, posY) else HUDCounter._CachedPosVec.X = posX; HUDCounter._CachedPosVec.Y = posY end
                Slot:SetPosition(HUDCounter._CachedPosVec)
            end
        end)
    end

    function HUDCounter.Update()
        local playerCount, botCount = CountPlayersAndBots()
        HUDCounter.SetCounts(playerCount, botCount)
        HUDCounter.UpdatePosition()
    end

    function HUDCounter.Start()
        if HUDCounter.bActive and HUDCounter.MainContainer and slua.isValid(HUDCounter.MainContainer) then return end
        if HUDCounter.Create() then
            HUDCounter.bActive = true
            pcall(function() HUDCounter.MainContainer:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible) end)
            HUDCounter.Update()
        end
    end

    function HUDCounter.Stop()
        HUDCounter.bActive = false
        if HUDCounter.MainContainer and slua.isValid(HUDCounter.MainContainer) then
            pcall(function() HUDCounter.MainContainer:RemoveFromParent(); HUDCounter.MainContainer:ConditionalBeginDestroy() end)
        end
        HUDCounter.MainContainer = nil
        HUDCounter.WidgetSlot = nil
        HUDCounter.EnemyTextBlock = nil
        HUDCounter.BotTextBlock = nil
        HUDCounter._CachedPosVec = nil
    end

    _G.HUDCounter = HUDCounter

    -- ============================================================
    -- RED BOX OVERLAY - GRADIENT BOX WITH PLAYER/BOT COUNT
    -- ============================================================
    local RedBoxOverlay = {
        bActive = false,
        MainContainer = nil,
        WidgetSlot = nil,
        TextBlock = nil,

        Width = 440,
        Height = 46,
        OffsetY = 10,

        PlayerCount = 0,
        BotCount = 0,

        Title = "ديمن",          -- الاسم في النص (غيّره زي ما تحب)
        PlayerLabel = "اللاعب :",
        BotLabel = "البوت :",
        TitleFontSize = 22,
        PlayerNumTxt = nil,
        BotNumTxt = nil,

        FontSize = 20,
        TextScaleValue = 1.1,

        NumLayers = 50,
        Red = 1.0,
        Green = 0.0,
        Blue = 0.0,
        LayerAlpha = 0.038,

        _CachedText = "",
        _CachedPosVec = nil
    }

    -- helper: create a TextBlock inside Container
    local function RB_MakeText(Container, str, size, r, g, b, cx, cy, z)
        local FLinearColor = import("LinearColor") or FLinearColor
        local FVector2D = import("Vector2D") or FVector2D
        local t = nil
        pcall(function() t = CGame:NewObjectFromPath("/Script/UMG.TextBlock", Container) end)
        if not t or not slua.isValid(t) then return nil end
        pcall(function()
            t:SetText(str)
            local FSlateColor = import("SlateColor") or import("/Script/SlateCore.SlateColor")
            local col = FLinearColor(r, g, b, 1.0)
            if FSlateColor then t:SetColorAndOpacity(FSlateColor(col)) else t:SetColorAndOpacity(col) end
            t:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
        end)
        pcall(function()
            if t.Font then
                local font = t.Font
                font.Size = size
                pcall(function() font.TypefaceFontName = "Bold" end)
                t.Font = font
            end
        end)
        -- black shadow so text pops like the banner
        pcall(function()
            t:SetShadowOffset(FVector2D(1, 1))
            t:SetShadowColorAndOpacity(FLinearColor(0, 0, 0, 1))
        end)
        local slot = Container:AddChildToCanvas(t)
        if slot then
            pcall(function()
                slot:SetAutoSize(true)
                slot:SetAlignment(FVector2D(0.5, 0.5))
                slot:SetPosition(FVector2D(cx, cy))
                slot:SetZOrder(z or 1000)
            end)
        end
        return t
    end

    -- helper: colored rectangle
    local function RB_MakeRect(Container, x, y, w, h, r, g, b, a, z)
        local FLinearColor = import("LinearColor") or FLinearColor
        local FVector2D = import("Vector2D") or FVector2D
        local border = nil
        pcall(function() border = CGame:NewObjectFromPath("/Script/UMG.Border", Container) end)
        if not border or not slua.isValid(border) then return nil end
        pcall(function()
            border:SetBrushColor(FLinearColor(r, g, b, a))
            border:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
        end)
        local slot = Container:AddChildToCanvas(border)
        if slot then
            pcall(function()
                slot:SetPosition(FVector2D(x, y))
                slot:SetSize(FVector2D(w, h))
                slot:SetZOrder(z or 0)
            end)
        end
        return border
    end

    function RedBoxOverlay.Create()
        if RedBoxOverlay.MainContainer and slua.isValid(RedBoxOverlay.MainContainer) then
            return true
        end

        local ParentCanvas = PlayerMapMarker.ESPCanvas
        if not ParentCanvas or not slua.isValid(ParentCanvas) then
            if not PlayerMapMarker.InitESPCanvas() then return false end
            ParentCanvas = PlayerMapMarker.ESPCanvas
        end

        if not ParentCanvas or not slua.isValid(ParentCanvas) then return false end

        local Container = nil
        pcall(function()
            Container = CGame:NewObjectFromPath("/Script/UMG.CanvasPanel", ParentCanvas)
        end)

        if not Container or not slua.isValid(Container) then return false end

        local FVector2D = import("Vector2D") or FVector2D
        local W = RedBoxOverlay.Width
        local H = RedBoxOverlay.Height

        -- ===== Background (red glow + black body + red lines) =====
        RB_MakeRect(Container, 0, 0, W, H, 1.0, 0.0, 0.0, 0.35, 0)              -- outer red glow
        RB_MakeRect(Container, 3, 3, W - 6, H - 6, 0.02, 0.0, 0.0, 0.92, 1)      -- black body
        RB_MakeRect(Container, 3, 3, W - 6, 2, 1.0, 0.05, 0.05, 1.0, 2)         -- top red line
        RB_MakeRect(Container, 3, H - 5, W - 6, 2, 1.0, 0.05, 0.05, 1.0, 2)     -- bottom red line
        RB_MakeRect(Container, W * 0.5 - 62, 3, 124, H - 6, 0.45, 0.0, 0.0, 0.95, 3)  -- center red panel
        RB_MakeRect(Container, W * 0.5 - 62, 3, 2, H - 6, 1.0, 0.1, 0.1, 1.0, 4)     -- center panel edges
        RB_MakeRect(Container, W * 0.5 + 60, 3, 2, H - 6, 1.0, 0.1, 0.1, 1.0, 4)

        -- ===== Texts =====
        local cy = H * 0.5
        -- center name
        RB_MakeText(Container, RedBoxOverlay.Title, RedBoxOverlay.TitleFontSize, 1.0, 1.0, 1.0, W * 0.5, cy, 1000)
        -- left: player (number far left, label next to it)
        RedBoxOverlay.PlayerNumTxt = RB_MakeText(Container, tostring(RedBoxOverlay.PlayerCount), RedBoxOverlay.FontSize, 1.0, 0.1, 0.1, W * 0.09, cy, 1000)
        RB_MakeText(Container, RedBoxOverlay.PlayerLabel, RedBoxOverlay.FontSize, 1.0, 1.0, 1.0, W * 0.25, cy, 1000)
        -- right: bot (number near center, label far right)
        RedBoxOverlay.BotNumTxt = RB_MakeText(Container, tostring(RedBoxOverlay.BotCount), RedBoxOverlay.FontSize, 1.0, 0.1, 0.1, W * 0.76, cy, 1000)
        RB_MakeText(Container, RedBoxOverlay.BotLabel, RedBoxOverlay.FontSize, 1.0, 1.0, 1.0, W * 0.91, cy, 1000)

        RedBoxOverlay.TextBlock = RedBoxOverlay.PlayerNumTxt

        local MainSlot = nil
        pcall(function() MainSlot = ParentCanvas:AddChildToCanvas(Container) end)
        if not MainSlot then return false end

        RedBoxOverlay.MainContainer = Container
        RedBoxOverlay.WidgetSlot = MainSlot

        pcall(function()
            MainSlot:SetAutoSize(false)
            MainSlot:SetZOrder(999)
            MainSlot:SetAlignment(FVector2D(0.5, 0.0))
            MainSlot:SetSize(FVector2D(W, H))
        end)

        RedBoxOverlay.UpdatePosition()
        return true
    end

    function RedBoxOverlay.SetCounts(players, bots)
        if RedBoxOverlay.PlayerCount == players and RedBoxOverlay.BotCount == bots then
            return
        end

        RedBoxOverlay.PlayerCount = players or 0
        RedBoxOverlay.BotCount = bots or 0

        pcall(function()
            if RedBoxOverlay.PlayerNumTxt and slua.isValid(RedBoxOverlay.PlayerNumTxt) then
                RedBoxOverlay.PlayerNumTxt:SetText(tostring(RedBoxOverlay.PlayerCount))
            end
            if RedBoxOverlay.BotNumTxt and slua.isValid(RedBoxOverlay.BotNumTxt) then
                RedBoxOverlay.BotNumTxt:SetText(tostring(RedBoxOverlay.BotCount))
            end
        end)
    end

    function RedBoxOverlay.UpdatePosition()
        local Slot = RedBoxOverlay.WidgetSlot
        if not Slot or not slua.isValid(Slot) then return end

        local PC = PlayerMapMarker.GetMyPlayerController()
        if not slua.isValid(PC) then return end

        local fromX, fromY = PlayerMapMarker.GetSnapLineStartPos(PC)

        pcall(function()
            if not RedBoxOverlay._CachedPosVec then
                RedBoxOverlay._CachedPosVec = import("Vector2D")(fromX, fromY)
            else
                RedBoxOverlay._CachedPosVec.X = fromX
                RedBoxOverlay._CachedPosVec.Y = fromY
            end
            Slot:SetPosition(RedBoxOverlay._CachedPosVec)
        end)
    end

    function RedBoxOverlay.Start()
        if RedBoxOverlay.bActive and RedBoxOverlay.MainContainer and slua.isValid(RedBoxOverlay.MainContainer) then return end
        if RedBoxOverlay.Create() then
            RedBoxOverlay.bActive = true
            pcall(function()
                RedBoxOverlay.MainContainer:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
            end)
        end
    end

    function RedBoxOverlay.Stop()
        RedBoxOverlay.bActive = false
        if RedBoxOverlay.MainContainer and slua.isValid(RedBoxOverlay.MainContainer) then
            pcall(function()
                RedBoxOverlay.MainContainer:RemoveFromParent()
                RedBoxOverlay.MainContainer:ConditionalBeginDestroy()
            end)
        end
        RedBoxOverlay.MainContainer = nil
        RedBoxOverlay.WidgetSlot = nil
        RedBoxOverlay.TextBlock = nil
        RedBoxOverlay.PlayerNumTxt = nil
        RedBoxOverlay.BotNumTxt = nil
        RedBoxOverlay._CachedPosVec = nil
    end

    _G.RedBoxOverlay = RedBoxOverlay

    -- ============================================================
    -- DEMON RAINBOW MESSAGE (يظهر كل فترة ويختفي - ألوان رينبو)
    -- ============================================================
    do
        if _G.DemonMsg and _G.DemonMsg.Stop then pcall(_G.DemonMsg.Stop) end

        local D = {
            Text = "الملف مجاني لا داعي للنصب: DEMON",
            HideSeconds = 6,      -- مدة الاختفاء بين كل ظهور
            ShowSeconds = 7,      -- مدة بقاء الرسالة
            PosX = 20,            -- من اليسار
            PosY = 140,           -- من فوق (زوّد الرقم تنزل لتحت)
            FontSize = 22,
            RainbowSpeed = 0.35,  -- سرعة تغير الألوان

            _TextBlock = nil, _Last = nil, _Elapsed = 0, _Hue = 0,
            _Visible = false, _NextTry = 0, _Timers = {},
        }

        function D.HSV(h)
            local i = math.floor(h * 6)
            local f = h * 6 - i
            local q = 1 - f
            i = i % 6
            if i == 0 then return 1, f, 0
            elseif i == 1 then return q, 1, 0
            elseif i == 2 then return 0, 1, f
            elseif i == 3 then return 0, q, 1
            elseif i == 4 then return f, 0, 1
            else return 1, 0, q end
        end

        -- يدوّر على Panel في واجهة اللوبي نحط فيه الرسالة
        function D.FindRootPanel(ui)
            local list = {}
            pcall(function() if ui.UIRoot then table.insert(list, ui.UIRoot) end end)
            pcall(function() table.insert(list, ui) end)
            for _, root in ipairs(list) do
                local ws = {}
                pcall(function() if root.WidgetTree and root.WidgetTree.RootWidget then table.insert(ws, root.WidgetTree.RootWidget) end end)
                pcall(function() if root.GetRootWidget then table.insert(ws, root:GetRootWidget()) end end)
                pcall(function() table.insert(ws, root) end)
                for _, w in ipairs(ws) do
                    local okv = false
                    pcall(function() okv = w and slua.isValid(w) end)
                    if okv then
                        local kind = nil
                        pcall(function()
                            if w.AddChildToCanvas then kind = "canvas"
                            elseif w.AddChildToOverlay then kind = "overlay" end
                        end)
                        if kind then return w, kind end
                    end
                end
            end
            return nil
        end

        function D.FindLobbyHost()
            local UM = _G.UIManager or UIManager
            if type(UM) ~= "table" or type(UM.GetUI) ~= "function" then return nil end
            local cfg = UM.UI_Config
            if type(cfg) ~= "table" then return nil end
            local cands = {}
            for k, v in pairs(cfg) do
                if type(k) == "string" then
                    local lk = string.lower(k)
                    if string.find(lk, "lobby") then
                        local sc = 0
                        if string.find(lk, "main") then sc = sc + 2 end
                        if string.find(lk, "panel") or string.find(lk, "base") then sc = sc + 1 end
                        table.insert(cands, { k = k, v = v, s = sc })
                    end
                end
            end
            table.sort(cands, function(x, y) if x.s ~= y.s then return x.s > y.s end return x.k < y.k end)
            for _, c in ipairs(cands) do
                local ui = nil
                pcall(function() ui = UM.GetUI(c.v) end)
                if ui then
                    local w, kind = D.FindRootPanel(ui)
                    if w then
                        D.HostKey = c.k
                        pcall(function() if LOG then LOG("DemonMsg lobby host: " .. tostring(c.k)) end end)
                        return w, kind
                    end
                end
            end
            return nil
        end

        function D.Ensure(now)
            if D._TextBlock and slua.isValid(D._TextBlock) then return true end
            D._TextBlock = nil
            if now < D._NextTry then return false end
            D._NextTry = now + 1.0   -- جرّب مرة كل ثانية بس

            -- 1) داخل الماتش: نفس الـ Canvas بتاع الـ ESP
            local Host, Kind = nil, nil
            local ParentCanvas = PlayerMapMarker.ESPCanvas
            if not ParentCanvas or not slua.isValid(ParentCanvas) then
                local ok = false
                pcall(function() ok = PlayerMapMarker.InitESPCanvas() end)
                if ok then ParentCanvas = PlayerMapMarker.ESPCanvas end
            end
            if ParentCanvas and slua.isValid(ParentCanvas) then
                Host, Kind = ParentCanvas, "canvas"
            else
                -- 2) في اللوبي: واجهة اللوبي
                Host, Kind = D.FindLobbyHost()
            end
            if not Host then return false end

            local FVector2D = import("Vector2D") or FVector2D
            local FLinearColor = import("LinearColor") or FLinearColor
            local t = nil
            pcall(function() t = CGame:NewObjectFromPath("/Script/UMG.TextBlock", Host) end)
            if not t or not slua.isValid(t) then return false end

            pcall(function()
                t:SetText(D.Text)
                if t.Font then
                    local font = t.Font
                    font.Size = D.FontSize
                    pcall(function() font.TypefaceFontName = "Bold" end)
                    t.Font = font
                end
            end)
            pcall(function()
                t:SetShadowOffset(FVector2D(1, 1))
                t:SetShadowColorAndOpacity(FLinearColor(0, 0, 0, 1))
            end)
            pcall(function() t:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed) end)

            local slot = nil
            if Kind == "canvas" then
                pcall(function() slot = Host:AddChildToCanvas(t) end)
                if not slot then return false end
                pcall(function()
                    slot:SetAutoSize(true)
                    slot:SetAlignment(FVector2D(0.0, 0.0))
                    slot:SetPosition(FVector2D(D.PosX, D.PosY))
                    slot:SetZOrder(1100)
                end)
            else
                pcall(function() slot = Host:AddChildToOverlay(t) end)
                if not slot then return false end
                pcall(function() slot:SetHorizontalAlignment(1) end)  -- Left
                pcall(function() slot:SetVerticalAlignment(1) end)    -- Top
                pcall(function()
                    local FMargin = import("Margin")
                    slot:SetPadding(FMargin(D.PosX, D.PosY, 0, 0))
                end)
            end

            D._TextBlock = t
            D._Visible = false
            D._Elapsed = 0
            return true
        end

        -- تُستدعى من أي تايمر (الوقت الحقيقي، فمفيش مشكلة لو اتنادت أكتر من مرة)
        function D.Step()
            if not D._Started then return end
            pcall(function()
                local now = os.clock()
                local dt = 0
                if D._Last then dt = now - D._Last end
                D._Last = now
                if dt < 0 then dt = 0 end
                if dt > 0.5 then dt = 0.5 end

                if not D.Ensure(now) then return end
                local t = D._TextBlock
                D._Elapsed = D._Elapsed + dt

                if D._Visible then
                    if D._Elapsed >= D.ShowSeconds then
                        D._Visible = false
                        D._Elapsed = 0
                        t:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed)
                        return
                    end
                    D._Hue = (D._Hue + D.RainbowSpeed * dt) % 1.0
                    local r, g, b = D.HSV(D._Hue)
                    local FLinearColor = import("LinearColor") or FLinearColor
                    local FSlateColor = import("SlateColor") or import("/Script/SlateCore.SlateColor")
                    local col = FLinearColor(r, g, b, 1.0)
                    if FSlateColor then t:SetColorAndOpacity(FSlateColor(col)) else t:SetColorAndOpacity(col) end
                else
                    if D._Elapsed >= D.HideSeconds then
                        D._Visible = true
                        D._Elapsed = 0
                        t:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
                    end
                end
            end)
        end

        function D.GetPC()
            local pc = nil
            pcall(function() pc = PlayerMapMarker.GetMyPlayerController() end)
            if pc and slua.isValid(pc) and pc.AddGameTimer then return pc end
            pc = nil
            pcall(function() if slua_GameFrontendHUD then pc = slua_GameFrontendHUD:GetPlayerController() end end)
            if pc and slua.isValid(pc) and pc.AddGameTimer then return pc end
            return nil
        end

        -- يراقب: لو الـ PlayerController اتغير (لوبي <-> ماتش) يربط تايمر جديد
        function D.Watchdog()
            if not D._Started then return end
            pcall(function()
                local pc = D.GetPC()
                if pc and pc ~= D._TimerPC then
                    D._TimerPC = pc
                    pc:AddGameTimer(0.05, true, D.Step)
                end
            end)
            pcall(function()
                require("timer").SetGameTimer(2.0, false, D.Watchdog)
            end)
        end

        function D.Start()
            if D._Started then return end
            D._Started = true
            pcall(function()
                if _G.Game and _G.Game.AddGameTimer then
                    _G.Game:AddGameTimer(0.05, true, D.Step)
                end
            end)
            D.Watchdog()
        end

        function D.Stop()
            D._Started = false
            if D._TextBlock and slua.isValid(D._TextBlock) then
                pcall(function() D._TextBlock:RemoveFromParent() end)
            end
            D._TextBlock = nil
        end

        _G.DemonMsg = D
        D.Start()
    end

    -- ============================================================
    -- ESP & MARKER SYSTEM CODE
    -- ============================================================

    local InGameMarkTools = require("GameLua.Mod.BaseMod.Common.InGameMarkTools")

    local SlateBlueprintLibrary = nil
    local WidgetLayoutLibrary = nil
    local KismetMathLibrary = nil
    local KismetSystemLibrary = nil

    pcall(function() SlateBlueprintLibrary = import("SlateBlueprintLibrary") or import("/Script/UMG.SlateBlueprintLibrary") end)
    pcall(function() WidgetLayoutLibrary = import("WidgetLayoutLibrary") or import("/Script/UMG.WidgetLayoutLibrary") end)
    pcall(function() KismetMathLibrary = import("KismetMathLibrary") end)
    pcall(function() KismetSystemLibrary = import("KismetSystemLibrary") end)

    PlayerMapMarker.MarkTypeID = 1007
    PlayerMapMarker.bUseScreenESP = true
    PlayerMapMarker.bUseScreenMark = false
    PlayerMapMarker.bUseQuickSign = false
    PlayerMapMarker.bUseNavigator = false
    PlayerMapMarker.bUseWidgetComponent = false
    PlayerMapMarker.QuickSignConfigKey = "C_MarkPos"

    PlayerMapMarker.WidgetCompUIPath = "/Game/BluePrints/ControlInput/NewbieItem/NewbieTips_ConsumeTips.NewbieTips_ConsumeTips"
    PlayerMapMarker.WidgetCompBoneName = "head"
    PlayerMapMarker.WidgetCompOffset = FVector(0, 0, 80)
    PlayerMapMarker.WidgetCompDrawSize = FVector2D(300, 50)

    PlayerMapMarker.ESPBoneName = "head"
    PlayerMapMarker.ESPWorldOffsetZ = 0
    PlayerMapMarker.ESPScreenOffsetY = 0

    PlayerMapMarker.ESPAnchorOffsetX = 50
    PlayerMapMarker.ESPAnchorOffsetY = 0
    PlayerMapMarker.ESPTextOffsetX = 0
    PlayerMapMarker.ESPTextOffsetY = 0

    PlayerMapMarker.ESPWidgetAlignment = FVector2D(0.5, 1.0)
    PlayerMapMarker.ESPWidgetSize = FVector2D(100, 30)
    PlayerMapMarker.ESPWidgetAutoSize = true
    PlayerMapMarker.ESPWidgetZOrder = 2

    PlayerMapMarker.bShowDistance = true
    PlayerMapMarker.DistanceUnit = "m"

    PlayerMapMarker.WeaponIconBrushW = 138
    PlayerMapMarker.WeaponIconBrushH = 69
    PlayerMapMarker.HPWidgetSwitcherTypeIndex = 0
    PlayerMapMarker.HPWidgetSwitcherType2Index = 0
    PlayerMapMarker.bForceSwitcherIndexEveryUpdate = true

    PlayerMapMarker.bUseSnapLines = true
    PlayerMapMarker.SnapLineThickness = 2.5
    PlayerMapMarker.SnapLineOriginY = 50
    PlayerMapMarker.SnapLineOriginOffsetX = 0
    PlayerMapMarker.SnapLineHeadOffsetX = 0
    PlayerMapMarker.SnapLineHeadOffsetY = -20
    PlayerMapMarker.SnapLineColor = nil
    PlayerMapMarker.SnapLineOpacity = 0.7

    -- FOV Circle config
    PlayerMapMarker.bUseFOVCircle = false
    PlayerMapMarker.FOVCircleSegments = 36
    PlayerMapMarker.FOVCircleThickness = 1.5
    local FLinearColor2 = _G.FLinearColor or import("LinearColor")
    PlayerMapMarker.FOVCircleColor = FLinearColor2 and FLinearColor2(0.2, 0.8, 1.0, 0.85) or {R=0.2,G=0.8,B=1.0,A=0.85}
    PlayerMapMarker.FOVCircleLines = {}

    -- Directional Arrows config
    PlayerMapMarker.bUseArrows = false
    PlayerMapMarker.ArrowStemLen = 20.0
    PlayerMapMarker.ArrowHeadLen = 10.0
    PlayerMapMarker.ArrowWingAngle = 0.45
    PlayerMapMarker.ArrowOffset = 4.0
    PlayerMapMarker.ArrowThickness = 2.5
    PlayerMapMarker.ArrowColor = FLinearColor2 and FLinearColor2(1.0, 0.1, 0.1, 0.95) or {R=1.0,G=0.1,B=0.1,A=0.95}
    PlayerMapMarker.ArrowWidgets = {}

    -- Box ESP config
    PlayerMapMarker.bUseBoxESP = false
    PlayerMapMarker.BoxThickness = 1.5
    PlayerMapMarker.BoxWidthFactor = 0.50
    PlayerMapMarker.BoxColor = FLinearColor2 and FLinearColor2(0.1, 1.0, 0.15, 0.9) or {R=0.1,G=1.0,B=0.15,A=0.9}
    PlayerMapMarker.BoxWidgets = {}

    PlayerMapMarker.MapAddedFlag = 4
    PlayerMapMarker.nUpdateInterval = 0.5

    PlayerMapMarker.bUseFrameTick = false
    PlayerMapMarker.nHeavyScanFrameInterval = 15
    PlayerMapMarker.nDistanceUpdateFrameInterval = 5

    PlayerMapMarker.bIncludeMe = false
    PlayerMapMarker.bIncludeAI = true
    PlayerMapMarker.bUseServerMarks = false

    PlayerMapMarker.bActive = false
    PlayerMapMarker.MarkMap = {}
    PlayerMapMarker.PlayerInfo = {}

    PlayerMapMarker.ESPCanvas = nil
    PlayerMapMarker.ESPWidgets = {}
    PlayerMapMarker.ESPWidgetPtrs = {}
    PlayerMapMarker.SnapLineWidgets = {}

    PlayerMapMarker._cachedViewportW = 1920
    PlayerMapMarker._cachedViewportH = 1080

    PlayerMapMarker._FrameCount = 0
    PlayerMapMarker._bTickRegistered = false
    PlayerMapMarker._CachedAllChars = nil
    PlayerMapMarker._CachedMyLoc = nil
    PlayerMapMarker._CachedMyKey = nil

    PlayerMapMarker.WidgetComps = {}
    PlayerMapMarker._bAllPathsFailed = false

    PlayerMapMarker._bLightUpdateScheduled = false
    PlayerMapMarker._LightUpdateInterval = 0.05

    PlayerMapMarker._bDistanceUpdateScheduled = false
    PlayerMapMarker._DistanceUpdateInterval = 0.2

    local function IsValid(obj)
        if obj == nil then return false end
        if slua and slua.isValid then return slua.isValid(obj) end
        return obj ~= nil
    end

    local function SafeStr(val)
        if val == nil then return "nil" end
        return tostring(val)
    end

    local function GetFVector(X, Y, Z)
        local VT = FVector
        if not VT then
            pcall(function() VT = import("/Script/CoreUObject.Vector") end)
        end
        if VT then
            local ok, vec = pcall(function() return VT(X or 0, Y or 0, Z or 0) end)
            if ok and vec then return vec end
        end
        return nil
    end

    local function GetMapAddedFlag()
        if PlayerMapMarker.MapAddedFlag ~= nil then
            return PlayerMapMarker.MapAddedFlag
        end
        if UEnums and UEnums.EAddMarkFlag and UEnums.EAddMarkFlag.EAMF_Both then
            return UEnums.EAddMarkFlag.EAMF_Both
        end
        return 3
    end

    PlayerMapMarker._bScreenMarkConfigSetup = false

    function PlayerMapMarker.SetupScreenMarkConfig()
        if PlayerMapMarker._bScreenMarkConfigSetup then return true end
        local bOK = false
        pcall(function()
            local GamePlayTools = require("GameLua.Mod.BaseMod.Common.GamePlayTools")
            local ScreenMarkConfig = GamePlayTools.GetCurrentConfig("ScreenMarkConfig")
            if ScreenMarkConfig then
                ScreenMarkConfig[1007] = {
                    UIPathName = "/Game/BluePrints/UI/OBUI/Item/OB_PlayerHeadHPItem_UIBP.OB_PlayerHeadHPItem_UIBP_C",
                    MaxWidgetNum = 100,
                    MaxShowDistance = 6000000,
                    bBindOutScreen = false,
                    bBindBlocked = true,
                    bNeedPreLoad = true,
                    bIsBindingActor = true,
                    BindSocketName = "HelmetSocket",
                    WorldPositionOffset = FVector(0, 0, 80)
                }
                PlayerMapMarker._bScreenMarkConfigSetup = true
                bOK = true
            end
        end)
        return bOK
    end

    function PlayerMapMarker.GetGameplayData()
        if PlayerMapMarker._CachedGameplayData then
            return PlayerMapMarker._CachedGameplayData
        end
        local ok, GDP = pcall(function()
            return require("GameLua.GameCore.Data.GameplayData")
        end)
        if ok and GDP then
            PlayerMapMarker._CachedGameplayData = GDP
            return GDP
        end
        return nil
    end

    function PlayerMapMarker.GetMyPlayerController()
        local PC = PlayerMapMarker._CachedPC
        if PC and IsValid(PC) then
            return PC
        end
        local GDP = PlayerMapMarker.GetGameplayData()
        if not GDP then return nil end
        pcall(function() PC = GDP.GetPlayerController and GDP.GetPlayerController() end)
        if PC and IsValid(PC) then
            PlayerMapMarker._CachedPC = PC
            return PC
        end
        return nil
    end

    function PlayerMapMarker.GetCGameState()
        if CGameState and IsValid(CGameState) then
            return CGameState
        end
        if PlayerMapMarker._CachedCGameState and IsValid(PlayerMapMarker._CachedCGameState) then
            return PlayerMapMarker._CachedCGameState
        end
        local ok, GS = pcall(function()
            return require("GameLua.GameCore.Data.CGameState")
        end)
        if ok and GS then
            PlayerMapMarker._CachedCGameState = GS
            return GS
        end
        return nil
    end

    function PlayerMapMarker.GetAllCharacters()
        local AllChars = {}
        pcall(function()
            local Pawns = Game:GetAllPlayerPawns()
            if Pawns then
                for _, Pawn in pairs(Pawns) do
                    if Pawn and slua.isValid(Pawn) then
                        local pKey = nil
                        if Pawn.GetPlayerKey then
                            pKey = Pawn:GetPlayerKey()
                        end
                        if not pKey and Pawn.PlayerKey then
                            pKey = Pawn.PlayerKey
                        end
                        if not pKey and Pawn.PlayerState and Pawn.PlayerState.PlayerKey then
                            pKey = Pawn.PlayerState.PlayerKey
                        end
                        if pKey then
                            AllChars[pKey] = Pawn
                        end
                    end
                end
            end
        end)
        
        if not next(AllChars) then
            local GS = PlayerMapMarker.GetCGameState()
            if GS and GS.GetAllCharacters then
                pcall(function() AllChars = GS:GetAllCharacters() end)
            end
        end
        
        return AllChars
    end

    function PlayerMapMarker.GetMyPlayerKey()
        local PC = PlayerMapMarker.GetMyPlayerController()
        if not IsValid(PC) then return nil end
        local MyKey = nil
        pcall(function()
            if PC.GetPlayerKey then
                MyKey = PC:GetPlayerKey()
            elseif PC.PlayerState and PC.PlayerState.PlayerKey then
                MyKey = PC.PlayerState.PlayerKey
            end
        end)
        return MyKey
    end

    function PlayerMapMarker.IsMe(Character, PlayerKey, MyKey)
        local bIsMe = false
        pcall(function()
            local GDP = PlayerMapMarker.GetGameplayData()
            if GDP and GDP.GetLocalCharacter then
                local MyChar = GDP.GetLocalCharacter()
                if MyChar and Character == MyChar then
                    bIsMe = true
                    return
                end
            end
            local PC = PlayerMapMarker.GetMyPlayerController()
            if PC and PC.GetPawn then
                local Pawn = PC:GetPawn()
                if Pawn and Character == Pawn then
                    bIsMe = true
                    return
                end
            end
        end)
        if not bIsMe and MyKey ~= nil and PlayerKey ~= nil then
            bIsMe = (tostring(PlayerKey) == tostring(MyKey))
        end
        return bIsMe
    end

    function PlayerMapMarker.GetCharacterLocation(Character)
        if not IsValid(Character) then return nil end
        local Loc = nil
        pcall(function()
            if Character.K2_GetActorLocation then
                Loc = Character:K2_GetActorLocation()
            end
        end)
        if not Loc then
            pcall(function()
                if Game and Game.GetActorLocation then
                    Loc = Game:GetActorLocation(Character)
                end
            end)
        end
        return Loc
    end

    function PlayerMapMarker.CalcDistance(Loc1, Loc2)
        if not Loc1 or not Loc2 then return nil end
        local Dist = nil
        pcall(function()
            if FVector and FVector.Dist2D then
                Dist = FVector.Dist2D(Loc1, Loc2)
            end
        end)
        if not Dist then
            pcall(function()
                local DX = (Loc1.X or 0) - (Loc2.X or 0)
                local DY = (Loc1.Y or 0) - (Loc2.Y or 0)
                Dist = math.sqrt(DX * DX + DY * DY)
            end)
        end
        return Dist
    end

    function PlayerMapMarker.GetDistanceString(MyLoc, TargetLoc)
        if not PlayerMapMarker.bShowDistance then return "" end
        if not MyLoc or not TargetLoc then return "" end
        local Dist = PlayerMapMarker.CalcDistance(MyLoc, TargetLoc)
        if not Dist then return "" end
        local Meters = Dist / 100
        if Meters < 1000 then
            return string.format("%dm", math.floor(Meters))
        else
            return string.format("%.1fkm", Meters / 1000)
        end
    end

    function PlayerMapMarker.GetMyLocation()
        local GDP = PlayerMapMarker.GetGameplayData()
        if not GDP then return nil end
        local MyChar = nil
        pcall(function() MyChar = GDP.GetLocalCharacter and GDP.GetLocalCharacter() end)
        if not IsValid(MyChar) then
            local PC = PlayerMapMarker.GetMyPlayerController()
            if IsValid(PC) then
                pcall(function()
                    if PC.GetPawn then
                        local Pawn = PC:GetPawn()
                        if IsValid(Pawn) and Pawn.K2_GetActorLocation then
                            return Pawn:K2_GetActorLocation()
                        end
                    end
                end)
            end
            return nil
        end
        return PlayerMapMarker.GetCharacterLocation(MyChar)
    end

    function PlayerMapMarker.GetPlayerName(Character)
        if not IsValid(Character) then return "Unknown" end
        local Name = nil
        pcall(function()
            if Character.GetPlayerNameSafety then
                Name = Character:GetPlayerNameSafety()
            end
        end)
        if not Name then
            pcall(function()
                local PS = nil
                if Character.GetPlayerStateSafety then
                    PS = Character:GetPlayerStateSafety()
                elseif Character.GetPlayerState then
                    PS = Character:GetPlayerState()
                end
                if IsValid(PS) and PS.GetPlayerName then
                    Name = PS:GetPlayerName()
                end
            end)
        end
        return Name or "Unknown"
    end

    function PlayerMapMarker.IsAI(Character)
        local bAI = false
        pcall(function()
            if Game and Game.IsAI then
                bAI = Game:IsAI(Character)
            end
        end)
        return bAI
    end

    function PlayerMapMarker.IsAlive(Character)
        local bAlive = true
        pcall(function()
            if Character.IsAlive then
                bAlive = Character:IsAlive()
            end
        end)
        return bAlive
    end

    function PlayerMapMarker.GetQuickSignComponent()
        local PC = PlayerMapMarker.GetMyPlayerController()
        if not IsValid(PC) then return nil end
        local QSC = nil
        pcall(function()
            if PC.GetQuickSignComponent then
                QSC = PC:GetQuickSignComponent()
            end
        end)
        if not IsValid(QSC) then
            pcall(function()
                local STExtraBlueprintFunctionLibrary = import("STExtraBlueprintFunctionLibrary")
                if STExtraBlueprintFunctionLibrary and STExtraBlueprintFunctionLibrary.GetQuickSignComponentFromController then
                    QSC = STExtraBlueprintFunctionLibrary.GetQuickSignComponentFromController(PC)
                end
            end)
        end
        return QSC
    end

    function PlayerMapMarker.CreateQuickSignMark(Location)
        if not Location then return nil end
        local QSC = PlayerMapMarker.GetQuickSignComponent()
        if not IsValid(QSC) then return nil end
        local MsgID = nil
        pcall(function()
            if QSC.MakeCustomMark then
                MsgID = QSC:MakeCustomMark(Location, PlayerMapMarker.QuickSignConfigKey)
            end
        end)
        return MsgID
    end

    function PlayerMapMarker.RemoveQuickSignMark(MsgID)
        if not MsgID then return end
        local QSC = PlayerMapMarker.GetQuickSignComponent()
        if not IsValid(QSC) then return end
        pcall(function()
            if QSC.DealWithDelMsg then
                QSC:DealWithDelMsg(MsgID, false)
            end
        end)
    end

    PlayerMapMarker._NavInstIDCounter = 1000
    PlayerMapMarker.NavigatorUIPath = "/Game/BluePrints/UI/OBUI/Item/OB_PlayerHeadHPItem_UIBP.OB_PlayerHeadHPItem_UIBP_C"
    PlayerMapMarker.NavigatorbIsIcon = true

    function PlayerMapMarker.CreateNavigatorMark(Location)
        if not Location then return nil end
        local InstID = PlayerMapMarker._NavInstIDCounter
        PlayerMapMarker._NavInstIDCounter = PlayerMapMarker._NavInstIDCounter + 1
        local NavWidget = nil
        pcall(function()
            if UIManager and UIManager.UI_Config_InGame and UIManager.UI_Config_InGame.NavigatorPanel then
                NavWidget = UIManager.GetUI(UIManager.UI_Config_InGame.NavigatorPanel)
            end
        end)
        if not NavWidget then return nil end
        local Result = nil
        pcall(function()
            Result = InGameMarkTools.ClientAddMarkToNavigator(
                PlayerMapMarker.NavigatorUIPath,
                Location,
                true,
                PlayerMapMarker.NavigatorbIsIcon,
                nil,
                InstID
            )
        end)
        return InstID
    end

    function PlayerMapMarker.UpdateNavigatorMark(InstID, Location)
        if not InstID or not Location then return end
        pcall(function()
            if not UIManager.UI_Config_InGame.NavigatorPanel then return end
            local NavigatorWidget = UIManager.GetUI(UIManager.UI_Config_InGame.NavigatorPanel)
            if not NavigatorWidget then return end
            if NavigatorWidget.UpdateCustomMarkLocation then
                NavigatorWidget:UpdateCustomMarkLocation(InstID, Location)
            end
        end)
    end

    function PlayerMapMarker.RemoveNavigatorMark(InstID)
        if not InstID then return end
        pcall(function()
            InGameMarkTools.ClientDestroyMarkToNavigator(InstID)
        end)
    end

    function PlayerMapMarker.IsOurESPWidget(w)
        if not w or not slua.isValid(w) then return false end
        local bIsOurs = false
        pcall(function()
            local wstr = tostring(w)
            for KeyStr, ESPData in pairs(PlayerMapMarker.ESPWidgets) do
                if ESPData and ESPData.Widget and ESPData.Widget.Container then
                    local cstr = tostring(ESPData.Widget.Container)
                    if cstr == wstr then
                        bIsOurs = true
                        return
                    end
                end
            end
        end)
        if bIsOurs then return true end
        pcall(function()
            if w.GetChildrenCount then
                local n = w:GetChildrenCount()
                for i = 0, n - 1 do
                    local child = w:GetChildAt(i)
                    if child and slua.isValid(child) then
                        local cstr = tostring(child)
                        if string.find(cstr, "Border") then
                            bIsOurs = true
                            break
                        end
                    end
                end
            end
        end)
        if not bIsOurs then
            pcall(function()
                local slot = w.Slot
                if slot and slot.GetPosition then
                    local pos = slot:GetPosition()
                    if pos and (math.abs(pos.X or 0) > 1 or math.abs(pos.Y or 0) > 1) then
                        bIsOurs = true
                    end
                end
            end)
        end
        if not bIsOurs then
            pcall(function()
                local function checkForDist(w2, depth)
                    if not w2 or not slua.isValid(w2) or depth > 5 then return false end
                    if w2.GetText then
                        local txt = nil
                        pcall(function() txt = w2:GetText() end)
                        if txt then
                            local s = tostring(txt)
                            if string.find(s, "%[%d+m%]") or string.find(s, "Dist=") then
                                return true
                            end
                        end
                    end
                    local n = 0
                    pcall(function() if w2.GetChildrenCount then n = w2:GetChildrenCount() end end)
                    for j = 0, n - 1 do
                        local c = nil
                        pcall(function() c = w2:GetChildAt(j) end)
                        if c and checkForDist(c, depth + 1) then return true end
                    end
                    return false
                end
                bIsOurs = checkForDist(w, 0)
            end)
        end
        return bIsOurs
    end

    function PlayerMapMarker.ApplyAnchorBasedPosition(Slot, ScreenPos, Canvas)
        if not Slot or not ScreenPos then return false end
        local sx = ScreenPos.X or 0
        local sy = ScreenPos.Y or 0
        local sz = PlayerMapMarker.ESPWidgetSize or FVector2D(100, 30)
        local align = PlayerMapMarker.ESPWidgetAlignment or FVector2D(0.5, 1.0)

        local canvasW, canvasH = 0, 0
        if PlayerMapMarker._cachedViewportW and PlayerMapMarker._cachedViewportW > 200 then
            canvasW = PlayerMapMarker._cachedViewportW
            canvasH = PlayerMapMarker._cachedViewportH
        end

        if canvasW < 200 then
            pcall(function()
                local PC = PlayerMapMarker.GetMyPlayerController()
                if IsValid(PC) and PC.GetViewportSize then
                    local VS = FVector2D(0, 0)
                    PC:GetViewportSize(VS)
                    if VS and VS.X and VS.X > 200 then
                        canvasW = VS.X
                        canvasH = VS.Y
                        PlayerMapMarker._cachedViewportW = canvasW
                        PlayerMapMarker._cachedViewportH = canvasH
                    end
                end
            end)
        end

        if canvasW < 200 and Canvas then
            pcall(function()
                local current = Canvas
                local depth = 0
                while current and depth < 20 do
                    local w, h = 0, 0
                    pcall(function()
                        if current.GetCachedGeometry then
                            local cg = current:GetCachedGeometry()
                            if cg then
                                if cg.GetAbsoluteSize then
                                    local cs = cg:GetAbsoluteSize()
                                    if cs then
                                        w = cs.X or 0
                                        h = cs.Y or 0
                                    end
                                end
                            end
                        end
                    end)
                    if w >= 200 and h >= 200 then
                        canvasW = w
                        canvasH = h
                        PlayerMapMarker._cachedViewportW = w
                        PlayerMapMarker._cachedViewportH = h
                        break
                    end
                    local parent = nil
                    pcall(function() if current.GetParent then parent = current:GetParent() end end)
                    if not parent then break end
                    current = parent
                    depth = depth + 1
                end
            end)
        end

        if canvasW > 200 and canvasH > 200 then
            local anchorX = (sx + (PlayerMapMarker.ESPAnchorOffsetX or 0)) / canvasW
            local anchorY = (sy + (PlayerMapMarker.ESPAnchorOffsetY or 0)) / canvasH
            anchorX = math.max(0, math.min(1, anchorX))
            anchorY = math.max(0, math.min(1, anchorY))

            local bSuccess = false
            pcall(function()
                if Slot.SetAnchors and FAnchors then
                    local anchors = FAnchors(anchorX, anchorY, anchorX, anchorY)
                    if anchors then
                        Slot:SetAnchors(anchors)
                        Slot:SetPosition(FVector2D(0, 0))
                        bSuccess = true
                    end
                end
            end)
            if not bSuccess then
                pcall(function()
                    if Slot.SetAnchors then
                        Slot:SetAnchors(anchorX, anchorY, anchorX, anchorY)
                        Slot:SetPosition(FVector2D(0, 0))
                        bSuccess = true
                    end
                end)
            end
            if bSuccess then
                pcall(function()
                    if Slot.SetOffsets and FMargin then
                        Slot:SetOffsets(FMargin(0, 0, sz.X, sz.Y))
                    end
                end)
                pcall(function() Slot:SetSize(sz) end)
                pcall(function() Slot:SetAlignment(align) end)
                pcall(function() if Slot.SetAutoSize then Slot:SetAutoSize(PlayerMapMarker.ESPWidgetAutoSize or true) end end)
                pcall(function() if Slot.SetZOrder then Slot:SetZOrder(PlayerMapMarker.ESPWidgetZOrder or 2) end end)
                return true
            end
        end

        pcall(function()
            Slot:SetPosition(FVector2D(sx, sy))
            pcall(function() Slot:SetSize(sz) end)
            pcall(function() Slot:SetAlignment(align) end)
            pcall(function() if Slot.SetAutoSize then Slot:SetAutoSize(PlayerMapMarker.ESPWidgetAutoSize or true) end end)
            pcall(function() if Slot.SetZOrder then Slot:SetZOrder(PlayerMapMarker.ESPWidgetZOrder or 2) end end)
        end)
        return false
    end

    function PlayerMapMarker.InitESPCanvas()
        if PlayerMapMarker.ESPCanvas and Game:IsValid(PlayerMapMarker.ESPCanvas) then
            return true
        end

        local InGameUITools = nil
        pcall(function() InGameUITools = require("GameLua.Mod.BaseMod.Common.UI.InGameUITools") end)
        if not InGameUITools then
            return false
        end

        local MainControlBaseUI = nil
        pcall(function() MainControlBaseUI = InGameUITools.GetMainControlBaseUI() end)
        if not MainControlBaseUI or not Game:IsValid(MainControlBaseUI) then
            return false
        end

        local ParentCanvas = nil
        pcall(function()
            if MainControlBaseUI.CanvasPanel_0 and Game:IsValid(MainControlBaseUI.CanvasPanel_0) then
                ParentCanvas = MainControlBaseUI.CanvasPanel_0
            elseif MainControlBaseUI.CanvasPanel_42 and Game:IsValid(MainControlBaseUI.CanvasPanel_42) then
                ParentCanvas = MainControlBaseUI.CanvasPanel_42
            end
        end)

        if not ParentCanvas then
            return false
        end

        PlayerMapMarker.ESPCanvas = ParentCanvas

        pcall(function()
            local nChildren = ParentCanvas:GetChildrenCount()
            for i = nChildren - 1, 0, -1 do
                local child = ParentCanvas:GetChildAt(i)
                if child and slua.isValid(child) then
                    if PlayerMapMarker.IsOurESPWidget(child) then
                        pcall(function() ParentCanvas:RemoveChild(child) end)
                    end
                end
            end
        end)

        return true
    end

    function PlayerMapMarker.FindProgressBarInWidget(WidgetObj, Depth, MaxDepth)
        if not WidgetObj or not slua.isValid(WidgetObj) then return nil end
        Depth = Depth or 0
        MaxDepth = MaxDepth or 5
        if Depth > MaxDepth then return nil end

        local bIsPB = false
        pcall(function()
            if WidgetObj.SetPercent and WidgetObj.SetFillColorAndOpacity then
                bIsPB = true
            end
        end)
        if bIsPB then return WidgetObj end

        local nChildren = 0
        pcall(function()
            if WidgetObj.GetChildrenCount then nChildren = WidgetObj:GetChildrenCount() end
        end)

        for i = 0, math.max(nChildren - 1, 0) do
            local child = nil
            pcall(function() child = WidgetObj:GetChildAt(i) end)
            if child and slua.isValid(child) then
                local result = PlayerMapMarker.FindProgressBarInWidget(child, Depth + 1, MaxDepth)
                if result then return result end
            end
        end

        return nil
    end

    function PlayerMapMarker.GetTeamID(Character)
        if not IsValid(Character) then return nil end
        local TeamID = nil
        pcall(function()
            if Character.GetTeamID then TeamID = Character:GetTeamID() end
        end)
        if not TeamID then
            pcall(function()
                local PS = nil
                if Character.GetPlayerStateSafety then
                    PS = Character:GetPlayerStateSafety()
                elseif Character.GetPlayerState then
                    PS = Character:GetPlayerState()
                end
                if IsValid(PS) and PS.GetTeamID then
                    TeamID = PS:GetTeamID()
                elseif IsValid(PS) and PS.TeamID then
                    TeamID = PS.TeamID
                end
            end)
        end
        if not TeamID then
            pcall(function()
                if Character.TeamID then TeamID = Character.TeamID end
            end)
        end
        return TeamID
    end

    function PlayerMapMarker.GetTeamColor(TeamID)
        if TeamID == nil then return nil end
        local TeamColors = {
            [1] = FLinearColor(1.0, 0.2, 0.2, 1.0),
            [2] = FLinearColor(0.2, 0.4, 1.0, 1.0),
            [3] = FLinearColor(0.2, 0.9, 0.3, 1.0),
            [4] = FLinearColor(1.0, 0.9, 0.2, 1.0),
            [5] = FLinearColor(0.8, 0.3, 1.0, 1.0),
            [6] = FLinearColor(0.2, 0.9, 0.9, 1.0),
            [7] = FLinearColor(1.0, 0.5, 0.2, 1.0),
            [8] = FLinearColor(1.0, 0.4, 0.7, 1.0),
        }
        local color = TeamColors[TeamID]
        if color then return color end
        if TeamID == 1 then
            return FLinearColor(1.0, 0.2, 0.2, 1.0)
        else
            return FLinearColor(0.2, 0.4, 1.0, 1.0)
        end
    end

    local _WhiteTexture = nil
    local _bWhiteTextureFailed = false

    local function GetWhiteTexture()
        if _WhiteTexture then return _WhiteTexture end
        if _bWhiteTextureFailed then return nil end
        pcall(function()
            local paths = {
                "/Game/BluePrints/UI/Textures/White.White",
                "/Game/BluePrints/UI/Textures/Common/White.White",
                "/Engine/EngineResources/WhiteSquareTexture.WhiteSquareTexture",
                "/Engine/EngineMaterials/DefaultWhiteGrid.DefaultWhiteGrid",
            }
            for _, path in ipairs(paths) do
                pcall(function()
                    local tex = import(path)
                    if tex and slua.isValid(tex) then
                        _WhiteTexture = tex
                        return
                    end
                end)
                if _WhiteTexture then break end
            end
        end)
        if not _WhiteTexture then
            _bWhiteTextureFailed = true
        end
        return _WhiteTexture
    end

    local function SetImageColor(Image, color)
        if not Image or not slua.isValid(Image) then return false end
        local bOK = false
        pcall(function()
            if Image.SetBrushTintColor then
                Image:SetBrushTintColor(color)
                bOK = true
            end
        end)
        pcall(function()
            if Image.SetBrushColor then
                Image:SetBrushColor(color)
                bOK = true
            end
        end)
        pcall(function()
            if Image.SetColorAndOpacity then
                Image:SetColorAndOpacity(color)
                bOK = true
            end
        end)
        pcall(function()
            if Image.SetTintColorAndOpacity then
                Image:SetTintColorAndOpacity(color)
                bOK = true
            end
        end)
        pcall(function()
            if Image.SetBrushFromTexture then
                local whiteTex = GetWhiteTexture()
                if whiteTex then
                    Image:SetBrushFromTexture(whiteTex, false)
                    if Image.SetColorAndOpacity then
                        Image:SetColorAndOpacity(color)
                    end
                    if Image.SetBrushTintColor then
                        Image:SetBrushTintColor(color)
                    end
                    bOK = true
                end
            end
        end)
        pcall(function()
            if Image.SetBrushFromAsset and not bOK then
                Image:SetBrushFromAsset("/Engine/EngineResources/WhiteSquareTexture.WhiteSquareTexture", false)
                if Image.SetColorAndOpacity then
                    Image:SetColorAndOpacity(color)
                end
                bOK = true
            end
        end)
        pcall(function() Image:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible) end)
        pcall(function() Image:SetRenderOpacity(1.0) end)
        return bOK
    end

    function PlayerMapMarker._GetWidgetRoot(WidgetObj)
        if not WidgetObj or not slua.isValid(WidgetObj) then return nil end
        local Root = nil
        pcall(function()
            if WidgetObj.GetRootWidget then
                Root = WidgetObj:GetRootWidget()
            end
        end)
        if Root and slua.isValid(Root) then return Root end
        pcall(function()
            if WidgetObj.WidgetTree and WidgetObj.WidgetTree.RootWidget then
                Root = WidgetObj.WidgetTree.RootWidget
            end
        end)
        if Root and slua.isValid(Root) then return Root end
        pcall(function()
            if WidgetObj.RootWidget and slua.isValid(WidgetObj.RootWidget) then
                Root = WidgetObj.RootWidget
            end
        end)
        return Root
    end

    function PlayerMapMarker._FindNamedWidgetInTree(WidgetObj, TargetName, MaxDepth)
        if not WidgetObj or not slua.isValid(WidgetObj) then return nil end
        MaxDepth = MaxDepth or 8

        local wname = nil
        pcall(function()
            if WidgetObj.GetName then wname = WidgetObj:GetName() end
        end)
        if wname and wname == TargetName then return WidgetObj end

        local wstr = tostring(WidgetObj)
        if wstr and string.find(wstr, TargetName, 1, true) then
            if wname and wname == TargetName then
                return WidgetObj
            elseif not wname or wname == "" then
                local _, endPos = string.find(wstr, TargetName, 1, true)
                if endPos then
                    local nextChar = string.sub(wstr, endPos + 1, endPos + 1)
                    if nextChar ~= "_" and nextChar ~= "" then
                        return WidgetObj
                    end
                end
            end
        end

        local nChildren = 0
        pcall(function()
            if WidgetObj.GetChildrenCount then nChildren = WidgetObj:GetChildrenCount() end
        end)

        if nChildren > 0 then
            for i = 0, nChildren - 1 do
                local child = nil
                pcall(function() child = WidgetObj:GetChildAt(i) end)
                if child and slua.isValid(child) then
                    local found = PlayerMapMarker._FindNamedWidgetInTree(child, TargetName, MaxDepth - 1)
                    if found then return found end
                end
            end
        else
            local Root = PlayerMapMarker._GetWidgetRoot(WidgetObj)
            if Root and slua.isValid(Root) and Root ~= WidgetObj then
                local found = PlayerMapMarker._FindNamedWidgetInTree(Root, TargetName, MaxDepth - 1)
                if found then return found end
            end
        end

        return nil
    end

    function PlayerMapMarker.ApplyTeamColor(Widget, TeamID)
        if not Widget or not Widget.Container then return end
        local color = PlayerMapMarker.GetTeamColor(TeamID)
        if not color then return end

        pcall(function()
            local W = Widget.Container
            if not W or not slua.isValid(W) then return end

            local bBG = false
            local Image_TeamBG = PlayerMapMarker._FindNamedWidgetInTree(W, "Image_TeamBG", 8)
            if Image_TeamBG and slua.isValid(Image_TeamBG) then
                bBG = SetImageColor(Image_TeamBG, color)
            end

            local Image_TeamLogoBG = PlayerMapMarker._FindNamedWidgetInTree(W, "Image_TeamLogoBG", 8)
            if Image_TeamLogoBG and slua.isValid(Image_TeamLogoBG) then
                SetImageColor(Image_TeamLogoBG, color)
            end

            if not bBG then
                if W.Image_TeamBG_2 and slua.isValid(W.Image_TeamBG_2) then
                    bBG = SetImageColor(W.Image_TeamBG_2, color)
                end
                if W.Image_TeamLogoBG2 and slua.isValid(W.Image_TeamLogoBG2) then
                    SetImageColor(W.Image_TeamLogoBG2, color)
                end
                if W.Image_TeamLogoBegin and slua.isValid(W.Image_TeamLogoBegin) then
                    SetImageColor(W.Image_TeamLogoBegin, color)
                end
            end

            if W.SetTeamColor then
                pcall(function() W:SetTeamColor(TeamID) end)
            end
            if W.SetTeamID then
                pcall(function() W:SetTeamID(TeamID) end)
            end

            if not Widget.TeamBgBorder or not slua.isValid(Widget.TeamBgBorder) then
                pcall(function()
                    local Border = CGame:NewObjectFromPath("/Script/UMG.Border", W)
                    if Border and slua.isValid(Border) then
                        pcall(function() Border:SetBrushColor(color) end)
                        pcall(function() Border:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible) end)
                        pcall(function() Border:SetRenderOpacity(0.7) end)
                        pcall(function() Border:SetDesiredSizeOverride(FVector2D(120, 20)) end)
                        pcall(function()
                            if W.AddChild then
                                W:AddChild(Border)
                            end
                        end)
                        pcall(function()
                            if Border.SetZOrder then
                                Border:SetZOrder(-1)
                            end
                        end)
                        pcall(function()
                            local Slot = Border.Slot
                            if Slot then
                                if Slot.SetSize then
                                    Slot:SetSize(FVector2D(120, 40))
                                end
                                if Slot.SetPosition then
                                    Slot:SetPosition(FVector2D(0, 0))
                                end
                            end
                        end)
                        Widget.TeamBgBorder = Border
                    end
                end)
            else
                pcall(function()
                    Widget.TeamBgBorder:SetBrushColor(color)
                    Widget.TeamBgBorder:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
                    Widget.TeamBgBorder:SetRenderOpacity(0.7)
                end)
            end
        end)
    end

    function PlayerMapMarker.GetCharacterMesh(Character)
        if not IsValid(Character) then return nil end
        local Mesh = nil
        pcall(function()
            if Character.Mesh and Game:IsValid(Character.Mesh) then
                Mesh = Character.Mesh
            end
        end)
        if not Mesh then
            pcall(function()
                local SkeletalMeshCompClass = import("/Script/Engine.SkeletalMeshComponent")
                Mesh = Character:GetComponentByClass(SkeletalMeshCompClass)
            end)
        end
        return Mesh
    end

    function PlayerMapMarker.GetBoneLocation(Character, BoneName)
        if not IsValid(Character) or not BoneName then return nil end
        local Mesh = PlayerMapMarker.GetCharacterMesh(Character)
        if not Mesh or not Game:IsValid(Mesh) then return nil end
        local Loc = nil
        pcall(function()
            if Mesh.GetSocketLocation then
                Loc = Mesh:GetSocketLocation(BoneName)
            end
        end)
        if not Loc then
            pcall(function()
                if Mesh.GetBoneLocation then
                    Loc = Mesh:GetBoneLocation(BoneName)
                end
            end)
        end
        return Loc
    end

    function PlayerMapMarker.ApplyWorldOffset(Loc, OffsetZ)
        if not Loc then return nil end
        if not OffsetZ or OffsetZ == 0 then return Loc end
        
        local ok = pcall(function()
            Loc.Z = Loc.Z + OffsetZ
        end)
        if ok then
            return Loc
        end

        local result = nil
        pcall(function()
            local X = Loc.X or 0
            local Y = Loc.Y or 0
            local Z = (Loc.Z or 0) + OffsetZ
            if FVector then
                result = FVector(X, Y, Z)
            end
        end)
        return result or Loc
    end

    function PlayerMapMarker.GetESPLocation(Character)
        if not IsValid(Character) then return nil end
        
        local BoneLoc = PlayerMapMarker.GetCharacterLocation(Character)
        if BoneLoc then
            local heightOffset = 85
            pcall(function()
                if Character.bIsCrouched then heightOffset = 60 end
                if Character.IsProne and Character:IsProne() then heightOffset = 30 end
            end)
            BoneLoc = PlayerMapMarker.ApplyWorldOffset(BoneLoc, heightOffset + (PlayerMapMarker.ESPWorldOffsetZ or 0))
        end
        
        return BoneLoc
    end

    function PlayerMapMarker.GetCharacterFeetLoc(Character)
        if not IsValid(Character) then return nil end
        local Loc = nil
        pcall(function()
            if Character.K2_GetActorLocation then Loc = Character:K2_GetActorLocation() end
        end)
        if not Loc then
            pcall(function()
                if Game and Game.GetActorLocation then Loc = Game:GetActorLocation(Character) end
            end)
        end
        return Loc
    end

    function PlayerMapMarker.GetCharacterHeadLoc(Character)
        if not IsValid(Character) then return nil end
        -- Try actual head bone first
        local headBone = nil
        pcall(function()
            local Mesh = Character.Mesh
            if not Mesh or not Game:IsValid(Mesh) then return end
            if Mesh.GetSocketLocation then
                headBone = Mesh:GetSocketLocation("head")
            end
            if not headBone and Mesh.GetBoneLocation then
                headBone = Mesh:GetBoneLocation("head")
            end
        end)
        if headBone and (headBone.X ~= 0 or headBone.Y ~= 0 or headBone.Z ~= 0) then
            return headBone
        end
        -- Fallback: use actor loc + offset
        local Feet = PlayerMapMarker.GetCharacterFeetLoc(Character)
        if not Feet then return nil end
        local headZ = Feet.Z + 170
        pcall(function()
            if Character.bIsCrouched then headZ = Feet.Z + 120 end
            if Character.IsProne and Character:IsProne() then headZ = Feet.Z + 50 end
        end)
        return { X = Feet.X, Y = Feet.Y, Z = headZ }
    end

    function PlayerMapMarker.GetCharacterWeaponInfo(Character)
        if not IsValid(Character) then return nil end

        local WeaponID = nil
        local WeaponName = nil
        local WeaponIconPath = nil
        local WeaponIconTexture = nil
        local CurrentWeapon = nil

        pcall(function()
            if Character.GetCurrentWeapon then
                CurrentWeapon = Character:GetCurrentWeapon()
            end
        end)
        
        if not CurrentWeapon then
            pcall(function()
                CurrentWeapon = Character.CurrentWeapon
            end)
        end

        if not CurrentWeapon then
            pcall(function()
                if Character.GetWeaponManager then
                    local WM = Character:GetWeaponManager()
                    if WM and WM.GetCurrentWeapon then
                        CurrentWeapon = WM:GetCurrentWeapon()
                    end
                end
            end)
        end

        if not CurrentWeapon then
            pcall(function()
                if Character.GetInventoryComponent then
                    local IC = Character:GetInventoryComponent()
                    if IC and IC.GetCurrentWeapon then
                        CurrentWeapon = IC:GetCurrentWeapon()
                    end
                end
            end)
        end

        if CurrentWeapon and IsValid(CurrentWeapon) then
            pcall(function()
                if CurrentWeapon.GetWeaponID then
                    WeaponID = CurrentWeapon:GetWeaponID()
                end
            end)
            if not WeaponID then
                pcall(function()
                    WeaponID = CurrentWeapon.WeaponID
                end)
            end
            if not WeaponID then
                pcall(function()
                    if CurrentWeapon.GetItemID then
                        WeaponID = CurrentWeapon:GetItemID()
                    end
                end)
            end
            
            pcall(function()
                if CurrentWeapon.GetWeaponName then
                    WeaponName = CurrentWeapon:GetWeaponName()
                end
            end)
            if not WeaponName then
                pcall(function()
                    WeaponName = CurrentWeapon.WeaponName
                end)
            end
            
            pcall(function()
                if CurrentWeapon.GetWeaponIconPath then
                    WeaponIconPath = CurrentWeapon:GetWeaponIconPath()
                end
            end)
            if not WeaponIconPath then
                pcall(function()
                    WeaponIconPath = CurrentWeapon.IconPath
                end)
            end
            
            pcall(function()
                if CurrentWeapon.GetWeaponIcon then
                    WeaponIconTexture = CurrentWeapon:GetWeaponIcon()
                end
            end)
            if not WeaponIconTexture then
                pcall(function()
                    WeaponIconTexture = CurrentWeapon.IconTexture
                end)
            end
        end

        if not WeaponID then
            pcall(function()
                local PS = nil
                if Character.GetPlayerStateSafety then
                    PS = Character:GetPlayerStateSafety()
                elseif Character.GetPlayerState then
                    PS = Character:GetPlayerState()
                end
                if PS and IsValid(PS) then
                    if PS.GetCurrentWeaponID then WeaponID = PS:GetCurrentWeaponID() end
                    if not WeaponID and PS.CurrentWeaponID then WeaponID = PS.CurrentWeaponID end
                    if not WeaponID and PS.WeaponID then WeaponID = PS.WeaponID end
                    if not WeaponID and PS.HoldWeaponID then WeaponID = PS.HoldWeaponID end
                    if not WeaponID and PS.CurWeaponID then WeaponID = PS.CurWeaponID end
                    if not WeaponID and PS.EquipWeaponID then WeaponID = PS.EquipWeaponID end
                end
            end)
        end
        
        if not WeaponID then
            pcall(function()
                if Character.WeaponID then WeaponID = Character.WeaponID end
                if not WeaponID and Character.CurrentWeaponID then WeaponID = Character.CurrentWeaponID end
                if not WeaponID and Character.HoldWeaponID then WeaponID = Character.HoldWeaponID end
                if not WeaponID and Character.CurWeaponID then WeaponID = Character.CurWeaponID end
                if not WeaponID and Character.EquipWeaponID then WeaponID = Character.EquipWeaponID end
                if not WeaponID and Character.WeaponManagerComponent then
                    local WMC = Character.WeaponManagerComponent
                    if WMC.CurrentWeaponID then WeaponID = WMC.CurrentWeaponID end
                    if not WeaponID and WMC.WeaponID then WeaponID = WMC.WeaponID end
                    if not WeaponID and WMC.HoldWeaponID then WeaponID = WMC.HoldWeaponID end
                    if not WeaponID and WMC.CurWeaponID then WeaponID = WMC.CurWeaponID end
                end
            end)
        end

        return {
            WeaponID = WeaponID,
            WeaponName = WeaponName,
            WeaponIconPath = WeaponIconPath,
            WeaponIconTexture = WeaponIconTexture,
            CurrentWeapon = CurrentWeapon,
        }
    end

    function PlayerMapMarker.FindWeaponIconInWidget(WidgetObj, Depth, MaxDepth)
        if not WidgetObj or not slua.isValid(WidgetObj) then return nil end
        Depth = Depth or 0
        MaxDepth = MaxDepth or 8

        local propNames = {
            "Image_Weapon", "Image_WeaponIcon", "Image_Gun", "Image_Icon",
            "WeaponIcon", "WeaponImage", "WeaponIconImage",
            "Image_Equip", "Image_WeaponIcon_2", "Image_WeaponIcon2",
        }
        
        for _, pname in ipairs(propNames) do
            pcall(function()
                local prop = WidgetObj[pname]
                if prop and slua.isValid(prop) then
                    local hasBrush = false
                    pcall(function() if prop.Brush then hasBrush = true end end)
                    if hasBrush then
                        return prop
                    end
                end
            end)
        end

        if Depth >= MaxDepth then
            return nil
        end

        local nChildren = 0
        pcall(function()
            if WidgetObj.GetChildrenCount then nChildren = WidgetObj:GetChildrenCount() end
        end)

        for i = 0, math.max(nChildren - 1, 0) do
            local child = nil
            pcall(function() child = WidgetObj:GetChildAt(i) end)
            if child and slua.isValid(child) then
                local result = PlayerMapMarker.FindWeaponIconInWidget(child, Depth + 1, MaxDepth)
                if result then return result end
            end
        end

        if nChildren == 0 then
            local Root = PlayerMapMarker._GetWidgetRoot(WidgetObj)
            if Root and slua.isValid(Root) and Root ~= WidgetObj then
                local result = PlayerMapMarker.FindWeaponIconInWidget(Root, Depth + 1, MaxDepth)
                if result then return result end
            end
        end

        return nil
    end

    function PlayerMapMarker.FixWeaponIconBrushSize(ImageWidget, DefaultW, DefaultH)
        if not ImageWidget or not slua.isValid(ImageWidget) then return end
        
        DefaultW = DefaultW or 138
        DefaultH = DefaultH or 69
        
        pcall(function()
            local brush = ImageWidget.Brush
            if brush then
                brush.ImageSize = FVector2D(DefaultW, DefaultH)
                brush.DrawAs = 3
                brush.TintColor = FLinearColor(1.0, 1.0, 1.0, 1.0)
                if ImageWidget.SetBrush then
                    ImageWidget:SetBrush(brush)
                end
            end
            
            if ImageWidget.SetDesiredSizeOverride then
                ImageWidget:SetDesiredSizeOverride(FVector2D(DefaultW, DefaultH))
            end
            
            local slot = ImageWidget.Slot
            if slot and slot.SetSize then
                slot:SetSize(FVector2D(DefaultW, DefaultH))
            end
            
            ImageWidget:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
            ImageWidget:SetRenderOpacity(1.0)
            ImageWidget:SetColorAndOpacity(FLinearColor(1.0, 1.0, 1.0, 1.0))
        end)
    end

    function PlayerMapMarker.ApplyWeaponIconFullOpacity(Container, ourWeaponIcon)
        local fullIcon = FLinearColor(1.0, 1.0, 1.0, 1.0)

        if not ourWeaponIcon or not slua.isValid(ourWeaponIcon) then return end

        pcall(function()
            if ourWeaponIcon.SetRenderOpacity then ourWeaponIcon:SetRenderOpacity(1.0) end
        end)
        pcall(function()
            if ourWeaponIcon.SetColorAndOpacity then ourWeaponIcon:SetColorAndOpacity(fullIcon) end
        end)
        pcall(function()
            if ourWeaponIcon.SetBrushTintColor then ourWeaponIcon:SetBrushTintColor(fullIcon) end
        end)
        pcall(function()
            if ourWeaponIcon.SetTintColorAndOpacity then ourWeaponIcon:SetTintColorAndOpacity(fullIcon) end
        end)
        
        pcall(function()
            local brush = ourWeaponIcon.Brush
            if brush then
                pcall(function() brush.TintColor = fullIcon end)
                if ourWeaponIcon.SetBrush then ourWeaponIcon:SetBrush(brush) end
            end
        end)

        local chainNames = {"Border_WeaponColor", "Border_Weapon", "Border_WeaponIcon",
            "SizeBox_Weapon", "ScaleBox_Weapon", "Switcher_WeaponIcon"}
        for _, pname in ipairs(chainNames) do
            pcall(function()
                local node = Container and Container[pname]
                if node and slua.isValid(node) and node.SetRenderOpacity then
                    node:SetRenderOpacity(1.0)
                end
                if node and slua.isValid(node) and node.SetColorAndOpacity then
                    node:SetColorAndOpacity(fullIcon)
                end
            end)
        end
    end

    function PlayerMapMarker.ApplyWeaponIconToImage(ImageWidget, winfo)
        if not ImageWidget or not slua.isValid(ImageWidget) then
            return false, "no_widget"
        end
        if not winfo or not winfo.WeaponID then
            return false, "no_weapon_id"
        end

        local iconPath = nil
        local method = "none"
        local bHasAddKnownMissing = false
        local defaultW = 138
        local defaultH = 69

        pcall(function()
            local itemRecord = CDataTable.GetTableData("Item", winfo.WeaponID)
            if itemRecord and itemRecord.KillWhiteIcon and itemRecord.KillWhiteIcon ~= "" then
                iconPath = itemRecord.KillWhiteIcon
                method = "KillWhiteIcon"
            end

            if (not iconPath or iconPath == "") and winfo.WeaponIconPath and winfo.WeaponIconPath ~= "" then
                iconPath = winfo.WeaponIconPath
                method = "WeaponIconPath"
            end

            if (not iconPath or iconPath == "") and winfo.WeaponIconTexture and slua.isValid(winfo.WeaponIconTexture) then
                if ImageWidget.SetBrushFromTexture then
                    ImageWidget:SetBrushFromTexture(winfo.WeaponIconTexture, true)
                    method = "WeaponIconTexture"
                    return
                end
            end

            if not iconPath or iconPath == "" then
                local UIUtil = require("client.common.ui_util")
                iconPath, bHasAddKnownMissing = UIUtil.GetItemBigIcon(winfo.WeaponID, ImageWidget)
                if iconPath and iconPath ~= "" then
                    method = "GetItemBigIcon"
                end
            end

            if not iconPath or iconPath == "" then
                local UIUtil = require("client.common.ui_util")
                iconPath = UIUtil.GetItemSmallIcon(winfo.WeaponID, ImageWidget, bHasAddKnownMissing)
                if iconPath and iconPath ~= "" then
                    method = "GetItemSmallIcon"
                end
            end
        end)

        if method == "WeaponIconTexture" then
            PlayerMapMarker.FixWeaponIconBrushSize(ImageWidget, defaultW, defaultH)
            return true, method
        end
        
        if not iconPath or iconPath == "" then
            return false, "no_path"
        end

        local bOK = false
        pcall(function()
            if ImageWidget.SetBrushResourceFromPathSync then
                ImageWidget:SetBrushResourceFromPathSync(iconPath, true)
                bOK = true
            end
            
            if not bOK then
                local util = require("client.slua_ui_framework.util")
                local result = util.SetTexture(ImageWidget, iconPath, {
                    sync = true,
                    bMatchSize = true,
                    bIsInCombatState = true,
                    bHasAddKnownMissing = bHasAddKnownMissing,
                })
                bOK = result ~= nil
            end
            
            if not bOK then
                local tex = import(iconPath)
                if tex and slua.isValid(tex) and ImageWidget.SetBrushFromTexture then
                    ImageWidget:SetBrushFromTexture(tex, true)
                    bOK = true
                end
            end
            
            if not bOK then
                local LoadObject = import("LoadObject")
                if LoadObject then
                    local tex = LoadObject(iconPath)
                    if tex and slua.isValid(tex) and ImageWidget.SetBrushFromTexture then
                        ImageWidget:SetBrushFromTexture(tex, true)
                        bOK = true
                    end
                end
            end
        end)

        if bOK then
            PlayerMapMarker.FixWeaponIconBrushSize(ImageWidget, defaultW, defaultH)
        end

        return bOK, method .. ":" .. tostring(iconPath)
    end

    function PlayerMapMarker.CopyWeaponIconBrushFromNative(ourWeaponIcon, nativeWeaponIcon)
        if not ourWeaponIcon or not slua.isValid(ourWeaponIcon) then return false end
        if not nativeWeaponIcon or not slua.isValid(nativeWeaponIcon) then return false end

        local bCopied = false
        
        pcall(function()
            local nBrush = nativeWeaponIcon.Brush
            if nBrush then
                local resObj = nil
                pcall(function() resObj = nBrush.ResourceObject end)
                if resObj and slua.isValid(resObj) and ourWeaponIcon.SetBrushFromTexture then
                    ourWeaponIcon:SetBrushFromTexture(resObj, true)
                    bCopied = true
                end
                
                if bCopied then
                    local imgSize = nil
                    pcall(function() imgSize = nBrush.ImageSize end)
                    if imgSize then
                        local oBrush = ourWeaponIcon.Brush
                        if oBrush then
                            oBrush.ImageSize = imgSize
                            if ourWeaponIcon.SetBrush then
                                ourWeaponIcon:SetBrush(oBrush)
                            end
                        end
                    end
                end
            end
        end)

        return bCopied
    end

    function PlayerMapMarker.AddWeaponIconToESP(WidgetData, Character)
        if not WidgetData or not WidgetData.Container then return end
        local Container = WidgetData.Container
        if not slua.isValid(Container) then return end

        pcall(function()
            local ourWeaponIcon = Container.WeaponIcon
            if not ourWeaponIcon or not slua.isValid(ourWeaponIcon) then
                ourWeaponIcon = PlayerMapMarker.FindWeaponIconInWidget(Container, 0, 8)
            end

            if not ourWeaponIcon or not slua.isValid(ourWeaponIcon) then
                return
            end

            local winfo = Character and PlayerMapMarker.GetCharacterWeaponInfo(Character) or nil

            if not winfo or not winfo.WeaponID or winfo.WeaponID == 0 then
                pcall(function() ourWeaponIcon:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed) end)
                local chainNames = {"Border_WeaponColor", "Border_Weapon", "Border_WeaponIcon",
                    "SizeBox_Weapon", "ScaleBox_Weapon", "Switcher_WeaponIcon"}
                for _, pname in ipairs(chainNames) do
                    pcall(function()
                        local node = Container and Container[pname]
                        if node and slua.isValid(node) and node.SetWidgetVisibility then
                            node:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed)
                        end
                    end)
                end
                WidgetData._LastWeaponID = 0
                WidgetData._WeaponIconApplied = false
                return
            end

            if WidgetData._LastWeaponID == winfo.WeaponID and WidgetData._WeaponIconApplied then
                pcall(function() ourWeaponIcon:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible) end)
                pcall(function() ourWeaponIcon:SetRenderOpacity(1.0) end)
                local chainNames = {"Border_WeaponColor", "Border_Weapon", "Border_WeaponIcon",
                    "SizeBox_Weapon", "ScaleBox_Weapon", "Switcher_WeaponIcon"}
                for _, pname in ipairs(chainNames) do
                    pcall(function()
                        local node = Container and Container[pname]
                        if node and slua.isValid(node) and node.SetWidgetVisibility then
                            node:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
                            pcall(function() if node.SetRenderOpacity then node:SetRenderOpacity(1.0) end end)
                        end
                    end)
                end
                if WidgetData._CachedSwitcherIndexes then
                    for sName, idx in pairs(WidgetData._CachedSwitcherIndexes) do
                        pcall(function()
                            local ws = Container[sName]
                            if ws and slua.isValid(ws) and ws.SetActiveWidgetIndex then
                                ws:SetActiveWidgetIndex(idx)
                            end
                        end)
                    end
                end
                if WidgetData._CachedParentSwitchers then
                    for _, data in pairs(WidgetData._CachedParentSwitchers) do
                        pcall(function()
                            if data.w and slua.isValid(data.w) and data.w.SetActiveWidgetIndex then
                                data.w:SetActiveWidgetIndex(data.idx)
                            end
                        end)
                    end
                end
                return
            end

            local chainNames = {"Border_WeaponColor", "Border_Weapon", "Border_WeaponIcon",
                "SizeBox_Weapon", "ScaleBox_Weapon", "Switcher_WeaponIcon"}
            for _, pname in ipairs(chainNames) do
                pcall(function()
                    local node = Container and Container[pname]
                    if node and slua.isValid(node) and node.SetWidgetVisibility then
                        node:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
                    end
                end)
            end

            local bCopied = false
            local copyMethod = "none"
            if winfo and winfo.WeaponID then
                local ok, method = PlayerMapMarker.ApplyWeaponIconToImage(ourWeaponIcon, winfo)
                if ok then
                    bCopied = true
                    copyMethod = method
                end
            end

            local bWeaponIconSet = false
            if Character and winfo then
                if winfo and winfo.WeaponID then
                    pcall(function()
                        if Container.SetWeaponIcon then
                            Container:SetWeaponIcon(winfo.WeaponID)
                            bWeaponIconSet = true
                        end
                    end)
                    if not bWeaponIconSet then
                        pcall(function()
                            if Container.SetWeaponIconByID then
                                Container:SetWeaponIconByID(winfo.WeaponID)
                                bWeaponIconSet = true
                            end
                        end)
                    end
                    if not bWeaponIconSet then
                        pcall(function()
                            if Container.UpdateWeaponIcon then
                                Container:UpdateWeaponIcon(winfo.WeaponID)
                                bWeaponIconSet = true
                            end
                        end)
                    end
                    if not bWeaponIconSet then
                        pcall(function()
                            if Container.SetWeaponID then
                                Container:SetWeaponID(winfo.WeaponID)
                                bWeaponIconSet = true
                            end
                        end)
                    end
                    pcall(function()
                        if Container.SetData then
                            Container:SetData(Character)
                        end
                    end)
                    pcall(function()
                        if Container.SetObservedPlayer then
                            Container:SetObservedPlayer(Character)
                        end
                    end)
                    pcall(function()
                        if Container.SetPlayerInfo then
                            Container:SetPlayerInfo(Character)
                        end
                    end)
                    if winfo.CurrentWeapon then
                        pcall(function()
                            if Container.SetCurrentWeapon then
                                Container:SetCurrentWeapon(winfo.CurrentWeapon)
                            end
                        end)
                    end
                end
            end

            if bWeaponIconSet then
                pcall(function()
                    local innerIcon = Container.Image_Icon
                    if not innerIcon or not slua.isValid(innerIcon) then
                        if Container.CanvasPanel_Type1 then
                            innerIcon = Container.CanvasPanel_Type1.Image_Icon
                        end
                    end
                    if not innerIcon or not slua.isValid(innerIcon) then
                        local function findImageIcon(w, depth)
                            if not w or not slua.isValid(w) or depth > 8 then return nil end
                            local prop = w.Image_Icon
                            if prop and slua.isValid(prop) then return prop end
                            local n = 0
                            pcall(function() if w.GetChildrenCount then n = w:GetChildrenCount() end end)
                            for i = 0, math.max(n - 1, 0) do
                                local c = nil
                                pcall(function() c = w:GetChildAt(i) end)
                                if c then
                                    local r = findImageIcon(c, depth + 1)
                                    if r then return r end
                                end
                            end
                            return nil
                        end
                        innerIcon = findImageIcon(Container, 0)
                    end
                    if innerIcon and slua.isValid(innerIcon) and innerIcon ~= ourWeaponIcon then
                        pcall(function()
                            local ibrush = innerIcon.Brush
                            if ibrush then
                                local iresObj = nil
                                pcall(function() iresObj = ibrush.ResourceObject end)
                                if iresObj and slua.isValid(iresObj) then
                                    if ourWeaponIcon.SetBrushFromAsset then
                                        ourWeaponIcon:SetBrushFromAsset(iresObj)
                                        bCopied = true
                                        copyMethod = "SetWeaponIcon+Image_Icon->SetBrushFromAsset"
                                    end
                                    if not bCopied and ourWeaponIcon.SetBrushFromTexture then
                                        ourWeaponIcon:SetBrushFromTexture(iresObj)
                                        bCopied = true
                                        copyMethod = "SetWeaponIcon+Image_Icon->SetBrushFromTexture"
                                    end
                                end
                            end
                        end)
                        if not bCopied then
                            pcall(function()
                                local brush = innerIcon.Brush
                                if brush then
                                    local iresObj = nil
                                    pcall(function() iresObj = brush.ResourceObject end)
                                    if iresObj and slua.isValid(iresObj) and ourWeaponIcon.SetBrushFromTexture then
                                        ourWeaponIcon:SetBrushFromTexture(iresObj, false)
                                        PlayerMapMarker.FixWeaponIconBrushSize(ourWeaponIcon)
                                        bCopied = true
                                        copyMethod = "SetWeaponIcon+Image_Icon->SetBrushFromTexture"
                                    end
                                end
                            end)
                        end
                    end
                end)
            end

            if not bCopied then
                local nativeWeaponIcon = nil
                if PlayerMapMarker.ESPCanvas and Game:IsValid(PlayerMapMarker.ESPCanvas) then
                    local nChildren = 0
                    pcall(function() nChildren = PlayerMapMarker.ESPCanvas:GetChildrenCount() end)
                    for i = 0, math.max(nChildren - 1, 0) do
                        local child = nil
                        pcall(function() child = PlayerMapMarker.ESPCanvas:GetChildAt(i) end)
                        if child and slua.isValid(child) then
                            local cstr = tostring(child)
                            if string.find(cstr, "OB_PlayerHeadHPItem") then
                                if not PlayerMapMarker.IsOurESPWidget(child) then
                                    local nativeIcon = child.WeaponIcon
                                    if nativeIcon and slua.isValid(nativeIcon) then
                                        nativeWeaponIcon = nativeIcon
                                        break
                                    end
                                end
                            end
                        end
                    end
                end

                if nativeWeaponIcon and slua.isValid(nativeWeaponIcon) then
                    local okNative, nativeMethod = PlayerMapMarker.CopyWeaponIconBrushFromNative(ourWeaponIcon, nativeWeaponIcon)
                    if okNative then
                        bCopied = true
                        copyMethod = nativeMethod
                    end
                end
            end

            if not bCopied then
                pcall(function()
                    local brush = ourWeaponIcon.Brush
                    if brush then
                        local resObj = nil
                        pcall(function() resObj = brush.ResourceObject end)
                        if resObj and slua.isValid(resObj) and ourWeaponIcon.SetBrushFromTexture then
                            ourWeaponIcon:SetBrushFromTexture(resObj)
                            bCopied = true
                            copyMethod = "ReRegisterDefault:SetBrushFromTexture"
                        end
                    end
                end)
            end

            if not bCopied then
                pcall(function()
                    local brush = ourWeaponIcon.Brush
                    if brush then
                        local imgSize = nil
                        pcall(function() imgSize = brush.ImageSize end)
                        local bZeroSize = false
                        if imgSize then
                            local sx, sy = nil, nil
                            pcall(function() sx = imgSize.X end)
                            pcall(function() sy = imgSize.Y end)
                            if (not sx or sx == 0) and (not sy or sy == 0) then
                                bZeroSize = true
                            end
                        end
                        if bZeroSize then
                            pcall(function()
                                brush.ImageSize = FVector2D(
                                    PlayerMapMarker.WeaponIconBrushW or 138,
                                    PlayerMapMarker.WeaponIconBrushH or 69)
                            end)
                        end
                        pcall(function() brush.DrawAs = 3 end)
                        if ourWeaponIcon.SetBrush then
                            ourWeaponIcon:SetBrush(brush)
                        end
                    end
                end)
            end

            pcall(function() ourWeaponIcon:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible) end)
            PlayerMapMarker.ApplyWeaponIconFullOpacity(Container, ourWeaponIcon)
            PlayerMapMarker.FixWeaponIconBrushSize(ourWeaponIcon)

            pcall(function()
                local function findWidgetInSwitcher(switcher, targetWidget)
                    if not switcher or not slua.isValid(switcher) then return nil end
                    if not switcher.GetChildrenCount or not switcher.GetChildAt then return nil end
                    local nChildren = switcher:GetChildrenCount()
                    for i = 0, math.max(nChildren - 1, 0) do
                        local child = switcher:GetChildAt(i)
                        if child and slua.isValid(child) then
                            if child == targetWidget then return i end
                            local function searchDescendant(w, target, depth)
                                if depth > 5 then return false end
                                if w == target then return true end
                                if not w.GetChildrenCount or not w.GetChildAt then return false end
                                local nc = w:GetChildrenCount()
                                for j = 0, math.max(nc - 1, 0) do
                                    local c = w:GetChildAt(j)
                                    if c and slua.isValid(c) and searchDescendant(c, target, depth + 1) then
                                        return true
                                    end
                                end
                                return false
                            end
                            if searchDescendant(child, targetWidget, 0) then return i end
                        end
                    end
                    return nil
                end

                for _, switcherName in ipairs({"Switcher_WeaponIcon", "WidgetSwitcher_Type", "WidgetSwitcher_Type2"}) do
                    local ws = Container[switcherName]
                    if ws and slua.isValid(ws) and ws.GetChildrenCount and ws.GetChildAt then
                        local foundIdx = findWidgetInSwitcher(ws, ourWeaponIcon)
                        if foundIdx then
                            if ws.SetActiveWidgetIndex then
                                ws:SetActiveWidgetIndex(foundIdx)
                                WidgetData._CachedSwitcherIndexes = WidgetData._CachedSwitcherIndexes or {}
                                WidgetData._CachedSwitcherIndexes[switcherName] = foundIdx
                            end
                        end
                    end
                end
            end)

            pcall(function()
                local parent = ourWeaponIcon
                for depth = 0, 8 do
                    if not parent or not slua.isValid(parent) then break end
                    if parent.GetParent then
                        local p = parent:GetParent()
                        if p and slua.isValid(p) then
                            local pStr = tostring(p)
                            if string.find(pStr, "WidgetSwitcher") then
                                if p.GetChildrenCount and p.GetChildAt then
                                    local nCh = p:GetChildrenCount()
                                    for i = 0, math.max(nCh - 1, 0) do
                                        local child = p:GetChildAt(i)
                                        if child and slua.isValid(child) then
                                            local function isDescendant(w, target, d)
                                                if d > 5 then return false end
                                                if w == target then return true end
                                                if not w.GetChildrenCount or not w.GetChildAt then return false end
                                                local nc = w:GetChildrenCount()
                                                for j = 0, math.max(nc - 1, 0) do
                                                    local c = w:GetChildAt(j)
                                                    if c and slua.isValid(c) and isDescendant(c, target, d + 1) then
                                                        return true
                                                    end
                                                end
                                                return false
                                            end
                                            if isDescendant(child, ourWeaponIcon, 0) then
                                                if p.SetActiveWidgetIndex then
                                                    p:SetActiveWidgetIndex(i)
                                                    WidgetData._CachedParentSwitchers = WidgetData._CachedParentSwitchers or {}
                                                    WidgetData._CachedParentSwitchers[tostring(p)] = {w = p, idx = i}
                                                end
                                                break
                                            end
                                        end
                                    end
                                end
                            end
                            parent = p
                        else
                            break
                        end
                    else
                        break
                    end
                end
            end)

            pcall(function()
                local parent = ourWeaponIcon
                for depth = 0, 8 do
                    pcall(function()
                        if parent.GetParent then
                            local p = parent:GetParent()
                            if p and slua.isValid(p) then
                                if p.SetWidgetVisibility then
                                    p:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
                                end
                                pcall(function() if p.SetRenderOpacity then p:SetRenderOpacity(1.0) end end)
                                pcall(function() if p.SetContentColorAndOpacity then p:SetContentColorAndOpacity(FLinearColor(1.0, 1.0, 1.0, 1.0)) end end)
                                pcall(function() if p.SetColorAndOpacity then p:SetColorAndOpacity(FLinearColor(1.0, 1.0, 1.0, 1.0)) end end)
                                pcall(function() if p.SetBrushTintColor then p:SetBrushTintColor(FLinearColor(1.0, 1.0, 1.0, 1.0)) end end)
                                pcall(function()
                                    local pBrush = p.Brush
                                    if pBrush and pBrush.TintColor then
                                        pBrush.TintColor = FLinearColor(1.0, 1.0, 1.0, 1.0)
                                        if p.SetBrush then p:SetBrush(pBrush) end
                                    end
                                end)
                                pcall(function() if p.InvalidateLayout then p:InvalidateLayout() end end)
                                parent = p
                            end
                        end
                    end)
                end
            end)
            pcall(function() if ourWeaponIcon.InvalidateLayout then ourWeaponIcon:InvalidateLayout() end end)

            pcall(function() if Container.UpdateWeapon then Container:UpdateWeapon() end end)
            pcall(function() if Container.RefreshWeapon then Container:RefreshWeapon() end end)
            
            WidgetData._LastWeaponID = winfo.WeaponID
            WidgetData._WeaponIconApplied = true
        end)
    end

    PlayerMapMarker._OBHeadWidgetClass = nil
    PlayerMapMarker._OBHeadWidgetLoadFailed = false
    PlayerMapMarker._bDumpedWidgetChildren = false

    function PlayerMapMarker.CreateESPWidget()
        if not PlayerMapMarker.ESPCanvas or not Game:IsValid(PlayerMapMarker.ESPCanvas) then
            return nil
        end

        if PlayerMapMarker._OBHeadWidgetLoadFailed then
            return nil
        end

        if not PlayerMapMarker._OBHeadWidgetClass then
            pcall(function()
                local Path = "/Game/BluePrints/UI/OBUI/Item/OB_PlayerHeadHPItem_UIBP.OB_PlayerHeadHPItem_UIBP"
                local uClass = slua.loadClass(Path)
                if uClass then
                    PlayerMapMarker._OBHeadWidgetClass = uClass
                end
            end)
            if not PlayerMapMarker._OBHeadWidgetClass then
                PlayerMapMarker._OBHeadWidgetLoadFailed = true
                return nil
            end
        else
            local bValid = false
            pcall(function() bValid = slua.isValid(PlayerMapMarker._OBHeadWidgetClass) end)
            if not bValid then
                PlayerMapMarker._OBHeadWidgetLoadFailed = true
                PlayerMapMarker._OBHeadWidgetClass = nil
                return nil
            end
        end

        local Widget = nil
        pcall(function()
            local STExtraBlueprintFunctionLibrary = import("STExtraBlueprintFunctionLibrary")
            local PC = PlayerMapMarker.GetMyPlayerController()
            local OuterObj = IsValid(PC) and PC.Object or PlayerMapMarker.ESPCanvas
            Widget = STExtraBlueprintFunctionLibrary.CreateWidgetByClass(PlayerMapMarker._OBHeadWidgetClass, OuterObj)
        end)

        if not Widget then
            return nil
        end

        pcall(function() Widget:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible) end)
        pcall(function() Widget:SetRenderOpacity(1.0) end)

        local NameText = nil
        local HealthFill = nil
        local bIsOriginalProgressBar = false

        pcall(function()
            NameText = Widget.TextBlock_TeamName
            if NameText and slua.isValid(NameText) then
                pcall(function() NameText:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible) end)
            end
            if Widget.TextBlock_PlayerName and slua.isValid(Widget.TextBlock_PlayerName) then
                pcall(function() Widget.TextBlock_PlayerName:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible) end)
            end

            local WS_Type = Widget.WidgetSwitcher_Type
            local WS_Type2 = Widget.WidgetSwitcher_Type2
            if WS_Type and slua.isValid(WS_Type) then
                pcall(function()
                    if WS_Type.SetActiveWidgetIndex then
                        WS_Type:SetActiveWidgetIndex(PlayerMapMarker.HPWidgetSwitcherTypeIndex)
                    end
                end)
            end
            if WS_Type2 and slua.isValid(WS_Type2) then
                pcall(function()
                    if WS_Type2.SetActiveWidgetIndex then
                        WS_Type2:SetActiveWidgetIndex(PlayerMapMarker.HPWidgetSwitcherType2Index)
                    end
                end)
            end

            local SizeBox_HP = Widget.SizeBox_HP
            if SizeBox_HP and slua.isValid(SizeBox_HP) then
                pcall(function() SizeBox_HP:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible) end)
                pcall(function() SizeBox_HP:SetHeightOverride(6) end)
                pcall(function() SizeBox_HP:SetWidthOverride(100) end)

                local ExistingChild = nil
                pcall(function()
                    if SizeBox_HP.GetContent then
                        ExistingChild = SizeBox_HP:GetContent()
                    end
                end)
                if not ExistingChild then
                    pcall(function()
                        if SizeBox_HP.GetChildAt then
                            ExistingChild = SizeBox_HP:GetChildAt(0)
                        end
                    end)
                end

                if ExistingChild and slua.isValid(ExistingChild) then
                    pcall(function() ExistingChild:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible) end)
                    pcall(function() ExistingChild:SetRenderOpacity(1.0) end)

                    local FoundPB = PlayerMapMarker.FindProgressBarInWidget(ExistingChild, 0, 5)
                    if FoundPB and slua.isValid(FoundPB) then
                        HealthFill = FoundPB
                        bIsOriginalProgressBar = true
                        pcall(function() FoundPB:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible) end)
                        pcall(function() FoundPB:SetRenderOpacity(1.0) end)
                    else
                        local PB = CGame:NewObjectFromPath("/Script/UMG.ProgressBar", ExistingChild)
                        if PB then
                            pcall(function() PB:SetFillColorAndOpacity(FLinearColor(0, 1, 0, 1)) end)
                            pcall(function() PB:SetPercent(1.0) end)
                            pcall(function() PB:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible) end)
                            pcall(function() PB:SetRenderOpacity(1.0) end)
                            pcall(function() PB:SetDesiredSizeOverride(FVector2D(100, 6)) end)
                            pcall(function() ExistingChild:AddChild(PB) end)
                            HealthFill = PB
                        end
                    end
                else
                    local PB = CGame:NewObjectFromPath("/Script/UMG.ProgressBar", SizeBox_HP)
                    if PB then
                        pcall(function() PB:SetFillColorAndOpacity(FLinearColor(0, 1, 0, 1)) end)
                        pcall(function() PB:SetPercent(1.0) end)
                        pcall(function() PB:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible) end)
                        pcall(function() PB:SetRenderOpacity(1.0) end)
                        pcall(function() PB:SetDesiredSizeOverride(FVector2D(100, 6)) end)

                        local bUsedSetContent = false
                        pcall(function()
                            if SizeBox_HP.SetContent then
                                SizeBox_HP:SetContent(PB)
                                bUsedSetContent = true
                            end
                        end)
                        if not bUsedSetContent then
                            pcall(function() SizeBox_HP:AddChild(PB) end)
                        end
                        HealthFill = PB
                    end
                end
            end
        end)

        local WidgetData = {
            Container = Widget,
            NameText = NameText,
            HealthFill = HealthFill,
            IsGameWidget = true,
            IsOriginalProgressBar = bIsOriginalProgressBar,
            HasChildren = (NameText ~= nil)
        }
        return WidgetData
    end

    PlayerMapMarker._CanvasScaleX = 1.0
    PlayerMapMarker._CanvasScaleY = 1.0
    PlayerMapMarker._CanvasOffsetX = 0.0
    PlayerMapMarker._CanvasOffsetY = 0.0

    function PlayerMapMarker.UpdateCanvasTransform(PC)
        if not PlayerMapMarker.ESPCanvas or not Game:IsValid(PlayerMapMarker.ESPCanvas) then
            return
        end

        local success = false

        pcall(function()
            local SBL = SlateBlueprintLibrary
            if SBL and SBL.AbsoluteToLocal then
                local cg = PlayerMapMarker.ESPCanvas:GetCachedGeometry()
                if cg then
                    local pt0 = SBL.AbsoluteToLocal(cg, FVector2D(0, 0))
                    local pt1 = SBL.AbsoluteToLocal(cg, FVector2D(100, 100))
                    if pt0 and pt1 then
                        PlayerMapMarker._CanvasScaleX = (pt1.X - pt0.X) / 100
                        PlayerMapMarker._CanvasScaleY = (pt1.Y - pt0.Y) / 100
                        PlayerMapMarker._CanvasOffsetX = pt0.X
                        PlayerMapMarker._CanvasOffsetY = pt0.Y
                        success = true
                    end
                end
            end
        end)

        if not success then
            pcall(function()
                local WLL = WidgetLayoutLibrary
                if WLL and WLL.ScreenToWidgetLocal then
                    local cg = PlayerMapMarker.ESPCanvas:GetCachedGeometry()
                    if cg then
                        local pt0 = FVector2D(0, 0)
                        local pt1 = FVector2D(0, 0)
                        WLL.ScreenToWidgetLocal(PC, cg, FVector2D(0, 0), pt0)
                        WLL.ScreenToWidgetLocal(PC, cg, FVector2D(100, 100), pt1)
                        PlayerMapMarker._CanvasScaleX = (pt1.X - pt0.X) / 100
                        PlayerMapMarker._CanvasScaleY = (pt1.Y - pt0.Y) / 100
                        PlayerMapMarker._CanvasOffsetX = pt0.X
                        PlayerMapMarker._CanvasOffsetY = pt0.Y
                        success = true
                    end
                end
            end)
        end

        if not success then
            local scale = 1.0
            local WLL = WidgetLayoutLibrary
            if WLL and WLL.GetViewportScale then
                scale = WLL.GetViewportScale(PC) or 1.0
            end
            PlayerMapMarker._CanvasScaleX = 1.0 / scale
            PlayerMapMarker._CanvasScaleY = 1.0 / scale
            PlayerMapMarker._CanvasOffsetX = 0
            PlayerMapMarker._CanvasOffsetY = 0
        end
    end

    function PlayerMapMarker.ScreenPixelToCanvasLocal(PC, ScreenPixelPos)
        if not ScreenPixelPos then return FVector2D(0, 0) end
        local scaleX = PlayerMapMarker._CanvasScaleX or 1.0
        local scaleY = PlayerMapMarker._CanvasScaleY or 1.0
        local offsetX = PlayerMapMarker._CanvasOffsetX or 0
        local offsetY = PlayerMapMarker._CanvasOffsetY or 0
        return FVector2D(ScreenPixelPos.X * scaleX + offsetX, ScreenPixelPos.Y * scaleY + offsetY)
    end

    function PlayerMapMarker.ProjectWorldToCanvasLocal(PC, WorldLoc)
        if not IsValid(PC) or not WorldLoc then return false, FVector2D(0, 0) end
        
        local ScreenPixelPos = FVector2D(0, 0)
        local bOK = false

        pcall(function()
            local res = PC:ProjectWorldLocationToScreen(WorldLoc, ScreenPixelPos, true)
            if res == true or res == 1 or (ScreenPixelPos and (ScreenPixelPos.X ~= 0 or ScreenPixelPos.Y ~= 0)) then
                bOK = true
            end
        end)

        if not bOK or not ScreenPixelPos or (ScreenPixelPos.X == 0 and ScreenPixelPos.Y == 0) then
            return false, FVector2D(0, 0)
        end

        local CanvasLocalPos = PlayerMapMarker.ScreenPixelToCanvasLocal(PC, ScreenPixelPos)
        return true, CanvasLocalPos
    end

    function PlayerMapMarker.GetDynamicViewportSize(PC)
        local width, height = 0, 0
        
        if PlayerMapMarker.ESPCanvas and Game:IsValid(PlayerMapMarker.ESPCanvas) then
            pcall(function()
                local cg = PlayerMapMarker.ESPCanvas:GetCachedGeometry()
                if cg and cg.GetLocalSize then
                    local sz = cg:GetLocalSize()
                    if sz and sz.X and sz.X > 200 then
                        width = sz.X
                        height = sz.Y
                    end
                end
            end)
        end

        if width > 200 then return width, height end

        pcall(function()
            local WLL = WidgetLayoutLibrary
            if WLL and WLL.GetViewportSize then
                local sz = WLL.GetViewportSize(PC or PlayerMapMarker.GetMyPlayerController())
                if sz and sz.X and sz.X > 200 then
                    width = sz.X
                    height = sz.Y
                end
            end
        end)

        if width > 200 then
            pcall(function()
                local WLL = WidgetLayoutLibrary
                if WLL and WLL.GetViewportScale then
                    local scale = WLL.GetViewportScale(PC or PlayerMapMarker.GetMyPlayerController())
                    if scale and type(scale) == "number" and scale > 0 and scale ~= 1.0 then
                        width = width / scale
                        height = height / scale
                    end
                end
            end)
            return width, height
        end

        return PlayerMapMarker._cachedViewportW or 1920, PlayerMapMarker._cachedViewportH or 1080
    end

    function PlayerMapMarker.UpdateESPPositionWithPC(Widget, WorldLoc, PC, CanvasPos)
        if not Widget or not IsValid(PC) then return false end
        local Container = Widget.Container or Widget

        local bOnScreen = true
        if not CanvasPos then
            if not WorldLoc then return false end
            bOnScreen, CanvasPos = PlayerMapMarker.ProjectWorldToCanvasLocal(PC, WorldLoc)
        end

        if not bOnScreen then
            pcall(function() Container:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed) end)
            return false
        end

        pcall(function()
            if PlayerMapMarker.ESPCanvas and Game:IsValid(PlayerMapMarker.ESPCanvas) then
                local ptr = tostring(Container)
                local Slot = PlayerMapMarker.ESPWidgetPtrs[ptr]

                if not Slot or not slua.isValid(Slot) or type(Slot) == "boolean" then
                    local addedSlot = PlayerMapMarker.ESPCanvas:AddChildToCanvas(Container)
                    if addedSlot and slua.isValid(addedSlot) then
                        Slot = addedSlot
                        PlayerMapMarker.ESPWidgetPtrs[ptr] = addedSlot
                        if type(Widget) == "table" then
                            Widget.Slot = addedSlot
                        end
                        
                        pcall(function() Slot:SetAutoSize(true) end)
                        pcall(function() Slot.bAutoSize = true end)
                        local align = FVector2D(0.5, 1.0)
                        pcall(function() Slot.Alignment = align end)
                        pcall(function() Slot:SetAlignment(align) end)
                        pcall(function() Slot:SetAlignment(0.5, 1.0) end)
                        pcall(function() Slot:SetZOrder(PlayerMapMarker.ESPWidgetZOrder or 20) end)
                    end
                end

                Container:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
                
                if not Widget._OffsetResetDone then
                    pcall(function() Container:SetRenderTranslation(FVector2D(0.0, 0.0)) end)
                    if Widget and type(Widget) == "table" then
                        if Widget.NameText and slua.isValid(Widget.NameText) then
                            pcall(function() Widget.NameText:SetRenderTranslation(FVector2D(0.0, 0.0)) end)
                        end
                        if Widget.HealthFill and slua.isValid(Widget.HealthFill) then
                            pcall(function() Widget.HealthFill:SetRenderTranslation(FVector2D(0.0, 0.0)) end)
                        end
                    end
                    
                    pcall(function() Container.RenderTransformPivot = FVector2D(0.5, 1.0) end)
                    pcall(function() Container:SetRenderTransformPivot(FVector2D(0.5, 1.0)) end)
                    Widget._OffsetResetDone = true
                end


                if not Slot or not slua.isValid(Slot) or Slot == PlayerMapMarker.ESPCanvas then
                    if Widget and type(Widget) == "table" and Widget.Slot and slua.isValid(Widget.Slot) then
                        Slot = Widget.Slot
                    elseif Container.Slot and slua.isValid(Container.Slot) then
                        Slot = Container.Slot
                    end
                end

                if Slot and slua.isValid(Slot) and Slot ~= PlayerMapMarker.ESPCanvas then
                    local finalX = CanvasPos.X + (PlayerMapMarker.ESPAnchorOffsetX or 0)
                    local finalY = CanvasPos.Y + (PlayerMapMarker.ESPAnchorOffsetY or 0)
                    if Widget and type(Widget) == "table" then
                        if not Widget._CachedPosVec then
                            Widget._CachedPosVec = FVector2D(finalX, finalY)
                        else
                            Widget._CachedPosVec.X = finalX
                            Widget._CachedPosVec.Y = finalY
                        end
                        pcall(function() Slot:SetPosition(Widget._CachedPosVec) end)
                    else
                        pcall(function() Slot:SetPosition(FVector2D(finalX, finalY)) end)
                    end
                end
            end
        end)
        return true
    end

    function PlayerMapMarker.UpdateESPText(Widget, Text)
        if not Widget then return end
        if Widget._LastESPText == Text then return end
        Widget._LastESPText = Text

        local function applyTextAndCenter(w, txt)
            if not w or not slua.isValid(w) then return end
            pcall(function() w:SetText(txt) end)
            pcall(function() if w.SetJustification then w:SetJustification(1) end end)
            pcall(function()
                local slot = w.Slot
                if slot and slot.SetHorizontalAlignment then
                    slot:SetHorizontalAlignment(1)
                end
            end)
            pcall(function()
                w:SetRenderTranslation(FVector2D(PlayerMapMarker.ESPTextOffsetX or 0, PlayerMapMarker.ESPTextOffsetY or 0))
            end)
        end

        if Widget.NameText and slua.isValid(Widget.NameText) then
            applyTextAndCenter(Widget.NameText, Text)
        end
        if Widget.IsGameWidget and Widget.Container then
            pcall(function()
                local W = Widget.Container
                if W and slua.isValid(W) then
                    if W.SetPlayerName then
                        local Name = Text
                        local idx = string.find(Text, " %[")
                        if idx then Name = string.sub(Text, 1, idx - 1) end
                        W:SetPlayerName(Name)
                    end

                    applyTextAndCenter(W.TextBlock_TeamName, Text)
                    applyTextAndCenter(W.TextBlock_PlayerName, Text)

                    pcall(function()
                        if not Widget._CachedVBChildren then
                            local list = {}
                            local VB = PlayerMapMarker._FindNamedWidgetInTree(W, "VerticalBox_0", 8)
                            if VB and slua.isValid(VB) and VB.GetChildrenCount then
                                local nChildren = VB:GetChildrenCount()
                                for i = 0, nChildren - 1 do
                                    local child = VB:GetChildAt(i)
                                    if child and slua.isValid(child) and child.SetText then
                                        table.insert(list, child)
                                    end
                                end
                            end
                            Widget._CachedVBChildren = list
                        end
                        for _, child in ipairs(Widget._CachedVBChildren) do
                            applyTextAndCenter(child, Text)
                        end
                    end)

                    pcall(function()
                        if not Widget._CachedHBChildren then
                            local list = {}
                            local HB = PlayerMapMarker._FindNamedWidgetInTree(W, "HorizontalBox_TeamName", 8)
                            if HB and slua.isValid(HB) and HB.GetChildrenCount then
                                local nChildren = HB:GetChildrenCount()
                                for i = 0, nChildren - 1 do
                                    local child = HB:GetChildAt(i)
                                    if child and slua.isValid(child) and child.SetText then
                                        table.insert(list, child)
                                    end
                                end
                            end
                            Widget._CachedHBChildren = list
                        end
                        for _, child in ipairs(Widget._CachedHBChildren) do
                            applyTextAndCenter(child, Text)
                        end
                    end)
                end
            end)
        end
    end

    function PlayerMapMarker.UpdateESPHealth(Widget, pct)
        if not Widget then return end
        if Widget.LastPct == pct then return end
        Widget.LastPct = pct

        if PlayerMapMarker.bForceSwitcherIndexEveryUpdate and Widget.Container then
            pcall(function()
                local W = Widget.Container
                if W and slua.isValid(W) then
                    if not Widget._SwitcherSetupDone then
                        if W.WidgetSwitcher_Type and slua.isValid(W.WidgetSwitcher_Type) then
                            pcall(function()
                                if W.WidgetSwitcher_Type.SetActiveWidgetIndex then
                                    W.WidgetSwitcher_Type:SetActiveWidgetIndex(PlayerMapMarker.HPWidgetSwitcherTypeIndex)
                                end
                            end)
                        end
                        if W.WidgetSwitcher_Type2 and slua.isValid(W.WidgetSwitcher_Type2) then
                            pcall(function()
                                if W.WidgetSwitcher_Type2.SetActiveWidgetIndex then
                                    W.WidgetSwitcher_Type2:SetActiveWidgetIndex(PlayerMapMarker.HPWidgetSwitcherType2Index)
                                end
                            end)
                        end
                        if W.SizeBox_HP and slua.isValid(W.SizeBox_HP) then
                            pcall(function() W.SizeBox_HP:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible) end)
                        end
                        Widget._SwitcherSetupDone = true
                    end
                end
            end)
        end

        if Widget.HealthFill then
            local bValid = false
            pcall(function() bValid = slua.isValid(Widget.HealthFill) end)
            if bValid then
                local bHasSetPercent = false
                pcall(function() bHasSetPercent = (Widget.HealthFill.SetPercent ~= nil) end)
                if not bHasSetPercent then
                    local PB = PlayerMapMarker.FindProgressBarInWidget(Widget.HealthFill, 0, 5)
                    if PB and slua.isValid(PB) then
                        Widget.HealthFill = PB
                    else
                        return
                    end
                end

                pcall(function()
                    if Widget.HealthFill.SetWidgetVisibility then
                        Widget.HealthFill:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
                    end
                    if Widget.HealthFill.SetRenderOpacity then
                        Widget.HealthFill:SetRenderOpacity(1.0)
                    end
                    if Widget.HealthFill.SetPercent then
                        Widget.HealthFill:SetPercent(pct)
                        if not Widget.IsOriginalProgressBar then
                            local color
                            if pct > 0.5 then
                                color = FLinearColor(0, 1, 0, 1)
                            elseif pct > 0.25 then
                                color = FLinearColor(1, 0.8, 0, 1)
                            else
                                color = FLinearColor(1, 0, 0, 1)
                            end
                            if Widget.HealthFill.SetFillColorAndOpacity then
                                Widget.HealthFill:SetFillColorAndOpacity(color)
                            end
                        end
                    end
                end)
            end
            return
        end
    end

    function PlayerMapMarker.RemoveESPWidget(Widget)
        if not Widget then return end
        local Container = Widget.Container or Widget
        pcall(function()
            local ptr = tostring(Container)
            PlayerMapMarker.ESPWidgetPtrs[ptr] = nil
            Container:RemoveFromParent()
            Container:ConditionalBeginDestroy()
        end)
    end

    function PlayerMapMarker.CreateSnapLine()
        if not PlayerMapMarker.ESPCanvas or not Game:IsValid(PlayerMapMarker.ESPCanvas) then return nil end

        local Border = nil
        pcall(function()
            Border = CGame:NewObjectFromPath("/Script/UMG.Border", PlayerMapMarker.ESPCanvas)
        end)
        if not Border or not slua.isValid(Border) then return nil end

        local color = PlayerMapMarker.SnapLineColor or FLinearColor(1.0, 1.0, 1.0, PlayerMapMarker.SnapLineOpacity or 0.7)
        pcall(function() Border:SetBrushColor(color) end)
        pcall(function() Border:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible) end)
        
        pcall(function() Border.RenderTransformPivot = FVector2D(0.0, 0.5) end)
        pcall(function() Border:SetRenderTransformPivot(FVector2D(0.0, 0.5)) end)

        local Slot = nil
        pcall(function()
            Slot = PlayerMapMarker.ESPCanvas:AddChildToCanvas(Border)
            if Slot then
                Slot:SetAutoSize(false)
                Slot:SetZOrder(1)
            end
        end)

        return { Widget = Border, Slot = Slot }
    end

    function PlayerMapMarker.GetSnapLineStartPos(PC)
        local screenPixelW, screenPixelH = 0, 0
        local scale = 1.0

        pcall(function()
            if PC and PC.GetViewportSize then
                local vs = FVector2D(0, 0)
                PC:GetViewportSize(vs)
                if vs and vs.X and vs.X > 200 then
                    screenPixelW = vs.X
                    screenPixelH = vs.Y
                end
            end
        end)

        if screenPixelW <= 200 then
            pcall(function()
                local WLL = WidgetLayoutLibrary
                if WLL and WLL.GetViewportSize then
                    local vs = WLL.GetViewportSize(PC)
                    if vs and vs.X and vs.X > 200 then
                        screenPixelW = vs.X
                        screenPixelH = vs.Y
                    end
                end
            end)
        end

        pcall(function()
            local WLL = WidgetLayoutLibrary
            if WLL and WLL.GetViewportScale then
                local s = WLL.GetViewportScale(PC)
                if s and type(s) == "number" and s > 0 then scale = s end
            end
        end)

        if screenPixelW <= 200 then
            screenPixelW = (PlayerMapMarker._cachedViewportW or 1920) * scale
            screenPixelH = (PlayerMapMarker._cachedViewportH or 1080) * scale
        end

        if not PlayerMapMarker._CachedTopCenterPixel then
            PlayerMapMarker._CachedTopCenterPixel = FVector2D(0, 0)
        end
        PlayerMapMarker._CachedTopCenterPixel.X = screenPixelW / 2.0
        PlayerMapMarker._CachedTopCenterPixel.Y = (PlayerMapMarker.SnapLineOriginY or 50) * scale

        local fromCanvasPos = PlayerMapMarker.ScreenPixelToCanvasLocal(PC, PlayerMapMarker._CachedTopCenterPixel)
        local fromX = fromCanvasPos.X + (PlayerMapMarker.SnapLineOriginOffsetX or 0)
        local fromY = fromCanvasPos.Y

        return fromX, fromY
    end

    function PlayerMapMarker.UpdateSnapLine(KeyStr, CanvasPos, bOnScreen, fromX, fromY)
        if not PlayerMapMarker.bUseSnapLines then return end
        if not PlayerMapMarker.ESPCanvas or not Game:IsValid(PlayerMapMarker.ESPCanvas) then return end

        local LineData = PlayerMapMarker.SnapLineWidgets[KeyStr]

        if not bOnScreen or not CanvasPos then
            if LineData and LineData.Widget and slua.isValid(LineData.Widget) then
                pcall(function() LineData.Widget:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed) end)
            end
            return
        end

        local bIsNew = false
        if not LineData then
            LineData = PlayerMapMarker.CreateSnapLine()
            if not LineData or not LineData.Widget or not LineData.Slot then return end
            PlayerMapMarker.SnapLineWidgets[KeyStr] = LineData
            bIsNew = true
        end

        local Widget = LineData.Widget
        local Slot = LineData.Slot

        pcall(function() Widget:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible) end)
        
        if not LineData._PivotSet then
            pcall(function() Widget.RenderTransformPivot = FVector2D(0.0, 0.5) end)
            pcall(function() Widget:SetRenderTransformPivot(FVector2D(0.0, 0.5)) end)
            LineData._PivotSet = true
        end

        local toX = CanvasPos.X + (PlayerMapMarker.SnapLineHeadOffsetX or 0)
        local toY = CanvasPos.Y + (PlayerMapMarker.SnapLineHeadOffsetY or 0)

        local dx = toX - fromX
        local dy = toY - fromY
        local length = math.sqrt(dx * dx + dy * dy)
        local thickness = PlayerMapMarker.SnapLineThickness or 1.5

        local angle_rad = 0
        if math.atan2 then
            angle_rad = math.atan2(dy, dx)
        else
            angle_rad = math.atan(dy, dx)
        end
        local angle = angle_rad * (180.0 / math.pi)

        if not LineData._CachedPosVec then
            LineData._CachedPosVec = FVector2D(fromX, fromY - thickness / 2.0)
            LineData._CachedSizeVec = FVector2D(length, thickness)
        else
            LineData._CachedPosVec.X = fromX
            LineData._CachedPosVec.Y = fromY - thickness / 2.0
            LineData._CachedSizeVec.X = length
            LineData._CachedSizeVec.Y = thickness
        end

        pcall(function() 
            Slot:SetPosition(LineData._CachedPosVec) 
            Slot:SetSize(LineData._CachedSizeVec)
            if bIsNew then
                Slot:SetZOrder(1)
            end
        end)
        pcall(function() Widget:SetRenderAngle(angle) end)
    end

    function PlayerMapMarker.RemoveSnapLine(KeyStr)
        local LineData = PlayerMapMarker.SnapLineWidgets[KeyStr]
        if LineData and LineData.Widget and slua.isValid(LineData.Widget) then
            pcall(function()
                LineData.Widget:RemoveFromParent()
                LineData.Widget:ConditionalBeginDestroy()
            end)
            PlayerMapMarker.SnapLineWidgets[KeyStr] = nil
        end
    end

    function PlayerMapMarker.ClearAllSnapLines()
        for KeyStr, LineData in pairs(PlayerMapMarker.SnapLineWidgets) do
            if LineData and LineData.Widget and slua.isValid(LineData.Widget) then
                pcall(function()
                    LineData.Widget:RemoveFromParent()
                    LineData.Widget:ConditionalBeginDestroy()
                end)
            end
        end
        PlayerMapMarker.SnapLineWidgets = {}
    end

    -- ===== FOV CIRCLE FUNCTIONS =====
    function PlayerMapMarker.CreateLineWidget(color, zOrder)
        if not PlayerMapMarker.ESPCanvas or not Game:IsValid(PlayerMapMarker.ESPCanvas) then return nil end
        local Border = nil
        pcall(function()
            Border = CGame:NewObjectFromPath("/Script/UMG.Border", PlayerMapMarker.ESPCanvas)
        end)
        if not Border or not slua.isValid(Border) then return nil end
        local FVector2D = _G.FVector2D or import("Vector2D")
        pcall(function()
            Border:SetBrushColor(color)
            Border:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
            Border:SetRenderTransformPivot(FVector2D and FVector2D(0.0,0.5) or {X=0,Y=0.5})
        end)
        local Slot = nil
        pcall(function()
            Slot = PlayerMapMarker.ESPCanvas:AddChildToCanvas(Border)
            if Slot then
                Slot:SetAutoSize(false)
                Slot:SetZOrder(zOrder or 1)
            end
        end)
        if not Slot then return nil end
        return { Widget = Border, Slot = Slot }
    end

    function PlayerMapMarker.DrawLine(ld, x1, y1, x2, y2, thickness)
        if not ld or not ld.Widget or not ld.Slot then return end
        local dx = x2 - x1
        local dy = y2 - y1
        local len = math.sqrt(dx*dx + dy*dy)
        if len < 0.5 then return end
        local ang = (math.atan2 and math.atan2(dy,dx) or math.atan(dy,dx)) * (180.0/math.pi)
        if not ld._CachedPos then
            ld._CachedPos = FVector2D and FVector2D(0, 0) or {X=0, Y=0}
            ld._CachedSize = FVector2D and FVector2D(0, 0) or {X=0, Y=0}
        end
        local pos, sz = ld._CachedPos, ld._CachedSize
        pos.X, pos.Y = x1, y1 - thickness / 2
        sz.X, sz.Y = len, thickness
        pcall(function()
            ld.Slot:SetPosition(pos)
            ld.Slot:SetSize(sz)
            ld.Widget:SetRenderAngle(ang)
            if not ld._VisSet then
                ld.Widget:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
                ld._VisSet = true
            end
        end)
    end

    function PlayerMapMarker.DestroyLineWidget(ld)
        if ld and ld.Widget and slua.isValid(ld.Widget) then
            pcall(function()
                ld.Widget:RemoveFromParent()
                ld.Widget:ConditionalBeginDestroy()
            end)
        end
    end

    function PlayerMapMarker.HideLineWidget(ld)
        if ld and ld.Widget and slua.isValid(ld.Widget) then
            pcall(function() ld.Widget:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed) end)
        end
    end

    function PlayerMapMarker.GetScreenCenterForESP(PC)
        local W, H = 0, 0
        local FVector2D = _G.FVector2D or import("Vector2D")
        pcall(function()
            if PC and PC.GetViewportSize then
                local vs = FVector2D and FVector2D(0,0) or {X=0,Y=0}
                PC:GetViewportSize(vs)
                if vs and vs.X and vs.X > 200 then
                    W, H = vs.X, vs.Y
                end
            end
        end)
        if W <= 200 then
            pcall(function()
                local WidgetLayoutLibrary = import("WidgetLayoutLibrary")
                if WidgetLayoutLibrary and WidgetLayoutLibrary.GetViewportSize then
                    local vs = WidgetLayoutLibrary.GetViewportSize(PC)
                    if vs and vs.X and vs.X > 200 then
                        W, H = vs.X, vs.Y
                    end
                end
            end)
        end
        if W <= 200 then
            W = PlayerMapMarker._cachedViewportW or 1920
            H = PlayerMapMarker._cachedViewportH or 1080
        end
        local sx = PlayerMapMarker._CanvasScaleX or 1.0
        local sy = PlayerMapMarker._CanvasScaleY or 1.0
        local ox = PlayerMapMarker._CanvasOffsetX or 0
        local oy = PlayerMapMarker._CanvasOffsetY or 0
        local cx = (W/2) * sx + ox
        local cy = (H/2) * sy + oy
        return {X=cx, Y=cy}, W, H
    end

    function PlayerMapMarker.UpdateFOVCircle(cx, cy)
        if not PlayerMapMarker.bUseFOVCircle then return end
        local segments = PlayerMapMarker.FOVCircleSegments or 36
        local thickness = PlayerMapMarker.FOVCircleThickness or 1.5
        local color = PlayerMapMarker.FOVCircleColor
        local fov = (_G.AimbotConfig and _G.AimbotConfig.FOV) or 30
        local viewW = PlayerMapMarker._cachedViewportW or 1920
        local radius = (fov / 100.0) * (viewW * 0.28)
        for i = 1, segments do
            local a1 = ((i-1)/segments) * (2*math.pi)
            local a2 = (i/segments) * (2*math.pi)
            if not PlayerMapMarker.FOVCircleLines[i] then
                PlayerMapMarker.FOVCircleLines[i] = PlayerMapMarker.CreateLineWidget(color, 0)
            end
            PlayerMapMarker.DrawLine(PlayerMapMarker.FOVCircleLines[i],
                cx + math.cos(a1)*radius, cy + math.sin(a1)*radius,
                cx + math.cos(a2)*radius, cy + math.sin(a2)*radius, thickness)
        end
    end

    function PlayerMapMarker.RemoveFOVCircle()
        for _, ld in pairs(PlayerMapMarker.FOVCircleLines) do
            PlayerMapMarker.DestroyLineWidget(ld)
        end
        PlayerMapMarker.FOVCircleLines = {}
    end

    -- ===== DIRECTIONAL ARROWS =====
    function PlayerMapMarker.GetArrowAngleRad(PC, WorldLoc, CenterCanvas)
        local angle_rad = 0
        local FVector2D = _G.FVector2D or import("Vector2D")
        local Pix = FVector2D and FVector2D(0,0) or {X=0,Y=0}
        local bOK = false
        pcall(function()
            local res = PC:ProjectWorldLocationToScreen(WorldLoc, Pix, true)
            bOK = (res == true or res == 1)
        end)
        if bOK then
            local sx = PlayerMapMarker._CanvasScaleX or 1.0
            local sy = PlayerMapMarker._CanvasScaleY or 1.0
            local ox = PlayerMapMarker._CanvasOffsetX or 0
            local oy = PlayerMapMarker._CanvasOffsetY or 0
            local cpX = Pix.X * sx + ox
            local cpY = Pix.Y * sy + oy
            local dx = cpX - CenterCanvas.X
            local dy = cpY - CenterCanvas.Y
            if math.abs(dx) > 0.1 or math.abs(dy) > 0.1 then
                angle_rad = math.atan2 and math.atan2(dy,dx) or math.atan(dy,dx)
            end
        else
            pcall(function()
                local CamMgr = PC:GetPlayerCameraManager()
                if not IsValid(CamMgr) then return end
                local CamLoc = CamMgr:GetCameraLocation()
                local CamRot = CamMgr:GetCameraRotation()
                local dx3 = WorldLoc.X - CamLoc.X
                local dy3 = WorldLoc.Y - CamLoc.Y
                local eYaw = math.atan2 and math.atan2(dy3,dx3) or math.atan(dy3,dx3)
                local cYaw = math.rad(CamRot.Yaw)
                local delta = eYaw - cYaw
                while delta > math.pi do delta = delta - 2*math.pi end
                while delta < -math.pi do delta = delta + 2*math.pi end
                angle_rad = delta + math.pi
                while angle_rad > math.pi do angle_rad = angle_rad - 2*math.pi end
                while angle_rad < -math.pi do angle_rad = angle_rad + 2*math.pi end
            end)
        end
        return angle_rad
    end

    function PlayerMapMarker.UpdateArrow(KeyStr, WorldLoc, PC, CenterCanvas)
        if not PlayerMapMarker.bUseArrows then return end
        local color = PlayerMapMarker.ArrowColor
        local arr = PlayerMapMarker.ArrowWidgets[KeyStr]
        if not arr then
            arr = {
                stem = PlayerMapMarker.CreateLineWidget(color, 2),
                wL = PlayerMapMarker.CreateLineWidget(color, 2),
                wR = PlayerMapMarker.CreateLineWidget(color, 2),
            }
            if not arr.stem or not arr.wL or not arr.wR then
                PlayerMapMarker.DestroyLineWidget(arr.stem)
                PlayerMapMarker.DestroyLineWidget(arr.wL)
                PlayerMapMarker.DestroyLineWidget(arr.wR)
                return
            end
            PlayerMapMarker.ArrowWidgets[KeyStr] = arr
        end
        if not WorldLoc then
            PlayerMapMarker.HideLineWidget(arr.stem)
            PlayerMapMarker.HideLineWidget(arr.wL)
            PlayerMapMarker.HideLineWidget(arr.wR)
            return
        end
        local a = PlayerMapMarker.GetArrowAngleRad(PC, WorldLoc, CenterCanvas)
        local radius = PlayerMapMarker.FOVCircleRadius or 150.0
        local stemLen = PlayerMapMarker.ArrowStemLen or 20.0
        local headLen = PlayerMapMarker.ArrowHeadLen or 10.0
        local wingAng = PlayerMapMarker.ArrowWingAngle or 0.45
        local offset = PlayerMapMarker.ArrowOffset or 4.0
        local thick = PlayerMapMarker.ArrowThickness or 2.5
        local cx = CenterCanvas.X
        local cy = CenterCanvas.Y
        local baseX = cx + math.cos(a) * radius
        local baseY = cy + math.sin(a) * radius
        local tipX = cx + math.cos(a) * (radius + offset + stemLen)
        local tipY = cy + math.sin(a) * (radius + offset + stemLen)
        local backL = a + math.pi - wingAng
        local backR = a + math.pi + wingAng
        local wLX = tipX + math.cos(backL) * headLen
        local wLY = tipY + math.sin(backL) * headLen
        local wRX = tipX + math.cos(backR) * headLen
        local wRY = tipY + math.sin(backR) * headLen
        PlayerMapMarker.DrawLine(arr.stem, baseX, baseY, tipX, tipY, thick)
        PlayerMapMarker.DrawLine(arr.wL, tipX, tipY, wLX, wLY, thick)
        PlayerMapMarker.DrawLine(arr.wR, tipX, tipY, wRX, wRY, thick)
    end

    function PlayerMapMarker.RemoveArrow(KeyStr)
        local arr = PlayerMapMarker.ArrowWidgets[KeyStr]
        if arr then
            PlayerMapMarker.DestroyLineWidget(arr.stem)
            PlayerMapMarker.DestroyLineWidget(arr.wL)
            PlayerMapMarker.DestroyLineWidget(arr.wR)
        end
        PlayerMapMarker.ArrowWidgets[KeyStr] = nil
    end

    function PlayerMapMarker.ClearAllArrows()
        for k, arr in pairs(PlayerMapMarker.ArrowWidgets) do
            if arr then
                PlayerMapMarker.DestroyLineWidget(arr.stem)
                PlayerMapMarker.DestroyLineWidget(arr.wL)
                PlayerMapMarker.DestroyLineWidget(arr.wR)
            end
        end
        PlayerMapMarker.ArrowWidgets = {}
    end

    -- ===== 2D BOX ESP (PERFECT - Box enemy ke andar draw ho) =====
    function PlayerMapMarker.UpdateBox(KeyStr, headCanvas, feetCanvas, bOnScreen, bodyCanvas)
        if not PlayerMapMarker.bUseBoxESP then return end
        local box = PlayerMapMarker.BoxWidgets[KeyStr]
        if not bOnScreen then
            if box then
                PlayerMapMarker.HideLineWidget(box.top)
                PlayerMapMarker.HideLineWidget(box.bot)
                PlayerMapMarker.HideLineWidget(box.left)
                PlayerMapMarker.HideLineWidget(box.right)
            end
            return
        end
        if not headCanvas or not feetCanvas then return end
        local boxH = feetCanvas.Y - headCanvas.Y
        if boxH < 5 then return end
        -- Use average of head + feet X for perfect center
        local centerX = (headCanvas.X + feetCanvas.X) * 0.5
        local boxW = boxH * (PlayerMapMarker.BoxWidthFactor or 0.50)
        local padX = boxW * 0.5
        local padY = boxH * 0.05
        local L = centerX - padX
        local R = centerX + padX
        local T = headCanvas.Y - padY
        local B = feetCanvas.Y + padY
        local thick = PlayerMapMarker.BoxThickness or 1.5
        local color = PlayerMapMarker.BoxColor
        if not box then
            box = {
                top = PlayerMapMarker.CreateLineWidget(color, 1),
                bot = PlayerMapMarker.CreateLineWidget(color, 1),
                left = PlayerMapMarker.CreateLineWidget(color, 1),
                right = PlayerMapMarker.CreateLineWidget(color, 1),
            }
            PlayerMapMarker.BoxWidgets[KeyStr] = box
        end
        PlayerMapMarker.DrawLine(box.top, L, T, R, T, thick)
        PlayerMapMarker.DrawLine(box.bot, L, B, R, B, thick)
        PlayerMapMarker.DrawLine(box.left, L, T, L, B, thick)
        PlayerMapMarker.DrawLine(box.right, R, T, R, B, thick)
    end

    function PlayerMapMarker.RemoveBox(KeyStr)
        local box = PlayerMapMarker.BoxWidgets[KeyStr]
        if box then
            PlayerMapMarker.DestroyLineWidget(box.top)
            PlayerMapMarker.DestroyLineWidget(box.bot)
            PlayerMapMarker.DestroyLineWidget(box.left)
            PlayerMapMarker.DestroyLineWidget(box.right)
        end
        PlayerMapMarker.BoxWidgets[KeyStr] = nil
    end

    function PlayerMapMarker.ClearAllBoxes()
        for k, box in pairs(PlayerMapMarker.BoxWidgets) do
            if box then
                PlayerMapMarker.DestroyLineWidget(box.top)
                PlayerMapMarker.DestroyLineWidget(box.bot)
                PlayerMapMarker.DestroyLineWidget(box.left)
                PlayerMapMarker.DestroyLineWidget(box.right)
            end
        end
        PlayerMapMarker.BoxWidgets = {}
    end

    function PlayerMapMarker.ClearAllESP()
        -- تنظيف كائنات المستطيل لمنع التراكم بين الأجوام
        RedBoxOverlay.Stop()

        for KeyStr, Data in pairs(PlayerMapMarker.ESPWidgets) do
            PlayerMapMarker.RemoveESPWidget(Data.Widget)
        end
        PlayerMapMarker.ESPWidgets = {}
        PlayerMapMarker.ESPWidgetPtrs = {}
        PlayerMapMarker.ClearAllSnapLines()
        PlayerMapMarker.ClearAllBoxes()
        PlayerMapMarker.ClearAllArrows()
        PlayerMapMarker.RemoveFOVCircle()
        if PlayerMapMarker.ESPCanvas and Game:IsValid(PlayerMapMarker.ESPCanvas) then
            pcall(function()
                local n = PlayerMapMarker.ESPCanvas:GetChildrenCount()
                for i = n - 1, 0, -1 do
                    local child = PlayerMapMarker.ESPCanvas:GetChildAt(i)
                    if child and slua.isValid(child) then
                        if PlayerMapMarker.IsOurESPWidget(child) then
                            PlayerMapMarker.ESPCanvas:RemoveChild(child)
                        end
                    end
                end
            end)
        end
        PlayerMapMarker.ESPCanvas = nil
        PlayerMapMarker._OBHeadWidgetClass = nil
        PlayerMapMarker._OBHeadWidgetLoadFailed = false
        PlayerMapMarker._bDumpedWidgetChildren = false
        PlayerMapMarker._cachedViewportW = 1920
        PlayerMapMarker._cachedViewportH = 1080
    end

    function PlayerMapMarker.UpdateESP(AllPlayers, MyLoc)
        if not PlayerMapMarker.bUseScreenESP then return end

        if not PlayerMapMarker.InitESPCanvas() then
            return
        end

        if PlayerMapMarker._OBHeadWidgetLoadFailed then return end

        local PC = PlayerMapMarker.GetMyPlayerController()
        if IsValid(PC) then
            PlayerMapMarker.UpdateCanvasTransform(PC)
        end

        local fromX, fromY = 0, 0
        if PlayerMapMarker.bUseSnapLines and IsValid(PC) then
            fromX, fromY = PlayerMapMarker.GetSnapLineStartPos(PC)
        end

        -- FOV Circle + Screen Center for Arrows
        local centerCanvas, viewW, viewH = nil, 0, 0
        if (PlayerMapMarker.bUseFOVCircle or PlayerMapMarker.bUseArrows) and IsValid(PC) then
            centerCanvas, viewW, viewH = PlayerMapMarker.GetScreenCenterForESP(PC)
            if centerCanvas and PlayerMapMarker.bUseFOVCircle then
                PlayerMapMarker.UpdateFOVCircle(centerCanvas.X, centerCanvas.Y)
            end
        end

        local MyKey = PlayerMapMarker.GetMyPlayerKey()
        local SeenKeys = {}
        
        local MyChar = nil
        pcall(function()
            local GDP = PlayerMapMarker.GetGameplayData()
            if GDP and GDP.GetLocalCharacter then
                MyChar = GDP.GetLocalCharacter()
            else
                if PC and PC.GetPawn then MyChar = PC:GetPawn() end
            end
        end)
        local MyTeamID = PlayerMapMarker.GetTeamID(MyChar)

        for PlayerKey, Character in pairs(AllPlayers) do
            if IsValid(Character) then
                local bIsMe = PlayerMapMarker.IsMe(Character, PlayerKey, MyKey)
                local bIsAI = PlayerMapMarker.IsAI(Character)
                local KeyStr = tostring(PlayerKey)
                local Name = PlayerMapMarker.GetPlayerName(Character)

                local Loc = PlayerMapMarker.GetESPLocation(Character)

                local DistStr = ""
                if MyLoc and Loc then
                    DistStr = PlayerMapMarker.GetDistanceString(MyLoc, Loc)
                end

                local bSkip = false
                if bIsMe and not PlayerMapMarker.bIncludeMe then bSkip = true end
                if bIsAI and not PlayerMapMarker.bIncludeAI then bSkip = true end
                
                local TeamID = PlayerMapMarker.GetTeamID(Character)
                if MyTeamID ~= nil and TeamID == MyTeamID and not bIsMe then
                    bSkip = true
                end

                local bIsAlive = PlayerMapMarker.IsAlive(Character)

                if not bSkip and Loc then
                    SeenKeys[KeyStr] = true
                    local ESPData = PlayerMapMarker.ESPWidgets[KeyStr]

                    local TeamID = PlayerMapMarker.GetTeamID(Character)

                    local Text = Name
                    if DistStr and DistStr ~= "" then
                        Text = string.format("%s [%s]", Name, DistStr)
                    end

                    local bOnScreen, CanvasPos = PlayerMapMarker.ProjectWorldToCanvasLocal(PC, Loc)

                    if not ESPData then
                        local Widget = PlayerMapMarker.CreateESPWidget()
                        if Widget then
                            PlayerMapMarker.ESPWidgets[KeyStr] = {
                                Widget = Widget,
                                Character = Character,
                                Name = Name,
                                LastDistStr = DistStr,
                                TeamID = TeamID,
                            }
                            PlayerMapMarker.UpdateESPText(Widget, Text)
                            if bIsAlive then
                                PlayerMapMarker.UpdateESPPositionWithPC(Widget, Loc, PC, CanvasPos)
                                PlayerMapMarker.ApplyTeamColor(Widget, TeamID)
                                local HP = Character.Health or 0
                                local MaxHP = Character.MaxHealth or 120
                                local pct = 0
                                if HP > 0 and MaxHP > 0 then
                                    pct = HP / MaxHP
                                    if pct > 1 then pct = 1 end
                                    if pct < 0 then pct = 0 end
                                end
                                PlayerMapMarker.UpdateESPHealth(Widget, pct)
                                PlayerMapMarker.AddWeaponIconToESP(Widget, Character)
                                
                                if PlayerMapMarker.bUseSnapLines then
                                    PlayerMapMarker.UpdateSnapLine(KeyStr, CanvasPos, bOnScreen, fromX, fromY)
                                else
                                    PlayerMapMarker.RemoveSnapLine(KeyStr)
                                end
                                if PlayerMapMarker.bUseBoxESP then
                                    local headLoc = PlayerMapMarker.GetCharacterHeadLoc(Character)
                                    local feetLoc = Loc
                                    local bodyLoc = PlayerMapMarker.GetESPLocation(Character)
                                    if headLoc and feetLoc and PC then
                                        local _, headCanvas = PlayerMapMarker.ProjectWorldToCanvasLocal(PC, headLoc)
                                        local _, feetCanvas = PlayerMapMarker.ProjectWorldToCanvasLocal(PC, feetLoc)
                                        local _, bodyCanvas = bodyLoc and PlayerMapMarker.ProjectWorldToCanvasLocal(PC, bodyLoc) or _, nil
                                        PlayerMapMarker.UpdateBox(KeyStr, headCanvas, feetCanvas, bOnScreen, bodyCanvas)
                                    end
                                end
                                if PlayerMapMarker.bUseArrows and not bOnScreen and centerCanvas then
                                    PlayerMapMarker.UpdateArrow(KeyStr, Loc, PC, centerCanvas)
                                elseif PlayerMapMarker.bUseArrows and bOnScreen then
                                    PlayerMapMarker.RemoveArrow(KeyStr)
                                end
                            else
                                local Container = Widget.Container or Widget
                                pcall(function() Container:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed) end)
                                PlayerMapMarker.UpdateESPHealth(Widget, 0)
                                PlayerMapMarker.RemoveSnapLine(KeyStr)
                                PlayerMapMarker.RemoveBox(KeyStr)
                                PlayerMapMarker.RemoveArrow(KeyStr)
                            end
                        end
                    else
                        ESPData.Character = Character
                        ESPData.Name = Name
                        ESPData.LastDistStr = DistStr
                        if bIsAlive then
                            if TeamID ~= ESPData.TeamID then
                                ESPData.TeamID = TeamID
                                PlayerMapMarker.ApplyTeamColor(ESPData.Widget, TeamID)
                            end
                            PlayerMapMarker.UpdateESPText(ESPData.Widget, Text)
                            PlayerMapMarker.UpdateESPPositionWithPC(ESPData.Widget, Loc, PC, CanvasPos)
                            local HP = Character.Health or 0
                            local MaxHP = Character.MaxHealth or 120
                            local pct = 0
                            if HP > 0 and MaxHP > 0 then
                                pct = HP / MaxHP
                                if pct > 1 then pct = 1 end
                                if pct < 0 then pct = 0 end
                            end
                            PlayerMapMarker.UpdateESPHealth(ESPData.Widget, pct)
                            PlayerMapMarker.AddWeaponIconToESP(ESPData.Widget, Character)
                            
                            if PlayerMapMarker.bUseSnapLines then
                                PlayerMapMarker.UpdateSnapLine(KeyStr, CanvasPos, bOnScreen, fromX, fromY)
                            else
                                PlayerMapMarker.RemoveSnapLine(KeyStr)
                            end
                            if PlayerMapMarker.bUseBoxESP then
                                local headLoc = PlayerMapMarker.GetCharacterHeadLoc(Character)
                                local feetLoc = Loc
                                local bodyLoc = PlayerMapMarker.GetESPLocation(Character)
                                if headLoc and feetLoc and PC then
                                    local _, headCanvas = PlayerMapMarker.ProjectWorldToCanvasLocal(PC, headLoc)
                                    local _, feetCanvas = PlayerMapMarker.ProjectWorldToCanvasLocal(PC, feetLoc)
                                    local _, bodyCanvas = bodyLoc and PlayerMapMarker.ProjectWorldToCanvasLocal(PC, bodyLoc) or _, nil
                                    PlayerMapMarker.UpdateBox(KeyStr, headCanvas, feetCanvas, bOnScreen, bodyCanvas)
                                end
                            end
                            if PlayerMapMarker.bUseArrows and not bOnScreen and centerCanvas then
                                PlayerMapMarker.UpdateArrow(KeyStr, Loc, PC, centerCanvas)
                            elseif PlayerMapMarker.bUseArrows and bOnScreen then
                                PlayerMapMarker.RemoveArrow(KeyStr)
                            end
                        else
                            local Container = ESPData.Widget.Container or ESPData.Widget
                            pcall(function() Container:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed) end)
                            PlayerMapMarker.UpdateESPHealth(ESPData.Widget, 0)
                            PlayerMapMarker.RemoveSnapLine(KeyStr)
                            PlayerMapMarker.RemoveBox(KeyStr)
                            PlayerMapMarker.RemoveArrow(KeyStr)
                        end
                    end
                end
            end
        end

        for KeyStr, Data in pairs(PlayerMapMarker.ESPWidgets) do
            if not SeenKeys[KeyStr] then
                PlayerMapMarker.RemoveESPWidget(Data.Widget)
                PlayerMapMarker.RemoveSnapLine(KeyStr)
                PlayerMapMarker.RemoveBox(KeyStr)
                PlayerMapMarker.RemoveArrow(KeyStr)
                PlayerMapMarker.ESPWidgets[KeyStr] = nil
            end
        end
    end

    function PlayerMapMarker.UpdateESPLight()
        pcall(ProcessAimbotFrame)

        -- تحديث موقع المستطيل في كل فريم ليبقى مطبقاً فوق SnapLine تماماً بدون lag
        if RedBoxOverlay.bActive then
            RedBoxOverlay.UpdatePosition()
        end

        if not PlayerMapMarker.bUseScreenESP then return end
        if not PlayerMapMarker.ESPCanvas or not Game:IsValid(PlayerMapMarker.ESPCanvas) then return end

        local PC = PlayerMapMarker.GetMyPlayerController()
        if not IsValid(PC) then return end

        PlayerMapMarker.UpdateCanvasTransform(PC)

        local fromX, fromY = 0, 0
        if PlayerMapMarker.bUseSnapLines then
            fromX, fromY = PlayerMapMarker.GetSnapLineStartPos(PC)
        end

        for KeyStr, ESPData in pairs(PlayerMapMarker.ESPWidgets) do
            local Widget = ESPData.Widget
            local Character = ESPData.Character
            local Container = Widget and (Widget.Container or Widget)
            local bWidgetValid = false
            pcall(function() bWidgetValid = Container and slua.isValid(Container) end)

            if Widget and bWidgetValid and Character and IsValid(Character) then
                local bIsAlive = PlayerMapMarker.IsAlive(Character)

                if not bIsAlive then
                    pcall(function() Container:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed) end)
                    PlayerMapMarker.RemoveSnapLine(KeyStr)
                else
                    pcall(function() Container:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible) end)
                    pcall(function() Container:SetRenderOpacity(1.0) end)

                    local Loc = PlayerMapMarker.GetESPLocation(Character)
                    if Loc then
                        local bOnScreen, CanvasPos = PlayerMapMarker.ProjectWorldToCanvasLocal(PC, Loc)
                        PlayerMapMarker.UpdateESPPositionWithPC(Widget, Loc, PC, CanvasPos)
                        if PlayerMapMarker.bUseSnapLines then
                            PlayerMapMarker.UpdateSnapLine(KeyStr, CanvasPos, bOnScreen, fromX, fromY)
                        else
                            PlayerMapMarker.RemoveSnapLine(KeyStr)
                        end
                    else
                        PlayerMapMarker.RemoveSnapLine(KeyStr)
                    end
                end
            end
        end
    end

    function PlayerMapMarker.UpdateESPDistances()
        if not PlayerMapMarker.bUseScreenESP then return end

        local MyLoc = PlayerMapMarker.GetMyLocation()
        if not MyLoc then return end

        local PC = PlayerMapMarker.GetMyPlayerController()
        if not IsValid(PC) then return end

        PlayerMapMarker.UpdateCanvasTransform(PC)

        for KeyStr, ESPData in pairs(PlayerMapMarker.ESPWidgets) do
            local Character = ESPData.Character
            local Widget = ESPData.Widget
            local Container = Widget and (Widget.Container or Widget)
            local bWidgetValid = false
            pcall(function() bWidgetValid = Container and slua.isValid(Container) end)
            if Character and IsValid(Character) and Widget and bWidgetValid then
                local Loc = PlayerMapMarker.GetESPLocation(Character)
                if Loc then
                    local Dist = PlayerMapMarker.CalcDistance(MyLoc, Loc)
                    ESPData.LastDistance = Dist

                    if PlayerMapMarker.bShowDistance then
                        local DistStr = ""
                        local Meters = 0
                        if Dist then
                            Meters = Dist / 100
                            if Meters < 1000 then
                                DistStr = string.format("%dm", math.floor(Meters))
                            else
                                DistStr = string.format("%.1fkm", Meters / 1000)
                            end
                        end

                        local Name = ESPData.Name or "Unknown"
                        local Text = Name
                        if DistStr and DistStr ~= "" then
                            Text = string.format("%s [%s]", Name, DistStr)
                        end
                        ESPData.LastDistStr = DistStr
                        PlayerMapMarker.UpdateESPText(Widget, Text)
                    end
                end
            end
        end
    end

    function PlayerMapMarker.OnTick(deltaTime)
        if not PlayerMapMarker.bActive then return end

        pcall(function()
            PlayerMapMarker._FrameCount = PlayerMapMarker._FrameCount + 1
            local frame = PlayerMapMarker._FrameCount

            if frame % PlayerMapMarker.nHeavyScanFrameInterval == 0 then
                local AllChars = PlayerMapMarker.GetAllCharacters()
                if AllChars then
                    local MyLoc = PlayerMapMarker.GetMyLocation()
                    PlayerMapMarker._CachedAllChars = AllChars
                    PlayerMapMarker._CachedMyLoc = MyLoc
                    PlayerMapMarker.UpdateESP(AllChars, MyLoc)
                end
            end

            if frame % PlayerMapMarker.nDistanceUpdateFrameInterval == 0 then
                PlayerMapMarker.UpdateESPDistances()
            end

            PlayerMapMarker.UpdateESPLight()
        end)
    end

    PlayerMapMarker._WorkingWidgetPath = nil
    PlayerMapMarker._FailedWidgetPaths = {}

    PlayerMapMarker.WidgetCompUIPaths = {
        "/Game/BluePrints/ControlInput/NewbieItem/NewbieTips_ConsumeTips.NewbieTips_ConsumeTips_C",
        "/Game/BluePrints/ControlInput/IngameUI/TipsItem/ChangeSight_Item01_UIBP.ChangeSight_Item01_UIBP_C",
        "/Game/Mod/PlanBT/BluePrints/UI/Fusion/FusionTitle_UIBP.FusionTitle_UIBP_C",
        "/Game/BluePrints/ControlInput/NewbieItem/NewbieTips_ConsumeTips.NewbieTips_ConsumeTips",
    }

    function PlayerMapMarker.CreateWidgetCompForPlayer(Character, Text)
        if not IsValid(Character) then return nil end
        local Mesh = PlayerMapMarker.GetCharacterMesh(Character)
        if not Mesh or not Game:IsValid(Mesh) then return nil end

        if PlayerMapMarker._bAllPathsFailed then return nil end

        local PathsToTry = {}
        if PlayerMapMarker._WorkingWidgetPath then
            table.insert(PathsToTry, PlayerMapMarker._WorkingWidgetPath)
        else
            for _, path in ipairs(PlayerMapMarker.WidgetCompUIPaths) do
                if not PlayerMapMarker._FailedWidgetPaths[path] then
                    table.insert(PathsToTry, path)
                end
            end
        end

        if #PathsToTry == 0 then
            PlayerMapMarker._bAllPathsFailed = true
            return nil
        end

        local STExtraBlueprintFunctionLibrary = nil
        pcall(function() STExtraBlueprintFunctionLibrary = import("STExtraBlueprintFunctionLibrary") end)
        if not STExtraBlueprintFunctionLibrary then return nil end

        local Widget = nil
        local UsedPath = nil
        for _, path in ipairs(PathsToTry) do
            local ok = false
            pcall(function()
                Widget = STExtraBlueprintFunctionLibrary.CreateWidgetByPathName(path, Character)
                if Widget and slua.isValid(Widget) then ok = true end
            end)
            if ok and Widget then
                UsedPath = path
                PlayerMapMarker._WorkingWidgetPath = path
                break
            else
                Widget = nil
                PlayerMapMarker._FailedWidgetPaths[path] = true
            end
        end

        if not Widget then
            if not PlayerMapMarker._WorkingWidgetPath then
                PlayerMapMarker._bAllPathsFailed = true
            end
            return nil
        end

        local WidgetComp = nil
        pcall(function()
            local UWidgetComponent = import("WidgetComponent")
            WidgetComp = Game:AddComponent(UWidgetComponent, Character, "PlayerMapMarkerWidget")

            if WidgetComp and Game:IsValid(WidgetComp) then
                WidgetComp.AlwaysLoadOnClient = true
                WidgetComp.AlwaysLoadOnServer = false
                WidgetComp:SetOwnerNoSee(false)
                WidgetComp.bGenerateOverlapEvents = false
                WidgetComp.bCanEverAffectNavigation = false
                WidgetComp.bUseAttachParentBound = true
                WidgetComp.Space = 1

                pcall(function() WidgetComp:SetHiddenInGame(false) end)
                pcall(function() WidgetComp:SetVisibility(true) end)
                pcall(function() WidgetComp:SetComponentTickEnabled(true) end)

                pcall(function() WidgetComp:SetDrawSize(PlayerMapMarker.WidgetCompDrawSize) end)
                WidgetComp:SetWidget(Widget)
                WidgetComp:RequestRedraw()

                WidgetComp:K2_AttachToComponent(
                    Mesh,
                    PlayerMapMarker.WidgetCompBoneName,
                    UEnums.EAttachmentRule.SnapToTarget,
                    UEnums.EAttachmentRule.SnapToTarget,
                    UEnums.EAttachmentRule.KeepWorld,
                    false
                )

                local KismetMathLibrary = import("KismetMathLibrary")
                local Transform = KismetMathLibrary.MakeTransform(
                    PlayerMapMarker.WidgetCompOffset,
                    FRotator(0, 180, 0),
                    FVector(1, 1, 1)
                )
                WidgetComp:K2_SetRelativeTransform(Transform, false, nil, false)

                local UserWidget = WidgetComp:GetUserWidgetObject()
                if UserWidget and Game:IsValid(UserWidget) then
                    pcall(function()
                        if UserWidget.PlayerName then
                            UserWidget.PlayerName:SetText(Text or "")
                        elseif UserWidget.TextTitle then
                            UserWidget.TextTitle:SetText(Text or "")
                        elseif UserWidget.UTRichTextBlock_Tips22_Text1 then
                            UserWidget.UTRichTextBlock_Tips22_Text1:SetText(Text or "")
                        end
                    end)
                end

                CGame:RegisterComponent(WidgetComp)
                pcall(function() WidgetComp:RequestRedraw() end)
            end
        end)

        if not WidgetComp or not Game:IsValid(WidgetComp) then
            if WidgetComp and Game:IsValid(WidgetComp) then
                pcall(function() WidgetComp:DestroyComponent() end)
            end
            return nil
        end

        return WidgetComp
    end

    function PlayerMapMarker.UpdateWidgetCompText(WidgetComp, Text)
        if not WidgetComp or not Game:IsValid(WidgetComp) then return end
        pcall(function()
            local UserWidget = WidgetComp:GetUserWidgetObject()
            if UserWidget and Game:IsValid(UserWidget) then
                if UserWidget.PlayerName then
                    UserWidget.PlayerName:SetText(Text or "")
                elseif UserWidget.TextTitle then
                    UserWidget.TextTitle:SetText(Text or "")
                elseif UserWidget.UTRichTextBlock_Tips22_Text1 then
                    UserWidget.UTRichTextBlock_Tips22_Text1:SetText(Text or "")
                end
            end
        end)
    end

    function PlayerMapMarker.RemoveWidgetComp(WidgetComp)
        if not WidgetComp then return end
        pcall(function()
            if Game:IsValid(WidgetComp) then
                WidgetComp:K2_DetachFromComponent(2, false)
                local UserWidget = WidgetComp:GetUserWidgetObject()
                if UserWidget and Game:IsValid(UserWidget) then
                    UserWidget:RemoveFromViewport()
                    UserWidget:ConditionalBeginDestroy()
                end
                WidgetComp:DestroyComponent()
            end
        end)
    end

    function PlayerMapMarker.ClearAllWidgetComps()
        for KeyStr, WidgetComp in pairs(PlayerMapMarker.WidgetComps) do
            PlayerMapMarker.RemoveWidgetComp(WidgetComp)
        end
        PlayerMapMarker.WidgetComps = {}
    end

    function PlayerMapMarker.UpdateWidgetComps(AllPlayers, MyLoc)
        if not PlayerMapMarker.bUseWidgetComponent then return end
        if PlayerMapMarker._bAllPathsFailed then return end

        local MyKey = PlayerMapMarker.GetMyPlayerKey()
        local SeenKeys = {}

        for PlayerKey, Character in pairs(AllPlayers) do
            if IsValid(Character) then
                local bIsMe = PlayerMapMarker.IsMe(Character, PlayerKey, MyKey)
                local bIsAI = PlayerMapMarker.IsAI(Character)
                local KeyStr = tostring(PlayerKey)
                local Name = PlayerMapMarker.GetPlayerName(Character)
                local Loc = PlayerMapMarker.GetCharacterLocation(Character)

                local DistStr = ""
                if MyLoc and Loc then
                    DistStr = PlayerMapMarker.GetDistanceString(MyLoc, Loc)
                end

                local bSkip = false
                if bIsMe and not PlayerMapMarker.bIncludeMe then bSkip = true end
                if bIsAI and not PlayerMapMarker.bIncludeAI then bSkip = true end

                if not bSkip then
                    SeenKeys[KeyStr] = true
                    local Text = Name
                    if DistStr and DistStr ~= "" then
                        Text = string.format("%s [%s]", Name, DistStr)
                    end

                    local ExistingComp = PlayerMapMarker.WidgetComps[KeyStr]
                    if not ExistingComp or not Game:IsValid(ExistingComp) then
                        local WidgetComp = PlayerMapMarker.CreateWidgetCompForPlayer(Character, Text)
                        if WidgetComp then
                            PlayerMapMarker.WidgetComps[KeyStr] = WidgetComp
                        end
                    else
                        PlayerMapMarker.UpdateWidgetCompText(ExistingComp, Text)
                    end
                end
            end
        end

        for KeyStr, WidgetComp in pairs(PlayerMapMarker.WidgetComps) do
            if not SeenKeys[KeyStr] then
                PlayerMapMarker.RemoveWidgetComp(WidgetComp)
                PlayerMapMarker.WidgetComps[KeyStr] = nil
            end
        end
    end

    function PlayerMapMarker.CreateMark(Location, CustomString, Actor)
        if not PlayerMapMarker.bUseScreenMark and not Location then return nil end

        local InstID = nil
        local Flag = GetMapAddedFlag()

        local MarkPos = Location
        if PlayerMapMarker.bUseScreenMark then
            MarkPos = nil
        end

        if PlayerMapMarker.bUseServerMarks then
            pcall(function()
                InstID = InGameMarkTools.ServerAddMapMark(
                    PlayerMapMarker.MarkTypeID,
                    MarkPos,
                    nil,
                    nil,
                    nil,
                    UEnums.EMarkDispatchRange.EMAMDT_ALL,
                    nil,
                    Actor
                )
            end)
        else
            pcall(function()
                local actorObj = Actor and (Actor.Object or Actor) or nil
                InstID = InGameMarkTools.ClientAddMapMark(
                    PlayerMapMarker.MarkTypeID,
                    MarkPos,
                    0,
                    CustomString or "",
                    Flag,
                    actorObj,
                    0,
                    nil
                )
            end)
        end

        return InstID
    end

    function PlayerMapMarker.UpdateMarkLocation(InstID, Location)
        if not InstID or not Location then return end
        pcall(function()
            InGameMarkTools.UpdateMapMarkLocation(InstID, Location)
        end)
    end

    function PlayerMapMarker.HideMark(InstID)
        if not InstID then return end
        pcall(function()
            InGameMarkTools.HideMapMark(InstID)
        end)
    end

    function PlayerMapMarker.ShowMark(InstID)
        if not InstID then return end
        pcall(function()
            InGameMarkTools.ShowMapMark(InstID)
        end)
    end

    function PlayerMapMarker.UpdateMarkString(InstID, sName)
        if not InstID or not sName then return end
        pcall(function()
            InGameMarkTools.UpdateMapMarkCustomString(InstID, sName)
        end)
    end

    function PlayerMapMarker.ClearAllMarks()
        for KeyStr, MarkID in pairs(PlayerMapMarker.MarkMap) do
            if PlayerMapMarker.bUseQuickSign then
                PlayerMapMarker.RemoveQuickSignMark(MarkID)
            elseif PlayerMapMarker.bUseNavigator then
                PlayerMapMarker.RemoveNavigatorMark(MarkID)
            else
                PlayerMapMarker.HideMark(MarkID)
            end
        end
        PlayerMapMarker.MarkMap = {}
        PlayerMapMarker.PlayerInfo = {}
        PlayerMapMarker.ClearAllWidgetComps()
        PlayerMapMarker.ClearAllESP()
    end

    function PlayerMapMarker.ScanAndUpdate()
        local AllChars = PlayerMapMarker.GetAllCharacters()
        if not AllChars then
            RedBoxOverlay.SetCounts(0, 0)
            return 0
        end

        local MyKey = PlayerMapMarker.GetMyPlayerKey()
        local MyLoc = PlayerMapMarker.GetMyLocation()

        local MyChar = nil
        pcall(function()
            local GDP = PlayerMapMarker.GetGameplayData()
            if GDP and GDP.GetLocalCharacter then
                MyChar = GDP.GetLocalCharacter()
            else
                local PC = PlayerMapMarker.GetMyPlayerController()
                if PC and PC.GetPawn then MyChar = PC:GetPawn() end
            end
        end)
        local MyTeamID = PlayerMapMarker.GetTeamID(MyChar)

        -- 1. حساب أعداد اللاعبين والبوتات الأحياء (بدون اللاعب نفسه والتيم)
        local realPlayers = 0
        local botPlayers = 0

        for PlayerKey, Character in pairs(AllChars) do
            if IsValid(Character) then
                local bIsMe = PlayerMapMarker.IsMe(Character, PlayerKey, MyKey)
                local bIsAI = PlayerMapMarker.IsAI(Character)
                local bIsAlive = PlayerMapMarker.IsAlive(Character)

                if bIsAlive and not bIsMe then
                    local bIsMyTeam = false
                    if MyTeamID ~= nil then
                        local targetTeamID = PlayerMapMarker.GetTeamID(Character)
                        if targetTeamID == MyTeamID then
                            bIsMyTeam = true
                        end
                    end
                    
                    if not bIsMyTeam then
                        if bIsAI then
                            botPlayers = botPlayers + 1
                        else
                            realPlayers = realPlayers + 1
                        end
                    end
                end
            end
        end

        -- 2. إرسال الأعداد للمستطيل وضمان تشغيله
        if RedBoxOverlay.bActive then
            RedBoxOverlay.SetCounts(realPlayers, botPlayers)
        else
            RedBoxOverlay.Start()
        end

        -- 3. استكمال باقي عملية المسح والـ ESP
        if PlayerMapMarker.bUseScreenMark then
            PlayerMapMarker.SetupScreenMarkConfig()
        end

        if PlayerMapMarker.bUseScreenESP then
            PlayerMapMarker.UpdateESP(AllChars, MyLoc)
            return 0
        end

        if PlayerMapMarker.bUseWidgetComponent then
            PlayerMapMarker.UpdateWidgetComps(AllChars, MyLoc)
            return 0
        end

        local nCount = 0
        local nMarked = 0
        local nNewMarks = 0
        local nUpdated = 0
        local SeenKeys = {}

        for PlayerKey, Character in pairs(AllChars) do
            if IsValid(Character) then
                local bIsMe = PlayerMapMarker.IsMe(Character, PlayerKey, MyKey)
                local bIsAI = PlayerMapMarker.IsAI(Character)
                local bIsAlive = PlayerMapMarker.IsAlive(Character)
                local KeyStr = tostring(PlayerKey)
                local Name = PlayerMapMarker.GetPlayerName(Character)
                local Loc = PlayerMapMarker.GetCharacterLocation(Character)

                local DistStr = ""
                if PlayerMapMarker.bShowDistance and MyLoc and Loc then
                    DistStr = PlayerMapMarker.GetDistanceString(MyLoc, Loc)
                end

                local MarkText = Name
                if DistStr and DistStr ~= "" then
                    MarkText = string.format("%s (%s)", Name, DistStr)
                end

                nCount = nCount + 1
                SeenKeys[KeyStr] = true

                local bSkip = false
                if bIsMe and not PlayerMapMarker.bIncludeMe then bSkip = true end
                if bIsAI and not PlayerMapMarker.bIncludeAI then bSkip = true end

                if not bSkip and Loc then
                    local ExistingMark = PlayerMapMarker.MarkMap[KeyStr]

                    if PlayerMapMarker.bUseQuickSign then
                        if ExistingMark then
                            PlayerMapMarker.RemoveQuickSignMark(ExistingMark)
                        end
                        local MsgID = PlayerMapMarker.CreateQuickSignMark(Loc)
                        if MsgID then
                            PlayerMapMarker.MarkMap[KeyStr] = MsgID
                            PlayerMapMarker.PlayerInfo[KeyStr] = {
                                Name = Name, bIsAlive = bIsAlive, bIsAI = bIsAI, bIsMe = bIsMe, LastDistStr = DistStr,
                            }
                            nMarked = nMarked + 1
                            if not ExistingMark then nNewMarks = nNewMarks + 1 else nUpdated = nUpdated + 1 end
                        end
                    elseif PlayerMapMarker.bUseNavigator then
                        if not ExistingMark then
                            local NavInstID = PlayerMapMarker.CreateNavigatorMark(Loc)
                            if NavInstID then
                                PlayerMapMarker.MarkMap[KeyStr] = NavInstID
                                PlayerMapMarker.PlayerInfo[KeyStr] = {
                                    Name = Name, bIsAlive = bIsAlive, bIsAI = bIsAI, bIsMe = bIsMe, LastDistStr = DistStr,
                                }
                                nMarked = nMarked + 1
                                nNewMarks = nNewMarks + 1
                            end
                        else
                            PlayerMapMarker.UpdateNavigatorMark(ExistingMark, Loc)
                            nMarked = nMarked + 1
                            nUpdated = nUpdated + 1
                            local OldInfo = PlayerMapMarker.PlayerInfo[KeyStr]
                            if OldInfo then
                                OldInfo.Name = Name
                                OldInfo.bIsAlive = bIsAlive
                                OldInfo.LastDistStr = DistStr
                            end
                        end
                    else
                        if not ExistingMark then
                            local InstID = PlayerMapMarker.CreateMark(Loc, MarkText, Character)
                            if InstID then
                                PlayerMapMarker.MarkMap[KeyStr] = InstID
                                PlayerMapMarker.ShowMark(InstID)
                                PlayerMapMarker.PlayerInfo[KeyStr] = {
                                    Name = Name, bIsAlive = bIsAlive, bIsAI = bIsAI, bIsMe = bIsMe, LastDistStr = DistStr,
                                }
                                nMarked = nMarked + 1
                                nNewMarks = nNewMarks + 1
                            end
                        else
                            if not PlayerMapMarker.bUseScreenMark then
                                PlayerMapMarker.UpdateMarkLocation(ExistingMark, Loc)
                            end
                            PlayerMapMarker.UpdateMarkString(ExistingMark, MarkText)
                            nMarked = nMarked + 1
                            nUpdated = nUpdated + 1
                            local OldInfo = PlayerMapMarker.PlayerInfo[KeyStr]
                            if OldInfo then
                                OldInfo.Name = Name
                                OldInfo.bIsAlive = bIsAlive
                                OldInfo.LastDistStr = DistStr
                            end
                        end
                    end
                elseif bSkip and PlayerMapMarker.MarkMap[KeyStr] then
                    if PlayerMapMarker.bUseQuickSign then
                        PlayerMapMarker.RemoveQuickSignMark(PlayerMapMarker.MarkMap[KeyStr])
                    elseif PlayerMapMarker.bUseNavigator then
                        PlayerMapMarker.RemoveNavigatorMark(PlayerMapMarker.MarkMap[KeyStr])
                    else
                        PlayerMapMarker.HideMark(PlayerMapMarker.MarkMap[KeyStr])
                    end
                    PlayerMapMarker.MarkMap[KeyStr] = nil
                    PlayerMapMarker.PlayerInfo[KeyStr] = nil
                end
            end
        end

        for KeyStr, MarkID in pairs(PlayerMapMarker.MarkMap) do
            if not SeenKeys[KeyStr] then
                if PlayerMapMarker.bUseQuickSign then
                    PlayerMapMarker.RemoveQuickSignMark(MarkID)
                elseif PlayerMapMarker.bUseNavigator then
                    PlayerMapMarker.RemoveNavigatorMark(MarkID)
                else
                    PlayerMapMarker.HideMark(MarkID)
                end
                PlayerMapMarker.MarkMap[KeyStr] = nil
                PlayerMapMarker.PlayerInfo[KeyStr] = nil
            end
        end

        return nCount
    end

    function PlayerMapMarker.AttachTimers()
        pcall(function()
            local pc = PlayerMapMarker.GetMyPlayerController()
            if not slua.isValid(pc) or not pc.AddGameTimer then
                local now = os.time()
                if PlayerMapMarker._AttachPending then
                    if PlayerMapMarker._AttachPendingTime and (now - PlayerMapMarker._AttachPendingTime) < 2 then return end
                end
                PlayerMapMarker._AttachPending = true
                PlayerMapMarker._AttachPendingTime = now
                pcall(function()
                    require("timer").SetGameTimer(1.0, false, function()
                        PlayerMapMarker._AttachPending = nil
                        PlayerMapMarker._AttachPendingTime = nil
                        PlayerMapMarker.AttachTimers()
                    end)
                end)
                return
            end

            PlayerMapMarker._AttachPending = nil
            PlayerMapMarker._AttachPendingTime = nil

            local now = os.time()
            local lastPC = PlayerMapMarker._ActiveTimerPC
            local lastTick = PlayerMapMarker._ActiveTimerTick
            if lastPC and slua.isValid(lastPC) and lastPC == pc then
                if lastTick and (now - lastTick) < 5 then return end
            end

            PlayerMapMarker._ActiveTimerPC = pc
            PlayerMapMarker._ActiveTimerTick = now

            pcall(function()
                pc:AddGameTimer(PlayerMapMarker.nUpdateInterval or 0.5, true, function()
                    PlayerMapMarker._ActiveTimerTick = os.time()
                    if PlayerMapMarker.bActive then
                        pcall(function() PlayerMapMarker.ScanAndUpdate() end)
                    end
                end)
            end)

            pcall(function()
                pc:AddGameTimer(PlayerMapMarker._LightUpdateInterval or 0.025, true, function()
                    PlayerMapMarker._ActiveTimerTick = os.time()
                    if _G.DemonMsg and _G.DemonMsg.Step then _G.DemonMsg.Step() end
                    if PlayerMapMarker.bActive then
                        pcall(function() PlayerMapMarker.UpdateESPLight() end)
                    end
                end)
            end)

            pcall(function()
                pc:AddGameTimer(PlayerMapMarker._DistanceUpdateInterval or 0.1, true, function()
                    PlayerMapMarker._ActiveTimerTick = os.time()
                    if PlayerMapMarker.bActive and PlayerMapMarker.bUseScreenESP and PlayerMapMarker.bShowDistance then
                        pcall(function() PlayerMapMarker.UpdateESPDistances() end)
                    end
                end)
            end)

            pcall(function()
                require("timer").SetGameTimer(5.0, false, PlayerMapMarker.AttachTimers)
            end)
        end)
    end

    function PlayerMapMarker.Start()
        if PlayerMapMarker.bActive then
            return
        end

        PlayerMapMarker.bActive = true
        PlayerMapMarker._FrameCount = 0

        PlayerMapMarker.ScanAndUpdate()
        PlayerMapMarker.AttachTimers()
    end

    function PlayerMapMarker.Stop()
        PlayerMapMarker.bActive = false
        PlayerMapMarker._FrameCount = 0

        PlayerMapMarker.ClearAllMarks()
    end

    function PlayerMapMarker.Reset()
        PlayerMapMarker.ClearAllMarks()
    end

    function PlayerMapMarker.ManualScan()
        return PlayerMapMarker.ScanAndUpdate()
    end

    if _G._PlayerMapMarker_Loaded then
        PlayerMapMarker.Stop()
        PlayerMapMarker.Start()
    else
        _G._PlayerMapMarker_Loaded = true
        PlayerMapMarker.Start()
    end

    _G.PlayerMapMarker = PlayerMapMarker

    -- ============================================================
    -- CHAMS (ENGINE DYEING) - PORTED FROM LEXUS / help.lua (WORKING)
    -- ============================================================
    _G.BRChamsConfig = _G.BRChamsConfig or {
        Enable = true,
        VisColor = 3,   -- 1=Red 2=Blue 3=Green 4=Yellow 5=Orange 6=Pink
        OccColor = 1,   -- 1=Red 2=Blue 3=Green 4=Yellow 5=Orange 6=Pink
    }

    local _chams_LC = nil
    local function _chamsGetLC()
        if _chams_LC == nil then _chams_LC = import("LinearColor") or _G.FLinearColor end
        return _chams_LC
    end
    local _chams_SK = nil
    local function _chamsGetSK()
        if _chams_SK == nil then _chams_SK = import("SkeletalMeshComponent") end
        return _chams_SK
    end

    local function ChamsGetColors(isBot)
        local vi = _G.BRChamsConfig.VisColor or 3
        local oc = _G.BRChamsConfig.OccColor or 1
        local LC = _chamsGetLC()
        local mk = function(r, g, b, a) return (LC and LC(r, g, b, a)) or {R=r, G=g, B=b, A=a} end
        local P = {
            [1] = mk(100, 0, 0, 1),
            [2] = mk(0, 40, 100, 1),
            [3] = mk(0, 100, 0, 1),
            [4] = mk(100, 100, 0, 1),
            [5] = mk(100, 50, 0, 1),
            [6] = mk(100, 0, 60, 1),
        }
        local vis = P[vi] or P[3]
        local occ = P[oc] or P[1]
        return vis, occ
    end

    local function ChamsGetMeshes(enemy)
        local meshes = {}
        if Valid(enemy.Mesh) then table.insert(meshes, enemy.Mesh) end
        pcall(function()
            local SK = _chamsGetSK()
            if SK and type(enemy.GetComponentsByClass) == "function" then
                local childs = enemy:GetComponentsByClass(SK)
                if childs then
                    local count = type(childs.Num) == "function" and childs:Num() or #childs
                    for i = 1, count do
                        local comp = type(childs.Get) == "function" and childs:Get(i - 1) or childs[i]
                        if Valid(comp) and comp ~= enemy.Mesh then table.insert(meshes, comp) end
                    end
                end
            end
        end)
        pcall(function()
            local w = enemy:GetCurrentWeapon()
            if Valid(w) and Valid(w.Mesh) then table.insert(meshes, w.Mesh) end
        end)
        return meshes
    end

    local _chamsConsoleReady = false
    local function ChamsEnableConsole()
        if _chamsConsoleReady then return end
        pcall(function()
            local KSL = import("KismetSystemLibrary")
            local world = slua.getWorld()
            if KSL and world then
                KSL.ExecuteConsoleCommand(world, "r.EnableDrawDyeingColor 1")
                KSL.ExecuteConsoleCommand(world, "r.CustomDepth 3")
                KSL.ExecuteConsoleCommand(world, "r.IdeaOutline.Enable 1")
                KSL.ExecuteConsoleCommand(world, "r.Highlight.Enable 1")
                _chamsConsoleReady = true
            end
        end)
    end

    local function ApplyChams(enemy)
        if not Valid(enemy) then return end
        pcall(function()
            ChamsEnableConsole()
            local isBot = false
            pcall(function()
                if enemy.bIsAI == true or enemy.IsAI == true then isBot = true end
                local ps = enemy.PlayerState or (type(enemy.GetPlayerState) == "function" and enemy:GetPlayerState())
                if Valid(ps) and (ps.bIsABot == true or ps.bIsBot == true) then isBot = true end
            end)
            local meshes = ChamsGetMeshes(enemy)
            local visColor, occColor = ChamsGetColors(isBot)
            for _, mesh in ipairs(meshes) do
                if Valid(mesh) then
                    pcall(function()
                        if type(mesh.SetDrawDyeing) == "function" then
                            mesh:SetDrawDyeing(true)
                            mesh:SetDrawDyeingMode(1)
                            mesh:SetVisibleDyeingColor(visColor)
                            mesh:SetOccludedDyeingColor(occColor)
                            mesh:SetDyeingColorFadeDistance(99999.0)
                            mesh:SetDyeingColorMinMaxDistance(0.0, 99999.0)
                            mesh:SetDrawHighlight(true)
                            mesh:OverrideHighlightColor(visColor)
                            mesh:SetHighlightCanBeOccluded(false)
                            mesh:SetDrawIdeaOutline(true)
                            mesh:SetIdeaOutlineNew(true)
                            mesh:SetIdeaOutlineOcclusionHighlight(true)
                            mesh:OverrideIdeaOutlineColor(visColor)
                            mesh:SetIdeaOutlineOcclusionColor(occColor)
                            mesh:OverrideIdeaOutlineThickness(20.0)
                            mesh:SetIdeaOverrideOutlineAndOcclusion(true)
                            mesh:SetRenderCustomDepth(true)
                            mesh:SetCustomDepthStencilValue(255)
                        end
                    end)
                end
            end
        end)
    end

    local function UndoChams(enemy)
        if not Valid(enemy) then return end
        pcall(function()
            local meshes = ChamsGetMeshes(enemy)
            for _, mesh in ipairs(meshes) do
                if Valid(mesh) then
                    pcall(function()
                        if type(mesh.SetDrawDyeing) == "function" then
                            mesh:SetDrawDyeing(false)
                            mesh:SetDrawHighlight(false)
                            mesh:SetDrawIdeaOutline(false)
                            mesh:SetRenderCustomDepth(false)
                        end
                    end)
                end
            end
        end)
    end

    _G._chamsTimer = _G._chamsTimer or nil
    local function ChamsTick()
        if not _G.BRChamsConfig or not _G.BRChamsConfig.Enable then return end
        pcall(function()
            local GDP = GameplayData
            if not GDP then return end
            local all = (GDP.GetAllPlayerCharacters and GDP.GetAllPlayerCharacters()) or {}
            local localChar = nil
            pcall(function() localChar = GDP.GetLocalCharacter and GDP.GetLocalCharacter() end)
            local myTeam = nil
            if Valid(localChar) and type(localChar.GetTeamID) == "function" then
                myTeam = localChar:GetTeamID()
            end
            for _, enemy in pairs(all) do
                if Valid(enemy) and enemy ~= localChar then
                    local isEnemy = true
                    if myTeam and type(enemy.GetTeamID) == "function" then
                        isEnemy = enemy:GetTeamID() ~= myTeam
                    end
                    if isEnemy then
                        if _G.BRChamsConfig.Enable then ApplyChams(enemy) else UndoChams(enemy) end
                    end
                end
            end
        end)
    end

    _G.BRStartChams = function()
        ChamsEnableConsole()
        if _G._chamsTimer then return end
        pcall(function()
            if _G.Game and _G.Game.AddGameTimer then
                _G._chamsTimer = _G.Game:AddGameTimer(0.3, true, ChamsTick)
            elseif slua_GameFrontendHUD then
                local pc = slua_GameFrontendHUD:GetPlayerController()
                if Valid(pc) and type(pc.AddGameTimer) == "function" then
                    _G._chamsTimer = pc:AddGameTimer(0.3, true, ChamsTick)
                end
            end
        end)
    end

    _G.BRStopChams = function()
        if _G._chamsTimer then
            pcall(function() if _G.Game then _G.Game:RemoveGameTimer(_G._chamsTimer) end end)
            _G._chamsTimer = nil
        end
        pcall(function()
            local GDP = GameplayData
            if not GDP then return end
            local all = (GDP.GetAllPlayerCharacters and GDP.GetAllPlayerCharacters()) or {}
            for _, enemy in pairs(all) do UndoChams(enemy) end
        end)
    end

    -- ============================================================
    -- PBC WALLHACK (PORTED FROM bb.lua) - ENGINE DYEING + AVATAR SLOTS
    -- ============================================================
    _G.PBCWallhackConfig = _G.PBCWallhackConfig or {
        Enable = false,
        VisColor = 1,
        OccColor = 4,
    }

    local _pbc_LC = nil
    local function _pbcGetLC()
        if _pbc_LC == nil then _pbc_LC = import("LinearColor") or _G.FLinearColor end
        return _pbc_LC
    end

    local _pbc_AVATAR_SLOTS = {0,1,2,3,4,5,6,7}
    _G.PBC_PROCESSED_PAWNS = _G.PBC_PROCESSED_PAWNS or {}

    local _pbc_colorData = {
        [1]={R=0,G=2,B=0,A=0},
        [2]={R=3,G=5,B=0,A=5},
        [3]={R=4,G=1,B=0,A=5},
        [4]={R=2,G=0,B=0,A=2},
        [5]={R=2,G=4,B=18,A=5},
        [6]={R=2,G=2,B=2,A=2},
        [7]={R=0,G=3,B=3,A=3},
    }
    local _pbc_COLOR_PALETTE = {}
    for i,d in pairs(_pbc_colorData) do
        local LC = _pbcGetLC()
        _pbc_COLOR_PALETTE[i] = LC and LC(d.R, d.G, d.B, d.A) or {R=d.R, G=d.G, B=d.B, A=d.A}
    end

    local _pbcConsoleReady = false
    local function PBCSetupConsole()
        if _pbcConsoleReady then return end
        pcall(function()
            local K = import("KismetSystemLibrary")
            local w = slua.getWorld()
            if K and w then
                K.ExecuteConsoleCommand(w, "r.EnableDrawDyeingColor 1")
                K.ExecuteConsoleCommand(w, "r.CustomDepth 3")
                K.ExecuteConsoleCommand(w, "r.IdeaOutline.Enable 1")
                K.ExecuteConsoleCommand(w, "r.Highlight.Enable 1")
            end
            _pbcConsoleReady = true
        end)
    end

    local function PBCApplyToMesh(m, vc, oc)
        if not m or not slua.isValid(m) then return end
        pcall(function()
            m:SetDrawDyeing(true)
            m:SetDrawDyeingMode(1)
            m:SetVisibleDyeingColor(vc)
            m:SetOccludedDyeingColor(oc)
            m:SetDyeingColorFadeDistance(99999.0)
            m:SetDyeingColorMinMaxDistance(0.0, 99999.0)
            m:SetDrawHighlight(true)
            m:OverrideHighlightColor(vc)
            m:SetHighlightCanBeOccluded(false)
            m:SetDrawIdeaOutline(true)
            m:SetIdeaOutlineNew(true)
            m:SetIdeaOutlineOcclusionHighlight(true)
            m:OverrideIdeaOutlineColor(vc)
            m:SetIdeaOutlineOcclusionColor(oc)
            m:OverrideIdeaOutlineThickness(20.0)
            m:SetIdeaOverrideOutlineAndOcclusion(true)
            m:SetRenderCustomDepth(true)
            m:SetCustomDepthStencilValue(255)
        end)
    end

    local function PBCGetColorFromIndex(i)
        return _pbc_COLOR_PALETTE[i] or _pbc_COLOR_PALETTE[1]
    end

    local _pbc_WH_TIMER = nil
    local function PBCTick()
        if not _G.PBCWallhackConfig or not _G.PBCWallhackConfig.Enable then return end
        pcall(function()
            local lp = GameplayData.GetPlayerCharacter()
            if not slua.isValid(lp) then return end
            PBCSetupConsole()
            _G.PBC_TICK = (_G.PBC_TICK or 0) + 1
            if _G.PBC_TICK % 6 == 0 then _G.PBC_PROCESSED_PAWNS = {} end
            local mt = lp.TeamID or 0
            local all = Game:GetAllPlayerPawns() or {}
            local pc = 0
            for _,p in pairs(all) do
                if pc >= 20 then break end
                if not slua.isValid(p) or p == lp then goto pbc_cont end
                if p.PlayerKey and _G.PBC_PROCESSED_PAWNS[p.PlayerKey] then goto pbc_cont end
                local alive = false
                pcall(function() if p.Health and p.Health > 0 then alive = true end end)
                if alive and p.TeamID and p.TeamID ~= mt then
                    local vc = PBCGetColorFromIndex(_G.PBCWallhackConfig.VisColor or 1)
                    local oc = PBCGetColorFromIndex(_G.PBCWallhackConfig.OccColor or 3)
                    pcall(function()
                        if slua.isValid(p.Mesh) then PBCApplyToMesh(p.Mesh, vc, oc) end
                        local a = p.CharacterAvatarComp2_BP or (type(p.getAvatarComponent2) == "function" and p:getAvatarComponent2())
                        if a and a.GetMeshCompBySlot then
                            for _,s in ipairs(_pbc_AVATAR_SLOTS) do
                                local m = a:GetMeshCompBySlot(s)
                                if slua.isValid(m) then PBCApplyToMesh(m, vc, oc) end
                            end
                        end
                    end)
                    if p.PlayerKey then _G.PBC_PROCESSED_PAWNS[p.PlayerKey] = true end
                    pc = pc + 1
                end
                ::pbc_cont::
            end
        end)
    end

    _G.PBCStartWallhack = function()
        if _pbc_WH_TIMER then return end
        if not _G.PBCWallhackConfig or not _G.PBCWallhackConfig.Enable then return end
        PBCSetupConsole()
        if _G.Game and _G.Game.AddGameTimer then
            _pbc_WH_TIMER = _G.Game:AddGameTimer(0.3, true, PBCTick)
        else
            local pc = slua_GameFrontendHUD and slua_GameFrontendHUD:GetPlayerController()
            if slua.isValid(pc) and pc.AddGameTimer then
                _pbc_WH_TIMER = pc:AddGameTimer(0.3, true, PBCTick)
            end
        end
    end

    _G.PBCStopWallhack = function()
        if _pbc_WH_TIMER then
            pcall(function() if _G.Game then _G.Game:RemoveGameTimer(_pbc_WH_TIMER) end end)
            _pbc_WH_TIMER = nil
        end
        _G.PBC_PROCESSED_PAWNS = {}
    end

    -- ============================================================
    -- BLUE FRAME ESP (Native Game Method - REAL BLUE FRAME)
    -- Uses Replay_CreateEnemyFrameUI / Replay_SetVisiableOfFrameUI
    -- ============================================================
    _G.BlueFrameConfig = _G.BlueFrameConfig or { Enable = false }
    local _bf_Timer = nil

    local function _bf_DrawFrame()
        pcall(function()
            local pc = slua_GameFrontendHUD and slua_GameFrontendHUD:GetPlayerController()
            if not slua.isValid(pc) then return end
            local localChar = pc:GetPlayerCharacterSafety()
            if not slua.isValid(localChar) then return end
            local allChars = Game:GetAllPlayerPawns() or {}
            local localTeam = localChar.TeamID or 0
            for _, enemy in pairs(allChars) do
                if slua.isValid(enemy) and enemy ~= localChar and enemy.TeamID ~= localTeam then
                    local isAlive = true
                    pcall(function()
                        if enemy.HealthStatus then
                            local ECharHPStatus = import("ECharacterHealthStatus")
                            isAlive = (enemy.HealthStatus ~= ECharHPStatus.FinishedLastBreath)
                        end
                    end)
                    if isAlive then
                        pcall(function()
                            if enemy.Replay_IsEnemyFrameUIExisted and not enemy:Replay_IsEnemyFrameUIExisted() then
                                enemy:Replay_CreateEnemyFrameUI(true, true)
                            end
                            if enemy.Replay_SetVisiableOfFrameUI then
                                enemy:Replay_SetVisiableOfFrameUI(true)
                            end
                        end)
                    else
                        pcall(function()
                            if enemy.Replay_SetVisiableOfFrameUI then
                                enemy:Replay_SetVisiableOfFrameUI(false)
                            end
                        end)
                    end
                end
            end
        end)
    end

    _G.BlueFrameStart = function()
        if _bf_Timer then return end
        if not _G.BlueFrameConfig or not _G.BlueFrameConfig.Enable then return end
        if _G.Game and _G.Game.AddGameTimer then
            _bf_Timer = _G.Game:AddGameTimer(0.3, true, _bf_DrawFrame)
        else
            local pc = slua_GameFrontendHUD and slua_GameFrontendHUD:GetPlayerController()
            if pc and slua.isValid(pc) and pc.AddGameTimer then
                _bf_Timer = pc:AddGameTimer(0.3, true, _bf_DrawFrame)
            end
        end
    end

    _G.BlueFrameStop = function()
        if _bf_Timer then
            pcall(function() if _G.Game then _G.Game:RemoveGameTimer(_bf_Timer) end end)
            _bf_Timer = nil
        end
        pcall(function()
            local pc = slua_GameFrontendHUD and slua_GameFrontendHUD:GetPlayerController()
            if slua.isValid(pc) then
                local localChar = pc:GetPlayerCharacterSafety()
                if slua.isValid(localChar) then
                    local allChars = Game:GetAllPlayerPawns() or {}
                    local localTeam = localChar.TeamID or 0
                    for _, enemy in pairs(allChars) do
                        if slua.isValid(enemy) and enemy ~= localChar and enemy.TeamID ~= localTeam then
                            pcall(function()
                                if enemy.Replay_SetVisiableOfFrameUI then
                                    enemy:Replay_SetVisiableOfFrameUI(false)
                                end
                            end)
                        end
                    end
                end
            end
        end)
    end

    -- ============================================================
    -- CAR FLY SYSTEM (SRC HUB Vehicle Fly With Horn by XThrlen)
    -- Horn HOLD = UP | Horn Stop = HOVER
    -- Speed = Hover Fly | L/R = turn
    -- Back tap = Back | Back HOLD = Slowly LAND
    -- ============================================================
    _G.CarFlyConfig = _G.CarFlyConfig or { Enable = false, FlySpeed = 1.0 }

    local TXtime_ticker_CF = nil
    pcall(function() TXtime_ticker_CF = require('common.time_ticker') end)

    local CF_CFG = {
        RiseSpeed     = 1800,       -- horn dabao = tez upar jaao (pehle 650 tha)
        HoverRise     = 900,        -- horn hold karne pe持续上升 speed
        FallSpeed     = 600,        -- landing speed
        FlyForwardMax = 2600,
        FlyBackMax    = 1400,
        FlyAccel      = 4500,
        Damp          = 1.8,
        TurnRate      = 110,
        TapBackTime   = 0.25,
        LightMass     = 150,
        ServerSync    = true,
        SyncInterval  = 0.05,
        TiltDamping   = 8.0,        -- car ko level rakhega flight me
        HoverDamp     = 0.6,        -- hover me smooth movement
    }

    local CF_S = { veh=nil, lastVeh=nil, flying=false,
                   vx=0, vy=0, vz=0, downT=0,
                   lastLandZ=nil, landT=0, syncT=0,
                   savedMass=nil, mc=nil,
                   hoverZ=nil, tiltX=0, tiltY=0 }

    local function CF_GetMyVehicle()
        local ok, veh = pcall(function()
            if not slua_GameFrontendHUD then return nil end
            local pc = slua_GameFrontendHUD:GetPlayerController()
            if not pc or not slua.isValid(pc) then return nil end
            local ch = pc.GetPlayerCharacterSafety and pc:GetPlayerCharacterSafety() or nil
            if not ch or not slua.isValid(ch) then return nil end
            return ch:GetCurrentVehicle()
        end)
        if ok and veh and slua.isValid(veh) then return veh end
        return nil
    end

    local function CF_ReadInputs(veh)
        local inp = { down=false, fwd=false, steer=0 }
        pcall(function()
            local mc = veh:GetMovementComponent()
            if not mc or not slua.isValid(mc) then return end
            local rb = tonumber(mc.RawBrakeInput) or 0
            local bi = tonumber(mc.BrakeInput) or 0
            local rt = tonumber(mc.RawThrottleInput) or 0
            local ti = tonumber(mc.ThrottleInput) or 0
            local st = tonumber(mc.RawSteeringInput) or 0
            if rb > 0.05 or bi > 0.05 or rt < -0.05 or ti < -0.05 then inp.down = true end
            if rt > 0.05 or ti > 0.05 then inp.fwd = true end
            if st > 0.05 or st < -0.05 then inp.steer = st end
            if not (inp.down or inp.fwd or inp.steer ~= 0) then
                local rs = mc.ReplicatedState
                if rs then
                    if (tonumber(rs.BrakeInput) or 0) > 0.05 then inp.down = true end
                    if (tonumber(rs.ThrottleInput) or 0) > 0.05 then inp.fwd = true end
                    local s2 = tonumber(rs.SteeringInput) or 0
                    if s2 > 0.05 or s2 < -0.05 then inp.steer = s2 end
                end
            end
        end)
        return inp
    end

    local CF_SETV_MODE = 0
    local function CF_SetVel(rc, vec)
        if CF_SETV_MODE ~= 2 then
            if pcall(function() rc:SetAllPhysicsLinearVelocity(vec, false) end) then
                CF_SETV_MODE = 1
                return true
            end
            CF_SETV_MODE = 2
        end
        local ok = pcall(function() rc:SetPhysicsLinearVelocity(vec, false, "None") end)
        if not ok then
            ok = pcall(function() rc:SetPhysicsLinearVelocity(vec, false) end)
        end
        return ok
    end

    local CF_ANG_MODE = 0
    local function CF_SetAngVel(rc, vx, vy, vz)
        if CF_ANG_MODE ~= 2 then
            if pcall(function() rc:SetPhysicsAngularVelocityInDegrees(FVector(vx, vy, vz), false, "None") end) then
                CF_ANG_MODE = 1
                return true
            end
            CF_ANG_MODE = 2
        end
        return pcall(function() rc:SetPhysicsAngularVelocity(FVector(vx, vy, vz), false, "None") end)
    end

    local function CF_SaveAndLighten(veh)
        pcall(function()
            local mc = veh:GetMovementComponent()
            if mc and slua.isValid(mc) then
                CF_S.mc = mc
                local okM, mval = pcall(function() return tonumber(mc.Mass) end)
                CF_S.savedMass = (okM and mval) or nil
                pcall(function() mc.Mass = CF_CFG.LightMass end)
            end
        end)
    end

    local function CF_RestoreMass()
        pcall(function()
            if CF_S.mc and slua.isValid(CF_S.mc) and CF_S.savedMass then
                CF_S.mc.Mass = CF_S.savedMass
            end
        end)
        CF_S.mc, CF_S.savedMass = nil, nil
    end

    local function CF_EnterFly()
        CF_SaveAndLighten(CF_S.veh)
        CF_S.flying, CF_S.vx, CF_S.vy, CF_S.vz = true, 0, 0, 0
        CF_S.downT, CF_S.hoverZ, CF_S.landT, CF_S.lastLandZ = 0, nil, 0, nil
        CF_S.tiltX, CF_S.tiltY = 0, 0
    end

    local function CF_ExitFly(reason)
        CF_RestoreMass()
        CF_S.flying, CF_S.vx, CF_S.vy, CF_S.vz = false, 0, 0, 0
        CF_S.downT, CF_S.hoverZ, CF_S.landT, CF_S.lastLandZ = 0, nil, 0, nil
        CF_S.tiltX, CF_S.tiltY = 0, 0
    end

    local function CF_Tick(dt)
        if not _G.CarFlyConfig or not _G.CarFlyConfig.Enable then return end
        dt = math.min(tonumber(dt) or 0.033, 0.1)

        -- Speed multiplier (1.0 to 5.0)
        local speedMul = _G.CarFlyConfig.FlySpeed or 1.0

        local veh = CF_GetMyVehicle()
        if veh ~= CF_S.veh then
            if CF_S.flying then CF_ExitFly('EXIT VEHICLE') end
            CF_S.veh = veh
        end
        CF_S.lastVeh = veh
        if not veh then return end

        local horn = false
        pcall(function() horn = (veh.bIsUsingHorn == true) end)
        local inp = CF_ReadInputs(veh)

        if horn and not CF_S.flying then
            CF_EnterFly()
        end
        if not CF_S.flying then return end

        if inp.down then CF_S.downT = CF_S.downT + dt else CF_S.downT = 0 end
        local descending = inp.down and (CF_S.downT >= CF_CFG.TapBackTime)
        local backing    = inp.down and not descending

        local okL, loc = pcall(veh.K2_GetActorLocation, veh)
        if not okL or not loc then return end

        -- Smooth Z velocity (prevents jitter)
        local targetVz = 0
        if horn then
            -- Horn hold = keep going UP smoothly
            if CF_S.hoverZ == nil then CF_S.hoverZ = loc.Z end
            CF_S.hoverZ = CF_S.hoverZ + CF_CFG.HoverRise * speedMul * dt
            local diff = CF_S.hoverZ - loc.Z
            targetVz = diff * 4.0 * speedMul
            targetVz = math.max(math.min(targetVz, CF_CFG.RiseSpeed * speedMul), -CF_CFG.FallSpeed * speedMul)
        elseif descending then
            targetVz = -CF_CFG.FallSpeed * speedMul
            CF_S.hoverZ = nil
        else
            -- Hover: maintain current altitude smoothly
            if CF_S.hoverZ == nil then CF_S.hoverZ = loc.Z end
            local diff = CF_S.hoverZ - loc.Z
            targetVz = diff * 3.0
            targetVz = math.max(math.min(targetVz, 400), -350)
        end
        
        -- Smooth interpolation (prevents sudden jumps)
        CF_S.vz = CF_S.vz + (targetVz - CF_S.vz) * CF_CFG.HoverDamp

        local fx, fy = 0, 0
        pcall(function()
            local f = veh:GetActorForwardVector()
            fx, fy = f.X, f.Y
        end)
        local flen = math.sqrt(fx * fx + fy * fy)
        if flen > 0.001 then fx, fy = fx / flen, fy / flen end

        if inp.fwd then
            CF_S.vx = CF_S.vx + fx * CF_CFG.FlyAccel * speedMul * dt
            CF_S.vy = CF_S.vy + fy * CF_CFG.FlyAccel * speedMul * dt
        elseif backing then
            CF_S.vx = CF_S.vx - fx * CF_CFG.FlyAccel * speedMul * dt
            CF_S.vy = CF_S.vy - fy * CF_CFG.FlyAccel * speedMul * dt
        else
            local d = math.max(0, 1 - CF_CFG.Damp * dt)
            CF_S.vx, CF_S.vy = CF_S.vx * d, CF_S.vy * d
        end
        local hs = math.sqrt(CF_S.vx * CF_S.vx + CF_S.vy * CF_S.vy)
        local hmax = backing and CF_CFG.FlyBackMax or CF_CFG.FlyForwardMax
        if hs > hmax then
            local sc = hmax / hs
            CF_S.vx, CF_S.vy = CF_S.vx * sc, CF_S.vy * sc
        end

        local vec = FVector(CF_S.vx, CF_S.vy, CF_S.vz)
        pcall(function()
            local rc = veh:K2_GetRootComponent()
            if rc and slua.isValid(rc) then CF_SetVel(rc, vec) end
        end)
        pcall(function()
            local m = veh.Mesh
            if m and slua.isValid(m) then CF_SetVel(m, vec) end
        end)

        -- Tilt stabilization: keep car level during flight (prevents flipping/glitching)
        pcall(function()
            local rc = veh:K2_GetRootComponent()
            if rc and slua.isValid(rc) then
                local turnAng = -(inp.steer or 0) * CF_CFG.TurnRate
                -- Add damping to roll/pitch to keep car flat
                CF_SetAngVel(rc, -CF_S.tiltX * CF_CFG.TiltDamping, -CF_S.tiltY * CF_CFG.TiltDamping, turnAng)
            end
        end)

        -- Track tilt for stabilization
        pcall(function()
            local rot = veh:K2_GetActorRotation()
            if rot then
                CF_S.tiltX = rot.Pitch * 0.1
                CF_S.tiltY = rot.Roll * 0.1
            end
        end)

        CF_S.syncT = CF_S.syncT + dt
        if CF_CFG.ServerSync and CF_S.syncT >= CF_CFG.SyncInterval then
            CF_S.syncT = 0
            pcall(veh.ServerImpulseVehicle, veh, FVector(CF_S.vx, CF_S.vy, CF_S.vz), false)
        end

        if descending then
            if CF_S.lastLandZ and math.abs(loc.Z - CF_S.lastLandZ) < 2 then
                CF_S.landT = CF_S.landT + dt
            else
                CF_S.landT = 0
            end
            CF_S.lastLandZ = loc.Z
            if CF_S.landT >= 0.35 then
                CF_ExitFly('LANDED')
                return
            end
        else
            CF_S.landT, CF_S.lastLandZ = 0, nil
        end
    end

    _G.CarFlyConfig.Start = function()
        if _G.CarFlyConfig._Timer then return end
        pcall(function()
            if TXtime_ticker_CF then
                _G.CarFlyConfig._Timer = TXtime_ticker_CF.AddTimerLoop(0, CF_Tick, -1, 0)
            else
                local pc = nil
                pcall(function() pc = slua_GameFrontendHUD:GetPlayerController() end)
                if pc and slua.isValid(pc) and pc.AddGameTimer then
                    _G.CarFlyConfig._Timer = pc:AddGameTimer(0.03, true, CF_Tick)
                end
            end
        end)
    end

    _G.CarFlyConfig.Stop = function()
        CF_ExitFly('DISABLED')
        if _G.CarFlyConfig._Timer then
            pcall(function()
                if TXtime_ticker_CF then
                    TXtime_ticker_CF.RemoveTimer(_G.CarFlyConfig._Timer)
                else
                    local pc = nil
                    pcall(function() pc = slua_GameFrontendHUD:GetPlayerController() end)
                    if pc and slua.isValid(pc) and pc.RemoveGameTimer then
                        pc:RemoveGameTimer(_G.CarFlyConfig._Timer)
                    end
                end
            end)
            _G.CarFlyConfig._Timer = nil
        end
    end

    -- ============================================================
    -- FAST CAR SYSTEM (by kali)
    -- ============================================================
    _G.FastCarEnabled = _G.FastCarEnabled or false
    _G.FastCarSpeed = _G.FastCarSpeed or 3000.0

    _G.FastCarTimer = nil

    local function FastCarTick()
        if not _G.FastCarEnabled then return end
        pcall(function()
            local PlayerController = slua_GameFrontendHUD and slua_GameFrontendHUD:GetPlayerController()
            if not PlayerController then return end
            local uCharacter = PlayerController:GetPlayerCharacterSafety()
            if not uCharacter then return end
            local currentVehicle = uCharacter.CurrentVehicle or (type(uCharacter.GetVehicle) == "function" and uCharacter:GetVehicle())
            if not currentVehicle or not slua.isValid(currentVehicle) then return end

            local rootComp = currentVehicle.RootComponent or (type(currentVehicle.K2_GetRootComponent) == "function" and currentVehicle:K2_GetRootComponent())
            if not rootComp or not slua.isValid(rootComp) then return end

            local moveComp = currentVehicle.VehicleMovement or currentVehicle.MovementComponent
            if not moveComp or not slua.isValid(moveComp) then return end

            local isAccelerating = false
            local throttle = 0
            pcall(function() throttle = tonumber(moveComp.ThrottleInput) or 0 end)
            if throttle < 0.05 then
                pcall(function() throttle = tonumber(moveComp.RawThrottleInput) or 0 end)
            end
            if throttle > 0.05 then isAccelerating = true end

            local speed = _G.FastCarSpeed or 3000.0

            if isAccelerating then
                local fwd = nil
                pcall(function() fwd = currentVehicle:GetActorForwardVector() end)
                if fwd then
                    local vel = FVector(fwd.X * speed, fwd.Y * speed, 0)
                    pcall(function() rootComp:SetAllPhysicsLinearVelocity(vel, false) end)
                end
            else
                local curVel = nil
                pcall(function() curVel = rootComp:GetPhysicsLinearVelocity() end)
                if curVel then
                    local damp = FVector(curVel.X * 0.9, curVel.Y * 0.9, curVel.Z)
                    pcall(function() rootComp:SetAllPhysicsLinearVelocity(damp, false) end)
                end
            end
        end)
    end

    _G.StartFastCar = function()
        if _G.FastCarTimer then return end
        _G.FastCarEnabled = true
        pcall(function()
            if slua_GameFrontendHUD then
                local pc = slua_GameFrontendHUD:GetPlayerController()
                if pc and slua.isValid(pc) and pc.AddGameTimer then
                    _G.FastCarTimer = pc:AddGameTimer(0.02, true, FastCarTick)
                end
            end
        end)
    end

    _G.StopFastCar = function()
        _G.FastCarEnabled = false
        if _G.FastCarTimer then
            pcall(function()
                local pc = slua_GameFrontendHUD and slua_GameFrontendHUD:GetPlayerController()
                if pc and slua.isValid(pc) and pc.RemoveGameTimer then
                    pc:RemoveGameTimer(_G.FastCarTimer)
                end
            end)
            _G.FastCarTimer = nil
        end
    end

    -- ============================================================
    -- FAKE HWID (ANTI-BAN) - PORTED FROM LEXUS / help.lua
    -- ============================================================
    _G.BRFakeHWID = _G.BRFakeHWID or { Enable = true }

    local function BRFakeHWID_Notify(msg)
        local s = "[BR] " .. tostring(msg)
        pcall(function() print(s) end)
        pcall(function()
            local sh = import("ScriptHelperClient")
            if sh and sh.AddOnScreenDebugMessage then
                sh.AddOnScreenDebugMessage(s, -1, 3.0, {R=1, G=1, B=0, A=1}, {X=1.2, Y=1.2})
            end
        end)
    end

    _G.GetOriginalHWID = function()
        if _G.Original_GetDeviceId then return tostring(_G.Original_GetDeviceId()) end
        local SystemLib = import("KismetSystemLibrary")
        if SystemLib and type(SystemLib.GetDeviceId) == "function" then return tostring(SystemLib.GetDeviceId()) end
        return "UNKNOWN_DEVICE"
    end

    local function InitFakeHWID()
        pcall(function()
            local SystemLib = import("KismetSystemLibrary")
            if SystemLib and not _G.FakeHWID_Hooked then
                _G.Original_GetDeviceId = SystemLib.GetDeviceId
                SystemLib.GetDeviceId = function(...)
                    if _G.BRFakeHWID.Enable then
                        if not _G.FakeHWID_String then
                            local chars = "0123456789ABCDEF"
                            local hwid = ""
                            for i = 1, 32 do
                                local idx = math.random(1, #chars)
                                hwid = hwid .. chars:sub(idx, idx)
                                if i == 8 or i == 12 or i == 16 or i == 20 then hwid = hwid .. "-" end
                            end
                            _G.FakeHWID_String = hwid
                        end
                        return _G.FakeHWID_String
                    end
                    if _G.Original_GetDeviceId then return _G.Original_GetDeviceId(...) end
                    return "UNKNOWN"
                end
                _G.FakeHWID_Hooked = true
                BRFakeHWID_Notify("Fake HWID Hook Active")
            end
        end)
    end

    InitFakeHWID()

    -- ============================================================
-- ===== COPIED SKIN SYSTEM (from help.lua) START =====
_G.LexusConfig = _G.LexusConfig or {
    FakeHWID = false,
    EspLoai5 = false, EspLoai6 = false, EspLoai7 = false, EspLoai9 = false,
    Esp7_SoLuong = true, Esp7_VuKhi = true, Esp7_TuThe = true,
    Esp9_Count = true, Esp9_Name = true, Esp9_HP = true, Esp9_Team = true,
    Esp9_Weapon = true, Esp9_Distance = true, Esp9_Line = true, Esp9_Skeleton = true,
    EspAntenna = false, EspOutline = false, OutlineThickness = 10,
    Esp3ShowName = true, Esp3ShowHP = true,
    ColorBodyNew = false, ChamsColorVis = 3, ChamsColorOcc = 1,
    WeaponGlow = false,
    CustomAimbot = false, CustomAimbotClose = false, CustomMagicBullet = false,
    CustomHRecoil = false, CustomVRecoil = false,
    LessShake = false, Accuracy = false, Crosshair = false, AutoHead = false, GodMode = false,
    NoRecoilEnabled = false, RecoilReduction = 100, WeaponAimbot = false,
    AimTouchEnable = false,
    AimTouchHipfire = false, AimTouchHipIgKnock = false, AimTouchHipIgBot = false, AimTouchHipVisCheck = false,
    AimTouchSG = false, AimTouchSGAutoFire = false, AimTouchSGIgKnock = false, AimTouchSGIgBot = false, AimTouchSGVisCheck = false,
    AimTouchScopeAll = false, AimTouchScopeIgKnock = false, AimTouchScopeIgBot = false, AimTouchScopeVisCheck = false,
    AimTouchScopeSniper = false, AimTouchSniperIgKnock = false, AimTouchSniperIgBot = false, AimTouchSniperVisCheck = false,
    AimTouchMortar = false,
    IpadView = false, UnlockFPS = false,
    SmallScope = false, SmallScopeFOV = 75,
    BugManEnable = false, FastCar = false, FastCarSpeed = 3000,
    WallVehicle = false, WhiteBody = false, BlackSky = false,
    RemoveFog = false, RemoveGrass = false, RemoveTrees = false,
    ModEmote = false, ModSkin = false, SkinDeadBox = false, SkinAttachment = false,
    KillMessage = false, KillCountUI = false, SkinOpenLink = false,
}

_G.LexusState = _G.LexusState or {
    LoopToken = 0, NativeESPReady = false, MenuStep = 0, GraphicsUnlocked = false,
    TrackedMarks = {}, EnemyMarks = {}, CustomTextData = nil,
    PrevGraphicsState = {}, LastMagicConfigHash = "",
}

local _cached_linear_color = nil
local _cached_skeletal_mesh = nil
local _cached_gameplay_data = nil

local function getCachedLinearColor()
    if _cached_linear_color == nil then _cached_linear_color = import("LinearColor") or _G.FLinearColor end
    return _cached_linear_color
end

local function getCachedSkeletalMesh()
    if _cached_skeletal_mesh == nil then _cached_skeletal_mesh = import("SkeletalMeshComponent") end
    return _cached_skeletal_mesh
end

local function getCachedGameplayData()
    if _cached_gameplay_data == nil then
        local ok, mod = pcall(require, "GameLua.GameCore.Data.GameplayData")
        if ok then _cached_gameplay_data = mod end
    end
    return _cached_gameplay_data
end

local function GetSafeEnemyKey(enemy)
    if Valid(enemy) then
        if enemy.PlayerKey then return tostring(enemy.PlayerKey) end
        if type(enemy.GetUniqueID) == "function" then return tostring(enemy:GetUniqueID()) end
    end
    return tostring(enemy)
end

local function CheckIsAI(pawn, markData)
    if markData.AK_IS_BOT ~= nil then return markData.AK_IS_BOT, true end
    local isAI = false
    local hasChecked = false
    pcall(function()
        if pawn.bIsAI == true or pawn.IsAI == true then isAI = true; hasChecked = true end
        if type(pawn.IsBot) == "function" and pawn:IsBot() then isAI = true; hasChecked = true end
        local pState = pawn.PlayerState or (type(pawn.GetPlayerState) == "function" and pawn:GetPlayerState())
        if Valid(pState) then
            hasChecked = true
            if pState.bIsABot == true or pState.bIsBot == true then isAI = true end
            if type(pState.IsBot) == "function" and pState:IsBot() then isAI = true end
        end
    end)
    if hasChecked then markData.AK_IS_BOT = isAI end
    return isAI, hasChecked
end

local function GetAllSkeletalMeshes(enemy, markData)
    local curTime = os.clock()
    if markData and markData.CachedMeshes and markData.CachedMeshTime and (curTime - markData.CachedMeshTime < 0.5) then
        local validMeshes = {}
        for _, cachedMesh in ipairs(markData.CachedMeshes) do
            local isPendingKill = false
            pcall(function() if type(cachedMesh.IsPendingKill) == "function" then isPendingKill = cachedMesh:IsPendingKill() end end)
            if Valid(cachedMesh) and not isPendingKill then table.insert(validMeshes, cachedMesh) end
        end
        markData.CachedMeshes = validMeshes
        return validMeshes
    end
    local meshes = {}
    if Valid(enemy.Mesh) then table.insert(meshes, enemy.Mesh) end
    pcall(function()
        local SkeletalMeshClass = getCachedSkeletalMesh()
        if SkeletalMeshClass and type(enemy.GetComponentsByClass) == "function" then
            local childs = enemy:GetComponentsByClass(SkeletalMeshClass)
            if childs then
                local count = type(childs.Num) == "function" and childs:Num() or #childs
                for i = 1, count do
                    local comp = type(childs.Get) == "function" and childs:Get(i-1) or childs[i]
                    if Valid(comp) and comp ~= enemy.Mesh then table.insert(meshes, comp) end
                end
            end
        end
    end)
    if markData then markData.CachedMeshes = meshes; markData.CachedMeshTime = curTime end
    return meshes
end

local function InitFakeHWID()
    pcall(function()
        local SystemLib = import("KismetSystemLibrary")
        if SystemLib and not _G.FakeHWID_Hooked then
            _G.Original_GetDeviceId = SystemLib.GetDeviceId
            SystemLib.GetDeviceId = function(...)
                if _G.LexusConfig.FakeHWID then
                    if not _G.FakeHWID_String then
                        local chars = "0123456789ABCDEF"
                        local hwid = ""
                        for i = 1, 32 do
                            local idx = math.random(1, #chars)
                            hwid = hwid .. chars:sub(idx, idx)
                            if i == 8 or i == 12 or i == 16 or i == 20 then hwid = hwid .. "-" end
                        end
                        _G.FakeHWID_String = hwid
                    end
                    return _G.FakeHWID_String
                end
                if _G.Original_GetDeviceId then return _G.Original_GetDeviceId(...) end
                return "UNKNOWN"
            end
            _G.FakeHWID_Hooked = true
            Notify("Fake HWID Hook Active")
        end
    end)
end

-- ====================================================================
-- SKIN SYSTEM: Helper Functions
-- ====================================================================
local function nop() return true end
local function retFalse() return false end
local function retZero() return 0 end
local function retEmpty() return {} end
local function retNil() return nil end
local function retTrue() return true end
local function retEmptyString() return "" end

function _G.InitializeSkinBypass()
    pcall(function()
        local ptlog = package.loaded["client.slua.logic.download.report.puffer_tlog"]
        if ptlog then ptlog.ReportEvent = nop; ptlog.ReportDownloadResult = nop; ptlog.ReportODPTDError = nop; ptlog.ReportSkinError = nop end
        local AvatarUtils = package.loaded["AvatarUtils"]
        if AvatarUtils then AvatarUtils.CheckIsWeaponInBlackList = retFalse; AvatarUtils.IsValidAvatar = retTrue; AvatarUtils.CheckAvatarIntegrity = retTrue; AvatarUtils.ReportInvalidAvatar = nop end
        local sub = require("GameLua.GameCore.Module.Subsystem.SubsystemMgr"):Get("FileCheckSubsystem")
        if sub then sub.StartCheck = nop; sub.ReportAbnormalFile = nop; sub.StopCheck = nop end
        local eqEx = package.loaded["client.slua.logic.report.EquipmentExceptionReport"]
        if eqEx then eqEx.Report = nop; eqEx.SendException = nop end
    end)
end

-- ====================================================================
-- SKIN SYSTEM: DATA TABLES
-- ====================================================================
_G.VIP_Attachments = {
    [1101004236]={1010042307,1010042306,1010042308,1010042304,1010042300,1010042305,1010042299,1010042298,1010042297,1010042296,1010042295,1010042294,0,1010042314,1010042309,1010042316,1010042317,1010042318,1010042310,1010042315,1010042319,0},
    [1101001116]={1010011106,1010011107,1010011108,0,1010011109,1010011112,1010011105,1010011104,1010011103,0,1010011102,0,0,0,0,0,0,0,0,0,0,0},
    [1101001128]={1010011232,1010011233,1010011234,1010011228,1010011227,1010011229,1010011226,1010011225,1010011224,1010011223,1010011222,0,0,0,0,0,0,0,0,0,0,0},
    [1101001154]={1010011487,1010011488,1010011489,1010011493,1010011490,1010011494,1010011486,1010011485,1010011484,1010011483,1010011482,1010011497,0,0,0,0,0,0,0,0,1010011498,0},
    [1101001174]={1010011667,1010011668,1010011669,1010011673,1010011670,1010011674,1010011666,1010011665,1010011664,1010011663,1010011662,0,0,0,0,0,0,0,0,0,0,0},
    [1101001213]={1010012067,1010012068,1010012069,1010012072,1010012070,1010012073,1010012066,1010012065,1010012064,1010012063,1010012062,0,0,0,0,0,0,0,0,1010012074,0},
    [1101001231]={1010012267,1010012268,1010012269,1010012273,1010012272,1010012274,1010012266,1010012265,1010012264,1010012263,1010012262,1010012075,0,0,0,0,0,0,0,0,1010012275,0},
    [1101001242]={1010012357,1010012358,1010012359,1010012363,1010012362,1010012364,1010012356,1010012355,1010012354,1010012353,1010012352,1010012276,0,0,0,0,0,0,0,0,1010012365,0},
    [1101001249]={1010012437,1010012438,1010012439,1010012443,1010012442,1010012444,1010012436,1010012435,1010012434,1010012433,1010012432,1010012366,0,0,0,0,0,0,0,0,1010012445,0},
    [1101001256]={1010012588,1010012589,1010012590,1010012593,1010012592,1010012594,1010012587,1010012586,1010012585,1010012584,1010012583,1010012582,0,0,0,0,0,0,0,0,1010012595,0},
    [1101001265]={1010012698,1010012699,1010012700,1010012703,1010012702,1010012704,1010012697,1010012696,1010012695,1010012694,1010012693,1010012692,0,0,0,0,0,0,0,0,1010012705,0},
    [1101001276]={1010012698,1010012699,1010012700,1010012703,1010012702,1010012704,1010012697,1010012696,1010012695,1010012694,1010012693,1010012692,0,0,0,0,0,0,0,0,1010012705,0},
    [1101002029]={1010020249,1010020250,1010020255,1010020247,1010020246,1010020248,1010020240,1010020239,1010020238,1010020237,1010020236,1010020235,0,0,0,0,0,0,0,1010020257,1010020256,1010020258},
    [1101002056]={1010020519,0,0,1010020517,1010020516,1010020518,1010020500,1010020509,1010020508,1010020507,1010020506,1010020505,0,0,0,0,0,0,0,0,0,0},
    [1101002081]={1010020768,1010020769,1010020770,1010020766,1010020760,1010020767,1010020759,1010020758,1010020757,1010020756,1010020755,1010020776,0,0,0,0,0,0,0,1010020775,1010020777,1010020778},
    [1101003070]={1010030654,1010030653,1010030655,1010030649,1010030648,1010030650,1010030647,1010030646,1010030645,1010030644,1010030643,1010030642,0,1010030658,1010030656,1010030660,1010030662,1010030659,1010030657,0,1010030663,0},
    [1101003080]={1010030754,1010030753,1010030755,1010030749,1010030748,1010030750,1010030747,1010030746,1010030745,1010030744,1010030743,1010030742,0,1010030758,1010030756,1010030760,1010030762,1010030759,1010030757,0,1010030763,0},
    [1101003099]={1010030943,1010030944,1010030945,1010030939,1010030938,1010030942,1010030937,1010030936,1010030935,1010030934,1010030933,1010030932,0,1010030947,1010030946,1010030948,1010030949,1010030953,1010030952,0,1010030955,0},
    [1101003119]={1010031139,1010031140,1010031142,1010031138,1010031137,1010031146,1010031136,1010031135,1010031134,1010031133,1010031132,0,0,1010031144,1010031143,0,0,0,1010031145,0,0,0},
    [1101003146]={1010031229,1010031230,1010031237,1010031228,1010031227,1010031242,1010031226,1010031225,1010031224,1010031223,1010031222,0,0,1010031239,1010031238,0,0,0,1010031240,0,0,0},
    [1101003167]={1010031609,1010031610,1010031613,1010031608,1010031607,1010031617,1010031606,1010031605,1010031604,1010031603,1010031602,1010031618,0,1010031615,1010031614,1010031620,1010031622,1010031619,1010031616,0,1010031623,0},
    [1101003181]={1010031765,1010031764,1010031766,1010031759,1010031758,1010031763,1010031757,1010031756,1010031755,1010031754,1010031753,1010031752,0,1010031769,1010031767,1010031773,1010031774,1010031772,1010031768,0,1010031775,0},
    [1101003195]={1010031912,1010031911,1010031913,1010031908,1010031907,1010031909,1010031906,1010031905,1010031904,1010031903,1010031902,1010031901,0,1010031916,1010031914,1010031918,1010031919,1010031917,1010031915,0,1010031921,0},
    [1101003208]={1010032034,1010032033,1010032045,1010032029,1010032028,1010032032,1010032027,1010032026,1010032025,1010032024,1010032023,1010032022,0,1010032038,1010032036,1010032042,1010032043,1010032039,1010032037,0,1010032044,0},
    [1101004046]={1010040474,1010040475,1010040476,1010040472,1010040471,1010040473,1010040470,1010040469,1010040468,1010040467,1010040466,1010040481,0,1010040479,1010040477,1010040482,1010040483,1010040484,1010040478,1010040480,1010040485,0},
    [1101004062]={1010040578,1010040577,1010040579,1010040575,1010040570,1010040576,1010040569,1010040568,1010040567,1010040566,1010040565,1010040564,0,1010040585,1010040580,1010040587,1010040588,1010040589,1010040584,1010040586,1010040590,1010040594},
    [1101004098]={1010040924,1010040926,1010040925,0,1010040937,1010040938,1010040935,1010040934,1010040929,1010040928,1010040927,0,0,1010040939,1010040945,0,0,0,1010040944,1010040936,0,0},
    [1101004138]={1010041136,1010041137,1010041138,1010041134,1010041129,1010041135,1010041128,1010041127,1010041126,1010041125,1010041124,0,0,1010041145,1010041139,0,0,0,1010041144,1010041146,0,0},
    [1101004163]={1010041570,1010041574,1010041575,1010041568,1010041567,1010041569,1010041566,1010041565,1010041564,1010041560,1010041554,0,0,1010041578,1010041576,0,0,0,1010041577,1010041579,0,0},
    [1101004201]={1010041956,1010041957,1010041958,1010041950,1010041949,1010041955,1010041948,1010041947,1010041946,1010041945,1010041944,1010041967,0,1010041965,1010041959,0,0,0,1010041960,1010041966,0,0},
    [1101004209]={1010042038,1010042037,1010042039,1010042035,1010042034,1010042036,1010042029,1010042028,1010042027,1010042026,1010042025,1010042024,0,1010042046,1010042044,1010042048,1010042049,1010042054,1010042045,1010042047,1010042055,0},
    [1101004218]={1010042128,1010042127,1010042129,1010042125,1010042124,1010042126,1010042119,1010042118,1010042117,1010042116,1010042115,1010042114,0,1010042136,1010042134,1010042138,1010042139,1010042144,1010042135,1010042137,1010042145,0},
    [1101004226]={1010042238,1010042237,1010042239,1010042235,1010042234,1010042236,1010042233,1010042232,1010042231,1010042219,1010042218,1010042217,0,1010042243,1010042241,1010042245,1010042246,1010042247,1010042242,1010042244,1010042248,0},
    [1101004246]={1010042406,1010042407,1010042408,1010042404,1010042400,1010042405,1010042399,1010042398,1010042397,1010042396,1010042395,1010042394,0,1010042414,1010042409,1010042416,1010042417,1010042418,1010042410,1010042415,1010042419,1010042420},
    [1101005038]={0,0,1010050327,1010050329,1010050328,1010050330,1010050326,1010050325,1010050324,1010050323,1010050322,1010050334,0,0,0,0,0,0,0,0,0,0},
    [1101005052]={0,0,1010050467,1010050469,1010050468,1010050470,1010050466,1010050465,1010050464,1010050463,1010050462,1010050473,0,0,0,0,0,0,0,0,0,0},
    [1101005098]={0,0,1010050928,1010050930,1010050929,1010050932,1010050927,1010050926,1010050925,1010050924,1010050923,1010050922,0,0,0,0,0,0,0,0,0,0},
    [1101006062]={1010060573,1010060572,1010060574,1010060564,1010060563,1010060571,1010060562,1010060561,1010060554,1010060553,1010060552,1010060551,0,1010060583,1010060581,1010060591,1010060592,1010060584,1010060582,0,1010060593,0},
    [1101006075]={1010060702,1010060701,1010060703,1010060698,1010060697,1010060699,1010060696,1010060695,1010060694,1010060693,1010060692,1010060691,0,1010060706,1010060704,1010060708,1010060709,1010060707,1010060705,0,1010060711,0},
    [1101006085]={1010060796,1010060795,1010060797,1010060793,1010060789,1010060794,1010060788,1010060787,1010060786,1010060785,1010060784,1010060783,0,1010060800,1010060798,1010060804,1010060805,1010060803,1010060799,0,1010060806,0},
    [1101007046]={1010070410,1010070413,1010070414,1010070408,1010070407,1010070409,1010070406,1010070405,1010070404,1010070403,1010070402,1010070418,0,1010070417,1010070415,1010070420,1010070422,1010070419,1010070416,0,1010070423,0},
    [1101007062]={1010070579,1010070578,1010070581,1010070576,1010070575,1010070577,1010070574,1010070573,1010070572,1010070571,1010070569,1010070568,0,1010070584,1010070582,1010070585,1010070586,1010070587,1010070583,0,1010070588,0},
    [1101007071]={1010070663,1010070662,1010070664,1010070659,1010070658,1010070660,1010070657,1010070656,1010070655,1010070654,1010070653,1010070652,0,1010070667,1010070665,1010070668,1010070669,1010070670,1010070666,0,1010070672,0},
    [1101008051]={1010080463,1010080464,1010080465,1010080459,1010080458,1010080462,1010080457,1010080456,1010080455,1010080454,1010080453,1010080452,0,1010080467,1010080466,1010080468,1010080469,1010080473,1010080472,0,1010080475,0},
    [1101008061]={1010080563,1010080564,1010080565,1010080559,1010080558,1010080562,1010080557,1010080556,1010080555,1010080554,1010080553,0,0,1010080567,1010080566,0,0,0,1010080572,0,0,0},
    [1101008070]={1010080609,1010080612,1010080613,1010080608,1010080607,1010080617,1010080606,1010080605,1010080604,1010080603,1010080602,0,0,1010080615,1010080614,0,0,0,1010080616,0,0,0},
    [1101008081]={1010080740,1010080743,1010080745,1010080738,1010080737,1010080739,1010080736,1010080735,1010080734,1010080733,1010080732,1010080748,0,1010080747,1010080746,1010080750,1010080752,1010080749,1010080744,0,1010080753,0},
    [1101008104]={1010080980,1010080982,1010080984,1010080978,1010080977,1010080979,1010080976,1010080975,1010080974,1010080973,1010080972,1010080992,0,1010080986,1010080985,1010080989,1010080987,1010080993,1010080983,0,1010080988,0},
    [1101008116]={1010081110,1010081112,1010081114,1010081108,1010081107,1010081109,1010081106,1010081105,1010081104,1010081103,1010081102,0,0,1010081116,1010081115,0,0,0,1010081113,0,0,0},
    [1101008126]={1010081210,1010081225,1010081226,1010081208,1010081207,1010081209,1010081206,1010081205,1010081204,1010081203,1010081202,1010081218,0,1010081217,1010081216,1010081219,1010081220,1010081222,1010081214,1010081228,1010081227,1010081229},
    [1101008136]={1010081314,1010081315,1010081316,1010081312,1010081308,1010081313,1010081307,1010081306,1010081305,1010081304,1010081303,1010081302,0,1010081318,1010081317,1010081322,1010081323,1010081325,1010081324,0,1010081326,0},
    [1101008146]={1010081401,1010081402,1010081403,1010081398,1010081397,1010081399,1010081396,1010081395,1010081394,1010081393,1010081392,1010081391,0,1010081405,1010081404,1010081406,1010081407,1010081409,1010081408,0,1010081411,0},
    [1101008154]={1010081531,1010081532,1010081533,1010081528,1010081527,1010081529,1010081526,1010081525,1010081524,1010081523,1010081522,1010081521,0,1010081541,1010081534,1010081542,1010081543,1010081545,1010081544,0,1010081546,0},
    [1101008163]={1010081582,1010081583,1010081584,1010081579,1010081578,1010081580,1010081577,1010081576,1010081575,1010081574,1010081573,1010081572,0,1010081586,1010081585,1010081587,1010081588,1010081590,1010081589,0,1010081592,0},
    [1101012033]={1010120284,1010120285,1010120286,1010120280,1010120279,1010120283,1010120278,1010120277,1010120276,1010120275,1010120274,1010120273,0,0,0,0,0,0,0,0,1010120287,0},
    [1101100012]={1011000066,1011000067,1011000068,0,0,0,1011000058,1011000057,1011000056,1011000055,1011000054,1011000053,0,0,0,0,0,0,0,0,1011000073,0},
    [1101102007]={1011010025,1011010024,1011010026,1011010020,1011010019,1011010023,1011010018,1011010017,1011010016,1011010015,1011010014,1011010013,0,0,0,0,0,0,0,0,1011010027,0},
    [1101102017]={1011020027,1011020028,1011020029,1011020025,1011020024,1011020026,1011020019,1011020018,1011020017,1011020016,1011020015,1011020014,0,1011020036,1011020034,1011020038,1011020039,1011020044,1011020035,1011020037,1011020045,1011020047},
    [1101102025]={1011020127,1011020128,1011020129,1011020125,1011020124,1011020126,1011020119,1011020118,1011020117,1011020116,1011020115,1011020114,0,1011020136,1011020134,1011020138,1011020139,1011020144,1011020135,1011020137,1011020145,0},
    [1101102041]={1011020214,1011020215,1011020216,1011020212,1011020211,1011020213,1011020209,1011020208,1011020207,1011020206,1011020205,1011020204,0,1011020219,1011020217,1011020222,1011020223,1011020224,1011020218,1011020221,1011020225,1011020229},
    [1101102049]={1011020356,1011020357,1011020358,1011020354,1011020350,1011020355,1011020349,1011020348,1011020347,1011020346,1011020345,1011020344,0,1011020364,1011020359,1011020366,1011020367,1011020368,1011020360,1011020365,1011020369,1011020370},
    [1101101007]={1011020436,1011020437,1011020438,1011020434,1011020430,1011020435,1011020429,1011020428,1011020427,1011020426,1011020425,1011020424,0,1011020444,1011020439,1011020446,1011020447,1011020448,1011020440,1011020445,1011020449,1011020450},
    [1102001120]={1020011137,1020011138,1020011139,1020011135,1020011134,1020011136,1020011133,1020011132,0,0,0,0,0,0,0,0,0,0,0,1020011142,0,0},
    [1102001130]={1020011247,1020011248,1020011249,1020011245,1020011244,1020011246,1020011243,1020011242,0,0,0,0,0,0,0,0,0,0,0,1020011250,0,0},
    [1102002043]={1020020372,1020020374,1020020373,1020020383,1020020380,1020020384,1020020379,1020020378,1020020377,1020020376,1020020375,1020020388,0,1020020385,1020020387,0,0,0,1020020386,0,0,0},
    [1102002061]={1020020552,1020020554,1020020553,1020020563,1020020562,1020020564,1020020559,1020020558,1020020557,1020020556,1020020555,1020020578,0,1020020565,1020020567,1020020573,1020020574,1020020572,1020020566,0,1020020569,0},
    [1102002136]={1020021314,1020021313,1020021315,1020021309,1020021308,1020021312,1020021307,1020021306,1020021305,1020021304,1020021303,1020021302,0,1020021318,1020021316,1020021323,1020021324,1020021322,1020021317,0,1020021325,0},
    [1102002424]={1020024193,1020024192,1020024194,1020024189,1020024188,1020024190,1020024187,1020024186,1020024185,1020024184,1020024183,1020024182,0,1020024197,1020024195,1020024199,1020024200,1020024198,1020024196,0,1020024202,0},
    [1102003080]={1020030755,1020030756,1020030758,0,1020030749,1020030754,1020030748,1020030747,1020030746,1020030745,1020030744,1020030764,0,1020030760,0,1020030759,1020030757,0,0,1020030765,0,0},
    [1102003100]={1020030956,1020030957,1020030958,1020030954,1020030950,1020030955,1020030949,1020030948,1020030947,1020030946,1020030945,1020030944,0,1020030964,0,1020030960,1020030959,1020030965,0,1020030967,1020030966,1020030968},
    [1102005064]={1020050588,1020050589,1020050590,0,0,0,1020050587,1020050586,1020050585,1020050584,1020050583,1020050582,0,0,0,0,0,0,0,0,1020050592,0},
    [1103001101]={1030010954,1030010955,1030010956,0,0,0,0,0,0,0,1030010953,1030010952,1030010951,0,0,0,0,0,0,1030010957,0,1030010958},
    [1103001146]={1030011344,1030011345,1030011346,0,0,0,0,0,0,0,1030011343,1030011342,1030011341,0,0,0,0,0,0,1030011347,0,1030011348},
    [1103001154]={1030011484,1030011485,1030011486,0,0,0,0,0,0,0,1030011483,1030011482,1030011481,0,0,0,0,0,0,1030011487,0,1030011488},
    [1103001179]={1030011738,1030011739,1030011741,0,0,0,1030011737,1030011736,1030011735,1030011734,1030011733,1030011732,1030011731,0,0,0,0,0,0,1030011742,1030011743,1030011744},
    [1103001191]={1030011858,1030011859,1030011861,0,0,0,1030011857,1030011856,1030011855,1030011854,1030011853,1030011852,1030011851,0,0,0,0,0,0,1030011862,1030011863,1030011864},
    [1103001202]={1030011948,1030011949,1030011950,0,0,0,1030011947,1030011946,1030011945,1030011944,1030011943,1030011942,1030011941,0,0,0,0,0,0,1030011951,1030011952,1030011953},
    [1103002030]={1030020245,1030020246,1030020247,1030020252,1030020249,1030020253,1030020258,1030020257,1030020256,1030020255,1030020244,1030020243,1030020242,0,0,0,0,0,0,1030020248,0,0},
    [1103002059]={1030020544,1030020545,1030020546,1030020542,1030020539,1030020543,1030020538,1030020537,1030020536,1030020535,1030020534,1030020533,1030020532,0,0,0,0,0,0,1030020547,1030020548,0},
    [1103002087]={1030020824,1030020825,1030020826,0,0,0,1030020818,1030020817,1030020816,1030020815,1030020814,1030020813,1030020812,0,0,0,0,0,0,1030020827,1030020828,0},
    [1103002106]={1030021009,1030021010,1030021012,1030021015,1030021014,1030021016,1030021008,1030021007,1030021006,1030021005,1030021004,1030021003,1030021002,0,0,0,0,0,0,1030021013,1030021017,0},
    [1103002113]={1030021079,1030021080,1030021082,1030021085,1030021084,1030021086,1030021078,1030021077,1030021076,1030021075,1030021074,1030021073,1030021072,0,0,0,0,0,0,1030021083,1030021087,0},
    [1103003022]={1030030165,1030030166,1030030167,1030030172,1030030169,1030030173,0,0,0,0,1030030164,1030030163,1030030162,0,0,0,0,0,0,0,0,0},
    [1103003030]={1030030256,1030030257,1030030258,1030030254,1030030253,1030030255,1030030248,1030030247,1030030246,1030030245,1030030244,1030030243,1030030242,0,0,0,0,0,0,1030030259,1030030249,0},
    [1103003042]={1030030374,1030030375,1030030376,1030030372,1030030369,1030030373,0,0,0,0,1030030364,1030030363,1030030362,0,0,0,0,0,0,1030030377,0,0},
    [1103003051]={1030030458,1030030459,1030030460,1030030456,1030030455,1030030457,0,0,0,0,1030030454,1030030453,1030030452,0,0,0,0,0,0,1030030463,0,0},
    [1103003062]={1030030568,1030030569,1030030570,1030030566,1030030565,1030030567,0,0,0,0,1030030564,1030030563,1030030562,0,0,0,0,0,0,1030030572,0,0},
    [1103003079]={1030030744,1030030745,1030030746,1030030742,1030030740,1030030743,1030030738,1030030737,1030030736,1030030735,1030030734,1030030733,1030030732,0,0,0,0,0,0,1030030747,1030030739,0},
    [1103003087]={1030030825,1030030826,1030030827,1030030823,1030030824,1030030824,1030030818,1030030817,1030030816,1030030815,1030030814,1030030813,1030030812,0,0,0,0,0,0,1030030828,1030030819,0},
    [1103004037]={1030040315,1030040316,1030040317,1030040325,1030040324,1030040323,0,0,0,0,1030040314,1030040313,1030040312,1030040327,1030040326,0,0,0,1030040328,1030040329,0,0},
    [1103006030]={1030060245,1030060246,1030060247,0,1030060253,1030060252,0,0,0,0,1030060244,1030060243,1030060242,0,0,0,0,0,0,0,0,0},
    [1103007028]={1030070233,1030070234,1030070235,1030070226,1030070225,1030070227,1030070218,1030070217,1030070216,1030070215,1030070214,1030070213,1030070212,0,0,0,0,0,0,1030070236,1030070219,0},
    [1103012010]={0,0,0,0,0,0,1030120038,1030120037,1030120036,1030120035,1030120034,1030120033,1030120032,0,0,0,0,0,0,0,0,0},
    [1103012019]={0,0,0,0,0,0,1030120138,1030120137,1030120136,1030120135,1030120134,1030120133,1030120132,0,0,0,0,0,0,0,0,0},
    [1103012031]={0,0,0,0,0,0,1030120258,1030120257,1030120256,1030120255,1030120254,1030120253,1030120252,0,0,0,0,0,0,0,0,0},
    [1103012039]={0,0,0,0,0,0,1030120339,1030120338,1030120337,1030120336,1030120335,1030120334,1030120333,0,0,0,0,0,0,0,0,0},
    [1103102007]={1031020026,1031020027,1031020028,1031020024,1031020023,1031020025,1031020019,1031020018,1031020017,1031020016,1031020015,1031020014,1031020013,0,0,0,0,0,0,1031020029,0,0},
    [1105001034]={0,0,0,0,1050010287,1050010289,1050010286,1050010285,1050010284,1050010283,1050010282,0,0,0,0,0,0,0,0,1050010292,0,0},
    [1105001048]={0,0,0,1050010429,1050010428,1050010434,1050010427,1050010426,1050010425,1050010424,1050010423,0,0,0,0,0,0,0,0,1050010435,0,1050010436},
    [1105001069]={0,0,0,1050010639,1050010638,1050010640,1050010637,1050010636,1050010635,1050010634,1050010633,1050010645,0,0,0,0,0,0,0,1050010643,1050010646,1050010644},
    [1105002091]={0,0,0,0,0,0,1050020847,1050020846,1050020845,1050020844,1050020843,1050020842,0,0,0,0,0,0,0,0,0,1050020848},
    [1105010019]={0,0,0,0,0,0,1050100144,1050100143,1050100142,1050100141,1050100139,1050100138,0,0,0,0,0,0,0,0,0,0}
}

_G.BaseAttachToIndex = {
    [201010]=1, [201005]=1, [201004]=1, [201009]=2, [201003]=2, [201002]=2, 
    [201011]=3, [201007]=3, [201006]=3, [204012]=4, [204005]=4, [204008]=4, 
    [204011]=5, [204004]=5, [204007]=5, [204013]=6, [204006]=6, [204009]=6, 
    [203001]=7, [203002]=8, [203003]=9, [203014]=10, [203004]=11, [203015]=12, [203005]=13, 
    [202002]=14, [202001]=15, [202004]=16, [202005]=17, [202007]=18, [202006]=19, 
    [205002]=20, [205003]=20, [205001]=20, [203018]=21, [204014]=22 
}

_G.VipAttachToIndex = {}
for skinId, attachList in pairs(_G.VIP_Attachments) do
    for index, attachId in ipairs(attachList) do
        if attachId > 0 then
            _G.VipAttachToIndex[attachId] = index
        end
    end
end

local _SKIN_BASE_PATH    = "/storage/emulated/0/Android/data/com.pubg.imobile/files/"
local _SKIN_ATTACH_PATH  = _SKIN_BASE_PATH .. "attachments.txt"
_G.g_parts = _G.g_parts or {}
_G.skinAttachCache = _G.skinAttachCache or {}

local ATTACH_NAME_MAP = {
    ["Red Dot Sight"]          = "RedDot",
    ["Holographic Sight"]      = "Holo",
    ["2x Scope"]               = "Scope2x",
    ["3x Scope"]               = "Scope3x",
    ["4x Scope"]               = "Scope4x",
    ["6x Scope"]               = "Scope6x",
    ["8x Scope"]               = "Scope8x",
    ["Canted Sight"]           = "CantedSight",
    ["Flash Hider"]            = "FlashHider",
    ["Compensator"]            = "Compensator",
    ["Suppressor"]             = "Suppressor",
    ["Extended Mag"]           = "ExtMag",
    ["Quickdraw Mag"]          = "QuickMag",
    ["Extended Quickdraw Mag"] = "ExtQuickMag",
    ["Angled Foregrip"]        = "AngledGrip",
    ["Vertical Foregrip"]      = "VerticalGrip",
    ["Thumb Grip"]             = "ThumbGrip",
    ["Half Grip"]              = "HalfGrip",
    ["Light Grip"]             = "LightGrip",
    ["Laser Sight"]            = "LaserSight",
    ["Tactical Stock"]         = "TactStock",
    ["Stock"]                  = "MicroStock",
    ["Cheek Pad"]              = "CheekPad",
}

local _attachFileCache = nil

local function _parseAttachmentsFile()
    local result = {}
    pcall(function()
        local f = io.open(_SKIN_ATTACH_PATH, "r")
        if not f then return end
        local content = f:read("*all")
        f:close()
        local curSkin = nil
        for line in content:gmatch("[^\r\n]+") do
            local firstNum = line:match("^(%d+)%s*|")
            if firstNum then
                local num = tonumber(firstNum)
                if num and num > 1100000000 then
                    curSkin = num
                    result[curSkin] = result[curSkin] or {}
                elseif num and curSkin then
                    local attachName = line:match("^%d+%s*|%s*%x+%s*|%s*(.-)%s*$")
                    if not attachName then attachName = line:match("^%d+%s*|%s*(.-)%s*$") end
                    if attachName and attachName ~= "" then
                        local key = ATTACH_NAME_MAP[attachName]
                        if key then result[curSkin][key] = num end
                    end
                end
            elseif line:find("^#%-%-%-%-") and line:find("skin") then
                curSkin = nil
            end
        end
    end)
    return result
end

_G.GetAttachForSkin = function(skinId, key)
    if not skinId or skinId == 0 or not key then return nil end
    if not _attachFileCache then _attachFileCache = _parseAttachmentsFile() end
    local t = _attachFileCache[skinId]
    if not t then return nil end
    local v = t[key]
    return (v and v > 0) and v or nil
end

_G.GetAttachFileCache = function()
    if not _attachFileCache then _attachFileCache = _parseAttachmentsFile() end
    return _attachFileCache
end

_G.download_item = function(i)
    if not i then return end
    pcall(function()
        local PM = require("client.slua.logic.download.puffer.puffer_manager")
        local PC = require("client.slua.logic.download.puffer_const")
        if PM.GetState(PC.ENUM_DownloadType.ODPAK, {i}) ~= PC.ENUM_DownloadState.Done then
            PM.Download(PC.ENUM_DownloadType.ODPAK, {i})
        end
    end)
end

_G.muzzles = {
    id_flash_hider = { 201010, 201005, 201004 },
    id_compensator = { 201009, 201003, 201002 },
    id_suppressor  = { 201011, 201006, 201007 }
}
_G.foregrips = {
    id_Angledforegrip = 202001,
    id_thumb_grip     = 202006,
    id_vertical_grip  = 202002,
    id_light_grip     = 202004,
    id_half_grip      = 202005,
    id_ergonomic_grip = 202051,
    id_laser_sight    = 202007
}
_G.magazines = {
    id_expanded_mag       = { 204011, 204007, 204004 },
    id_quick_mag          = { 204012, 204008, 204005 },
    id_expanded_quick_mag = { 204013, 204009, 204006 }
}
_G.scopes = {
    id_reddot = 203001,
    id_holo   = 203002,
    id_2x     = 203003,
    id_3x     = 203014,
    id_4x     = 203004,
    id_6x     = 203015,
    id_8x     = 203005
}
_G.stock = {
    id_microStock = 205001,
    id_tactical   = 205002,
    id_bulletloop = 204014,
    id_CheekPad   = 205003
}

_G.ItemUpgradeSystem = nil
pcall(function()
    local MM  = require("client.module_framework.ModuleManager")
    local IUS = MM.GetModule(MM.CommonModuleConfig.ItemUpgradeManager)
    if IUS then
        IUS:DefineAndResetData()
        IUS:OnInitialize()
        _G.ItemUpgradeSystem = IUS
    end
end)

_G.get_group_id = function(itemId)
    if not _G.ItemUpgradeSystem or not itemId then return nil end
    local cfg = _G.ItemUpgradeSystem:GetUpgradeCfg(itemId)
    return cfg and cfg.GroupID or nil
end

_G.InitParts = function(groupId, itemId)
    if not itemId then return _G.g_parts end
    if _G.g_parts[itemId] and next(_G.g_parts[itemId]) then return _G.g_parts end
    _G.g_parts[itemId] = {}
    if not _G.ItemUpgradeSystem then return _G.g_parts end
    if _G.ItemUpgradeSystem:IsWeaponIsRefit(itemId) then
        groupId = _G.ItemUpgradeSystem:GetNormalGroupID(groupId or _G.get_group_id(itemId))
    else
        groupId = groupId or _G.get_group_id(itemId)
    end
    if not groupId then return _G.g_parts end
    local cfg = rawGetTableByFilter("ItemUpgradeUnLockConfig", "GroupID", groupId)
    if cfg then
        for _, info in pairs(cfg) do
            local partId = info.PartId
            if _G.ItemUpgradeSystem:IsWeaponIsRefit(itemId) then
                local switched = _G.ItemUpgradeSystem:PartIDSwitch(partId, true)
                if switched and switched ~= partId then partId = switched end
            end
            local item = rawGetTableData("Item", partId)
            if item and item.ItemName then
                _G.g_parts[itemId][item.ItemName] = partId
            end
        end
    end
    return _G.g_parts
end

_G.GetRawAttachMap = function(skinid)
    if not skinid or skinid <= 0 then return {} end
    if _G.skinAttachCache[skinid] then return _G.skinAttachCache[skinid] end
    local UAvatarUtils = import("AvatarUtils")
    if not UAvatarUtils then return {} end
    local list = UAvatarUtils.GetWeaponAvatarDefaultAttachmentSkin(skinid, {}, false) or {}
    _G.skinAttachCache[skinid] = list
    return list
end

_G.GetSlotFromSkinID = function(skinid, slot)
    if not skinid or not slot then return 0 end
    local list = _G.GetRawAttachMap(skinid)
    local attachmentTypeMap = {
        [1] = {291004,291102,291001,291006,291005,291002,293003,293004,293009,293007,293005,293006,295001,295002,291007,291003,292002,292003,291011,291008},
        [2] = {205005,205102,205007,205009,205006},
        [3] = {203008,203009,203006,203022,203010}
    }
    local targetIDs = attachmentTypeMap[slot]
    if not targetIDs then return 0 end
    for _, targetID in ipairs(targetIDs) do
        for attachID, attachSkinID in pairs(list) do
            if attachID == targetID then return attachSkinID end
        end
    end
    return 0
end

_G.AutoDetectAttach = function(skinid, base_id)
    if not skinid or not base_id then return 0 end
    local list = _G.GetRawAttachMap(skinid)
    local v = list[base_id]
    return (v and v > 0) and v or 0
end

_G.get_muzzleid = function(current_id, avatarid)
    local initial_id = current_id
    _G.InitParts(_G.get_group_id(avatarid), avatarid)
    local p = _G.g_parts[avatarid]
    local function is_in(t)
        for _, id in ipairs(_G.muzzles[t]) do if current_id == id then return true end end
        return false
    end
    if is_in("id_flash_hider") then
        local auto = _G.AutoDetectAttach(avatarid, current_id)
        current_id = _G.GetAttachForSkin(avatarid, "FlashHider") or (p and p["Flash Hider"]) or (auto > 0 and auto) or current_id
    elseif is_in("id_compensator") then
        local auto = _G.AutoDetectAttach(avatarid, current_id)
        current_id = _G.GetAttachForSkin(avatarid, "Compensator") or (p and p["Compensator"]) or (auto > 0 and auto) or current_id
    elseif is_in("id_suppressor") then
        local auto = _G.AutoDetectAttach(avatarid, current_id)
        current_id = _G.GetAttachForSkin(avatarid, "Suppressor") or (p and p["Suppressor"]) or (auto > 0 and auto) or current_id
    end
    return current_id, (initial_id ~= current_id)
end

_G.get_forgripid = function(current_id, avatarid)
    local initial_id = current_id
    _G.InitParts(_G.get_group_id(avatarid), avatarid)
    local p = _G.g_parts[avatarid]
    local auto = _G.AutoDetectAttach(avatarid, current_id)
    if current_id == _G.foregrips.id_Angledforegrip then
        current_id = _G.GetAttachForSkin(avatarid, "AngledGrip") or (p and p["Angled Foregrip"]) or (auto > 0 and auto) or current_id
    elseif current_id == _G.foregrips.id_thumb_grip then
        current_id = _G.GetAttachForSkin(avatarid, "ThumbGrip") or (p and p["Thumb Grip"]) or (auto > 0 and auto) or current_id
    elseif current_id == _G.foregrips.id_vertical_grip then
        current_id = _G.GetAttachForSkin(avatarid, "VerticalGrip") or (p and p["Vertical Foregrip"]) or (auto > 0 and auto) or current_id
    elseif current_id == _G.foregrips.id_light_grip then
        current_id = _G.GetAttachForSkin(avatarid, "LightGrip") or (p and p["Light Grip"]) or (auto > 0 and auto) or current_id
    elseif current_id == _G.foregrips.id_half_grip then
        current_id = _G.GetAttachForSkin(avatarid, "HalfGrip") or (p and p["Half Grip"]) or (auto > 0 and auto) or current_id
    elseif current_id == _G.foregrips.id_ergonomic_grip then
        current_id = (p and p["Ergonomic Grip"]) or (auto > 0 and auto) or current_id
    elseif current_id == _G.foregrips.id_laser_sight then
        current_id = _G.GetAttachForSkin(avatarid, "LaserSight") or (p and p["Laser Sight"]) or (auto > 0 and auto) or current_id
    end
    return current_id, (initial_id ~= current_id)
end

_G.get_magazinesid = function(current_id, avatarid)
    local initial_id = current_id
    _G.InitParts(_G.get_group_id(avatarid), avatarid)
    local p = _G.g_parts[avatarid]
    local function is_in(t)
        for _, id in ipairs(_G.magazines[t]) do if current_id == id then return true end end
        return false
    end
    if is_in("id_expanded_mag") then
        local auto = _G.AutoDetectAttach(avatarid, current_id)
        current_id = _G.GetAttachForSkin(avatarid, "ExtMag") or (p and p["Extended Mag"]) or _G.GetSlotFromSkinID(avatarid, 1) or (auto > 0 and auto) or current_id
    elseif is_in("id_quick_mag") then
        local auto = _G.AutoDetectAttach(avatarid, current_id)
        current_id = _G.GetAttachForSkin(avatarid, "QuickMag") or (p and p["Quickdraw Mag"]) or _G.GetSlotFromSkinID(avatarid, 1) or (auto > 0 and auto) or current_id
    elseif is_in("id_expanded_quick_mag") then
        local auto = _G.AutoDetectAttach(avatarid, current_id)
        current_id = _G.GetAttachForSkin(avatarid, "ExtQuickMag") or (p and p["Extended Quickdraw Mag"]) or _G.GetSlotFromSkinID(avatarid, 1) or (auto > 0 and auto) or current_id
    else
        local fb = _G.GetSlotFromSkinID(avatarid, 1)
        if fb and fb > 0 then current_id = fb end
    end
    return current_id, (initial_id ~= current_id)
end

_G.get_scopeid = function(current_id, avatarid)
    local initial_id = current_id
    _G.InitParts(_G.get_group_id(avatarid), avatarid)
    local p = _G.g_parts[avatarid]
    local auto = _G.AutoDetectAttach(avatarid, current_id)
    if current_id == _G.scopes.id_reddot then
        current_id = _G.GetAttachForSkin(avatarid, "RedDot") or (p and p["Red Dot Sight"]) or _G.GetSlotFromSkinID(avatarid, 3) or (auto > 0 and auto) or current_id
    elseif current_id == _G.scopes.id_holo then
        current_id = _G.GetAttachForSkin(avatarid, "Holo") or (p and p["Holographic Sight"]) or _G.GetSlotFromSkinID(avatarid, 3) or (auto > 0 and auto) or current_id
    elseif current_id == _G.scopes.id_2x then
        current_id = _G.GetAttachForSkin(avatarid, "Scope2x") or (p and p["2x Scope"]) or _G.GetSlotFromSkinID(avatarid, 3) or (auto > 0 and auto) or current_id
    elseif current_id == _G.scopes.id_3x then
        current_id = _G.GetAttachForSkin(avatarid, "Scope3x") or (p and p["3x Scope"]) or _G.GetSlotFromSkinID(avatarid, 3) or (auto > 0 and auto) or current_id
    elseif current_id == _G.scopes.id_4x then
        current_id = _G.GetAttachForSkin(avatarid, "Scope4x") or (p and p["4x Scope"]) or _G.GetSlotFromSkinID(avatarid, 3) or (auto > 0 and auto) or current_id
    elseif current_id == _G.scopes.id_6x then
        current_id = _G.GetAttachForSkin(avatarid, "Scope6x") or (p and p["6x Scope"]) or _G.GetSlotFromSkinID(avatarid, 3) or (auto > 0 and auto) or current_id
    elseif current_id == _G.scopes.id_8x then
        current_id = _G.GetAttachForSkin(avatarid, "Scope8x") or (p and p["8x Scope"]) or _G.GetSlotFromSkinID(avatarid, 3) or (auto > 0 and auto) or current_id
    else
        local fb = _G.GetSlotFromSkinID(avatarid, 3)
        if fb and fb > 0 then current_id = fb end
    end
    return current_id, (initial_id ~= current_id)
end

_G.get_stockid = function(current_id, avatarid)
    local initial_id = current_id
    _G.InitParts(_G.get_group_id(avatarid), avatarid)
    local p = _G.g_parts[avatarid]
    local auto = _G.AutoDetectAttach(avatarid, current_id)
    if current_id == _G.stock.id_microStock then
        current_id = _G.GetAttachForSkin(avatarid, "MicroStock") or (p and p["Stock"]) or _G.GetSlotFromSkinID(avatarid, 2) or (auto > 0 and auto) or current_id
    elseif current_id == _G.stock.id_tactical then
        current_id = _G.GetAttachForSkin(avatarid, "TactStock") or (p and p["Tactical Stock"]) or _G.GetSlotFromSkinID(avatarid, 2) or (auto > 0 and auto) or current_id
    elseif current_id == _G.stock.id_bulletloop then
        current_id = (p and p["Bullet Loop"]) or _G.GetSlotFromSkinID(avatarid, 2) or (auto > 0 and auto) or current_id
    elseif current_id == _G.stock.id_CheekPad then
        current_id = _G.GetAttachForSkin(avatarid, "CheekPad") or (p and p["Cheek Pad"]) or _G.GetSlotFromSkinID(avatarid, 2) or (auto > 0 and auto) or current_id
    else
        local fb = _G.GetSlotFromSkinID(avatarid, 2)
        if fb and fb > 0 then current_id = fb end
    end
    return current_id, (initial_id ~= current_id)
end

_G.apply_attachment = function(CurWeapon, avatarid)
    local array = CurWeapon.synData
    for AttachIdx = 0, 4 do
        local Data = array:Get(AttachIdx)
        local itemid = slua.IndexReference(Data, "defineID").TypeSpecificID
        if itemid and itemid > 0 and itemid < 10000000 then
            local isrefresh = false
            if AttachIdx == 0 then
                Data.defineID.TypeSpecificID, isrefresh = _G.get_muzzleid(slua.IndexReference(Data, "defineID").TypeSpecificID, avatarid)
                array:Set(AttachIdx, Data)
            elseif AttachIdx == 1 then
                Data.defineID.TypeSpecificID, isrefresh = _G.get_forgripid(slua.IndexReference(Data, "defineID").TypeSpecificID, avatarid)
                array:Set(AttachIdx, Data)
            elseif AttachIdx == 2 then
                Data.defineID.TypeSpecificID, isrefresh = _G.get_magazinesid(slua.IndexReference(Data, "defineID").TypeSpecificID, avatarid)
                array:Set(AttachIdx, Data)
            elseif AttachIdx == 3 then
                Data.defineID.TypeSpecificID, isrefresh = _G.get_stockid(slua.IndexReference(Data, "defineID").TypeSpecificID, avatarid)
                array:Set(AttachIdx, Data)
            elseif AttachIdx == 4 then
                Data.defineID.TypeSpecificID, isrefresh = _G.get_scopeid(slua.IndexReference(Data, "defineID").TypeSpecificID, avatarid)
                array:Set(AttachIdx, Data)
            else
                break
            end
            if isrefresh then
                _G.download_item(slua.IndexReference(Data, "defineID").TypeSpecificID)
                CurWeapon:DelayHandleAvatarMeshChanged()
            end
        end
    end
end

_G.WeaponSkinMap = _G.WeaponSkinMap or {}
_G.VehicleSkinMap = _G.VehicleSkinMap or {}
_G.OutfitMap = _G.OutfitMap or {}
_G.skinIdCache = _G.skinIdCache or {}
_G.skinIdCache2 = _G.skinIdCache2 or {}

_G.OutfitSkins = {
    Suit = {1406469,1405870,1407811,1407103,1408045,1408038,1407219,1407990,1405628,1407920,1407916,1407895,1405760,1407870,1407856,1407812,1407758,1407789,1407682,1407696,1407695,1407632,1407631,1407667,1407618,1407573,1407572,1407559,1407558,1407550,1407523,1407718,1407512,1407471,1407470,1406985,1407353,1407366,1407330,1407487,1410668,1407276,1407275,1407142,1407141,1407140,1406971,1406897,1406891,1407187,1405802,1405192,1405334,1400687,1405340,1405623,1405132,1405436,1405435,1405434,1405433,1405208,1407916,1407917,1407918,1407921,1407921,1407926,1407901,1407902,1407903,1407904,1407822,1407823,1407824,1407825,1407807,1407808,1407845,1407846,1407847,1407848,1407794,1411037,1407795,1411038,1407796,1411039},
    Pants = {1404002,1404050,1404425,1404495,1400650,1404522,1404441,1404152,1404196,1404134,1404137,1404164,1404191,1404466,1400052,404035,1404181,404084,1404516},
    Hair = {1501000699,40605010,40605011,40605012,1410480,1410085,1410299,1402834,441400152,1400150,1402582,1410289,1402218,1402223,1402283,1400426},
    Bag = {
        {501001, 501002, 501003}, {1501001174, 1501002174, 1501003174}, {1501001220, 1501002220, 1501003220},
        {1501001051, 1501002051, 1501003051}, {1501001443, 1501002443, 1501003443}, {1501001265, 1501002265, 1501003265},
        {1501001321, 1501002321, 1501003321}, {1501001277, 1501002277, 1501003277}, {1501001550, 1501002550, 1501003550},
        {1501001592, 1501002592, 1501003592}, {1501001608, 1501002608, 1501003608}, {1501001024, 1501002024, 1501003024},
        {1501001019, 1501002019, 1501003019}, {1501001179, 1501002179, 1501003179}, {1501001194, 1501002194, 1501003194},
        {1501001346, 1501002346, 1501003346}
    },
    Helmet = {
        {502001, 502002, 502003}, {1502001014, 1502002014, 1502003014}, {1502001349, 1502002349, 1502003349},
        {1502001012, 1502002012, 1502003012}, {1502001009, 1502002009, 1502003009}, {1502001397, 1502002397, 1502003397},
        {1502001390, 1502002390, 1502003390}, {1502001381, 1502002381, 1502003381}, {1502001358, 1502002358, 1502003358},
        {1502001350, 1502002350, 1502003350}, {1502001342, 1502002342, 1502003342}
    },
    Pet = {50000,50001,50002,50003,50004,50005,50006,50021,50022,50038,50039,50040}
}

_G.skinIdMappings = {
    [101004]={101004, 1101004246,1101004226,1101004236,1101004062,1101004078,1101004086,1101004201,1101004218},
    [101001]={101001,1101001276,1101001089,1101001213,1101001172,1101001127,1101001230,1101001241},                    
    [101003]={101003,1101003227,1103003208,1101003195,1101003187,1101003098,1101003166,1101003218},                    
    [102002]={102002,1102002136,1102002043,1102002061,1102002424},                                          
    [101008]={101008,1101008146,1101008154,1101008079,1101008126,1101008104,1101008146,1101008061,1101008116},                    
    [101006]={101006,1101006085,1101006061,1101006074,1101006043,1101006032,1101006084},
    [102001]={102001, 1102001120}, -- UZI Băng Giá
    [101005]={101005, 1101005098}, -- Groza Godzilla Bốc Lửa
    [104003]={104003, 1104003037}, -- S12K Nguyên Tử
    [104004]={104004, 1104004035, 1104004041}, -- DBS Quái Thú & Sandsinger
    [101101]={101101, 1101101007}, --asm
    [101007]={101007, 1101007071,1101007062,1101007046,1101007078,1101007072},  -- QBZ
    [101012]={101012, 1101012033},  -- Honey Badger
    [101002]={101002, 1101002081,1101002056,1101002029,1101002149},  -- M16A4
    [101102]={101102, 1101102049,1101102056,1101102025,1101102017,1101102007,1101102032},  -- ACE32
    
    [103001]={103001, 1103001202,1103001191,1103001179,1103001146,1103001101,1103001079,1103001202},  -- Kar98k
    [103002]={103002, 1103002113,1103002098,1103002087,1103002060,1103002059,1103002030},  -- M24
    [103003]={103003, 1103003087,1103003079,1103003069,1103003062,1103003055,1103003051,1103003042,1103003030,1103003022,1103003092},  -- AWM
    
}

_G.VehicleSkins = { 
    [1961001] = { 1961151,1961152,1961153,1961147,1961148,1961149,1961144,1961145,1961137,1961138,1961139,1961066,1961067,1961065,1961062,1961063,1961064,1961054,1961055,1961056,1961057,1961051,1961052,1961053,1961048,1961049,1961050,1961044,1961045,1961046,1961047,1961041,1961042,1961043,1961038,1961039,1961040,1961033,1961034,1961035,1961029,1961030,1961031,1961032,1961007,1961010,1961012,1961013,1961014,1961015,1961140,1961141,1961142,1961143,1991023,1991024 }, --cople rb
    [1903001] = { 1903228,1903220,1903221,1903223,1903218,1903219,1903213,1903212,1903202,1908094,1908095,1903193,1903192,1903191,19030790,19030791,19030800,19030801,1903074,1903075,1903076,1903071,1903072,1903073,1903216,1903217,1991001,1991002,1991003,1991004,1903088,1903089,1903090,1903023 }, --dacia
    [1915004] = { 1915021, 1915022, 1915008, 1915009, 1914011 }, -- Mirado open top        
    [1908001] = { 1908108,1908109,19080951,19081080,1908084,1908085,1908075,1908077,1908078,1908070,1908069,1908066,1908086,1908088,1908089,1908018 },  --uaz 
    [1907002] = { 1907058, 1907054, 1907059, 1907053, 1907063, 1907072, 1907040, 1907041, 1907027, 1907047, 1907021} -- Buggy 
}
_G.CustSlotType = { ClothesEquipemtSlot=5, BackpackEquipemtSlot=8, HelmetEquipemtSlot=9, ParachuteEquipemtSlot=11, GlideEquipemtSlot=15 }

-- ====================================================================
-- SKIN SYSTEM: LOGIC FUNCTIONS
-- ====================================================================
local function DownloadGameItem(id)
    local puffer_manager = require('client.slua.logic.download.puffer.puffer_manager')
    local puffer_const = require('client.slua.logic.download.puffer_const')
    if not puffer_manager or not puffer_const then return end
    local state = puffer_manager.GetState(puffer_const.ENUM_DownloadType.ODPTD, {id})
    if state ~= puffer_const.ENUM_DownloadState.Done and state ~= puffer_const.ENUM_DownloadState.Downloading then
        puffer_manager.Download(puffer_const.ENUM_DownloadType.ODPTD, {id})
    end
end

_G.get_skin_id = function(weaponID)
    if not weaponID then return nil end
    local targetSkinId = _G.WeaponSkinMap and _G.WeaponSkinMap[weaponID]
    if targetSkinId and targetSkinId > 0 then
        if not _G.skinIdCache2[targetSkinId] then
            if _G.download_item then pcall(_G.download_item, targetSkinId) end
            _G.skinIdCache2[targetSkinId] = true
        end
        return targetSkinId
    end
    return weaponID
end

_G.equip_character_avatar = function(Character)
    if not Character or not slua.isValid(Character) or not Character.AvatarComponent2 then return end
    local BackpackUtils = import("BackpackUtils")
    local SlotSyncData = Character.AvatarComponent2.NetAvatarData and Character.AvatarComponent2.NetAvatarData.SlotSyncData
    if not SlotSyncData or not slua.isValid(SlotSyncData) or not BackpackUtils then return end
    
    local function EquipAvatar(ApplyDataIdx, mappedSkin, ApplyEquipSlot, isLevelDependent, levelFunc)
        if not mappedSkin or mappedSkin == 0 then return end
        local slotData = SlotSyncData:Get(ApplyDataIdx)
        if slotData and slotData.SlotID == ApplyEquipSlot then
            local applyItemId = mappedSkin
            if isLevelDependent and type(mappedSkin) == "table" then
                local level = levelFunc(slotData.AdditionalItemID) or 1
                if level < 1 then level = 1 end
                if level > 3 then level = 3 end
                applyItemId = mappedSkin[level] or mappedSkin[1]
            end

            if not applyItemId or applyItemId == 0 or slotData.ItemId == applyItemId then return end

            if not _G.skinIdCache[applyItemId] then
                if _G.download_item then pcall(_G.download_item, applyItemId) end
                _G.skinIdCache[applyItemId] = true
            end

            slotData.ItemId = applyItemId
            SlotSyncData:Set(ApplyDataIdx, slotData)
            Character.AvatarComponent2:OnRep_BodySlotStateChanged()
        end
    end

    local hasGliderSlot = false
    for i = 0, SlotSyncData:Num() - 1 do
        local slotData = SlotSyncData:Get(i)
        if slotData and slotData.SlotID == _G.CustSlotType.GlideEquipemtSlot then 
            hasGliderSlot = true
            break 
        end
    end
    if not hasGliderSlot then SlotSyncData:Add({ SlotID = _G.CustSlotType.GlideEquipemtSlot, ItemId = 0 }) end

    for i = 0, SlotSyncData:Num() - 1 do
        EquipAvatar(i, _G.OutfitMap.Suit or 0, _G.CustSlotType.ClothesEquipemtSlot, false)
        EquipAvatar(i, _G.OutfitMap.Pants or 0, 6, false)
        EquipAvatar(i, _G.OutfitMap.Hair or 0, 7, false)
        EquipAvatar(i, _G.OutfitMap.Bag, _G.CustSlotType.BackpackEquipemtSlot, true, BackpackUtils.GetEquipmentBagLevel)
        EquipAvatar(i, _G.OutfitMap.Helmet, _G.CustSlotType.HelmetEquipemtSlot, true, BackpackUtils.GetEquipmentHelmetLevel)
        EquipAvatar(i, _G.OutfitMap.Parachute or 0, _G.CustSlotType.ParachuteEquipemtSlot, false)
    end
end

_G.ApplyWeaponSkins = function(PlayerCharacter)
    pcall(function()
        local WeaponManager = PlayerCharacter:GetWeaponManager()
        if not slua.isValid(WeaponManager) then return end
        
        for slot = 1, 3 do
            local Weapon = WeaponManager:GetInventoryWeaponByPropSlot(slot)
            if slua.isValid(Weapon) and slua.isValid(Weapon.synData) then
                local WeaponID = Weapon:GetWeaponID()
                local SkinID = _G.get_skin_id(WeaponID) or WeaponID
                local isModified = false
                
                local SkinData = Weapon.synData:Get(7) 
                if SkinData and SkinData.defineID and SkinData.defineID.TypeSpecificID ~= SkinID then
                    SkinData.defineID.TypeSpecificID = SkinID
                    Weapon.synData:Set(7, SkinData)
                    if Weapon.SetWeaponAvatarID then pcall(function() Weapon:SetWeaponAvatarID(SkinID) end) end
                    if not _G.skinIdCache[SkinID] then 
                        _G.download_item(SkinID)
                        _G.skinIdCache[SkinID] = true 
                    end
                    isModified = true
                end
                
                if SkinID >= 10000000 and _G.VIP_Attachments and _G.VIP_Attachments[SkinID] then
                    for AttachIdx = 0, 5 do 
                        local attachData = Weapon.synData:Get(AttachIdx)
                        if attachData then
                            local defineIDRef = slua.IndexReference(attachData, "defineID")
                            if defineIDRef then
                                local attachmentId = defineIDRef.TypeSpecificID
                                if attachmentId and attachmentId > 0 then
                                    local mapIndex = _G.BaseAttachToIndex[attachmentId] or _G.VipAttachToIndex[attachmentId]
                                    if mapIndex and _G.VIP_Attachments[SkinID][mapIndex] and _G.VIP_Attachments[SkinID][mapIndex] > 0 then
                                        local targetAttachId = _G.VIP_Attachments[SkinID][mapIndex]
                                        if targetAttachId ~= attachmentId then
                                            attachData.defineID.TypeSpecificID = targetAttachId
                                            Weapon.synData:Set(AttachIdx, attachData)
                                            if not _G.skinIdCache2[targetAttachId] then 
                                                if _G.download_item then pcall(_G.download_item, targetAttachId) end
                                                _G.skinIdCache2[targetAttachId] = true 
                                            end
                                            isModified = true
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
                
                if _G.apply_attachment and SkinID >= 10000000 then
                    pcall(function() _G.apply_attachment(Weapon, SkinID) end)
                end
                
                if isModified then
                    if Weapon.DelayHandleAvatarMeshChanged then pcall(function() Weapon:DelayHandleAvatarMeshChanged() end) end
                    if Weapon.OnRep_synData then pcall(function() Weapon:OnRep_synData() end) end
                end
            end
        end
    end)
end

-- ====== NO RECOIL SYSTEM ======
_G.recoilOriginalCache = _G.recoilOriginalCache or setmetatable({}, { __mode = "k" })
_G.RECOIL_FIELDS = { "RecoilKick", "RecoilKickADS", "AnimationKick", "GameDeviationFactor", "RecoilModifierStand", "RecoilModifierCrouch", "RecoilModifierProne", "CameraShakeScale", "AimCameraShakeScale", "ShootCameraShakeScale", "FireCameraShakeScale", "GameDeviationAccuracy", "ShotGunHorizontalSpread", "ShotGunVerticalSpread", "DeviationMultiplier" }
_G.RECOIL_TARGET_VALUES = { RecoilKick=0.01, RecoilKickADS=0.01, AnimationKick=0.01, GameDeviationFactor=0.01, RecoilModifierStand=0.01, RecoilModifierCrouch=0.01, RecoilModifierProne=0.01, CameraShakeScale=0.01, AimCameraShakeScale=0.01, ShootCameraShakeScale=0.01, FireCameraShakeScale=0.01, GameDeviationAccuracy=0.01, ShotGunHorizontalSpread=0.01, ShotGunVerticalSpread=0.01, DeviationMultiplier=0.01 }
_G.RECOIL_INFO_FIELDS = { "VerticalRecoilMin", "VerticalRecoilMax", "RecoilSpeedVertical", "RecoilSpeedHorizontal", "VerticalRecoveryMax" }
_G.RECOIL_INFO_TARGET = { VerticalRecoilMin=0.01, VerticalRecoilMax=0.01, RecoilSpeedVertical=0.01, RecoilSpeedHorizontal=0.01, VerticalRecoveryMax=0.01 }

_G.ApplyNoRecoil = function()
    pcall(function()
        local GameplayData = getCachedGameplayData()
        if not GameplayData or not GameplayData.GetPlayerController then return end
        local pc = GameplayData.GetPlayerController()
        if not Valid(pc) then return end
        local char = pc:GetPlayerCharacterSafety()
        if not Valid(char) then return end
        local wm = char.WeaponManagerComponent
        if not wm then return end
        local weapon = wm.CurrentWeaponReplicated
        if not weapon then return end
        local entity = weapon.ShootWeaponEntityComp
        if not Valid(entity) then return end
        if not _G.LexusConfig.NoRecoilEnabled then
            if _G.recoilOriginalCache[entity] then
                local saved = _G.recoilOriginalCache[entity]
                for k, v in pairs(saved) do
                    if k == "RecoilInfo" then
                        if entity.RecoilInfo then for rk, rv in pairs(v) do entity.RecoilInfo[rk] = rv end end
                    elseif k == "ShootCameraShakeScale" then
                        if entity.ShootCameraShake then entity.ShootCameraShake.Scale = v end
                    else entity[k] = v end
                end
                _G.recoilOriginalCache[entity] = nil
            end
            return
        end
        if not _G.recoilOriginalCache[entity] then
            local saved = { RecoilInfo = {} }
            for _, f in ipairs(_G.RECOIL_FIELDS) do if entity[f] ~= nil then saved[f] = entity[f] end end
            if entity.RecoilInfo then for _, f in ipairs(_G.RECOIL_INFO_FIELDS) do if entity.RecoilInfo[f] ~= nil then saved.RecoilInfo[f] = entity.RecoilInfo[f] end end end
            if entity.ShootCameraShake then saved.ShootCameraShakeScale = entity.ShootCameraShake.Scale end
            _G.recoilOriginalCache[entity] = saved
        end
        local orig = _G.recoilOriginalCache[entity]
        local slider = (_G.LexusConfig.RecoilReduction or 100) / 100
        if slider > 1 then slider = 1 end
        for _, f in ipairs(_G.RECOIL_FIELDS) do
            if entity[f] ~= nil and orig[f] ~= nil and _G.RECOIL_TARGET_VALUES[f] then
                entity[f] = orig[f] + (_G.RECOIL_TARGET_VALUES[f] - orig[f]) * slider
            end
        end
        if entity.RecoilInfo then
            for _, f in ipairs(_G.RECOIL_INFO_FIELDS) do
                if entity.RecoilInfo[f] ~= nil and orig.RecoilInfo[f] ~= nil and _G.RECOIL_INFO_TARGET[f] then
                    entity.RecoilInfo[f] = orig.RecoilInfo[f] + (_G.RECOIL_INFO_TARGET[f] - orig.RecoilInfo[f]) * slider
                end
            end
        end
        if entity.ShootCameraShake then
            local origScale = orig.ShootCameraShakeScale or 1.0
            entity.ShootCameraShake.Scale = origScale + (0.01 - origScale) * slider
        end
    end)
end

-- ====== AUTO HEAD / AIMBOT (Scope-Aware) ======
_G.ApplyAutoHead = function()
    pcall(function()
        local GameplayData = getCachedGameplayData()
        if not GameplayData or not GameplayData.GetPlayerController then return end
        local pc = GameplayData.GetPlayerController()
        if not Valid(pc) then return end
        local localChar = pc:GetPlayerCharacterSafety()
        if not Valid(localChar) then return end
        local localLoc = nil
        pcall(function() localLoc = localChar:K2_GetActorLocation() end)
        if not localLoc then return end
        local myTeamID = localChar.TeamID

        local isScoped = false
        pcall(function()
            local cam = localChar.ThirdPersonCameraComponent
            if Valid(cam) and cam.FieldOfView then
                isScoped = cam.FieldOfView < 60
            end
        end)

        local maxDist = isScoped and 500 or 250
        local closestEnemy = nil
        local closestDist = 999999
        local allChars = GameplayData.GetAllPlayerCharacters and GameplayData.GetAllPlayerCharacters() or {}
        for _, enemy in pairs(allChars) do
            if Valid(enemy) and enemy ~= localChar and enemy.TeamID ~= myTeamID then
                local bDead = false
                pcall(function()
                    if type(enemy.IsDead) == "function" then bDead = enemy:IsDead()
                    elseif enemy.bIsDead ~= nil then bDead = enemy.bIsDead end
                end)
                if not bDead then
                    local eLoc = nil
                    pcall(function() eLoc = enemy:K2_GetActorLocation() end)
                    if eLoc then
                        local dx = (eLoc.X or 0) - (localLoc.X or 0)
                        local dy = (eLoc.Y or 0) - (localLoc.Y or 0)
                        local dz = (eLoc.Z or 0) - (localLoc.Z or 0)
                        local dist = math.sqrt(dx*dx + dy*dy + dz*dz)
                        if dist < closestDist then
                            closestDist = dist
                            closestEnemy = enemy
                        end
                    end
                end
            end
        end
        if closestEnemy and closestDist <= maxDist then
            local targetLoc = nil
            pcall(function()
                local mesh = closestEnemy.Mesh
                if Valid(mesh) and type(mesh.GetSocketLocation) == "function" then
                    if isScoped then
                        targetLoc = mesh:GetSocketLocation("head")
                    else
                        targetLoc = mesh:GetSocketLocation("spine_02")
                        if not targetLoc then targetLoc = closestEnemy:K2_GetActorLocation() end
                        if targetLoc then targetLoc.Z = targetLoc.Z + 100 end
                    end
                end
            end)
            if not targetLoc then
                pcall(function() targetLoc = closestEnemy:K2_GetActorLocation() end)
                if targetLoc then targetLoc.Z = targetLoc.Z + (isScoped and 180 or 100) end
            end
            if targetLoc then
                local myCam = localChar.ThirdPersonCameraComponent
                if Valid(myCam) then
                    local camLoc = nil
                    pcall(function() camLoc = myCam:K2_GetComponentLocation() end)
                    if camLoc then
                        local dirX = (targetLoc.X or 0) - (camLoc.X or 0)
                        local dirY = (targetLoc.Y or 0) - (camLoc.Y or 0)
                        local dirZ = (targetLoc.Z or 0) - (camLoc.Z or 0)
                        local len = math.sqrt(dirX*dirX + dirY*dirY + dirZ*dirZ)
                        if len > 0 then
                            local rot = nil
                            pcall(function()
                                local FRotator = import("Rotator")
                                local pitch = math.deg(math.asin(dirZ / len))
                                local yaw = math.deg(math.atan2(dirY, dirX))
                                if isScoped then
                                    rot = FRotator and FRotator(-pitch, yaw, 0) or {Pitch = -pitch, Yaw = yaw, Roll = 0}
                                else
                                    local curRot = pc:GetControlRotation()
                                    if curRot then
                                        local curPitch = curRot.Pitch or 0
                                        local curYaw = curRot.Yaw or 0
                                        local blend = 0.35
                                        local newPitch = curPitch + (-pitch - curPitch) * blend
                                        local newYaw = curYaw + (yaw - curYaw) * blend
                                        rot = FRotator and FRotator(newPitch, newYaw, 0) or {Pitch = newPitch, Yaw = newYaw, Roll = 0}
                                    else
                                        rot = FRotator and FRotator(-pitch, yaw, 0) or {Pitch = -pitch, Yaw = yaw, Roll = 0}
                                    end
                                end
                            end)
                            if rot then
                                pcall(function() pc:SetControlRotation(rot) end)
                            end
                        end
                    end
                end
            end
        end
    end)
end

-- ====== WEAPON AIMBOT (AutoAimingConfig + Head Bones) ======
_G.ApplyWeaponAimbot = function()
    pcall(function()
        local GameplayData = getCachedGameplayData()
        if not GameplayData or not GameplayData.GetPlayerController then return end
        local pc = GameplayData.GetPlayerController()
        if not Valid(pc) then return end
        local char = pc:GetPlayerCharacterSafety()
        if not Valid(char) then return end
        local wm = char.WeaponManagerComponent
        if not slua.isValid(wm) then return end
        local weapon = wm.CurrentWeaponReplicated
        if not slua.isValid(weapon) then return end
        local entity = weapon.ShootWeaponEntityComp
        if slua.isValid(entity) and entity.AutoAimingConfig then
            for _, range in ipairs({"OuterRange", "InnerRange"}) do
                local cfg = entity.AutoAimingConfig[range]
                if cfg then
                    cfg.Speed = 90
                    cfg.RangeRate = 90
                    cfg.SpeedRate = 1
                    cfg.RangeRateSight = 1
                    cfg.SpeedRateSight = 2
                    cfg.CrouchRate = 5
                    cfg.ProneRate = 5
                    cfg.DyingRate = 0
                end
            end
            entity.AutoAimingConfig = entity.AutoAimingConfig
        end
        local aimComp = char.BP_AutoAimingComponent_C or char.BP_AutoAimingComponent
        if slua.isValid(aimComp) and aimComp.Bones then
            aimComp.Bones = {"head", "head", "head"}
        end
    end)
end

_G.RestoreWeaponAimbot = function()
    pcall(function()
        local GameplayData = getCachedGameplayData()
        if not GameplayData or not GameplayData.GetPlayerController then return end
        local pc = GameplayData.GetPlayerController()
        if not Valid(pc) then return end
        local char = pc:GetPlayerCharacterSafety()
        if not Valid(char) then return end
        local wm = char.WeaponManagerComponent
        if not slua.isValid(wm) then return end
        local weapon = wm.CurrentWeaponReplicated
        if not slua.isValid(weapon) then return end
        local entity = weapon.ShootWeaponEntityComp
        if slua.isValid(entity) and entity.AutoAimingConfig then
            for _, range in ipairs({"OuterRange", "InnerRange"}) do
                local cfg = entity.AutoAimingConfig[range]
                if cfg then
                    cfg.Speed = 10
                    cfg.RangeRate = 2
                    cfg.SpeedRate = 4
                    cfg.RangeRateSight = 2
                    cfg.SpeedRateSight = 4
                    cfg.CrouchRate = 2
                    cfg.ProneRate = 2
                    cfg.DyingRate = 2
                end
            end
            entity.AutoAimingConfig = entity.AutoAimingConfig
        end
    end)
end

_G.ApplyVehicleSkins = function(PlayerCharacter)
    pcall(function()
        local Vehicle = PlayerCharacter:GetCurrentVehicle()
        if not slua.isValid(Vehicle) then 
            _G.LastVehicleEntity = nil
            return 
        end
        
        if _G.LastVehicleEntity == Vehicle and _G.CurrentEquipVehicleID ~= nil then
            return
        end

        local VehicleAvatar = Vehicle.VehicleAvatar or Vehicle.VehicleAvatarComponent_BP or Vehicle:GetAvatarComponent()
        if not slua.isValid(VehicleAvatar) then return end

        local defId = tostring(VehicleAvatar:GetDefaultAvatarID() or Vehicle.VehicleID or "")
        local currentId = tostring(Vehicle:GetAvatarId() or "")
        local applySkinId = 0
        
        for baseMapId, targetSkin in pairs(_G.VehicleSkinMap) do
            if defId:find(tostring(baseMapId)) or currentId:find(tostring(baseMapId)) then 
                applySkinId = targetSkin
                break 
            end
        end

        if applySkinId and applySkinId > 0 then
            _G.skinIdCache = _G.skinIdCache or {}
            if not _G.skinIdCache[applySkinId] then 
                if _G.download_item then pcall(_G.download_item, applySkinId) end
                _G.skinIdCache[applySkinId] = true 
            end

            VehicleAvatar.curSwitchEffectId = 7303001
            if VehicleAvatar.ChangeItemAvatar then VehicleAvatar:ChangeItemAvatar(applySkinId, true) end
            
            _G.CurrentEquipVehicleID = applySkinId
            _G.LastVehicleEntity = Vehicle
        end
    end)
end

_G.HandlePetLogic = function()
    pcall(function()
        local petSkin = _G.OutfitMap.Pet
        if not petSkin or petSkin == 0 or petSkin == 50000 or petSkin == _G.LastAppliedPet then return end
        
        _G.skinIdCache = _G.skinIdCache or {}
        if not _G.skinIdCache[petSkin] then 
            if _G.download_item then pcall(_G.download_item, petSkin) end
            _G.skinIdCache[petSkin] = true 
        end
        
        local ModuleManager = require("client.module_framework.ModuleManager")
        if ModuleManager then
            local logic_pet = ModuleManager.GetModule(ModuleManager.CommonModuleConfig.logic_pet)
            if logic_pet then
                if logic_pet.SetCurPetID then logic_pet:SetCurPetID(petSkin) end
                if logic_pet.EquipPet then logic_pet:EquipPet(petSkin) end
            end
        end
        _G.LastAppliedPet = petSkin
    end)
end

_G.ForceRefreshSkinMaps = function()
    pcall(function()
        if not _G.LexusState or not _G.LexusState.CustomTextData then return end
        local cData = _G.LexusState.CustomTextData

        if _G.OutfitSkins then
            if cData.SkinSuit and _G.OutfitSkins.Suit[cData.SkinSuit] then _G.OutfitMap.Suit = _G.OutfitSkins.Suit[cData.SkinSuit] end
            if cData.SkinBag and _G.OutfitSkins.Bag[cData.SkinBag] then _G.OutfitMap.Bag = _G.OutfitSkins.Bag[cData.SkinBag] end
            if cData.SkinHelmet and _G.OutfitSkins.Helmet[cData.SkinHelmet] then _G.OutfitMap.Helmet = _G.OutfitSkins.Helmet[cData.SkinHelmet] end
        end

        if _G.skinIdMappings then
            if cData.SkinM416 and _G.skinIdMappings[101004] and _G.skinIdMappings[101004][cData.SkinM416] then _G.WeaponSkinMap[101004] = _G.skinIdMappings[101004][cData.SkinM416] end
            if cData.SkinAKM and _G.skinIdMappings[101001] and _G.skinIdMappings[101001][cData.SkinAKM] then _G.WeaponSkinMap[101001] = _G.skinIdMappings[101001][cData.SkinAKM] end
            if cData.SkinSCAR and _G.skinIdMappings[101003] and _G.skinIdMappings[101003][cData.SkinSCAR] then _G.WeaponSkinMap[101003] = _G.skinIdMappings[101003][cData.SkinSCAR] end
            if cData.SkinM762 and _G.skinIdMappings[101008] and _G.skinIdMappings[101008][cData.SkinM762] then _G.WeaponSkinMap[101008] = _G.skinIdMappings[101008][cData.SkinM762] end
            if cData.SkinAUG and _G.skinIdMappings[101006] and _G.skinIdMappings[101006][cData.SkinAUG] then _G.WeaponSkinMap[101006] = _G.skinIdMappings[101006][cData.SkinAUG] end
            if cData.SkinUMP and _G.skinIdMappings[102002] and _G.skinIdMappings[102002][cData.SkinUMP] then _G.WeaponSkinMap[102002] = _G.skinIdMappings[102002][cData.SkinUMP] end
            
            if cData.SkinUZI and _G.skinIdMappings[102001] and _G.skinIdMappings[102001][cData.SkinUZI] then _G.WeaponSkinMap[102001] = _G.skinIdMappings[102001][cData.SkinUZI] end
            if cData.SkinGroza and _G.skinIdMappings[101005] and _G.skinIdMappings[101005][cData.SkinGroza] then _G.WeaponSkinMap[101005] = _G.skinIdMappings[101005][cData.SkinGroza] end
            if cData.SkinS12K and _G.skinIdMappings[104003] and _G.skinIdMappings[104003][cData.SkinS12K] then _G.WeaponSkinMap[104003] = _G.skinIdMappings[104003][cData.SkinS12K] end
            if cData.SkinDBS and _G.skinIdMappings[104004] and _G.skinIdMappings[104004][cData.SkinDBS] then _G.WeaponSkinMap[104004] = _G.skinIdMappings[104004][cData.SkinDBS] end
            if cData.SkinASM and _G.skinIdMappings[101101] and _G.skinIdMappings[101101][cData.SkinASM] then _G.WeaponSkinMap[101101] = _G.skinIdMappings[101101][cData.SkinASM] end
        end

        if _G.VehicleSkins then
            if cData.SkinDacia and _G.VehicleSkins[1903001] and _G.VehicleSkins[1903001][cData.SkinDacia] then _G.VehicleSkinMap[1903001] = _G.VehicleSkins[1903001][cData.SkinDacia] end
            if cData.SkinUAZ and _G.VehicleSkins[1908001] and _G.VehicleSkins[1908001][cData.SkinUAZ] then _G.VehicleSkinMap[1908001] = _G.VehicleSkins[1908001][cData.SkinUAZ] end
            if cData.SkinCoupe and _G.VehicleSkins[1961001] and _G.VehicleSkins[1961001][cData.SkinCoupe] then _G.VehicleSkinMap[1961001] = _G.VehicleSkins[1961001][cData.SkinCoupe] end
            if cData.SkinBuggy and _G.VehicleSkins[1907002] and _G.VehicleSkins[1907002][cData.SkinBuggy] then _G.VehicleSkinMap[1907002] = _G.VehicleSkins[1907002][cData.SkinBuggy] end
            if cData.SkinMirado and _G.VehicleSkins[1915004] and _G.VehicleSkins[1915004][cData.SkinMirado] then _G.VehicleSkinMap[1915004] = _G.VehicleSkins[1915004][cData.SkinMirado] end
            if cData.SkinQBZ and _G.skinIdMappings[101007] and _G.skinIdMappings[101007][cData.SkinQBZ] then _G.WeaponSkinMap[101007] = _G.skinIdMappings[101007][cData.SkinQBZ] end
if cData.SkinHoney and _G.skinIdMappings[101012] and _G.skinIdMappings[101012][cData.SkinHoney] then _G.WeaponSkinMap[101012] = _G.skinIdMappings[101012][cData.SkinHoney] end
if cData.SkinM16A4 and _G.skinIdMappings[101002] and _G.skinIdMappings[101002][cData.SkinM16A4] then _G.WeaponSkinMap[101002] = _G.skinIdMappings[101002][cData.SkinM16A4] end
if cData.SkinACE32 and _G.skinIdMappings[101102] and _G.skinIdMappings[101102][cData.SkinACE32] then _G.WeaponSkinMap[101102] = _G.skinIdMappings[101102][cData.SkinACE32] end
if cData.SkinKar98k and _G.skinIdMappings[103001] and _G.skinIdMappings[103001][cData.SkinKar98k] then _G.WeaponSkinMap[103001] = _G.skinIdMappings[103001][cData.SkinKar98k] end
if cData.SkinM24 and _G.skinIdMappings[103002] and _G.skinIdMappings[103002][cData.SkinM24] then _G.WeaponSkinMap[103002] = _G.skinIdMappings[103002][cData.SkinM24] end
if cData.SkinAWM and _G.skinIdMappings[103003] and _G.skinIdMappings[103003][cData.SkinAWM] then _G.WeaponSkinMap[103003] = _G.skinIdMappings[103003][cData.SkinAWM] end
        end
    end)
end

local cached_GameplayStatics = nil
local cached_PlayerTombBox = nil
local cached_ActorClass = nil
_G.NeedCheckDeadBoxTimer = 100

_G.DeadBox_TemperRequest = function(PlayerController)
    if not _G.LexusConfig.SkinDeadBox then return end
    if _G.NeedCheckDeadBoxTimer <= 0 then return end
    
    local curTime = os.clock()
    if _G.LastCheckDeadBoxTime and (curTime - _G.LastCheckDeadBoxTime) < 2.0 then return end
    _G.LastCheckDeadBoxTime = curTime
    
    _G.NeedCheckDeadBoxTimer = _G.NeedCheckDeadBoxTimer - 1

    local PlayerCharacter = PlayerController:GetPlayerCharacterSafety()
    if not slua.isValid(PlayerCharacter) then return end
    
    if not cached_GameplayStatics then
        cached_GameplayStatics = import("GameplayStatics")
        cached_ActorClass = import("Actor")
        cached_PlayerTombBox = import("PlayerTombBox")
    end
    
    if not _G.CachedActorArray then
        _G.CachedActorArray = slua.Array(UEnums.EPropertyClass.Object, cached_ActorClass)
    end
    
    local UI_Util = require("client.common.ui_util")
    local GameInstance = UI_Util and UI_Util.GetGameInstance()
    if not GameInstance or not cached_GameplayStatics then return end

    local deadBoxes = cached_GameplayStatics.GetAllActorsOfClass(GameInstance, cached_PlayerTombBox, _G.CachedActorArray)
    
    for _, deadBoxActor in pairs(deadBoxes) do
        if slua.isValid(deadBoxActor) and not deadBoxActor.bIsTDSkinApplied then
            local damageCauser = deadBoxActor.DamageCauser
            if damageCauser and damageCauser.PlayerKey == PlayerController.PlayerKey then
                local DeadBoxAvatarComponent = deadBoxActor.DeadBoxAvatarComponent_BP
                if slua.isValid(DeadBoxAvatarComponent) then
                    local currentBoxSkinId = 0
                    if PlayerCharacter.CurrentVehicle and _G.CurrentEquipVehicleID and _G.CurrentEquipVehicleID ~= 0 then
                        currentBoxSkinId = tonumber(tostring(_G.CurrentEquipVehicleID) .. "1") or 0
                    else
                        local currentWeapon = PlayerCharacter:GetCurrentWeapon()
                        if slua.isValid(currentWeapon) and currentWeapon.synData then
                            local weaponSkinData = currentWeapon.synData:Get(7)
                            if weaponSkinData and weaponSkinData.defineID then
                                currentBoxSkinId = weaponSkinData.defineID.TypeSpecificID
                            end
                        end
                    end
                    
                    if currentBoxSkinId ~= 0 then
                        pcall(function()
                            DeadBoxAvatarComponent:ResetItemAvatar()
                            DeadBoxAvatarComponent:PreChangeItemAvatar(currentBoxSkinId)
                            DeadBoxAvatarComponent:SyncChangeItemAvatar(currentBoxSkinId)
                        end)
                    end
                    deadBoxActor.bIsTDSkinApplied = true
                end
            end
        end
    end
end

_G.TDFTDeKillCounts = _G.TDFTDeKillCounts or {}
local CACHED_LinearColor = import("LinearColor")
local CACHED_GoldColor = CACHED_LinearColor and CACHED_LinearColor(1.0, 0.8, 0.0, 1.0) or nil
local CACHED_UI_Manager = nil

_G.ForceEnableKillCounterUI = function()
    pcall(function()
        local KillCounterUISubsystem = package.loaded["GameLua.Mod.BaseMod.Client.KillCounter.KillCounterUISubsystem"] or require("GameLua.Mod.BaseMod.Client.KillCounter.KillCounterUISubsystem")
        if KillCounterUISubsystem and KillCounterUISubsystem.__inner_impl and not _G.KCUISystemHacked2 then
            local kcImpl = KillCounterUISubsystem.__inner_impl
            kcImpl.CheckSupportKCUI = function() return true end
            kcImpl.CheckNeedMainKillCounterUI = function(self, PlayerWeapon, PlayerID)
                if slua.isValid(PlayerWeapon) then
                    local WeaponID = PlayerWeapon:GetWeaponID()
                    self:UpdateMainKillCounterUI(true, WeaponID, _G.get_skin_id(WeaponID) or WeaponID)
                else self:UpdateMainKillCounterUI(false) end
            end
            local originalUpdateMainKillCounterUI = kcImpl.UpdateMainKillCounterUI
            kcImpl.UpdateMainKillCounterUI = function(self, bShow, WeaponID, AvatarID)
                if bShow then AvatarID = _G.get_skin_id(WeaponID) or AvatarID end
                if originalUpdateMainKillCounterUI then originalUpdateMainKillCounterUI(self, bShow, WeaponID, AvatarID) end
            end
            _G.KCUISystemHacked2 = true
        end

        local ModuleManager = require("client.module_framework.ModuleManager")
        if ModuleManager and not _G.KCLogicHacked2 then
            local LogicKillCounter = ModuleManager.GetModule(ModuleManager.CommonModuleConfig.LogicKillCounter)
            if LogicKillCounter then
                LogicKillCounter.CheckSupportKC = function() return true end
                LogicKillCounter.CheckSupportKillCounterAvatar = function() return true end
                LogicKillCounter.CheckHasWeaponKillCounter = function() return true end
                LogicKillCounter.GetBaseKillCounterIdByWeaponId = function() return 2100004 end
                LogicKillCounter.GetEquipedKillCounterId = function() return 2100004 end
                LogicKillCounter.GetMyEquipedKillCounterId = function() return 2100004 end
                LogicKillCounter.GetOneWeaponKillCountInBattle = function(self, uid, weaponId) return _G.TDFTDeKillCounts[weaponId] or 0 end
                LogicKillCounter.GetWeaponKillCountByUid = function(self, uid, weaponId) return _G.TDFTDeKillCounts[weaponId] or 0 end
                _G.KCLogicHacked2 = true
            end
        end

        local killInfoPath = "GameLua.Mod.BaseMod.Client.KillInfoTips.KillInfo"
        local KillInfo = package.loaded[killInfoPath] or require(killInfoPath)
        
        if KillInfo and KillInfo.__inner_impl and not _G.KillInfoCounterHacked then
            local originalFileItem = KillInfo.__inner_impl.FileItem
            KillInfo.__inner_impl.FileItem = function(self, DamageRecordData)
                pcall(function()
                    local LocalPlayer = require("GameLua.GameCore.Data.GameplayData").GetPlayerCharacter()
                    if slua.isValid(LocalPlayer) and DamageRecordData.Causer == LocalPlayer:GetPlayerNameSafety() then 
                        local currentWeapon = LocalPlayer:GetCurrentWeapon()
                        if slua.isValid(currentWeapon) then
                            local weaponID = currentWeapon:GetWeaponID()
                            local skinID = _G.get_skin_id(weaponID)
                            if skinID then DamageRecordData.CauserWeaponAvatarID = skinID end
                            if _G.OutfitMap.Suit and _G.OutfitMap.Suit ~= 0 then DamageRecordData.CauserClothAvatarID = _G.OutfitMap.Suit end
                            
                            if CACHED_GoldColor then
                                DamageRecordData.IsUseColor, DamageRecordData.UseColor = true, CACHED_GoldColor
                            end
                            
                            if DamageRecordData.ResultHealthStatus == 2 then
                                _G.TDFTDeKillCounts[weaponID] = (_G.TDFTDeKillCounts[weaponID] or 0) + 1
                                _G.NeedCheckDeadBoxTimer = 50 
                                
                                if not CACHED_UI_Manager then CACHED_UI_Manager = require("client.slua_ui_framework.manager") end
                                local uiMainKillCounter = CACHED_UI_Manager.GetUI(CACHED_UI_Manager.UI_Config_InGame.MainKillCounter)
                                
                                if uiMainKillCounter and uiMainKillCounter.UpdateWeaponID then
                                    local mainAvatarID = skinID or currentWeapon:GetWeaponMainAvatarID()
                                    uiMainKillCounter:UpdateWeaponID(weaponID, mainAvatarID)
                                    local kcModule = ModuleManager.GetModule(ModuleManager.CommonModuleConfig.LogicKillCounter)
                                    local kcItemID = kcModule:GetEquipedKillCounterId(0, mainAvatarID)
                                    uiMainKillCounter:SetKillCounterItemShowWithNum(kcItemID, _G.TDFTDeKillCounts[weaponID], mainAvatarID)
                                end
                            end
                        end
                    end
                end)
                if originalFileItem then return originalFileItem(self, DamageRecordData) end
            end
            _G.KillInfoCounterHacked = true
        end

        local SwitchWeaponSlotMode2 = package.loaded["GameLua.Mod.BaseMod.Client.MainControlUI.SwitchWeaponSlotMode2"] or require("GameLua.Mod.BaseMod.Client.MainControlUI.SwitchWeaponSlotMode2")
        if SwitchWeaponSlotMode2 and SwitchWeaponSlotMode2.__inner_impl and not _G.SlotBaseHacked then
            SwitchWeaponSlotMode2.__inner_impl.CheckShowKCIcon = function(self)
                if slua.isValid(self.KillCounterImg) then 
                    self.KillCounterImg:SetVisibility(import("ESlateVisibility").SelfHitTestInvisible) 
                end
            end
            _G.SlotBaseHacked = true
        end
    end)
end

function _G.InitializeSkinModSystem()
    pcall(function()
        local LobbyAvatar = package.loaded["client.logic.avatar.LobbyAvatar"] or require("client.logic.avatar.LobbyAvatar")
        if LobbyAvatar and not _G.LobbyBypassHacked then
            local originalPutonEquipment = LobbyAvatar.PutonEquipment
            LobbyAvatar.PutonEquipment = function(self, itemID, tAvatarCustom, tExtraData)
                local attachIndex = _G.BaseAttachToIndex and _G.BaseAttachToIndex[itemID]
                if attachIndex then
                    local holdingWeaponSkinID = self.GetCurHoldingWeaponSkinID and self:GetCurHoldingWeaponSkinID()
                    if holdingWeaponSkinID and holdingWeaponSkinID >= 10000000 and _G.VIP_Attachments and _G.VIP_Attachments[holdingWeaponSkinID] then
                        local vipAttachID = _G.VIP_Attachments[holdingWeaponSkinID][attachIndex]
                        if vipAttachID and vipAttachID > 0 then
                            if self.HandleDownload then self:HandleDownload(vipAttachID, nil, nil, false) end
                            itemID = vipAttachID
                        end
                    end
                end
                if originalPutonEquipment then return originalPutonEquipment(self, itemID, tAvatarCustom, tExtraData) end
            end

            local originalCharEquipWeaponByResId = LobbyAvatar.CharEquipWeaponByResId
            LobbyAvatar.CharEquipWeaponByResId = function(self, resID, isUse, isAsync, SocketName)
                local retValue = originalCharEquipWeaponByResId and originalCharEquipWeaponByResId(self, resID, isUse, isAsync, SocketName) or nil
                if isUse and self.GetEquipments then
                    local equipments = self:GetEquipments()
                    for _, equip in ipairs(equipments) do
                        if _G.BaseAttachToIndex and _G.BaseAttachToIndex[equip.itemID] then
                            self:PutonEquipment(equip.itemID, equip.CustomInfo, {bIsUse = false})
                        end
                    end
                end
                return retValue
            end
            _G.LobbyBypassHacked = true
        end
    end)
    
    pcall(function()
        local Common_Items_UIBP = package.loaded["client.slua.component.item.ItemChildren.Common_Items_UIBP"] or require("client.slua.component.item.ItemChildren.Common_Items_UIBP")
        if Common_Items_UIBP and not _G.IconBaloHacked then
        local originalInitView = Common_Items_UIBP.InitView
            Common_Items_UIBP.InitView = function(self, nItemId, nCount, nValidTime, tExtraData)
                tExtraData = tExtraData or {}
                local displayResId = nil
                
                if _G.get_skin_id then
                    local skinID = _G.get_skin_id(nItemId)
                    if skinID and skinID ~= nItemId then displayResId = skinID end
                end
                
                local attachIndex = _G.BaseAttachToIndex and _G.BaseAttachToIndex[nItemId]
                if not displayResId and attachIndex then
                    local GameplayData = require("GameLua.GameCore.Data.GameplayData")
                    local LocalPlayer = GameplayData and GameplayData.GetPlayerCharacter()
                    if slua.isValid(LocalPlayer) then
                        local currentWeapon = LocalPlayer:GetCurrentWeapon()
                        if slua.isValid(currentWeapon) then
                            local weaponID = currentWeapon:GetWeaponID()
                            local finalSkinID = _G.get_skin_id(weaponID) or weaponID
                            if finalSkinID >= 10000000 and _G.VIP_Attachments and _G.VIP_Attachments[finalSkinID] then
                                local vipAttachID = _G.VIP_Attachments[finalSkinID][attachIndex]
                                if vipAttachID and vipAttachID > 0 then displayResId = vipAttachID end
                            end
                        end
                    end
                end
                
                if displayResId then
                    tExtraData.displayResId = displayResId
                    if not _G.skinIdCache2[displayResId] then
                        if _G.download_item then pcall(_G.download_item, displayResId) end
                        _G.skinIdCache2[displayResId] = true
                    end
                end
                if originalInitView then return originalInitView(self, nItemId, nCount, nValidTime, tExtraData) end
            end
            _G.IconBaloHacked = true
        end
    end)
end
-- ===== COPIED SKIN SYSTEM END =====
_G.LexusState = _G.LexusState or {}
_G.LexusState.CustomTextData = _G.LexusState.CustomTextData or {
    SkinSuit=1, SkinBag=1, SkinHelmet=1,
    SkinM416=1, SkinAKM=1, SkinSCAR=1, SkinM762=1, SkinAUG=1, SkinUMP=1, SkinUZI=1,
    SkinGroza=1, SkinS12K=1, SkinDBS=1, SkinASM=1, SkinQBZ=1, SkinHoney=1, SkinM16A4=1,
    SkinACE32=1, SkinKar98k=1, SkinM24=1, SkinAWM=1,
    SkinDacia=1, SkinUAZ=1, SkinCoupe=1, SkinBuggy=1, SkinMirado=1,
}
pcall(function()
    if _G.ForceRefreshSkinMaps then _G.ForceRefreshSkinMaps() end
end)

pcall(function() if _G.InitializeSkinBypass then _G.InitializeSkinBypass() end end)

_G.BRSkinUpdate = function()
    pcall(function()
        local GDP = GameplayData
        local localPlayer = GDP and GDP.GetLocalCharacter and GDP.GetLocalCharacter()
        if not Valid(localPlayer) then return end
        local PC = nil
        pcall(function() if slua_GameFrontendHUD then PC = slua_GameFrontendHUD:GetPlayerController() end end)

        -- KILL COUNTER UI hack (self-guards via KillInfoCounterHacked)
        pcall(function()
            if not _G.KillInfoCounterHacked and _G.ForceEnableKillCounterUI then _G.ForceEnableKillCounterUI() end
        end)

        -- DEAD BOX skin
        pcall(function() if _G.DeadBox_TemperRequest and PC then _G.DeadBox_TemperRequest(PC) end end)

        -- AUTO REPORT (Reports enemies, skips teammates)
        pcall(function()
            if _G.AutoReportConfig and _G.AutoReportConfig.Enable and _G.AutoReportTick then
                _G.AutoReportTick()
            end
        end)

        -- FPS re-assert (engine sometimes resets the limiter)
        pcall(function()
            if _G.MemoryConfig and _G.MemoryConfig.UnlockFPS and _G.ApplyMemoryFeature then
                _G.ApplyMemoryFeature("FPS", true)
            end
        end)

        if _G.LexusConfig.ModSkin then
            if not _G.TDSkinLoopStarted then
                if _G.InitializeSkinModSystem then _G.InitializeSkinModSystem() end
                if _G.ForceRefreshSkinMaps then _G.ForceRefreshSkinMaps() end
                _G.TDSkinLoopStarted = true
            end
            _G.LexusState.SkinWasApplied = true
            local curTime = os.clock()
            if not _G.LastSkinUpdateTime or (curTime - _G.LastSkinUpdateTime) > 1.5 then
                _G.LastSkinUpdateTime = curTime
                pcall(function()
                    local isAlive = type(localPlayer.IsAlive) == "function" and localPlayer:IsAlive() or true
                    if isAlive then
                        if _G.equip_character_avatar then _G.equip_character_avatar(localPlayer) end
                        if _G.ApplyWeaponSkins then _G.ApplyWeaponSkins(localPlayer) end
                        if _G.ApplyVehicleSkins then _G.ApplyVehicleSkins(localPlayer) end
                        if _G.HandlePetLogic then _G.HandlePetLogic(localPlayer) end
                    end
                end)
            end
            if _G.LexusState.DirtyConfig then
                if _G.ForceRefreshSkinMaps then _G.ForceRefreshSkinMaps() end
                _G.LexusState.DirtyConfig = false
            end
        else
            if _G.LexusState.SkinWasApplied then
                _G.OutfitMap = {}
                _G.WeaponSkinMap = {}
                _G.VehicleSkinMap = {}
                pcall(function()
                    local WeaponManager = localPlayer:GetWeaponManager()
                    if Valid(WeaponManager) then
                        for slot = 1, 3 do
                            local Weapon = WeaponManager:GetInventoryWeaponByPropSlot(slot)
                            if Valid(Weapon) and Valid(Weapon.synData) then
                                local WeaponID = Weapon:GetWeaponID()
                                local SkinData = Weapon.synData:Get(7)
                                if SkinData and SkinData.defineID then
                                    SkinData.defineID.TypeSpecificID = WeaponID
                                    Weapon.synData:Set(7, SkinData)
                                    if Weapon.SetWeaponAvatarID then pcall(function() Weapon:SetWeaponAvatarID(WeaponID) end) end
                                    if Weapon.DelayHandleAvatarMeshChanged then pcall(function() Weapon:DelayHandleAvatarMeshChanged() end) end
                                end
                            end
                        end
                    end
                    local Vehicle = localPlayer:GetCurrentVehicle()
                    if Valid(Vehicle) then
                        local VehicleAvatar = Vehicle.VehicleAvatar or Vehicle.VehicleAvatarComponent_BP or Vehicle:GetAvatarComponent()
                        if Valid(VehicleAvatar) and type(VehicleAvatar.GetDefaultAvatarID) == "function" then
                            local defId = VehicleAvatar:GetDefaultAvatarID()
                            if VehicleAvatar.ChangeItemAvatar then VehicleAvatar:ChangeItemAvatar(defId, true) end
                        end
                    end
                    if localPlayer.AvatarComponent2 and type(localPlayer.AvatarComponent2.OnRep_BodySlotStateChanged) == "function" then
                        localPlayer.AvatarComponent2:OnRep_BodySlotStateChanged()
                    end
                end)
                _G.LexusState.SkinWasApplied = false
            end
            _G.TDSkinLoopStarted = false
        end
    end)
end

-- ===== KILL BROADCAST SKIN INJECT HOOK (by @DEMON_D5) =====
if not _G.ZN_KillBroadcastHacked then
    pcall(function()
        local BattleKillBroadcastSubSystem = require("GameLua.Mod.BaseMod.Client.BattleKillBroadcast.BattleKillBroadcastSubSystem")
        if BattleKillBroadcastSubSystem then
            local O_CopyKillOrPutDownMessageDataUserDataToLuaTable = BattleKillBroadcastSubSystem.CopyKillOrPutDownMessageDataUserDataToLuaTable
            BattleKillBroadcastSubSystem.CopyKillOrPutDownMessageDataUserDataToLuaTable = function(self, messageData)
                local msgData = O_CopyKillOrPutDownMessageDataUserDataToLuaTable(self, messageData)
                if msgData and msgData.bIamCauser then
                    local uCharacter = slua_GameFrontendHUD and slua_GameFrontendHUD:GetPlayerController() and slua_GameFrontendHUD:GetPlayerController():GetPlayerCharacterSafety()
                    if uCharacter and slua.isValid(uCharacter) then
                        if msgData.DamageType == UEnums.DamageType.VehicleDamage then
                            local carSkinID = _G.CurrentEquipVehicleID
                            if carSkinID ~= 0 then
                                local ExpandData = slua.LuaArchiverDecode(LuaStateWrapper, msgData.ExpandDataContent) or {}
                                ExpandData.CauserVehicleSkinID = carSkinID
                                ExpandData.CauserWeaponAvatarID = carSkinID
                                msgData.ExpandDataContent = slua.LuaArchiverEncode(LuaStateWrapper, ExpandData)
                            end
                        else
                            local currWeapon = uCharacter:GetCurrentWeapon()
                            if currWeapon and slua.isValid(currWeapon) then
                                local synData = currWeapon.synData
                                if synData and slua.isValid(synData) then
                                    local weaponDefineID = slua.IndexReference(synData:Get(7), "defineID")
                                    if weaponDefineID and slua.isValid(weaponDefineID) then
                                        local ExpandData = slua.LuaArchiverDecode(LuaStateWrapper, msgData.ExpandDataContent) or {}
                                        ExpandData.CauserWeaponAvatarID = weaponDefineID.TypeSpecificID
                                        msgData.ExpandDataContent = slua.LuaArchiverEncode(LuaStateWrapper, ExpandData)
                                    end
                                end
                            end
                        end
                    end
                end
                return msgData
            end
            _G.ZN_KillBroadcastHacked = true
        end
    end)
end
-- ===== KILL BROADCAST SKIN INJECT HOOK END =====

-- ====== AUTO REPORT SYSTEM (Reports all enemies, skips teammates) ======
_G.AutoReportConfig = _G.AutoReportConfig or {
    Enable = false,
    ReportReason = 1,
    ReportDelay = 3.0,
    BotsOnly = false,
    AutoScreenshot = true,
    _lastReportTime = 0,
    _reportedPlayers = {},
    _cachedReportModule = nil,
    _reportQueue = {},
}

_G.AutoReportReasons = {
    [1] = "Cheating",
    [2] = "Hacking",
    [3] = "Abusing",
    [4] = "Griefing",
    [5] = "Team Killing",
}

_G.AutoReportPlayer = function(targetPlayer)
    if not _G.AutoReportConfig.Enable then return end
    if not targetPlayer or not slua.isValid(targetPlayer) then return end
    if not targetPlayer:IsAlive() then return end

    local localPlayer = nil
    pcall(function() localPlayer = GameplayData.GetLocalCharacter() end)
    if not Valid(localPlayer) then return end

    local myTeam = nil
    pcall(function() myTeam = localPlayer:GetTeamID() end)
    local targetTeam = nil
    pcall(function() targetTeam = targetPlayer:GetTeamID() end)

    if myTeam and targetTeam and myTeam == targetTeam then return end

    local targetKey = nil
    pcall(function() targetKey = targetPlayer:GetPlayerKey() end)
    if not targetKey then
        pcall(function() targetKey = targetPlayer.PlayerKey end)
    end
    if not targetKey then return end

    if _G.AutoReportConfig._reportedPlayers[targetKey] then return end

    local targetName = nil
    pcall(function() targetName = targetPlayer:GetPlayerNameSafety() end)
    if not targetName then
        pcall(function()
            local PS = targetPlayer:GetPlayerState()
            if Valid(PS) and PS.GetPlayerName then
                targetName = PS:GetPlayerName()
            end
        end)
    end
    if not targetName or targetName == "" or targetName == "Unknown" then return end

    local reason = _G.AutoReportReasons[_G.AutoReportConfig.ReportReason] or "Cheating"
    _G.AutoReportConfig._reportedPlayers[targetKey] = true
    _G.AutoReportConfig._reportQueue[#_G.AutoReportConfig._reportQueue + 1] = {key = targetKey, reason = reason, name = targetName}
end

_G._ProcessReportQueue = function()
    local queue = _G.AutoReportConfig._reportQueue
    if not queue or #queue == 0 then return end

    local curTime = os.clock()
    if (curTime - _G.AutoReportConfig._lastReportTime) < 0.5 then return end

    local entry = table.remove(queue, 1)
    if not entry then return end

    pcall(function()
        if not _G.AutoReportConfig._cachedReportModule then
            _G.AutoReportConfig._cachedReportModule = require("GameLua.Mod.BaseMod.Client.Security.ClientReportPlayerSubsystem")
        end
        local mod = _G.AutoReportConfig._cachedReportModule
        if mod and mod.ReportPlayer then
            mod:ReportPlayer(entry.key, entry.reason)
            _G.AutoReportConfig._lastReportTime = curTime
        end
    end)
end

_G.AutoReportTick = function()
    if not _G.AutoReportConfig.Enable then return end

    _G._ProcessReportQueue()

    local localPlayer = nil
    pcall(function() localPlayer = GameplayData.GetLocalCharacter() end)
    if not Valid(localPlayer) then return end

    local allCharacters = {}
    pcall(function()
        if GameplayData.GetAllPlayerCharacters then
            allCharacters = GameplayData.GetAllPlayerCharacters()
        end
    end)

    local aliveEnemies = 0
    for _, actor in pairs(allCharacters) do
        if Valid(actor) and actor ~= localPlayer and actor:IsAlive() then
            local isTeammate = false
            pcall(function()
                local myTeam = localPlayer:GetTeamID()
                local tTeam = actor:GetTeamID()
                if myTeam and tTeam and myTeam == tTeam then isTeammate = true end
            end)
            if not isTeammate then
                aliveEnemies = aliveEnemies + 1
                _G.AutoReportPlayer(actor)
                if (os.clock() - _G._AutoReportTickStart or 0) > 0.05 then break end
            end
        end
    end

    if aliveEnemies == 0 and _G.AutoReportConfig.AutoScreenshot then
        if not _G._AutoReportSSSent then
            _G._AutoReportSSSent = true
            pcall(function()
                local KSL = import("KismetSystemLibrary")
                local world = slua.getWorld()
                if KSL and world then
                    KSL.ExecuteConsoleCommand(world, "HighResShot 1920x1080")
                end
            end)
        end
    end

    if aliveEnemies > 0 then
        _G._AutoReportSSSent = false
    end
end

_G.BRStartSkinLoop = function()
    _G.__BR_SkinTimer = nil
    pcall(function()
        if _G.Game and _G.Game.AddGameTimer then
            _G.__BR_SkinTimer = _G.Game:AddGameTimer(0.5, true, _G.BRSkinUpdate)
        elseif slua_GameFrontendHUD then
            local pc = slua_GameFrontendHUD:GetPlayerController()
            if Valid(pc) and type(pc.AddGameTimer) == "function" then
                _G.__BR_SkinTimer = pc:AddGameTimer(0.5, true, _G.BRSkinUpdate)
            end
        end
    end)
end
_G.BRStartSkinLoop()
    -- Zn MENU MODULE - OPTIMIZED FOR NO LAG (ZERO REPETITION)
    -- ============================================================
    local MY_TAB_VER = 16

    if not _G.__MyTabInstalled then
    _G.__MyTabInstalled = true

    local LOC = {
        MY_TAB             = 9990001,
        TAB_AIMBOT         = 9990011,
        TAB_MEMORY         = 9990014,
        TAB_SKIN           = 9990015,
        TITLE_SKIN         = 9990016,

        BTN_ESP_ENABLE     = 9990100,
        TITLE_ESP          = 9990101,
        BTN_CHAMS_ENABLE   = 9990102,
        BTN_ESP_LINES      = 9990103,
        BTN_ESP_FOV_CIRCLE = 9990110,
        BTN_ESP_ARROWS     = 9990111,
        BTN_ESP_BOX        = 9990112,
        BTN_CHAMS_VIS      = 9990104,
        BTN_CHAMS_OCC      = 9990105,
        BTN_NEW_WALLHACK   = 9990120,
        BTN_NEW_WH_VIS     = 9990121,
        BTN_NEW_WH_OCC     = 9990122,
        BTN_BLUE_FRAME     = 9990123,
        BTN_FAKE_HWID      = 9990106,
        
        TAB_BAN            = 9990017,
        BTN_CAR_FLY        = 9990107,
        BTN_CAR_FLY_SPEED  = 9990108,
        BTN_FAST_CAR       = 9990109,

        BTN_AIMBOT_ENABLE  = 9990030,
        BTN_AIMBOT_NORMAL = 9990036,
        BTN_AIMBOT_FOV     = 9990031,
        BTN_AIMBOT_DIST    = 9990032,
        BTN_AIMBOT_SPEED   = 9990033,
        BTN_AIMBOT_KNOCK   = 9990034,
        BTN_AIMBOT_BOT     = 9990035,
        BTN_AIMBOT_TARGET  = 9990037,
        BTN_AIMBOT_WALL    = 9990038,
        BTN_AIMBOT_INSCOPE = 9990039,
        BTN_AIMBOT_LONGRANGE = 9990042,
        BTN_AIMBOT_BONE    = 9990041,
        BTN_LOBBY_SKIN     = 9990040,
        
        BTN_MEM_GRASS      = 9990080,
        BTN_MEM_TREES      = 9990081,
        BTN_MEM_FOG        = 9990082,
        BTN_MEM_BLACKSKY   = 9990083,
        BTN_MEM_FPS        = 9990084,
        BTN_MEM_IPAD       = 9990085,
        BTN_MEM_IPAD_FOV   = 9990086,
        BTN_MEM_SMALLSCOPE     = 9990088,
        BTN_MEM_SMALLSCOPE_FOV = 9990089,
        
        BTN_MEM_CROSSHAIR  = 9990087,
        
        BTN_AUTO_REPORT       = 9990090,
        BTN_AUTO_REPORT_REASON = 9990091,
        BTN_AUTO_REPORT_DELAY  = 9990092,
        
        OPT_ON             = 9990060,
        OPT_OFF            = 9990061,
        
        TITLE_AIMING       = 9990062,
        TITLE_SETTINGS     = 9990063,
    }

    local LOC_STR = {
        [LOC.MY_TAB]            = "VIP MENU",
        [LOC.TAB_AIMBOT]        = "AIMBOT",
        [LOC.TAB_MEMORY]        = "MEMORY",
        [LOC.TAB_SKIN]          = "SKIN",
        [LOC.TAB_BAN]           = "BAN FEATURES",
        [LOC.BTN_CAR_FLY]       = "Car Fly",
        [LOC.BTN_CAR_FLY_SPEED] = "Car Fly Speed",
        [LOC.BTN_FAST_CAR]      = "Fast Car",
        [LOC.TITLE_SKIN]        = "SKIN CONTROL",

        [LOC.BTN_ESP_ENABLE]    = "ESP Enable",
        [LOC.TITLE_ESP]         = "ESP Control",
        [LOC.BTN_CHAMS_ENABLE]  = "Chams (Color)",
        [LOC.BTN_ESP_LINES]     = "ESP Lines",
        [LOC.BTN_ESP_FOV_CIRCLE] = "FOV Circle",
        [LOC.BTN_ESP_ARROWS]     = "Offscreen Arrows",
        [LOC.BTN_ESP_BOX]        = "Box ESP",
        [LOC.BTN_CHAMS_VIS]     = "Chams Front Color (1R 2B 3G 4Y 5O 6P)",
        [LOC.BTN_CHAMS_OCC]     = "Chams Wall Color (1R 2B 3G 4Y 5O 6P)",
        [LOC.BTN_NEW_WALLHACK]  = "NEW WALLHACK (PBC)",
        [LOC.BTN_NEW_WH_VIS]    = "Wallhack Visible Color (1Green 2Lime 3Orange 4Red 5Blue 6Gray 7Teal)",
        [LOC.BTN_NEW_WH_OCC]    = "Wallhack Wall Color (1Green 2Lime 3Orange 4Red 5Blue 6Gray 7Teal)",
        [LOC.BTN_BLUE_FRAME]    = "BLUE FRAME ESP (OB Head)",
        [LOC.BTN_FAKE_HWID]     = "Fake HWID (Anti-Ban)",
        
        [LOC.BTN_AIMBOT_ENABLE] = "Aimbot Enable",
        [LOC.BTN_AIMBOT_NORMAL] = "Normal Aimbot",
        [LOC.BTN_AIMBOT_FOV]    = "Aimbot FOV",
        [LOC.BTN_AIMBOT_DIST]   = "Aimbot Max Dist",
        [LOC.BTN_AIMBOT_SPEED]  = "Aimbot Smooth Speed",
        [LOC.BTN_AIMBOT_KNOCK]  = "Ignore Knocked",
        [LOC.BTN_AIMBOT_BOT]    = "Ignore Bots",
        [LOC.BTN_AIMBOT_TARGET] = "Target Mode (1Near 2LowHP)",
        [LOC.BTN_AIMBOT_WALL]   = "Wall Target (Through Wall)",
        [LOC.BTN_AIMBOT_INSCOPE] = "In Scope Aimbot (10-100m)",
        [LOC.BTN_AIMBOT_LONGRANGE] = "Long Range Aimbot (300m+)",
        [LOC.BTN_AIMBOT_BONE]    = "Aim Bone",
        [LOC.BTN_LOBBY_SKIN]     = "Show (LOBBY SKIN)",
        
        [LOC.BTN_MEM_GRASS]     = "Remove Grass",
        [LOC.BTN_MEM_TREES]     = "Remove Trees",
        [LOC.BTN_MEM_FOG]       = "Remove Fog",
        [LOC.BTN_MEM_BLACKSKY]  = "Black Sky",
        [LOC.BTN_MEM_FPS]       = "Unlock 165 FPS",
        [LOC.BTN_MEM_IPAD]      = "iPad View",
        [LOC.BTN_MEM_IPAD_FOV]  = "iPad FOV",
        [LOC.BTN_MEM_SMALLSCOPE]     = "Small Scope (iPad Style)",
        [LOC.BTN_MEM_SMALLSCOPE_FOV] = "Small Scope FOV",
        
        [LOC.BTN_MEM_CROSSHAIR]  = "Small Crosshair",
        
        [LOC.BTN_AUTO_REPORT]    = "Auto Report Enemies",
        [LOC.BTN_AUTO_REPORT_REASON] = "Report Reason",
        [LOC.BTN_AUTO_REPORT_DELAY]  = "Report Delay",
        
        [LOC.OPT_ON]            = "ON",
        [LOC.OPT_OFF]           = "OFF",
        
        [LOC.TITLE_AIMING]      = "Aimbot Configuration",
        [LOC.TITLE_SETTINGS]    = "Memory Hacks",
    }

    _G.MemoryConfig = _G.MemoryConfig or {
        RemoveGrass = false,
        RemoveTrees = false,
        RemoveFog   = false,
        BlackSky    = false,
        UnlockFPS   = false,
        IpadView    = false,
        IpadFOV     = 120,
        _IpadWasActive = false,
        SmallCrosshair = false,
        _CrosshairWasActive = false,
    }

    local function ResolveLoc(id)
        return LOC_STR[id]
    end

    local function LOG(msg)
        pcall(print, "[Zn Menu] " .. tostring(msg))
    end

    LOG("Zn Menu v" .. MY_TAB_VER .. " loading...")

    local function ApplyMemoryFeature(feature, state)
        pcall(function()
        local lsg = require("client.slua.logic.setting.logic_setting_graphics")
        local gi = lsg.GetGameInstance()
        if not gi then
            gi = slua_GameFrontendHUD and slua_GameFrontendHUD:GetWorld()
        end
        if not gi then return end

        if feature == "Grass" then
            if state then
            gi:ExecuteCMD("grass.DensityScale", "0")
            gi:ExecuteCMD("grass.DiscardDataOnLoad", "1")
            else
            gi:ExecuteCMD("grass.DensityScale", "1")
            gi:ExecuteCMD("grass.DiscardDataOnLoad", "0")
            end
        elseif feature == "Trees" then
            if state then
            gi:ExecuteCMD("foliage.DensityScale", "0")
            gi:ExecuteCMD("r.Foliage.DensityScale", "0")
            gi:ExecuteCMD("foliage.MinimumScreenSize", "10000")
            gi:ExecuteCMD("r.DisableTreeRender", "1")
            else
            gi:ExecuteCMD("foliage.DensityScale", "1")
            gi:ExecuteCMD("r.Foliage.DensityScale", "1")
            gi:ExecuteCMD("foliage.MinimumScreenSize", "0")
            gi:ExecuteCMD("r.DisableTreeRender", "0")
            end
        elseif feature == "Fog" then
            if state then
            gi:ExecuteCMD("r.SkyAtmosphere", "1")
            gi:ExecuteCMD("r.Fog", "0")
            gi:ExecuteCMD("r.VolumetricFog", "0")
            else
            gi:ExecuteCMD("r.SkyAtmosphere", "1")
            gi:ExecuteCMD("r.Fog", "1")
            gi:ExecuteCMD("r.VolumetricFog", "1")
            end
        elseif feature == "BlackSky" then
            if state then
            gi:ExecuteCMD("r.CylinderMaxDrawHeight", "9999")
            else
            gi:ExecuteCMD("r.CylinderMaxDrawHeight", "0")
            end
        elseif feature == "FPS" then
            local SettingCfg = require("client.logic.setting.setting_config")
            local GraphicSettingDB = require("client.slua.umg.NewSetting.GraphicsNew.GraphicSettingDB")
            
            if state then
            if SettingCfg then
                if SettingCfg.TpViewValue then SettingCfg.TpViewValue.max = 160 end
                if SettingCfg.FpViewValue then SettingCfg.FpViewValue.max = 160 end
            end
            if GraphicSettingDB then
                if GraphicSettingDB.TpViewValue then GraphicSettingDB.TpViewValue.max = 160 end
            end
            gi:ExecuteCMD("t.MaxFPS", "165")
            gi:ExecuteCMD("r.FrameRateLimit", "165")
            else
            if SettingCfg then
                if SettingCfg.TpViewValue then SettingCfg.TpViewValue.max = 90 end
                if SettingCfg.FpViewValue then SettingCfg.FpViewValue.max = 90 end
            end
            if GraphicSettingDB then
                if GraphicSettingDB.TpViewValue then GraphicSettingDB.TpViewValue.max = 90 end
            end
            gi:ExecuteCMD("t.MaxFPS", "90")
            gi:ExecuteCMD("r.FrameRateLimit", "90")
            end
        end
        end)
    end

    _G.ApplyMemoryFeature = ApplyMemoryFeature

    local function RefreshAllMemoryFeatures()
        if not _G.MemoryConfig then return end
        ApplyMemoryFeature("Grass", _G.MemoryConfig.RemoveGrass)
        ApplyMemoryFeature("Trees", _G.MemoryConfig.RemoveTrees)
        ApplyMemoryFeature("Fog", _G.MemoryConfig.RemoveFog)
        ApplyMemoryFeature("BlackSky", _G.MemoryConfig.BlackSky)
        ApplyMemoryFeature("FPS", _G.MemoryConfig.UnlockFPS)
    end
    _G.RefreshAllMemoryFeatures = RefreshAllMemoryFeatures

    RefreshAllMemoryFeatures()

    local function HookLoc(tbl, fname)
        if type(tbl) ~= "table" then return end
        if tbl["__mytab_hooked_" .. fname] then return end
        
        local orig = tbl[fname]
        if type(orig) ~= "function" then return end
        
        tbl["__mytab_hooked_" .. fname] = true
        tbl["__mytab_" .. fname] = orig
        
        tbl[fname] = function(...)
        local arg1 = select(1, ...)
        local id = arg1
        if type(arg1) == "table" and arg1 == tbl then
            id = select(2, ...)
        end
        
        local s = ResolveLoc(id)
        if s then return s end
        return orig(...)
        end
    end

    local function InstallLocHooks()
        local LocUtil = _G.LocUtil
        if not LocUtil then
        local ok, lu = pcall(require, "common.loc_util")
        if ok and lu then LocUtil = lu end
        end
        if type(LocUtil) == "table" then
        HookLoc(LocUtil, "GetLocalizeResStr")
        HookLoc(LocUtil, "GetLocalizeResStrV2")
        HookLoc(LocUtil, "TryGetLocalizeResStr")
        HookLoc(LocUtil, "ResolveText")
        end
        local DataMgr = _G.DataMgr
        if not DataMgr then
        local ok2, dm = pcall(require, "client.logic.data.data_mgr")
        if ok2 and dm then DataMgr = dm end
        end
        if type(DataMgr) == "table" then
        HookLoc(DataMgr, "GetMsgByID")
        HookLoc(DataMgr, "GetFormatMsgByID")
        end
    end

    InstallLocHooks()

    pcall(function()
        if type(slua) == "table" and type(slua.AddTickerDelegate) == "function" then
        local tries = 0
        slua.AddTickerDelegate(function()
            tries = tries + 1
            InstallLocHooks()
            return tries < 5
        end, 1.0)
        end
    end)

    local MY_TAB_DEFINE = {
        Key  = "MyTab",
        Text = LOC.MY_TAB,
    }

    local function GetMyTabDefine()
        if MY_TAB_DEFINE.Category then return MY_TAB_DEFINE end
        local cfg = UIManager and UIManager.UI_Config
        if not cfg then return MY_TAB_DEFINE end

        local SwitcherUI = cfg.Setting_Option_Switcher
        if not SwitcherUI then return MY_TAB_DEFINE end

        local TitleUI   = cfg.Setting_Title
        local SliderUI  = cfg.Setting_Option_Slider
        local SpacerUI  = cfg.Setting_Spacer

        local function MakeSwitcher(key, textId, getCb, setCb)
        return {
            Key          = "MyTab_" .. key,
            UI           = SwitcherUI,
            Text         = textId,
            SwitcherText = { LOC.OPT_ON, LOC.OPT_OFF },
            GetFunc = function(item)
            local index = getCb()
            if type(item) == "table" then item.CurrentIndex = index end
            return index
            end,
            SetFunc = function(item, index)
            setCb(index)
            if type(item) == "table" then
                item.CurrentIndex = index
                item.SelectedIndex = index
                item.Value = index
                pcall(function()
                if item.SetSelectedIndex then item:SetSelectedIndex(index) end
                if item.UpdateView then item:UpdateView() end
                if item.RefreshUI then item:RefreshUI() end
                end)
            end
            return true
            end,
        }
        end

        local function MakeBoneSwitcher(key, textId, getCb, setCb)
        return {
            Key          = "MyTab_" .. key,
            UI           = SwitcherUI,
            Text         = textId,
            SwitcherText = { "Head", "Chest", "Pelvis" },
            GetFunc = function(item)
            local index = getCb()
            if type(item) == "table" then item.CurrentIndex = index end
            return index
            end,
            SetFunc = function(item, index)
            setCb(index)
            if type(item) == "table" then
                item.CurrentIndex = index
                item.SelectedIndex = index
                item.Value = index
                pcall(function()
                if item.SetSelectedIndex then item:SetSelectedIndex(index) end
                if item.UpdateView then item:UpdateView() end
                if item.RefreshUI then item:RefreshUI() end
                end)
            end
            return true
            end,
        }
        end

        local function MakeSlider(key, textId, minVal, maxVal, getCb, setCb)
        return {
            Key      = "MyTab_" .. key,
            UI       = SliderUI,
            Text     = textId,
            Min      = minVal,
            Max      = maxVal,
            GetFunc  = function(item)
            local val = getCb()
            if type(item) == "table" then item.Value = val end
            return val
            end,
            SetFunc  = function(item, val)
            setCb(val)
            if type(item) == "table" then
                item.Value = val
                pcall(function()
                if item.UpdateView then item:UpdateView() end
                if item.RefreshUI then item:RefreshUI() end
                end)
            end
            end,
        }
        end

        local function skinSlider(key, label, minVal, maxVal, field, mapTbl, mapKey)
            return MakeSlider(key, label, minVal, maxVal,
                function()
                    if not _G.LexusState.CustomTextData then return 1 end
                    return _G.LexusState.CustomTextData[field] or 1
                end,
                function(val)
                    local v = math.floor(val)
                    _G.LexusState.CustomTextData = _G.LexusState.CustomTextData or {}
                    _G.LexusState.CustomTextData[field] = v
                    if mapTbl and mapKey and _G[mapTbl] and _G[mapTbl][mapKey] then
                        local entry = _G[mapTbl][mapKey]
                        if entry and entry[v] then
                            if mapTbl == "OutfitSkins" then
                                _G.OutfitMap = _G.OutfitMap or {}
                                _G.OutfitMap[field:gsub("^Skin", "")] = entry[v]
                            elseif mapTbl == "VehicleSkins" then
                                _G.VehicleSkinMap[mapKey] = entry[v]
                            else
                                _G.WeaponSkinMap[mapKey] = entry[v]
                            end
                        end
                    end
                    _G.LexusState.DirtyConfig = true
                end
            )
        end

        local function MakeStack(sections)
        local stack = {}
        for secIdx, sec in ipairs(sections) do
            if secIdx > 1 and SpacerUI then
            stack[#stack + 1] = {
                Key  = "MyTab_spacer_" .. tostring(#stack),
                UI   = SpacerUI,
            }
            end
            if TitleUI and sec.title then
            stack[#stack + 1] = {
                Key  = "MyTab_title_" .. tostring(secIdx),
                UI   = TitleUI,
                Text = sec.title,
            }
            end
            for _, item in ipairs(sec.items or {}) do
            stack[#stack + 1] = item
            end
        end
        return stack
        end

        local tab1Section1 = {
        MakeSwitcher("aim_enable", LOC.BTN_AIMBOT_ENABLE, 
            function() return (_G.AimbotConfig and _G.AimbotConfig.Enable) and 1 or 2 end,
            function(idx) if _G.AimbotConfig then _G.AimbotConfig.Enable = (idx == 1) end end
        ),
        MakeSwitcher("aim_normal", LOC.BTN_AIMBOT_NORMAL, 
            function() return (_G.AimbotConfig and _G.AimbotConfig.NormalAimbot) and 1 or 2 end,
            function(idx) 
                if _G.AimbotConfig then _G.AimbotConfig.NormalAimbot = (idx == 1) end
                if idx == 1 then
                    if _G.ApplyWeaponAimbot then _G.ApplyWeaponAimbot() end
                else
                    if _G.RestoreWeaponAimbot then _G.RestoreWeaponAimbot() end
                end
            end
        )
        }

        local tab1Section2 = {
        MakeSlider("aim_fov", LOC.BTN_AIMBOT_FOV, 1, 300,
            function() return _G.AimbotConfig and _G.AimbotConfig.FOV or 30 end,
            function(val) if _G.AimbotConfig then _G.AimbotConfig.FOV = val end end
        ),
        MakeSlider("aim_dist", LOC.BTN_AIMBOT_DIST, 1, 1000,
            function() return _G.AimbotConfig and _G.AimbotConfig.Distance or 250 end,
            function(val) if _G.AimbotConfig then _G.AimbotConfig.Distance = val end end
        ),
        MakeSlider("aim_speed", LOC.BTN_AIMBOT_SPEED, 1, 100,
            function() return _G.AimbotConfig and _G.AimbotConfig.Speed or 50 end,
            function(val) if _G.AimbotConfig then _G.AimbotConfig.Speed = val end end
        ),
        MakeSwitcher("aim_knock", LOC.BTN_AIMBOT_KNOCK,
            function() return (_G.AimbotConfig and _G.AimbotConfig.IgnoreKnock) and 1 or 2 end,
            function(idx) if _G.AimbotConfig then _G.AimbotConfig.IgnoreKnock = (idx == 1) end end
        ),
        MakeSwitcher("aim_bot", LOC.BTN_AIMBOT_BOT,
            function() return (_G.AimbotConfig and _G.AimbotConfig.IgnoreBot) and 1 or 2 end,
            function(idx) if _G.AimbotConfig then _G.AimbotConfig.IgnoreBot = (idx == 1) end end
        ),
        MakeSwitcher("aim_target", LOC.BTN_AIMBOT_TARGET,
            function() return (_G.AimbotConfig and _G.AimbotConfig.TargetMode) or 1 end,
            function(idx) if _G.AimbotConfig then _G.AimbotConfig.TargetMode = idx end end
        ),
        MakeSwitcher("aim_wall", LOC.BTN_AIMBOT_WALL,
            function() return (_G.AimbotConfig and _G.AimbotConfig.WallTarget) and 1 or 2 end,
            function(idx) if _G.AimbotConfig then _G.AimbotConfig.WallTarget = (idx == 1) end end
        ),
        MakeSwitcher("aim_inscope", LOC.BTN_AIMBOT_INSCOPE,
            function() return (_G.AimbotConfig and _G.AimbotConfig.InScopeAimbot) and 1 or 2 end,
            function(idx) if _G.AimbotConfig then _G.AimbotConfig.InScopeAimbot = (idx == 1) end end
        ),
        MakeSwitcher("aim_longrange", LOC.BTN_AIMBOT_LONGRANGE,
            function() return (_G.AimbotConfig and _G.AimbotConfig.LongRange) and 1 or 2 end,
            function(idx) if _G.AimbotConfig then _G.AimbotConfig.LongRange = (idx == 1) end end
        ),
        MakeBoneSwitcher("aim_bone", LOC.BTN_AIMBOT_BONE,
            function()
                local bone = _G.AimbotConfig and _G.AimbotConfig.Bone or "spine_03"
                if bone == "head" then return 1
                elseif bone == "pelvis" then return 3
                else return 2 end
            end,
            function(idx)
                if _G.AimbotConfig then
                    if idx == 1 then _G.AimbotConfig.Bone = "head"
                    elseif idx == 3 then _G.AimbotConfig.Bone = "pelvis"
                    else _G.AimbotConfig.Bone = "spine_03" end
                end
            end
        ),
        }

        local tab2Section1 = {
        MakeSwitcher("mem_grass", LOC.BTN_MEM_GRASS,
            function() return (_G.MemoryConfig.RemoveGrass and 1 or 2) end,
            function(idx) 
                _G.MemoryConfig.RemoveGrass = (idx == 1) 
                ApplyMemoryFeature("Grass", _G.MemoryConfig.RemoveGrass)
            end
        ),
        MakeSwitcher("mem_trees", LOC.BTN_MEM_TREES,
            function() return (_G.MemoryConfig.RemoveTrees and 1 or 2) end,
            function(idx) 
                _G.MemoryConfig.RemoveTrees = (idx == 1) 
                ApplyMemoryFeature("Trees", _G.MemoryConfig.RemoveTrees)
            end
        ),
        MakeSwitcher("mem_fog", LOC.BTN_MEM_FOG,
            function() return (_G.MemoryConfig.RemoveFog and 1 or 2) end,
            function(idx) 
                _G.MemoryConfig.RemoveFog = (idx == 1) 
                ApplyMemoryFeature("Fog", _G.MemoryConfig.RemoveFog)
            end
        ),
        MakeSwitcher("mem_blacksky", LOC.BTN_MEM_BLACKSKY,
            function() return (_G.MemoryConfig.BlackSky and 1 or 2) end,
            function(idx) 
                _G.MemoryConfig.BlackSky = (idx == 1) 
                ApplyMemoryFeature("BlackSky", _G.MemoryConfig.BlackSky)
            end
        ),
        MakeSwitcher("mem_fps", LOC.BTN_MEM_FPS,
            function() return (_G.MemoryConfig.UnlockFPS and 1 or 2) end,
            function(idx) 
                _G.MemoryConfig.UnlockFPS = (idx == 1) 
                ApplyMemoryFeature("FPS", _G.MemoryConfig.UnlockFPS)
            end
        ),
        MakeSwitcher("mem_crosshair", LOC.BTN_MEM_CROSSHAIR,
            function() return (_G.MemoryConfig.SmallCrosshair and 1 or 2) end,
            function(idx) _G.MemoryConfig.SmallCrosshair = (idx == 1) end
        ),
        MakeSwitcher("mem_ipad", LOC.BTN_MEM_IPAD,
            function() return (_G.MemoryConfig.IpadView and 1 or 2) end,
            function(idx) _G.MemoryConfig.IpadView = (idx == 1) end
        ),
        MakeSlider("mem_ipad_fov", LOC.BTN_MEM_IPAD_FOV, 60, 160,
            function() return _G.MemoryConfig.IpadFOV or 120 end,
            function(val) _G.MemoryConfig.IpadFOV = val end
        ),
        MakeSwitcher("mem_smallscope", LOC.BTN_MEM_SMALLSCOPE,
            function() return (_G.MemoryConfig.SmallScope and 1 or 2) end,
            function(idx) _G.MemoryConfig.SmallScope = (idx == 1) end
        ),
        MakeSlider("mem_smallscope_fov", LOC.BTN_MEM_SMALLSCOPE_FOV, 40, 120,
            function() return _G.MemoryConfig.SmallScopeFOV or 75 end,
            function(val) _G.MemoryConfig.SmallScopeFOV = val end
        ),
        }

        local tabEspSection = {
        MakeSwitcher("esp_enable", LOC.BTN_ESP_ENABLE,
            function() return (_G.PlayerMapMarker and _G.PlayerMapMarker.bActive) and 1 or 2 end,
            function(idx)
                if _G.PlayerMapMarker then
                    if idx == 1 then _G.PlayerMapMarker.Start() else _G.PlayerMapMarker.Stop() end
                end
                if _G.RedBoxOverlay then
                    if idx == 1 then _G.RedBoxOverlay.Start() else _G.RedBoxOverlay.Stop() end
                end
            end
        ),
        MakeSwitcher("chams_enable", LOC.BTN_CHAMS_ENABLE,
            function() return (_G.BRChamsConfig and _G.BRChamsConfig.Enable) and 1 or 2 end,
            function(idx)
                _G.BRChamsConfig.Enable = (idx == 1)
                if idx == 1 then _G.BRStartChams() else _G.BRStopChams() end
            end
        ),
        MakeSlider("chams_vis", LOC.BTN_CHAMS_VIS, 1, 6,
            function() return (_G.BRChamsConfig and _G.BRChamsConfig.VisColor) or 3 end,
            function(val) if _G.BRChamsConfig then _G.BRChamsConfig.VisColor = math.floor(val) end end
        ),
        MakeSlider("chams_occ", LOC.BTN_CHAMS_OCC, 1, 6,
            function() return (_G.BRChamsConfig and _G.BRChamsConfig.OccColor) or 1 end,
            function(val) if _G.BRChamsConfig then _G.BRChamsConfig.OccColor = math.floor(val) end end
        ),
        MakeSwitcher("new_wallhack", LOC.BTN_NEW_WALLHACK,
            function() return (_G.PBCWallhackConfig and _G.PBCWallhackConfig.Enable) and 1 or 2 end,
            function(idx)
                if not _G.PBCWallhackConfig then _G.PBCWallhackConfig = {} end
                _G.PBCWallhackConfig.Enable = (idx == 1)
                if idx == 1 then _G.PBCStartWallhack() else _G.PBCStopWallhack() end
            end
        ),
        MakeSlider("new_wh_vis", LOC.BTN_NEW_WH_VIS, 1, 7,
            function() return (_G.PBCWallhackConfig and _G.PBCWallhackConfig.VisColor) or 1 end,
            function(val) if _G.PBCWallhackConfig then _G.PBCWallhackConfig.VisColor = math.floor(val) end end
        ),
        MakeSlider("new_wh_occ", LOC.BTN_NEW_WH_OCC, 1, 7,
            function() return (_G.PBCWallhackConfig and _G.PBCWallhackConfig.OccColor) or 4 end,
            function(val) if _G.PBCWallhackConfig then _G.PBCWallhackConfig.OccColor = math.floor(val) end end
        ),
        MakeSwitcher("blue_frame", LOC.BTN_BLUE_FRAME,
            function() return (_G.BlueFrameConfig and _G.BlueFrameConfig.Enable) and 1 or 2 end,
            function(idx)
                if not _G.BlueFrameConfig then _G.BlueFrameConfig = {} end
                _G.BlueFrameConfig.Enable = (idx == 1)
                if idx == 1 then _G.BlueFrameStart() else _G.BlueFrameStop() end
            end
        ),
        MakeSwitcher("esp_lines", LOC.BTN_ESP_LINES,
            function() return (_G.PlayerMapMarker and _G.PlayerMapMarker.bUseSnapLines) and 1 or 2 end,
            function(idx)
                if _G.PlayerMapMarker then
                    _G.PlayerMapMarker.bUseSnapLines = (idx == 1)
                end
            end
        ),
        MakeSwitcher("esp_fov_circle", LOC.BTN_ESP_FOV_CIRCLE,
            function() return (_G.PlayerMapMarker and _G.PlayerMapMarker.bUseFOVCircle) and 1 or 2 end,
            function(idx)
                if _G.PlayerMapMarker then
                    _G.PlayerMapMarker.bUseFOVCircle = (idx == 1)
                    if idx == 2 then _G.PlayerMapMarker.RemoveFOVCircle() end
                end
            end
        ),
        MakeSwitcher("esp_arrows", LOC.BTN_ESP_ARROWS,
            function() return (_G.PlayerMapMarker and _G.PlayerMapMarker.bUseArrows) and 1 or 2 end,
            function(idx)
                if _G.PlayerMapMarker then
                    _G.PlayerMapMarker.bUseArrows = (idx == 1)
                    if idx == 2 then _G.PlayerMapMarker.ClearAllArrows() end
                end
            end
        ),
        MakeSwitcher("esp_box", LOC.BTN_ESP_BOX,
            function() return (_G.PlayerMapMarker and _G.PlayerMapMarker.bUseBoxESP) and 1 or 2 end,
            function(idx)
                if _G.PlayerMapMarker then
                    _G.PlayerMapMarker.bUseBoxESP = (idx == 1)
                    if idx == 2 then _G.PlayerMapMarker.ClearAllBoxes() end
                end
            end
        ),
        MakeSwitcher("fake_hwid", LOC.BTN_FAKE_HWID,
            function() return (_G.BRFakeHWID and _G.BRFakeHWID.Enable) and 1 or 2 end,
            function(idx)
                _G.BRFakeHWID.Enable = (idx == 1)
                if _G.BRFakeHWID.Enable then
                    _G.FakeHWID_String = nil
                end
                BRFakeHWID_Notify("Fake HWID " .. (_G.BRFakeHWID.Enable and "ON" or "OFF"))
            end
        )
        }

        local tabBanSection = {
        MakeSwitcher("car_fly", LOC.BTN_CAR_FLY,
            function() return (_G.CarFlyConfig and _G.CarFlyConfig.Enable) and 1 or 2 end,
            function(idx)
                if not _G.CarFlyConfig then _G.CarFlyConfig = {} end
                _G.CarFlyConfig.Enable = (idx == 1)
                if _G.CarFlyConfig.Enable then
                    _G.CarFlyConfig.Start()
                else
                    _G.CarFlyConfig.Stop()
                end
            end
        ),
        MakeSlider("car_fly_speed", LOC.BTN_CAR_FLY_SPEED, 1, 5,
            function() return _G.CarFlyConfig and _G.CarFlyConfig.FlySpeed or 1 end,
            function(val) 
                if not _G.CarFlyConfig then _G.CarFlyConfig = {} end
                _G.CarFlyConfig.FlySpeed = val 
            end
        ),
        MakeSwitcher("fast_car", LOC.BTN_FAST_CAR,
            function() return (_G.FastCarEnabled) and 1 or 2 end,
            function(idx)
                if idx == 1 then
                    _G.StartFastCar()
                else
                    _G.StopFastCar()
                end
            end
        ),
        MakeSwitcher("auto_report", "Auto Report Enemies",
            function() return (_G.AutoReportConfig and _G.AutoReportConfig.Enable) and 1 or 2 end,
            function(idx)
                if not _G.AutoReportConfig then _G.AutoReportConfig = {} end
                _G.AutoReportConfig.Enable = (idx == 1)
                if idx == 1 then
                    _G.AutoReportConfig._reportedPlayers = {}
                    _G.AutoReportConfig._lastReportTime = 0
                    _G._AutoReportSSSent = false
                end
            end
        ),
        MakeSwitcher("auto_report_ss", "Auto Screenshot at #1",
            function() return (_G.AutoReportConfig and _G.AutoReportConfig.AutoScreenshot) and 1 or 2 end,
            function(idx) if _G.AutoReportConfig then _G.AutoReportConfig.AutoScreenshot = (idx == 1) end end
        ),
        MakeSlider("auto_report_reason", "Report Reason (1Cheat 2Hack 3Abuse 4Grief 5TK)", 1, 5,
            function() return _G.AutoReportConfig and _G.AutoReportConfig.ReportReason or 1 end,
            function(val) if _G.AutoReportConfig then _G.AutoReportConfig.ReportReason = math.floor(val) end end
        ),
        MakeSlider("auto_report_delay", "Report Delay (sec)", 1, 10,
            function() return _G.AutoReportConfig and _G.AutoReportConfig.ReportDelay or 3 end,
            function(val) if _G.AutoReportConfig then _G.AutoReportConfig.ReportDelay = val end end
        ),
        }

        local tabSkinSection = {
        MakeSwitcher("skin_mod", "MOD SKIN ON/OFF",
            function() return (_G.LexusConfig and _G.LexusConfig.ModSkin) and 1 or 2 end,
            function(idx)
                if not _G.LexusConfig then _G.LexusConfig = {} end
                _G.LexusConfig.ModSkin = (idx == 1)
                if _G.BRStartSkinLoop then _G.BRStartSkinLoop() end
            end
        ),
        skinSlider("skin_suit", "Suit Skin", 1, 80, "SkinSuit", "OutfitSkins", "Suit"),
        skinSlider("skin_bag", "Bag Skin", 1, 15, "SkinBag", "OutfitSkins", "Bag"),
        skinSlider("skin_helmet", "Helmet Skin", 1, 11, "SkinHelmet", "OutfitSkins", "Helmet"),
        skinSlider("skin_m416", "M416 Skin", 1, 8, "SkinM416", "skinIdMappings", 101004),
        skinSlider("skin_akm", "AKM Skin", 1, 8, "SkinAKM", "skinIdMappings", 101001),
        skinSlider("skin_scar", "SCAR Skin", 1, 8, "SkinSCAR", "skinIdMappings", 101003),
        skinSlider("skin_m762", "M762 Skin", 1, 8, "SkinM762", "skinIdMappings", 101008),
        skinSlider("skin_aug", "AUG Skin", 1, 7, "SkinAUG", "skinIdMappings", 101006),
        skinSlider("skin_ump", "UMP Skin", 1, 5, "SkinUMP", "skinIdMappings", 102002),
        skinSlider("skin_uzi", "UZI Skin", 1, 2, "SkinUZI", "skinIdMappings", 102001),
        skinSlider("skin_groza", "Groza Skin", 1, 2, "SkinGroza", "skinIdMappings", 101005),
        skinSlider("skin_s12k", "S12K Skin", 1, 2, "SkinS12K", "skinIdMappings", 104003),
        skinSlider("skin_dbs", "DBS Skin", 1, 3, "SkinDBS", "skinIdMappings", 104004),
        skinSlider("skin_asm", "ASM Gen8 Skin", 1, 2, "SkinASM", "skinIdMappings", 101101),
        skinSlider("skin_qbz", "QBZ Skin", 1, 2, "SkinQBZ", "skinIdMappings", 101007),
        skinSlider("skin_honey", "Honey Badger Skin", 1, 2, "SkinHoney", "skinIdMappings", 101012),
        skinSlider("skin_m16a4", "M16A4 Skin", 1, 2, "SkinM16A4", "skinIdMappings", 101002),
        skinSlider("skin_ace32", "ACE32 Skin", 1, 2, "SkinACE32", "skinIdMappings", 101102),
        skinSlider("skin_kar98k", "Kar98k Skin", 1, 2, "SkinKar98k", "skinIdMappings", 103001),
        skinSlider("skin_m24", "M24 Skin", 1, 2, "SkinM24", "skinIdMappings", 103002),
        skinSlider("skin_awm", "AWM Skin", 1, 2, "SkinAWM", "skinIdMappings", 103003),
        skinSlider("skin_dacia", "Dacia Skin", 1, 34, "SkinDacia", "VehicleSkins", 1903001),
        skinSlider("skin_uaz", "UAZ Skin", 1, 16, "SkinUAZ", "VehicleSkins", 1908001),
        skinSlider("skin_coupe", "Coupe Skin", 1, 55, "SkinCoupe", "VehicleSkins", 1961001),
        skinSlider("skin_buggy", "Buggy Skin", 1, 11, "SkinBuggy", "VehicleSkins", 1907002),
        skinSlider("skin_mirado", "Mirado Skin", 1, 5, "SkinMirado", "VehicleSkins", 1915004),
        MakeSwitcher("skin_deadbox", "DeadBox Skin",
            function() return (_G.LexusConfig and _G.LexusConfig.SkinDeadBox) and 1 or 2 end,
            function(idx) if not _G.LexusConfig then _G.LexusConfig = {} end _G.LexusConfig.SkinDeadBox = (idx == 1) end
        ),
        MakeSwitcher("skin_attach", "Attachment Skin",
            function() return (_G.LexusConfig and _G.LexusConfig.SkinAttachment) and 1 or 2 end,
            function(idx) if not _G.LexusConfig then _G.LexusConfig = {} end _G.LexusConfig.SkinAttachment = (idx == 1) end
        )
        }

        MY_TAB_DEFINE.Category = {
        {
            Key   = "MyTab_TAB1",
            Text  = LOC.TAB_AIMBOT,
            UIKey = "Setting_Page_Game",
            Stack = MakeStack({
            { title = LOC.TITLE_AIMING,   items = tab1Section1 },
            { title = LOC.TITLE_SETTINGS, items = tab1Section2 },
            }),
        },
        {
            Key   = "MyTab_TAB2",
            Text  = LOC.TAB_MEMORY,
            UIKey = "Setting_Page_Game",
            Stack = MakeStack({
            { title = LOC.TITLE_SETTINGS, items = tab2Section1 },
            { title = LOC.TITLE_ESP,     items = tabEspSection },
            }),
        },
        {
            Key   = "MyTab_TAB3",
            Text  = LOC.TAB_SKIN,
            UIKey = "Setting_Page_Game",
            Stack = MakeStack({
            { title = LOC.TITLE_SKIN, items = tabSkinSection },
            }),
        },
        {
            Key   = "MyTab_TAB4",
            Text  = LOC.TAB_BAN,
            UIKey = "Setting_Page_Game",
            Stack = MakeStack({
            { title = LOC.TAB_BAN, items = tabBanSection },
            }),
        },
        }

        LOG("GetMyTabDefine: built successfully.")
        return MY_TAB_DEFINE
    end

    local function HasMyTab(catalog)
        if type(catalog) ~= "table" then return false end
        for _, item in ipairs(catalog) do
        if type(item) == "table" and item.Key == "MyTab" then return true end
        end
        return false
    end

    local function InjectMyTab(catalog)
        if type(catalog) ~= "table" then return end
        if HasMyTab(catalog) then return end
        GetMyTabDefine()
        table.insert(catalog, 1, MY_TAB_DEFINE)
        LOG("InjectMyTab: inserted at position 1")
    end

    if type(UIManager) == "table" and type(UIManager.ShowUI) == "function" then
        if UIManager.__mytab_ShowUI then
        UIManager.ShowUI = UIManager.__mytab_ShowUI
        UIManager.__mytab_ShowUI = nil
        end
        UIManager.__mytab_ShowUI = UIManager.ShowUI
        
        UIManager.ShowUI = function(...)
        local uiKey = select(1, ...)
        local arg1 = uiKey
        local args_start = 1
        if type(arg1) == "table" and arg1 == UIManager then
            uiKey = select(2, ...)
            args_start = 2
        end
        
        local cfg = UIManager.UI_Config
        if cfg and uiKey == cfg.setting_main then
            local catArg = select(args_start + 1, ...)
            if type(catArg) == "table" then InjectMyTab(catArg) end
        end
        return UIManager.__mytab_ShowUI(...)
        end
        LOG("UIManager.ShowUI hooked")
    end

    local SettingMainPath = "client.slua.umg.NewSetting.Main.setting_main_base"
    local okSM, SettingMain = pcall(require, SettingMainPath)
    if okSM and SettingMain then
        if SettingMain.__mytab_OnSelectTab_Page then
        SettingMain.OnSelectTab_Page = SettingMain.__mytab_OnSelectTab_Page
        SettingMain.__mytab_OnSelectTab_Page = nil
        end
        SettingMain.__mytab_OnSelectTab_Page = SettingMain.OnSelectTab_Page
        SettingMain.OnSelectTab_Page = function(self, ItemIndex)
        local pageData = self.AvailablePageList and self.AvailablePageList[ItemIndex]
        if pageData and pageData.Key == "MyTab" then
            if self._PageUI then
            pcall(function() self._PageUI:CloseSelf() end)
            self._PageUI = nil
            end
            if self._CategoryUI then
            pcall(function() self._CategoryUI:CloseSelf() end)
            self._CategoryUI = nil
            end

            local def = GetMyTabDefine()
            if not def.Category then return end

            self._CurrentPage = pageData
            self._AvailableCategoryList = def.Category

            -- Try to ensure enough tab buttons exist
            pcall(function()
                local catCount = #def.Category
                self.UIRoot.HorizontalSelector_Category:SetNum(catCount)
            end)
            for i, catData in ipairs(def.Category) do
            pcall(function()
                local Child = self.UIRoot.HorizontalSelector_Category:GetChildAt(i - 1)
                if Child and slua.isValid(Child) and Child.TextBlock_Name then
                    Child.TextBlock_Name:SetText(ResolveLoc(catData.Text) or tostring(catData.Text))
                end
            end)
            end

            self:SetWidgetVisible(self.UIRoot.Border_Header, true)
            pcall(function()
            self:PlayUserWidgetAnimation(self.UIRoot.Fadein_Page, 0, 1, 0, 1)
            end)

            self.UIRoot.HorizontalSelector_Category:SetSelectedIndex(-1)
            self.UIRoot.HorizontalSelector_Category:SetSelectedIndex(1)
            return true
        end
        return SettingMain.__mytab_OnSelectTab_Page(self, ItemIndex)
        end
        LOG("OnSelectTab_Page hooked")

        if SettingMain.__mytab_OnSelectTab_Category then
        SettingMain.OnSelectTab_Category = SettingMain.__mytab_OnSelectTab_Category
        SettingMain.__mytab_OnSelectTab_Category = nil
        end
        SettingMain.__mytab_OnSelectTab_Category = SettingMain.OnSelectTab_Category
        SettingMain.OnSelectTab_Category = function(self, ItemIndex)
        local curPage = self._CurrentPage
        if curPage and curPage.Key == "MyTab" then
            local lastIndex = self.UIRoot.HorizontalSelector_Category:GetSelectedIndex()
            if lastIndex > 0 and self._CategoryUI then
            pcall(function() self._CategoryUI:CloseSelf() end)
            self._CategoryUI = nil
            end

            local catData = self._AvailableCategoryList and self._AvailableCategoryList[ItemIndex]
            if catData then
            if catData.UIKey and catData.Stack then
                self._CategoryUI = self:CreateChildWindow(
                self.UIRoot.StackRoot,
                UIManager.UI_Config[catData.UIKey],
                catData.Stack
                )
            elseif catData.Stack then
                self._CategoryUI = self:CreateChildWindow(
                self.UIRoot.StackRoot,
                UIManager.UI_Config.Setting_StackContainer,
                catData.Stack
                )
            end
            end

            pcall(function()
            self:PlayUserWidgetAnimation(self.UIRoot.Fadein_Category, 0, 1, 0, 1)
            end)
            return true
        end
        return SettingMain.__mytab_OnSelectTab_Category(self, ItemIndex)
        end
        LOG("OnSelectTab_Category hooked")
    end

    if type(UIManager) == "table" and type(UIManager.HideUI) == "function" then
        if UIManager.__mytab_HideUI then
        UIManager.HideUI = UIManager.__mytab_HideUI
        UIManager.__mytab_HideUI = nil
        end
        UIManager.__mytab_HideUI = UIManager.HideUI
        UIManager.HideUI = function(...)
        local uiKey = select(1, ...)
        local arg1 = uiKey
        local args_start = 1
        if type(arg1) == "table" and arg1 == UIManager then
            uiKey = select(2, ...)
            args_start = 2
        end
        
        local cfg = UIManager.UI_Config
        if cfg and uiKey == cfg.setting_main then
            local ui = UIManager.GetUI and UIManager.GetUI(cfg.setting_main)
            if ui then ui.__mytabInstalled = nil end
        end
        return UIManager.__mytab_HideUI(...)
        end
    end

    LOG("Zn Menu v" .. MY_TAB_VER .. " globally installed.")
    end

    -- Auto-restart features that were enabled in previous match
    -- (timers die when old PlayerController is destroyed between matches)
    -- Must be OUTSIDE __MyTabInstalled block so it runs every script load
    pcall(function()
        if _G.BRChamsConfig and _G.BRChamsConfig.Enable then
            _G._chamsTimer = nil  -- Force clear dead timer reference
            if _G.BRStopChams then _G.BRStopChams() end
            _G.BRStartChams()
        end
    end)
    pcall(function()
        if _G.PBCWallhackConfig and _G.PBCWallhackConfig.Enable then
            if _G.PBCStopWallhack then _G.PBCStopWallhack() end
            _G.PBCStartWallhack()
        end
    end)
    pcall(function()
        if _G.BlueFrameConfig and _G.BlueFrameConfig.Enable then
            if _G.BlueFrameStop then _G.BlueFrameStop() end
            _G.BlueFrameStart()
        end
    end)
    pcall(function()
        if _G.CarFlyConfig and _G.CarFlyConfig.Enable then
            if _G.CarFlyConfig.Stop then _G.CarFlyConfig.Stop() end
            _G.CarFlyConfig.Start()
        end
    end)
    pcall(function()
        if _G.FastCarEnabled then
            if _G.StopFastCar then _G.StopFastCar() end
            _G.StartFastCar()
        end
    end)
    pcall(function()
        if _G.RefreshAllMemoryFeatures then
            _G.RefreshAllMemoryFeatures()
        end
    end)
    pcall(function()
        if _G.PlayerMapMarker and _G.PlayerMapMarker.bActive then
            if _G.RedBoxOverlay and _G.RedBoxOverlay.Start then
                _G.RedBoxOverlay.Start()
            end
        end
    end)

    -- ============================================================
    -- LIBANOGS BAN HOOK - Anti-Detection bypass
    -- ============================================================
    do
        local _libanogs_OrigBan = nil
        local function InitBanHook()
            pcall(function()
                local KSL = import("KismetSystemLibrary")
                if not KSL then return end
                local world = slua.getWorld()
                if not world then return end

                KSL.ExecuteConsoleCommand(world, "LoadLibrary libanogs.so")

                local libanogs = nil
                pcall(function() libanogs = slua.loadLibrary("libanogs.so") end)
                if not libanogs then
                    pcall(function() libanogs = import("libanogs.so") end)
                end

                if not libanogs then
                    LOG("[BanHook] libanogs.so not available, trying string scan")
                end

                _G._BanHookActive = true
                _G._OrigBanString = nil

                local function CheckBanString(s)
                    if type(s) ~= "string" then return s end
                    if string.find(s, "Anti%-Detection") or string.find(s, "10 Years") then
                        LOG("[BanHook] Ban string detected: " .. string.sub(s, 1, 50))
                        local safeStr = "Data/file/%%"
                        _G._OrigBanString = s
                        return safeStr
                    end
                    return s
                end
                _G.CheckBanString = CheckBanString

                if libanogs then
                    local banFuncNames = {"Ban", "BanPlayer", "BanUser", "ReportBan"}
                    for _, fname in ipairs(banFuncNames) do
                        if libanogs[fname] and type(libanogs[fname]) == "function" then
                            local orig = libanogs[fname]
                            libanogs[fname] = function(...)
                                local args = {...}
                                for i, arg in ipairs(args) do
                                    if type(arg) == "string" then
                                        args[i] = CheckBanString(arg)
                                    end
                                end
                                return orig(table.unpack(args))
                            end
                            LOG("[BanHook] Hooked " .. fname .. " in libanogs.so")
                        end
                    end
                end

                if KSL.GetDeviceId then
                    local origDeviceId = KSL.GetDeviceId
                    KSL.GetDeviceId = function(...)
                        local result = origDeviceId(...)
                        if _G.BRFakeHWID and _G.BRFakeHWID.Enable then
                            if not _G.FakeHWID_String then
                                local chars = "0123456789ABCDEF"
                                local hwid = ""
                                for i = 1, 32 do
                                    local idx = math.random(1, #chars)
                                    hwid = hwid .. chars:sub(idx, idx)
                                    if i == 8 or i == 12 or i == 16 or i == 20 then hwid = hwid .. "-" end
                                end
                                _G.FakeHWID_String = hwid
                            end
                            return _G.FakeHWID_String
                        end
                        return result
                    end
                    LOG("[BanHook] DeviceId hook active")
                end

                if KSL.GetDeviceIdOS then
                    local origDeviceIdOS = KSL.GetDeviceIdOS
                    KSL.GetDeviceIdOS = function(...)
                        local result = origDeviceIdOS(...)
                        if _G.BRFakeHWID and _G.BRFakeHWID.Enable then
                            if not _G.FakeHWID_String then
                                local chars = "0123456789ABCDEF"
                                local hwid = ""
                                for i = 1, 32 do
                                    local idx = math.random(1, #chars)
                                    hwid = hwid .. chars:sub(idx, idx)
                                    if i == 8 or i == 12 or i == 16 or i == 20 then hwid = hwid .. "-" end
                                end
                                _G.FakeHWID_String = hwid
                            end
                            return _G.FakeHWID_String
                        end
                        return result
                    end
                    LOG("[BanHook] DeviceIdOS hook active")
                end

                LOG("[BanHook] Anti-Detection bypass active")
            end)
        end

        pcall(InitBanHook)
    end

    -- ============================================
    -- BRPLAYERCHARACTERBASE CLASS & GAME INTEGRATION
    -- ============================================

    -- ============================================================
    -- NATIVE C++ PROCESS EVENT HOOK (bypass ke sath merge)
    -- ============================================================
    --[[
    void *(*oProcessEvent)(UObject *pObj, UFunction *pFunc, void *pArgs);

    void *hkProcessEvent(UObject *pObj, UFunction *pFunc, void *pArgs) {
        const char *EngineHUD = ("Function Engine.HUD.ReceiveDrawHUD");
        if (pFunc) {
            if (pFunc->GetFullName() == EngineHUD) {
                AHUD *pHUD = (AHUD *) pObj;
                if (pHUD) {
                    auto Params = (AHUD_ReceiveDrawHUD_Params *) pArgs;
                    if (Params) {
                        RenderESPPRIVATE(pHUD, Params->SizeX, Params->SizeY);
                        DrawHUD(pHUD);
                    }
                }
            }
        }
        return oProcessEvent(pObj, pFunc, pArgs);
    }

    void initOffset() {
        ProcessEvent = (Cheat::libUE4Base + 0x9FA1C34);
        if (ProcessEvent) {
            HOOK_LIB("libUE4.so", "0x9ae522c", hkProcessEvent, oProcessEvent);
        }
    }
    ]]

end

-- Self Invoke (Script ko start karne ke liye)
if not _G.guruSelfStarted then
    _G.guruSelfStarted = true
    if type(_G.StartAdvancedSystems) == "function" then
        local ok, err = pcall(_G.StartAdvancedSystems)
        if not ok then print("[ZN] start error:", tostring(err)) end
    end
end

local class = require("class")
local CCharacterBase = require("GameLua.GameCore.Framework.CharacterBase")
local CBRPlayerCharacterBase = class(CCharacterBase, nil, BRPlayerCharacterBase)
pcall(function()
    local IPS = require("GameLua.Mod.Library.Client.UI.IngamePhoneStateUI")
    if IPS and IPS.__inner_impl then
        local o = IPS.__inner_impl.UpdateArtQualityUI
        IPS.__inner_impl.UpdateArtQualityUI = function(self, _, _)
            if self.UIRoot and self.UIRoot.TextBlock_quality then
                local _FSlateColor = import("SlateColor") or import("/Script/SlateCore.SlateColor")
                local _FLinearColor = import("LinearColor")
                self.UIRoot.TextBlock_quality:SetText("  ♕ديــــمــــن♕  ")
                self.UIRoot.TextBlock_quality:SetColorAndOpacity(_FSlateColor(_FLinearColor(1, 1, 0, 1)))
            end
        end
    end
end)

return require("combine_class").DeclareFeature(CBRPlayerCharacterBase, {
  {
    SkyTransition = "GameLua.Mod.BaseMod.Gameplay.Feature.SkyControl.PlayerCharacterSkyTransitionFeature"
  },
  {
    CarryDeadBoxFeature = "GameLua.Mod.Library.GamePlay.Feature.CarryDeadBoxFeature"
  },
  {
    SpecialSuitFeature = "GameLua.Mod.Library.GamePlay.Feature.SpecialSuitFeature"
  },
  {
    TeleportPawnFeature = "GameLua.Mod.Library.GamePlay.Feature.TeleportPawnFeature"
  },
  {
    LifterControl = "GameLua.Mod.BaseMod.Gameplay.Feature.Player.CharacterLifterControlFeature"
  },
  {
    FinalKillEffect = "GameLua.Mod.BaseMod.Gameplay.Feature.Player.PlayerCharacterFinalKillEffectFeature"
  },
  {
    CampFeature = "GameLua.Mod.BaseMod.GamePlay.Feature.Camp.PlayerCharacterCampFeature"
  },
  {
    BuildAircraftVehicleFeature = "GameLua.Mod.BaseMod.GamePlay.Feature.PlayerCharacterBuildVehicleFeature"
  },
  {
    UnifiedBuildVehicleFeature = "GameLua.Mod.BaseMod.GamePlay.Feature.UnifiedBuildVehicleFeature"
  },
  {
    CommonBornlandTransformFeature = "GameLua.Mod.BaseMod.GamePlay.Feature.HeroPropFeature.CommonBornlandTransformFeature"
  },
  {
    ParachuteFormation = "GameLua.Mod.BaseMod.GamePlay.Feature.ParachuteFormationFeature"
  },
  {
    ParachuteSprint = "GameLua.Mod.BaseMod.GamePlay.Feature.Parachute.ParachuteSprintFeature"
  },
  {
    GeneralShowSpotFeature = "GameLua.Mod.BRMod.Gameplay.Feature.PlayerCharacterGeneralShowSpotFeature"
  },
  {
    FPPAnimMonitor = "GameLua.Mod.BaseMod.GamePlay.Feature.Player.FPPAnimMonitorFeature"
  }
}, "BRPlayerCharacterBase")
