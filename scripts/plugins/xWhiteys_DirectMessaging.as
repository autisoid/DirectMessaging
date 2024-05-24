class CWhisperer {
	string m_lpszSteamID;
	EHandle m_hLastTarget;
	
	CWhisperer(const string& in _SteamID) {
		m_lpszSteamID = _SteamID;
	}
}

array<CWhisperer@> g_aWhisperers;

CWhisperer@ DM_UTIL_GetWhispererBySteamID(const string& in _SteamID) {
    if (g_aWhisperers.length() == 0) return null; //save some computing powerz
    
    for (uint idx = 0; idx < g_aWhisperers.length(); idx++) {
        CWhisperer@ theWhisperer = g_aWhisperers[idx];
        
        if (theWhisperer.m_lpszSteamID == _SteamID) return theWhisperer;
    }

    return null;
}

void PluginInit() {
    g_Module.ScriptInfo.SetAuthor("xWhitey");
    g_Module.ScriptInfo.SetContactInfo("tyabus @ Discord");
	
    g_Hooks.RegisterHook(Hooks::Player::ClientSay, @HOOKED_ClientSay);
}

HookReturnCode HOOKED_ClientSay(SayParameters@ _Params) {
    const CCommand@ args = _Params.GetArguments();
	
	 if (args.ArgC() > 0 && 
		(args[0].ToLowercase().Find("/w") == 0 || args[0].ToLowercase().Find("/whisper") == 0 || args[0].ToLowercase().Find("/msg") == 0 || args[0].ToLowercase().Find("/m") == 0)) {
		if (args[0].ToLowercase().Find("/me") == 0) return HOOK_CONTINUE; 
		
		_Params.ShouldHide = true;
		
		if (args.ArgC() < 3) {
            g_PlayerFuncs.SayText(_Params.GetPlayer(), "Usage: " + args[0] + " <receiver> <message> - Send a private message to somebody.\n");
		
			return HOOK_CONTINUE;
		}
		
		if (args.ArgC() >= 3) {
            string szName = args[1].ToLowercase();
            CBasePlayer@ receiver = g_PlayerFuncs.FindPlayerByName(szName, false);
			if (receiver is null or !receiver.IsConnected()) {
                string szSecondAttempt = szName;
                for (uint idx = 0; idx < szSecondAttempt.Length(); idx++) {
                    if (szSecondAttempt[idx] == ',')
                        szSecondAttempt[idx] = ';';
                }
                
                @receiver = g_PlayerFuncs.FindPlayerByName(szSecondAttempt, false);
                
                if (receiver is null or !receiver.IsConnected()) {
                    g_PlayerFuncs.SayText(_Params.GetPlayer(), "Error: Couldn't find specified player.\n");
                    return HOOK_HANDLED;
                }
			}
            
			string text = _Params.GetCommand().SubString(args[0].Length() + szName.Length() + 2 /* two spaces */);
            if (text.StartsWith('" ')) {
                text = text.SubString(2); //FIXME
            }
			
			string szSenderID = g_EngineFuncs.GetPlayerAuthId(_Params.GetPlayer().edict());
			CWhisperer@ sender = DM_UTIL_GetWhispererBySteamID(szSenderID);
			if (sender is null) {
				@sender = CWhisperer(szSenderID);
				g_aWhisperers.insertLast(sender);
			}
			
			string szReceiverID = g_EngineFuncs.GetPlayerAuthId(receiver.edict());
			CWhisperer@ recver = DM_UTIL_GetWhispererBySteamID(szReceiverID);
			if (recver is null) {
				@recver = CWhisperer(szReceiverID);
				g_aWhisperers.insertLast(recver);
			}
			
			sender.m_hLastTarget = EHandle(receiver);
			recver.m_hLastTarget = EHandle(_Params.GetPlayer());
			
			g_PlayerFuncs.SayText(_Params.GetPlayer(), "* You whisper to " + receiver.pev.netname + ": " + text + "\n");
			g_PlayerFuncs.SayText(receiver, "* " + _Params.GetPlayer().pev.netname + " whispers to you: " + text + "\n");
		
			return HOOK_HANDLED;
		}
    
        return HOOK_HANDLED;
    }
	
	if (args.ArgC() > 0 && (args[0].ToLowercase().Find("/r") == 0 || args[0].ToLowercase().Find("/reply") == 0)) {
		_Params.ShouldHide = true;
		
		if (args.ArgC() == 1) {
			g_PlayerFuncs.SayText(_Params.GetPlayer(), "Usage: " + args[0] + " <message> - Fast reply to somebody (if they have DM'ed you)\n");
		
			return HOOK_HANDLED;
		}
		
		if (args.ArgC() >= 2) {
			CWhisperer@ sender = DM_UTIL_GetWhispererBySteamID(g_EngineFuncs.GetPlayerAuthId(_Params.GetPlayer().edict()));
			if (sender is null) {
				g_PlayerFuncs.SayText(_Params.GetPlayer(), "Error: You haven't sent a message to somebody yet! (Or nobody sent a message to you)\n");
			
				return HOOK_HANDLED;
			}
			
			if (sender.m_hLastTarget.IsValid()) {
				CBasePlayer@ target = cast<CBasePlayer@>(sender.m_hLastTarget.GetEntity());
			
				if (target is null || !target.IsConnected()) {
					g_PlayerFuncs.SayText(_Params.GetPlayer(), "Error: Couldn't find specified player.\n");
				
					return HOOK_HANDLED;
				}
                
                CWhisperer@ recv = DM_UTIL_GetWhispererBySteamID(g_EngineFuncs.GetPlayerAuthId(target.edict()));
                recv.m_hLastTarget = EHandle(_Params.GetPlayer());
				
				string text = _Params.GetCommand().SubString(args[0].Length() + 1 /* a space */);
			
				g_PlayerFuncs.SayText(_Params.GetPlayer(), "* You whisper to " + target.pev.netname + ": " + text + "\n");
				g_PlayerFuncs.SayText(target, "* " + _Params.GetPlayer().pev.netname + " whispers to you: " + text + "\n");
			} else {
				g_PlayerFuncs.SayText(_Params.GetPlayer(), "Error: You haven't sent a message to somebody yet! (Or nobody sent a message to you)\n");
			
				return HOOK_HANDLED;
			}
		
			return HOOK_HANDLED;
		}
		
        return HOOK_HANDLED;
	}
	
	return HOOK_CONTINUE;
}
