#!/bin/bash

#  install.sh / uninstall.sh - Install or uninstall software

_prefixDir="$HOME/opt"
_provider=""
_product="gsatellite"

# user install activated? 0 => no, 1 => yes
_uIserInstall=1

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

	#  create directory structure
	mkdir -p "$_prefixDir/$_provider/$_product/bin" &>/dev/null
	mkdir -p "$_prefixDir/$_provider/$_product/lib" &>/dev/null
	mkdir -p "$_prefixDir/$_provider/$_product/share/doc" &>/dev/null
	mkdir -p "$_prefixDir/$_provider/$_product/share/man/man1" &>/dev/null

	#  create directory for configuration files and also copy configuration
	#+ files
	if [[ $_userInstall -eq 1 ]]; then
		mkdir -p "$HOME/.$_product/etc" &>/dev/null
		cp ./etc/paths.conf "$HOME/.$_product/etc"
	else	
		mkdir -p "$_prefixDir/$_provider/$_product/etc" &>/dev/null
		cp ./etc/paths.conf "$_prefixDir/$_provider/$_product/etc"
	fi

	#  copy scripts and...
	cp ./bin/gsatctl.bash \
           ./bin/gsatlc.bash \
           ./bin/gsatlcd.bash \
           ./bin/sendcmd.bash \
           ./bin/sigfwd.bash \
           ./bin/sputnik.bash \
           ./bin/sputnikd.bash \
           "$_prefixDir/$_provider/$_product/bin"

        #  reconfigure paths inside of the scripts
        #        + reconfigure path to configuration files
        #        |
        #        |                                                             + remove (special) comments
        #        |                                                             |
        sed -e "s|<PATH_TO_GSATELLITE>|$_prefixDir/$_provider/$_product|g" -e 's/#sed#//g' -i "$_prefixDir/$_provider/$_product/bin/gsatctl.bash"
        sed -e "s|<PATH_TO_GSATELLITE>|$_prefixDir/$_provider/$_product|g" -e 's/#sed#//g' -i "$_prefixDir/$_provider/$_product/bin/gsatlc.bash"
        sed -e "s|<PATH_TO_GSATELLITE>|$_prefixDir/$_provider/$_product|g" -e 's/#sed#//g' -i "$_prefixDir/$_provider/$_product/bin/sendcmd.bash"
        sed -e "s|<PATH_TO_GSATELLITE>|$_prefixDir/$_provider/$_product|g" -e 's/#sed#//g' -i "$_prefixDir/$_provider/$_product/bin/sigfwd.bash"
        sed -e "s|<PATH_TO_GSATELLITE>|$_prefixDir/$_provider/$_product|g" -e 's/#sed#//g' -i "$_prefixDir/$_provider/$_product/bin/sputnik.bash"


	#  ...make links...
	if [[ $_userInstall -eq 1 ]]; then
		linkPath="$HOME"
	else
		linkPath="$_prefixDir/$_provider/$_product"
	fi

	ln -s "$_prefixDir/$_provider/$_product/bin/gsatctl.bash" "$linkPath/bin/gsatctl" \
                                                                  "$linkPath/bin/gqstat" \
                                                                  "$linkPath/bin/gqsub" \
                                                                  "$linkPath/bin/gqhold" \
                                                                  "$linkPath/bin/gqrls" \
                                                                  "$linkPath/bin/gdel"

	ln -s "$_prefixDir/$_provider/$_product/bin/sendcmd.bash" "$linkPath/bin/sendcmd"

	ln -s "$_prefixDir/$_provider/$_product/bin/gsatlc.bash" "$linkPath/bin/gsatlc"
	ln -s "$_prefixDir/$_provider/$_product/bin/gsatlcd.bash" "$linkPath/bin/gsatlcd"
	ln -s "$_prefixDir/$_provider/$_product/bin/sigfwd.bash" "$linkPath/bin/sigfwd"
	ln -s "$_prefixDir/$_provider/$_product/bin/sigfwdd.bash" "$linkPath/bin/sigfwdd"
     	ln -s "$_prefixDir/$_provider/$_product/bin/sputnik.bash" "$linkPath/bin/sputnik"
	ln -s "$_prefixDir/$_provider/$_product/bin/sputnikd.bash" "$linkPath/bin/sputnikd"

	#  copy README and manpages
	cp ./README "$_prefixDir/$_provider/$_product/share/doc"
	#cp ./gtransfer.1.pdf ./dpath.1.pdf ./dparam.1.pdf "$_prefixDir/gtransfer/share/doc"
	cp ./COPYING "$_prefixDir/$_provider/$_product/share/doc"

	cp ./gsatctl.1 "$_prefixDir/$_provider/$_product/share/man/man1"
	cp ./sendcmd.1 "$_prefixDir/$_provider/$_product/share/man/man1"

#  uninstallation
elif [[ "$(basename $0)" == "uninstall.sh" ]]; then

	#  remove a system installed gtransfer
	if [[ "$1" != "" ]]; then
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


