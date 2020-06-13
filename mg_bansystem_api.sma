#include <amxmodx>
#include <amxmisc>
#include <mg_core>
#include <sqlx>

#define PLUGIN  "[MG] BanSystem API"
#define VERSION "1.0"
#define AUTH    "Vieni"

new SERVERID
// All works by steamid search
new Trie:trieBanName
new Trie:trieBanReason
new Trie:trieBanAdminName
new Trie:trieBanAdminId
new Trie:trieBanType
new Trie:trieBanDate
new Trie:trieBanUnbanDate
new Trie:trieBanUnbanUnix
new Trie:trieBanIpcheckTime

new Handle:gSqlBanTuple

new cvarBanDelay, cvarIpcheckTime

new gForwardClientBan, gForwardClientKick

public plugin_init()
{
    register_plugin(PLUGIN, VERSION, AUTH)

    cvarBanDelay = register_cvar("bansystem_ban_delay", "1.5")
    cvarIpcheckTime = register_cvar("bansystem_ipchecktime(mins)", "4320")

    loadSettings()
    loadBanList()
}

public plugin_natives()
{
    gSqlBanTuple = SQL_MakeDbTuple("127.0.0.1","ebateam_forum", "z8hEn1gEUTWaSzfY","ebateam_forum")

    trieBanName = TrieCreate()
    trieBanReason = TrieCreate()
    trieBanAdminName = TrieCreate()
    trieBanAdminId = TrieCreate()
    trieBanType = TrieCreate()
    trieBanDate = TrieCreate()
    trieBanUnbanDate = TrieCreate()
    trieBanUnbanUnix = TrieCreate()
    trieBanIpcheckTime = TrieCreate()

    register_native("mg_ban_user_kick", "native_ban_user_kick")
    register_native("mg_ban_user_ban", "native_ban_user_ban")
    register_native("mg_ban_user_addban", "native_ban_user_addban")
    register_native("mg_ban_user_unban", "native_ban_user_unban")
}

public loadSettings()
{
    SERVERID = mg_core_serverid_get()
}

public loadBanList()
{
	formatex(lSqlTxt, charsmax(lSqlTxt), "SELECT * FROM regSystemAccounts;")
	SQL_ThreadQuery(gSqlRegTuple, "sqlBanLoadHandle", lSqlTxt, data, sizeof(data))

    set_task(240.0, "loadBanList")
}

public sqlBanLoadHandle(FailState, Handle:Query, error[],errcode, data[], datasize)
{
    if(FailState == TQUERY_CONNECT_FAILED || FailState == TQUERY_QUERY_FAILED)
	{
		log_amx("%s", error)
		return
	}

    static lSqlNamesLoaded, lSqlAuthId
    static lSqlGlobalName, lSqlGlobalReason, lSqlGlobalAdminName, lSqlGlobalAdminId, lSqlGlobalDate, lSqlGlobalUnbanDate, lSqlGlobalUnbanUnix
    static lSqlName, lSqlReason, lSqlAdminName, lSqlAdminId, lSqlDate, lSqlUnbanDate, lSqlUnbanUnix

    if(!lSqlNamesLoaded)
    {
        new helpTxt[40]

        lSqlAuthId = SQL_FieldNameToNum(Query, "authId")

        helpTxt[0] = EOS
        formatex(helpTxt, charsmax(helpTxt), "banName%d", SERVERID)
        lSqlName = SQL_FieldNameToNum(Query, helpTxt)

        helpTxt[0] = EOS
        formatex(helpTxt, charsmax(helpTxt), "banReason%d", MG_SERVER_GLOBAL)
        lSqlReason = SQL_FieldNameToNum(Query, helpTxt)

        helpTxt[0] = EOS
        formatex(helpTxt, charsmax(helpTxt), "banAdminName%d", MG_SERVER_GLOBAL)
        lSqlAdminName = SQL_FieldNameToNum(Query, helpTxt)

        helpTxt[0] = EOS
        formatex(helpTxt, charsmax(helpTxt), "banAdminId%d", MG_SERVER_GLOBAL)
        lSqlAdminId = SQL_FieldNameToNum(Query, helpTxt)

        helpTxt[0] = EOS
        formatex(helpTxt, charsmax(helpTxt), "banDate%d", MG_SERVER_GLOBAL)
        lSqlDate = SQL_FieldNameToNum(Query, helpTxt)

        helpTxt[0] = EOS
        formatex(helpTxt, charsmax(helpTxt), "banUnbanDated%d", MG_SERVER_GLOBAL)
        lSqlUnbanDate = SQL_FieldNameToNum(Query, helpTxt)

        helpTxt[0] = EOS
        formatex(helpTxt, charsmax(helpTxt), "banUnbanUnix%d", MG_SERVER_GLOBAL)
        lSqlGlobalUnbanUnix = SQL_FieldNameToNum(Query, helpTxt)

        helpTxt[0] = EOS
        formatex(helpTxt, charsmax(helpTxt), "banName%d", SERVERID)
        lSqlName = SQL_FieldNameToNum(Query, helpTxt)

        helpTxt[0] = EOS
        formatex(helpTxt, charsmax(helpTxt), "banReason%d", SERVERID)
        lSqlReason = SQL_FieldNameToNum(Query, helpTxt)

        helpTxt[0] = EOS
        formatex(helpTxt, charsmax(helpTxt), "banAdminName%d", SERVERID)
        lSqlAdminName = SQL_FieldNameToNum(Query, helpTxt)

        helpTxt[0] = EOS
        formatex(helpTxt, charsmax(helpTxt), "banAdminId%d", SERVERID)
        lSqlAdminId = SQL_FieldNameToNum(Query, helpTxt)

        helpTxt[0] = EOS
        formatex(helpTxt, charsmax(helpTxt), "banDate%d", SERVERID)
        lSqlDate = SQL_FieldNameToNum(Query, helpTxt)

        helpTxt[0] = EOS
        formatex(helpTxt, charsmax(helpTxt), "banUnbanDated%d", SERVERID)
        lSqlUnbanDate = SQL_FieldNameToNum(Query, helpTxt)

        helpTxt[0] = EOS
        formatex(helpTxt, charsmax(helpTxt), "banUnbanUnix%d", SERVERID)
        lSqlUnbanUnix = SQL_FieldNameToNum(Query, helpTxt)

        lSqlNamesLoaded = true
    }

    new Trie:lTrieAuthIdList
    new lUnbanUnix
    new lAuthId[MAX_AUTHID_LENGTH+1], helpTxt[100]

    lTrieAuthIdList = TrieCreate()

    while(SQL_MoreResults(Query))
    {
        SQL_ReadResult(Query, lSqlAuthId, lAuthId, charsmax(lAuthId))

        if(TrieKeyExists(lTrieAuthIdList, lAuthId))
        {
            log_amx("[LOADBANS] !!WARNING!! More bans found on this authid! (%s)", lAuthId)
            SQL_NextRow(Query)
            continue
        }

        if(TrieKeyExists(trieBanName, lAuthId))
        {
            SQL_NextRow(Query)
            continue
        }

        if((lUnbanUnix = SQL_ReadResult(Query, lSqlGlobalUnbanUnix)) > get_systime())
        {
            helpTxt[0] = EOS
            SQL_ReadResult(Query, lSqlGlobalName, helpTxt, charsmax(helpTxt))
            TrieSetString(trieBanName, lAuthId, helpTxt)

            helpTxt[0] = EOS
            SQL_ReadResult(Query, lSqlGlobalReason, helpTxt, charsmax(helpTxt))
            TrieSetString(trieBanReason, lAuthId, helpTxt)

            helpTxt[0] = EOS
            SQL_ReadResult(Query, lAuthId, helpTxt, charsmax(helpTxt))
            TrieSetString(trieBanAdminName, lAuthId, helpTxt)

            TrieSetCell(trieBanAdminId, lAuthId, SQL_ReadResult(Query, lSqlGlobalAdminId))

            helpTxt[0] = EOS
            SQL_ReadResult(Query, lSqlGlobalDate, helpTxt, charsmax(helpTxt))
            TrieSetString(trieBanDate, lAuthId, helpTxt)

            helpTxt[0] = EOS
            SQL_ReadResult(Query, lSqlGlobalUnbanDate, helpTxt, charsmax(helpTxt))
            TrieSetString(trieBanUnbanDate, lAuthId, helpTxt)

            TrieSetCell(trieBanUnbanUnix, lAuthId, lUnbanUnix)

            TrieSetCell(lTrieAuthIdList, lAuthId, 1)
            SQL_NextRow(Query)
            continue
        }

        if((lUnbanUnix = SQL_ReadResult(Query, lSqlUnbanUnix)) > get_systime()))
        {
            helpTxt[0] = EOS
            SQL_ReadResult(Query, lSqlName, helpTxt, charsmax(helpTxt))
            TrieSetString(trieBanName, lAuthId, helpTxt)

            helpTxt[0] = EOS
            SQL_ReadResult(Query, lSqlReason, helpTxt, charsmax(helpTxt))
            TrieSetString(trieBanReason, lAuthId, helpTxt)

            helpTxt[0] = EOS
            SQL_ReadResult(Query, lAuthId, helpTxt, charsmax(helpTxt))
            TrieSetString(trieBanAdminName, lAuthId, helpTxt)

            TrieSetCell(trieBanAdminId, lAuthId, SQL_ReadResult(Query, lSqlAdminId))

            helpTxt[0] = EOS
            SQL_ReadResult(Query, lSqlDate, helpTxt, charsmax(helpTxt))
            TrieSetString(trieBanDate, lAuthId, helpTxt)

            helpTxt[0] = EOS
            SQL_ReadResult(Query, lSqlUnbanDate, helpTxt, charsmax(helpTxt))
            TrieSetString(trieBanUnbanDate, lAuthId, helpTxt)

            TrieSetCell(trieBanUnbanUnix, lAuthId, lUnbanUnix)

            TrieSetCell(lTrieAuthIdList, lAuthId, 1)
            SQL_NextRow(Query)
            continue
        }

        TrieSetCell(lTrieAuthIdList, lAuthId, 1)
        SQL_NextRow(Query)
    }

    TrieDestroy(lTrieAuthIdList)
}

public kickPlayerByBan(id)
{
    kickPlayer(id, "BAN_ALREADYBANNED")
}

public sqlGeneralHandle(FailState, Handle:Query, error[],errcode, data[], datasize)
{
	if(FailState == TQUERY_CONNECT_FAILED || FailState == TQUERY_QUERY_FAILED)
	{
		log_amx("%s", error)
		return
	}
}

public native_ban_user_kick(plugin_id, param_num)
{
    new id = get_param(1)

    if(!is_user_connected(id))
        return false
    
    new lReason[32], lType

    get_string(2, lReason, charsmax(lReason))
    lType = get_param(3)

    kickPlayer(id, lReason, lType)
    return true
}

public native_ban_user_ban(plugin_id, param_num)
{
    new id = get_param(1)

    if(!is_user_connected(id))
        return false
    
    new lBanReason[32], lBanAdminName[MAX_NAME_LENGTH+1], lBanAdminId, lBanTime, lType

    get_string(2, lBanReason, charsmax(lBanReason))
    get_string(3, lBanAdminName, charsmax(lBanAdminName))
    lBanAdminId = get_param(4)
    lBanTime = get_param(5)
    lType = get_param(6)

    banPlayer()
}

public client_authorized(id)
{
    checkBannedPlayer(id)
}

checkBannedPlayer(id)
{
    new lAuthId[MAX_AUTHID_LENGTH+1]

    get_user_authid(id, lAuthId, charsmax(lAuthId))

    if(!TrieKeyExists(trieBanDate, lAuthId))
        return
    
    new lUnbanUnix

    TrieGetCell(trieBanUnbanUnix, lAuthId, lUnbanUnix)

    if(lUnbanUnix < get_systime())
    {
        removeBan(lAuthId)
        return
    }
    
    sendPlayerBanMessage(id, lAuthId)
    set_task(get_pcvar_float(cvarBanDelay), "kickPlayerByBan", id)
}

removeBan(const authId[])
{
    new sqlText[100]

	formatex(sqlText, charsmax(sqlText), "DELETE * FROM banList WHERE authId=^"%s^";", authId)
	SQL_ThreadQuery(gSqlBanTuple, "sqlGeneralHandle", sqlText)

    TrieDeleteKey(trieBanName, authId)
    TrieDeleteKey(trieBanReason, authId)
    TrieDeleteKey(trieBanAdminName, authId)
    TrieDeleteKey(trieBanAdminId, authId)
    TrieDeleteKey(trieBanType, authId)
    TrieDeleteKey(trieBanDate, authId)
    TrieDeleteKey(trieBanUnbanDate, authId)
    TrieDeleteKey(trieBanUnix, authId)
    TrieDeleteKey(trieBanIpcheckTime, authId)
}

sendPlayerBanMessage(id, const authId[] = "none")
{
    if(equal(authId, "none"))
        get_user_authid(id, authId, MAX_AUTHID_LENGTH)
    
    new lBanName[MAX_NAME_LENGTH+1], lBanReason[32], lBanAdminName[MAX_NAME_LENGTH+1]
    new lBanAdminId, lBanDate[20], lUnbanDate[20]

    TrieGetString(trieBanName, authId, lBanName, charsmax(lBanName))
    TrieGetString(trieBanReason, authId, lBanReason, charsmax(lBanReason))
    TrieGetString(trieBanAdminName, authId, lBanAdminName, charsmax(lBanAdminName))
    TrieGetString(trieBanAdminId, authId, lBanAdminId, charsmax(lBanAdminId))
    TrieGetString(trieBanDate, authId, lBanDate, charsmax(lBanDate))
    TrieGetString(trieBanUnbanDate, authId, lUnbanDate, charsmax(lUnbanDate))

    client_cmd(id, "echo %s", id, "BANLINE1")
    client_cmd(id, "echo %s", id, "BANLINE2", lBanName)
    client_cmd(id, "echo %s", id, "BANLINE3", lBanAdminName, lBanAdminId)
    client_cmd(id, "echo %s", id, "BANLINE4", lBanReason)
    client_cmd(id, "echo %s", id, "BANLINE5", lBanDate)
    client_cmd(id, "echo %s", id, "BANLINE6", lUnbanDate)
    client_cmd(id, "echo %s", id, "BANLINE7")
    client_cmd(id, "echo %s", id, "BANLINE8")
}

banPlayer(id, const banReason[], banUnix, banType, const adminName[] = "SERVERCMD", adminId = -1)
{
    if(!is_user_connected(id))
        return
    
    new lAuthId[MAX_AUTHID_LENGTH+1], lName[MAX_NAME_LENGTH+1]

    get_user_name(id, lName, charsmax(lName))
    get_user_authid(id, lAuthId, charsmax(lAuthId))

    // Calculation from unix to normal date

    TrieSetString(trieBanName, lAuthId, lName)
    TrieSetString(trieBanReason, lAuthId, banReason)
    TrieSetString(trieBanAdminName, lAuthId, adminName)
    TrieSetCell(trieBanAdminId, lAuthId, adminID)
    TrieSetCell(trieBanType, lAuthId, banType)
    TrieSetString(trieBanDate, lAuthId, )
    TrieSetString(trieBanUnbanDate, lAuthId, )
    TrieSetCell(trieBanUnix, lAuthId, get_systime()+banUnix)
    TrieSetCell(trieBanIpcheckTime, lAuthId, get_pcvar_num(cvarIpcheckTime))

    sendPlayerBanMessage(id, lAuthId)
    set_task(get_pcvar_float(cvarBanDelay), "kickPlayerByBan", id)
}

kickPlayer(id, const reason[], type = 0)
{
	new lKickTxt[64]

    if(type)
    {
        formatex(lKickTxt, charsmax(lKickTxt), "kick #%i ^"%s^"", get_user_userid(id), reason)
        server_cmd(lKickTxt)
    }
    else
    {
        formatex(lKickTxt, charsmax(lKickTxt), "kick #%i ^"%L^"", get_user_userid(id), id, reason)
        server_cmd(lKickTxt)
    }
}