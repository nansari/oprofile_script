#!/bin/bash
set -n
# nasimuddin ansari : nasim.ansari (at) gmail.com
# 16 Feb 2015, version 2, Tested in Production environment
# references:
#  http://techmolecules.blogspot.sg/2015/02/how-to-use-oprofile-opcontrol-opreport.html
#  http://oprofile.sourceforge.net/doc/index.html
#  http://www-01.ibm.com/support/knowledgecenter/linuxonibm/liacf/oprofgetstart.htm
#  https://access.redhat.com/articles/21842
#  http://people.redhat.com/wcohen/OProfileTutorial.txt
#  http://blogs.epfl.ch/category/3239

working_dir=/var/lib/oprofile/new
sample_dir=$working_dir/samples
script_log=$sample_dir/oprofile-script-$(date +%d%b%Y).log
time_now=$(date +%F_%Hh%Mm%Ss)
PATH=$PATH:/usr/bin
exit_status=0
#set -x

[ ! -d "$working_dir" ] && echo Failed: $working_dir does not exist && exit 1
[ ! -d "$working_dir/samples" ] && mkdir $working_dir/samples
[ ! -f "$script_log" ] || touch $script_log

function reinitialize_oprofile {
    echo -e "\nReinitializing oprofile ...."
    opcontrol --deinit
    pgrep -f /usr/bin/oprofiled && pkill -f /usr/bin/oprofiled
    opcontrol --vmlinux=/usr/lib/debug/lib/modules/`uname -r`/vmlinux --session-dir=$working_dir
    opcontrol --start-daemon --session-dir=$working_dir
    # start capture a profile - with default events (cpu cycles)
    opcontrol --start
    opcontrol --status
    # for each of detection, when oprofile was reinitiatlize, touch a file
    touch $sample_dir/reinitialize_oprofile-$time_now
    sleep 60
}

(
echo -e "\nScript $0 started on $(date)"
cd $sample_dir

# if oprofiled is not running, restart it
if ! pgrep -f /usr/bin/oprofiled  >/dev/null
then
    echo oprofiled is not running ...
    reinitialize_oprofile
    if ! pgrep -f /usr/bin/oprofiled  >/dev/null
    then
        echo Failed: Tried to start oprofile, but could not. Please fix it !
    echo Exiting ....
        exit 1
    fi
fi

# if oprofile is running, dump and save stats
opcontrol --dump
opcontrol --save=$time_now

# above save session will create a directory as $time_now
if [ -d "$time_now" ]; then

    # run opreport on saved session to confirm it is good
    if opreport -fg -l session:$time_now --session-dir=$working_dir >/dev/null 2>&1
    then
        echo OK: saved session $time_now is good, start capturing new profile
    if opcontrol --start
    then
        echo OK: 'opcontrol --start' sucess. Creating oparchive now ...
            oparchive -o oparchive-$time_now session:$time_now --session-dir=$working_dir >/dev/null 2>&1

            # if oparchive has been created in above step, create opreport
            if [ -d "oparchive-$time_now" ]; then
                echo OK: oparchive-$time_now has been created, creating opreport now ....
                opreport -fg -l archive:oparchive-$time_now --session-dir=$working_dir session:$time_now >opreport-from-oparchive-${time_now
}.txt 2>&1

                # if opreport has been created, make tarball and do housekeeping
                if [ $? = 0 ];then
            echo OK: opreport-from-oparchive-${time_now}.txt has been created, creating tarball now ...
                    # create a tar file of session, archive and report
                    tar -jcf oprofile-oparchive-opreport-${time_now}.tar.bz2 \
                        oparchive-$time_now $time_now opreport-from-oparchive-${time_now}.txt
                    rm -rf oparchive-$time_now $time_now opreport-from-oparchive-${time_now}.txt
                    if [ -f oprofile-oparchive-opreport-${time_now}.tar.bz2 ];then
                      echo OK: Created oprofile-oparchive-opreport-${time_now}.tar.bz2 file having session, archive and report
                    else
                      echo Failed: to create oprofile-oparchive-opreport-${time_now}.tar.bz2 file session, archive and report
                      exit_status=1
                    fi
                else
                    echo Failed: to create opreport using archived and session
                    exit_status=1
                fi
            else
                echo Failed: oparchive did not create "$sample_dir/$oparchive-$time_now" directory. Hence opreport has failed.
                exit_status=1
            fi
    else
        echo Failed: 'opcontrol --start'. Please fix it !
        exit_status=1
    fi
    else
        echo Failed: "opreport -fg -l session:$time_now" did not work. Hence oparchive too has failed.
        exit_status=1
    fi
else
    echo Failed: "opcontrol --save=$time_now" did not create a valid session. skipping oparchive and opreport. Fix it please !
    exit_status=1
fi


if [ $exit_status = 1 ]; then
    reinitialize_oprofile
    echo -e "Script $0 completed at $(date) Done....\n"
    exit 1
else
    echo -e "Script $0 completed at $(date) Done....\n"
    exit 0
fi

) >>$script_log 2>&1
#set +x
#end of script
