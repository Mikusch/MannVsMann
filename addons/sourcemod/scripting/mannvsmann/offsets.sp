#pragma semicolon 1
#pragma newdecls required

static StringMap g_Offsets;
static GameData g_GameConf;

void Offsets_Init(GameData gameconf)
{
	g_Offsets = new StringMap();
	g_GameConf = view_as<GameData>(CloneHandle(gameconf));
}

int GetOffset(const char[] key)
{
	int offset;
	if (!g_Offsets.GetValue(key, offset))
	{
		offset = ResolveRelativeOffset(g_GameConf, key);
		g_Offsets.SetValue(key, offset);
	}

	return offset;
}

static int ResolveRelativeOffset(GameData gameconf, const char[] key)
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
		ThrowError("Relative offset '%s' has a malformed spec '%s' (expected 'Class::prop+delta')", key, spec);
	}

	char anchor[64];
	strcopy(anchor, sizeof(anchor), spec);
	anchor[split] = '\0';
	int delta = sign * StringToInt(spec[split + 1]);

	int sep = StrContains(anchor, "::");
	if (sep == -1)
	{
		ThrowError("Anchor '%s' for offset '%s' must be qualified as 'Class::prop'", anchor, key);
	}

	char cls[64];
	strcopy(cls, sizeof(cls), anchor);
	cls[sep] = '\0';

	int base = FindSendPropInfo(cls, anchor[sep + 2]);
	if (base <= 0)
	{
		ThrowError("Anchor '%s' for offset '%s' could not be resolved (FindSendPropInfo returned %d)", anchor, key, base);
	}

	int offset = base + delta;
	LogMessage("Resolved offset %s = %d (anchor %s at %d, delta %d)", key, offset, anchor, base, delta);

	return offset;
}
