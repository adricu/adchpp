from Helpers import *

class Hub(object):
    def __init__(self):
        self.settings = dict()
    
class Profile(object):
    def __init__(self, name, hub):
        self.name = name
        self.settings = fallbackdict(hub.settings)
        self.hub = hub

class User(object):
    def __init__(self, hub = None, profile = None, nick = None, cid = None, password = None):
        if not profile:
            self._profile = Profile(hub)
        else:
            self._profile = profile
        
        self.nick = nick
        self.cid = cid
        self.settings = fallbackdict(self._profile.settings)
        
    def setProfile(self, profile):
        self._profile = profile
        self.settings.fallback = profile.settings

    profile = property(lambda self: self._profile, setProfile)