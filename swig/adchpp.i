%{

#include <adchpp/adchpp.h>
#include <adchpp/common.h>

#include <adchpp/Signal.h>
#include <adchpp/Client.h>

using namespace adchpp;

%}

%include "std_string.i"
%include "std_vector.i"
using namespace std;

%inline%{
void startup() {
	adchpp::startup(0);
}
void shutdown() {
	adchpp::shutdown(0);
}
%}

namespace adchpp {

void initConfig(const std::string& configPath);

typedef std::vector<std::string> StringList;

template<typename F>
struct Signal {
	void operator()();	
	template<typename T0>
	void operator()(T0& t0);
	template<typename T0, typename T1>
	void operator()(T0& t0, T1& t1);
	
	template<typename T0, typename T1, typename T2>
	void operator()(const T0& t0, const T1& t1, const T2& t2);

	template<typename T0, typename T1, typename T2>
	void operator()(const T0& t0, T1& t1, T2& t2);
	
	template<typename T0, typename T1, typename T2>
	void operator()(T0& t0, T1& t1, T2& t2);
	
	~Signal() { }
};

template<typename Sig>
struct ManagedConnection {
	ManagedConnection();
	ManagedConnection(const typename Sig::Connection& conn);
	
	~ManagedConnection();
	typename Sig::Connection connection;
};

class CID {
public:
	enum { SIZE = 192 / 8 };
	enum { BASE32_SIZE = 39 };

	CID();
	explicit CID(const uint8_t* data);
	explicit CID(const string& base32);

	bool operator==(const CID& rhs) const;
	bool operator<(const CID& rhs) const;

	string toBase32() const;
	//string& toBase32(string& tmp) const;

	size_t toHash() const;
	const uint8_t* data() const;

	bool isZero() const;
	static CID generate();

};

%nodefaultctor Client;

class Client {
public:
	enum State {
		/** Initial protocol negotiation (wait for SUP) */
		STATE_PROTOCOL,
		/** Identify the connecting client (wait for INF) */
		STATE_IDENTIFY,
		/** Verify the client (wait for PAS) */
		STATE_VERIFY,
		/** Normal operation */
		STATE_NORMAL,
		/** Binary data transfer */
		STATE_DATA
	};

	enum {
		FLAG_BOT = 0x01,
		FLAG_OP = 0x02,				
		FLAG_PASSWORD = 0x04,
		FLAG_HIDDEN = 0x08,
		FLAG_HUB = 0x10,
		/** Extended away, no need to send msg */
		FLAG_EXT_AWAY = 0x20,
		/** Plugins can use these flags to disable various checks */
		/** Bypass max users count */
		FLAG_OK_COUNT = 0x80,
		/** Bypass ip check */
		FLAG_OK_IP = 0x100
	};

	//DLL static Client* create(uint32_t sid) throw();
	//DLL void deleteThis() throw();

	const StringList& getSupportList() const throw();
	bool supports(const string& feat) const throw();

	//void send(const char* command, size_t len) throw();
	//void send(const AdcCommand& cmd) throw();
	void send(const string& command) throw();
	void send(const char* command) throw();

	void disconnect() throw();
	//ManagedSocket* getSocket() throw() { return socket; }
	//const ManagedSocket* getSocket() const throw() { return socket; }
	const string& getIp() const throw();

	//void setSocket(ManagedSocket* aSocket) throw();

	//void setDataMode(boost::function<void (const uint8_t*, size_t)> handler, int64_t aBytes) { dataHandler = handler; dataBytes = aBytes; }

	/** Add any flags that have been updated to the AdcCommand (type etc is not set) */
	//bool getChangedFields(AdcCommand& cmd);
	//bool getAllFields(AdcCommand& cmd);

	//void resetChanged() { changed.clear(); }

	const string& getField(const char* name) const throw();
	void setField(const char* name, const string& value) throw();

	//void updateFields(const AdcCommand& cmd) throw();
	//void updateSupports(const AdcCommand& cmd) throw();

	bool isUdpActive();
	bool isTcpActive();

	bool isFlooding(time_t addSeconds);
	
	//void* setPSD(int id, void* data) throw();
	//void* getPSD(int id) throw();
	
	//const CID& getCID() const { return cid; }
	//void setCID(const CID& cid_) { cid = cid_; }
	uint32_t getSID() const { return sid; }
	State getState() const { return state; }
	void setState(State state_) { state = state_; }

	//Client(uint32_t aSID) throw();
	//virtual ~Client() throw() { }
};

}
