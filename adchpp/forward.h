#ifndef FORWARD_H_
#define FORWARD_H_

namespace adchpp {

class Client;
class Entity;
class ManagedSocket;
typedef boost::intrusive_ptr<ManagedSocket> ManagedSocketPtr;
class PluginManager;
class SocketFactory;
typedef boost::intrusive_ptr<SocketFactory> SocketFactoryPtr;
class SocketManager;
class SimpleXML;

/// Named parameter map (INF etc), AdcCommand::toField offers conversion
typedef std::map<uint16_t, std::string> FieldMap;

}

#endif /*FORWARD_H_*/
