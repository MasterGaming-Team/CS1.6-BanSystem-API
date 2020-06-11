#include <amxmodx>
#include <amxmisc>
#include <sqlx>

#define PLUGIN  "[MG] BanSystem API"
#define VERSION "1.0"
#define AUTH    "Vieni"

// All works by steamid search
new Trie:trieBanName
new Trie:trieBanReason
new Trie:trieBanAdminName
new Trie:trieBanAdminId
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
}

public plugin_natives()
{
    gSqlBanTuple = SQL_MakeDbTuple("127.0.0.1","ebateam_forum", "z8hEn1gEUTWaSzfY","ebateam_forum")

    trieBanName = TrieCreate()
    trieBanReason = TrieCreate()
    trieBanAdminName = TrieCreate()
    trieBanAdminId = TrieCreate()
    trieBanDate = TrieCreate()
    trieBanUnbanDate = TrieCreate()
    trieBanUnbanUnix = TrieCreate()
    trieBanIpcheckTime = TrieCreate()

    register_native("mg_ban_user_kick", "native_ban_user_kick")
    register_native("mg_ban_user_ban", "native_ban_user_ban")
    register_native("mg_ban_user_addban", "native_ban_user_addban")
    register_native("mg_ban_user_unban", "native_ban_user_unban")
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

    TrieGetCell(trieBanUnbanDate, lAuthId, lUnbanUnix)

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

banPlayer(id, const banReason[], banUnix, type = 0, const adminName[] = "SERVERCMD", adminId = -1)
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
    TrieSetString(trieBanAdminId, lAuthId, adminID)
    TrieSetString(trieBanDate, lAuthId, )
    TrieSetString(trieBanUnbanDate, lAuthId, )
    TrieSetString(trieBanUnix, lAuthId, get_systime()+banUnix)
    TrieSetString(trieBanIpcheckTime, lAuthId, get_pcvar_num(cvarIpcheckTime))

    switch(type)
    {
        case 0:
        {
            
        }
    }
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