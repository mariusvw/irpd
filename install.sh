#!/bin/sh
##########################################################################
#  install.sh                                          John Sachs        #
#  3/5/2001                                            john@zlilo.com    #
#                      lame install script.                              #
#    Released under the GPL  see www.gnu.org for more information        #
##########################################################################

PREFIX=/usr/local/irpd

if [ ! -d $PREFIX ]
then
 mkdir $PREFIX
fi
if [ -e $PREFIX/irpd.conf ]
then
 mv $PREFIX/irpd.conf $PREFIX/irpd.conf.bak
fi
cp -R * $PREFIX
