#!/bin/bash

function showHelp()
{
    echo "Usage: [sudo] ./install_ubuntu.sh [--prefix=absolute_path] [OPTIONS]"
    echo "Options:" 
    echo -e "\t -a | --all \t\t install nginx(openresty) and Quick Server framework, redis and beanstalkd"
    echo -e "\t -n | --nginx \t\t install nginx(openresty) and Quick Server framework"
    echo -e "\t -r | --redis \t\t install redis"
    echo -e "\t -b | --beanstalkd \t install beanstalkd"
    echo -e "\t -h | --help \t\t show this help"
    echo "if the option is not specified, default option is \"--all(-a)\"."
    echo "if the \"--prefix\" is not specified, default path is \"/opt/quick_server\"."
}

if [ $UID -ne 0 ]; then
    echo "Superuser privileges are required to run this script."
    echo "e.g. \"sudo $0\""
    exit 1
fi

ARGS=$(getopt -o abrnh --long all,nginx,redis,beanstalkd,help,prefix: -n 'Install quick server' -- "$@")

if [ $? != 0 ] ; then echo "Install Quick Server Terminating..." >&2; exit 1; fi

eval set -- "$ARGS"

declare DEST_DIR=/opt/quick_server
declare -i ALL=0
declare -i BEANS=0
declare -i NGINX=0
declare -i REDIS=0

if [ $# -eq 1 ] ; then
    ALL=1
fi
if [ $# -eq 3 ] && [ $1 == "--prefix" ] ; then
    ALL=1
fi

while true ; do
    case "$1" in
        --prefix) 
            DEST_DIR=$2
            shift 2
            ;;

        -a|--all)
            ALL=1
            shift
            ;;

        -b|--beanstalkd)
            BEANS=1
            shift
            ;;

        -r|--redis)
            REDIS=1
            shift
            ;;

        -n|--nginx)
            NGINX=1
            shift
            ;;

        -h|--help)
            showHelp;
            exit 0 
            ;;

        --) shift; break ;;
        
        *)
            echo "invalid option: $1"
            exit 1
            ;;
    esac
done

eval apt-get > /dev/null 2> /dev/null
if [ $? -eq 0 ] ; then
    apt-get install -y build-essential libpcre3-dev libssl-dev git-core unzip
else
    yum install -y pcre-devel zlib-devel openssl-devel unzip
    yum groupinstall -y "Development Tools"
fi

set -e

CUR_DIR=$(dirname $(readlink -f $0))
BUILD_DIR=/tmp/install_quick_server

OPENRESTY_VER=1.7.7.1
REDIS_VAR=2.6.16
BEANSTALKD_VER=1.9

cd ~
rm -fr $BUILD_DIR
mkdir -p $BUILD_DIR
cp -f $CUR_DIR/install/*.tar.gz $BUILD_DIR

mkdir -p $DEST_DIR
mkdir -p $DEST_DIR/logs
mkdir -p $DEST_DIR/tmp
mkdir -p $DEST_DIR/conf

# install nginx and Quick Server framework 
if [ $ALL -eq 1 ] || [ $NGINX -eq 1 ] ; then
    cd $BUILD_DIR
    tar zxf ngx_openresty-$OPENRESTY_VER.tar.gz
    cd ngx_openresty-$OPENRESTY_VER
    mkdir -p $DEST_DIR/openresty

    # install nginx
    ./configure --prefix=$DEST_DIR/openresty --with-luajit
    make
    make install

    # install quick server framework
    ln -f -s $DEST_DIR/openresty/luajit/bin/luajit-2.1.0-alpha /usr/bin/lua
    ln -f -s $DEST_DIR/openresty/luajit/bin/luajit-2.1.0-alpha $DEST_DIR/openresty/luajit/bin/lua
    cp -rf $CUR_DIR/src $DEST_DIR
    cd $CUR_DIR/tool/

    #deploy tool script
    cp -f start_quick_server.sh stop_quick_server.sh status_quick_server.sh $DEST_DIR
    ln -f -s $DEST_DIR/openresty/nginx/sbin/nginx /usr/bin/nginx

    #copy nginx and Quick Server framework conf file
    cp -f $CUR_DIR/conf/nginx.conf $DEST_DIR/openresty/nginx/conf/.
    sed -i "s#/opt/quick_server#$DEST_DIR#g" $DEST_DIR/openresty/nginx/conf/nginx.conf
    cp -f $CUR_DIR/conf/config.lua $DEST_DIR/conf

    #install luasocket
    cd $BUILD_DIR
    tar zxf luasocket.tar.gz
    cp -rf socket $DEST_DIR/openresty/luajit/lib/lua/5.1/.
    cp -f socket.lua $DEST_DIR/openresty/luajit/share/lua/5.1/.

    #install cjson
    cd $BUILD_DIR
    tar zxf cjson.tar.gz
    cp -f cjson.so $DEST_DIR/openresty/luajit/lib/lua/5.1/.

    echo "Install Openresty and Quick Server framework DONE"
fi

#install redis
if [ $ALL -eq 1 ] || [ $REDIS -eq 1 ] ; then
    cd $BUILD_DIR
    tar zxf redis-$REDIS_VAR.tar.gz
    cd redis-$REDIS_VAR
    mkdir -p $DEST_DIR/redis/bin

    make
    cp src/redis-server $DEST_DIR/redis/bin
    cp src/redis-cli $DEST_DIR/redis/bin
    cp src/redis-sentinel $DEST_DIR/redis/bin
    cp src/redis-benchmark $DEST_DIR/redis/bin
    cp src/redis-check-aof $DEST_DIR/redis/bin
    cp src/redis-check-dump $DEST_DIR/redis/bin

    cp $CUR_DIR/conf/redis.conf $DEST_DIR/conf/. -f
    sed -i "s#/opt/quick_server#$DEST_DIR#g" $DEST_DIR/conf/redis.conf
    mkdir -p $DEST_DIR/redis/rdb
    
    echo "Install Redis DONE"
fi

# install beanstalkd
if [ $ALL -eq 1 ] || [ $BEANS -eq 1 ] ; then
    cd $BUILD_DIR
    tar zxf beanstalkd-$BEANSTALKD_VER.tar.gz
    cd beanstalkd-$BEANSTALKD_VER
    mkdir -p $DEST_DIR/beanstalkd/bin

    make
    cp beanstalkd $DEST_DIR/beanstalkd/bin

    echo "Install Beanstalkd DONE"
fi

# done

echo ""
echo ""
echo ""
echo "DONE!"
echo ""
echo ""