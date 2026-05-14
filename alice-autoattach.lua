--[[
  CheatEngine autorun: attach to game + load CheatTable + tick entries.
  Copied to CE autorun/custom/ by launch script before CE starts.
  The %%CT_PATH%% placeholder is replaced with the real path at copy time.
  Self-deletes after running so it doesn't fire on unrelated CE sessions.
]]
local SCRIPT_PATH = debug.getinfo(1, "S").source:match("@?(.*)")
local TARGET_CT = [[%%CT_PATH%%]]

local pid = nil
pcall(function() pid = getProcessIDFromProcessName("AliceMadnessReturns.exe") end)
if not pid or pid == 0 then
  pcall(os.remove, SCRIPT_PATH)
  return
end
pcall(function() openProcess(pid) end)

local function log(msg)
  if _G.amrOut then _G.amrOut(msg) else print(msg) end
end
log(string.format("[autoattach] Attached to PID %d", pid))

local al = getAddressList()
if not al or al.Count == 0 then
  local ok, err = pcall(function() loadTable(TARGET_CT) end)
  if not ok then
    log(string.format("[autoattach] loadTable failed: %s", tostring(err)))
    pcall(os.remove, SCRIPT_PATH)
    return
  end
  log("[autoattach] Loaded CT")
  al = getAddressList()
end

for _, id in ipairs({0, 7}) do
  local mr = al.getMemoryRecordByID(id)
  if mr then
    mr.Active = true
    log(string.format("[autoattach] ID %d %s", id,
      mr.Active and "ticked" or "FAILED to tick"))
  else
    log(string.format("[autoattach] ID %d not found in table", id))
  end
end

pcall(os.remove, SCRIPT_PATH)
