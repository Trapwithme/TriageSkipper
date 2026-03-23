#include <windows.h>
#include <wbemidl.h>
#include <comdef.h>
#include <string>
#include <vector>
#include <fstream>
#include <sstream>
#include <algorithm>

#pragma comment(lib, "wbemuuid.lib")

static const wchar_t* MOUSE_ID = L"ACPI\\PNP0F13\\4&22F5829E&0";
static const wchar_t* MOUSE_NAME = L"PS2/2 Compatible Mouse";
static const wchar_t* INPUT_ID = L"USB\\VID_0627&PID_0001\\28754-0000:00:04.0-1";
static const wchar_t* INPUT_NAME = L"USB Input Device";
static const wchar_t* MONITOR_ID = L"DISPLAY\\RHT1234\\4&22F5829E&0";
static const wchar_t* MONITOR_NAME = L"Generic PnP Monitor";
static const wchar_t* KEYBOARD_ID = L"ACPI\\PNP0303\\4&22F5829E&0";
static const wchar_t* KEYBOARD_NAME = L"Standard PS/2 Keyboard";
static const wchar_t* CPU = L"Intel Core Processor (Broadwell)";
static const std::string WALLPAPER_SIG = "/9j/4AAQSkZJRgABAQAAAQABAAD/2wCEAAwMDAwMDA0ODg0SExETEhsYFhYYGygd";

bool contains_ci(const std::wstring& s, const std::wstring& needle) {
    auto lower = [](std::wstring v) {
        std::transform(v.begin(), v.end(), v.begin(), towlower);
        return v;
    };
    return lower(s).find(lower(needle)) != std::wstring::npos;
}

std::wstring bstr_to_wstring(BSTR b) {
    if (!b) return L"";
    return std::wstring(b, SysStringLen(b));
}

int query_and_count(IWbemServices* svc, const wchar_t* query, const wchar_t* valueField, const wchar_t* idNeedle, const wchar_t* descField, const wchar_t* descNeedle) {
    int idx = 0;
    IEnumWbemClassObject* enumerator = nullptr;
    HRESULT hr = svc->ExecQuery(
        bstr_t("WQL"),
        bstr_t(query),
        WBEM_FLAG_FORWARD_ONLY | WBEM_FLAG_RETURN_IMMEDIATELY,
        nullptr,
        &enumerator
    );
    if (FAILED(hr) || !enumerator) return 0;

    IWbemClassObject* obj = nullptr;
    ULONG returned = 0;
    while (enumerator->Next(WBEM_INFINITE, 1, &obj, &returned) == S_OK) {
        VARIANT vVal; VariantInit(&vVal);
        VARIANT vDesc; VariantInit(&vDesc);

        std::wstring idVal, descVal;
        if (SUCCEEDED(obj->Get(valueField, 0, &vVal, nullptr, nullptr)) && vVal.vt == VT_BSTR) {
            idVal = bstr_to_wstring(vVal.bstrVal);
        }
        if (descField && SUCCEEDED(obj->Get(descField, 0, &vDesc, nullptr, nullptr)) && vDesc.vt == VT_BSTR) {
            descVal = bstr_to_wstring(vDesc.bstrVal);
        }

        if (!idVal.empty() && contains_ci(idVal, idNeedle)) {
            idx++;
            if (!descVal.empty() && descNeedle && contains_ci(descVal, descNeedle)) {
                idx++;
            }
        }

        VariantClear(&vVal);
        VariantClear(&vDesc);
        obj->Release();
    }

    enumerator->Release();
    return idx;
}

std::string base64_encode(const std::vector<unsigned char>& data) {
    static const char* tbl = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
    std::string out;
    int val = 0, valb = -6;
    for (unsigned char c : data) {
        val = (val << 8) + c;
        valb += 8;
        while (valb >= 0) {
            out.push_back(tbl[(val >> valb) & 0x3F]);
            valb -= 6;
        }
    }
    if (valb > -6) out.push_back(tbl[((val << 8) >> (valb + 8)) & 0x3F]);
    while (out.size() % 4) out.push_back('=');
    return out;
}

std::wstring get_wallpaper() {
    HKEY key;
    if (RegOpenKeyExW(HKEY_CURRENT_USER, L"Control Panel\\Desktop", 0, KEY_READ, &key) != ERROR_SUCCESS) return L"";
    wchar_t buf[MAX_PATH] = {0};
    DWORD size = sizeof(buf);
    if (RegQueryValueExW(key, L"Wallpaper", nullptr, nullptr, reinterpret_cast<LPBYTE>(buf), &size) != ERROR_SUCCESS) {
        RegCloseKey(key);
        return L"";
    }
    RegCloseKey(key);
    return std::wstring(buf);
}

bool triage_v2() {
    std::wstring wp = get_wallpaper();
    if (wp.empty()) return false;

    std::ifstream f(wp, std::ios::binary);
    if (!f) return false;
    std::vector<unsigned char> bytes((std::istreambuf_iterator<char>(f)), std::istreambuf_iterator<char>());
    if (bytes.empty()) return false;

    std::string b64 = base64_encode(bytes);
    std::string prefix = b64.substr(0, std::min<size_t>(64, b64.size()));
    return prefix == WALLPAPER_SIG;
}

int main() {
    CoInitializeEx(nullptr, COINIT_MULTITHREADED);
    CoInitializeSecurity(nullptr, -1, nullptr, nullptr, RPC_C_AUTHN_LEVEL_DEFAULT, RPC_C_IMP_LEVEL_IMPERSONATE, nullptr, EOAC_NONE, nullptr);

    IWbemLocator* locator = nullptr;
    IWbemServices* svc = nullptr;
    if (FAILED(CoCreateInstance(CLSID_WbemLocator, 0, CLSCTX_INPROC_SERVER, IID_IWbemLocator, (LPVOID*)&locator))) return 0;
    if (FAILED(locator->ConnectServer(_bstr_t(L"ROOT\\CIMV2"), nullptr, nullptr, 0, 0, 0, 0, &svc))) return 0;

    CoSetProxyBlanket(svc, RPC_C_AUTHN_WINNT, RPC_C_AUTHZ_NONE, nullptr, RPC_C_AUTHN_LEVEL_CALL, RPC_C_IMP_LEVEL_IMPERSONATE, nullptr, EOAC_NONE);

    int total = 0;
    total += query_and_count(svc, L"SELECT Description, DeviceID FROM Win32_Keyboard", L"DeviceID", KEYBOARD_ID, L"Description", KEYBOARD_NAME);
    total += query_and_count(svc, L"SELECT Description, PNPDeviceID FROM Win32_PointingDevice", L"PNPDeviceID", MOUSE_ID, L"Description", MOUSE_NAME);
    total += query_and_count(svc, L"SELECT Description, PNPDeviceID FROM Win32_PointingDevice", L"PNPDeviceID", INPUT_ID, L"Description", INPUT_NAME);
    total += query_and_count(svc, L"SELECT Description, PNPDeviceID FROM Win32_DesktopMonitor", L"PNPDeviceID", MONITOR_ID, L"Description", MONITOR_NAME);
    total += query_and_count(svc, L"SELECT Name FROM Win32_Processor", L"Name", CPU, nullptr, nullptr);

    bool detected = total >= 5 || triage_v2();
    if (detected) {
        MessageBoxW(nullptr, L"Virtual Machine Detected", L"System Check", MB_OK | MB_ICONWARNING);
        return 1;
    }

    locator->Release();
    svc->Release();
    CoUninitialize();
    return 0;
}
