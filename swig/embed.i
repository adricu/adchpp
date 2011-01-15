// Subset of the api intended for embedded use

%include "adchpp.i"

%extend adchpp::ClientManager {
	time_t getStartTime() const {
		return (self->getCore().getStartTime() - time::ptime(boost::gregorian::date(1970, 1, 1))).total_seconds();
	}

	uint32_t getUpTime() const {
		return (time::now() - self->getCore().getStartTime()).total_seconds();
	}
}
