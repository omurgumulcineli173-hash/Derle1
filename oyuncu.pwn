/*
    DUKTUR RP - OYUNCU SISTEMI (oyuncu.pwn)
    Gereken include'lar: a_samp, a_mysql (BlueG R41-4), sscanf2, zcmd
    Veritabani: duktur_schema.sql (web paneliyle ortak)
    Web -> oyun: web_queue tablosu (5 sn'de bir okunur)
*/

#include <a_samp>
#include <a_mysql>
#include <sscanf2>
#include <zcmd>

#undef MAX_PLAYERS
#define MAX_PLAYERS 100

#define SQL_HOST        "127.0.0.1"
#define SQL_USER        "duktur"
#define SQL_PASS        "DEGISTIR"
#define SQL_DB          "duktur_rp"
#define PANEL_URL       "https://dukturrp.com"

#define MAX_SLOTS       4
#define MAX_HOUSES      200
#define C_PURPLE        0xB266FFFF
#define C_ERR           0xFF4D4DFF
#define C_OK            0x66FF99FF
#define C_WHITE         0xFFFFFFFF
#define C_RP            0xE6C8FFFF
#define IsAdmin(%0,%1)  (P[%0][pAdmin] >= %1)

new MySQL:g_SQL;

enum
{
    D_NONE, D_LOGIN, D_REGISTER, D_EMAIL, D_SLOTS,
    D_C_FNAME, D_C_LNAME, D_C_AGE, D_C_GENDER, D_C_SKIN,
    D_BANK, D_BANK_DEP, D_BANK_WD, D_BANK_IBAN, D_BANK_AMT,
    D_REP_TYPE, D_REP_TEXT, D_INFO
}

enum E_PLAYER
{
    pAcc, bool:pLogged, pTries, pAdmin, pSlot, pChar,
    pFName[24], pLName[24], pAge, pGender, pSkin,
    pCash, pBank, pLevel, pPlay, pJob, pPhone, pIban[20],
    Float:pPX, Float:pPY, Float:pPZ, Float:pPA,
    pTmpF[24], pTmpL[24], pTmpAge, pTmpG, pTmpPass[65],
    pTransferIban[20], pRepType
}
new P[MAX_PLAYERS][E_PLAYER];
new gHash[MAX_PLAYERS][65], gSalt[MAX_PLAYERS][17];
new gSlotId[MAX_PLAYERS][MAX_SLOTS], gSlotName[MAX_PLAYERS][MAX_SLOTS][50];

new const gJobName[][] = {
    "Issiz", "Polis", "Saglik Gorevlisi", "Avukat", "Mekanik", "Taksi Soforu",
    "Otobus Soforu", "Tir Soforu", "Copcu", "Belediye Calisani", "Gazeteci",
    "Isletmeci", "Serbest Calisan"
};
new const gJobPay[] = { 500, 3500, 3200, 3800, 2500, 2000, 2200, 2600, 1500, 2000, 2300, 3000, 1800 };
new const gRepTypes[][] = {
    "Oyuncu Sikayeti", "Admin Sikayeti", "Hile Bildirimi", "Bug Bildirimi", "Teknik Destek",
    "Hesap Sorunu", "Ceza Itirazi", "Oneri", "Genel Destek"
};

new gVehOwner[MAX_VEHICLES], gVehDB[MAX_VEHICLES];

new gHouseCount, gHouseId[MAX_HOUSES], gHouseOwner[MAX_HOUSES], gHousePrice[MAX_HOUSES];
new Float:gHouseX[MAX_HOUSES], Float:gHouseY[MAX_HOUSES], Float:gHouseZ[MAX_HOUSES];
new gHouseAddr[MAX_HOUSES][48], gHousePickup[MAX_HOUSES], Text3D:gHouseLbl[MAX_HOUSES];

new gMinuteCounter;

/* ---------------------------------------------------------------- yardimcilar */

stock Err(playerid, const text[]) { SendClientMessage(playerid, C_ERR, text); return 1; }
stock Ok(playerid, const text[])  { SendClientMessage(playerid, C_OK, text); return 1; }

stock bool:ValidName(const s[])
{
    new len = strlen(s);
    if(len < 3 || len > 15) return false;
    for(new i = 0; i < len; i++)
    {
        if(i == 0) { if(s[i] < 'A' || s[i] > 'Z') return false; }
        else if(s[i] < 'a' || s[i] > 'z') return false;
    }
    return true;
}

stock bool:ValidSkin(skin) { return (skin >= 0 && skin <= 311 && skin != 74); }

stock GetPlayerByChar(charid)
{
    for(new i = 0; i < MAX_PLAYERS; i++)
        if(IsPlayerConnected(i) && P[i][pLogged] && P[i][pChar] == charid) return i;
    return INVALID_PLAYER_ID;
}

stock BankLog(charid, const type[], amount, const desc[])
{
    new q[300];
    mysql_format(g_SQL, q, sizeof q,
        "INSERT INTO bank_log (char_id,type,amount,description,created) VALUES (%d,'%e',%d,'%e',NOW())",
        charid, type, amount, desc);
    mysql_tquery(g_SQL, q);
}

stock KickDelayed(playerid) { return SetTimerEx("DoKick", 500, false, "d", playerid); }
forward DoKick(playerid);
public DoKick(playerid) { Kick(playerid); return 1; }

stock Punish(targetid, const type[], const reason[], const admin[])
{
    new q[300];
    mysql_format(g_SQL, q, sizeof q,
        "INSERT INTO punishments (account_id,type,reason,admin_name,created) VALUES (%d,'%e','%e','%e',NOW())",
        P[targetid][pAcc], type, reason, admin);
    mysql_tquery(g_SQL, q);
}

/* ---------------------------------------------------------------- hesap */

stock ShowLogin(playerid)
{
    ShowPlayerDialog(playerid, D_LOGIN, DIALOG_STYLE_PASSWORD, "DUKTUR RP - Giris",
        "{FFFFFF}Hesabin kayitli. Lutfen sifreni gir:", "Giris", "Cikis");
    return 1;
}

stock ShowRegister(playerid)
{
    ShowPlayerDialog(playerid, D_REGISTER, DIALOG_STYLE_PASSWORD, "DUKTUR RP - Kayit",
        "{FFFFFF}DUKTUR RP'ye hos geldin!\nHesap olusturmak icin bir sifre belirle (en az 6 karakter):", "Devam", "Cikis");
    return 1;
}

stock ShowSlots(playerid)
{
    new s[512], line[96];
    for(new i = 0; i < MAX_SLOTS; i++)
    {
        if(gSlotId[playerid][i]) format(line, sizeof line, "{FFFFFF}%d. Karakter: {B266FF}%s\n", i + 1, gSlotName[playerid][i]);
        else format(line, sizeof line, "{FFFFFF}%d. Karakter: {808080}[Bos Slot - Olustur]\n", i + 1);
        strcat(s, line);
    }
    ShowPlayerDialog(playerid, D_SLOTS, DIALOG_STYLE_LIST, "DUKTUR RP - Karakter Secimi", s, "Sec", "Cikis");
    return 1;
}

stock LoadSlots(playerid)
{
    new q[160];
    mysql_format(g_SQL, q, sizeof q, "SELECT id,slot,fname,lname FROM characters WHERE account_id=%d", P[playerid][pAcc]);
    mysql_tquery(g_SQL, q, "OnSlotsLoaded", "d", playerid);
}

stock LoadCharacter(playerid, charid)
{
    new q[160];
    // account_id kontrolu: oyuncu yalnizca kendi karakterini yukleyebilir
    mysql_format(g_SQL, q, sizeof q, "SELECT * FROM characters WHERE id=%d AND account_id=%d LIMIT 1", charid, P[playerid][pAcc]);
    mysql_tquery(g_SQL, q, "OnCharLoaded", "d", playerid);
}

stock LoadVehicles(playerid)
{
    new q[200];
    mysql_format(g_SQL, q, sizeof q,
        "SELECT id,model,plate,x,y,z,a,color1,color2,health FROM vehicles WHERE char_id=%d", P[playerid][pChar]);
    mysql_tquery(g_SQL, q, "OnVehsLoaded", "d", playerid);
}

stock SaveVehicles(charid)
{
    new q[300], Float:x, Float:y, Float:z, Float:a, Float:hp;
    for(new v = 1; v < MAX_VEHICLES; v++)
    {
        if(gVehOwner[v] != charid || !GetVehicleModel(v)) continue;
        GetVehiclePos(v, x, y, z); GetVehicleZAngle(v, a); GetVehicleHealth(v, hp);
        mysql_format(g_SQL, q, sizeof q,
            "UPDATE vehicles SET x=%.3f,y=%.3f,z=%.3f,a=%.3f,health=%.1f WHERE id=%d", x, y, z, a, hp, gVehDB[v]);
        mysql_tquery(g_SQL, q);
        DestroyVehicle(v);
        gVehOwner[v] = 0; gVehDB[v] = 0;
    }
}

stock SaveChar(playerid)
{
    if(!P[playerid][pLogged]) return 0;
    new q[512], Float:x, Float:y, Float:z, Float:a;
    GetPlayerPos(playerid, x, y, z); GetPlayerFacingAngle(playerid, a);
    P[playerid][pCash] = GetPlayerMoney(playerid);
    mysql_format(g_SQL, q, sizeof q,
        "UPDATE characters SET cash=%d,bank=%d,level=%d,playtime=%d,job=%d,x=%.3f,y=%.3f,z=%.3f,a=%.3f,last_seen=NOW() WHERE id=%d",
        P[playerid][pCash], P[playerid][pBank], P[playerid][pLevel], P[playerid][pPlay], P[playerid][pJob],
        x, y, z, a, P[playerid][pChar]);
    mysql_tquery(g_SQL, q);
    return 1;
}

/* ---------------------------------------------------------------- evler */

stock UpdateHouse(h)
{
    new s[128];
    if(gHouseOwner[h])
    {
        format(s, sizeof s, "{B266FF}%s\n{FFFFFF}Sahipli ev", gHouseAddr[h]);
        DestroyPickup(gHousePickup[h]);
        gHousePickup[h] = CreatePickup(1272, 1, gHouseX[h], gHouseY[h], gHouseZ[h], -1);
    }
    else
    {
        format(s, sizeof s, "{66FF99}SATILIK\n{FFFFFF}%s\n{66FF99}$%d\n{FFFFFF}/evsatinal", gHouseAddr[h], gHousePrice[h]);
        DestroyPickup(gHousePickup[h]);
        gHousePickup[h] = CreatePickup(1273, 1, gHouseX[h], gHouseY[h], gHouseZ[h], -1);
    }
    Update3DTextLabelText(gHouseLbl[h], 0xFFFFFFFF, s);
}

stock NearHouse(playerid)
{
    for(new h = 0; h < gHouseCount; h++)
        if(IsPlayerInRangeOfPoint(playerid, 3.0, gHouseX[h], gHouseY[h], gHouseZ[h])) return h;
    return -1;
}

forward OnHousesLoaded();
public OnHousesLoaded()
{
    gHouseCount = cache_num_rows();
    if(gHouseCount > MAX_HOUSES) gHouseCount = MAX_HOUSES;
    for(new h = 0; h < gHouseCount; h++)
    {
        cache_get_value_name_int(h, "id", gHouseId[h]);
        cache_get_value_name_int(h, "owner_char", gHouseOwner[h]);
        cache_get_value_name_int(h, "price", gHousePrice[h]);
        cache_get_value_name(h, "address", gHouseAddr[h], 48);
        cache_get_value_name_float(h, "x", gHouseX[h]);
        cache_get_value_name_float(h, "y", gHouseY[h]);
        cache_get_value_name_float(h, "z", gHouseZ[h]);
        gHouseLbl[h] = Create3DTextLabel(" ", 0xFFFFFFFF, gHouseX[h], gHouseY[h], gHouseZ[h] + 0.8, 15.0, 0, 1);
        gHousePickup[h] = CreatePickup(1273, 1, gHouseX[h], gHouseY[h], gHouseZ[h], -1);
        UpdateHouse(h);
    }
    printf("[DUKTUR RP] %d ev yuklendi.", gHouseCount);
    return 1;
}

/* ---------------------------------------------------------------- baslangic */

main() {}

public OnGameModeInit()
{
    SetGameModeText("DUKTUR RP");
    UsePlayerPedAnims();
    DisableInteriorEnterExits();
    EnableStuntBonusForAll(0);
    AddPlayerClass(0, 1642.0, -2333.0, 13.5, 0.0, 0, 0, 0, 0, 0, 0);

    mysql_log(ERROR | WARNING);
    g_SQL = mysql_connect(SQL_HOST, SQL_USER, SQL_PASS, SQL_DB);
    if(mysql_errno(g_SQL) != 0)
    {
        print("[DUKTUR RP] MySQL baglantisi KURULAMADI! Sunucu kapatiliyor.");
        SendRconCommand("exit");
        return 1;
    }
    mysql_set_charset("latin5", g_SQL);
    mysql_tquery(g_SQL, "UPDATE characters SET online=0");
    mysql_tquery(g_SQL, "SELECT id,owner_char,price,address,x,y,z FROM houses", "OnHousesLoaded");

    SetTimer("MinuteTimer", 60000, true);
    SetTimer("PollWeb", 5000, true);
    print("[DUKTUR RP] Oyuncu sistemi yuklendi.");
    return 1;
}

public OnGameModeExit()
{
    for(new i = 0; i < MAX_PLAYERS; i++)
        if(IsPlayerConnected(i)) { SaveChar(i); SaveVehicles(P[i][pChar]); }
    mysql_close(g_SQL);
    return 1;
}

public OnPlayerConnect(playerid)
{
    static const empty[E_PLAYER];
    P[playerid] = empty;
    for(new s = 0; s < MAX_SLOTS; s++) { gSlotId[playerid][s] = 0; gSlotName[playerid][s][0] = 0; }
    TogglePlayerSpectating(playerid, true);
    SetPlayerCameraPos(playerid, 1481.0, -1750.0, 60.0);
    SetPlayerCameraLookAt(playerid, 1481.0, -1700.0, 20.0);

    new name[MAX_PLAYER_NAME], q[200];
    GetPlayerName(playerid, name, sizeof name);
    mysql_format(g_SQL, q, sizeof q, "SELECT id,pass_hash,salt,status,admin FROM accounts WHERE name='%e' LIMIT 1", name);
    mysql_tquery(g_SQL, q, "OnAccountCheck", "d", playerid);
    return 1;
}

public OnPlayerDisconnect(playerid, reason)
{
    if(P[playerid][pLogged])
    {
        SaveChar(playerid);
        SaveVehicles(P[playerid][pChar]);
        new q[100];
        mysql_format(g_SQL, q, sizeof q, "UPDATE characters SET online=0 WHERE id=%d", P[playerid][pChar]);
        mysql_tquery(g_SQL, q);
    }
    static const empty[E_PLAYER];
    P[playerid] = empty;
    return 1;
}

forward OnAccountCheck(playerid);
public OnAccountCheck(playerid)
{
    if(!IsPlayerConnected(playerid)) return 1;
    if(!cache_num_rows()) { ShowRegister(playerid); return 1; }

    new st;
    cache_get_value_name_int(0, "id", P[playerid][pAcc]);
    cache_get_value_name(0, "pass_hash", gHash[playerid], 65);
    cache_get_value_name(0, "salt", gSalt[playerid], 17);
    cache_get_value_name_int(0, "status", st);
    cache_get_value_name_int(0, "admin", P[playerid][pAdmin]);
    if(st == 1)
    {
        SendClientMessage(playerid, C_ERR, "Bu hesap yasakli. Itiraz icin " PANEL_URL " adresindeki rapor merkezini kullan.");
        KickDelayed(playerid);
        return 1;
    }
    ShowLogin(playerid);
    return 1;
}

forward OnAccountRegistered(playerid);
public OnAccountRegistered(playerid)
{
    if(!IsPlayerConnected(playerid)) return 1;
    P[playerid][pAcc] = cache_insert_id();
    if(!P[playerid][pAcc]) { SendClientMessage(playerid, C_ERR, "Kayit basarisiz. Yetkililere bildir."); KickDelayed(playerid); return 1; }
    Ok(playerid, "Hesabin olusturuldu! Simdi karakterini olusturabilirsin.");
    LoadSlots(playerid);
    return 1;
}

forward OnSlotsLoaded(playerid);
public OnSlotsLoaded(playerid)
{
    if(!IsPlayerConnected(playerid)) return 1;
    new rows = cache_num_rows(), slot, f[24], l[24];
    for(new r = 0; r < rows; r++)
    {
        cache_get_value_name_int(r, "slot", slot);
        if(slot < 1 || slot > MAX_SLOTS) continue;
        cache_get_value_name_int(r, "id", gSlotId[playerid][slot - 1]);
        cache_get_value_name(r, "fname", f, sizeof f);
        cache_get_value_name(r, "lname", l, sizeof l);
        format(gSlotName[playerid][slot - 1], 50, "%s %s", f, l);
    }
    ShowSlots(playerid);
    return 1;
}

forward OnNameChecked(playerid);
public OnNameChecked(playerid)
{
    if(!IsPlayerConnected(playerid)) return 1;
    if(cache_num_rows())
    {
        Err(playerid, "Bu isim soyisim zaten kullaniliyor. Baska bir isim sec.");
        ShowPlayerDialog(playerid, D_C_FNAME, DIALOG_STYLE_INPUT, "Karakter - Ad",
            "{FFFFFF}Karakter adini gir (Roleplay kurallarina uygun, orn: Ahmet):", "Devam", "Geri");
        return 1;
    }
    ShowPlayerDialog(playerid, D_C_AGE, DIALOG_STYLE_INPUT, "Karakter - Yas", "{FFFFFF}Karakter yasi (18 - 80):", "Devam", "Geri");
    return 1;
}

forward OnCharCreated(playerid);
public OnCharCreated(playerid)
{
    if(!IsPlayerConnected(playerid)) return 1;
    new id = cache_insert_id();
    if(!id) { Err(playerid, "Karakter olusturulamadi (isim/slot cakismasi). Tekrar dene."); LoadSlots(playerid); return 1; }

    new q[300];
    mysql_format(g_SQL, q, sizeof q,
        "INSERT INTO inventory (char_id,item,amount) VALUES (%d,'Kimlik Karti',1),(%d,'Telefon',1),(%d,'Su',2),(%d,'Ekmek',2)",
        id, id, id, id);
    mysql_tquery(g_SQL, q);
    LoadCharacter(playerid, id);
    return 1;
}

forward OnCharLoaded(playerid);
public OnCharLoaded(playerid)
{
    if(!IsPlayerConnected(playerid)) return 1;
    if(!cache_num_rows()) { Err(playerid, "Karakter yuklenemedi."); ShowSlots(playerid); return 1; }

    cache_get_value_name_int(0, "id", P[playerid][pChar]);
    cache_get_value_name(0, "fname", P[playerid][pFName], 24);
    cache_get_value_name(0, "lname", P[playerid][pLName], 24);
    cache_get_value_name_int(0, "age", P[playerid][pAge]);
    cache_get_value_name_int(0, "gender", P[playerid][pGender]);
    cache_get_value_name_int(0, "skin", P[playerid][pSkin]);
    cache_get_value_name_int(0, "cash", P[playerid][pCash]);
    cache_get_value_name_int(0, "bank", P[playerid][pBank]);
    cache_get_value_name_int(0, "level", P[playerid][pLevel]);
    cache_get_value_name_int(0, "playtime", P[playerid][pPlay]);
    cache_get_value_name_int(0, "job", P[playerid][pJob]);
    cache_get_value_name_int(0, "phone", P[playerid][pPhone]);
    cache_get_value_name(0, "iban", P[playerid][pIban], 20);
    cache_get_value_name_float(0, "x", P[playerid][pPX]);
    cache_get_value_name_float(0, "y", P[playerid][pPY]);
    cache_get_value_name_float(0, "z", P[playerid][pPZ]);
    cache_get_value_name_float(0, "a", P[playerid][pPA]);
    if(P[playerid][pJob] < 0 || P[playerid][pJob] >= sizeof gJobName) P[playerid][pJob] = 0;

    P[playerid][pLogged] = true;
    new q[120];
    mysql_format(g_SQL, q, sizeof q, "UPDATE characters SET online=1 WHERE id=%d", P[playerid][pChar]);
    mysql_tquery(g_SQL, q);

    new rpname[50];
    format(rpname, sizeof rpname, "%s_%s", P[playerid][pFName], P[playerid][pLName]);
    ResetPlayerMoney(playerid);
    GivePlayerMoney(playerid, P[playerid][pCash]);
    SetSpawnInfo(playerid, NO_TEAM, P[playerid][pSkin], P[playerid][pPX], P[playerid][pPY], P[playerid][pPZ], P[playerid][pPA], 0, 0, 0, 0, 0, 0);
    TogglePlayerSpectating(playerid, false);    // oyuncu otomatik dogar
    LoadVehicles(playerid);
    new msg[96];
    format(msg, sizeof msg, "Hos geldin, %s %s! Komutlar icin /yardim", P[playerid][pFName], P[playerid][pLName]);
    Ok(playerid, msg);
    return 1;
}

forward OnVehsLoaded(playerid);
public OnVehsLoaded(playerid)
{
    new rows = cache_num_rows(), dbid, model, c1, c2, plate[12], Float:x, Float:y, Float:z, Float:a, Float:hp;
    for(new r = 0; r < rows; r++)
    {
        cache_get_value_name_int(r, "id", dbid);
        cache_get_value_name_int(r, "model", model);
        cache_get_value_name(r, "plate", plate, sizeof plate);
        cache_get_value_name_float(r, "x", x); cache_get_value_name_float(r, "y", y);
        cache_get_value_name_float(r, "z", z); cache_get_value_name_float(r, "a", a);
        cache_get_value_name_int(r, "color1", c1); cache_get_value_name_int(r, "color2", c2);
        cache_get_value_name_float(r, "health", hp);
        new v = CreateVehicle(model, x, y, z, a, c1, c2, -1);
        if(v == INVALID_VEHICLE_ID) continue;
        SetVehicleNumberPlate(v, plate);
        SetVehicleHealth(v, hp);
        gVehDB[v] = dbid;
        gVehOwner[v] = P[playerid][pChar];
    }
    return 1;
}

/* ---------------------------------------------------------------- oyun callback'leri */

public OnPlayerRequestSpawn(playerid) { return P[playerid][pLogged] ? 1 : 0; }

public OnPlayerSpawn(playerid)
{
    if(!P[playerid][pLogged]) return 1;
    SetPlayerSkin(playerid, P[playerid][pSkin]);
    SetPlayerHealth(playerid, 100.0);
    return 1;
}

public OnPlayerDeath(playerid, killerid, reason)
{
    if(!P[playerid][pLogged]) return 1;
    P[playerid][pCash] = GetPlayerMoney(playerid);
    P[playerid][pPX] = 1177.0; P[playerid][pPY] = -1323.5; P[playerid][pPZ] = 14.0; P[playerid][pPA] = 270.0;
    SetSpawnInfo(playerid, NO_TEAM, P[playerid][pSkin], P[playerid][pPX], P[playerid][pPY], P[playerid][pPZ], P[playerid][pPA], 0, 0, 0, 0, 0, 0);
    return 1;
}

public OnPlayerStateChange(playerid, newstate, oldstate)
{
    if(newstate == PLAYER_STATE_DRIVER)
    {
        new v = GetPlayerVehicleID(playerid);
        if(gVehOwner[v] && gVehOwner[v] != P[playerid][pChar])
        {
            RemovePlayerFromVehicle(playerid);
            Err(playerid, "Bu arac baskasina ait.");
        }
    }
    return 1;
}

public OnPlayerCommandReceived(playerid, cmdtext[])
{
    if(!P[playerid][pLogged]) { Err(playerid, "Once giris yapip karakter secmelisin."); return 0; }
    return 1;
}

public OnPlayerText(playerid, text[])
{
    if(!P[playerid][pLogged]) return 0;
    new s[160], Float:x, Float:y, Float:z;
    GetPlayerPos(playerid, x, y, z);
    format(s, sizeof s, "%s %s diyor ki: %s", P[playerid][pFName], P[playerid][pLName], text);
    for(new i = 0; i < MAX_PLAYERS; i++)
        if(IsPlayerConnected(i) && P[i][pLogged] && IsPlayerInRangeOfPoint(i, 20.0, x, y, z)) SendClientMessage(i, C_WHITE, s);
    return 0;
}

forward MinuteTimer();
public MinuteTimer()
{
    gMinuteCounter++;
    new s[128];
    for(new i = 0; i < MAX_PLAYERS; i++)
    {
        if(!IsPlayerConnected(i) || !P[i][pLogged]) continue;
        P[i][pPlay]++;
        if(P[i][pPlay] % 60 == 0)
        {
            new pay = gJobPay[P[i][pJob]];
            P[i][pBank] += pay;
            P[i][pLevel] = 1 + (P[i][pPlay] / 120);
            BankLog(P[i][pChar], "MAAS", pay, gJobName[P[i][pJob]]);
            format(s, sizeof s, "[MAAS] %s maasi $%d bankana yatirildi. Seviye: %d", gJobName[P[i][pJob]], pay, P[i][pLevel]);
            SendClientMessage(i, C_PURPLE, s);
        }
        if(gMinuteCounter % 5 == 0) SaveChar(i);
    }
    return 1;
}

/* ---------------------------------------------------------------- web -> oyun koprusu */

forward PollWeb();
public PollWeb()
{
    mysql_tquery(g_SQL, "SELECT id,char_id,action,value,text FROM web_queue WHERE done=0 ORDER BY id LIMIT 25", "OnWebQueue");
    return 1;
}

forward OnWebQueue();
public OnWebQueue()
{
    new rows = cache_num_rows();
    for(new r = 0; r < rows; r++)
    {
        new id, cid, val, act[24], txt[128], q[200];
        cache_get_value_name_int(r, "id", id);
        cache_get_value_name_int(r, "char_id", cid);
        cache_get_value_name_int(r, "value", val);
        cache_get_value_name(r, "action", act, sizeof act);
        cache_get_value_name(r, "text", txt, sizeof txt);
        new p = GetPlayerByChar(cid);

        if(!strcmp(act, "GIVE_CASH"))
        {
            if(p != INVALID_PLAYER_ID) { GivePlayerMoney(p, val); P[p][pCash] = GetPlayerMoney(p); }
            else { mysql_format(g_SQL, q, sizeof q, "UPDATE characters SET cash=GREATEST(cash+%d,0) WHERE id=%d", val, cid); mysql_tquery(g_SQL, q); }
        }
        else if(!strcmp(act, "GIVE_BANK"))
        {
            if(p != INVALID_PLAYER_ID) { P[p][pBank] += val; if(P[p][pBank] < 0) P[p][pBank] = 0; }
            else { mysql_format(g_SQL, q, sizeof q, "UPDATE characters SET bank=GREATEST(bank+%d,0) WHERE id=%d", val, cid); mysql_tquery(g_SQL, q); }
            BankLog(cid, "WEB", val, txt);
        }
        else if(!strcmp(act, "SET_JOB") && val >= 0 && val < sizeof gJobName)
        {
            if(p != INVALID_PLAYER_ID) P[p][pJob] = val;
            else { mysql_format(g_SQL, q, sizeof q, "UPDATE characters SET job=%d WHERE id=%d", val, cid); mysql_tquery(g_SQL, q); }
        }
        else if(!strcmp(act, "KICK") && p != INVALID_PLAYER_ID)
        {
            SendClientMessage(p, C_ERR, "Web panelinden sunucudan atildin.");
            KickDelayed(p);
        }
        else if(!strcmp(act, "MSG") && p != INVALID_PLAYER_ID)
        {
            format(q, sizeof q, "[PANEL] %s", txt);
            SendClientMessage(p, C_PURPLE, q);
        }
        mysql_format(g_SQL, q, sizeof q, "UPDATE web_queue SET done=1 WHERE id=%d", id);
        mysql_tquery(g_SQL, q);
    }
    return 1;
}

/* ---------------------------------------------------------------- dialoglar */

public OnDialogResponse(playerid, dialogid, response, listitem, inputtext[])
{
    switch(dialogid)
    {
        case D_LOGIN:
        {
            if(!response) return Kick(playerid);
            new h[65];
            SHA256_PassHash(inputtext, gSalt[playerid], h, sizeof h);
            if(!strcmp(h, gHash[playerid]))
            {
                new q[200], ip[16];
                GetPlayerIp(playerid, ip, sizeof ip);
                mysql_format(g_SQL, q, sizeof q, "UPDATE accounts SET last_login=NOW(), last_ip='%e' WHERE id=%d", ip, P[playerid][pAcc]);
                mysql_tquery(g_SQL, q);
                LoadSlots(playerid);
            }
            else
            {
                if(++P[playerid][pTries] >= 3) { Err(playerid, "3 hatali giris. Sunucudan atildin."); return KickDelayed(playerid); }
                Err(playerid, "Hatali sifre!");
                ShowLogin(playerid);
            }
        }
        case D_REGISTER:
        {
            if(!response) return Kick(playerid);
            if(strlen(inputtext) < 6 || strlen(inputtext) > 32) { Err(playerid, "Sifre 6-32 karakter olmali."); return ShowRegister(playerid); }
            format(P[playerid][pTmpPass], 65, "%s", inputtext);
            ShowPlayerDialog(playerid, D_EMAIL, DIALOG_STYLE_INPUT, "DUKTUR RP - E-posta",
                "{FFFFFF}Hesap kurtarma ve dogrulama icin e-posta adresini gir:", "Kaydol", "Cikis");
        }
        case D_EMAIL:
        {
            if(!response) return Kick(playerid);
            if(strfind(inputtext, "@") < 1 || strfind(inputtext, ".") < 3 || strlen(inputtext) > 99)
            {
                Err(playerid, "Gecerli bir e-posta gir.");
                return ShowPlayerDialog(playerid, D_EMAIL, DIALOG_STYLE_INPUT, "DUKTUR RP - E-posta", "{FFFFFF}E-posta adresin:", "Kaydol", "Cikis");
            }
            new salt[17], name[MAX_PLAYER_NAME], ip[16], q[512];
            for(new i = 0; i < 16; i++) salt[i] = 'A' + random(26);
            salt[16] = 0;
            SHA256_PassHash(P[playerid][pTmpPass], salt, gHash[playerid], 65);
            format(gSalt[playerid], 17, "%s", salt);
            P[playerid][pTmpPass][0] = 0;
            GetPlayerName(playerid, name, sizeof name);
            GetPlayerIp(playerid, ip, sizeof ip);
            mysql_format(g_SQL, q, sizeof q,
                "INSERT INTO accounts (name,pass_hash,salt,email,reg_date,last_login,last_ip) VALUES ('%e','%e','%e','%e',NOW(),NOW(),'%e')",
                name, gHash[playerid], salt, inputtext, ip);
            mysql_tquery(g_SQL, q, "OnAccountRegistered", "d", playerid);
        }
        case D_SLOTS:
        {
            if(!response) return Kick(playerid);
            P[playerid][pSlot] = listitem + 1;
            if(gSlotId[playerid][listitem]) LoadCharacter(playerid, gSlotId[playerid][listitem]);
            else ShowPlayerDialog(playerid, D_C_FNAME, DIALOG_STYLE_INPUT, "Karakter - Ad",
                "{FFFFFF}Karakter adini gir (Roleplay kurallarina uygun, orn: Ahmet):", "Devam", "Geri");
        }
        case D_C_FNAME:
        {
            if(!response) return ShowSlots(playerid);
            if(!ValidName(inputtext)) { Err(playerid, "Ad 3-15 harf, ilk harf buyuk, Turkce karakter/rakam yok."); return ShowPlayerDialog(playerid, D_C_FNAME, DIALOG_STYLE_INPUT, "Karakter - Ad", "{FFFFFF}Karakter adini gir:", "Devam", "Geri"); }
            format(P[playerid][pTmpF], 24, "%s", inputtext);
            ShowPlayerDialog(playerid, D_C_LNAME, DIALOG_STYLE_INPUT, "Karakter - Soyad", "{FFFFFF}Karakter soyadini gir:", "Devam", "Geri");
        }
        case D_C_LNAME:
        {
            if(!response) return ShowPlayerDialog(playerid, D_C_FNAME, DIALOG_STYLE_INPUT, "Karakter - Ad", "{FFFFFF}Karakter adini gir:", "Devam", "Geri");
            if(!ValidName(inputtext)) { Err(playerid, "Soyad 3-15 harf, ilk harf buyuk olmali."); return ShowPlayerDialog(playerid, D_C_LNAME, DIALOG_STYLE_INPUT, "Karakter - Soyad", "{FFFFFF}Karakter soyadini gir:", "Devam", "Geri"); }
            format(P[playerid][pTmpL], 24, "%s", inputtext);
            new q[160];
            mysql_format(g_SQL, q, sizeof q, "SELECT id FROM characters WHERE fname='%e' AND lname='%e' LIMIT 1", P[playerid][pTmpF], P[playerid][pTmpL]);
            mysql_tquery(g_SQL, q, "OnNameChecked", "d", playerid);
        }
        case D_C_AGE:
        {
            if(!response) return ShowPlayerDialog(playerid, D_C_FNAME, DIALOG_STYLE_INPUT, "Karakter - Ad", "{FFFFFF}Karakter adini gir:", "Devam", "Geri");
            new age = strval(inputtext);
            if(age < 18 || age > 80) { Err(playerid, "Yas 18 ile 80 arasinda olmali."); return ShowPlayerDialog(playerid, D_C_AGE, DIALOG_STYLE_INPUT, "Karakter - Yas", "{FFFFFF}Karakter yasi (18 - 80):", "Devam", "Geri"); }
            P[playerid][pTmpAge] = age;
            ShowPlayerDialog(playerid, D_C_GENDER, DIALOG_STYLE_LIST, "Karakter - Cinsiyet", "Erkek\nKadin", "Devam", "Geri");
        }
        case D_C_GENDER:
        {
            if(!response) return ShowPlayerDialog(playerid, D_C_AGE, DIALOG_STYLE_INPUT, "Karakter - Yas", "{FFFFFF}Karakter yasi (18 - 80):", "Devam", "Geri");
            P[playerid][pTmpG] = listitem + 1;
            ShowPlayerDialog(playerid, D_C_SKIN, DIALOG_STYLE_INPUT, "Karakter - Gorunum",
                "{FFFFFF}Skin ID gir (0-311).\nErkek ornek: 60, 29, 170 | Kadin ornek: 9, 41, 55", "Olustur", "Geri");
        }
        case D_C_SKIN:
        {
            if(!response) return ShowPlayerDialog(playerid, D_C_GENDER, DIALOG_STYLE_LIST, "Karakter - Cinsiyet", "Erkek\nKadin", "Devam", "Geri");
            new skin = strval(inputtext);
            if(!ValidSkin(skin)) return Err(playerid, "Gecersiz skin ID."), ShowPlayerDialog(playerid, D_C_SKIN, DIALOG_STYLE_INPUT, "Karakter - Gorunum", "{FFFFFF}Skin ID gir (0-311):", "Olustur", "Geri");
            new q[700];
            mysql_format(g_SQL, q, sizeof q,
                "INSERT INTO characters (account_id,slot,fname,lname,age,gender,skin,phone,iban,x,y,z,a,created) VALUES (%d,%d,'%e','%e',%d,%d,%d,%d,'DRP%08d',1642.0,-2333.0,13.5,0.0,NOW())",
                P[playerid][pAcc], P[playerid][pSlot], P[playerid][pTmpF], P[playerid][pTmpL],
                P[playerid][pTmpAge], P[playerid][pTmpG], skin, 500000 + random(499999), random(99999999));
            mysql_tquery(g_SQL, q, "OnCharCreated", "d", playerid);
        }
        case D_BANK:
        {
            if(!response) return 1;
            switch(listitem)
            {
                case 0:
                {
                    new s[128];
                    format(s, sizeof s, "{FFFFFF}Banka Bakiyesi: {66FF99}$%d\n{FFFFFF}Nakit: {66FF99}$%d\n{FFFFFF}IBAN: {B266FF}%s", P[playerid][pBank], GetPlayerMoney(playerid), P[playerid][pIban]);
                    ShowPlayerDialog(playerid, D_INFO, DIALOG_STYLE_MSGBOX, "Hesap Bilgisi", s, "Tamam", "");
                }
                case 1: ShowPlayerDialog(playerid, D_BANK_DEP, DIALOG_STYLE_INPUT, "Para Yatir", "{FFFFFF}Yatirilacak miktar:", "Yatir", "Iptal");
                case 2: ShowPlayerDialog(playerid, D_BANK_WD, DIALOG_STYLE_INPUT, "Para Cek", "{FFFFFF}Cekilecek miktar:", "Cek", "Iptal");
                case 3: ShowPlayerDialog(playerid, D_BANK_IBAN, DIALOG_STYLE_INPUT, "Transfer", "{FFFFFF}Alicinin IBAN'i (orn: DRP01234567):", "Devam", "Iptal");
                case 4:
                {
                    new q[200];
                    mysql_format(g_SQL, q, sizeof q, "SELECT type,amount,description,created FROM bank_log WHERE char_id=%d ORDER BY id DESC LIMIT 10", P[playerid][pChar]);
                    mysql_tquery(g_SQL, q, "OnBankHistory", "d", playerid);
                }
            }
        }
        case D_BANK_DEP:
        {
            if(!response) return 1;
            new amt = strval(inputtext);
            if(amt <= 0 || amt > GetPlayerMoney(playerid)) return Err(playerid, "Gecersiz miktar veya yeterli nakdin yok.");
            GivePlayerMoney(playerid, -amt);
            P[playerid][pBank] += amt;
            BankLog(P[playerid][pChar], "YATIRMA", amt, "Nakit yatirma");
            Ok(playerid, "Para bankaya yatirildi.");
        }
        case D_BANK_WD:
        {
            if(!response) return 1;
            new amt = strval(inputtext);
            if(amt <= 0 || amt > P[playerid][pBank]) return Err(playerid, "Gecersiz miktar veya yeterli bakiyen yok.");
            P[playerid][pBank] -= amt;
            GivePlayerMoney(playerid, amt);
            BankLog(P[playerid][pChar], "CEKME", -amt, "Nakit cekme");
            Ok(playerid, "Para cekildi.");
        }
        case D_BANK_IBAN:
        {
            if(!response) return 1;
            if(strlen(inputtext) < 5 || strlen(inputtext) > 16 || !strcmp(inputtext, P[playerid][pIban])) return Err(playerid, "Gecersiz IBAN.");
            format(P[playerid][pTransferIban], 20, "%s", inputtext);
            ShowPlayerDialog(playerid, D_BANK_AMT, DIALOG_STYLE_INPUT, "Transfer", "{FFFFFF}Gonderilecek miktar:", "Gonder", "Iptal");
        }
        case D_BANK_AMT:
        {
            if(!response) return 1;
            new amt = strval(inputtext);
            if(amt <= 0 || amt > P[playerid][pBank]) return Err(playerid, "Gecersiz miktar veya yeterli bakiyen yok.");
            P[playerid][pBank] -= amt;     // once dus, basarisiz olursa iade edilir
            new t = INVALID_PLAYER_ID;
            for(new i = 0; i < MAX_PLAYERS; i++)
                if(IsPlayerConnected(i) && P[i][pLogged] && !strcmp(P[i][pIban], P[playerid][pTransferIban])) { t = i; break; }
            if(t != INVALID_PLAYER_ID)
            {
                P[t][pBank] += amt;
                new s[96];
                format(s, sizeof s, "[BANKA] Hesabina $%d transfer edildi.", amt);
                SendClientMessage(t, C_OK, s);
                BankLog(P[playerid][pChar], "TRANSFER", -amt, P[playerid][pTransferIban]);
                BankLog(P[t][pChar], "TRANSFER", amt, P[playerid][pIban]);
                Ok(playerid, "Transfer tamamlandi.");
            }
            else
            {
                new q[200];
                mysql_format(g_SQL, q, sizeof q, "UPDATE characters SET bank=bank+%d WHERE iban='%e'", amt, P[playerid][pTransferIban]);
                mysql_tquery(g_SQL, q, "OnTransferOffline", "dds", playerid, amt, P[playerid][pTransferIban]);
            }
        }
        case D_REP_TYPE:
        {
            if(!response) return 1;
            P[playerid][pRepType] = listitem;
            ShowPlayerDialog(playerid, D_REP_TEXT, DIALOG_STYLE_INPUT, gRepTypes[listitem],
                "{FFFFFF}Raporunu detayli yaz. Kanit gorselini web panelinden ekleyebilirsin:", "Gonder", "Iptal");
        }
        case D_REP_TEXT:
        {
            if(!response) return 1;
            if(strlen(inputtext) < 10) return Err(playerid, "Rapor en az 10 karakter olmali.");
            new q[600], subj[64];
            format(subj, sizeof subj, "%s (oyun ici)", gRepTypes[P[playerid][pRepType]]);
            mysql_format(g_SQL, q, sizeof q,
                "INSERT INTO reports (account_id,char_id,type,subject,body,status,created) VALUES (%d,%d,'%e','%e','%e','Beklemede',NOW())",
                P[playerid][pAcc], P[playerid][pChar], gRepTypes[P[playerid][pRepType]], subj, inputtext);
            mysql_tquery(g_SQL, q, "OnReportCreated", "d", playerid);
        }
    }
    return 1;
}

forward OnTransferOffline(playerid, amount, const iban[]);
public OnTransferOffline(playerid, amount, const iban[])
{
    if(!IsPlayerConnected(playerid)) return 1;
    if(cache_affected_rows() == 0)
    {
        P[playerid][pBank] += amount;   // iade
        Err(playerid, "Bu IBAN'a ait hesap bulunamadi. Para iade edildi.");
        return 1;
    }
    BankLog(P[playerid][pChar], "TRANSFER", -amount, iban);
    Ok(playerid, "Transfer tamamlandi.");
    return 1;
}

forward OnBankHistory(playerid);
public OnBankHistory(playerid)
{
    new s[1024] = "Islem\tTutar\tAciklama\tTarih\n", rows = cache_num_rows(), t[24], d[100], c[24], amt, line[200];
    for(new r = 0; r < rows; r++)
    {
        cache_get_value_name(r, "type", t, sizeof t);
        cache_get_value_name_int(r, "amount", amt);
        cache_get_value_name(r, "description", d, sizeof d);
        cache_get_value_name(r, "created", c, sizeof c);
        format(line, sizeof line, "%s\t$%d\t%s\t%s\n", t, amt, d, c);
        strcat(s, line);
    }
    ShowPlayerDialog(playerid, D_INFO, DIALOG_STYLE_TABLIST_HEADERS, "Hesap Hareketleri", s, "Kapat", "");
    return 1;
}

forward OnReportCreated(playerid);
public OnReportCreated(playerid)
{
    new id = cache_insert_id(), s[128];
    format(s, sizeof s, "Raporun alindi. Rapor No: #DRP-%05d. Durumu web panelinden takip edebilirsin.", id);
    Ok(playerid, s);
    format(s, sizeof s, "[RAPOR] Yeni rapor #DRP-%05d (%s)", id, gRepTypes[P[playerid][pRepType]]);
    for(new i = 0; i < MAX_PLAYERS; i++)
        if(IsPlayerConnected(i) && P[i][pLogged] && IsAdmin(i, 1)) SendClientMessage(i, C_PURPLE, s);
    return 1;
}

forward OnInventory(playerid);
public OnInventory(playerid)
{
    new s[1024] = "Esya\tMiktar\n", rows = cache_num_rows(), item[40], amt, line[80];
    for(new r = 0; r < rows; r++)
    {
        cache_get_value_name(r, "item", item, sizeof item);
        cache_get_value_name_int(r, "amount", amt);
        format(line, sizeof line, "%s\t%d\n", item, amt);
        strcat(s, line);
    }
    if(!rows) strcat(s, "Envanterin bos\t-\n");
    ShowPlayerDialog(playerid, D_INFO, DIALOG_STYLE_TABLIST_HEADERS, "Envanter", s, "Kapat", "");
    return 1;
}

forward OnMyVehicles(playerid);
public OnMyVehicles(playerid)
{
    new s[600] = "Model\tPlaka\n", rows = cache_num_rows(), model, plate[12], line[64];
    for(new r = 0; r < rows; r++)
    {
        cache_get_value_name_int(r, "model", model);
        cache_get_value_name(r, "plate", plate, sizeof plate);
        format(line, sizeof line, "%d\t%s\n", model, plate);
        strcat(s, line);
    }
    if(!rows) strcat(s, "Aracin yok\t-\n");
    ShowPlayerDialog(playerid, D_INFO, DIALOG_STYLE_TABLIST_HEADERS, "Araclarim", s, "Kapat", "");
    return 1;
}

forward OnMyPunish(playerid);
public OnMyPunish(playerid)
{
    new s[1200] = "Tur\tSebep\tYetkili\tTarih\n", rows = cache_num_rows(), t[10], rs[100], ad[24], c[24], line[200];
    for(new r = 0; r < rows; r++)
    {
        cache_get_value_name(r, "type", t, sizeof t);
        cache_get_value_name(r, "reason", rs, sizeof rs);
        cache_get_value_name(r, "admin_name", ad, sizeof ad);
        cache_get_value_name(r, "created", c, sizeof c);
        format(line, sizeof line, "%s\t%s\t%s\t%s\n", t, rs, ad, c);
        strcat(s, line);
    }
    if(!rows) strcat(s, "Temiz sicil\t-\t-\t-\n");
    ShowPlayerDialog(playerid, D_INFO, DIALOG_STYLE_TABLIST_HEADERS, "Ceza Gecmisim", s, "Kapat", "");
    return 1;
}

/* ---------------------------------------------------------------- komutlar */

CMD:yardim(playerid, params[])
{
    SendClientMessage(playerid, C_PURPLE, "=== DUKTUR RP ===");
    SendClientMessage(playerid, C_WHITE, "/stats /banka /telefon /sms /envanter /meslek /araclarim /evlerim /evsatinal /evsat");
    SendClientMessage(playerid, C_WHITE, "/rapor /cezalarim /me /do /b /panel");
    return 1;
}

CMD:panel(playerid, params[])
{
    new s[96];
    format(s, sizeof s, "Oyuncu paneli: %s", PANEL_URL);
    return SendClientMessage(playerid, C_PURPLE, s);
}

CMD:stats(playerid, params[])
{
    new s[600];
    format(s, sizeof s,
        "{FFFFFF}Karakter: {B266FF}%s %s\n{FFFFFF}Yas: %d\nSeviye: %d\nOyun Suresi: %d saat %d dk\nMeslek: %s\nNakit: $%d\nBanka: $%d\nTelefon: %d\nIBAN: %s",
        P[playerid][pFName], P[playerid][pLName], P[playerid][pAge], P[playerid][pLevel],
        P[playerid][pPlay] / 60, P[playerid][pPlay] % 60, gJobName[P[playerid][pJob]],
        GetPlayerMoney(playerid), P[playerid][pBank], P[playerid][pPhone], P[playerid][pIban]);
    return ShowPlayerDialog(playerid, D_INFO, DIALOG_STYLE_MSGBOX, "Karakter Bilgileri", s, "Kapat", "");
}

CMD:banka(playerid, params[])
{
    return ShowPlayerDialog(playerid, D_BANK, DIALOG_STYLE_LIST, "DUKTUR Bank",
        "Bakiye Sorgula\nPara Yatir\nPara Cek\nIBAN ile Transfer\nHesap Hareketleri", "Sec", "Kapat");
}

CMD:telefon(playerid, params[])
{
    new s[64];
    format(s, sizeof s, "Telefon numaran: %d  |  /sms [numara] [mesaj]", P[playerid][pPhone]);
    return SendClientMessage(playerid, C_PURPLE, s);
}

CMD:sms(playerid, params[])
{
    new num, msg[100];
    if(sscanf(params, "ds[100]", num, msg)) return Err(playerid, "Kullanim: /sms [numara] [mesaj]");
    new t = INVALID_PLAYER_ID, s[160], q[300];
    for(new i = 0; i < MAX_PLAYERS; i++)
        if(IsPlayerConnected(i) && P[i][pLogged] && P[i][pPhone] == num) { t = i; break; }
    mysql_format(g_SQL, q, sizeof q, "INSERT INTO sms_log (from_phone,to_phone,message,created) VALUES (%d,%d,'%e',NOW())", P[playerid][pPhone], num, msg);
    mysql_tquery(g_SQL, q);
    format(s, sizeof s, "[SMS -> %d] %s", num, msg);
    SendClientMessage(playerid, C_OK, s);
    if(t != INVALID_PLAYER_ID)
    {
        format(s, sizeof s, "[SMS <- %d] %s", P[playerid][pPhone], msg);
        SendClientMessage(t, C_OK, s);
    }
    return 1;
}

CMD:envanter(playerid, params[])
{
    new q[160];
    mysql_format(g_SQL, q, sizeof q, "SELECT item,amount FROM inventory WHERE char_id=%d AND amount>0 ORDER BY item", P[playerid][pChar]);
    return mysql_tquery(g_SQL, q, "OnInventory", "d", playerid);
}

CMD:meslek(playerid, params[])
{
    new s[600], line[80];
    for(new i = 0; i < sizeof gJobName; i++)
    {
        format(line, sizeof line, "{FFFFFF}%s - {66FF99}$%d/saat\n", gJobName[i], gJobPay[i]);
        strcat(s, line);
    }
    strcat(s, "\n{B266FF}Basvuru icin web panelindeki Basvuru Merkezi'ni kullan.");
    return ShowPlayerDialog(playerid, D_INFO, DIALOG_STYLE_MSGBOX, "Meslekler", s, "Kapat", "");
}

CMD:araclarim(playerid, params[])
{
    new q[160];
    mysql_format(g_SQL, q, sizeof q, "SELECT model,plate FROM vehicles WHERE char_id=%d", P[playerid][pChar]);
    return mysql_tquery(g_SQL, q, "OnMyVehicles", "d", playerid);
}

CMD:evlerim(playerid, params[])
{
    new s[400], line[96], c;
    for(new h = 0; h < gHouseCount; h++)
        if(gHouseOwner[h] == P[playerid][pChar]) { format(line, sizeof line, "Ev #%d - %s\n", gHouseId[h], gHouseAddr[h]); strcat(s, line); c++; }
    if(!c) return Err(playerid, "Hic evin yok.");
    return ShowPlayerDialog(playerid, D_INFO, DIALOG_STYLE_MSGBOX, "Evlerim", s, "Kapat", "");
}

CMD:evsatinal(playerid, params[])
{
    new h = NearHouse(playerid);
    if(h == -1) return Err(playerid, "Bir evin yaninda degilsin.");
    if(gHouseOwner[h]) return Err(playerid, "Bu ev satilik degil.");
    if(GetPlayerMoney(playerid) < gHousePrice[h]) return Err(playerid, "Yeterli nakdin yok.");
    GivePlayerMoney(playerid, -gHousePrice[h]);
    gHouseOwner[h] = P[playerid][pChar];
    UpdateHouse(h);
    new q[120];
    mysql_format(g_SQL, q, sizeof q, "UPDATE houses SET owner_char=%d WHERE id=%d", gHouseOwner[h], gHouseId[h]);
    mysql_tquery(g_SQL, q);
    BankLog(P[playerid][pChar], "EV ALIM", -gHousePrice[h], gHouseAddr[h]);
    return Ok(playerid, "Evi satin aldin!");
}

CMD:evsat(playerid, params[])
{
    new h = NearHouse(playerid);
    if(h == -1 || gHouseOwner[h] != P[playerid][pChar]) return Err(playerid, "Sahibi oldugun bir evin yaninda degilsin.");
    new refund = gHousePrice[h] * 70 / 100, q[120];
    P[playerid][pBank] += refund;
    gHouseOwner[h] = 0;
    UpdateHouse(h);
    mysql_format(g_SQL, q, sizeof q, "UPDATE houses SET owner_char=0 WHERE id=%d", gHouseId[h]);
    mysql_tquery(g_SQL, q);
    BankLog(P[playerid][pChar], "EV SATIS", refund, gHouseAddr[h]);
    return Ok(playerid, "Evi devlete sattin, bedel bankana yatirildi.");
}

CMD:rapor(playerid, params[])
{
    new s[400], line[48];
    for(new i = 0; i < sizeof gRepTypes; i++) { format(line, sizeof line, "%s\n", gRepTypes[i]); strcat(s, line); }
    return ShowPlayerDialog(playerid, D_REP_TYPE, DIALOG_STYLE_LIST, "Rapor / Destek Merkezi", s, "Sec", "Kapat");
}

CMD:cezalarim(playerid, params[])
{
    new q[200];
    mysql_format(g_SQL, q, sizeof q, "SELECT type,reason,admin_name,created FROM punishments WHERE account_id=%d ORDER BY id DESC LIMIT 10", P[playerid][pAcc]);
    return mysql_tquery(g_SQL, q, "OnMyPunish", "d", playerid);
}

CMD:me(playerid, params[])
{
    if(isnull(params)) return Err(playerid, "Kullanim: /me [eylem]");
    new s[160], Float:x, Float:y, Float:z;
    GetPlayerPos(playerid, x, y, z);
    format(s, sizeof s, "* %s %s %s", P[playerid][pFName], P[playerid][pLName], params);
    for(new i = 0; i < MAX_PLAYERS; i++)
        if(IsPlayerConnected(i) && P[i][pLogged] && IsPlayerInRangeOfPoint(i, 20.0, x, y, z)) SendClientMessage(i, C_RP, s);
    return 1;
}

CMD:do(playerid, params[])
{
    if(isnull(params)) return Err(playerid, "Kullanim: /do [durum]");
    new s[160], Float:x, Float:y, Float:z;
    GetPlayerPos(playerid, x, y, z);
    format(s, sizeof s, "* %s (( %s %s ))", params, P[playerid][pFName], P[playerid][pLName]);
    for(new i = 0; i < MAX_PLAYERS; i++)
        if(IsPlayerConnected(i) && P[i][pLogged] && IsPlayerInRangeOfPoint(i, 20.0, x, y, z)) SendClientMessage(i, C_RP, s);
    return 1;
}

CMD:b(playerid, params[])
{
    if(isnull(params)) return Err(playerid, "Kullanim: /b [mesaj]");
    new s[160], Float:x, Float:y, Float:z;
    GetPlayerPos(playerid, x, y, z);
    format(s, sizeof s, "(( %s: %s ))", P[playerid][pFName], params);
    for(new i = 0; i < MAX_PLAYERS; i++)
        if(IsPlayerConnected(i) && P[i][pLogged] && IsPlayerInRangeOfPoint(i, 20.0, x, y, z)) SendClientMessage(i, 0xAAAAAAFF, s);
    return 1;
}

/* ---- yetkili komutlari ---- */

CMD:warn(playerid, params[])
{
    if(!IsAdmin(playerid, 1)) return 0;
    new t, reason[64], an[MAX_PLAYER_NAME], s[128];
    if(sscanf(params, "us[64]", t, reason)) return Err(playerid, "Kullanim: /warn [id] [sebep]");
    if(!IsPlayerConnected(t) || !P[t][pLogged]) return Err(playerid, "Oyuncu bulunamadi.");
    GetPlayerName(playerid, an, sizeof an);
    Punish(t, "WARN", reason, an);
    format(s, sizeof s, "[UYARI] %s tarafindan uyarildin: %s", an, reason);
    return SendClientMessage(t, C_ERR, s);
}

CMD:kick(playerid, params[])
{
    if(!IsAdmin(playerid, 1)) return 0;
    new t, reason[64], an[MAX_PLAYER_NAME], s[128];
    if(sscanf(params, "us[64]", t, reason)) return Err(playerid, "Kullanim: /kick [id] [sebep]");
    if(!IsPlayerConnected(t) || !P[t][pLogged]) return Err(playerid, "Oyuncu bulunamadi.");
    GetPlayerName(playerid, an, sizeof an);
    Punish(t, "KICK", reason, an);
    format(s, sizeof s, "[KICK] %s atildi. Sebep: %s", P[t][pFName], reason);
    SendClientMessageToAll(C_ERR, s);
    return KickDelayed(t);
}

CMD:ban(playerid, params[])
{
    if(!IsAdmin(playerid, 2)) return 0;
    new t, reason[64], an[MAX_PLAYER_NAME], s[128], q[120];
    if(sscanf(params, "us[64]", t, reason)) return Err(playerid, "Kullanim: /ban [id] [sebep]");
    if(!IsPlayerConnected(t) || !P[t][pLogged]) return Err(playerid, "Oyuncu bulunamadi.");
    GetPlayerName(playerid, an, sizeof an);
    Punish(t, "BAN", reason, an);
    mysql_format(g_SQL, q, sizeof q, "UPDATE accounts SET status=1 WHERE id=%d", P[t][pAcc]);
    mysql_tquery(g_SQL, q);
    format(s, sizeof s, "[BAN] %s yasaklandi. Sebep: %s", P[t][pFName], reason);
    SendClientMessageToAll(C_ERR, s);
    return KickDelayed(t);
}
