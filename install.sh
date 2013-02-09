#!/bin/bash

#  install.sh / uninstall.sh - Install or uninstall software

_prefixDir="$HOME/opt"
#  Provider of the software, e.g. project name or similar
_provider="clusterd"
_product="gsatellite"

# user install activated? 0 => no, 1 => yes
_userInstall=1

#  if a (prefix) directory is provided, switch to system install
if [[ "$1" != "" ]]; then
	_prefixDir="$1"
	_userInstall=0
fi

#  installation
if [[ "$(basename $0)" == "install.sh" ]]; then

	#  first create bin dir in home, if not already existing (only for user
        #+ install!)
	if [[ $_userInstall -eq 1 ]]; then
		if [[ ! -e "$HOME/bin" ]]; then
			mkdir -p "$HOME/bin" &>/dev/null
		fi
	fi

	#  create base directory
	mkdir -p "$_prefixDir/$_provider/$_product" &>/dev/null

	#  create directory for configuration files and also copy configuration
	#+ files
	if [[ $_userInstall -eq 1 ]]; then
		mkdir -p "$HOME/.$_product" &>/dev/null
		cp ./etc/paths.conf "$HOME/.$_product/paths.conf"
	else		
		cp ./etc/paths.conf "$_prefixDir/$_provider/$_product/etc/paths.conf"
	fi

	#  copy scripts and libs
	cp -rd ./bin "$_prefixDir/$_provider/$_product/"
	cp -rd ./lib "$_prefixDir/$_provider/$_product/"

        #  reconfigure paths inside of the scripts and configurations files
        #        + reconfigure path to configuration files
        #        |
        #        |                                                             + remove (special) comments
        #        |                                                             |
        sed -e "s|<PATH_TO_GSATELLITE>|$_prefixDir/$_provider/$_product|g" -e 's/#sed#//g' -i "$_prefixDir/$_provider/$_product/bin/gsatctl.bash"
        sed -e "s|<PATH_TO_GSATELLITE>|$_prefixDir/$_provider/$_product|g" -e 's/#sed#//g' -i "$_prefixDir/$_provider/$_product/bin/gsatlc.bash"
        sed -e "s|<PATH_TO_GSATELLITE>|$_prefixDir/$_provider/$_product|g" -e 's/#sed#//g' -i "$_prefixDir/$_provider/$_product/bin/sendcmd.bash"
        sed -e "s|<PATH_TO_GSATELLITE>|$_prefixDir/$_provider/$_product|g" -e 's/#sed#//g' -i "$_prefixDir/$_provider/$_product/bin/sigfwd.bash"
        sed -e "s|<PATH_TO_GSATELLITE>|$_prefixDir/$_provider/$_product|g" -e 's/#sed#//g' -i "$_prefixDir/$_provider/$_product/bin/sputnik.bash"
        
	if [[ $_userInstall -eq 1 ]]; then
        	sed -e "s|<PATH_TO_GSATELLITE>|$_prefixDir/$_provider/$_product|g" -i "$HOME/.$_product/paths.conf"
        else
        	sed -e "s|<PATH_TO_GSATELLITE>|$_prefixDir/$_provider/$_product|g" -i "$_prefixDir/$_provider/$_product/etc/paths.conf"
	fi

	#  if this is a user install create links in "$HOME/bin"
	if [[ $_userInstall -eq 1 ]]; then
		linkPath="$HOME"
		ln -s "$_prefixDir/$_provider/$_product/bin/gsatctl.bash" "$linkPath/bin/gsatctl" &>/dev/null
		ln -s "$_prefixDir/$_provider/$_product/bin/gsatctl.bash" "$linkPath/bin/gqstat" &>/dev/null
		ln -s "$_prefixDir/$_provider/$_product/bin/gsatctl.bash" "$linkPath/bin/gqsub" &>/dev/null
		ln -s "$_prefixDir/$_provider/$_product/bin/gsatctl.bash" "$linkPath/bin/gqhold" &>/dev/null
		ln -s "$_prefixDir/$_provider/$_product/bin/gsatctl.bash" "$linkPath/bin/gqrls" &>/dev/null
		ln -s "$_prefixDir/$_provider/$_product/bin/gsatctl.bash" "$linkPath/bin/gqdel" &>/dev/null

		ln -s "$_prefixDir/$_provider/$_product/bin/sendcmd.bash" "$linkPath/bin/sendcmd" &>/dev/null

		ln -s "$_prefixDir/$_provider/$_product/bin/gsatlc.bash" "$linkPath/bin/gsatlc" &>/dev/null
		ln -s "$_prefixDir/$_provider/$_product/bin/gsatlcd.bash" "$linkPath/bin/gsatlcd" &>/dev/null
		ln -s "$_prefixDir/$_provider/$_product/bin/sigfwd.bash" "$linkPath/bin/sigfwd" &>/dev/null
		ln -s "$_prefixDir/$_provider/$_product/bin/sigfwdd.bash" "$linkPath/bin/sigfwdd" &>/dev/null
	     	ln -s "$_prefixDir/$_provider/$_product/bin/sputnik.bash" "$linkPath/bin/sputnik" &>/dev/null
		ln -s "$_prefixDir/$_provider/$_product/bin/sputnikd.bash" "$linkPath/bin/sputnikd" &>/dev/null
	fi

	#  copy README and manpages
	cp -r ./share "$_prefixDir/$_provider/$_product/"
	
#  uninstallation
elif [[ "$(basename $0)" == "uninstall.sh" ]]; then

	#  remove a system installed gtransfer
	if [[ ! $_userInstall -eq 1 ]]; then
		rm -rf "$_prefixDir/$_provider/$_product"
                rmdir --ignore-fail-on-non-empty "$_prefixDir/$_provider"
	#  remove a user installed gtransfer
	else
		#  remove scripts and links "$HOME/bin"
		rm "$HOME/bin/gsatctl" \
                   "$HOME/bin/gqstat" \
                   "$HOME/bin/gqsub" \
                   "$HOME/bin/gqhold" \
                   "$HOME/bin/gqrls" \
                   "$HOME/bin/gqdel" \
                   "$HOME/bin/sendcmd" \
                   "$HOME/bin/gsatlc" \
                   "$HOME/bin/gsatlcd" \
                   "$HOME/bin/sigfwd" \
                   "$HOME/bin/sigfwdd" \
                   "$HOME/bin/sputnik" \
                   "$HOME/bin/sputnikd"

		#  remove gtransfer dir
		rm -rf "$_prefixDir/$_provider/$_product"
                rmdir --ignore-fail-on-non-empty "$_prefixDir/$_provider"

		#  remove basedir configuration files, etc.
		rm -rf "$HOME/.$_product"
	fi
fi


