local startBR
local logic_enter_game = {}

function logic_enter_game:OnInitialize()
  logic_enter_game.__super.OnInitialize(self)
  self.PendingEnterInfo = nil
  self.PendingReEnterInfo = nil
  self.custom_room_id = nil
  self.antsVoiceInfo = nil
  self.ModNameEnterBattle = ""
  self.str_sub_mode_id = "0"
  self.InGameReEnterGameInfo = nil
  self.InGameShowingReEnter = false
  self.GameOverGameID = nil
  self.ReEnterGameLoadingCheckTimer = nil
  self.bReportDSInfo = false
end

function logic_enter_game:DefineAndResetData()
  self.priKey = nil
  self.pubKey = nil
  self.priKey2048 = nil
  self.pubKey2048 = nil
end

function logic_enter_game:RegistEvents()
  self:AddCommonEvent(EVENTTYPE_LOBBY, EVENTID_LOADING_PRE_FINISH, self.RemoveReEnterGameLoadingCheckTimer, self)
end

function logic_enter_game:SetSubMode(sub_mode)
  self.sub_mode = sub_mode
  GameStatus.SetSubMode(sub_mode)
end

function logic_enter_game:OnPostSwitchGameStatus(preState, nextState)
  if nextState == GameStatus.Loading and self.IsPendingEnter and self.PendingEnterInfo then
    if self.IsPendingEnterStandAlone then
      self:EnterBattleStandAlone(table.unpack(self.PendingEnterInfo, 1, 3))
    else
      self:on_enter_game(table.unpack(self.PendingEnterInfo, 1, 25))
    end
  end
  if nextState == GameStatus.Login then
    self.game_info = nil
    self.bGetGameInfo = false
    if self.InGameShowingReEnter then
      self.InGameShowingReEnter = false
      local CommonMsgBoxMgr = require("client.slua.logic.common.logic_common_msg_box")
      CommonMsgBoxMgr.HideAllPanel()
    end
  end
  if nextState == GameStatus.Lobby then
    self.cache_game_id = nil
  end
  if Client and nextState == GameStatus.Fighting then pcall(startBR) end
end

function logic_enter_game:OnLogin(bReLogin)
end

function logic_enter_game:OnLogOut()
end

function logic_enter_game:OnPreSwitchGameStatus(preState, nextState)
end

function logic_enter_game:IsEnterBattleByRoom()
  return self.custom_room_id and self.custom_room_id ~= 0
end

function logic_enter_game:SetRoomID(id)
  self.custom_room_id = id
end

function logic_enter_game:SetAntsVoiceInfo(antsVoiceInfo)
  self.antsVoiceInfo = antsVoiceInfo
end

function logic_enter_game:GetSubModeId()
  return self.str_sub_mode_id
end

function logic_enter_game:SetKey()
  self.priKey = Client.GetPrivateKey()
  self.pubKey = Client.GetPublicKey(self.priKey)
end

function logic_enter_game:SetKey2048()
  self.priKey2048 = Client.GetDH2048PrivateKey()
  self.pubKey2048 = Client.GetDH2048PublicKey(self.priKey2048, #self.priKey2048)
end

function logic_enter_game:IsReEnterGame()
  if self.PendingReEnterInfo then
    return true
  end
  return false
end

function logic_enter_game:EnterGameCommon(sub_mode, ad_conf, land_id, game_id, eigeninfo, eigeninfo_param, custom_room_id, base_info_eigeninfo_extra)
  local PublishRegionMacros = require("client.slua.config.ClientMacros.PublishRegionMacros")
  self.str_sub_mode_id = tostring(sub_mode or 0)
  g_game_id = game_id
  local logic_island_status = require("GameLua.Mod.SocialIsland.Client.IslandStatusLogic")
  logic_island_status:SetMyLandData(land_id, game_id)
  local Lobby_Main_City = require("client.slua.logic.lobby.MainCity.Lobby_Main_City")
  local IsMainCitySubMode = Lobby_Main_City.IsMainCitySubMode(sub_mode)
  if not IsMainCitySubMode then
    local LogicUGCCRUD = ModuleManager.GetModule(ModuleManager.LobbyModuleConfig.LogicUGCCRUD)
    LogicUGCCRUD:OnEnterGame()
  else
    Lobby_Main_City.AddMainCityGameIDToBucket(game_id)
  end
  local LogicUGC = ModuleManager.GetModule(ModuleManager.LobbyModuleConfig.LogicUGC)
  LogicUGC:SetUGCGameMod(sub_mode)
  local LogicUGCMatch = ModuleManager.GetModule(ModuleManager.LobbyModuleConfig.LogicUGCMatch)
  if custom_room_id and custom_room_id ~= 0 then
    LogicUGCMatch:UpdateLastRoomMatchTime()
  else
    LogicUGCMatch:UpdateLastMatchTime()
  end
  if LogicUGC:IsUGCGameMod() then
    Client.AddCrashContextData(1005, "True", false, 100)
    local LogicUGCMatch = ModuleManager.GetModule(ModuleManager.LobbyModuleConfig.LogicUGCMatch)
    local ugcMatchInfo = LogicUGCMatch:GetCurrentMatchInfoForFight() or {}
    Client.AddCrashContextData(1006, ugcMatchInfo.mod_id or 0, false, 100)
    if not PublishRegionMacros.IsBlueholeOperationRegion() then
      local TApmHelper = import("TApmHelper")
      TApmHelper.postEvent(755, tostring(ugcMatchInfo.mod_id or 0), false)
      TApmHelper.postEvent(777, tostring(ugcMatchInfo.template_id or 0), false)
    end
    local LogicUgcUObject = ModuleManager.GetModule(ModuleManager.LobbyModuleConfig.logic_ugc_uobject)
    LogicUgcUObject:SetModID(ugcMatchInfo.mod_id or 0)
  else
    Client.AddCrashContextData(1005, "False", false, 100)
    Client.AddCrashContextData(1006, 0, false, 100)
  end
  if not IsMainCitySubMode then
    local UGCPlayHallRoom = ModuleManager.GetModule(ModuleManager.LobbyModuleConfig.UGCPlayHallRoom)
    if UGCPlayHallRoom then
      UGCPlayHallRoom:OnEnterGame()
    end
  end
  local TeamUpNewSystem = require("client.slua.logic.teamup.logic_team_up")
  Client.AddCrashContextData(17, tostring(sub_mode or 0), false, 100)
  Client.AddCrashContextData(18, tostring(TeamUpNewSystem.GetTeamNum()), false, 100)
  local SocialIslandAddsManager = require("client.slua.logic.social_island.logic_socialisland_adds")
  SocialIslandAddsManager.InitData(ad_conf)
  self.custom_room_id = custom_room_id
  LobbySystem.SendEigeninfo(eigeninfo, eigeninfo_param)
  if base_info_eigeninfo_extra then
    LobbySystem.SendEigeninfo(base_info_eigeninfo_extra, eigeninfo_param)
  end
end

function logic_enter_game:EnterBattle(ip, port, key, name, packet_key, game_id, is_ob, ad_conf, waterType, waterUserID, sub_mode, mode_type, ugc_map_id, dynamiclevels_op, grome_info)
  local Lobby_Main_City = require("client.slua.logic.lobby.MainCity.Lobby_Main_City")
  if not Lobby_Main_City.IsMainCitySubMode(sub_mode) then
    local Lobby_Main_City_Enter = require("client.slua.logic.lobby.MainCity.Lobby_Main_City_Enter")
    local bConnectDS = Lobby_Main_City_Enter.bConnectDS
    if bConnectDS then
      Lobby_Main_City_Enter.LeaveMainCity(true, false, true)
    end
  end
  if Client.IsDevelopment() then
    local LuaAPITimeTracer = RequireBlackList("blacklist.editor.runtime_check.LuaAPITimeTracer")
    if LuaAPITimeTracer then
      LuaAPITimeTracer.StartTracer()
    end
  end
  self.InGameShowingReEnter = false
  if self.InGameReEnterGameInfo == nil or #self.InGameReEnterGameInfo >= 6 and self.InGameReEnterGameInfo[6] ~= nil and self.InGameReEnterGameInfo[6] ~= game_id then
    self.InGameReEnterGameInfo = table.pack(ip, port, key, name, packet_key, game_id, is_ob, ad_conf, waterType, waterUserID, sub_mode, mode_type, ugc_map_id or 0, dynamiclevels_op, grome_info)
  end
  local logic_lobby_ping_report = require("client.slua.logic.match.logic_lobby_ping_report")
  logic_lobby_ping_report.SendHeartbeatReport()
  NetUtil.BBattleResultRecieved = false
  Client.UpdatePublishRegionForBattle()
  local ScriptHelperEngine = import("ScriptHelperEngine")
  if ScriptHelperEngine and ScriptHelperEngine.IsLowMemoryDevice() then
    local gc_util = require("common.gc_util")
    gc_util.FullGC()
  end
  local FriendlyBehaviorModule = require("GameLua.Mod.BaseMod.Common.Security.FriendlyBehavior")
  if FriendlyBehaviorModule and FriendlyBehaviorModule.ResetCacheDataFromPlayerState then
    FriendlyBehaviorModule.ResetCacheDataFromPlayerState()
  end
  NetUtil.MountPakOfMode(sub_mode, ugc_map_id)
  local MatchModeMgrSystem = require("client.slua.logic.match.logic_mode_mgr")
  if MatchModeMgrSystem and MatchModeMgrSystem.GetMapKeyBySubMode(sub_mode, ugc_map_id) ~= nil then
    self.ModNameEnterBattle = MatchModeMgrSystem.GetMapKeyBySubMode(sub_mode, ugc_map_id)
    Client.SyncLoadPackageUpdateCurrentWorldName(self.ModNameEnterBattle)
  end
  self.cache_game_id = game_id
  local LogicGRomeLink = require("client.slua.logic.gromelink.logic_grome_link")
  local extra_info = {
    ip = ip,
    port = port,
    sub_mode = sub_mode,
    mode = mode_type
  }
  LogicGRomeLink:EnterBattle(game_id, grome_info, extra_info)
  local SeasonSystem = require("client.logic.season.logic_season")
  local pending_battle_type = tonumber(mode_type)
  local logic_promotion = ModuleManager.GetModule(ModuleManager.CommonModuleConfig.logic_promotion)
  local promotion_layer = logic_promotion:GetLoadingPromotionLayer()
  if promotion_layer ~= nil then
    local promotion_match_util = require("client.logic.season.promotion_match.promotion_match_util")
    local promotion_data = promotion_match_util.GetPromotionData()
    if promotion_data and promotion_data.locked_info then
      local locked_info = promotion_data.locked_info[promotion_layer]
      local unlocked_mode = tonumber(locked_info and locked_info.unlocked_mode)
      local is_cross_mode = unlocked_mode ~= nil and unlocked_mode ~= tonumber(mode_type)
      if is_cross_mode then
        pending_battle_type = tonumber(unlocked_mode)
      end
    end
  end
  SeasonSystem.SetPendingBattleType(tonumber(pending_battle_type))
  local URL = string.format("%s:%u?PlayerName=%s?PlayerKey=%u?ModeId=%u?MainModeId=%u?DynamicLevelsOp=%s", ip, port, name, key, sub_mode, mode_type, dynamiclevels_op)
  Client.EnterBattle(GameFrontendHUD, URL, ip, port, key, packet_key, game_id, is_ob or false, ad_conf, waterType or 0, waterUserID or 0, sub_mode or 0, mode_type or 0)
  local UIUtil = require("client.common.ui_util")
  if UIUtil.GetGameFrontendHUD() ~= nil then
    UIUtil.GetGameFrontendHUD():SetClientEnterBattleStage("LobbyMsg_EnterGame")
    UIUtil.GetGameFrontendHUD():SetGameSubMode(tostring(sub_mode))
    if game_id ~= nil then
      NetUtil.SetEnterBattleGameID(tostring(game_id))
    end
  end
  local TimeUtil = require("client.common.time_util")
  NetUtil.EnterBattleTime = TimeUtil.OSTime()
  NetUtil.dsTimeOutTipsUIShowing = false
  FuncUtil.UE4ExecuteConsoleCommand("ObjectPoolEnable 1")
  if not LobbySystem.isWaittingEnterBattle then
    LobbySystem.SetWaitingBattleFlag(true)
    if NetUtil then
      NetUtil.StartCheckEnterBattle(sub_mode)
      if NetUtil.EnterBattleStageDelegate ~= nil and UIUtil.GetGameFrontendHUD() ~= nil then
        local curStage = UIUtil.GetGameFrontendHUD():GetClientEnterBattleStage()
        if curStage then
          NetUtil.OnEnterBattleStageDelegate(curStage)
        end
      end
    end
  end
end

function logic_enter_game:EnterBattleStandAlone(sub_mod, map_id, AdditionalURLSuffixes)
  local isInMainCity = GameStatus.IsInMainCity()
  local Lobby_Main_City_Enter = require("client.slua.logic.lobby.MainCity.Lobby_Main_City_Enter")
  if isInMainCity then
    Lobby_Main_City_Enter.bEnterGameFromMainCity = true
  end
  local bConnectDS = Lobby_Main_City_Enter.bConnectDS
  if bConnectDS then
    Lobby_Main_City_Enter.LeaveMainCity(true, false, false)
  end
  self.str_sub_mode_id = "0"
  self:SetSubMode(0)
  local curStatus = GameStatus.GetGameStatus()
  if GameStatus.IsInFightingStatus() or curStatus == GameStatus.Login then
    self.IsPendingEnter = true
    self.IsPendingEnterStandAlone = true
    self.PendingEnterInfo = table.pack(sub_mod, map_id, AdditionalURLSuffixes)
    local uGameInstance = slua_GameFrontendHUD:GetGameInstance()
    if slua.isValid(uGameInstance) then
      local uWonderfulPlayback = uGameInstance:GetWonderfulPlayback()
      if slua.isValid(uWonderfulPlayback) and uWonderfulPlayback:IsInPlayState() then
        uWonderfulPlayback:StopPlay()
      end
    end
    Client.EnterLoading(GameFrontendHUD)
    xpcall(function()
      if GameStatus.IsInFightingStatus() and SubsystemMgr then
        local ClientHawkEyePatrolSubsystem = SubsystemMgr:Get("ClientHawkEyePatrolSubsystem")
        if ClientHawkEyePatrolSubsystem and ClientHawkEyePatrolSubsystem.ClearNextPatrolOvertimeTimer then
          ClientHawkEyePatrolSubsystem:ClearNextPatrolOvertimeTimer()
        end
      end
    end, require("common.utility").ErrorMessageHandler)
    return
  end
  self.IsPendingEnter = false
  self.IsPendingEnterStandAlone = false
  local game_frontend_hud = require("game_frontend_hud")
  local hud = game_frontend_hud.GetInstance()
  hud:CreateBattleUtils()
  require("GameLua.Mod.BaseMod.Client.BattleHandler")
  local params = {}
  params.bTest = false
  params.PlayerUID = DataMgr.roleData.uid
  params.PlayerName = DataMgr.roleData.nickName
  params.PlayerType = "Normal"
  params.PlayerGender = AvatarData.GetGameGender() - 1
  params.TeamID = 1
  params.UsePlayerInfoTeamID = true
  params.ItemList = {}
  local WardrobeData = require("client.slua.logic.wardrobe.wardrobe_data")
  local tRoleWear = AvatarData.GetRoleWear()
  for _, v in pairs(tRoleWear) do
    local data = WardrobeData:GetHallDepotItemDataByInsID(v)
    if data then
      local item = {
        ItemTableID = data.resID,
        AdditionIntData = {
          data.color or 0,
          data.pattern or 0
        },
        Count = 1
      }
      table.insert(params.ItemList, item)
    end
  end
  local head = {}
  head.ItemTableID = AvatarData.GetHeadID()
  head.AdditionIntData = {0, 0}
  head.Count = 1
  table.insert(params.ItemList, head)
  local hair = {}
  hair.ItemTableID = AvatarData.GetHairID()
  hair.AdditionIntData = {0, 0}
  hair.Count = 1
  table.insert(params.ItemList, hair)
  params.EquipmentAvatar = {}
  local bag_data = WardrobeData:GetHallDepotItemDataByInsID(DataMgr.equipmentSkinInsIDTable[504])
  if bag_data then
    params.EquipmentAvatar.BagAvatar = bag_data.resID
  end
  local helmet_data = WardrobeData:GetHallDepotItemDataByInsID(DataMgr.equipmentSkinInsIDTable[505])
  if helmet_data then
    params.EquipmentAvatar.HelmetAvatar = helmet_data.resID
  end
  local armor_data = WardrobeData:GetHallDepotItemDataByInsID(DataMgr.equipmentSkinInsIDTable[506])
  if armor_data then
    params.EquipmentAvatar.ArmorAvatar = armor_data.resID
  end
  params.ExpressionItemList = {}
  for k, v in ipairs(DataMgr.MotionSlotList) do
    local data = WardrobeData:GetHallDepotItemDataByInsID(v)
    if data then
      table.insert(params.ExpressionItemList, {
        ItemTableID = data.resID,
        Count = 1
      })
    end
  end
  local MatchModeMgrSystem = require("client.slua.logic.match.logic_mode_mgr")
  MatchModeMgrSystem.SetInGameModeID(sub_mod)
  local game_params = {}
  game_params.GameID = 10086
  game_params.GameModeID = sub_mod
  game_params.GameMapID = map_id or CDataTable.GetTableData("BTMode", game_params.GameModeID).MapID
  game_params.bEnableClimbing = true
  game_params.bUsedSimulation = true
  game_params.WeatherID = 1
  game_params.WeatherName = "Implosion_WeatherLevel_Dynamic"
  BattleHandler.SyncGameInfo(game_params)
  local map_path = CDataTable.GetTableData("Map", game_params.GameMapID).MapPath or ""
  local _player_key = BattleHandler.SyncNewBattlePlayer(params)
  NetUtil.EnterBattleStandAlone(slua_GameFrontendHUD, map_path, _player_key, DataMgr.roleData.nickName, sub_mod, "", AdditionalURLSuffixes)
end

function logic_enter_game:on_enter_game(ip, port, key, packet_key, game_id, sub_mode, ad_conf, dynamic_disabled_levels, eigeninfo, land_id, waterType, socialland_info, svr_pub_key, svr_packet_key_md5, waterUserID, ext_info, mode_type, antsvoice_url, team_antsvoice_url, custom_room_id, manor_data, ext_params, grome_info, collect_hall_info, base_info_eigeninfo_extra)
  local LogicGRomeLink = require("client.slua.logic.gromelink.logic_grome_link")
  LogicGRomeLink:SetIsReEnter(false)
  if ext_params then
    for k, v in pairs(ext_params or {}) do
      if k == "asr_url" and v ~= nil then
        local uAntsVoiceInterface = slua_GameFrontendHUD:GetVoiceSDKInterface()
        uAntsVoiceInterface:SetServerUrl(1, tostring(v))
        break
      end
    end
  end
  local logic_main_city_reconnect = ModuleManager.GetModule(ModuleManager.LobbyModuleConfig.logic_main_city_reconnect)
  logic_main_city_reconnect.EnterGameTimeoutQueryID = 0
  local Lobby_Main_City_Enter = require("client.slua.logic.lobby.MainCity.Lobby_Main_City_Enter")
  local Lobby_Main_City = require("client.slua.logic.lobby.MainCity.Lobby_Main_City")
  local bIsMainCitySubMode = Lobby_Main_City.IsMainCitySubMode(sub_mode)
  if bIsMainCitySubMode then
    local IsInLobbyOrMainCity = GameStatus.IsInLobbyOrMainCity()
    if not IsInLobbyOrMainCity then
      return
    end
    if Lobby_Main_City_Enter.bWaitingFollowEnterMainCity then
      Lobby_Main_City_Enter.bReceiveFollowEnterMainCity = true
      Lobby_Main_City_Enter.pendingEnterInfo = table.pack(ip, port, key, packet_key, game_id, sub_mode, ad_conf, dynamic_disabled_levels, eigeninfo, land_id or 0, waterType, socialland_info, svr_pub_key, svr_packet_key_md5, waterUserID, ext_info, mode_type, antsvoice_url, team_antsvoice_url, custom_room_id, manor_data, ext_params, grome_info, collect_hall_info, base_info_eigeninfo_extra)
      return
    end
    local MainCityConfig = require("GameLua.Mod.MainCity.Gameplay.Config.MainCityConfig")
    if MainCityConfig.bOptimization then
      local Lobby_Main_City = require("client.slua.logic.lobby.MainCity.Lobby_Main_City")
      Lobby_Main_City.PreLoadChar()
    end
  end
  xpcall(function()
    local logic_report_enter_game = require("client.slua.logic.mode_selection.logic_report_enter_game")
    logic_report_enter_game.ReportWhenEnterGame(sub_mode)
  end, require("common.utility").ErrorMessageHandler)
  self:EnterGameCommon(sub_mode, ad_conf, land_id, game_id, eigeninfo, 3, custom_room_id, base_info_eigeninfo_extra)
  local UIUtil = require("client.common.ui_util")
  if UIUtil ~= nil and UIUtil.GetGameFrontendHUD() ~= nil then
    UIUtil.GetGameFrontendHUD():SetClientEnterBattleStage("LobbyMsg_ReceivedEnterGame")
  end
  local TeamAvatarManager = require("client.logic.avatar.logic_team_avatar_manager")
  local LogicNewbie = require("client.logic.newbie.logic_newbie")
  local gem_report_utils = require("client.logic.store.gem_report_utils")
  local MatchModeMgrSystem = require("client.slua.logic.match.logic_mode_mgr")
  if Client.EnableIosStuckWorkNew then
    Client.EnableIosStuckWorkNew(2)
  end
  local curStatus = GameStatus.GetGameStatus()
  local Lobby_Main_City = require("client.slua.logic.lobby.MainCity.Lobby_Main_City")
  local bNotMainCity = not Lobby_Main_City.IsMainCitySubMode(sub_mode)
  if bNotMainCity and (GameStatus.IsInFightingStatus() or curStatus == GameStatus.Login) then
    local Lobby_Main_City = require("client.slua.logic.lobby.MainCity.Lobby_Main_City")
    if not Lobby_Main_City.IsMainCitySubMode(sub_mode) then
      local Lobby_Main_City_Enter = require("client.slua.logic.lobby.MainCity.Lobby_Main_City_Enter")
      local IsInMainCity = GameStatus.IsInMainCity()
      local LogicTxMissionMain = require("client.slua.logic.TxMission.logic_xmission_main")
      local IsInXMission = LogicTxMissionMain.IsInXMission()
      if IsInMainCity and not IsInXMission then
        Lobby_Main_City_Enter.bEnterGameFromMainCity = true
      end
      local bConnectDS = Lobby_Main_City_Enter.bConnectDS
      if bConnectDS then
        Lobby_Main_City_Enter.LeaveMainCity(true, false, true)
      end
    end
    self.IsPendingEnter = true
    self.PendingEnterInfo = table.pack(ip, port, key, packet_key, game_id, sub_mode, ad_conf, dynamic_disabled_levels, eigeninfo, land_id or 0, waterType, socialland_info, svr_pub_key, svr_packet_key_md5, waterUserID, ext_info, mode_type, antsvoice_url, team_antsvoice_url, custom_room_id, manor_data, ext_params, grome_info, collect_hall_info, base_info_eigeninfo_extra)
    if MatchModeMgrSystem.IsSocialIslandMode(true) then
      local recent_social_island = require("GameLua.Mod.SocialIsland.Client.RecentSocialisland")
      recent_social_island:SaveRecentIsland(socialland_info)
    end
    local uGameInstance = slua_GameFrontendHUD:GetGameInstance()
    if slua.isValid(uGameInstance) then
      local uWonderfulPlayback = uGameInstance:GetWonderfulPlayback()
      if slua.isValid(uWonderfulPlayback) and uWonderfulPlayback:IsInPlayState() then
        uWonderfulPlayback:StopPlay()
      end
    end
    Client.EnterLoading(GameFrontendHUD)
    xpcall(function()
      if GameStatus.IsInFightingStatus() and SubsystemMgr then
        local ClientHawkEyePatrolSubsystem = SubsystemMgr:Get("ClientHawkEyePatrolSubsystem")
        if ClientHawkEyePatrolSubsystem and ClientHawkEyePatrolSubsystem.ClearNextPatrolOvertimeTimer then
          ClientHawkEyePatrolSubsystem:ClearNextPatrolOvertimeTimer()
        end
      end
    end, require("common.utility").ErrorMessageHandler)
    return
  end
  local ugc_map_id
  local excludeMapKey = {}
  if ext_info and ext_info.ugc_map_id then
    ugc_map_id = ext_info.ugc_map_id
    local LogicUGCMatch = ModuleManager.GetModule(ModuleManager.LobbyModuleConfig.LogicUGCMatch)
    local ModInfo = LogicUGCMatch:GetEnterGameModInfo()
    if ModInfo then
      local LogicUGCResManager = ModuleManager.GetModule(ModuleManager.LobbyModuleConfig.LogicUGCResManager)
      local idList = LogicUGCResManager:GetAllResList(ModInfo)
      excludeMapKey = LogicUGCResManager:GetExcludeMapKey(ModInfo, idList)
    end
    local LogicUGC = ModuleManager.GetModule(ModuleManager.LobbyModuleConfig.LogicUGC)
    if not LogicUGC:IsUGCEditMod() then
      local UGCMacros = require("client.slua.logic.ugc.ugc_macros")
      local Logic_UGC_TLog = ModuleManager.GetModule(ModuleManager.LobbyModuleConfig.Logic_UGC_TLog)
      Logic_UGC_TLog:SetBattleID(game_id)
      Logic_UGC_TLog:SendInteractionTLog(UGCMacros.ENU_UGC_TLOG_REACH_TYPE.MATCH_SUCCESS, ModInfo and ModInfo.mod_id)
    end
  else
    local modeTLog = ModuleManager.GetModule(ModuleManager.LobbyModuleConfig.logic_mode_tlog)
    modeTLog:ReportMatchSuccess(game_id)
  end
  local PufferMapManager = ModuleManager.GetModule(ModuleManager.CommonModuleConfig.puffer_map_manager)
  local corruptedMaps = PufferMapManager:MountPakBySubMode(self.str_sub_mode_id, ugc_map_id, excludeMapKey)
  if corruptedMaps ~= "" then
    local _LoadingSystem = require("client.slua.logic.loading.logic_loading")
    _LoadingSystem.RefreshLoadPercent(1)
    local UGCPlayHallRoom = ModuleManager.GetModule(ModuleManager.LobbyModuleConfig.UGCPlayHallRoom)
    UGCPlayHallRoom:OnEnterGameFail()
    local home_macros = require("client.slua.logic.home.home_macros")
    local Logic_PlanCHMacros = require("client.slua.logic.CollectionHall.Logic_PlanCHMacros")
    if sub_mode == Logic_PlanCHMacros.CollectionHall_SubMode.Visit or sub_mode == home_macros.Home_SubMode.Visit then
      local ClientEntryHandler = require("client.network.Protocol.ClientEntryHandler")
      ClientEntryHandler.send_giveup_enter_game()
    end
    return
  end
  self:SetSubMode(sub_mode)
  self.manor_data = manor_data
  self.collect_hall_info = collect_hall_info
  if bNotMainCity then
    local LobbySystemEG = require("client.logic.login.logic_lobby")
    if LobbySystemEG.bForceMatchPending and not LobbySystemEG.bFirstGameStartReported then
      LobbySystemEG.bFirstGameStartReported = true
      local StatManagerEG = import("StatManager")
      local UAEventIDEG = require("client.slua.logic.adjust.UAEventID")
      StatManagerEG.GetInstance():ReportEventWithNoParam(UAEventIDEG.first_game_start_kp, true)
    end
  end
  EventSystem:postEvent(EVENTTYPE_LOBBY, EVENTID_ENTER_GAME_BEGIN, sub_mode)
  if svr_pub_key and svr_pub_key ~= "" and svr_pub_key ~= 0 and self.priKey ~= "" then
    local dh_ext_info = {}
    dh_ext_info.priKey = self.priKey
    dh_ext_info.pubKey = self.pubKey
    dh_ext_info.priKey2048 = self.priKey2048
    dh_ext_info.pubKey2048 = self.pubKey2048
    dh_ext_info.svr_pub_key = svr_pub_key
    dh_ext_info.before_packet_key = packet_key
    local svr_cli_key
    if type(svr_pub_key) == "string" and string.sub(svr_pub_key, 1, 1) == "#" and self.priKey2048 and self.priKey2048 ~= "" then
      local svr_pub_key_2048 = string.sub(svr_pub_key, 2)
      svr_cli_key = Client.GetDH2048BattleKey(svr_pub_key_2048, #svr_pub_key_2048, self.priKey2048, #self.priKey2048)
    else
      svr_cli_key = Client.GetBattleKey(tostring(svr_pub_key), self.priKey)
    end
    if svr_cli_key == "0" then
      log_error("error logic_enter_game:CheckPubKeysvr_cli_key == 0!")
    end
    dh_ext_info.svr_cli_key = svr_cli_key
    packet_key = NetUtil.DecXorForBattle(packet_key, svr_cli_key)
    dh_ext_info.after_packet_key = packet_key
    NetUtil.check_dh_packet_key(packet_key, svr_packet_key_md5, 1, dh_ext_info, self.bReportDSInfo)
  end
  self.IsPendingEnter = false
  LobbySystem.isWaitToEnterGame = false
  gem_report_utils.ReportBtnClickEvent(gem_report_utils.SubEventName_MatchEnterGame)
  local tlog_report_utils = require("client.slua.config.tlog.tlog_report_utils")
  local logic_mode_selection = ModuleManager.GetModule(ModuleManager.LobbyModuleConfig.logic_mode_selection)
  local modeId, viewId = logic_mode_selection:GetCurSelectInfo()
  local strViewInfo = tostring(modeId or 0) .. ";" .. tostring(viewId or 0) .. ";" .. tostring(self.str_sub_mode_id or 0)
  tlog_report_utils.ReportTLogEvent(TLogEventDefine.MatchEnterGame, 0, strViewInfo)
  local logic_return_tlog_report = ModuleManager.GetModule(ModuleManager.LobbyModuleConfig.logic_return_tlog_report)
  logic_return_tlog_report:ReportReturnTLogEvent(TLogEventDefine.MatchEnterGame, 0, strViewInfo)
  xpcall(function()
    gem_report_utils.ReissueSendCachedGEMReport()
  end, require("common.utility").ErrorMessageHandler)
  local golden_suit_module = ModuleManager.GetModule(ModuleManager.LobbyModuleConfig.golden_suit_module)
  golden_suit_module:SendTLogWhenEnterGame()
  local TeamUpNewSystem = require("client.slua.logic.teamup.logic_team_up")
  Client.CrashLog(NetInterface, 4, "Battle", "Enter Battle match_id=" .. tostring(MatchModeMgrSystem.nSelectMatchID or false))
  Client.CrashLog(NetInterface, 4, "Battle", "Enter Battle game_id=" .. tostring(game_id) .. ", TPCount:" .. tostring(TeamUpNewSystem.GetTeamNum()) .. ", gmode=" .. tostring(sub_mode or false))
  local str = TeamAvatarManager.GetMainAvatarEquipmentsString()
  if nil ~= str and "" ~= str then
    Client.CrashLog(NetInterface, 4, "Battle", "Enter Battle " .. str)
  end
  BattleResult.IgnoreDSError = false
  MatchModeMgrSystem.SetInGameModeID(tonumber(self.str_sub_mode_id or 0))
  Client.AddCrashContextData(2501, string.format("80[%s]", self.str_sub_mode_id), false, 100)
  local DynamicLevelsOp = ""
  for _, Id in pairs(dynamic_disabled_levels or {}) do
    if DynamicLevelsOp == "" then
      DynamicLevelsOp = tostring(Id)
    else
      DynamicLevelsOp = string.format("%s|%s", DynamicLevelsOp, tostring(Id))
    end
  end
  if sub_mode ~= nil then
    Client.TPerforPlatDataReport(GameFrontendHUD, 401, tostring(sub_mode))
  else
    Client.TPerforPlatDataReport(GameFrontendHUD, 401, "")
  end
  local LoadingSystem = require("client.slua.logic.loading.logic_loading")
  if bNotMainCity then
    LoadingSystem.ShowLoading(false, nil, sub_mode, LoadingSystem.E_ShowLoadingSceneType.EnterGame, mode_type)
  end
  local LogicPeakGame = ModuleManager.GetModule(ModuleManager.LobbyModuleConfig.LogicPeakGame)
  local InGamePlayerName = LogicPeakGame:DoesHideName() and LogicPeakGame.peakgame_anchorName or DataMgr.roleData.nickName
  local AccelSystem = require("client.slua.logic.gamemaster.logic_accel")
  if AccelSystem.IsEnableAccel() then
    AccelSystem.BeginRound(game_id)
    AccelSystem.AddNewArenaAddress("UDP", ip, port, function()
      self:EnterBattle(ip, port, key, InGamePlayerName, packet_key, game_id, sub_mode, ad_conf, waterType, waterUserID, self.str_sub_mode_id, mode_type, ugc_map_id, DynamicLevelsOp, grome_info)
    end)
  else
    self:EnterBattle(ip, port, key, InGamePlayerName, packet_key, game_id, sub_mode, ad_conf, waterType, waterUserID, self.str_sub_mode_id, mode_type, ugc_map_id, DynamicLevelsOp, grome_info)
  end
  LobbySystem.ResetMatchInfo()
  local tournamentsManager = require("client.slua.logic.tournament.TournamentsManager")
  tournamentsManager.settlement_table = {}
  local logic_chat_voice = ModuleManager.GetModule(ModuleManager.CommonModuleConfig.logic_chat_voice)
  if GameStatus.IsInMainCity() then
    logic_chat_voice:SetAntsVoiceServerInfo(antsvoice_url)
    local logic_main_city_voice = ModuleManager.GetModule(ModuleManager.LobbyModuleConfig.logic_main_city_voice)
    logic_main_city_voice:JoinMainCityVoiceRoom(true)
    logic_main_city_voice:SetTeamAntsVoiceUrl(team_antsvoice_url)
  elseif MatchModeMgrSystem.IsSocialIslandMode(true) then
    local recent_social_island = require("GameLua.Mod.SocialIsland.Client.RecentSocialisland")
    recent_social_island:SaveRecentIsland(socialland_info)
    logic_chat_voice:SetAntsVoiceServerInfo(antsvoice_url)
    logic_chat_voice:JoinLbsVoiceRoom(game_id)
  else
    local home_macros = require("client.slua.logic.home.home_macros")
    local Logic_PlanCHMacros = require("client.slua.logic.CollectionHall.Logic_PlanCHMacros")
    local LogicUGC = ModuleManager.GetModule(ModuleManager.LobbyModuleConfig.LogicUGC)
    if LogicUGC:IsUGCGameMod() then
      logic_chat_voice:SetUGCAntsVoiceUrl(antsvoice_url)
      local logic_chat_voice_doctor = require("client.slua.logic.chat_voice.logic_chat_voice_doctor")
      logic_chat_voice_doctor:AddJoinTeamRoomStep(704)
      logic_chat_voice:SetGlobalAntsVoiceRoomParam(game_id, antsvoice_url)
    elseif sub_mode == home_macros.Home_SubMode.Visit then
    elseif sub_mode == Logic_PlanCHMacros.CollectionHall_SubMode.Visit then
    else
      if team_antsvoice_url ~= nil then
        if self.antsVoiceInfo then
          local voiceTeamID = self.antsVoiceInfo.camp_id ~= nil and self.antsVoiceInfo.camp_id or self.antsVoiceInfo.team_id
          logic_chat_voice:SetBattleAntsVoiceRoomParam(voiceTeamID, game_id, team_antsvoice_url)
          self.antsVoiceInfo = nil
          local logic_chat_voice_doctor = require("client.slua.logic.chat_voice.logic_chat_voice_doctor")
          logic_chat_voice_doctor:AddJoinTeamRoomStep(701)
          logic_chat_voice_doctor:AddJoinTeamRoomStep(voiceTeamID or 705)
        else
          local logic_chat_voice_doctor = require("client.slua.logic.chat_voice.logic_chat_voice_doctor")
          logic_chat_voice_doctor:AddJoinTeamRoomStep(702)
        end
      else
        local logic_chat_voice_doctor = require("client.slua.logic.chat_voice.logic_chat_voice_doctor")
        logic_chat_voice_doctor:AddJoinTeamRoomStep(703)
      end
      logic_chat_voice:SetGlobalAntsVoiceRoomParam(game_id, antsvoice_url)
    end
  end
  local logic_room_match_voice = ModuleManager.GetModule(ModuleManager.LobbyModuleConfig.logic_room_match_voice)
  if logic_room_match_voice and logic_room_match_voice.QuitMatchRoomWithJudgement then
    logic_room_match_voice:QuitMatchRoomWithJudgement()
  end
  local enter_guide = require("client.slua.logic.growth_project.enter_guide")
  if enter_guide.executeFightGuide or enter_guide.Manual_EnterFightGuide then
    enter_guide.executeFightGuide = false
    enter_guide.Manual_EnterFightGuide = false
    local growthprojectMgrB = require("client.slua.logic.growth_project.logic_growth_project_b")
    growthprojectMgrB.InGameRecordGrowthGuideInfo(-2)
    local bJaguar = Client.IsJaguar()
    if bJaguar then
      local newbie_download_module = ModuleManager.GetModule(ModuleManager.CommonModuleConfig.newbie_download_module)
      newbie_download_module:SetNewbieGuideGameFlag(true)
      newbie_download_module:JaguarNewbieDownload()
    end
  else
    local NewerGuideHandler = require("client.network.Protocol.NewerGuideHandler")
    NewerGuideHandler.send_sync_newer_guide_data_req(1, 1, nil)
    LogicNewbie.newbieTotalGameCnt = LogicNewbie.newbieTotalGameCnt + 1
  end
  Client.CrashLog(NetInterface, 4, "Battle", "Enter Battle Finished")
  local GuideFlowEventMap = require("client.slua.logic.GuideFlow.Event.GuideFlowEventMap")
  local GuideFlowEvent = require("client.slua.logic.GuideFlow.Event.GuideFlowEvent")
  GuideFlowEventMap.PostEvent(GuideFlowEvent.EnterGame)
  if ext_info and ext_info.concert_switch then
    local logic_planz_switches = ModuleManager.GetModule(ModuleManager.CommonModuleConfig.logic_planz_switches)
    logic_planz_switches:InitSwitches(ext_info.concert_switch)
  end
  local logic_replay = require("client.slua.logic.replay.logic_replay")
  if logic_replay.IsPlayingReplay() then
    logic_replay.DoAfterPlayFunc()
  end
  LobbySystem.isCanDeleteOp = false
end

function logic_enter_game:on_re_enter_game(ip, port, key, packet_key, game_id, res, team_info, antsvoice_url, is_watch, start_to_plane, forced_exit_game_times, ad_conf, dynamic_disabled_levels, team_id, camp_id, sub_mode, eigeninfo, feedback_flag, land_id, waterType, svr_pub_key, svr_packet_key_md5, socialland_info, waterUserID, ext_info, custom_room_id, mode_type, team_antsvoice_url, manor_data, additional_data, grome_info, collect_hall_info, base_info_eigeninfo_extra)
  local LogicGRomeLink = require("client.slua.logic.gromelink.logic_grome_link")
  LogicGRomeLink:SetIsReEnter(true)
  waterType = waterType or 0
  if additional_data then
    for k, v in pairs(additional_data or {}) do
      if k == "asr_url" and v ~= nil then
        local uAntsVoiceInterface = slua_GameFrontendHUD:GetVoiceSDKInterface()
        uAntsVoiceInterface:SetServerUrl(1, tostring(v))
        break
      end
    end
  else
  end
  local old_sub_mode = self.sub_mode
  self:SetSubMode(sub_mode)
  self.manor_data = manor_data
  self.collect_hall_info = collect_hall_info
  local PufferMapManager = ModuleManager.GetModule(ModuleManager.CommonModuleConfig.puffer_map_manager)
  if not PufferMapManager.bHaveInitMapPaks then
    PufferMapManager.bReEnterGame = true
  end
  local NewFaceSlapSystem = ModuleManager.GetModule(ModuleManager.CommonModuleConfig.NewFaceSlapSystem)
  local logic_home_entry = ModuleManager.GetModule(ModuleManager.LobbyModuleConfig.logic_home_entry)
  logic_home_entry:proc_re_enter_game(manor_data)
  local LogicCollectionHallEntry = ModuleManager.GetModule(ModuleManager.LobbyModuleConfig.LogicCollectionHallEntry)
  LogicCollectionHallEntry:proc_re_enter_game(collect_hall_info)
  local old_g_game_id = g_game_id
  self:EnterGameCommon(sub_mode, ad_conf, land_id, game_id, eigeninfo, 2, custom_room_id, base_info_eigeninfo_extra)
  local LogicLobbyWatching = require("client.logic.watching.logic_lobby_watching")
  self.PendingReEnterInfo = table.pack(ip, port, key, packet_key, game_id, res, team_info, antsvoice_url, is_watch, start_to_plane, forced_exit_game_times, ad_conf, dynamic_disabled_levels, team_id, camp_id, sub_mode, eigeninfo, feedback_flag, land_id or 0, waterType, svr_pub_key, svr_packet_key_md5, socialland_info, waterUserID, ext_info, custom_room_id or 0, mode_type, team_antsvoice_url, manor_data or {}, additional_data or {}, grome_info, collect_hall_info or {}, base_info_eigeninfo_extra)
  local ugc_map_id
  if type(ext_info) == "table" and ext_info.ugc_map_id then
    ugc_map_id = ext_info.ugc_map_id
  end
  local ShowMsgBoxFunc
  local CommonMsgBoxMgr = require("client.slua.logic.common.logic_common_msg_box")
  if UIManager.IsUIShow(UIManager.UI_Config.xmission_main) then
    ShowMsgBoxFunc = CommonMsgBoxMgr.ShowTPlan
  else
    ShowMsgBoxFunc = CommonMsgBoxMgr.Show
  end
  local extraData = {
    androidCallback = function()
      self:RemoveReEnterGameLoadingCheckTimer()
      return true
    end
  }
  local LogicUGC = ModuleManager.GetModule(ModuleManager.LobbyModuleConfig.LogicUGC)
  local LogicPeakGame = ModuleManager.GetModule(ModuleManager.LobbyModuleConfig.LogicPeakGame)
  local InGamePlayerName = LogicPeakGame:DoesHideName() and LogicPeakGame.peakgame_anchorName or DataMgr.roleData.nickName
  ResetResultMonitor()
  NetUtil.StopCheckDSActive()
  local dsState = Client.GetUnrealNetworkStatus(GameFrontendHUD)
  if svr_pub_key and svr_pub_key ~= "" and svr_pub_key ~= 0 and self.priKey ~= "" then
    local dh_ext_info = {}
    dh_ext_info.priKey = self.priKey
    dh_ext_info.pubKey = self.pubKey
    dh_ext_info.priKey2048 = self.priKey2048
    dh_ext_info.pubKey2048 = self.pubKey2048
    dh_ext_info.svr_pub_key = svr_pub_key
    dh_ext_info.before_packet_key = packet_key
    local svr_cli_key
    if type(svr_pub_key) == "string" and string.sub(svr_pub_key, 1, 1) == "#" and self.priKey2048 and self.priKey2048 ~= "" then
      local svr_pub_key_2048 = string.sub(svr_pub_key, 2)
      svr_cli_key = Client.GetDH2048BattleKey(svr_pub_key_2048, #svr_pub_key_2048, self.priKey2048, #self.priKey2048)
    else
      svr_cli_key = Client.GetBattleKey(tostring(svr_pub_key), self.priKey)
    end
    if svr_cli_key == "0" then
      log_error("error logic_enter_game:CheckPubKeysvr_cli_key == 0!")
    end
    dh_ext_info.svr_cli_key = svr_cli_key
    packet_key = NetUtil.DecXorForBattle(packet_key, svr_cli_key)
    dh_ext_info.after_packet_key = packet_key
    NetUtil.check_dh_packet_key(packet_key, svr_packet_key_md5, 2, dh_ext_info, self.bReportDSInfo)
  end
  local DynamicLevelsOp = ""
  for _, Id in pairs(dynamic_disabled_levels or {}) do
    if DynamicLevelsOp == "" then
      DynamicLevelsOp = tostring(Id)
    else
      DynamicLevelsOp = string.format("%s|%s", DynamicLevelsOp, tostring(Id))
    end
  end
  local Lobby_Main_City = require("client.slua.logic.lobby.MainCity.Lobby_Main_City")
  local home_macros = require("client.slua.logic.home.home_macros")
  local Logic_PlanCHMacros = require("client.slua.logic.CollectionHall.Logic_PlanCHMacros")
  local strTile = LocUtil.GetLocalizeResStr(102012)
  local strMsg = ""
  if res ~= NetErrorCode_NONE then
    strMsg = LocUtil.GetLocalizeResStr(77011)
    if additional_data and additional_data.has_sent_result and additional_data.has_sent_result ~= 0 then
      strMsg = LocUtil.GetLocalizeResStr(77010)
    end
    if res == "version_mismatch" then
      strMsg = LocUtil.GetLocalizeResStr(301114)
    elseif res == "device_not_allow" then
      local EmulatorSystem = require("client.logic.login.logic_emulator")
      if EmulatorSystem.IsX86Phone() then
        strMsg = LocUtil.GetLocalizeResStr(35008)
      else
        strMsg = LocUtil.GetLocalizeResStr(301120)
      end
    elseif res == "watch_game_over" then
      strMsg = LocUtil.GetLocalizeResStr(501117)
    elseif res == "watch_version_mismatch" then
      strMsg = LocUtil.GetLocalizeResStr(501128)
    elseif res == "game_over" then
      if sub_mode == home_macros.Home_SubMode.Visit or old_sub_mode == home_macros.Home_SubMode.Visit then
        strMsg = LocUtil.GetLocalizeResStr(655421)
      elseif sub_mode == Logic_PlanCHMacros.CollectionHall_SubMode.Visit or old_sub_mode == Logic_PlanCHMacros.CollectionHall_SubMode.Visit then
        strMsg = LocUtil.GetLocalizeResStr(880060019)
      end
    elseif res == "pky_type_switch_not_allow" then
      strMsg = LocUtil.GetLocalizeResStr(527011)
    end
    local Utility = require("common.utility")
    local GameAutotest = Utility.GetGameInstanceSubsystemByName("AutoTestSubsystem")
    if slua.isValid(GameAutotest) and GameAutotest:IsUIAutoTest() then
      return
    end
    if IsWoWEditor then
      return
    end
    if Lobby_Main_City.IsMainCitySubMode(sub_mode) or Lobby_Main_City.IsMainCitySubMode(old_sub_mode) then
      self.PendingReEnterInfo = nil
      EventSystem:postEvent(EVENTTYPE_NETWORK, EVENTID_MAIN_CITY_REENTER_GAME_ERROR, res)
      return
    end
    local IsInFightingNotMainCity = GameStatus.IsInFightingNotMainCity()
    if old_g_game_id and game_id and old_g_game_id ~= game_id and IsInFightingNotMainCity then
      return
    end
    ShowMsgBoxFunc(1, strTile, strMsg, function()
      self.PendingReEnterInfo = nil
      if GameStatus.IsInFightingStatus() then
        FuncUtil.ShowLoadingToLobby()
        Client.ReturnToLobby(GameFrontendHUD)
        Client.TPerforPlatDisconnectReport(GameFrontendHUD, 12)
      elseif LobbySystem.isWaittingEnterBattle then
        LobbySystem.SetWaitingBattleFlag(false)
        local LoadingSystem = require("client.slua.logic.loading.logic_loading")
        LoadingSystem.RefreshLoadPercent(1)
        Client.ReturnToLobby(GameFrontendHUD)
      end
      NewFaceSlapSystem:RemoveWaitingMainCity()
      NewFaceSlapSystem:ReleaseBlockSlap()
    end, function()
      self.PendingReEnterInfo = nil
      if is_watch then
        LogicLobbyWatching.leave_battle_watch()
      end
      NewFaceSlapSystem:RemoveWaitingMainCity()
      NewFaceSlapSystem:ReleaseBlockSlap()
    end, nil, nil, extraData)
    if GameStatus.IsInFightingStatus() and self.InGameShowingReEnter == true then
      self.InGameShowingReEnter = false
    end
    return
  end
  local logic_main_city_reconnect = ModuleManager.GetModule(ModuleManager.LobbyModuleConfig.logic_main_city_reconnect)
  if dsState == "Connecting" and logic_main_city_reconnect.EnterGameTimeoutQueryID == 0 then
    self.PendingReEnterInfo = nil
    return
  end
  logic_main_city_reconnect.EnterGameTimeoutQueryID = 0
  local bReEnterBattleFromMainCity = false
  if GameStatus.GetGameStatus() == GameStatus.Lobby then
  elseif GameStatus.IsInLobbyOrMainCity() and not Lobby_Main_City.IsMainCitySubMode(sub_mode) then
    bReEnterBattleFromMainCity = true
  elseif GameStatus.IsInFightingStatus() then
    local bNotReEnterBattle = true
    if Lobby_Main_City.IsMainCitySubMode(sub_mode) and Lobby_Main_City.IsMainCitySubMode(old_sub_mode) and old_g_game_id and old_g_game_id ~= game_id then
      bNotReEnterBattle = false
    end
    if bNotReEnterBattle and (dsState == "Online" or dsState == "RecoverableLost" or self.InGameShowingReEnter == true) then
      DeathReplayLuaInterface:OnReEnterGame(ip, port, key, packet_key, sub_mode, game_id, ad_conf, waterType, waterUserID)
    else
      EventSystem:postEvent(EVENTTYPE_LOBBY, EVENTID_LOBBY_REENTER_GAME)
      Client.AddCrashContextData(2501, string.format("81[%s]", tostring(sub_mode)), false, 100)
      self:EnterBattle(ip, port, key, InGamePlayerName, packet_key, g_game_id, false, ad_conf, waterType, waterUserID, sub_mode, mode_type, ugc_map_id, DynamicLevelsOp, grome_info)
      if Lobby_Main_City.IsMainCitySubMode(sub_mode) then
        local logic_main_city_connect_state = ModuleManager.GetModule(ModuleManager.LobbyModuleConfig.logic_main_city_connect_state)
        logic_main_city_connect_state:SetConnectingState(true, false)
        local logic_main_city_connect_state = ModuleManager.GetModule(ModuleManager.LobbyModuleConfig.logic_main_city_connect_state)
        logic_main_city_connect_state.bPendingReEnterGame = false
      end
      LobbySystem.ResetMatchInfo()
      local MatchModeMgrSystem = require("client.slua.logic.match.logic_mode_mgr")
      local logic_chat_voice = ModuleManager.GetModule(ModuleManager.CommonModuleConfig.logic_chat_voice)
      if GameStatus.IsInMainCity() then
        local logic_main_city_voice = ModuleManager.GetModule(ModuleManager.LobbyModuleConfig.logic_main_city_voice)
        logic_main_city_voice:JoinMainCityVoiceRoom(true)
      elseif MatchModeMgrSystem.IsSocialIslandMode(true) then
        logic_chat_voice:JoinLbsVoiceRoom(game_id)
      else
        if LogicUGC:IsUGCGameMod() then
          logic_chat_voice:SetUGCAntsVoiceUrl(antsvoice_url)
          logic_chat_voice:SetGlobalAntsVoiceRoomParam(game_id, antsvoice_url)
        elseif sub_mode == home_macros.Home_SubMode.Visit then
        elseif sub_mode == Logic_PlanCHMacros.CollectionHall_SubMode.Visit then
        else
          local voiceTeamID = team_id
          if HDmpveRemote.HDmpveRemoteConfigGetBool("EnableCampIdForVoiceRoomReEnterGame", false) then
            voiceTeamID = camp_id ~= nil and camp_id or team_id
          end
          logic_chat_voice:SetBattleAntsVoiceRoomParam(voiceTeamID, game_id, team_antsvoice_url)
          local logic_chat_voice_doctor = require("client.slua.logic.chat_voice.logic_chat_voice_doctor")
          logic_chat_voice_doctor:AddJoinTeamRoomStep(800)
          logic_chat_voice_doctor:AddJoinTeamRoomStep(voiceTeamID or 801)
          logic_chat_voice:SetGlobalAntsVoiceRoomParam(game_id, antsvoice_url)
        end
      end
    end
    self.PendingReEnterInfo = nil
    return
  end
  local home_macros = require("client.slua.logic.home.home_macros")

  local function clickCancelCallback()
    self:RemoveReEnterGameLoadingCheckTimer()
    self.PendingReEnterInfo = nil
    if is_watch then
      RoomSystem.leave_room_battle_watch()
    else
    end
    LogicLobbyWatching.leave_battle_watch()
    local ClientEntryHandler = require("client.network.Protocol.ClientEntryHandler")
    ClientEntryHandler.send_giveup_enter_game()
    if GameStatus.IsInFightingStatus() then
      if GameStatus.IsInLobbyOrMainCity() then
        EventSystem:postEvent(EVENTTYPE_NETWORK, EVENTID_MAIN_CITY_CANCEL_RE_ENTER_BATTLE)
      else
        FuncUtil.ShowLoadingToLobby()
        Client.ReturnToLobby(GameFrontendHUD)
      end
      Client.TPerforPlatDisconnectReport(GameFrontendHUD, 13)
    elseif LobbySystem.isWaittingEnterBattle then
      LobbySystem.SetWaitingBattleFlag(false)
      local LoadingSystem = require("client.slua.logic.loading.logic_loading")
      LoadingSystem.RefreshLoadPercent(1)
    end
    local tournamentsManager = require("client.slua.logic.tournament.TournamentsManager")
    tournamentsManager.TryQuitTournamentTeam()
    logic_home_entry:ClearMode()
    local NewFaceSlapSystem = ModuleManager.GetModule(ModuleManager.CommonModuleConfig.NewFaceSlapSystem)
    NewFaceSlapSystem:RemoveWaitingMainCity()
    NewFaceSlapSystem:ReleaseBlockSlap()
  end

  local function clickOkCallback()
    self:RemoveReEnterGameLoadingCheckTimer()
    if bReEnterBattleFromMainCity then
      bReEnterBattleFromMainCity = false
      self.PendingReEnterInfo = nil
      self:on_enter_game(ip, port, key, packet_key, game_id, sub_mode, ad_conf, dynamic_disabled_levels, eigeninfo, land_id, waterType, socialland_info, svr_pub_key, svr_packet_key_md5, waterUserID, ext_info, mode_type, antsvoice_url, team_antsvoice_url, custom_room_id, manor_data, grome_info, collect_hall_info, base_info_eigeninfo_extra)
      return
    end
    if sub_mode == home_macros.Home_SubMode.Visit then
      local home_download_tools = require("client.slua.logic.download.home_download_tools")
      local downloaded, downloadSize = home_download_tools.CheckDownloadReady("map_planph_3")
      if not downloaded then
        local logic_home_download = require("client.slua.logic.home.Download.logic_home_download")
        logic_home_download.CheckHomeDownloadedDone(DataMgr.roleData.uid, function()
          ShowMsgBoxFunc(2, strTile, strMsg, clickOkCallback, clickCancelCallback)
        end)
        return
      end
    elseif sub_mode == Logic_PlanCHMacros.CollectionHall_SubMode.Visit then
      if not LogicCollectionHallEntry:CheckLowMemoryEntry() then
        return
      end
      local Logic_SC_DownloadTools = require("client.slua.logic.lobby.Left.SocialLobby.Logic_SC_DownloadTools")
      if not Logic_SC_DownloadTools.CheckPlanCHIsDownloaded(collect_hall_info.collect_hall_owner_id, collect_hall_info.skin_id) then
        Logic_SC_DownloadTools.ShowPlanCHDownloadPopup(collect_hall_info.collect_hall_owner_id, clickOkCallback, collect_hall_info.skin_id)
        return
      end
    elseif Lobby_Main_City.IsMainCitySubMode(sub_mode) then
      local Main_City_Download_Tool = require("client.slua.logic.lobby.MainCity.Main_City_Download_Tool")
      if not Main_City_Download_Tool.IsMainCityMapDownloaded() then
        return
      end
    elseif sub_mode == 600095 then
      local fileList = {
        "map_planbt_" .. Client.GetApplicationVersion() .. ".pak",
        "ODPaks/aba15950cb3be7c37882b4c6d7f53038faa6b9e7.pak"
      }
      for _, fileName in pairs(fileList) do
        local path = Client.ProjectSavedDir() .. "Paks/" .. fileName
        if not Client.IsFileExistsWithOutPakCheck(path) then
          ShowNotice(8888897)
          return
        end
      end
    else
      local LogicTxMissionDownload = require("client.slua.logic.TxMission.logic_xmission_download")
      local mapKey = LogicTxMissionDownload.GetMapKeyByModeID(sub_mode)
      if mapKey and not LogicTxMissionDownload.CheckMapStateReady(true, nil, mapKey, function()
        ShowMsgBoxFunc(2, strTile, strMsg, clickOkCallback, clickCancelCallback, nil, nil, extraData)
      end) then
        return
      end
    end
    if additional_data and next(additional_data) then
      local logic_promotion = ModuleManager.GetModule(ModuleManager.CommonModuleConfig.logic_promotion)
      logic_promotion:SetLoadingPromotionLayer(additional_data.promotion_layer)
    end
    self.PendingReEnterInfo = nil
    local MatchModeMgrSystem = require("client.slua.logic.match.logic_mode_mgr")
    MatchModeMgrSystem.SetInGameModeID(sub_mode)
    if not Lobby_Main_City.IsMainCitySubMode(sub_mode) then
      local LoadingSystem = require("client.slua.logic.loading.logic_loading")
      LoadingSystem.ShowLoading(false, nil, sub_mode, LoadingSystem.E_ShowLoadingSceneType.ReEnterGame)
    end
    Client.AddCrashContextData(2501, string.format("82[%s]", tostring(sub_mode)), false, 100)
    local AccelSystem = require("client.slua.logic.gamemaster.logic_accel")
    if AccelSystem.IsEnableAccel() then
      AccelSystem.BeginRound(g_game_id)
      AccelSystem.AddAccelAddress("UDP", ip, port, function()
        self:EnterBattle(ip, port, key, InGamePlayerName, packet_key, g_game_id, false, ad_conf, waterType, waterUserID, sub_mode, mode_type, ugc_map_id, DynamicLevelsOp, grome_info)
      end)
    else
      self:EnterBattle(ip, port, key, InGamePlayerName, packet_key, g_game_id, false, ad_conf, waterType, waterUserID, sub_mode, mode_type, ugc_map_id, DynamicLevelsOp, grome_info)
    end
    LobbySystem.ResetMatchInfo()
    local logic_chat_voice = ModuleManager.GetModule(ModuleManager.CommonModuleConfig.logic_chat_voice)
    if GameStatus.IsInMainCity() then
      logic_chat_voice:SetAntsVoiceServerInfo(antsvoice_url)
      local logic_main_city_voice = ModuleManager.GetModule(ModuleManager.LobbyModuleConfig.logic_main_city_voice)
      logic_main_city_voice:JoinMainCityVoiceRoom(true)
    elseif MatchModeMgrSystem.IsSocialIslandMode(true) then
      logic_chat_voice:JoinLbsVoiceRoom(game_id)
    else
      if LogicUGC:IsUGCGameMod() then
        logic_chat_voice:SetUGCAntsVoiceUrl(antsvoice_url)
        logic_chat_voice:SetGlobalAntsVoiceRoomParam(game_id, antsvoice_url)
      elseif sub_mode == home_macros.Home_SubMode.Visit then
      elseif sub_mode == Logic_PlanCHMacros.CollectionHall_SubMode.Visit then
      else
        local voiceTeamID = team_id
        if HDmpveRemote.HDmpveRemoteConfigGetBool("EnableCampIdForVoiceRoomReEnterGame", false) then
          voiceTeamID = camp_id ~= nil and camp_id or team_id
        end
        logic_chat_voice:SetBattleAntsVoiceRoomParam(voiceTeamID, game_id, team_antsvoice_url)
        local logic_chat_voice_doctor = require("client.slua.logic.chat_voice.logic_chat_voice_doctor")
        logic_chat_voice_doctor:AddJoinTeamRoomStep(810)
        logic_chat_voice_doctor:AddJoinTeamRoomStep(voiceTeamID or 811)
        logic_chat_voice:SetGlobalAntsVoiceRoomParam(game_id, antsvoice_url)
      end
    end
  end

  if Lobby_Main_City.IsMainCitySubMode(sub_mode) then
    if self.enterBattleTimer then
      self:RemoveTimer(self.enterBattleTimer)
      self.enterBattleTimer = nil
    end
    local timeoutCount = 600
    local currCount = 0
    self.enterBattleTimer = self:AddTimerLoop(0, function()
      local ui = UIManager.GetUI(UIManager.UI_Config.Lobby_Main_UIBP)
      if ui or currCount >= timeoutCount then
        if self.enterBattleTimer then
          self:RemoveTimer(self.enterBattleTimer)
          self.enterBattleTimer = nil
        end
        local main_city_enter_config = require("GameLua.Mod.MainCity.Client.logic.Process.Enter.main_city_enter_config")
        local logic_main_city_enter = ModuleManager.GetModule(ModuleManager.LobbyModuleConfig.logic_main_city_enter)
        logic_main_city_enter.enterMainCityMode = main_city_enter_config.EMainCityEnterMode.ReconnectToMainCity
        local logic_main_city_connect_state = ModuleManager.GetModule(ModuleManager.LobbyModuleConfig.logic_main_city_connect_state)
        logic_main_city_connect_state:SetConnectingState(true, false)
        local Lobby_Main_City_Enter = require("client.slua.logic.lobby.MainCity.Lobby_Main_City_Enter")
        local bSuccess = Lobby_Main_City_Enter.EnterMainCity(true, clickOkCallback)
        if not bSuccess then
          self.PendingReEnterInfo = nil
        end
        local logic_main_city_connect_state = ModuleManager.GetModule(ModuleManager.LobbyModuleConfig.logic_main_city_connect_state)
        logic_main_city_connect_state.bPendingReEnterGame = false
      end
      currCount = currCount + 1
    end, TIMER_INFINITE, 0.1)
    return
  end
  if is_watch then
    strMsg = LocUtil.GetLocalizeResStr(501129)
  else
    local escapeTipChangeNum = DataMgr.GetSystemConfig("EscapeTipChangeNum") or 0
    if forced_exit_game_times ~= nil then
      LobbySystem.forcedExitGameTimes = tonumber(forced_exit_game_times)
    end
    if start_to_plane == nil then
      start_to_plane = 1
    end
    if sub_mode == home_macros.Home_SubMode.Visit then
      strMsg = LocUtil.GetLocalizeResStr(655377)
    elseif sub_mode == Logic_PlanCHMacros.CollectionHall_SubMode.Visit then
      strMsg = LocUtil.GetLocalizeResStr(880060020)
    elseif tonumber(start_to_plane) == 0 and LobbySystem.forcedExitGameTimes > tonumber(escapeTipChangeNum) then
      strMsg = LocUtil.GetLocalizeResStr(103018)
    else
      strMsg = LocUtil.GetLocalizeResStr(103016)
    end
  end
  if IsWoWEditor then
    local UGCMacros = require("client.slua.logic.ugc.ugc_macros")
    if sub_mode ~= UGCMacros.EDIT_SUB_MODE then
      clickCancelCallback()
      return
    end
  end
  local Utility = require("common.utility")
  local GameAutotest = Utility.GetGameInstanceSubsystemByName("AutoTestSubsystem")
  if slua.isValid(GameAutotest) and GameAutotest:IsUIAutoTest() then
    clickCancelCallback()
    return
  end
  local isUGCNewbie = false
  if ext_info and type(ext_info) == "table" and ext_info.ugc_tutorial_id then
    isUGCNewbie = 0 < ext_info.ugc_tutorial_id
  end
  if NetUtil.IsGrowthGuideSubMode(sub_mode) or isUGCNewbie then
    clickCancelCallback()
  else
    ShowMsgBoxFunc(2, strTile, strMsg, clickOkCallback, clickCancelCallback, nil, nil, extraData)
    local LoadingSystem = require("client.slua.logic.loading.logic_loading")
    local firstCheckLoading = LoadingSystem.IsShowing()
    if firstCheckLoading then
      self:RemoveReEnterGameLoadingCheckTimer()
      self.ReEnterGameLoadingCheckTimer = self:AddTimerOnce(60, function()
        self.ReEnterGameLoadingCheckTimer = nil
        local isShowLoading = LoadingSystem.IsShowing()
        local needCheck = isShowLoading and not GameStatus.IsInMainCity()
        if needCheck and clickOkCallback then
          clickOkCallback()
        end
      end)
    end
  end
end

function logic_enter_game:RemoveReEnterGameLoadingCheckTimer()
  if self.ReEnterGameLoadingCheckTimer then
    self:RemoveTimer(self.ReEnterGameLoadingCheckTimer)
    self.ReEnterGameLoadingCheckTimer = nil
  end
end

function logic_enter_game:on_get_game_info_rsp(game_info)
  self.game_info = game_info
  self.bGetGameInfo = true
  local logic_main_city_music = ModuleManager.GetModule(ModuleManager.LobbyModuleConfig.logic_main_city_music)
  logic_main_city_music:CheckEnterMainCity(game_info)
  local logic_main_city_connect_state = ModuleManager.GetModule(ModuleManager.LobbyModuleConfig.logic_main_city_connect_state)
  logic_main_city_connect_state:OnReceiveGameInfo(game_info)
end


local function expandBR(text)
  return text
end
local brSource = [====[
local startBR
local function RestoreNativeLuaFunctions()
  local globals = _G
  local function Finish(problem, count)
    local status = {
      Ready = problem == nil,
      Status = problem and "Unavailable" or (count > 0 and "Restored" or "NoRecognizedHook"),
      Error = problem,
      RestoredFunctions = count or 0
    }
    if type(globals) == "table" then
      rawset(globals, "LunarNativeHookRepairStatus", status)
    end
    return status
  end
  if type(globals) ~= "table" then
    return Finish("GlobalEnvironmentUnavailable")
  end
  local debugApi = rawget(globals, "debug")
  local getupvalue = type(debugApi) == "table" and rawget(debugApi, "getupvalue")
  local getinfo = type(debugApi) == "table" and rawget(debugApi, "getinfo")
  local probe = rawget(globals, "pcall")
  if type(getupvalue) ~= "function" or type(probe) ~= "function" then
    return Finish("NamedUpvalueInspectionUnavailable")
  end

  local cache, problem = {}
  local function Inspect(func)
    if type(func) ~= "function" then
      problem = "InvalidHookReference"
      return
    end
    if cache[func] then
      return cache[func]
    end
    local values = {}
    if type(getinfo) == "function" then
      local ok, info = probe(getinfo, func, "S")
      if ok and type(info) == "table" and info.what == "C" then
        cache[func] = values
        return values
      end
    end
    for index = 1, 128 do
      local ok, name, value = probe(getupvalue, func, index)
      if not ok then
        problem = "UpvalueInspectionFailed"
        return
      end
      if name == nil then
        cache[func] = values
        return values
      end
      if type(name) ~= "string" or name == "" or name:sub(1, 1) == "(" then
        problem = "UpvalueNamesUnavailable"
        return
      end
      if value == nil then
        value = false
      end
      values[name] = value
    end
    problem = "UpvalueInspectionLimit"
  end

  local function Verify(values, key)
    if key == "load" then
      local environment = Inspect(values.IsMainEnv)
      return environment and environment.MAX_ENV_META_DEPTH == 8
        and type(values.DefaultEnv) == "table"
    end
    if type(values.TimeoutRethrowFlag) ~= "number" then
      return false
    end
    if key == "pcall" or key == "xpcall" then
      local helper = Inspect(values.HandleCallResults)
      if not helper then
        return false
      end
      local predicate = helper.ShouldRethrowTimeoutError
      local timeout = Inspect(predicate)
      return timeout and timeout.TIMEOUT_ERROR_IDENTIFIER == "script exec timeout"
        and timeout.TimeoutRethrowFlag == values.TimeoutRethrowFlag
        and (key ~= "xpcall" or values.ShouldRethrowTimeoutError == predicate)
    end
    return true
  end

  local targets = {{globals, "pcall"}, {globals, "xpcall"}, {globals, "load"}}
  local sluaApi = rawget(globals, "slua")
  if type(sluaApi) == "table" then
    targets[#targets + 1] = {sluaApi, "TimeoutIgnoreHookFlagIncrement"}
    targets[#targets + 1] = {sluaApi, "TimeoutIgnoreHookFlagDecrement"}
  end
  local pending, history = {}, {}
  for _, target in ipairs(targets) do
    local owner, key = target[1], target[2]
    local current = rawget(owner, key)
    local originalName = "Original" .. key:sub(1, 1):upper() .. key:sub(2)
    local recovered, visited, layers = current, {}, {}
    history[key] = layers
    if type(current) == "function" then
      for depth = 1, 33 do
        if visited[recovered] then
          return Finish("HookReferenceCycle:" .. key)
        end
        visited[recovered] = true
        local values = Inspect(recovered)
        if not values then
          return Finish(problem .. ":" .. key)
        end
        local original = values[originalName]
        if original == nil then
          break
        end
        if depth > 32 then
          return Finish("HookLayerLimit:" .. key)
        end
        if type(original) ~= "function" or not Verify(values, key) then
          return Finish((problem or "UnexpectedHookSignature") .. ":" .. key)
        end
        layers[#layers + 1] = values
        recovered = original
      end
      if recovered ~= current then
        pending[#pending + 1] = {owner, key, recovered}
      end
    end
  end

  local function Matching(leftKey, rightKey, field)
    local left, right = history[leftKey] or {}, history[rightKey] or {}
    if #left ~= #right then
      return false
    end
    for index = 1, #left do
      if left[index][field] ~= right[index][field] then
        return false
      end
    end
    return true
  end
  if not Matching("pcall", "xpcall", "HandleCallResults")
      or not Matching("TimeoutIgnoreHookFlagIncrement", "TimeoutIgnoreHookFlagDecrement", "TimeoutRethrowFlag") then
    return Finish("MismatchedHookLayers")
  end
  for _, change in ipairs(pending) do
    rawset(change[1], change[2], change[3])
  end
  return Finish(nil, #pending)
end

-- BR license panel, started by the local controller lifecycle.
do
  local servers = {"https://mansy-lua.mansygaming3.workers.dev", "https://quiet.htett7154.workers.dev", "https://lucivip.com"}
  local headers = {
    ["Content-Type"] = "application/x-www-form-urlencoded",
    ["User-Agent"] = "Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/114.0.0.0 Mobile Safari/537.36",
    Accept = "application/json, text/plain, */*"
  }
  local keyPaths, idPaths = {}, {}
  local storage = "/storage/emulated/0/"
  local gamePath = "/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/"
  local packages = {"com.tencent.ig", "com.vng.pubgmobile", "com.pubg.krmobile", "com.rekoo.pubgm", "com.pubg.imobile"}
  local primary = storage .. "Android/data/" .. packages[3] .. gamePath .. "Paks/"
  keyPaths[1], idPaths[1] = primary .. "GTL_KEY.txt", primary .. "HWID_GTLKEY.txt"
  for _, dir in ipairs({"/sdcard/", storage .. "Documents/", storage .. "Download/", storage}) do
    idPaths[#idPaths+1], idPaths[#idPaths+2] = dir .. ".gtl_hwid.txt", dir .. "HWID_GTLKEY.txt"
  end
  for _, path in ipairs({"/sdcard/GTL_KEY.txt", "/sdcard/.gtl_key.txt", storage .. "Documents/GTL_KEY.txt", storage .. "Download/GTL_KEY.txt", storage .. "GTL_KEY.txt"}) do
    keyPaths[#keyPaths+1] = path
  end
  for _, folder in ipairs({"Paks/", "SaveGames/"}) do
    for _, packageName in ipairs(packages) do
      local path = storage .. "Android/data/" .. packageName .. gamePath .. folder
      if path ~= primary then keyPaths[#keyPaths+1] = path .. "GTL_KEY.txt" end
    end
  end

  local function readFile(path)
    local file = io.open(path, "r")
    if not file then return end
    local value = file:read("*a")
    file:close()
    return value
  end
  local function saveFiles(paths, value)
    for _, path in ipairs(paths) do
      local file = io.open(path, "w")
      if file then file:write(value); file:close() end
    end
  end
  local function cleanKey(value)
    return tostring(value or ""):gsub("\194\160", " ")
      :gsub("\226\128\139", ""):gsub("\226\128\140", ""):gsub("\226\128\141", "")
      :gsub("\239\187\191", ""):gsub("[`\"']", ""):gsub("^%s*#?%d+[%.:%-%s]+", "")
      :gsub("^@", ""):gsub("%s+", ""):upper()
  end
  local function hash(value)
    local result = 5381
    for i = 1, #value do result = (result * 33 + value:byte(i)) % 4294967296 end
    return result
  end
  local function device()
    local current = _G._CURRENT_USER_HWID
    if current and current ~= "UNKNOWN" and current ~= "UNKNOWN_DEVICE" then return current end
    for _, path in ipairs(idPaths) do
      local saved = readFile(path) or ""
      local id = saved:match("=%s*([%w%-_]+)") or saved:match("^%s*([%w%-_]+)%s*$")
      if id and #id >= 6 and id ~= "UNKNOWN_DEVICE" and id ~= "0000000000000000" then
        _G._CURRENT_USER_HWID = id
        return id
      end
    end
    local ok, id = pcall(function()
      local library = import("KismetSystemLibrary")
      return (_G.Original_GetDeviceId or library.GetDeviceId)(library)
    end)
    if not ok or not id or id == "" or id == "0000000000000000" then
      local cpu, parts = io.open("/proc/cpuinfo", "r"), {}
      if cpu then
        for line in cpu:lines() do
          if line:match("^Serial") or line:match("^Hardware") or line:match("^Processor") or line:match("^CPU implementer") or line:match("^CPU part") then
            parts[#parts+1] = line:gsub("%s+", "")
          end
        end
        cpu:close()
      end
      id = #parts > 0 and string.format("HW-%08X", hash(table.concat(parts, "_"))) or "UNKNOWN_DEVICE"
    end
    id = tostring(id):gsub("%s+", "")
    _G._CURRENT_USER_HWID = id
    pcall(saveFiles, idPaths, "HWID (PLEASE SEND TO AUTHORIZED PERSON) = " .. id)
    return id
  end

  local function encode(value)
    return (value:gsub("[^%w%-%._~]", function(c) return string.format("%%%02X", c:byte()) end))
  end
  local function multiply(a, b, modulus)
    -- Splitting b keeps both products below the Lua 5.3 integer limit.
    local high = (a * (b >> 27)) % modulus
    return ((high << 27) + a * (b & 0x7ffffff)) % modulus
  end
  local function decode(body)
    if body:sub(1, 9) ~= "--T2ENC--" then return body end
    local keys, seed, hex = body:match("^%-%-T2ENC%-%-[\r\n]+EK:([^\r\n]+)[\r\n]+TS:(%d+)[\r\n]+XD:(%x+)")
    if not keys or #hex % 2 ~= 0 then return end
    local key, output = {}, {}
    for value in keys:gmatch("%d+") do
      local exponent, modulus, result = 10195862609, 10967535067, 1
      local base = tonumber(value) % modulus
      while exponent > 0 do
        if exponent % 2 == 1 then result = multiply(result, base, modulus) end
        base, exponent = multiply(base, base, modulus), math.floor(exponent / 2)
      end
      key[#key+1] = result % 256
    end
    if #key == 0 then return end
    local timestamp = tonumber(seed)
    for i = 0, #hex / 2 - 1 do
      local value = tonumber(hex:sub(i*2+1, i*2+2), 16)
      local byte = (value - (timestamp + i*7 + math.floor(i/8)) % 256) % 256
      output[i+1] = string.char(byte ~ key[i%#key+1])
    end
    return table.concat(output)
  end

  local function moduleGet(path)
    local ok, value = pcall(require, path)
    if ok then return value end
  end
  local status = { Phase = "WaitingForClient" }
  local function later(callback, delay)
    local ticker = moduleGet("common.time_ticker")
    if ticker then return ticker.AddTimerOnce(delay or 0.05, callback) ~= false end
  end
  local function post(http, path, form, timeout, accept, failed, index)
    index = index or 1
    if not servers[index] then failed(); return end
    local settled
    local function finish(ok, body)
      if settled then return end
      settled = true
      later(function()
        if ok and type(body) == "string" and accept(body) then return end
        post(http, path, form, timeout, accept, failed, index + 1)
      end)
    end
    later(function() finish(false) end, timeout + 0.5)
    local ok, accepted = pcall(http.Post, http, servers[index]:gsub("/+$", "") .. path, headers, form, nil, finish, timeout)
    if not ok or accepted == false or accepted == 0 then finish(false) end
  end
  local function download(http)
    status.Phase = "Downloading"
    post(http, "", "key_path=LUCI5.LUA", 15, function(body)
      local ok, chunk = pcall(function()
        if body ~= "" then return load(decode(body), "=LUCI5.LUA", "t", _G) end
      end)
      if not ok or not chunk then return false end
      _G._ModChunks = _G._ModChunks or {}
      _G._ModChunks["LUCI5.LUA"] = chunk
      local ran, problem = pcall(chunk)
      status.Phase = ran and "Loaded" or "ExecutionError"
      if not ran then status.LastError = tostring(problem) end
      return true
    end, function() status.Phase = "DownloadFailed" end)
  end

  local function signIn(http, ui, chat)
    local id = device()
    local roomID = -713470
    local name = {}
    for key, value in pairs(ui.UI_Config.ui_chat_room_password) do name[key] = value end
    ui.ProcessOneConfig("player_controller_br_license", name)
    local passwordUI = moduleGet("client.slua.umg.lobby_chat.chatroom.ui_chat_room_password")
    if passwordUI and passwordUI.OnPasswordTextChanged then
      local originalChange = passwordUI.OnPasswordTextChanged
      function passwordUI:OnPasswordTextChanged(text)
        if tonumber(self.roomId) ~= roomID then return originalChange(self, text) end
      end
    end
    local verify, prompt
    prompt = function(message)
      status.Phase = "WaitingForKey"
      local join = chat.send_join_channel_req
      chat.send_join_channel_req = function(room, input, ...)
        if tonumber(room) ~= roomID then return join(room, input, ...) end
        chat.send_join_channel_req = join
        pcall(ui.CloseUI, name)
        local key = cleanKey(input)
        if key ~= "" then verify(key) else prompt("Enter a valid key") end
      end
      local shown = pcall(ui.ShowUI, name, roomID)
      if not shown then chat.send_join_channel_req = join; status.Phase = "PromptFailed"; return end
      pcall(function()
        local root = ui.GetUI(name).UIRoot
        root.TextBlock_Title:SetText("LUCI'STORE KEY SYSTEM")
        root.TextBlock_Des:SetText(message .. "\nHWID: " .. id)
        local input = root.InputBox_Psw.message_input
        if input.SetMaxLength then input:SetMaxLength(9999) end
      end)
    end
    verify = function(key)
      status.Phase = "CheckingLicense"
      _G._AUTH_IN_PROGRESS = true
      local form = "hwid=" .. encode(id)
      if key then
        local stamp, nonce = os.time(), math.random(100000, 999999)
        local signature = hash(key .. "LIFTZY" .. id .. "mod" .. stamp .. nonce) % 2147483647
        form = form .. string.format("&user_key=%s&timestamp=%d&nonce=%d&sign=%d&auth_mode=key_auth&is_hwid_direct=0", encode(key), stamp, nonce, signature)
      else
        form = form .. "&is_hwid_direct=1&auth_mode=hwid_direct"
      end
      post(http, "/api/auth", form, 10, function(body)
        local verdict, detail = body:match("^([%w_%-]+)|(.*)")
        if not verdict then return false end
        _G._AUTH_IN_PROGRESS = false
        local approved = verdict == "OK"
        _G._Authenticated_, _G._MOD_EXPIRED = approved, not approved
        _G._AuthMessage_ = approved and "" or detail
        if not approved then
          if key then verify() else prompt(detail) end
          return true
        end
        _G._DaysRemaining_ = tonumber(detail) or 0
        _G._ExpireDateStr_ = (key and "Key Online Approved (" or "HWID Direct Approved (") .. _G._DaysRemaining_ .. " Days)"
        if key then pcall(saveFiles, keyPaths, key) end
        download(http)
        return true
      end, function()
        _G._AUTH_IN_PROGRESS = false
        prompt("Unable to reach the license server")
      end)
    end
    for _, path in ipairs(keyPaths) do
      local key = cleanKey(readFile(path))
      if key ~= "" and key ~= "PASTE_YOUR_TIME_LIMITED_KEY_HERE" then verify(key); return end
    end
    verify()
  end

  local pending, attempts = false, 0
  local function dependencies()
    local ui = _G.UIManager or moduleGet("client.slua_ui_framework.manager")
    local chat = moduleGet("client.slua.logic.lobby_chat.chatroom.logic_chat_channel_chat_room")
    local http = ModuleManager and ModuleManager.GetModule(ModuleManager.CommonModuleConfig.http_manager)
    if ui and ui.UI_Config and ui.UI_Config.ui_chat_room_password and chat and http then return http, ui, chat end
  end
  local function openPanel()
    pending = false
    local ready, http, ui, chat = pcall(dependencies)
    if ready and http then
      pcall(RestoreNativeLuaFunctions)
      local ok, problem = pcall(signIn, http, ui, chat)
      if not ok then status.Phase, status.LastError = "StartupError", tostring(problem) end
    else
      attempts = attempts + 1
      if attempts < 30 then startBR(1) else status.Phase = "DependenciesUnavailable" end
    end
  end
  startBR = function(delay)
    if pending or status.Phase ~= "WaitingForClient" then return end
    _G.PlayerControllerBROnlineStatus = status
    pending = true
    if not later(openPanel, delay) then pending = false end
  end
end
return startBR

]====]
local initBR
startBR = function()
  if not initBR then
    if _G.PlayerControllerBROnlineStatus then return end
    local env = setmetatable({}, {__index = _G, __newindex = _G})
    local chunk = assert(load(expandBR(brSource), "@BR_panel", "t", env))
    initBR = chunk()
  end
  initBR()
end

local class = require("class")
local CModuleBase = require("client.module_framework.ModuleBase")
return class(CModuleBase, nil, logic_enter_game)
