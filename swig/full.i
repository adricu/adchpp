// Full API into the adchpp core

%include "adchpp.i"

%template(TCorePtr) shared_ptr<adchpp::Core>;

namespace adchpp {

class Core {
public:
	typedef std::function<void()> Callback;

	static shared_ptr<Core> create(const std::string &configPath);

	void run();

	void shutdown();

	LogManager &getLogManager();
	SocketManager &getSocketManager();
	PluginManager &getPluginManager();
	ClientManager &getClientManager();

	const std::string &getConfigPath() const;

	typedef std::function<void()> Callback;
	%extend {
		/* work around 2 problems:
		- SWIG fails to convert a script function to const Callback&.
		- SWIG has trouble choosing the overload of addJob / addTimedJob to use.
		*/
		void addJob(const long msec, Callback callback) {
			self->addJob(msec, callback);
		}
		void addJob_str(const std::string& time, Callback callback) {
			self->addJob(time, callback);
		}
		Callback addTimedJob(const long msec, Callback callback) {
			return self->addTimedJob(msec, callback);
		}
		Callback addTimedJob_str(const std::string& time, Callback callback) {
			return self->addTimedJob(time, callback);
		}
	}

%extend {
	time_t getStartTime() const {
		return ($self->getStartTime() - time::ptime(boost::gregorian::date(1970, 1, 1))).total_seconds();
	}
}

};

}
