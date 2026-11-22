/*
=====================================================================
  ULTIMATE ADMIN PANEL v3.0
  Sadece <a_samp> gerektirir (zcmd / sscanf / dini YOK).

  KURULUM
   1) pawno ile derle  ->  filterscripts/ultimate_admin.amx
   2) server.cfg:  filterscripts ultimate_admin
   3) scriptfiles/ klasoru sunucuda olmali (dosyalar otomatik olusur)
   4) /rcon login <sifre>  ->  /setadmin <id> 8   (ilk Owner)

  DOSYALAR (scriptfiles/): uap_admins.txt, uap_bans.txt, uap_log.txt,
                           uap_perms.txt, uap_locs.txt
  Tum yetki kontrolleri SUNUCU tarafinda ExecCmd() icinde yapilir.
  Panel butonlari da ayni ExecCmd() uzerinden calisir.
=====================================================================
*/
#define FILTERSCRIPT
#include <a_samp>
#pragma dynamic 24576
#pragma tabsize 0

#define MAX_LVL      8
#define MAX_CMDS     64
#define MAX_REPORTS  20
#define MAX_LOCS     40
#define RECENT_N     5
#define RECENT_LEN   80
#define LOG_LINES    12
#define CMD_PAGE     18
#define IP_LEVEL     4

#define F_ADMINS "uap_admins.txt"
#define F_BANS   "uap_bans.txt"
#define F_LOG    "uap_log.txt"
#define F_PERMS  "uap_perms.txt"
#define F_LOCS   "uap_locs.txt"

#define D_PLAYERS 9501
#define D_PACT    9502
#define D_INPUT   9503
#define D_CONFIRM 9504
#define D_MOD     9505
#define D_VEH     9506
#define D_TP      9507
#define D_SRV     9508
#define D_CMDS    9509
#define D_VIEW    9510
#define D_REPORTS 9511
#define D_LOCS    9512
#define D_SEARCH  9513
#define D_MAIN    9514
#define DUTY_SKIN 17

#define IS(%0) (!strcmp(cmd, %0, true))

forward ExecCmd(playerid, const line[]);
forward OpenPanel(playerid);
forward HidePanel(playerid);
forward ShowPlayers(playerid);
forward ShowLog(playerid);
forward ShowCmdPage(playerid, page);
forward ShowConfirm(playerid, const cmdline[]);
forward AskInput(playerid, const title[], const msg[], const prefix[], confirm);
forward UAP_Tick();
forward UAP_Fly();
forward UAP_Kick(playerid);

// ------------------------------------------------------------------
//  RUTBELER VE KOMUT TABLOSU  ("<seviye><isim> <parametreler>|<aciklama>")
// ------------------------------------------------------------------
new const gRank[][] =
{
    "Oyuncu", "Support", "Moderator", "Admin", "Senior Admin",
    "Head Admin", "Manager", "Founder", "Owner"
};

new const gCmdTbl[][] =
{
    "1ahelp|Admin yardimi",
    "1admin|Admin panelini acar",
    "1duty|Admin gorevi: olumsuz + takim elbise + kirmizi ADMIN",
    "1players|Online oyuncu listesi",
    "1goto [id/isim]|Oyuncuya isinlanir",
    "1gotoid [id]|Oyuncuya isinlanir (ID)",
    "2gethere [id/isim]|Oyuncuyu yanina ceker",
    "2bring [id/isim]|Oyuncuyu yanina ceker",
    "4tp [x] [y] [z] [interior]|Koordinata isinlanir",
    "2back|Isinlanma oncesi konuma doner",
    "3revive [id/isim]|Oyuncuyu canlandirir",
    "2heal [id/isim]|Cani 100 yapar",
    "2armor [id/isim]|Zirhi 100 yapar",
    "4god|God mode ac/kapa",
    "5noclip|Hizli ucus (noclip) ac/kapa",
    "4fly|Jetpack ac/kapa",
    "4invisible|Isim etiketi ve harita isaretini gizle",
    "4infammo|Sinirsiz mermi ac/kapa",
    "2freeze [id/isim]|Oyuncuyu dondurur",
    "2unfreeze [id/isim]|Dondurmayi kaldirir",
    "1spectate [id/isim]|Oyuncuyu izler",
    "1unspectate|Izlemeyi birakir",
    "2kick [id/isim] [sebep]|Oyuncuyu atar",
    "4ban [id/isim] [sebep]|Kalici ban",
    "3tempban [id/isim] [dakika] [sebep]|Gecici ban",
    "4unban [isim/ip]|Ban kaldirir",
    "2mute [id/isim] [dakika] [sebep]|Susturur (0=kalici)",
    "2unmute [id/isim]|Susturmayi kaldirir",
    "3jail [id/isim] [dakika] [sebep]|Hapse atar",
    "3unjail [id/isim]|Hapisten cikarir",
    "2warn [id/isim] [sebep]|Uyari verir (3 uyari = kick)",
    "1apm [id/isim] [mesaj]|Oyuncuya admin ozel mesaji",
    "1reports|Acik sikayetleri listeler",
    "1acceptreport [no]|Sikayeti kabul eder",
    "1denyreport [no] [sebep]|Sikayeti reddeder",
    "0report [id/isim] [sebep]|Oyuncuyu admine sikayet eder",
    "4veh [model] [renk1] [renk2]|Arac olusturur",
    "3vehdel|Icinde oldugun /veh aracini siler",
    "4vcolor [renk1] [renk2]|Arac rengini degistirir",
    "4vgod|Arac god mode ac/kapa",
    "3repair [id/isim]|Araci tamir eder",
    "3flip [id/isim]|Araci duzeltir",
    "4giveweapon [id/isim] [silah] [mermi]|Silah verir",
    "3sethealth [id/isim] [0-100]|Can ayarlar",
    "3setarmor [id/isim] [0-100]|Zirh ayarlar",
    "4setskin [id/isim] [skin]|Skin degistirir",
    "6setmoney [id/isim] [miktar]|Para ayarlar",
    "5settime [saat]|Dunya saatini ayarlar",
    "5setweather [id]|Hava durumunu ayarlar",
    "4setvw [id/isim] [vw]|Virtual world ayarlar",
    "4setinterior [id/isim] [interior]|Interior ayarlar",
    "3announce [mesaj]|Duyuru yapar",
    "0admins|Online adminleri gosterir",
    "1acmds|Yetkine uygun komutlar",
    "5adminlog|Son admin islemleri",
    "1coords|Koordinatini gosterir",
    "2savepos [isim]|Konumu kaydeder",
    "3clearchat|Sohbeti temizler",
    "7setadmin [id/isim] [0-8]|Admin rutbesi verir",
    "7setperm [komut] [seviye]|Komut yetkisini degistirir"
};

// ------------------------------------------------------------------
//  GLOBAL DEGISKENLER
// ------------------------------------------------------------------
new gLvl[MAX_CMDS];
new gLevel[MAX_PLAYERS], gGod[MAX_PLAYERS], gFly[MAX_PLAYERS], gInvis[MAX_PLAYERS];
new gInfAmmo[MAX_PLAYERS], gVGod[MAX_PLAYERS], gSpec[MAX_PLAYERS], gSpecBack[MAX_PLAYERS];
new gMuteUntil[MAX_PLAYERS], gJailUntil[MAX_PLAYERS], gWarns[MAX_PLAYERS], gJoin[MAX_PLAYERS];
new gSel[MAX_PLAYERS], gPanel[MAX_PLAYERS], gCmdPage[MAX_PLAYERS], gPendConf[MAX_PLAYERS];
new gDead[MAX_PLAYERS], gRevive[MAX_PLAYERS], gLastRep[MAX_PLAYERS], gOldColor[MAX_PLAYERS];
new Float:gLast[MAX_PLAYERS][3], gLastInt[MAX_PLAYERS], gLastVW[MAX_PLAYERS];
new Float:gDeadPos[MAX_PLAYERS][3], gDeadInt[MAX_PLAYERS];
new gPendLine[MAX_PLAYERS][128], gFilter[MAX_PLAYERS][24];
new gVehMade[MAX_VEHICLES + 1];
new gDuty[MAX_PLAYERS], gDutySkin[MAX_PLAYERS], Text3D:gDutyLbl[MAX_PLAYERS];

new gRepActive[MAX_REPORTS], gRepTime[MAX_REPORTS];
new gRepFrom[MAX_REPORTS][MAX_PLAYER_NAME], gRepTarget[MAX_REPORTS][MAX_PLAYER_NAME], gRepText[MAX_REPORTS][64];

new gLocName[MAX_LOCS][24], Float:gLocPos[MAX_LOCS][3], gLocInt[MAX_LOCS], gLocCount;
new gRecent[RECENT_N][RECENT_LEN];
new gStart, gBanCount, gHour = 12, gWeather = 10, gTmrTick, gTmrFly;

new Text:gTDBg, Text:gTDBar, Text:gTDTitle, Text:gTDSub, Text:gTDClock, Text:gTDRecentLbl, Text:gTDRecent;
new Text:gTDCard[6], Text:gTDLbl[6], Text:gTDVal[6], Text:gTDBtn[8];
new PlayerText:gPTDProf[MAX_PLAYERS];

// ------------------------------------------------------------------
//  YARDIMCI FONKSIYONLAR
// ------------------------------------------------------------------
stock Err(playerid, const t[]) { new s[144]; format(s, sizeof s, "{F87171}[HATA] {FFFFFF}%s", t); SendClientMessage(playerid, -1, s); return 1; }
stock Okm(playerid, const t[]) { new s[144]; format(s, sizeof s, "{4ADE80}[OK] {FFFFFF}%s", t); SendClientMessage(playerid, -1, s); return 1; }
stock Inf(playerid, const t[]) { new s[144]; format(s, sizeof s, "{A855F7}[ADMIN] {E9D5FF}%s", t); SendClientMessage(playerid, -1, s); return 1; }

stock IsNum(const s[])
{
    if (!s[0]) return 0;
    for (new i = 0; s[i]; i++)
    {
        if (s[i] < '0' || s[i] > '9') return 0;
    }
    return 1;
}

stock UFind(const s[])
{
    if (!s[0]) return INVALID_PLAYER_ID;
    if (IsNum(s))
    {
        new id = strval(s);
        if (id >= 0 && id < MAX_PLAYERS && IsPlayerConnected(id)) return id;
        return INVALID_PLAYER_ID;
    }
    new n[MAX_PLAYER_NAME], found = INVALID_PLAYER_ID;
    for (new i = 0; i < MAX_PLAYERS; i++)
    {
        if (!IsPlayerConnected(i)) continue;
        GetPlayerName(i, n, sizeof n);
        if (!strcmp(n, s, true)) return i;
        if (found == INVALID_PLAYER_ID && strfind(n, s, true) != -1) found = i;
    }
    return found;
}

stock UTok(const s[], &pos, dest[], size = sizeof dest)
{
    while (s[pos] == ' ') pos++;
    new i = 0;
    while (s[pos] && s[pos] != ' ' && i < size - 1) { dest[i++] = s[pos++]; }
    dest[i] = 0;
    return i;
}

stock URest(const s[], pos, dest[], size = sizeof dest)
{
    while (s[pos] == ' ') pos++;
    strmid(dest, s, pos, strlen(s), size);
    return strlen(dest);
}

stock GetField(const src[], index, dest[], size = sizeof dest)
{
    new cur = 0, start = 0, len = strlen(src);
    for (new i = 0; i <= len; i++)
    {
        if (src[i] == '|' || src[i] == 0)
        {
            if (cur == index) { strmid(dest, src, start, i, size); return 1; }
            cur++;
            start = i + 1;
        }
    }
    dest[0] = 0;
    return 0;
}

stock ReplaceBar(str[])
{
    for (new i = 0; str[i]; i++) { if (str[i] == '|') str[i] = '/'; }
}

stock ReadLine(File:f, line[], size = sizeof line)
{
    if (!fread(f, line, size)) return 0;
    new l = strlen(line);
    while (l > 0 && (line[l - 1] == '\n' || line[l - 1] == '\r')) { line[--l] = 0; }
    return 1;
}

stock CopyFile(const src[], const dst[])
{
    new File:a = fopen(src, io_read);
    if (!a) return 0;
    new File:b = fopen(dst, io_write);
    if (!b) { fclose(a); return 0; }
    new line[256];
    while (ReadLine(a, line)) { fwrite(b, line); fwrite(b, "\r\n"); }
    fclose(a);
    fclose(b);
    return 1;
}

stock Lvl(playerid)
{
    if (IsPlayerAdmin(playerid)) return MAX_LVL;
    return gLevel[playerid];
}

stock CmdName(idx, dest[], size = sizeof dest)
{
    new i = 1;
    while (gCmdTbl[idx][i] && gCmdTbl[idx][i] != ' ' && gCmdTbl[idx][i] != '|' && i - 1 < size - 1)
    {
        dest[i - 1] = gCmdTbl[idx][i];
        i++;
    }
    dest[i - 1] = 0;
}

stock FindCmd(const name[])
{
    new n[24];
    for (new i = 0; i < sizeof gCmdTbl; i++)
    {
        CmdName(i, n);
        if (!strcmp(n, name, true)) return i;
    }
    return -1;
}

stock CmdUsage(idx, dest[], size = sizeof dest)
{
    new i = 1, j = 0;
    dest[j++] = '/';
    while (gCmdTbl[idx][i] && gCmdTbl[idx][i] != '|' && j < size - 1) { dest[j++] = gCmdTbl[idx][i++]; }
    dest[j] = 0;
}

stock CmdDesc(idx, dest[], size = sizeof dest)
{
    new p = strfind(gCmdTbl[idx], "|");
    if (p == -1) dest[0] = 0;
    else strmid(dest, gCmdTbl[idx], p + 1, strlen(gCmdTbl[idx]), size);
}

stock CanUse(playerid, const name[])
{
    new ci = FindCmd(name);
    if (ci == -1) return 0;
    return (Lvl(playerid) >= gLvl[ci]);
}

stock UsageMsg(playerid, ci)
{
    new u[64], d[64], s[144];
    CmdUsage(ci, u);
    CmdDesc(ci, d);
    format(s, sizeof s, "{FBBF24}Kullanim: {FFFFFF}%s {9CA3AF}- %s", u, d);
    SendClientMessage(playerid, -1, s);
    return 1;
}

stock GetT(playerid, const arg[])
{
    new t = UFind(arg);
    if (t == INVALID_PLAYER_ID) Err(playerid, "Oyuncu bulunamadi.");
    return t;
}

stock CanPunish(playerid, t)
{
    if (t == playerid) { Err(playerid, "Kendine bu islemi uygulayamazsin."); return 0; }
    if (Lvl(playerid) < MAX_LVL && Lvl(t) >= Lvl(playerid)) { Err(playerid, "Ayni veya daha yuksek yetkili birine uygulanamaz."); return 0; }
    return 1;
}

stock AdminMsg(const text[])
{
    for (new i = 0; i < MAX_PLAYERS; i++)
    {
        if (IsPlayerConnected(i) && Lvl(i) >= 1) SendClientMessage(i, 0xC4B5FDFF, text);
    }
}

stock SaveLast(playerid)
{
    GetPlayerPos(playerid, gLast[playerid][0], gLast[playerid][1], gLast[playerid][2]);
    gLastInt[playerid] = GetPlayerInterior(playerid);
    gLastVW[playerid] = GetPlayerVirtualWorld(playerid);
}

stock UTP(playerid, Float:x, Float:y, Float:z, interior, vw)
{
    SetPlayerInterior(playerid, interior);
    SetPlayerVirtualWorld(playerid, vw);
    if (IsPlayerInAnyVehicle(playerid) && GetPlayerVehicleSeat(playerid) == 0)
    {
        new v = GetPlayerVehicleID(playerid);
        SetVehiclePos(v, x, y, z);
        LinkVehicleToInterior(v, interior);
        SetVehicleVirtualWorld(v, vw);
    }
    else SetPlayerPos(playerid, x, y, z);
}

stock SendToJail(t)
{
    ResetPlayerWeapons(t);
    SetPlayerVirtualWorld(t, 0);
    SetPlayerInterior(t, 6);
    SetPlayerPos(t, 264.6, 77.5, 1001.0);
}

stock ReleaseJail(t)
{
    gJailUntil[t] = 0;
    SetPlayerInterior(t, 0);
    SetPlayerVirtualWorld(t, 0);
    SetPlayerPos(t, 1544.2, -1675.4, 13.6);
    Inf(t, "Hapis sureni tamamladin.");
}

stock ApplyInvisFor(viewer, target)
{
    if (viewer == target) return 0;
    if (!gInvis[target])
    {
        ShowPlayerNameTagForPlayer(viewer, target, 1);
        SetPlayerMarkerForPlayer(viewer, target, gOldColor[target]);
    }
    else if (Lvl(viewer) >= 1)
    {
        ShowPlayerNameTagForPlayer(viewer, target, 1);
        SetPlayerMarkerForPlayer(viewer, target, 0xC084FCFF);
    }
    else ShowPlayerNameTagForPlayer(viewer, target, 0);
    return 1;
}

stock Sanitize(str[])
{
    for (new i = 0; str[i]; i++) { if (str[i] == '~') str[i] = '-'; }
}

// ------------------------------------------------------------------
//  DOSYA TABANLI VERI: ADMIN / BAN / YETKI / KONUM / LOG
// ------------------------------------------------------------------
stock LoadAdminLevel(const name[])
{
    new File:f = fopen(F_ADMINS, io_read);
    if (!f) return 0;
    new line[64], nm[MAX_PLAYER_NAME], lv[8], res = 0;
    while (ReadLine(f, line))
    {
        if (!line[0]) continue;
        GetField(line, 0, nm);
        if (!strcmp(nm, name, true)) { GetField(line, 1, lv); res = strval(lv); break; }
    }
    fclose(f);
    return res;
}

stock SaveAdminLevel(const name[], level)
{
    new line[64], nm[MAX_PLAYER_NAME];
    new File:f = fopen(F_ADMINS, io_read);
    new File:t = fopen("uap_admins.tmp", io_write);
    if (!t) { if (f) fclose(f); return 0; }
    if (f)
    {
        while (ReadLine(f, line))
        {
            if (!line[0]) continue;
            GetField(line, 0, nm);
            if (strcmp(nm, name, true)) { fwrite(t, line); fwrite(t, "\r\n"); }
        }
        fclose(f);
    }
    if (level > 0)
    {
        format(line, sizeof line, "%s|%d\r\n", name, level);
        fwrite(t, line);
    }
    fclose(t);
    CopyFile("uap_admins.tmp", F_ADMINS);
    fremove("uap_admins.tmp");
    return 1;
}

stock SavePerms()
{
    new File:f = fopen(F_PERMS, io_write);
    if (!f) return 0;
    new n[24], line[48];
    for (new i = 0; i < sizeof gCmdTbl; i++)
    {
        CmdName(i, n);
        format(line, sizeof line, "%s|%d\r\n", n, gLvl[i]);
        fwrite(f, line);
    }
    fclose(f);
    return 1;
}

stock LoadPerms()
{
    for (new i = 0; i < sizeof gCmdTbl; i++) gLvl[i] = gCmdTbl[i][0] - '0';
    new File:f = fopen(F_PERMS, io_read);
    if (!f) return 0;
    new line[48], nm[24], lv[8], ci;
    while (ReadLine(f, line))
    {
        if (!line[0]) continue;
        GetField(line, 0, nm);
        GetField(line, 1, lv);
        ci = FindCmd(nm);
        if (ci != -1 && IsNum(lv) && strval(lv) <= MAX_LVL) gLvl[ci] = strval(lv);
    }
    fclose(f);
    return 1;
}

stock CountBans()
{
    gBanCount = 0;
    new File:f = fopen(F_BANS, io_read);
    if (!f) return 0;
    new line[200], ex[16], e;
    while (ReadLine(f, line))
    {
        if (!line[0]) continue;
        GetField(line, 2, ex);
        e = strval(ex);
        if (e != 0 && gettime() >= e) continue;
        gBanCount++;
    }
    fclose(f);
    return gBanCount;
}

stock AddBan(const name[], const ip[], expiry, const admin[], const reason[])
{
    new File:f = fopen(F_BANS, io_append);
    if (!f) return 0;
    new line[220], r[96];
    strmid(r, reason, 0, strlen(reason), sizeof r);
    ReplaceBar(r);
    format(line, sizeof line, "%s|%s|%d|%s|%s\r\n", name, ip, expiry, admin, r);
    fwrite(f, line);
    fclose(f);
    gBanCount++;
    return 1;
}

stock RemoveBan(const key[])
{
    new File:f = fopen(F_BANS, io_read);
    if (!f) return 0;
    new File:t = fopen("uap_bans.tmp", io_write);
    if (!t) { fclose(f); return 0; }
    new line[200], nm[MAX_PLAYER_NAME], ip[20], removed = 0;
    while (ReadLine(f, line))
    {
        if (!line[0]) continue;
        GetField(line, 0, nm);
        GetField(line, 1, ip);
        if (!strcmp(nm, key, true) || !strcmp(ip, key)) { removed++; continue; }
        fwrite(t, line);
        fwrite(t, "\r\n");
    }
    fclose(f);
    fclose(t);
    if (removed) CopyFile("uap_bans.tmp", F_BANS);
    fremove("uap_bans.tmp");
    CountBans();
    return removed;
}

stock BanCheck(playerid)
{
    new File:f = fopen(F_BANS, io_read);
    if (!f) return 0;
    new line[200], nm[MAX_PLAYER_NAME], ip[20], ex[16], ad[MAX_PLAYER_NAME], rs[96];
    new pn[MAX_PLAYER_NAME], pip[20], s[144], e, res = 0;
    GetPlayerName(playerid, pn, sizeof pn);
    GetPlayerIp(playerid, pip, sizeof pip);
    while (ReadLine(f, line))
    {
        if (!line[0]) continue;
        GetField(line, 0, nm);
        GetField(line, 1, ip);
        GetField(line, 2, ex);
        if (strcmp(nm, pn, true) && strcmp(ip, pip)) continue;
        e = strval(ex);
        if (e != 0 && gettime() >= e) continue;
        GetField(line, 3, ad);
        GetField(line, 4, rs);
        format(s, sizeof s, "{F87171}[BAN] {FFFFFF}Yasaklisin. Yetkili: %s | Sebep: %s", ad, rs);
        SendClientMessage(playerid, -1, s);
        if (e != 0)
        {
            format(s, sizeof s, "{F87171}[BAN] {FFFFFF}Kalan sure: %d dakika", (e - gettime()) / 60 + 1);
            SendClientMessage(playerid, -1, s);
        }
        res = 1;
        break;
    }
    fclose(f);
    return res;
}

stock AddLoc(const name[], Float:x, Float:y, Float:z, interior)
{
    if (gLocCount >= MAX_LOCS) return 0;
    format(gLocName[gLocCount], 24, "%s", name);
    gLocPos[gLocCount][0] = x;
    gLocPos[gLocCount][1] = y;
    gLocPos[gLocCount][2] = z;
    gLocInt[gLocCount] = interior;
    gLocCount++;
    return 1;
}

stock LoadLocs()
{
    gLocCount = 0;
    AddLoc("Admin_Base(LV_Havalimani)", 1682.2, 1447.0, 10.8, 0);
    AddLoc("LS_Grove_Street", 2495.3, -1688.8, 13.5, 0);
    AddLoc("LS_Polis_Merkezi", 1554.5, -1675.6, 16.2, 0);
    AddLoc("LS_Havalimani", 1642.0, -2333.0, 13.5, 0);
    AddLoc("LV_Four_Dragons", 2027.4, 1008.2, 10.8, 0);
    AddLoc("SF_Tren_Istasyonu", -1985.7, 137.8, 27.7, 0);
    AddLoc("Chiliad_Tepesi", -2321.8, -1641.4, 483.7, 0);
    new File:f = fopen(F_LOCS, io_read);
    if (!f) return 1;
    new line[128], nm[24], v[16];
    new Float:x, Float:y, Float:z, it;
    while (ReadLine(f, line))
    {
        if (!line[0]) continue;
        GetField(line, 0, nm);
        GetField(line, 1, v); x = floatstr(v);
        GetField(line, 2, v); y = floatstr(v);
        GetField(line, 3, v); z = floatstr(v);
        GetField(line, 4, v); it = strval(v);
        AddLoc(nm, x, y, z, it);
    }
    fclose(f);
    return 1;
}

stock UpdateRecent()
{
    new big[RECENT_N * RECENT_LEN + 16];
    for (new i = 0; i < RECENT_N; i++)
    {
        if (!gRecent[i][0]) continue;
        strcat(big, gRecent[i], sizeof big);
        strcat(big, "~n~", sizeof big);
    }
    if (!big[0]) strcat(big, "-", sizeof big);
    TextDrawSetString(gTDRecent, big);
}

stock ULog(playerid, const action[], const target[], const detail[], const result[])
{
    new y, mo, d, h, mi, sc, an[MAX_PLAYER_NAME], line[256];
    getdate(y, mo, d);
    gettime(h, mi, sc);
    if (playerid == INVALID_PLAYER_ID) format(an, sizeof an, "SISTEM");
    else GetPlayerName(playerid, an, sizeof an);
    format(line, sizeof line, "[%02d.%02d.%d %02d:%02d:%02d] %s | %s | %s | %s | %s\r\n", d, mo, y, h, mi, sc, an, action, target, detail, result);
    new File:f = fopen(F_LOG, io_append);
    if (f) { fwrite(f, line); fclose(f); }
    for (new i = RECENT_N - 1; i > 0; i--) format(gRecent[i], RECENT_LEN, "%s", gRecent[i - 1]);
    format(gRecent[0], RECENT_LEN, "%s: %s %s", an, action, target);
    UpdateRecent();
    new s[144];
    format(s, sizeof s, "[LOG] %s: %s -> %s (%s)", an, action, target, detail);
    AdminMsg(s);
}

// ------------------------------------------------------------------
//  TEXTDRAW PANEL
// ------------------------------------------------------------------
stock Text:TDBox(Float:x, Float:y, Float:x2, Float:lines, color)
{
    new Text:t = TextDrawCreate(x, y, "_");
    TextDrawLetterSize(t, 0.5, lines);
    TextDrawUseBox(t, 1);
    TextDrawBoxColor(t, color);
    TextDrawTextSize(t, x2, 0.0);
    return t;
}

stock Text:TDText(Float:x, Float:y, const str[], Float:lx, Float:ly, color, font)
{
    new Text:t = TextDrawCreate(x, y, str);
    TextDrawLetterSize(t, lx, ly);
    TextDrawColor(t, color);
    TextDrawFont(t, font);
    TextDrawSetShadow(t, 0);
    TextDrawSetOutline(t, 1);
    TextDrawBackgroundColor(t, 0x000000FF);
    TextDrawSetProportional(t, 1);
    return t;
}

stock CreateTDs()
{
    new Float:cx, Float:cy, i;
    gTDBg = TDBox(145.0, 108.0, 495.0, 24.8, 0x0C0817F0);
    gTDBar = TDBox(145.0, 108.0, 495.0, 0.4, 0xA855F7FF);
    gTDTitle = TDText(155.0, 114.0, "ULTIMATE ADMIN PANEL", 0.34, 1.45, 0xE9D5FFFF, 1);
    gTDSub = TDText(155.0, 131.0, "Profesyonel Yonetim Paneli v3.0", 0.2, 0.9, 0x9CA3AFFF, 2);
    gTDClock = TDText(485.0, 116.0, "00:00:00", 0.22, 1.0, 0xFFFFFFFF, 1);
    TextDrawAlignment(gTDClock, 3);

    new const lbl[][] = {"OYUNCU", "ADMIN ONLINE", "SERVER TICK", "BAN", "MUTE", "UPTIME"};
    for (i = 0; i < 6; i++)
    {
        cx = 155.0 + float(i % 3) * 110.0;
        cy = 164.0 + float(i / 3) * 40.0;
        gTDCard[i] = TDBox(cx, cy, cx + 100.0, 3.1, 0x1E1233F0);
        gTDLbl[i] = TDText(cx + 6.0, cy + 4.0, lbl[i], 0.17, 0.8, 0xA78BFAFF, 2);
        gTDVal[i] = TDText(cx + 6.0, cy + 15.0, "0", 0.34, 1.45, 0xFFFFFFFF, 1);
    }

    new const bt[][] = {" OYUNCULAR", " MODERASYON", "   ARAC", " TELEPORT", "  SUNUCU", " KOMUTLAR", "   LOGLAR", "  KAPAT"};
    for (i = 0; i < 8; i++)
    {
        cx = 155.0 + float(i % 4) * 83.0;
        cy = 252.0 + float(i / 4) * 26.0;
        gTDBtn[i] = TDText(cx, cy, bt[i], 0.2, 1.0, 0xFFFFFFFF, 2);
        TextDrawUseBox(gTDBtn[i], 1);
        if (i == 7) TextDrawBoxColor(gTDBtn[i], 0x7F1D1DE0);
        else TextDrawBoxColor(gTDBtn[i], 0x5B21B6E0);
        TextDrawTextSize(gTDBtn[i], cx + 78.0, 10.0);
        TextDrawSetSelectable(gTDBtn[i], true);
    }
    gTDRecentLbl = TDText(155.0, 306.0, "SON ISLEMLER", 0.2, 1.0, 0xA855F7FF, 1);
    gTDRecent = TDText(155.0, 319.0, "-", 0.17, 0.85, 0xD1D5DBFF, 2);
}

stock DestroyTDs()
{
    TextDrawDestroy(gTDBg); TextDrawDestroy(gTDBar); TextDrawDestroy(gTDTitle); TextDrawDestroy(gTDSub);
    TextDrawDestroy(gTDClock); TextDrawDestroy(gTDRecentLbl); TextDrawDestroy(gTDRecent);
    for (new i = 0; i < 6; i++) { TextDrawDestroy(gTDCard[i]); TextDrawDestroy(gTDLbl[i]); TextDrawDestroy(gTDVal[i]); }
    for (new i = 0; i < 8; i++) TextDrawDestroy(gTDBtn[i]);
}

stock ShowTDs(playerid)
{
    TextDrawShowForPlayer(playerid, gTDBg); TextDrawShowForPlayer(playerid, gTDBar);
    TextDrawShowForPlayer(playerid, gTDTitle); TextDrawShowForPlayer(playerid, gTDSub);
    TextDrawShowForPlayer(playerid, gTDClock);
    for (new i = 0; i < 6; i++) { TextDrawShowForPlayer(playerid, gTDCard[i]); TextDrawShowForPlayer(playerid, gTDLbl[i]); TextDrawShowForPlayer(playerid, gTDVal[i]); }
    for (new i = 0; i < 8; i++) TextDrawShowForPlayer(playerid, gTDBtn[i]);
    TextDrawShowForPlayer(playerid, gTDRecentLbl); TextDrawShowForPlayer(playerid, gTDRecent);
}

stock HideTDs(playerid)
{
    TextDrawHideForPlayer(playerid, gTDBg); TextDrawHideForPlayer(playerid, gTDBar);
    TextDrawHideForPlayer(playerid, gTDTitle); TextDrawHideForPlayer(playerid, gTDSub);
    TextDrawHideForPlayer(playerid, gTDClock);
    for (new i = 0; i < 6; i++) { TextDrawHideForPlayer(playerid, gTDCard[i]); TextDrawHideForPlayer(playerid, gTDLbl[i]); TextDrawHideForPlayer(playerid, gTDVal[i]); }
    for (new i = 0; i < 8; i++) TextDrawHideForPlayer(playerid, gTDBtn[i]);
    TextDrawHideForPlayer(playerid, gTDRecentLbl); TextDrawHideForPlayer(playerid, gTDRecent);
}

public OpenPanel(playerid)
{
    if (Lvl(playerid) < 1) return 0;
    ShowPlayerDialog(playerid, D_MAIN, DIALOG_STYLE_LIST, "Ultimate Admin Panel",
        "Oyuncular\nModerasyon\nArac\nTeleport\nSunucu\nKomutlar\nLoglar", "Sec", "Kapat");
    return 1;
}

public HidePanel(playerid)
{
    if (!gPanel[playerid]) return 1;
    gPanel[playerid] = 0;
    PlayerTextDrawDestroy(playerid, gPTDProf[playerid]);
    HideTDs(playerid);
    CancelSelectTextDraw(playerid);
    return 1;
}

// ------------------------------------------------------------------
//  DIALOGLAR
// ------------------------------------------------------------------
public AskInput(playerid, const title[], const msg[], const prefix[], confirm)
{
    format(gPendLine[playerid], 128, "%s", prefix);
    gPendConf[playerid] = confirm;
    ShowPlayerDialog(playerid, D_INPUT, DIALOG_STYLE_INPUT, title, msg, "Tamam", "Geri");
    return 1;
}

public ShowConfirm(playerid, const cmdline[])
{
    new s[200];
    format(gPendLine[playerid], 128, "%s", cmdline);
    format(s, sizeof s, "{FFFFFF}Su islemi onayliyor musun?\n\n{A855F7}/%s", cmdline);
    ShowPlayerDialog(playerid, D_CONFIRM, DIALOG_STYLE_MSGBOX, "Onay Gerekli", s, "Onayla", "Iptal");
    return 1;
}

public ShowPlayers(playerid)
{
    new big[3600], line[110], n[MAX_PLAYER_NAME], byid;
    if (gFilter[playerid][0]) format(line, sizeof line, "{A855F7}>> Filtre: %s (degistirmek icin sec)\n", gFilter[playerid]);
    else format(line, sizeof line, "{A855F7}>> Oyuncu ara / filtrele\n");
    strcat(big, line, sizeof big);
    for (new i = 0; i < MAX_PLAYERS; i++)
    {
        if (!IsPlayerConnected(i)) continue;
        GetPlayerName(i, n, sizeof n);
        byid = (IsNum(gFilter[playerid]) && strval(gFilter[playerid]) == i);
        if (gFilter[playerid][0] && !byid && strfind(n, gFilter[playerid], true) == -1) continue;
        format(line, sizeof line, "{FFFFFF}[%d] %s {9CA3AF}| ping %d | %s\n", i, n, GetPlayerPing(i), gRank[Lvl(i)]);
        if (strlen(big) + strlen(line) > 3500) break;
        strcat(big, line, sizeof big);
    }
    ShowPlayerDialog(playerid, D_PLAYERS, DIALOG_STYLE_LIST, "Oyuncular", big, "Sec", "Geri");
    return 1;
}

stock ShowPlayerActions(playerid)
{
    new n[MAX_PLAYER_NAME], cap[64];
    GetPlayerName(gSel[playerid], n, sizeof n);
    format(cap, sizeof cap, "Oyuncu: %s (ID %d)", n, gSel[playerid]);
    ShowPlayerDialog(playerid, D_PACT, DIALOG_STYLE_LIST, cap,
        "Bilgi\nYanina isinlan\nYanima cek\nIzle\nDondur\nDondurmayi coz\nIyilestir\nZirh ver\nCanlandir\nSustur (5 dk)\nSusturmayi kaldir\nUyari ver\nHapis (5 dk)\nHapisten cikar\nKick\nBan\nOzel mesaj",
        "Uygula", "Geri");
    return 1;
}

stock ShowPlayerInfo(playerid, t)
{
    new s[900], n[MAX_PLAYER_NAME], ip[32], st[48], Float:x, Float:y, Float:z, Float:hp, Float:ar, now = gettime();
    GetPlayerName(t, n, sizeof n);
    GetPlayerPos(t, x, y, z);
    GetPlayerHealth(t, hp);
    GetPlayerArmour(t, ar);
    if (Lvl(playerid) >= IP_LEVEL) GetPlayerIp(t, ip, sizeof ip);
    else format(ip, sizeof ip, "Gizli");
    format(st, sizeof st, "Normal");
    if (gMuteUntil[t] > now) format(st, sizeof st, "Susturulmus");
    if (gJailUntil[t] > now) format(st, sizeof st, "Hapiste");
    format(s, sizeof s, "{C4B5FD}ID: {FFFFFF}%d\n{C4B5FD}Isim: {FFFFFF}%s\n{C4B5FD}IP: {FFFFFF}%s\n{C4B5FD}Ping: {FFFFFF}%d\n{C4B5FD}Can / Zirh: {FFFFFF}%.0f / %.0f\n{C4B5FD}Konum: {FFFFFF}%.1f, %.1f, %.1f\n{C4B5FD}Interior / VW: {FFFFFF}%d / %d\n{C4B5FD}Skin / Para: {FFFFFF}%d / $%d\n{C4B5FD}Oturum suresi: {FFFFFF}%d dk\n{C4B5FD}Uyari: {FFFFFF}%d/3\n{C4B5FD}Rutbe: {FFFFFF}%s\n{C4B5FD}Durum: {FFFFFF}%s",
        t, n, ip, GetPlayerPing(t), hp, ar, x, y, z, GetPlayerInterior(t), GetPlayerVirtualWorld(t),
        GetPlayerSkin(t), GetPlayerMoney(t), (now - gJoin[t]) / 60, gWarns[t], gRank[Lvl(t)], st);
    ShowPlayerDialog(playerid, D_VIEW, DIALOG_STYLE_MSGBOX, "Oyuncu Bilgisi", s, "Geri", "");
    return 1;
}

public ShowCmdPage(playerid, page)
{
    new big[2400], line[128], u[64], ds[64], lv = Lvl(playerid), idx = 0, total = 0, maxp, cap[48];
    for (new i = 0; i < sizeof gCmdTbl; i++) { if (gLvl[i] <= lv) total++; }
    maxp = (total + CMD_PAGE - 1) / CMD_PAGE;
    if (page >= maxp) page = 0;
    gCmdPage[playerid] = page;
    for (new i = 0; i < sizeof gCmdTbl; i++)
    {
        if (gLvl[i] > lv) continue;
        if (idx >= page * CMD_PAGE && idx < (page + 1) * CMD_PAGE)
        {
            CmdUsage(i, u);
            CmdDesc(i, ds);
            format(line, sizeof line, "{C4B5FD}[%d] {FFFFFF}%s {9CA3AF}- %s\n", gLvl[i], u, ds);
            strcat(big, line, sizeof big);
        }
        idx++;
    }
    format(cap, sizeof cap, "Komutlar (%d/%d)", page + 1, maxp);
    ShowPlayerDialog(playerid, D_CMDS, DIALOG_STYLE_MSGBOX, cap, big, "Sonraki", "Kapat");
    return 1;
}

public ShowLog(playerid)
{
    if (!CanUse(playerid, "adminlog")) return Err(playerid, "Loglari gorme yetkin yok.");
    new File:f = fopen(F_LOG, io_read);
    if (!f) return Inf(playerid, "Henuz log kaydi yok.");
    new tail[LOG_LINES][160], line[256], cnt = 0, big[2600], start;
    while (ReadLine(f, line))
    {
        if (!line[0]) continue;
        strmid(tail[cnt % LOG_LINES], line, 0, 159, 160);
        cnt++;
    }
    fclose(f);
    start = (cnt > LOG_LINES) ? (cnt - LOG_LINES) : 0;
    for (new i = start; i < cnt; i++)
    {
        strcat(big, tail[i % LOG_LINES], sizeof big);
        strcat(big, "\n", sizeof big);
    }
    ShowPlayerDialog(playerid, D_VIEW, DIALOG_STYLE_MSGBOX, "Admin Islem Loglari", big, "Geri", "");
    return 1;
}

stock ShowBanList(playerid)
{
    if (!CanUse(playerid, "unban")) return Err(playerid, "Ban listesini gorme yetkin yok.");
    new File:f = fopen(F_BANS, io_read);
    if (!f) return Inf(playerid, "Ban kaydi yok.");
    new tail[15][120], line[200], nm[MAX_PLAYER_NAME], ip[20], shown[20], ex[16], ad[MAX_PLAYER_NAME], rs[64];
    new left[16], cnt = 0, big[2200], e, start;
    while (ReadLine(f, line))
    {
        if (!line[0]) continue;
        GetField(line, 0, nm); GetField(line, 1, ip); GetField(line, 2, ex);
        GetField(line, 3, ad); GetField(line, 4, rs);
        e = strval(ex);
        if (e == 0) format(left, sizeof left, "kalici");
        else if (e <= gettime()) continue;
        else format(left, sizeof left, "%d dk", (e - gettime()) / 60 + 1);
        if (Lvl(playerid) >= IP_LEVEL) format(shown, sizeof shown, "%s", ip);
        else format(shown, sizeof shown, "gizli");
        format(tail[cnt % 15], 120, "%s | %s | %s | %s | %s", nm, shown, left, ad, rs);
        cnt++;
    }
    fclose(f);
    start = (cnt > 15) ? (cnt - 15) : 0;
    for (new i = start; i < cnt; i++)
    {
        strcat(big, tail[i % 15], sizeof big);
        strcat(big, "\n", sizeof big);
    }
    if (!big[0]) format(big, sizeof big, "Aktif ban yok.");
    ShowPlayerDialog(playerid, D_VIEW, DIALOG_STYLE_MSGBOX, "Ban Listesi (son 15)", big, "Geri", "");
    return 1;
}

stock ShowPunished(playerid)
{
    new big[1600], line[96], n[MAX_PLAYER_NAME], now = gettime();
    for (new i = 0; i < MAX_PLAYERS; i++)
    {
        if (!IsPlayerConnected(i)) continue;
        GetPlayerName(i, n, sizeof n);
        if (gMuteUntil[i] > now)
        {
            format(line, sizeof line, "{FBBF24}MUTE {FFFFFF}%s (ID %d) - %d dk kaldi\n", n, i, (gMuteUntil[i] - now) / 60 + 1);
            strcat(big, line, sizeof big);
        }
        if (gJailUntil[i] > now)
        {
            format(line, sizeof line, "{F87171}JAIL {FFFFFF}%s (ID %d) - %d dk kaldi\n", n, i, (gJailUntil[i] - now) / 60 + 1);
            strcat(big, line, sizeof big);
        }
        if (gWarns[i] > 0)
        {
            format(line, sizeof line, "{C4B5FD}WARN {FFFFFF}%s (ID %d) - %d/3\n", n, i, gWarns[i]);
            strcat(big, line, sizeof big);
        }
    }
    if (!big[0]) format(big, sizeof big, "Su an cezali oyuncu yok.");
    ShowPlayerDialog(playerid, D_VIEW, DIALOG_STYLE_MSGBOX, "Aktif Cezalar", big, "Geri", "");
    return 1;
}

stock ShowReports(playerid)
{
    new big[1800], line[200], now = gettime(), cnt = 0;
    for (new i = 0; i < MAX_REPORTS; i++)
    {
        if (!gRepActive[i]) continue;
        format(line, sizeof line, "{FFFFFF}[%d] %s -> %s: %s {9CA3AF}(%d dk once)\n", i + 1, gRepFrom[i], gRepTarget[i], gRepText[i], (now - gRepTime[i]) / 60);
        strcat(big, line, sizeof big);
        cnt++;
    }
    if (!cnt) return Inf(playerid, "Aktif sikayet yok.");
    ShowPlayerDialog(playerid, D_REPORTS, DIALOG_STYLE_LIST, "Aktif Sikayetler (sec = kabul et)", big, "Kabul", "Geri");
    return 1;
}

stock ShowLocs(playerid)
{
    new big[1500], line[48];
    for (new i = 0; i < gLocCount; i++)
    {
        format(line, sizeof line, "%s\n", gLocName[i]);
        strcat(big, line, sizeof big);
    }
    ShowPlayerDialog(playerid, D_LOCS, DIALOG_STYLE_LIST, "Kayitli Konumlar", big, "Isinlan", "Geri");
    return 1;
}

stock ShowServerInfo(playerid)
{
    new s[1100], host[64], ns[400], online = 0, now = gettime(), up = now - gStart, act = 0;
    GetServerVarAsString("hostname", host, sizeof host);
    GetNetworkStats(ns, sizeof ns);
    for (new i = 0; i < MAX_PLAYERS; i++) { if (IsPlayerConnected(i)) online++; }
    for (new i = 0; i < MAX_REPORTS; i++) { if (gRepActive[i]) act++; }
    format(s, sizeof s, "{C4B5FD}Sunucu: {FFFFFF}%s\n{C4B5FD}Oyuncu: {FFFFFF}%d / %d\n{C4B5FD}Server tick: {FFFFFF}%d\n{C4B5FD}Uptime (filterscript): {FFFFFF}%dg %ds %ddk\n{C4B5FD}Aktif ban: {FFFFFF}%d\n{C4B5FD}Aktif sikayet: {FFFFFF}%d\n{C4B5FD}Dunya saati / hava: {FFFFFF}%d / %d\n\n{C4B5FD}Ag istatistikleri:\n{9CA3AF}%s",
        host, online, GetMaxPlayers(), GetServerTickRate(), up / 86400, (up % 86400) / 3600, (up % 3600) / 60, gBanCount, act, gHour, gWeather, ns);
    ShowPlayerDialog(playerid, D_VIEW, DIALOG_STYLE_MSGBOX, "Sunucu Bilgisi ve Performans", s, "Geri", "");
    return 1;
}

// ------------------------------------------------------------------
//  KOMUT MOTORU  (sohbet + panel ayni yoldan gecer, yetki burada dogrulanir)
// ------------------------------------------------------------------
public ExecCmd(playerid, const line[])
{
    new cmd[24], p = 0;
    UTok(line, p, cmd);
    if (!cmd[0]) return 0;
    new ci = FindCmd(cmd);
    if (ci == -1) return 0;
    new lv = Lvl(playerid);
    if (lv < gLvl[ci])
    {
        if (lv == 0) return 0;
        return Err(playerid, "Bu komut icin yetkin yok.");
    }
    new a[48], b[48], c[48], rest[128], s[144], an[MAX_PLAYER_NAME], tn[MAX_PLAYER_NAME], ip[20], d[96];
    new t, Float:x, Float:y, Float:z, Float:f, n1, n2, now = gettime();
    GetPlayerName(playerid, an, sizeof an);

    // ---------------- BILGI ----------------
    if (IS("ahelp"))
    {
        format(s, sizeof s, "Rutben: %s (Seviye %d). Panel: /admin  |  Komutlar: /acmds  |  Oyuncular: /players", gRank[lv], lv);
        return Inf(playerid, s);
    }
    if (IS("acmds")) { ShowCmdPage(playerid, 0); return 1; }
    if (IS("admin")) { OpenPanel(playerid); return 1; }
    if (IS("players")) { gFilter[playerid][0] = 0; ShowPlayers(playerid); return 1; }
    if (IS("admins"))
    {
        Inf(playerid, "--- Online Adminler ---");
        for (new i = 0; i < MAX_PLAYERS; i++)
        {
            if (!IsPlayerConnected(i) || Lvl(i) < 1) continue;
            GetPlayerName(i, tn, sizeof tn);
            format(s, sizeof s, "%s (ID %d) - %s", tn, i, gRank[Lvl(i)]);
            Inf(playerid, s);
        }
        return 1;
    }
    if (IS("coords"))
    {
        GetPlayerPos(playerid, x, y, z);
        GetPlayerFacingAngle(playerid, f);
        format(s, sizeof s, "X: %.3f Y: %.3f Z: %.3f A: %.1f | Interior: %d | VW: %d", x, y, z, f, GetPlayerInterior(playerid), GetPlayerVirtualWorld(playerid));
        return Inf(playerid, s);
    }
    if (IS("adminlog")) { ShowLog(playerid); return 1; }

    // ---------------- TELEPORT ----------------
    if (IS("goto") || IS("gotoid"))
    {
        UTok(line, p, a);
        if (!a[0]) return UsageMsg(playerid, ci);
        t = GetT(playerid, a);
        if (t == INVALID_PLAYER_ID) return 1;
        if (t == playerid) return Err(playerid, "Kendine isinlanamazsin.");
        SaveLast(playerid);
        GetPlayerPos(t, x, y, z);
        UTP(playerid, x + 1.0, y, z, GetPlayerInterior(t), GetPlayerVirtualWorld(t));
        GetPlayerName(t, tn, sizeof tn);
        format(s, sizeof s, "%s oyuncusunun yanina isinlandin.", tn);
        Okm(playerid, s);
        ULog(playerid, "goto", tn, "-", "OK");
        return 1;
    }
    if (IS("gethere") || IS("bring"))
    {
        UTok(line, p, a);
        if (!a[0]) return UsageMsg(playerid, ci);
        t = GetT(playerid, a);
        if (t == INVALID_PLAYER_ID) return 1;
        if (t == playerid) return Err(playerid, "Kendini cekemezsin.");
        if (Lvl(playerid) < MAX_LVL && Lvl(t) > Lvl(playerid)) return Err(playerid, "Daha yuksek yetkiliyi cekemezsin.");
        SaveLast(t);
        GetPlayerPos(playerid, x, y, z);
        UTP(t, x + 1.0, y, z, GetPlayerInterior(playerid), GetPlayerVirtualWorld(playerid));
        GetPlayerName(t, tn, sizeof tn);
        format(s, sizeof s, "%s oyuncusu yanina cekildi.", tn);
        Okm(playerid, s);
        Inf(t, "Bir yetkili tarafindan yanina cekildin.");
        ULog(playerid, "bring", tn, "-", "OK");
        return 1;
    }
    if (IS("tp"))
    {
        UTok(line, p, a); UTok(line, p, b); UTok(line, p, c); UTok(line, p, d);
        if (!a[0] || !b[0] || !c[0]) return UsageMsg(playerid, ci);
        SaveLast(playerid);
        UTP(playerid, floatstr(a), floatstr(b), floatstr(c), strval(d), 0);
        format(s, sizeof s, "Koordinata isinlandin: %s %s %s", a, b, c);
        Okm(playerid, s);
        ULog(playerid, "tp", an, s, "OK");
        return 1;
    }
    if (IS("back"))
    {
        GetPlayerPos(playerid, x, y, z);
        n1 = GetPlayerInterior(playerid);
        n2 = GetPlayerVirtualWorld(playerid);
        if (gLast[playerid][0] == 0.0 && gLast[playerid][1] == 0.0) return Err(playerid, "Kayitli onceki konum yok.");
        UTP(playerid, gLast[playerid][0], gLast[playerid][1], gLast[playerid][2], gLastInt[playerid], gLastVW[playerid]);
        gLast[playerid][0] = x; gLast[playerid][1] = y; gLast[playerid][2] = z;
        gLastInt[playerid] = n1; gLastVW[playerid] = n2;
        return Okm(playerid, "Onceki konuma donuldu.");
    }
    if (IS("savepos"))
    {
        UTok(line, p, a);
        if (!a[0]) return UsageMsg(playerid, ci);
        ReplaceBar(a);
        if (strlen(a) > 23) return Err(playerid, "Isim en fazla 23 karakter olabilir.");
        if (gLocCount >= MAX_LOCS) return Err(playerid, "Konum listesi dolu.");
        GetPlayerPos(playerid, x, y, z);
        n1 = GetPlayerInterior(playerid);
        AddLoc(a, x, y, z, n1);
        new File:fl = fopen(F_LOCS, io_append);
        if (fl)
        {
            format(d, sizeof d, "%s|%.3f|%.3f|%.3f|%d\r\n", a, x, y, z, n1);
            fwrite(fl, d);
            fclose(fl);
        }
        format(s, sizeof s, "Konum kaydedildi: %s", a);
        Okm(playerid, s);
        ULog(playerid, "savepos", a, "-", "OK");
        return 1;
    }

    // ---------------- OYUNCU DURUMU ----------------
    if (IS("revive"))
    {
        UTok(line, p, a);
        if (a[0]) t = GetT(playerid, a); else t = playerid;
        if (t == INVALID_PLAYER_ID) return 1;
        GetPlayerName(t, tn, sizeof tn);
        GetPlayerHealth(t, f);
        if (gDead[t]) { gRevive[t] = 1; SpawnPlayer(t); }
        else { SetPlayerHealth(t, 100.0); }
        format(s, sizeof s, "%.0f -> 100", f);
        Okm(playerid, "Oyuncu canlandirildi.");
        ULog(playerid, "revive", tn, s, "OK");
        return 1;
    }
    if (IS("heal") || IS("armor"))
    {
        UTok(line, p, a);
        if (a[0]) t = GetT(playerid, a); else t = playerid;
        if (t == INVALID_PLAYER_ID) return 1;
        GetPlayerName(t, tn, sizeof tn);
        if (IS("heal")) { GetPlayerHealth(t, f); SetPlayerHealth(t, 100.0); }
        else { GetPlayerArmour(t, f); SetPlayerArmour(t, 100.0); }
        format(s, sizeof s, "%.0f -> 100", f);
        Okm(playerid, "Islem uygulandi.");
        ULog(playerid, cmd, tn, s, "OK");
        return 1;
    }
    if (IS("sethealth") || IS("setarmor"))
    {
        UTok(line, p, a); UTok(line, p, b);
        if (!a[0] || !b[0]) return UsageMsg(playerid, ci);
        t = GetT(playerid, a);
        if (t == INVALID_PLAYER_ID) return 1;
        n1 = strval(b);
        if (n1 < 0 || n1 > 100) return Err(playerid, "Deger 0-100 arasinda olmali.");
        GetPlayerName(t, tn, sizeof tn);
        if (IS("sethealth")) { GetPlayerHealth(t, f); SetPlayerHealth(t, float(n1)); }
        else { GetPlayerArmour(t, f); SetPlayerArmour(t, float(n1)); }
        format(s, sizeof s, "%.0f -> %d", f, n1);
        Okm(playerid, s);
        ULog(playerid, cmd, tn, s, "OK");
        return 1;
    }
    if (IS("setskin"))
    {
        UTok(line, p, a); UTok(line, p, b);
        if (!a[0] || !b[0]) return UsageMsg(playerid, ci);
        t = GetT(playerid, a);
        if (t == INVALID_PLAYER_ID) return 1;
        n1 = strval(b);
        if (n1 < 0 || n1 > 311 || n1 == 74) return Err(playerid, "Gecersiz skin ID (0-311, 74 haric).");
        GetPlayerName(t, tn, sizeof tn);
        format(s, sizeof s, "%d -> %d", GetPlayerSkin(t), n1);
        SetPlayerSkin(t, n1);
        Okm(playerid, s);
        ULog(playerid, "setskin", tn, s, "OK");
        return 1;
    }
    if (IS("setmoney"))
    {
        UTok(line, p, a); UTok(line, p, b);
        if (!a[0] || !b[0]) return UsageMsg(playerid, ci);
        t = GetT(playerid, a);
        if (t == INVALID_PLAYER_ID) return 1;
        n1 = strval(b);
        if (n1 < 0 || n1 > 1000000000) return Err(playerid, "Miktar 0 - 1.000.000.000 arasinda olmali.");
        GetPlayerName(t, tn, sizeof tn);
        format(s, sizeof s, "%d -> %d", GetPlayerMoney(t), n1);
        ResetPlayerMoney(t);
        GivePlayerMoney(t, n1);
        Okm(playerid, s);
        ULog(playerid, "setmoney", tn, s, "OK");
        return 1;
    }
    if (IS("giveweapon"))
    {
        UTok(line, p, a); UTok(line, p, b); UTok(line, p, c);
        if (!a[0] || !b[0]) return UsageMsg(playerid, ci);
        t = GetT(playerid, a);
        if (t == INVALID_PLAYER_ID) return 1;
        n1 = strval(b);
        n2 = c[0] ? strval(c) : 100;
        if (n1 < 1 || n1 > 46 || n1 == 19 || n1 == 20 || n1 == 21) return Err(playerid, "Gecersiz silah ID (1-46).");
        if (n2 < 1 || n2 > 9999) n2 = 100;
        GetPlayerName(t, tn, sizeof tn);
        GivePlayerWeapon(t, n1, n2);
        format(s, sizeof s, "silah %d, mermi %d", n1, n2);
        Okm(playerid, s);
        ULog(playerid, "giveweapon", tn, s, "OK");
        return 1;
    }
    if (IS("setvw") || IS("setinterior"))
    {
        UTok(line, p, a); UTok(line, p, b);
        if (!a[0] || !b[0]) return UsageMsg(playerid, ci);
        t = GetT(playerid, a);
        if (t == INVALID_PLAYER_ID) return 1;
        n1 = strval(b);
        if (n1 < 0 || n1 > 255) return Err(playerid, "Deger 0-255 arasinda olmali.");
        GetPlayerName(t, tn, sizeof tn);
        if (IS("setvw")) { format(s, sizeof s, "%d -> %d", GetPlayerVirtualWorld(t), n1); SetPlayerVirtualWorld(t, n1); }
        else { format(s, sizeof s, "%d -> %d", GetPlayerInterior(t), n1); SetPlayerInterior(t, n1); }
        Okm(playerid, s);
        ULog(playerid, cmd, tn, s, "OK");
        return 1;
    }
    if (IS("freeze") || IS("unfreeze"))
    {
        UTok(line, p, a);
        if (!a[0]) return UsageMsg(playerid, ci);
        t = GetT(playerid, a);
        if (t == INVALID_PLAYER_ID) return 1;
        if (IS("freeze") && !CanPunish(playerid, t)) return 1;
        GetPlayerName(t, tn, sizeof tn);
        TogglePlayerControllable(t, IS("unfreeze") ? 1 : 0);
        Okm(playerid, "Islem uygulandi.");
        ULog(playerid, cmd, tn, "-", "OK");
        return 1;
    }

    // ---------------- ADMIN MODLARI ----------------
    if (IS("duty"))
    {
        if (!gDuty[playerid])
        {
            gDutySkin[playerid] = GetPlayerSkin(playerid);
            SetPlayerSkin(playerid, DUTY_SKIN);
            gGod[playerid] = 1;
            SetPlayerHealth(playerid, 99999.0);
            gDutyLbl[playerid] = Create3DTextLabel("ADMIN", 0xFF0000FF, 0.0, 0.0, 0.0, 40.0, -1, 1);
            Attach3DTextLabelToPlayer(gDutyLbl[playerid], playerid, 0.0, 0.0, 0.4);
            gDuty[playerid] = 1;
            Okm(playerid, "Admin gorevine basladin: olumsuzsun, takim elbise giydin.");
        }
        else
        {
            Delete3DTextLabel(gDutyLbl[playerid]);
            SetPlayerSkin(playerid, gDutySkin[playerid]);
            gGod[playerid] = 0;
            SetPlayerHealth(playerid, 100.0);
            gDuty[playerid] = 0;
            Okm(playerid, "Admin gorevinden ciktin.");
        }
        ULog(playerid, "duty", an, gDuty[playerid] ? "acik" : "kapali", "OK");
        return 1;
    }
    if (IS("god"))
    {
        gGod[playerid] = !gGod[playerid];
        if (gGod[playerid]) { SetPlayerHealth(playerid, 99999.0); Okm(playerid, "God mode ACIK."); }
        else { SetPlayerHealth(playerid, 100.0); Okm(playerid, "God mode KAPALI."); }
        ULog(playerid, "god", an, gGod[playerid] ? "acik" : "kapali", "OK");
        return 1;
    }
    if (IS("fly"))
    {
        if (IsPlayerInAnyVehicle(playerid)) return Err(playerid, "Aracta jetpack kullanamazsin.");
        if (gFly[playerid]) { gFly[playerid] = 0; ClearAnimations(playerid); }
        if (GetPlayerSpecialAction(playerid) == SPECIAL_ACTION_USEJETPACK)
        {
            SetPlayerSpecialAction(playerid, SPECIAL_ACTION_NONE);
            Okm(playerid, "Jetpack KAPALI.");
        }
        else
        {
            SetPlayerSpecialAction(playerid, SPECIAL_ACTION_USEJETPACK);
            Okm(playerid, "Jetpack ACIK. Kapatmak icin tekrar /fly yaz.");
        }
        ULog(playerid, "fly", an, "jetpack", "OK");
        return 1;
    }
    if (IS("noclip"))
    {
        n1 = IS("noclip") ? 2 : 1;
        if (IsPlayerInAnyVehicle(playerid)) return Err(playerid, "Aracta ucamazsin.");
        if (gFly[playerid] == n1)
        {
            gFly[playerid] = 0;
            ClearAnimations(playerid);
            Okm(playerid, "Ucus modu KAPALI.");
        }
        else
        {
            gFly[playerid] = n1;
            Okm(playerid, "Ucus ACIK: W/S = ileri/geri (kamera yonunde), SPACE = yukari, C = asagi, SHIFT = hizlan.");
        }
        ULog(playerid, cmd, an, gFly[playerid] ? "acik" : "kapali", "OK");
        return 1;
    }
    if (IS("invisible"))
    {
        gInvis[playerid] = !gInvis[playerid];
        if (gInvis[playerid])
        {
            gOldColor[playerid] = GetPlayerColor(playerid);
            SetPlayerColor(playerid, 0xFFFFFF00);
        }
        else SetPlayerColor(playerid, gOldColor[playerid]);
        for (new i = 0; i < MAX_PLAYERS; i++)
        {
            if (IsPlayerConnected(i)) ApplyInvisFor(i, playerid);
        }
        if (gInvis[playerid]) Okm(playerid, "Gizlendin: isim etiketin ve harita isaretin sadece adminlere gorunur (model gizlenemez).");
        else Okm(playerid, "Gorunur oldun.");
        ULog(playerid, "invisible", an, gInvis[playerid] ? "acik" : "kapali", "OK");
        return 1;
    }
    if (IS("infammo"))
    {
        gInfAmmo[playerid] = !gInfAmmo[playerid];
        Okm(playerid, gInfAmmo[playerid] ? "Sinirsiz mermi ACIK." : "Sinirsiz mermi KAPALI.");
        ULog(playerid, "infammo", an, gInfAmmo[playerid] ? "acik" : "kapali", "OK");
        return 1;
    }
    if (IS("vgod"))
    {
        gVGod[playerid] = !gVGod[playerid];
        Okm(playerid, gVGod[playerid] ? "Arac god mode ACIK." : "Arac god mode KAPALI.");
        ULog(playerid, "vgod", an, gVGod[playerid] ? "acik" : "kapali", "OK");
        return 1;
    }
    if (IS("spectate"))
    {
        UTok(line, p, a);
        if (!a[0]) return UsageMsg(playerid, ci);
        t = GetT(playerid, a);
        if (t == INVALID_PLAYER_ID) return 1;
        if (t == playerid) return Err(playerid, "Kendini izleyemezsin.");
        if (gSpec[t] != INVALID_PLAYER_ID) return Err(playerid, "Bu oyuncu baska birini izliyor.");
        if (gSpec[playerid] == INVALID_PLAYER_ID) { SaveLast(playerid); TogglePlayerSpectating(playerid, 1); }
        SetPlayerInterior(playerid, GetPlayerInterior(t));
        SetPlayerVirtualWorld(playerid, GetPlayerVirtualWorld(t));
        if (IsPlayerInAnyVehicle(t)) PlayerSpectateVehicle(playerid, GetPlayerVehicleID(t));
        else PlayerSpectatePlayer(playerid, t);
        gSpec[playerid] = t;
        GetPlayerName(t, tn, sizeof tn);
        format(s, sizeof s, "%s izleniyor. Birakmak icin /unspectate", tn);
        Okm(playerid, s);
        ULog(playerid, "spectate", tn, "-", "OK");
        return 1;
    }
    if (IS("unspectate"))
    {
        if (gSpec[playerid] == INVALID_PLAYER_ID) return Err(playerid, "Kimseyi izlemiyorsun.");
        gSpec[playerid] = INVALID_PLAYER_ID;
        gSpecBack[playerid] = 1;
        TogglePlayerSpectating(playerid, 0);
        return Okm(playerid, "Izleme birakildi.");
    }

    // ---------------- CEZA SISTEMI ----------------
    if (IS("kick") || IS("ban"))
    {
        UTok(line, p, a); URest(line, p, rest);
        if (!a[0]) return UsageMsg(playerid, ci);
        t = GetT(playerid, a);
        if (t == INVALID_PLAYER_ID) return 1;
        if (!CanPunish(playerid, t)) return 1;
        if (!rest[0]) format(rest, sizeof rest, "Belirtilmedi");
        GetPlayerName(t, tn, sizeof tn);
        if (IS("ban"))
        {
            GetPlayerIp(t, ip, sizeof ip);
            AddBan(tn, ip, 0, an, rest);
            format(s, sizeof s, "{A855F7}[ADMIN] {FFFFFF}%s, %s oyuncusunu KALICI yasakladi. Sebep: %s", an, tn, rest);
        }
        else format(s, sizeof s, "{A855F7}[ADMIN] {FFFFFF}%s, %s oyuncusunu atti. Sebep: %s", an, tn, rest);
        SendClientMessageToAll(-1, s);
        SetTimerEx("UAP_Kick", 600, false, "i", t);
        ULog(playerid, cmd, tn, rest, "OK");
        return 1;
    }
    if (IS("tempban"))
    {
        UTok(line, p, a); UTok(line, p, b); URest(line, p, rest);
        if (!a[0] || !b[0]) return UsageMsg(playerid, ci);
        t = GetT(playerid, a);
        if (t == INVALID_PLAYER_ID) return 1;
        n1 = strval(b);
        if (n1 < 1 || n1 > 525600) return Err(playerid, "Sure 1 - 525600 dakika olmali.");
        if (!CanPunish(playerid, t)) return 1;
        if (!rest[0]) format(rest, sizeof rest, "Belirtilmedi");
        GetPlayerName(t, tn, sizeof tn);
        GetPlayerIp(t, ip, sizeof ip);
        AddBan(tn, ip, now + n1 * 60, an, rest);
        format(s, sizeof s, "{A855F7}[ADMIN] {FFFFFF}%s, %s oyuncusunu %d dk yasakladi. Sebep: %s", an, tn, n1, rest);
        SendClientMessageToAll(-1, s);
        SetTimerEx("UAP_Kick", 600, false, "i", t);
        format(d, sizeof d, "%d dk | %s", n1, rest);
        ULog(playerid, "tempban", tn, d, "OK");
        return 1;
    }
    if (IS("unban"))
    {
        UTok(line, p, a);
        if (!a[0]) return UsageMsg(playerid, ci);
        n1 = RemoveBan(a);
        if (!n1) return Err(playerid, "Bu isim/IP ile ban kaydi bulunamadi.");
        format(s, sizeof s, "%d ban kaydi kaldirildi: %s", n1, a);
        Okm(playerid, s);
        ULog(playerid, "unban", a, "-", "OK");
        return 1;
    }
    if (IS("mute"))
    {
        UTok(line, p, a); UTok(line, p, b); URest(line, p, rest);
        if (!a[0] || !b[0]) return UsageMsg(playerid, ci);
        t = GetT(playerid, a);
        if (t == INVALID_PLAYER_ID) return 1;
        if (!IsNum(b) || strval(b) > 100000) return Err(playerid, "Dakika gecersiz (0 = kalici).");
        if (!CanPunish(playerid, t)) return 1;
        n1 = strval(b);
        if (!rest[0]) format(rest, sizeof rest, "Belirtilmedi");
        GetPlayerName(t, tn, sizeof tn);
        if (n1 == 0) gMuteUntil[t] = 2147000000; else gMuteUntil[t] = now + n1 * 60;
        format(s, sizeof s, "{A855F7}[ADMIN] {FFFFFF}%s, %s oyuncusunu susturdu (%d dk). Sebep: %s", an, tn, n1, rest);
        SendClientMessageToAll(-1, s);
        format(d, sizeof d, "%d dk | %s", n1, rest);
        ULog(playerid, "mute", tn, d, "OK");
        return 1;
    }
    if (IS("unmute"))
    {
        UTok(line, p, a);
        if (!a[0]) return UsageMsg(playerid, ci);
        t = GetT(playerid, a);
        if (t == INVALID_PLAYER_ID) return 1;
        GetPlayerName(t, tn, sizeof tn);
        gMuteUntil[t] = 0;
        Inf(t, "Susturman kaldirildi.");
        Okm(playerid, "Susturma kaldirildi.");
        ULog(playerid, "unmute", tn, "-", "OK");
        return 1;
    }
    if (IS("jail"))
    {
        UTok(line, p, a); UTok(line, p, b); URest(line, p, rest);
        if (!a[0] || !b[0]) return UsageMsg(playerid, ci);
        t = GetT(playerid, a);
        if (t == INVALID_PLAYER_ID) return 1;
        n1 = strval(b);
        if (n1 < 1 || n1 > 1440) return Err(playerid, "Sure 1-1440 dakika olmali.");
        if (!CanPunish(playerid, t)) return 1;
        if (!rest[0]) format(rest, sizeof rest, "Belirtilmedi");
        GetPlayerName(t, tn, sizeof tn);
        gJailUntil[t] = now + n1 * 60;
        gFly[t] = 0;
        SendToJail(t);
        format(s, sizeof s, "{A855F7}[ADMIN] {FFFFFF}%s, %s oyuncusunu %d dk hapse atti. Sebep: %s", an, tn, n1, rest);
        SendClientMessageToAll(-1, s);
        format(d, sizeof d, "%d dk | %s", n1, rest);
        ULog(playerid, "jail", tn, d, "OK");
        return 1;
    }
    if (IS("unjail"))
    {
        UTok(line, p, a);
        if (!a[0]) return UsageMsg(playerid, ci);
        t = GetT(playerid, a);
        if (t == INVALID_PLAYER_ID) return 1;
        if (gJailUntil[t] <= now) return Err(playerid, "Oyuncu hapiste degil.");
        GetPlayerName(t, tn, sizeof tn);
        ReleaseJail(t);
        Okm(playerid, "Oyuncu hapisten cikarildi.");
        ULog(playerid, "unjail", tn, "-", "OK");
        return 1;
    }
    if (IS("warn"))
    {
        UTok(line, p, a); URest(line, p, rest);
        if (!a[0]) return UsageMsg(playerid, ci);
        t = GetT(playerid, a);
        if (t == INVALID_PLAYER_ID) return 1;
        if (!CanPunish(playerid, t)) return 1;
        if (!rest[0]) format(rest, sizeof rest, "Belirtilmedi");
        GetPlayerName(t, tn, sizeof tn);
        format(d, sizeof d, "%d -> %d | %s", gWarns[t], gWarns[t] + 1, rest);
        gWarns[t]++;
        format(s, sizeof s, "{A855F7}[ADMIN] {FFFFFF}%s, %s oyuncusuna uyari verdi (%d/3). Sebep: %s", an, tn, gWarns[t], rest);
        SendClientMessageToAll(-1, s);
        if (gWarns[t] >= 3)
        {
            gWarns[t] = 0;
            SendClientMessage(t, 0xF87171FF, "[ADMIN] 3 uyariya ulastin, sunucudan atiliyorsun.");
            SetTimerEx("UAP_Kick", 800, false, "i", t);
        }
        ULog(playerid, "warn", tn, d, "OK");
        return 1;
    }
    if (IS("apm"))
    {
        UTok(line, p, a); URest(line, p, rest);
        if (!a[0] || !rest[0]) return UsageMsg(playerid, ci);
        t = GetT(playerid, a);
        if (t == INVALID_PLAYER_ID) return 1;
        GetPlayerName(t, tn, sizeof tn);
        format(s, sizeof s, "{A855F7}[ADMIN MESAJI] {FFFFFF}%s: %s", an, rest);
        SendClientMessage(t, -1, s);
        format(s, sizeof s, "{A855F7}[MESAJ -> %s] {FFFFFF}%s", tn, rest);
        SendClientMessage(playerid, -1, s);
        ULog(playerid, "apm", tn, rest, "OK");
        return 1;
    }

    // ---------------- SIKAYETLER ----------------
    if (IS("report"))
    {
        UTok(line, p, a); URest(line, p, rest);
        if (!a[0] || !rest[0]) return UsageMsg(playerid, ci);
        if (now - gLastRep[playerid] < 30) return Err(playerid, "Sikayetler arasinda 30 saniye beklemelisin.");
        t = GetT(playerid, a);
        if (t == INVALID_PLAYER_ID) return 1;
        n1 = -1;
        for (new i = 0; i < MAX_REPORTS; i++) { if (!gRepActive[i]) { n1 = i; break; } }
        if (n1 == -1) return Err(playerid, "Sikayet listesi dolu, daha sonra dene.");
        GetPlayerName(t, tn, sizeof tn);
        gRepActive[n1] = 1;
        gRepTime[n1] = now;
        format(gRepFrom[n1], MAX_PLAYER_NAME, "%s", an);
        format(gRepTarget[n1], MAX_PLAYER_NAME, "%s", tn);
        format(gRepText[n1], 64, "%s", rest);
        gLastRep[playerid] = now;
        format(s, sizeof s, "{FBBF24}[SIKAYET #%d] {FFFFFF}%s -> %s: %s", n1 + 1, an, tn, rest);
        AdminMsg(s);
        SendClientMessage(playerid, 0x4ADE80FF, "[OK] Sikayetin yetkililere iletildi.");
        ULog(playerid, "report", tn, rest, "OK");
        return 1;
    }
    if (IS("reports")) { return ShowReports(playerid); }
    if (IS("acceptreport") || IS("denyreport"))
    {
        UTok(line, p, a); URest(line, p, rest);
        if (!a[0]) return UsageMsg(playerid, ci);
        n1 = strval(a) - 1;
        if (n1 < 0 || n1 >= MAX_REPORTS || !gRepActive[n1]) return Err(playerid, "Gecersiz sikayet numarasi.");
        t = UFind(gRepFrom[n1]);
        if (IS("acceptreport"))
        {
            if (t != INVALID_PLAYER_ID)
            {
                format(s, sizeof s, "{4ADE80}[SIKAYET] {FFFFFF}Sikayetin %s tarafindan kabul edildi.", an);
                SendClientMessage(t, -1, s);
            }
            format(s, sizeof s, "{FBBF24}[SIKAYET #%d] {FFFFFF}%s tarafindan kabul edildi.", n1 + 1, an);
        }
        else
        {
            if (!rest[0]) format(rest, sizeof rest, "Belirtilmedi");
            if (t != INVALID_PLAYER_ID)
            {
                format(s, sizeof s, "{F87171}[SIKAYET] {FFFFFF}Sikayetin reddedildi. Sebep: %s", rest);
                SendClientMessage(t, -1, s);
            }
            format(s, sizeof s, "{FBBF24}[SIKAYET #%d] {FFFFFF}%s tarafindan reddedildi.", n1 + 1, an);
        }
        AdminMsg(s);
        gRepActive[n1] = 0;
        ULog(playerid, cmd, gRepTarget[n1], gRepText[n1], "OK");
        return 1;
    }

    // ---------------- ARAC ----------------
    if (IS("veh"))
    {
        UTok(line, p, a); UTok(line, p, b); UTok(line, p, c);
        if (!a[0]) return UsageMsg(playerid, ci);
        n1 = strval(a);
        if (n1 < 400 || n1 > 611) return Err(playerid, "Model ID 400-611 arasinda olmali.");
        GetPlayerPos(playerid, x, y, z);
        GetPlayerFacingAngle(playerid, f);
        n2 = CreateVehicle(n1, x + 2.0, y, z + 0.5, f, b[0] ? strval(b) : -1, c[0] ? strval(c) : -1, -1);
        if (n2 == INVALID_VEHICLE_ID) return Err(playerid, "Arac olusturulamadi (limit).");
        gVehMade[n2] = 1;
        LinkVehicleToInterior(n2, GetPlayerInterior(playerid));
        SetVehicleVirtualWorld(n2, GetPlayerVirtualWorld(playerid));
        PutPlayerInVehicle(playerid, n2, 0);
        format(s, sizeof s, "model %d, arac ID %d", n1, n2);
        Okm(playerid, s);
        ULog(playerid, "veh", an, s, "OK");
        return 1;
    }
    if (IS("vehdel"))
    {
        if (!IsPlayerInAnyVehicle(playerid)) return Err(playerid, "Bir aracin icinde olmalisin.");
        n1 = GetPlayerVehicleID(playerid);
        if (!gVehMade[n1]) return Err(playerid, "Sadece /veh ile olusturulan araclar silinebilir.");
        gVehMade[n1] = 0;
        DestroyVehicle(n1);
        Okm(playerid, "Arac silindi.");
        ULog(playerid, "vehdel", an, "-", "OK");
        return 1;
    }
    if (IS("vcolor"))
    {
        UTok(line, p, a); UTok(line, p, b);
        if (!a[0]) return UsageMsg(playerid, ci);
        if (!IsPlayerInAnyVehicle(playerid)) return Err(playerid, "Bir aracin icinde olmalisin.");
        ChangeVehicleColor(GetPlayerVehicleID(playerid), strval(a), b[0] ? strval(b) : strval(a));
        return Okm(playerid, "Arac rengi degisti.");
    }
    if (IS("repair") || IS("flip"))
    {
        UTok(line, p, a);
        if (a[0]) t = GetT(playerid, a); else t = playerid;
        if (t == INVALID_PLAYER_ID) return 1;
        if (!IsPlayerInAnyVehicle(t)) return Err(playerid, "Oyuncu bir aracin icinde degil.");
        n1 = GetPlayerVehicleID(t);
        GetPlayerName(t, tn, sizeof tn);
        if (IS("repair")) { RepairVehicle(n1); SetVehicleHealth(n1, 1000.0); }
        else { GetVehicleZAngle(n1, f); SetVehicleZAngle(n1, f); }
        Okm(playerid, "Islem uygulandi.");
        ULog(playerid, cmd, tn, "-", "OK");
        return 1;
    }

    // ---------------- SUNUCU ----------------
    if (IS("settime"))
    {
        UTok(line, p, a);
        if (!a[0] || !IsNum(a)) return UsageMsg(playerid, ci);
        n1 = strval(a);
        if (n1 < 0 || n1 > 23) return Err(playerid, "Saat 0-23 olmali.");
        format(s, sizeof s, "%d -> %d", gHour, n1);
        gHour = n1;
        SetWorldTime(n1);
        for (new i = 0; i < MAX_PLAYERS; i++) { if (IsPlayerConnected(i)) SetPlayerTime(i, n1, 0); }
        Okm(playerid, s);
        ULog(playerid, "settime", "sunucu", s, "OK");
        return 1;
    }
    if (IS("setweather"))
    {
        UTok(line, p, a);
        if (!a[0] || !IsNum(a)) return UsageMsg(playerid, ci);
        n1 = strval(a);
        if (n1 < 0 || n1 > 45) return Err(playerid, "Hava ID 0-45 olmali.");
        format(s, sizeof s, "%d -> %d", gWeather, n1);
        gWeather = n1;
        SetWeather(n1);
        Okm(playerid, s);
        ULog(playerid, "setweather", "sunucu", s, "OK");
        return 1;
    }
    if (IS("announce"))
    {
        URest(line, p, rest);
        if (!rest[0]) return UsageMsg(playerid, ci);
        Sanitize(rest);
        format(d, sizeof d, "~p~DUYURU~n~~w~%s", rest);
        GameTextForAll(d, 6000, 3);
        format(s, sizeof s, "{A855F7}[DUYURU] {FFFFFF}%s", rest);
        SendClientMessageToAll(-1, s);
        ULog(playerid, "announce", "herkes", rest, "OK");
        return 1;
    }
    if (IS("clearchat"))
    {
        for (new i = 0; i < 30; i++) SendClientMessageToAll(-1, " ");
        format(s, sizeof s, "{A855F7}[ADMIN] {FFFFFF}Sohbet %s tarafindan temizlendi.", an);
        SendClientMessageToAll(-1, s);
        ULog(playerid, "clearchat", "herkes", "-", "OK");
        return 1;
    }

    // ---------------- YETKI YONETIMI ----------------
    if (IS("setadmin"))
    {
        UTok(line, p, a); UTok(line, p, b);
        if (!a[0] || !IsNum(b)) return UsageMsg(playerid, ci);
        t = GetT(playerid, a);
        if (t == INVALID_PLAYER_ID) return 1;
        n1 = strval(b);
        if (n1 < 0 || n1 > MAX_LVL) return Err(playerid, "Seviye 0-8 olmali.");
        if (lv < MAX_LVL)
        {
            if (n1 >= lv) return Err(playerid, "Kendi seviyenle ayni veya yuksek rutbe veremezsin.");
            if (gLevel[t] >= lv) return Err(playerid, "Bu oyuncunun rutbesini degistiremezsin.");
        }
        GetPlayerName(t, tn, sizeof tn);
        format(s, sizeof s, "%d -> %d", gLevel[t], n1);
        gLevel[t] = n1;
        SaveAdminLevel(tn, n1);
        format(d, sizeof d, "Rutben degisti: %s", gRank[n1]);
        Inf(t, d);
        Okm(playerid, s);
        ULog(playerid, "setadmin", tn, s, "OK");
        return 1;
    }
    if (IS("setperm"))
    {
        UTok(line, p, a); UTok(line, p, b);
        if (!a[0] || !IsNum(b)) return UsageMsg(playerid, ci);
        n2 = FindCmd(a);
        if (n2 == -1) return Err(playerid, "Boyle bir komut yok.");
        n1 = strval(b);
        if (n1 < 0 || n1 > MAX_LVL) return Err(playerid, "Seviye 0-8 olmali.");
        if ((IS("setperm") || !strcmp(a, "setperm", true)) && n1 < 7) return Err(playerid, "setperm en az 7. seviye olmali.");
        if (n1 == 0 && strcmp(a, "report", true) && strcmp(a, "admins", true)) return Err(playerid, "Sadece /report ve /admins herkese acilabilir.");
        format(s, sizeof s, "/%s: %d -> %d", a, gLvl[n2], n1);
        gLvl[n2] = n1;
        SavePerms();
        Okm(playerid, s);
        ULog(playerid, "setperm", a, s, "OK");
        return 1;
    }
    return 0;
}

// ------------------------------------------------------------------
//  ZAMANLAYICILAR
// ------------------------------------------------------------------
public UAP_Kick(playerid)
{
    if (IsPlayerConnected(playerid)) Kick(playerid);
    return 1;
}

public UAP_Tick()
{
    new pc = 0, ac = 0, mc = 0, now = gettime(), s[64], h, mi, sc, y, mo, d, w, am, v, rc = 0;
    for (new i = 0; i < MAX_PLAYERS; i++)
    {
        if (!IsPlayerConnected(i)) continue;
        pc++;
        if (Lvl(i) > 0) ac++;
        if (gMuteUntil[i] > now) mc++;
        if (gJailUntil[i] != 0 && now >= gJailUntil[i]) ReleaseJail(i);
        if (gGod[i])
        {
            new Float:hp;
            GetPlayerHealth(i, hp);
            if (hp < 90000.0) SetPlayerHealth(i, 99999.0);
        }
        if (gFly[i]) ApplyAnimation(i, "PARACHUTE", "PARA_float", 4.1, 1, 0, 0, 0, 0, 1);
        if (gVGod[i] && IsPlayerInAnyVehicle(i))
        {
            v = GetPlayerVehicleID(i);
            SetVehicleHealth(v, 1000.0);
        }
        if (gInfAmmo[i])
        {
            for (new slot = 2; slot < 12; slot++)
            {
                GetPlayerWeaponData(i, slot, w, am);
                if (w > 0 && am < 50) GivePlayerWeapon(i, w, 500);
            }
        }
    }
    for (new i = 0; i < MAX_REPORTS; i++) { if (gRepActive[i]) rc++; }
    format(s, sizeof s, "%d/%d", pc, GetMaxPlayers());
    TextDrawSetString(gTDVal[0], s);
    format(s, sizeof s, "%d", ac);
    TextDrawSetString(gTDVal[1], s);
    format(s, sizeof s, "%d", GetServerTickRate());
    TextDrawSetString(gTDVal[2], s);
    format(s, sizeof s, "%d", gBanCount);
    TextDrawSetString(gTDVal[3], s);
    format(s, sizeof s, "%d", mc);
    TextDrawSetString(gTDVal[4], s);
    new up = now - gStart;
    format(s, sizeof s, "%dg %ds %ddk", up / 86400, (up % 86400) / 3600, (up % 3600) / 60);
    TextDrawSetString(gTDVal[5], s);
    gettime(h, mi, sc);
    getdate(y, mo, d);
    format(s, sizeof s, "%02d:%02d:%02d  %02d.%02d.%d  Sikayet: %d", h, mi, sc, d, mo, y, rc);
    TextDrawSetString(gTDClock, s);
    return 1;
}

public UAP_Fly()
{
    new k, ud, lr, Float:x, Float:y, Float:z, Float:fx, Float:fy, Float:fz, Float:sp;
    for (new i = 0; i < MAX_PLAYERS; i++)
    {
        if (!gFly[i] || !IsPlayerConnected(i)) continue;
        GetPlayerKeys(i, k, ud, lr);
        SetPlayerVelocity(i, 0.0, 0.0, 0.0);
        if (ud == 0 && !(k & (KEY_JUMP | KEY_CROUCH))) continue;
        GetPlayerPos(i, x, y, z);
        GetPlayerCameraFrontVector(i, fx, fy, fz);
        if (gFly[i] == 2) sp = 3.0; else sp = 1.0;
        if (k & KEY_SPRINT) sp *= 2.0;
        if (ud < 0) { x += fx * sp; y += fy * sp; z += fz * sp; }
        else if (ud > 0) { x -= fx * sp; y -= fy * sp; z -= fz * sp; }
        if (k & KEY_JUMP) z += sp;
        if (k & KEY_CROUCH) z -= sp;
        SetPlayerPos(i, x, y, z);
        SetPlayerFacingAngle(i, atan2(fy, fx) - 90.0);
    }
    return 1;
}

// ------------------------------------------------------------------
//  CALLBACK'LER
// ------------------------------------------------------------------
stock ResetPlayer(playerid)
{
    gLevel[playerid] = 0; gGod[playerid] = 0; gFly[playerid] = 0; gInvis[playerid] = 0;
    gInfAmmo[playerid] = 0; gVGod[playerid] = 0; gSpec[playerid] = INVALID_PLAYER_ID;
    gSpecBack[playerid] = 0; gMuteUntil[playerid] = 0; gJailUntil[playerid] = 0; gWarns[playerid] = 0;
    gJoin[playerid] = gettime(); gSel[playerid] = INVALID_PLAYER_ID; gPanel[playerid] = 0;
    gDead[playerid] = 0; gRevive[playerid] = 0; gLastRep[playerid] = 0; gPendConf[playerid] = 0;
    gFilter[playerid][0] = 0; gPendLine[playerid][0] = 0;
    gLast[playerid][0] = 0.0; gLast[playerid][1] = 0.0; gLast[playerid][2] = 0.0;
}

public OnFilterScriptInit()
{
    gStart = gettime();
    for (new i = 0; i < MAX_PLAYERS; i++) ResetPlayer(i);
    LoadPerms();
    LoadLocs();
    CountBans();
    CreateTDs();
    for (new i = 0; i < MAX_PLAYERS; i++)
    {
        if (!IsPlayerConnected(i)) continue;
        new n[MAX_PLAYER_NAME];
        GetPlayerName(i, n, sizeof n);
        gLevel[i] = LoadAdminLevel(n);
    }
    gTmrTick = SetTimer("UAP_Tick", 1000, true);
    gTmrFly = SetTimer("UAP_Fly", 50, true);
    print("[UAP] Ultimate Admin Panel v3.0 yuklendi.");
    return 1;
}

public OnFilterScriptExit()
{
    KillTimer(gTmrTick);
    KillTimer(gTmrFly);
    for (new i = 0; i < MAX_PLAYERS; i++)
    {
        if (!IsPlayerConnected(i)) continue;
        if (gPanel[i]) HidePanel(i);
        if (gGod[i]) SetPlayerHealth(i, 100.0);
        if (gDuty[i]) { Delete3DTextLabel(gDutyLbl[i]); SetPlayerSkin(i, gDutySkin[i]); gDuty[i] = 0; }
        if (gFly[i]) ClearAnimations(i);
        if (gInvis[i]) SetPlayerColor(i, gOldColor[i]);
    }
    DestroyTDs();
    print("[UAP] Ultimate Admin Panel kapatildi.");
    return 1;
}

public OnPlayerConnect(playerid)
{
    ResetPlayer(playerid);
    new n[MAX_PLAYER_NAME], s[96];
    GetPlayerName(playerid, n, sizeof n);
    gLevel[playerid] = LoadAdminLevel(n);
    if (BanCheck(playerid))
    {
        SetTimerEx("UAP_Kick", 700, false, "i", playerid);
        return 1;
    }
    for (new i = 0; i < MAX_PLAYERS; i++)
    {
        if (IsPlayerConnected(i) && gInvis[i]) ApplyInvisFor(playerid, i);
    }
    ApplyAnimation(playerid, "PARACHUTE", "null", 0.0, 0, 0, 0, 0, 0);
    if (gLevel[playerid] > 0)
    {
        format(s, sizeof s, "Admin girisi: %s (%s). Panel icin /admin", n, gRank[gLevel[playerid]]);
        Inf(playerid, s);
    }
    return 1;
}

public OnPlayerDisconnect(playerid, reason)
{
    for (new i = 0; i < MAX_PLAYERS; i++)
    {
        if (IsPlayerConnected(i) && gSpec[i] == playerid)
        {
            gSpec[i] = INVALID_PLAYER_ID;
            gSpecBack[i] = 1;
            TogglePlayerSpectating(i, 0);
            Inf(i, "Izledigin oyuncu sunucudan cikti.");
        }
    }
    if (gDuty[playerid]) { Delete3DTextLabel(gDutyLbl[playerid]); gDuty[playerid] = 0; }
    ResetPlayer(playerid);
    return 1;
}

public OnPlayerDeath(playerid, killerid, reason)
{
    gDead[playerid] = 1;
    GetPlayerPos(playerid, gDeadPos[playerid][0], gDeadPos[playerid][1], gDeadPos[playerid][2]);
    gDeadInt[playerid] = GetPlayerInterior(playerid);
    gFly[playerid] = 0;
    return 1;
}

public OnPlayerSpawn(playerid)
{
    if (gRevive[playerid])
    {
        gRevive[playerid] = 0;
        SetPlayerInterior(playerid, gDeadInt[playerid]);
        SetPlayerPos(playerid, gDeadPos[playerid][0], gDeadPos[playerid][1], gDeadPos[playerid][2]);
        SetPlayerHealth(playerid, 100.0);
    }
    else if (gSpecBack[playerid])
    {
        gSpecBack[playerid] = 0;
        SetPlayerInterior(playerid, gLastInt[playerid]);
        SetPlayerVirtualWorld(playerid, gLastVW[playerid]);
        SetPlayerPos(playerid, gLast[playerid][0], gLast[playerid][1], gLast[playerid][2]);
    }
    if (gJailUntil[playerid] > gettime()) SendToJail(playerid);
    if (gDuty[playerid]) SetPlayerSkin(playerid, DUTY_SKIN);
    if (gGod[playerid]) SetPlayerHealth(playerid, 99999.0);
    gDead[playerid] = 0;
    return 1;
}

public OnPlayerText(playerid, text[])
{
    if (gMuteUntil[playerid] > gettime())
    {
        new s[96];
        if (gMuteUntil[playerid] > 2000000000) format(s, sizeof s, "Kalici olarak susturulmussun.");
        else format(s, sizeof s, "Susturulmussun. Kalan sure: %d dk", (gMuteUntil[playerid] - gettime()) / 60 + 1);
        Err(playerid, s);
        return 0;
    }
    return 1;
}

public OnPlayerCommandText(playerid, cmdtext[])
{
    if (cmdtext[0] != '/') return 0;
    return ExecCmd(playerid, cmdtext[1]);
}

public OnPlayerClickTextDraw(playerid, Text:clickedid)
{
    if (!gPanel[playerid]) return 0;
    if (clickedid == INVALID_TEXT_DRAW) { HidePanel(playerid); return 1; }
    for (new i = 0; i < 8; i++)
    {
        if (clickedid != gTDBtn[i]) continue;
        HidePanel(playerid);
        switch (i)
        {
            case 0:
            {
                if (!CanUse(playerid, "players")) return Err(playerid, "Yetkin yok.");
                gFilter[playerid][0] = 0;
                ShowPlayers(playerid);
            }
            case 1:
            {
                ShowPlayerDialog(playerid, D_MOD, DIALOG_STYLE_LIST, "Moderasyon Merkezi",
                    "Sikayetler\nBan listesi\nAktif cezalar (mute/jail/warn)\nBan kaldir\nAdmin islem logu", "Sec", "Geri");
            }
            case 2:
            {
                ShowPlayerDialog(playerid, D_VEH, DIALOG_STYLE_LIST, "Arac Kontrolu",
                    "Arac olustur\nAracimi tamir et\nAracimi duzelt (flip)\nAracimi sil\nArac rengi\nArac god mode", "Sec", "Geri");
            }
            case 3:
            {
                ShowPlayerDialog(playerid, D_TP, DIALOG_STYLE_LIST, "Teleport Merkezi",
                    "Koordinata isinlan\nKayitli konumlar\nOnceki konuma don\nMevcut koordinatim", "Sec", "Geri");
            }
            case 4:
            {
                ShowPlayerDialog(playerid, D_SRV, DIALOG_STYLE_LIST, "Sunucu Yonetimi",
                    "Sunucu bilgisi / performans\nOnline adminler\nDuyuru yap\nHava durumu\nSaat\nSohbeti temizle\nAdmin islem logu", "Sec", "Geri");
            }
            case 5: ShowCmdPage(playerid, 0);
            case 6: ShowLog(playerid);
        }
        return 1;
    }
    return 0;
}

public OnDialogResponse(playerid, dialogid, response, listitem, inputtext[])
{
    if (dialogid < D_PLAYERS || dialogid > D_MAIN) return 0;
    new cmdl[160], tn[MAX_PLAYER_NAME], pos;

    switch (dialogid)
    {
        case D_MAIN:
        {
            if (!response) return 1;
            switch (listitem)
            {
                case 0:
                {
                    if (!CanUse(playerid, "players")) return Err(playerid, "Yetkin yok.");
                    gFilter[playerid][0] = 0;
                    ShowPlayers(playerid);
                }
                case 1: ShowPlayerDialog(playerid, D_MOD, DIALOG_STYLE_LIST, "Moderasyon Merkezi",
                    "Sikayetler\nBan listesi\nAktif cezalar (mute/jail/warn)\nBan kaldir\nAdmin islem logu", "Sec", "Geri");
                case 2: ShowPlayerDialog(playerid, D_VEH, DIALOG_STYLE_LIST, "Arac Kontrolu",
                    "Arac olustur\nAracimi tamir et\nAracimi duzelt (flip)\nAracimi sil\nArac rengi\nArac god mode", "Sec", "Geri");
                case 3: ShowPlayerDialog(playerid, D_TP, DIALOG_STYLE_LIST, "Teleport Merkezi",
                    "Koordinata isinlan\nKayitli konumlar\nOnceki konuma don\nMevcut koordinatim", "Sec", "Geri");
                case 4: ShowPlayerDialog(playerid, D_SRV, DIALOG_STYLE_LIST, "Sunucu Yonetimi",
                    "Sunucu bilgisi / performans\nOnline adminler\nDuyuru yap\nHava durumu\nSaat\nSohbeti temizle\nAdmin islem logu", "Sec", "Geri");
                case 5: ShowCmdPage(playerid, 0);
                case 6: ShowLog(playerid);
            }
            return 1;
        }
        case D_VIEW:
        {
            OpenPanel(playerid);
            return 1;
        }
        case D_PLAYERS:
        {
            if (!response) { OpenPanel(playerid); return 1; }
            if (!CanUse(playerid, "players")) return 1;
            if (listitem == 0)
            {
                ShowPlayerDialog(playerid, D_SEARCH, DIALOG_STYLE_INPUT, "Oyuncu Ara", "ID veya isim yaz (bos birak = filtreyi temizle):", "Ara", "Geri");
                return 1;
            }
            pos = strfind(inputtext, "[");
            if (pos == -1) return 1;
            gSel[playerid] = strval(inputtext[pos + 1]);
            if (gSel[playerid] < 0 || gSel[playerid] >= MAX_PLAYERS || !IsPlayerConnected(gSel[playerid])) { Err(playerid, "Oyuncu artik cevrimdisi."); ShowPlayers(playerid); return 1; }
            ShowPlayerActions(playerid);
            return 1;
        }
        case D_SEARCH:
        {
            if (response) format(gFilter[playerid], 24, "%s", inputtext);
            ShowPlayers(playerid);
            return 1;
        }
        case D_PACT:
        {
            if (!response) { ShowPlayers(playerid); return 1; }
            if (gSel[playerid] < 0 || gSel[playerid] >= MAX_PLAYERS || !IsPlayerConnected(gSel[playerid])) { Err(playerid, "Oyuncu artik cevrimdisi."); ShowPlayers(playerid); return 1; }
            GetPlayerName(gSel[playerid], tn, sizeof tn);
            switch (listitem)
            {
                case 0: ShowPlayerInfo(playerid, gSel[playerid]);
                case 1: { format(cmdl, sizeof cmdl, "goto %s", tn); ExecCmd(playerid, cmdl); }
                case 2: { format(cmdl, sizeof cmdl, "bring %s", tn); ExecCmd(playerid, cmdl); }
                case 3: { format(cmdl, sizeof cmdl, "spectate %s", tn); ExecCmd(playerid, cmdl); }
                case 4: { format(cmdl, sizeof cmdl, "freeze %s", tn); ExecCmd(playerid, cmdl); }
                case 5: { format(cmdl, sizeof cmdl, "unfreeze %s", tn); ExecCmd(playerid, cmdl); }
                case 6: { format(cmdl, sizeof cmdl, "heal %s", tn); ExecCmd(playerid, cmdl); }
                case 7: { format(cmdl, sizeof cmdl, "armor %s", tn); ExecCmd(playerid, cmdl); }
                case 8: { format(cmdl, sizeof cmdl, "revive %s", tn); ExecCmd(playerid, cmdl); }
                case 9: { format(cmdl, sizeof cmdl, "mute %s 5 Panel", tn); ExecCmd(playerid, cmdl); }
                case 10: { format(cmdl, sizeof cmdl, "unmute %s", tn); ExecCmd(playerid, cmdl); }
                case 11: { format(cmdl, sizeof cmdl, "warn %s ", tn); AskInput(playerid, "Uyari", "Uyari sebebini yaz:", cmdl, 0); }
                case 12: { format(cmdl, sizeof cmdl, "jail %s 5 Panel", tn); ExecCmd(playerid, cmdl); }
                case 13: { format(cmdl, sizeof cmdl, "unjail %s", tn); ExecCmd(playerid, cmdl); }
                case 14: { format(cmdl, sizeof cmdl, "kick %s ", tn); AskInput(playerid, "Kick", "Kick sebebini yaz:", cmdl, 1); }
                case 15: { format(cmdl, sizeof cmdl, "ban %s ", tn); AskInput(playerid, "Kalici Ban", "Ban sebebini yaz:", cmdl, 1); }
                case 16: { format(cmdl, sizeof cmdl, "apm %s ", tn); AskInput(playerid, "Ozel Mesaj", "Mesajini yaz:", cmdl, 0); }
            }
            return 1;
        }
        case D_INPUT:
        {
            if (!response) { OpenPanel(playerid); return 1; }
            if (!inputtext[0]) { Err(playerid, "Bos birakilamaz."); return 1; }
            format(cmdl, sizeof cmdl, "%s%s", gPendLine[playerid], inputtext);
            if (gPendConf[playerid]) ShowConfirm(playerid, cmdl);
            else ExecCmd(playerid, cmdl);
            return 1;
        }
        case D_CONFIRM:
        {
            if (response) ExecCmd(playerid, gPendLine[playerid]);
            else Inf(playerid, "Islem iptal edildi.");
            return 1;
        }
        case D_MOD:
        {
            if (!response) { OpenPanel(playerid); return 1; }
            switch (listitem)
            {
                case 0: { if (CanUse(playerid, "reports")) ShowReports(playerid); }
                case 1: ShowBanList(playerid);
                case 2: { if (CanUse(playerid, "mute")) ShowPunished(playerid); else Err(playerid, "Yetkin yok."); }
                case 3: { if (CanUse(playerid, "unban")) AskInput(playerid, "Ban Kaldir", "Oyuncu ismi veya IP yaz:", "unban ", 1); else Err(playerid, "Yetkin yok."); }
                case 4: ShowLog(playerid);
            }
            return 1;
        }
        case D_REPORTS:
        {
            if (!response) { OpenPanel(playerid); return 1; }
            pos = strfind(inputtext, "[");
            if (pos == -1) return 1;
            format(cmdl, sizeof cmdl, "acceptreport %d", strval(inputtext[pos + 1]));
            ExecCmd(playerid, cmdl);
            return 1;
        }
        case D_VEH:
        {
            if (!response) { OpenPanel(playerid); return 1; }
            switch (listitem)
            {
                case 0: AskInput(playerid, "Arac Olustur", "Model ID (400-611), istersen renk1 renk2:", "veh ", 0);
                case 1: ExecCmd(playerid, "repair");
                case 2: ExecCmd(playerid, "flip");
                case 3: ShowConfirm(playerid, "vehdel");
                case 4: AskInput(playerid, "Arac Rengi", "renk1 renk2 (0-255):", "vcolor ", 0);
                case 5: ExecCmd(playerid, "vgod");
            }
            return 1;
        }
        case D_TP:
        {
            if (!response) { OpenPanel(playerid); return 1; }
            switch (listitem)
            {
                case 0: AskInput(playerid, "Koordinata Isinlan", "x y z [interior]", "tp ", 0);
                case 1: { if (CanUse(playerid, "goto")) ShowLocs(playerid); else Err(playerid, "Yetkin yok."); }
                case 2: ExecCmd(playerid, "back");
                case 3: ExecCmd(playerid, "coords");
            }
            return 1;
        }
        case D_LOCS:
        {
            if (!response) { OpenPanel(playerid); return 1; }
            if (!CanUse(playerid, "goto")) return 1;
            if (listitem >= 0 && listitem < gLocCount)
            {
                SaveLast(playerid);
                UTP(playerid, gLocPos[listitem][0], gLocPos[listitem][1], gLocPos[listitem][2], gLocInt[listitem], 0);
                format(cmdl, sizeof cmdl, "Isinlandin: %s", gLocName[listitem]);
                Okm(playerid, cmdl);
                ULog(playerid, "locteleport", gLocName[listitem], "-", "OK");
            }
            return 1;
        }
        case D_SRV:
        {
            if (!response) { OpenPanel(playerid); return 1; }
            switch (listitem)
            {
                case 0: { if (CanUse(playerid, "players")) ShowServerInfo(playerid); }
                case 1: ExecCmd(playerid, "admins");
                case 2: { if (CanUse(playerid, "announce")) AskInput(playerid, "Duyuru", "Duyuru metni:", "announce ", 1); else Err(playerid, "Yetkin yok."); }
                case 3: { if (CanUse(playerid, "setweather")) AskInput(playerid, "Hava Durumu", "Hava ID (0-45):", "setweather ", 0); else Err(playerid, "Yetkin yok."); }
                case 4: { if (CanUse(playerid, "settime")) AskInput(playerid, "Saat", "Saat (0-23):", "settime ", 0); else Err(playerid, "Yetkin yok."); }
                case 5: { if (CanUse(playerid, "clearchat")) ShowConfirm(playerid, "clearchat"); else Err(playerid, "Yetkin yok."); }
                case 6: ShowLog(playerid);
            }
            return 1;
        }
        case D_CMDS:
        {
            if (response) ShowCmdPage(playerid, gCmdPage[playerid] + 1);
            else OpenPanel(playerid);
            return 1;
        }
    }
    return 0;
}
