// Full API into the adchpp core

%include "adchpp.i"

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

	/** execute a function asynchronously */
	void addJob(const Callback& callback) throw();

	/** execute a function after the specified amount of time
	* @param msec milliseconds
	*/
	void addJob(const long msec, const Callback& callback);

	/** execute a function after the specified amount of time
	* @param time a string that obeys to the "[-]h[h][:mm][:ss][.fff]" format
	*/
	void addJob(const std::string& time, const Callback& callback);

	/** execute a function at regular intervals
	* @param msec milliseconds
	* @return function one must call to cancel the timer (its callback will still be executed)
	*/
	Callback addTimedJob(const long msec, const Callback& callback);

	/** execute a function at regular intervals
	* @param time a string that obeys to the "[-]h[h][:mm][:ss][.fff]" format
	* @return function one must call to cancel the timer (its callback will still be executed)
	*/
	Callback addTimedJob(const std::string& time, const Callback& callback);

%extend {
	time_t getStartTime() const {
		return ($self->getStartTime() - time::ptime(boost::gregorian::date(1970, 1, 1))).total_seconds();
	}
}

};

}
