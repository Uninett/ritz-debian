#!/store/bin/scotty

# $Id$

# Test rig for config file parsing & handling

source "../common/util.tcl"
source "../common/conffile.tcl"

catch { namespace delete ::polljob }

namespace eval ::polljob {
    namespace export start restart stop

    proc start { devs } {

	puts [format "polljob::start '%s'" $devs]
    }

    proc restart { devs } {

	puts [format "polljob::restart '%s'" $devs]
    }

    proc stop { devs } {

	puts [format "polljob::stop '%s'" $devs]
    }

}

source "../common/config.tcl"

set conffile "routers.cf"

namespace import config::conf

proc handleChangedConf { file } {
    
    puts [format "config file %s reread, handling" $file]
    config::handleChangedConf $file

    puts [format "new config is:"]
    puts [format "-----"]
    ::config::printConf ::config::conf
    puts [format "-----"]
}

conffile::setHandler handleChangedConf
conffile::startCheckJob $conffile 30
