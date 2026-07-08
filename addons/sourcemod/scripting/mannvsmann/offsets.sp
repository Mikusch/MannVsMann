#pragma semicolon 1
#pragma newdecls required

static StringMap g_Offsets;

void Offsets_Init(GameData gameconf)
{
	g_Offsets = new StringMap();

	SetOffset(gameconf, "CTFPlayer", "CTFPlayer::m_hReviveMarker");
	SetOffset(gameconf, "CCurrencyPack", "CCurrencyPack::m_nAmount");
	SetOffset(gameconf, "CPopulationManager", "CPopulationManager::m_isRestoringCheckpoint");
}

int GetOffset(const char[] key)
{
	int offset;
	if (!g_Offsets.GetValue(key, offset))
	{
		ThrowError("Offset '%s' not present in map", key);
	}

	return offset;
}

static void SetOffset(GameData gameconf, const char[] cls, const char[] key)
{
	char spec[64];
	if (!gameconf.GetKeyValue(key, spec, sizeof(spec)))
	{
		ThrowError("Relative offset '%s' is missing from gamedata", key);
	}

	int sign = 1;
	int split = FindCharInString(spec, '+');
	if (split == -1)
	{
		split = FindCharInString(spec, '-');
		sign = -1;
	}
	if (split == -1)
	{
		ThrowError("Relative offset '%s' has a malformed spec '%s' (expected '<prop>+<delta>')", key, spec);
	}

	char anchor[64];
	strcopy(anchor, sizeof(anchor), spec);
	anchor[split] = '\0';
	int delta = sign * StringToInt(spec[split + 1]);

	int base = FindSendPropInfo(cls, anchor);
	if (base <= 0)
	{
		base = FindSendPropInfo("CBaseEntity", anchor);
	}
	if (base <= 0)
	{
		ThrowError("Anchor prop '%s' for offset '%s' could not be resolved (FindSendPropInfo returned %d)", anchor, key, base);
	}

	int offset = base + delta;
	LogMessage("Resolved offset %s = %d (anchor %s at %d, delta %d)", key, offset, anchor, base, delta);

	g_Offsets.SetValue(key, offset);
}
