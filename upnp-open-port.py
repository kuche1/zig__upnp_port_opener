
import miniupnpc

upnp = miniupnpc.UPnP()

upnp.discover()

upnp.selectigd()

port = 6969

upnp.addportmapping(port, 'TCP', upnp.lanaddr, port, 'sussy-little-baka', '')

