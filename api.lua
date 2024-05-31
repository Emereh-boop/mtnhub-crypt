#!/usr/bin/lua

local util    = require("luci.util")
local sys     = require("luci.sys")
local jsonc   = require("luci.jsonc")
local mtkwifi = require("mtkwifi")
local uci     = require("luci.model.uci").cursor()

local SERVER  = "https://device-api-stg.wicrypt.com"

local function session_retrieve(session_id)
    local session = util.ubus("session", "get", { ubus_rpc_session = session_id })
    if type(session) == "table" then
        return jsonc.stringify({ data = session, success = true, error = nil })
    else
        return jsonc.stringify({ error = "Invalid Session", success = false, data = nil })
    end
end

local function login(user, pass)
    local lgin = util.ubus("session", "login", {
        username = "root",
        password = pass,
        timeout = 900
    })
    if type(lgin) == "table" and type(lgin.ubus_rpc_session) == "string" then
        util.ubus("session", "set", {
            ubus_rpc_session = lgin.ubus_rpc_session,
            values = { token = sys.uniqueid(16) }
        })
        print("Set-Cookie: sessionId=" .. lgin.ubus_rpc_session .. "; Path=/; HttpOnly")
        print("\r\n")
        return session_retrieve(lgin.ubus_rpc_session)
    else
        print("\r\n")
        return jsonc.stringify({ error = "Wrong credentials", success = false, data = nil })
    end
end

local function board_info()
    print("\r\n")
    local info = util.ubus("system", "board")
    return jsonc.stringify({ data = info, success = true, error = nil })
end

local function firmw_enable()
    print("\r\n")
    os.execute("/etc/init.d/spikeserviceprocd enable")
    local suc, exitCode, code = os.execute("/etc/init.d/spikeserviceprocd start")
    if suc then
        return jsonc.stringify({ message = "spikeserviceprocd started successfully", error = nil, success = true })
    else
        return jsonc.stringify({ error = "Failed to start spikeserviceprocd", message = nil, success = false })
    end
end

local function firmw_disable()
    print("\r\n")
    local suc, exitCode, code = os.execute("/etc/init.d/spikeserviceprocd disable")
    if suc then
        return jsonc.stringify({ message = "spikeserviceprocd disabled successfully", error = nil, success = true })
    else
        return jsonc.stringify({ error = "Failed to disable spikeserviceprocd", message = nil, success = false })
    end
end

local function register_device(email, pin)
    print("\r\n")
    local mac = util.ubus("luci-rpc", "getNetworkDevices", {}).br0.mac
    local wireless = util.ubus("iwinfo", "info", { device = "ra0" })

    local brd_info = util.ubus("system", "board")

    local license = uci:get("wicrypt", "licence", "key")


    local body = jsonc.stringify({
        architecture = brd_info.system,
        bssid = wireless.bssid,
        deviceModel = brd_info.model,
        email = email,
        macAddress = mac,
        pin = pin,
        releaseVersion = "1.0.0",
        ssid = wireless.ssid
    })

    local curlCommand = string.format(
        'curl -s -X POST -H "Content-Type: application/json" -H "x-license-key: %s"  -d \'%s\' %s/api/v1/device',
        license,
        body, SERVER)
    local result = util.exec(curlCommand)
    return result
end

local function reg_status()
    print("\r\n")
    local bssid = util.ubus("iwinfo", "info", { device = "ra0" }).bssid
    local curlCommand = string.format(
        'curl -s -X GET -H encType="multipart/form-data" -d "" "%s/api/v1/device/status/%s"', SERVER, bssid)
    local result = util.exec(curlCommand)
    return result
end

local function firmw_service_status()
    print("\r\n")
    local spikeserviceprocd = util.ubus("luci", "getInitList", { name = "spikeserviceprocd" })
    if type(spikeserviceprocd) ~= "table" then
        return jsonc.stringify({ error = "Failed to get spikeserviceprocd status", success = false })
    end
    return jsonc.stringify(spikeserviceprocd)
end

local function memoryInfo()
    print("\r\n")
    local memory_info = util.ubus("system", "info")
    return jsonc.stringify({ data = memory_info, success = true, error = nil })
end

local function wireless()
    print("\r\n")
    local wireless_info_ra0 = util.ubus("iwinfo", "info", { device = "ra0" })
    local wireless_info_rai0 = util.ubus("iwinfo", "info", { device = "rai0" })
    local wireless_info = {
        ra0 = wireless_info_ra0,
        rai0 = wireless_info_rai0
    }
    return jsonc.stringify({ data = wireless_info, success = true, error = nil })
end

local function dhcplease()
    print("\r\n")
    local cusor = io.open("/tmp/dnsmasq.leases", "r")
    if cusor == nil then
        return jsonc.stringify({ data = {}, success = true, error = nil })
    end
    local content = cusor:read("*all")
    cusor:close()
    local result = {}
    -- format the dhcp data to json
    for line in content:gmatch("[^\r\n]+") do
        local parts = {}
        for part in line:gmatch("%S+") do
            table.insert(parts, part)
        end

        local entry = {
            timestamp = tonumber(parts[1]),
            mac = parts[2],
            ip = parts[3],
            clientName = parts[4] == "*" and nil or parts[4],
            additionalMac = parts[5]
        }

        table.insert(result, entry)
    end
    return jsonc.stringify({ data = result, success = true, error = nil })
end

local function wifi_devices()
    print("\r\n")
    local result = {}
    local devices = mtkwifi.get_all_devs()
    for _, device in ipairs(devices) do
        for _, vif in ipairs(device.vifs) do
            if vif.vifname == 'ra0' or vif.vifname == 'rai0' then
                table.insert(result, {
                    devname = device.devname,
                    vifs_prefix = device.vifs.__prefix,
                    ssid = vif.__ssid,
                    encrypttype = vif.__encrypttype,
                    authmode =
                        vif.__authmode,
                    vifname = vif.vifname,
                    hidessid = vif.__hidessid,
                    vifidx = vif.vifidx,
                    wpapsk = vif.__wpapsk
                })
            end
        end
    end
    return jsonc.stringify({ data = result, success = true, error = nil })
end

local function change_ssid(devname, newssid)
    print("\r\n")
    if devname == "5G" then
        util.exec("wc_wifi_config ssid5 " .. newssid)
    elseif devname == "2.4G" then
        util.exec("wc_wifi_config ssid2.4 " .. newssid)
    end
    return jsonc.stringify({ success = true, error = nil })
end

local function change_wireless_auth_config(devname, authmode, key)
    print("\r\n")
    if devname == "5G" and key ~= nil then
        util.exec("wc_wifi_config pwd5 " .. key)
    end
    if devname == "2.4G" and key ~= nil then
        util.exec("wc_wifi_config pwd2.4 " .. key)
    end
    if devname == "5G" and authmode ~= nil then
        util.exec("wc_wifi_config enc5 " .. authmode)
    elseif devname == "2.4G" and authmode ~= nil then
        util.exec("wc_wifi_config enc2.4 " .. authmode)
    end
    return jsonc.stringify({ success = true, error = nil })
end

local function whitelisted_devices()
    print("\r\n")
    local cursor = io.open("/etc/wicrypt/database/whitelisted_devices.json", "r")
    if cursor == nil then
        return jsonc.stringify({ data = {}, success = true, error = nil })
    end
    local content = cursor:read("*all")
    cursor:close()
    return jsonc.stringify({ data = jsonc.parse(content).data.records, success = true, error = nil })
end

local function whitelist_dev(mac, name)
    print("\r\n")
    local resp = util.exec("sh /etc/wicrypt/shellscripts/splash_page.sh whitelistDevice " .. mac .. " " .. name)
    return jsonc.stringify(jsonc.parse(resp))
end

local function delist_dev(mac, name)
    print("\r\n")
    local resp = util.exec("sh /etc/wicrypt/shellscripts/splash_page.sh unwhitelist " .. mac .. " " .. name)
    return jsonc.stringify(jsonc.parse(resp))
end

local function download_whitelisted()
    print("\r\n")
    util.exec("sh /etc/wicrypt/shellscripts/splash_page.sh whitelistedDevices")
    return jsonc.stringify({ success = true, error = nil })
end

local function download_firmw_file()
    print("\r\n")
    local suc, exitCode, code = os.execute("sh /etc/wicrypt/shellscripts/splash_page.sh staticFiles")
    if suc then
        return jsonc.stringify({ message = "required files downloaded successfully", error = nil, success = true })
    else
        return jsonc.stringify({ error = "Failed to download required files", message = nil, success = false })
    end
end

local function data_usage()
    print("\r\n")
    local res = util.exec(
        "sed -i 's/\"\"/\"/g' /etc/wicrypt/database/data_usage.json && cat /etc/wicrypt/database/data_usage.json")
    return jsonc.stringify({ data = jsonc.parse(res), success = true, error = nil })
end

local function firmw_version()
    print("\r\n")
    local res = util.exec("uci get wicrypt.firmwareAssetRelease.releaseVersion")
    return jsonc.stringify({ data = { firmware_version = res }, success = true, error = nil })
end

local function fetch_post_data()
    local content_length = tonumber(os.getenv("CONTENT_LENGTH"))
    if content_length then
        local post_data = ""
        local chunk
        repeat
            chunk = io.read(1024) -- Read 1 KB at a time
            if chunk then
                post_data = post_data .. chunk
            end
        until not chunk
        return post_data
    else
        return nil
    end
end

local function validate_session()
    print("\r\n")
    return jsonc.stringify({ success = true, error = nil })
end

local function api()
    local http_method = os.getenv("REQUEST_METHOD")
    if http_method == "POST" then
        local post_data = fetch_post_data()
        local json_data = jsonc.parse(post_data)
        local cookies = os.getenv("HTTP_COOKIE") or ""
        local session_id = cookies:match("sessionId=([^;]+)")
        if session_id == "00000000000000000000000000000000" then
            print("\r\n")
            return jsonc.stringify({ error = "Invalid Session", success = false })
        end
        local cmd = json_data.cmd or ""

        if cmd == "login" then
            return login(json_data.username or "root", json_data.password)
        else
            local session = util.ubus("session", "get", { ubus_rpc_session = session_id })
            if type(session) ~= "table" then
                print("\r\n")
                return jsonc.stringify({ error = "Invalid Session", success = false })
            end
        end
        if cmd == "board_info" then
            return board_info()
        elseif cmd == "firmw_enable" then
            return firmw_enable()
        elseif cmd == "firmw_disable" then
            return firmw_disable()
        elseif cmd == "reg_status" then
            return reg_status()
        elseif cmd == "firmw_status" then
            return firmw_service_status()
        elseif cmd == "memory_info" then
            return memoryInfo()
        elseif cmd == "wireless" then
            return wireless()
        elseif cmd == "dhcplease" then
            return dhcplease()
        elseif cmd == "register_device" then
            return register_device(json_data.email, json_data.pin)
        elseif cmd == "wifis" then
            return wifi_devices()
        elseif cmd == "change_ssid" then
            return change_ssid(json_data.devname, json_data.newssid)
        elseif cmd == "change_wireless_key" then
            return change_wireless_auth_config(json_data.devname, json_data.authmode, json_data.newkey)
        elseif cmd == "setup_firmw" then
            return download_firmw_file()
        elseif cmd == "whitelisted" then
            return whitelisted_devices()
        elseif cmd == "whitelist" then
            return whitelist_dev(json_data.mac, json_data.name)
        elseif cmd == "delist" then
            return delist_dev(json_data.mac, json_data.name)
        elseif cmd == "download_whitelisted" then
            return download_whitelisted()
        elseif cmd == "data_usg" then
            return data_usage()
        elseif cmd == "firmw_version" then
            return firmw_version()
        elseif cmd == "validate_session" then
            return validate_session()
        else
            return jsonc.stringify({ error = "Method not found", success = false })
        end
    else
        return jsonc.stringify({ error = "Method not allowed", success = false })
    end
end

local http_method = os.getenv("REQUEST_METHOD")
if http_method == "OPTIONS" then
    print("Access-Control-Allow-Origin: *")
    print("Access-Control-Allow-Methods: POST, GET, OPTIONS")
    print("Access-Control-Allow-Headers: Content-Type")
    print("Access-Control-Max-Age: 86400")
    print("Content-Type: application/json")
    print("\r\n")
    return
end
print("Access-Control-Allow-Origin: *")
print("Access-Control-Allow-Methods: POST, OPTIONS")
print("Access-Control-Allow-Headers: Content-Type")
print("Access-Control-Max-Age: 86400")
print("Content-Type: application/json")
print(api())
