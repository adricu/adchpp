%{

#include <adchpp/adchpp.h>
#include <adchpp/common.h>

#include <adchpp/Signal.h>
#include <adchpp/Client.h>
#include <adchpp/ClientManager.h>
#include <adchpp/LogManager.h>
#include <adchpp/SettingsManager.h>
#include <adchpp/SimpleXML.h>
#include <adchpp/Exception.h>
#include <adchpp/PluginManager.h>
#include <adchpp/TigerHash.h>
#include <adchpp/SocketManager.h>

using namespace adchpp;

%}

%include "exception.i"
%include "std_string.i"
%include "std_vector.i"
%include "std_except.i"
%include "std_pair.i"

%include "carrays.i"

%array_functions(size_t, size_t);

%exception {
	try {
		$action
	} catch(const std::exception& e) {
		SWIG_exception(SWIG_UnknownError, e.what());
	}
}

typedef unsigned char uint8_t;
typedef unsigned short uint16_t;
typedef unsigned int uint32_t;
typedef unsigned long long uint64_t;
typedef signed char int8_t;
typedef signed short int16_t;
typedef signed int int32_t;
typedef signed long long int64_t;
typedef unsigned int time_t;

using namespace std;

%inline%{
void startup() {
	adchpp::startup(0);
}
void shutdown() {
	adchpp::shutdown(0);
}
%}

%nodefaultctor;
%nodefaultdtor Client;
%nodefaultdtor ClientManager;
%nodefaultdtor LogManager;
%nodefaultdtor SettingsManager;
%nodefaultdtor Util;
%nodefaultdtor PluginManager;
%nodefaultdtor SocketManager;

namespace adchpp {
	class Client;
}

%template(TErrorPair) std::pair<int, size_t>;
%template(TErrorList) std::vector<std::pair<int, size_t> >;

%template(TClientList) std::vector<adchpp::Client*>;
%template(TStringList) std::vector<std::string>;

%template(TByteVector) std::vector<uint8_t>;

typedef std::vector<std::string> StringList;
%inline%{
typedef std::vector<adchpp::Client*> ClientList;
%}

namespace boost {
template<typename T>
class intrusive_ptr {
public:
	T* operator->();	
};
}

namespace adchpp {

void initialize(const std::string& configPath);
void cleanup();

template<typename F>
struct Signal {
};

template<typename Sig>
struct ManagedConnection {
	void disconnect();
	void release();
};

template<typename F>
struct SignalTraits {
	typedef Signal<F> Signal;
	typedef typename Signal::Connection Connection;
	typedef boost::intrusive_ptr<ManagedConnection<Signal> > ManagedConnection;
};

class Exception : public std::exception
{
public:
	Exception();
	Exception(const std::string& aError) throw();
	virtual ~Exception() throw();
	const std::string& getError() const throw();
	
	virtual const char* what();
};

struct Stats {
	static size_t queueCalls;
	static int64_t queueBytes;
	static size_t sendCalls;
	static int64_t sendBytes;
	static int64_t recvCalls;
	static int64_t recvBytes;
	static time_t startTime;
};

class Util  
{
public:
	enum Reason {
		REASON_BAD_STATE,
		REASON_CID_CHANGE,
		REASON_CID_TAKEN,
		REASON_FLOODING,
		REASON_HUB_FULL,
		REASON_INVALID_COMMAND_TYPE,
		REASON_INVALID_IP,
		REASON_INVALID_SID,
		REASON_LOGIN_TIMEOUT,
		REASON_MAX_COMMAND_SIZE,
		REASON_NICK_INVALID,
		REASON_NICK_TAKEN,
		REASON_NO_BASE_SUPPORT,
		REASON_NO_TIGR_SUPPORT,
		REASON_PID_MISSING,
		REASON_PID_CID_LENGTH,
		REASON_PID_CID_MISMATCH,
		REASON_PID_WITHOUT_CID,
		REASON_PLUGIN,
		REASON_WRITE_OVERFLOW,
		REASON_LAST,
	};

	static size_t reasons[REASON_LAST];
	
	static std::string emptyString;

	static void initialize(const std::string& configPath);
	static std::string getOsVersion();
	static void decodeUrl(const std::string& aUrl, std::string& aServer, short& aPort, std::string& aFile);
	static std::string formatTime(const std::string& msg, time_t t = time(NULL));
	
	static const std::string& getCfgPath();
	static void setCfgPath(const std::string& path);

	static std::string getAppPath();
	static std::string getAppName();

	static std::string translateError(int aError);
	
	static std::string toAcp(const std::wstring& wString);
	static const std::string& toAcp(const std::string& wString);

	static std::wstring toUnicode(const std::string& aString);
	static const std::wstring& toUnicode(const std::wstring& aString);

	static std::string formatBytes(const std::string& aString);

	static std::string getShortTimeString();
	static std::string getTimeString();
		
	static std::string formatBytes(int64_t aBytes);

	static void tokenize(StringList& lst, const std::string& str, char sep, std::string::size_type j = 0);

	static std::string formatSeconds(int64_t aSec);
	

	/** Avoid this! Use the one of a connected socket instead... */
	static std::string getLocalIp();

	static uint32_t rand();
	static uint32_t rand(uint32_t high);
	static uint32_t rand(uint32_t low, uint32_t high);
	static double randd();

};

class CID {
public:
	enum { SIZE = 192 / 8 };
	enum { BASE32_SIZE = 39 };

	CID();
	explicit CID(const uint8_t* data);
	explicit CID(const std::string& base32);

	bool operator==(const CID& rhs) const;
	bool operator<(const CID& rhs) const;

	std::string toBase32() const;
	//std::string& toBase32(std::string& tmp) const;

	size_t toHash() const;
	//const uint8_t* data() const;
	
	%extend {
		std::string data() const { return std::string(reinterpret_cast<const char*>(self->data()), CID::SIZE); }
		std::string __str__() { return self->toBase32(); }
	}  

	bool isZero() const;
	static CID generate();

};

class ParseException : public Exception {
public:
	ParseException() throw();
	ParseException(const std::string&) throw();
};

class AdcCommand {
public:
/*	template<uint32_t T>
	struct Type {
		enum { CMD = T };
	};
*/
	enum Error {
		ERROR_GENERIC = 0,
		ERROR_HUB_GENERIC = 10,
		ERROR_HUB_FULL = 11,
		ERROR_HUB_DISABLED = 12,
		ERROR_LOGIN_GENERIC = 20,
		ERROR_NICK_INVALID = 21,
		ERROR_NICK_TAKEN = 22,
		ERROR_BAD_PASSWORD = 23,
		ERROR_CID_TAKEN = 24,
		ERROR_COMMAND_ACCESS = 25,
		ERROR_REGGED_ONLY = 26,
		ERROR_INVALID_PID = 27,
		ERROR_BANNED_GENERIC = 30,
		ERROR_PERM_BANNED = 31,
		ERROR_TEMP_BANNED = 32,
		ERROR_PROTOCOL_GENERIC = 40,
		ERROR_PROTOCOL_UNSUPPORTED = 41,
		ERROR_INF_MISSING = 42,
		ERROR_BAD_STATE = 43,
		ERROR_FEATURE_MISSING = 44,
		ERROR_BAD_IP = 45,
		ERROR_TRANSFER_GENERIC = 50,
		ERROR_FILE_NOT_AVAILABLE = 51,
		ERROR_FILE_PART_NOT_AVAILABLE = 52,
		ERROR_SLOTS_FULL = 53
	};

	enum Severity {
		SEV_SUCCESS = 0,
		SEV_RECOVERABLE = 1,
		SEV_FATAL = 2
	};

	static const char TYPE_BROADCAST = 'B';
	static const char TYPE_CLIENT = 'C';
	static const char TYPE_DIRECT = 'D';
	static const char TYPE_ECHO = 'E';
	static const char TYPE_FEATURE = 'F';
	static const char TYPE_INFO = 'I';
	static const char TYPE_HUB = 'H';
	static const char TYPE_UDP = 'U';

	// Known commands...
#define C(n, a, b, c) static const unsigned int CMD_##n = (((uint32_t)a) | (((uint32_t)b)<<8) | (((uint32_t)c)<<16)); 
	// Base commands
	C(SUP, 'S','U','P');
	C(STA, 'S','T','A');
	C(INF, 'I','N','F');
	C(MSG, 'M','S','G');
	C(SCH, 'S','C','H');
	C(RES, 'R','E','S');
	C(CTM, 'C','T','M');
	C(RCM, 'R','C','M');
	C(GPA, 'G','P','A');
	C(PAS, 'P','A','S');
	C(QUI, 'Q','U','I');
	C(GET, 'G','E','T');
	C(GFI, 'G','F','I');
	C(SND, 'S','N','D');
	C(SID, 'S','I','D');
	// Extensions
	C(CMD, 'C','M','D');
#undef C

	enum { HUB_SID = 0xffffffff };

	AdcCommand();
	explicit AdcCommand(Severity sev, Error err, const std::string& desc, char aType);
	explicit AdcCommand(uint32_t cmd, char aType, uint32_t aFrom);
	explicit AdcCommand(const std::string& aLine) throw(ParseException);
	AdcCommand(const AdcCommand& rhs);

	void parse(const std::string& aLine) throw(ParseException);
	uint32_t getCommand() const;
	char getType() const;

	StringList& getParameters();
	//const StringList& getParameters() const;

	const std::string& toString() const;
	void resetString();

	AdcCommand& addParam(const std::string& name, const std::string& value);
	AdcCommand& addParam(const std::string& str);
	const std::string& getParam(size_t n) const;
	
	const std::string& getFeatures() const;

#ifndef SWIGLUA
	bool getParam(const char* name, size_t start, std::string& OUTPUT) const;
#endif
	bool delParam(const char* name, size_t start);
	
	bool hasFlag(const char* name, size_t start) const;
	static uint16_t toCode(const char* x);

	bool operator==(uint32_t aCmd) const;

	static void escape(const std::string& s, std::string& out);

	uint32_t getTo() const;
	void setTo(uint32_t aTo);
	uint32_t getFrom() const;
	void setFrom(uint32_t aFrom);

	static uint32_t toSID(const std::string& aSID);
	static std::string fromSID(const uint32_t aSID);
	static void appendSID(std::string& str, uint32_t aSID);

%extend {
	std::string getCommandString() {
		int cmd = self->getCommand();
		return std::string(reinterpret_cast<const char*>(&cmd), 3);
	}
	static uint32_t toCMD(const std::string& cmd) {
		if(cmd.length() != 3) {
			return 0;
		}
		return (((uint32_t)cmd[0]) | (((uint32_t)cmd[1])<<8) | (((uint32_t)cmd[2])<<16));
	}
}
	
};

class Client {
public:
	enum State {
		STATE_PROTOCOL,
		STATE_IDENTIFY,
		STATE_VERIFY,
		STATE_NORMAL,
		STATE_DATA
	};
	
	enum {
		FLAG_BOT = 0x01,
		FLAG_REGISTERED = 0x02,
		FLAG_OP = 0x04,
		FLAG_SU = 0x08,
		FLAG_OWNER = 0x10,
		FLAG_HUB = 0x20,
		MASK_CLIENT_TYPE = FLAG_BOT | FLAG_REGISTERED | FLAG_OP | FLAG_SU | FLAG_OWNER | FLAG_HUB,
		FLAG_PASSWORD = 0x100,
		FLAG_HIDDEN = 0x101,
		/** Extended away, no need to send msg */
		FLAG_EXT_AWAY = 0x102,
		/** Plugins can use these flags to disable various checks */
		/** Bypass ip check */
		FLAG_OK_IP = 0x104
	};

	//static Client* create(uint32_t sid) throw();
	//DLL void deleteThis() throw();

	const StringList& getSupportList() const throw();
	bool supports(const std::string& feat) const throw();

	//void send(const char* command, size_t len) throw();
	void send(const AdcCommand& cmd) throw();
	void send(const std::string& command) throw();
	//void send(const char* command) throw();

	void disconnect(Util::Reason reason) throw();
	//ManagedSocket* getSocket() throw() { return socket; }
	//const ManagedSocket* getSocket() const throw() { return socket; }
	const std::string& getIp() const throw();

	//void setSocket(ManagedSocket* aSocket) throw();

	//void setDataMode(std::tr1::function<void (const uint8_t*, size_t)> handler, int64_t aBytes) { dataHandler = handler; dataBytes = aBytes; }

	/** Add any flags that have been updated to the AdcCommand (type etc is not set) */
	bool getChangedFields(AdcCommand& cmd);
	bool getAllFields(AdcCommand& cmd);

	void resetChanged() { changed.clear(); }

	const std::string& getField(const char* name) const throw();
	void setField(const char* name, const std::string& value) throw();

	void updateFields(const AdcCommand& cmd) throw();
	void updateSupports(const AdcCommand& cmd) throw();

	bool isUdpActive();
	bool isTcpActive();

	bool isFiltered(const std::string& features) const;

	bool isFlooding(time_t addSeconds);
	
	//void* setPSD(int id, void* data) throw();
	//void* getPSD(int id) throw();
	
	const CID& getCID() const { return cid; }
	void setCID(const CID& cid_) { cid = cid_; }
	uint32_t getSID() const { return sid; }
	State getState() const { return state; }
	void setState(State state_) { state = state_; }

	//Client(uint32_t aSID) throw();
	//virtual ~Client() throw() { }
};

class LogManager
{
public:
	void log(const std::string& area, const std::string& msg) throw();
	void logDateTime(const std::string& area, const std::string& msg) throw();
};

%template(SignalC) Signal<void (Client&)>;
%template(SignalTraitsC) SignalTraits<void (Client&)>;
%template(SignalCA) Signal<void (Client&, AdcCommand&)>;
%template(SignalTraitsCA) SignalTraits<void (Client&, AdcCommand&)>;
%template(SignalCAI) Signal<void (Client&, AdcCommand&, int&)>;
%template(SignalTraitsCAI) SignalTraits<void (Client&, AdcCommand&, int&)>;
%template(SignalCI) Signal<void (Client&, int)>;
%template(SignalTraitsCI) SignalTraits<void (Client&, int)>;
%template(SignalCS) Signal<void (Client&, const std::string&)>;
%template(SignalTraitsCS) SignalTraits<void (Client&, const std::string&)>;
%template(SignalS) Signal<void (const SimpleXML&)>;
%template(SignalTraitsS) SignalTraits<void (const SimpleXML&)>;

%template(ManagedC) boost::intrusive_ptr<ManagedConnection<Signal<void (Client&)> > >;
%template(ManagedCA) boost::intrusive_ptr<ManagedConnection<Signal<void (Client&, AdcCommand&)> > >;
%template(ManagedCAI) boost::intrusive_ptr<ManagedConnection<Signal<void (Client&, AdcCommand&, int&)> > >;
%template(ManagedCI) boost::intrusive_ptr<ManagedConnection<Signal<void (Client&, int)> > >;
%template(ManagedCS) boost::intrusive_ptr<ManagedConnection<Signal<void (Client&, const std::string&)> > >;
%template(ManagedS) boost::intrusive_ptr<ManagedConnection<Signal<const SimpleXML&> > >;

%extend Signal<void (Client&)> {
	SignalTraits<void (Client&)>::ManagedConnection connect(std::tr1::function<void (Client&)> f) {
		return manage(self, f);
	}
}

%extend Signal<void (Client&, AdcCommand&)> {
	SignalTraits<void (Client&, AdcCommand&)>::ManagedConnection connect(std::tr1::function<void (Client&, AdcCommand&)> f) {
		return manage(self, f);
	}
}

%extend Signal<void (Client&, AdcCommand&, int&)> {
	SignalTraits<void (Client&, AdcCommand&, int&)>::ManagedConnection connect(std::tr1::function<void (Client&, AdcCommand&, int&)> f) {
		return manage(self, f);
	}
}

%extend Signal<void (Client&, int)> {
	SignalTraits<void (Client&, int)>::ManagedConnection connect(std::tr1::function<void (Client&, int)> f) {
		return manage(self, f);
	}
}

%extend Signal<void (Client&, const std::string&)> {
	SignalTraits<void (Client&, const std::string&)>::ManagedConnection connect(std::tr1::function<void (Client&, const std::string&)> f) {
		return manage(self, f);
	}
}

%extend Signal<void (const SimpleXML&)> {
	SignalTraits<void (const SimpleXML&)>::ManagedConnection connect(std::tr1::function<void (const SimpleXML&)> f) {
		return manage(self, f);
	}
}

class SocketManager {
	public:
};

class ClientManager 
{
public:
	enum SignalCommandOverride {
		DONT_DISPATCH = 1 << 0,
		DONT_SEND = 1 << 1
	};
	
	//typedef HASH_MAP<uint32_t, Client*> ClientMap;
	//typedef ClientMap::iterator ClientIter;
	
	void addSupports(const std::string& str) throw();
	void removeSupports(const std::string& str) throw();

	void updateCache() throw();
	
	uint32_t getSID(const std::string& nick) const throw();
	uint32_t getSID(const CID& cid) const throw();
	
	Client* getClient(const uint32_t& aSid) throw();
	//ClientMap& getClients() throw() { return clients; }
	%extend{
	ClientList getClients() throw() {
		ClientList ret;
		for(ClientManager::ClientMap::iterator i = self->getClients().begin(); i != self->getClients().end(); ++i) {
			ret.push_back(i->second);
		}
		return ret;
	}
	Client* findByNick(const std::string& nick) {
		for(ClientManager::ClientMap::iterator i = self->getClients().begin(); i != self->getClients().end(); ++i) {
			const std::string& nick2 = i->second->getField("NI");
			if(nick == nick2)
				return i->second;
		}
		return 0;
	}
	}
	
	void send(const AdcCommand& cmd, bool lowPrio = false) throw();
	void sendToAll(const AdcCommand& cmd) throw();
	void sendToAll(const std::string& cmd) throw();
	void sendTo(const AdcCommand& cmd, const uint32_t& to) throw();

	bool checkFlooding(Client& c, const AdcCommand&) throw();
	
	void enterIdentify(Client& c, bool sendData) throw();

	ByteVector enterVerify(Client& c, bool sendData) throw();

	bool enterNormal(Client& c, bool sendData, bool sendOwnInf) throw();
	bool verifySUP(Client& c, AdcCommand& cmd) throw();
	bool verifyINF(Client& c, AdcCommand& cmd) throw();
	bool verifyNick(Client& c, const AdcCommand& cmd) throw();
	bool verifyPassword(Client& c, const std::string& password, const ByteVector& salt, const std::string& suppliedHash);
	bool verifyIp(Client& c, AdcCommand& cmd) throw();
	bool verifyCID(Client& c, AdcCommand& cmd) throw();

	void setState(Client& c, Client::State newState) throw();
	
	size_t getQueuedBytes() throw();
	
	//void incomingConnection(ManagedSocket* ms) throw();
	
	//void startup() throw() { updateCache(); }
	//void shutdown();
	
	typedef SignalTraits<void (Client&)> SignalConnected;
	typedef SignalTraits<void (Client&, AdcCommand&, int&)> SignalReceive;
	typedef SignalTraits<void (Client&, const std::string&)> SignalBadLine;
	typedef SignalTraits<void (Client&, AdcCommand&, int&)> SignalSend;
	typedef SignalTraits<void (Client&, int)> SignalState;
	typedef SignalTraits<void (Client&)> SignalDisconnected;

	SignalConnected::Signal& signalConnected() { return signalConnected_; }
	SignalReceive::Signal& signalReceive() { return signalReceive_; }
	SignalBadLine::Signal& signalBadLine() { return signalBadLine_; }
	SignalSend::Signal& signalSend() { return signalSend_; }
	SignalState::Signal& signalState() { return signalState_; }
	SignalDisconnected::Signal& signalDisconnected() { return signalDisconnected_; }

	//virtual ~ClientManager() throw() { }
};

class SimpleXML  
{
public:
	SimpleXML(int numAttribs = 0);
	~SimpleXML();
	
	void addTag(const std::string& aName, const std::string& aData = Util::emptyString) throw(SimpleXMLException);
	void addAttrib(const std::string& aName, const std::string& aData) throw(SimpleXMLException);
	void addChildAttrib(const std::string& aName, const std::string& aData) throw(SimpleXMLException);

	const std::string& getData() const;
	void stepIn() const throw(SimpleXMLException);
	void stepOut() const throw(SimpleXMLException);
	
	void resetCurrentChild() const throw();
	bool findChild(const std::string& aName) const throw();

	const std::string& getChildData() const throw(SimpleXMLException);

	const std::string& getChildAttrib(const std::string& aName, const std::string& aDefault = Util::emptyString) const throw(SimpleXMLException);

	int getIntChildAttrib(const std::string& aName) throw(SimpleXMLException);
	int64_t getLongLongChildAttrib(const std::string& aName) throw(SimpleXMLException);
	bool getBoolChildAttrib(const std::string& aName) throw(SimpleXMLException);
	void fromXML(const std::string& aXML) throw(SimpleXMLException);
	std::string toXML();
	
	static void escape(std::string& aString, bool aAttrib, bool aLoading = false);
	/** 
	 * This is a heurestic for whether escape needs to be called or not. The results are
 	 * only guaranteed for false, i e sometimes true might be returned even though escape
	 * was not needed...
	 */
	static bool needsEscape(const std::string& aString, bool aAttrib, bool aLoading = false);
};

class SettingsManager
{
public:
	enum Types {
		TYPE_STRING,
		TYPE_INT,
		TYPE_INT64
	};

	enum StrSetting { STR_FIRST,
		HUB_NAME = STR_FIRST, SERVER_IP, LOG_FILE, DESCRIPTION,
		STR_LAST };

	enum IntSetting { INT_FIRST = STR_LAST + 1,
		SERVER_PORT = INT_FIRST, LOG, KEEP_SLOW_USERS, 
		MAX_SEND_SIZE, MAX_BUFFER_SIZE, BUFFER_SIZE, MAX_COMMAND_SIZE, 
		OVERFLOW_TIMEOUT, DISCONNECT_TIMEOUT, FLOOD_ADD, FLOOD_THRESHOLD, 
		LOGIN_TIMEOUT,
		INT_LAST };

	//bool getType(const char* name, int& n, int& type);
	const std::string& getName(int n) { dcassert(n < SETTINGS_LAST); return settingTags[n]; }

%extend {
	const std::string& getString(StrSetting key) {
		return self->get(key);
	}
	int getInt(IntSetting key) {
		return self->get(key);
	}
	void setString(StrSetting key, std::string const& value) {
		self->set(key, value);
	}
	void setInt(IntSetting key, int value) {
		self->set(key, value);
	}
	void setBool(IntSetting key, bool value) {
		self->set(key, value);
	}
}
	bool getBool(IntSetting key) const;
	
	typedef SignalTraits<void (const SimpleXML&)> SignalLoad;
	SignalLoad::Signal& signalLoad();
};

class TigerHash {
public:
	/** Hash size in bytes */
	enum { HASH_SIZE = 24 };

	TigerHash();
	
	%extend {
		void update(const std::string& data) {
			self->update(data.data(), data.size());
		}
		std::string finalize() {
			return std::string(reinterpret_cast<const char*>(self->finalize()), TigerHash::HASH_SIZE);
		}
	}
};

class Encoder
{
public:
	%extend {
		static std::string toBase32(const std::string& src) {
			return Encoder::toBase32(reinterpret_cast<const uint8_t*>(src.data()), src.size());
		}
		static std::string fromBase32(const std::string& src) {
			std::string result((src.length()*5)/8, 0);
			Encoder::fromBase32(src.data(), reinterpret_cast<uint8_t*>(&result[0]), result.size());
			return result;
		}
	}
};

class PluginManager 
{
public:
	//typedef HASH_MAP<std::string, Plugin*> Registry;
	//typedef Registry::iterator RegistryIter;

	const StringList& getPluginList() const;
	const std::string& getPluginPath() const;
	//int getPluginId() { return pluginIds++; }

	//bool registerPlugin(const std::string& name, Plugin* ptr);
	//bool unregisterPlugin(const std::string& name);
	//Plugin* getPlugin(const std::string& name);
	//const Registry& getPlugins();
	//void load();
	//void shutdown();
};


}

%inline%{
namespace adchpp {
	ClientManager* getCM() { return ClientManager::getInstance(); }
	LogManager* getLM() { return LogManager::getInstance(); }
	SettingsManager* getSM() { return SettingsManager::getInstance(); }
	PluginManager* getPM() { return PluginManager::getInstance(); }
	SocketManager* getSocketManager() { return SocketManager::getInstance(); }
}
%}
