// @Prolog: #include "adchpp.h"
// @Prolog: #include "ResourceManager.h"
// @Prolog: namespace adchpp {

// @Strings: string ResourceManager::strings[]
// @Names: string ResourceManager::names[]

enum Strings { // @DontAdd
	B, // "B"
	BAD_IP, // "Your client's IP is incorrectly configured, and you will therefore be disconnected. Either you have to enter the correct one in the IP field in your client settings or try passive mode. Your current ip is: "
	CID_TAKEN, // "CID taken"
	DISK_FULL, // "Disk full?"
	ENTER_PASSWORD, // "Please send your password"
	FLOODING, // "You're flooding. Adios."
	GB, // "GiB"
	HUB_FULL, // "Hub is currently full"
	IP_UNALLOWED, // "You're connecting from an IP that's not allowed (banned) on this hub. If you feel this is wrong, you can always try contacting the owner of the hub."
	KB, // "KiB"
	MB, // "MiB"
	NICK_INVALID, // "Your nick contains invalid characters. Adios."
	NICK_TAKEN, // "Your nick is already taken, please select another one"
	NICK_TOO_LONG, // "Your nick is %d characters too long"
	NOT_CONNECTED, // "Not connected"
	PERMISSION_DENIED, // "Permission denied"
	PERM_BANNED, // "You're permanently banned from this hub. Go away."
	PERM_BANNED_REASON, // "You're permanently banned from this hub because: "
	SHARE_SIZE_NOT_MET, // "Share size requirement not met, you need to share %s more."
	TB, // "TiB"
	TEMP_BANNED, // "You're banned from this hub (time left: %s)."
	TEMP_BANNED_REASON, // "You're banned from this hub (time left: %s) because: "
	UNABLE_TO_CREATE_THREAD, // "Unable to create thread"
	LAST			// @DontAdd
};

// @Epilog: }
