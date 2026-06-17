#pragma semicolon 1
#pragma newdecls required

static StringMap g_Offsets;

void Offsets_Init(GameData gameconf)
{
	g_Offsets = new StringMap();
	
	SetOffset(gameconf, "CTFPlayer", "m_hReviveMarker");
	SetOffset(gameconf, "CCurrencyPack", "m_nAmount");
	SetOffset(gameconf, "CPopulationManager", "m_isRestoringCheckpoint");
}

any GetOffset(const char[] cls, const char[] prop)
{
	char key[64];
	Format(key, sizeof(key), "%s::%s", cls, prop);
	
	int offset;
	if (!g_Offsets.GetValue(key, offset))
	{
		ThrowError("Offset '%s' not present in map", key);
	}
	
	return offset;
}

static void SetOffset(GameData gameconf, const char[] cls, const char[] prop)
{
	char key[64], base_key[64], base_prop[64];
	Format(key, sizeof(key), "%s::%s", cls, prop);
	Format(base_key, sizeof(base_key), "%s_BaseOffset", cls);
	
	// Get the actual offset, calculated using a base offset if present
	if (gameconf.GetKeyValue(base_key, base_prop, sizeof(base_prop)))
	{
		int base_offset = FindSendPropInfo(cls, base_prop);
		if (base_offset == -1)
		{
			// If we found nothing, search on CBaseEntity instead
			base_offset = FindSendPropInfo("CBaseEntity", base_prop);
			if (base_offset == -1)
			{
				ThrowError("Base offset '%s::%s' could not be found", cls, base_prop);
			}
		}
		
		int rel_offset = gameconf.GetOffset(key);
		if (rel_offset == -1)
		{
			ThrowError("Offset '%s' could not be found", key);
		}

		int offset = base_offset + rel_offset;
		g_Offsets.SetValue(key, offset);
	}
	else
	{
		int offset = gameconf.GetOffset(key);
		if (offset == -1)
		{
			ThrowError("Offset '%s' could not be found", key);
		}
		
		g_Offsets.SetValue(key, offset);
	}
}
