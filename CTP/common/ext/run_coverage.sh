#!/bin/bash
# 
# Copyright (c) 2016, Search Solution Corporation. All rights reserved.
# 
# Redistribution and use in source and binary forms, with or without 
# modification, are permitted provided that the following conditions are met:
# 
#   * Redistributions of source code must retain the above copyright notice, 
#     this list of conditions and the following disclaimer.
# 
#   * Redistributions in binary form must reproduce the above copyright 
#     notice, this list of conditions and the following disclaimer in 
#     the documentation and/or other materials provided with the distribution.
# 
#   * Neither the name of the copyright holder nor the names of its contributors may be used to endorse or promote products 
#     derived from this software without specific prior written permission.
# 
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, 
# INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE 
# DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, 
# SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR 
# SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
# WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE 
# USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE. 
#
set -x


build_home=$HOME/build
binary_build_folder="_install"
source_code_dir=""
build_log=""
alias ini="sh ${CTP_HOME}/bin/ini.sh"

function deploySource()
{
  curDir=`pwd`
  
  if [ "$BUILD_ID" ]
  then
	cd $build_home
        buildID=${BUILD_ID}
        prefixBuildId=${buildID%.*}
        branchSrcFolder="cubrid-${prefixBuildId}"
	mkdir -p $branchSrcFolder
	mkdir -p $binary_build_folder
	rm -rf $binary_build_folder/* > /dev/null
	
	cd $branchSrcFolder
        wget $BUILD_URLS
	
        buildPackageName=${BUILD_URLS##*/}
	if [ -d "$buildPackageName" ];then
	   rm -rf $buildPackageName
	   tar zvxf ${buildPackageName} -C .
	else
	   tar zvxf ${buildPackageName} -C .
	fi

	if [ -f "$buildPackageName" ];then
	   rm $buildPackageName
	fi
	source_build_full_name=${buildPackageName%.tar*}
	source_code_dir=${build_home}/${branchSrcFolder}/${source_build_full_name}

  else
	echo "Please confirm your branch in message is correct!"
	exit -1
  fi

  cd $curDir 

}

function doCompile()
{
   curDir=`pwd`

   if [ "$source_code_dir" ] && [ -d "$source_code_dir" ];then
	cd $source_code_dir
	binary_build_dir="${build_home}/$binary_build_folder"
	build_log_dir="${CTP_HOME}/result/coverage"
	if [ ! -d "$build_log_dir" ];then
	   mkdir -p $build_log_dir
	fi
	build_log="${build_log_dir}/coverage_compile.log"
	if [ -f "$build_log" ];then
	    rm $build_log
	fi

	sh build.sh -m coverage -p $binary_build_dir 2>&1 |tee $build_log
	if [ $? -ne 0 ];then
	    echo ""
	    echo "Fail, please check the compile log -> $build_log"
	    exit -1
        fi

   else
	echo ""
	echo "Please confirm your source code delopyment is done correctly!"
	exit -1
   fi
   cd $curDir

}

function packageBuildsAndUploadpackages()
{
   curDir=`pwd`
   build_succ=`cat $build_log|grep "\[OK\] Building"|wc -l`
   install_ok=`cat $build_log|grep "\[OK\] Installing"|wc -l`
   if [ $build_succ -ne 0 -a $install_ok -ne 0 ];then
	cov_binary_package_name="CUBRID-${BUILD_ID}-gcov-linux.x86_64.tar.gz"
	cov_source_package_name="cubrid-${BUILD_ID}-gcov-src-linux.x86_64.tar.gz"

        cd $source_code_dir
	tar zvcf $cov_source_package_name . 2>&1 >> $build_log
    
	coverage_kr_host=`ini ${CTP_HOME}/conf/common.conf covarage_build_server_host`
	coverage_kr_usr=`ini ${CTP_HOME}/conf/common.conf coverage_build_server_usr`
	coverage_kr_password=`ini ${CTP_HOME}/conf/common.conf coverage_build_server_pwd`
	coverage_kr_port=`ini ${CTP_HOME}/conf/common.conf coverage_build_server_port`
	coverage_kr_build_target_dir=`ini ${CTP_HOME}/conf/common.conf coverage_build_server_target_dir`

        coverage_cn_host="$MKEY_TARGET_IP"
        coverage_cn_usr="$MKEY_TARGET_USER"
        coverage_cn_password="$MKEY_TARGET_PWD"
        coverage_cn_port="$MKEY_TARGET_PORT"
	if [ ! "$coverage_cn_port" ];then
		coverage_cn_port="22"
	fi
        coverage_cn_build_target_dir="$BUILD_ABSOLUTE_PATH"

	

        run_remote_script -user "$coverage_kr_usr" -password "$coverage_kr_password" -host "$coverage_kr_host" -port "$coverage_kr_port" -c "cd ${coverage_kr_build_target_dir};mkdir -p ${BUILD_ID}/drop;"
        run_upload -from "$cov_source_package_name" -user "$coverage_kr_usr" -password "$coverage_kr_password" -host "$coverage_kr_host" -port "$coverage_kr_port" -to "$coverage_kr_build_target_dir/${BUILD_ID}/drop"
        	
        cd ${build_home}/${binary_build_folder}
        tar zvcf $cov_binary_package_name . 2>&1 >> $build_log

        run_upload -from "$cov_binary_package_name" -user "$coverage_cn_usr" -password "$coverage_cn_password" -host "$coverage_cn_host" -port "$coverage_cn_port" -to "$BUILD_ABSOLUTE_PATH"
        run_upload -from "$cov_source_package_name" -user "$coverage_cn_usr" -password "$coverage_cn_password" -host "$coverage_cn_host" -port "$coverage_cn_port" -to "$BUILD_ABSOLUTE_PATH"
  fi
   cd $curDir
}

#=====
# MAIN
# Deploy the source code
deploySource

# Do compile for coverage build
doCompile

# Generate packages for the coverage build
packageBuildsAndUploadpackages
