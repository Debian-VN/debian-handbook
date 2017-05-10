#!/bin/sh
set -eux;

configure () {
	export DEBIAN_FRONTEND=noninteractive;
	export DEBCONF_NONINTERACTIVE_SEEN=true;
	export LC_ALL=C;
	export LANGUAGE=C;
	export LANG=C;
	export TZ=GMT;

	readonly CHROOT_POOL_DIR="${HOME}/chroot";
	readonly CHROOT_SUITE='testing'
	readonly CHROOT_ARCH='amd64';
	readonly CHROOT_INFO='build';
	readonly CHROOT_VARIANT='minbase';
	readonly CHROOT_ID="${CHROOT_SUITE}_${CHROOT_ARCH}_${CHROOT_INFO}";
	readonly CHROOT_DIR="${CHROOT_POOL_DIR}/${CHROOT_ID}";
	readonly CHROOT_MIRROR='http://deb.debian.org/debian';
	readonly CURRENT_USER="$(id \
		--user \
		--name \
	;)";
	readonly CURRENT_GROUP="$(id \
		--group \
		--name \
		 "${CURRENT_USER}" \
	;)";
	readonly CURRENT_HOST="$(hostname \
	;)";

	export GIT_AUTHOR_NAME="${CURRENT_USER}";
	export GIT_AUTHOR_EMAIL="${CURRENT_USER}@${CURRENT_HOST}";
	export GIT_COMMITTER_NAME="${GIT_AUTHOR_NAME}";
	export GIT_COMMITTER_EMAIL="${GIT_AUTHOR_EMAIL}";

	readonly BIN="$(readlink \
		--canonicalize \
		"${0}" \
	;)";
	return 0;
}

setup_system_base () {
	if test "root" != "${CURRENT_USER}" ;
	then
		return 1;
	fi
	{
	cat << 'EOT'
APT::Install-Recommends "0";
APT::Install-Suggests "0";
EOT
	} | tee '/etc/apt/apt.conf.d/01norecommend'
	apt-get update
	apt-get \
		--assume-yes \
		install \
		debootstrap \
		schroot \
	;
	return 0;
}

setup_system_build_init () {
	readonly _CHROOT_USER="${1}";
	readonly _CHROOT_GROUP="${2}";
	if test "root" != "${CURRENT_USER}" ;
	then
		return 1;
	fi
	mkdir \
		--parent \
		"$(dirname "${CHROOT_DIR}")" \
	;
	{
	cat << EOF
[${CHROOT_ID}]
description=Debian ${CHROOT_SUITE} ${CHROOT_ARCH} for ${CHROOT_INFO} (${CHROOT_VARIANT})
type=directory
directory=${CHROOT_DIR}
users=${_CHROOT_USER}
groups=${_CHROOT_GROUP}
root-groups=root
EOF
	} | tee \
		"/etc/schroot/chroot.d/${CHROOT_ID}.conf" \
	;
	debootstrap \
		--foreign \
		--verbose \
		--arch="${CHROOT_ARCH}" \
		--variant="${CHROOT_VARIANT}" \
		"${CHROOT_SUITE}" \
		"${CHROOT_DIR}" \
		"${CHROOT_MIRROR}" \
	;
	schroot \
		--chroot="${CHROOT_ID}" \
		-- \
		/debootstrap/debootstrap \
		--second-stage \
	;
	{
	cat << 'EOT'
#!/bin/sh
exit 101
EOT
	} | tee \
		"${CHROOT_DIR}/usr/sbin/policy-rc.d" \
	;
	chmod \
		'a+x' \
		"${CHROOT_DIR}/usr/sbin/policy-rc.d" \
	;
	{
	cat << EOT
deb ${CHROOT_MIRROR} ${CHROOT_SUITE} main
EOT
	} | tee \
		"${CHROOT_DIR}/etc/apt/sources.list.d/01${CHROOT_SUITE}.list" \
	;
	{
	cat << 'EOT'
APT::Install-Recommends "0";
APT::Install-Suggests "0";
EOT
	} | tee \
		"${CHROOT_DIR}/etc/apt/apt.conf.d/01norecommend" \
	;
	{
	cat << 'EOT'
DPkg::options { "--force-confdef"; "--force-confnew"; }
EOT
	} | tee \
		"${CHROOT_DIR}/etc/apt/apt.conf.d/02confnew" \
	;
	return 0;
}

setup_system_build_conf () {
	if test "root" != "${CURRENT_USER}" ;
	then
		return 1;
	fi
	apt-get update;
	#apt-get -y upgrade;
	#apt-get autoremove;
	#apt-get clean;

	echo apt-config \
		dump \
	;
	echo cat \
		'/etc/debian_version' \
	;
	echo id \
	;
	cat \
		'/etc/apt/sources.list' \
	;
	apt-cache \
		policy \
	;
	apt-get install\
		--assume-yes \
		dblatex texlive texlive-xetex publican publican-debian curl lmodern texlive-lang-cyrillic \
		texlive-fonts-extra texlive-font-utils texlive-generic-recommended texlive-math-extra texlive-pstricks ghostscript
	return 0;
}

print_line_separator () {
	echo \
		"======================================================" \
	;
	return 0;
}


build () {
	local _EXIT_STATUS=0;
	# setup_build_dir;
	publican update_pot
	./build/build-pdf --lang="vi-VN"
	RESULT=$?
	curl --upload-file publish/vi-VN/Debian/8/pdf/debian-handbook/debian-handbook.pdf https://transfer.sh
	return $RESULT;
}

travis () {
	sudo \
		-- \
		"${BIN}" \
		'setup/system/base' \
	;
	sudo \
		-- \
		"${BIN}" \
		'setup/system/build/init' \
		"${CURRENT_USER}" \
		"${CURRENT_GROUP}" \
	;
	sudo \
		-- \
		schroot \
		--chroot="${CHROOT_ID}" \
		-- \
		"${BIN}" \
		'setup/system/build/conf' \
	;
	schroot \
		--chroot="${CHROOT_ID}" \
		-- \
		"${BIN}" \
		'build' \
	;
	return 0;
}


configure;
readonly MODE="${1}";
case "${MODE}" in
	'setup/system/base')
		setup_system_base;
	;;
	'setup/system/build/init')
		setup_system_build_init \
			"${2}" \
			"${3}" \
		;
	;;
	'setup/system/build/conf')
		setup_system_build_conf;
	;;
	'build')
		build;
	;;
	'travis')
		travis;
	;;
	*)
		exit 1;
	;;
esac;

exit 0;
