#
# LN_CONFIG_MAX_PAYLOAD
#
# configure maximum payload
#
AC_DEFUN([LN_CONFIG_MAX_PAYLOAD], [
AC_MSG_CHECKING([for non-default maximum LNET payload])
AC_ARG_WITH([max-payload-mb],
	AC_HELP_STRING([--with-max-payload-mb=MBytes],
		[set maximum lnet payload in MBytes]),
	[
		AC_MSG_RESULT([$with_max_payload_mb])
		CONFIG_LNET_MAX_PAYLOAD_MB=$with_max_payload_mb
		CONFIG_LNET_MAX_PAYLOAD="(($with_max_payload_mb)<<20)"
	], [
		AC_MSG_RESULT([no])
		CONFIG_LNET_MAX_PAYLOAD="LNET_MTU"
	])
AC_DEFINE_UNQUOTED(CONFIG_LNET_MAX_PAYLOAD, $CONFIG_LNET_MAX_PAYLOAD,
	[Max LNET payload])
]) # LN_CONFIG_MAX_PAYLOAD

#
# LN_CHECK_GCC_VERSION
#
# Check compiler version
#
AC_DEFUN([LN_CHECK_GCC_VERSION], [
AC_MSG_CHECKING([compiler version])
PTL_CC_VERSION=`$CC --version | awk '/^gcc/{print $ 3}'`
PTL_MIN_CC_VERSION="3.2.2"
v2n() {
	awk -F. '{printf "%d\n", (($ 1)*100+($ 2))*100+($ 3)}'
}
if test -z "$PTL_CC_VERSION" -o \
	$(echo $PTL_CC_VERSION | v2n) -ge $(echo $PTL_MIN_CC_VERSION | v2n); then
	AC_MSG_RESULT([ok])
else
	AC_MSG_RESULT([Buggy compiler found])
	AC_MSG_ERROR([Need gcc version >= $PTL_MIN_CC_VERSION])
fi
]) # LN_CHECK_GCC_VERSION

#
# LN_FUNC_DEV_GET_BY_NAME_2ARG
#
AC_DEFUN([LN_FUNC_DEV_GET_BY_NAME_2ARG], [
LB_CHECK_COMPILE([if 'dev_get_by_name' has two args],
dev_get_by_name_2args, [
	#include <linux/netdevice.h>
],[
	dev_get_by_name(NULL, NULL);
],[
	AC_DEFINE(HAVE_DEV_GET_BY_NAME_2ARG, 1,
		[dev_get_by_name has 2 args])
])
]) # LN_FUNC_DEV_GET_BY_NAME_2ARG

#
# LN_CONFIG_AFFINITY
#
# check if cpu affinity is available/wanted
#
AC_DEFUN([LN_CONFIG_AFFINITY], [
AC_MSG_CHECKING([whether to enable CPU affinity support])
AC_ARG_ENABLE([affinity],
	AC_HELP_STRING([--disable-affinity],
		[disable process/irq affinity]),
	[], [enable_affinity="yes"])
AC_MSG_RESULT([$enable_affinity])
AS_IF([test "x$enable_affinity" = xyes], [
	LB_CHECK_COMPILE([if Linux kernel has cpu affinity support],
	set_cpus_allowed_ptr, [
		#include <linux/sched.h>
	],[
		struct task_struct *t;
		#if HAVE_CPUMASK_T
		cpumask_t     m;
		#else
		unsigned long m;
		#endif
		set_cpus_allowed_ptr(t, &m);
	],[
		AC_DEFINE(CPU_AFFINITY, 1,
			[kernel has cpu affinity support])
	])
])
]) # LN_CONFIG_AFFINITY

#
# LN_CONFIG_BACKOFF
#
# check if tunable tcp backoff is available/wanted
#
AC_DEFUN([LN_CONFIG_BACKOFF], [
AC_MSG_CHECKING([whether to enable tunable backoff TCP support])
AC_ARG_ENABLE([backoff],
	AC_HELP_STRING([--disable-backoff],
		[disable socknal tunable backoff]),
	[], [enable_backoff="yes"])
AC_MSG_RESULT([$enable_backoff])
AS_IF([test "x$enable_backoff" = xyes], [
	AC_MSG_CHECKING([if Linux kernel has tunable backoff TCP support])
	AS_IF([grep -c TCP_BACKOFF $LINUX/include/linux/tcp.h >/dev/null], [
		AC_MSG_RESULT([yes])
		AC_DEFINE(SOCKNAL_BACKOFF, 1, [use tunable backoff TCP])
		AS_IF([grep rto_max $LINUX/include/linux/tcp.h | grep -q __u16 >/dev/null],
			[AC_DEFINE(SOCKNAL_BACKOFF_MS, 1,
				[tunable backoff TCP in ms])])
	], [
		AC_MSG_RESULT([no])
	])
])
]) # LN_CONFIG_BACKOFF

#
# LN_CONFIG_DLC
#
# Configure dlc if enabled
#
# if libyaml is set (IE libyaml installed) and enable_dlc = yes then build
# dlc other wise (IE if libyaml is not set or enable_dlc = no) then don't
# build dlc.
#
AC_DEFUN([LN_CONFIG_DLC], [
	AC_CHECK_LIB([yaml],  [yaml_parser_initialize],[
		LIBYAML="libyaml"],[
		LIBYAML=""],[-lm])
	AC_MSG_CHECKING([whether to enable dlc])
	AC_ARG_ENABLE([dlc],
		AC_HELP_STRING([--disable-dlc],
			[disable building dlc]),
			[], [enable_dlc="yes"])
	AC_MSG_RESULT([$enable_dlc])
	USE_DLC=""
	AS_IF([test "x$enable_dlc" = xyes],
	      [AS_IF([test "x$LIBYAML" = xlibyaml], [
			USE_DLC="yes"
		], [
			AC_MSG_RESULT([no (libyaml not present)])
		])
	])
	AC_SUBST(USE_DLC)
])

#
# LN_CONFIG_QUADRICS
#
# check if quadrics support is in this kernel
#
AC_DEFUN([LN_CONFIG_QUADRICS], [
AC_MSG_CHECKING([for QsNet sources])
AC_ARG_WITH([qsnet],
	AC_HELP_STRING([--with-qsnet=path],
		[set path to qsnet source (default=$LINUX)]),
	[QSNET=$with_qsnet], [QSNET=$LINUX])
AC_MSG_RESULT([$QSNET])

QSWLND=""
QSWCPPFLAGS=""
AC_MSG_CHECKING([if quadrics kernel headers are present])
AS_IF([test -d $QSNET/drivers/net/qsnet], [
	AC_MSG_RESULT([yes])
	QSWLND="qswlnd"
	AC_MSG_CHECKING([for multirail EKC])
	AS_IF([test -f $QSNET/include/elan/epcomms.h], [
		AC_MSG_RESULT([supported])
		QSNET=$(readlink --canonicalize $QSNET)
		QSWCPPFLAGS="-I$QSNET/include -DMULTIRAIL_EKC=1"
	], [
		AC_MSG_RESULT([not supported])
		AC_MSG_ERROR([Need multirail EKC])
	])

	AS_IF([test x$QSNET = x$LINUX], [
		LB_CHECK_CONFIG([QSNET], [], [
			LB_CHECK_CONFIG([QSNET_MODULE], [], [
				AC_MSG_WARN([QSNET is not enabled in this kernel; not building qswlnd.])
				QSWLND=""
				QSWCPPFLAGS=""
			])
		])
	])
], [
	AC_MSG_RESULT([no])
])
AC_SUBST(QSWLND)
AC_SUBST(QSWCPPFLAGS)
]) # LN_CONFIG_QUADRICS

#
# LN_CONFIG_MX
#
AC_DEFUN([LN_CONFIG_MX], [
# set default
MXPATH="/opt/mx"
AC_MSG_CHECKING([whether to enable Myrinet MX support])
AC_ARG_WITH([mx],
	AC_HELP_STRING([--with-mx=path],
		[build mxlnd against path]),
	[
		case $with_mx in
		yes) ENABLEMX=2 ;;
		no)  ENABLEMX=0 ;;
		*)   ENABLEMX=3; MXPATH=$with_mx ;;
		esac
	],[
		ENABLEMX=1
	])
AS_IF([test $ENABLEMX -eq 0], [
	AC_MSG_RESULT([disabled])
], [test ! \( -f ${MXPATH}/include/myriexpress.h -a \
	      -f ${MXPATH}/include/mx_kernel_api.h -a \
	      -f ${MXPATH}/include/mx_pin.h \)], [
	AC_MSG_RESULT([no])
	case $ENABLEMX in
	1) ;;
	2) AC_MSG_ERROR([Myrinet MX kernel headers not present]) ;;
	3) AC_MSG_ERROR([bad --with-mx path]) ;;
	*) AC_MSG_ERROR([internal error]) ;;
	esac
], [
	AC_MSG_RESULT([check])
	MXPATH=$(readlink --canonicalize $MXPATH)
	MXCPPFLAGS="-I$MXPATH/include"
	MXLIBS="-L$MXPATH/lib"
	EXTRA_KCFLAGS_save="$EXTRA_KCFLAGS"
	EXTRA_KCFLAGS="$EXTRA_KCFLAGS $MXCPPFLAGS"
	LB_CHECK_COMPILE([if have Myrinet MX support],
	myrinet_mx_support, [
		#define MX_KERNEL 1
		#include <mx_extensions.h>
		#include <myriexpress.h>
	],[
		mx_endpoint_t   end;
		mx_status_t     status;
		mx_request_t    request;
		int             result;
		mx_init();
		mx_open_endpoint(MX_ANY_NIC, MX_ANY_ENDPOINT, 0, NULL, 0, &end);
		mx_register_unexp_handler(end, (mx_unexp_handler_t) NULL, NULL);
		mx_wait_any(end, MX_INFINITE, 0LL, 0LL, &status, &result);
		mx_iconnect(end, 0LL, 0, 0, 0, NULL, &request);
		return 0;
	],[
		MXLND="mxlnd"
	],[
		case $ENABLEMX in
		1) ;;
		2) AC_MSG_ERROR([can't compile with Myrinet MX kernel headers]) ;;
		3) AC_MSG_ERROR([can't compile with Myrinet MX headers under $MXPATH]) ;;
		*) AC_MSG_ERROR([internal error]) ;;
		esac
		MXCPPFLAGS=""
		MXLIBS=""
		MXLND=""
	])
	EXTRA_KCFLAGS="$EXTRA_KCFLAGS_save"
])
AC_SUBST(MXCPPFLAGS)
AC_SUBST(MXLIBS)
AC_SUBST(MXLND)
]) # LN_CONFIG_MX

#
# LN_CONFIG_O2IB
#
AC_DEFUN([LN_CONFIG_O2IB], [
AC_MSG_CHECKING([whether to use Compat RDMA])
AC_ARG_WITH([o2ib],
	AC_HELP_STRING([--with-o2ib=path],
		[build o2iblnd against path]),
	[
		case $with_o2ib in
		yes)    O2IBPATHS="$LINUX $LINUX/drivers/infiniband"
			ENABLEO2IB=2
			;;
		no)     ENABLEO2IB=0
			;;
		*)      O2IBPATHS=$with_o2ib
			ENABLEO2IB=3
			;;
		esac
	],[
		O2IBPATHS="$LINUX $LINUX/drivers/infiniband"
		ENABLEO2IB=1
	])
AS_IF([test $ENABLEO2IB -eq 0], [
	AC_MSG_RESULT([no])
], [
	o2ib_found=false
	for O2IBPATH in $O2IBPATHS; do
		AS_IF([test \( -f ${O2IBPATH}/include/rdma/rdma_cm.h -a \
			   -f ${O2IBPATH}/include/rdma/ib_cm.h -a \
			   -f ${O2IBPATH}/include/rdma/ib_verbs.h -a \
			   -f ${O2IBPATH}/include/rdma/ib_fmr_pool.h \)], [
			AS_IF([test \( -d ${O2IBPATH}/kernel_patches -a \
				   -f ${O2IBPATH}/Makefile \)], [
				AC_MSG_RESULT([no])
				AC_MSG_ERROR([

you appear to be trying to use the OFED distribution's source
directory (${O2IBPATH}) rather than the "development/headers"
directory which is likely in ${O2IBPATH%-*}
])
			])
			o2ib_found=true
			break
		])
	done
	if ! $o2ib_found; then
		AC_MSG_RESULT([no])
		case $ENABLEO2IB in
			1) ;;
			2) AC_MSG_ERROR([kernel OpenIB gen2 headers not present]) ;;
			3) AC_MSG_ERROR([bad --with-o2ib path]) ;;
			*) AC_MSG_ERROR([internal error]) ;;
		esac
	else
		compatrdma_found=false
		if test -f ${O2IBPATH}/include/linux/compat-2.6.h; then
			AC_MSG_RESULT([yes])
			compatrdma_found=true
			AC_DEFINE(HAVE_COMPAT_RDMA, 1, [compat rdma found])
		else
			AC_MSG_RESULT([no])
		fi
		if ! $compatrdma_found; then
			if test -f "$O2IBPATH/config.mk"; then
				. "$O2IBPATH/config.mk"
			elif test -f "$O2IBPATH/ofed_patch.mk"; then
				. "$O2IBPATH/ofed_patch.mk"
			fi
		else
			if test "x$RHEL_KERNEL" = xyes; then
				case "$RHEL_KERNEL_VERSION" in
					2.6.32-358*)
						EXTRA_OFED_INCLUDE="$EXTRA_OFED_INCLUDE -DCONFIG_COMPAT_RHEL_6_4" ;;
					2.6.32-431*)
						EXTRA_OFED_INCLUDE="$EXTRA_OFED_INCLUDE -DCONFIG_COMPAT_RHEL_6_4 -DCONFIG_COMPAT_RHEL_6_5" ;;
				esac
			elif test "x$SUSE_KERNEL" = xyes; then
				SP=$(grep PATCHLEVEL /etc/SuSE-release | sed -e 's/.*= *//')
				EXTRA_OFED_INCLUDE="$EXTRA_OFED_INCLUDE -DCONFIG_COMPAT_SLES_11_$SP"
			fi
		fi
		AC_MSG_CHECKING([whether to use any OFED backport headers])
		if test -n "$BACKPORT_INCLUDES"; then
			AC_MSG_RESULT([yes])
			OFED_BACKPORT_PATH="$O2IBPATH/${BACKPORT_INCLUDES/*\/kernel_addons/kernel_addons}/"
			EXTRA_OFED_INCLUDE="-I$OFED_BACKPORT_PATH $EXTRA_OFED_INCLUDE"
		else
			AC_MSG_RESULT([no])
		fi

		O2IBLND=""
		O2IBPATH=$(readlink --canonicalize $O2IBPATH)
		EXTRA_OFED_INCLUDE="$EXTRA_OFED_INCLUDE -I$O2IBPATH/include"
		LB_CHECK_COMPILE([whether to enable OpenIB gen2 support],
		openib_gen2_support, [
			#include <linux/version.h>
			#include <linux/pci.h>
			#include <linux/gfp.h>
			#ifdef HAVE_COMPAT_RDMA
			#include <linux/compat-2.6.h>
			#endif
			#include <rdma/rdma_cm.h>
			#include <rdma/ib_cm.h>
			#include <rdma/ib_verbs.h>
			#include <rdma/ib_fmr_pool.h>
		],[
			struct rdma_cm_id      *cm_idi __attribute__ ((unused));
			struct rdma_conn_param  conn_param __attribute__ ((unused));
			struct ib_device_attr   device_attr __attribute__ ((unused));
			struct ib_qp_attr       qp_attr __attribute__ ((unused));
			struct ib_pool_fmr      pool_fmr __attribute__ ((unused));
			enum   ib_cm_rej_reason rej_reason __attribute__ ((unused));
			rdma_destroy_id(NULL);
		],[
			O2IBLND="o2iblnd"
		],[
			case $ENABLEO2IB in
			1) ;;
			2) AC_MSG_ERROR([can't compile with kernel OpenIB gen2 headers]) ;;
			3) AC_MSG_ERROR([can't compile with OpenIB gen2 headers under $O2IBPATH]) ;;
			*) AC_MSG_ERROR([internal error]) ;;
			esac
		])
		# we know at this point that the found OFED source is good
		O2IB_SYMVER=""
		if test $ENABLEO2IB -eq 3 ; then
			# OFED default rpm not handle sles10 Modules.symvers name
			for name in Module.symvers Modules.symvers; do
				if test -f $O2IBPATH/$name; then
					O2IB_SYMVER=$name;
					break;
				fi
			done
			if test -n "$O2IB_SYMVER"; then
				AC_MSG_NOTICE([adding $O2IBPATH/$O2IB_SYMVER to $PWD/$SYMVERFILE])
				# strip out the existing symbols versions first
				if test -f $PWD/$SYMVERFILE; then
				egrep -v $(echo $(awk '{ print $2 }' $O2IBPATH/$O2IB_SYMVER) | tr ' ' '|') $PWD/$SYMVERFILE > $PWD/$SYMVERFILE.old
				else
					touch $PWD/$SYMVERFILE.old
				fi
				cat $PWD/$SYMVERFILE.old $O2IBPATH/$O2IB_SYMVER > $PWD/$SYMVERFILE
				rm $PWD/$SYMVERFILE.old
			else
				AC_MSG_ERROR([an external source tree was specified for o2iblnd however I could not find a $O2IBPATH/Module.symvers there])
			fi
		fi

		LN_CONFIG_OFED_SPEC
	fi
])
AC_SUBST(EXTRA_OFED_INCLUDE)
AC_SUBST(O2IBLND)

# In RHEL 6.2, rdma_create_id() takes the queue-pair type as a fourth argument
AS_IF([test $ENABLEO2IB -ne 0], [
	LB_CHECK_COMPILE([if 'rdma_create_id' wants four args],
	rdma_create_id_4args, [
		#ifdef HAVE_COMPAT_RDMA
		#include <linux/compat-2.6.h>
		#endif
		#include <rdma/rdma_cm.h>
	],[
		rdma_create_id(NULL, NULL, 0, 0);
	],[
		AC_DEFINE(HAVE_RDMA_CREATE_ID_4ARG, 1,
			[rdma_create_id wants 4 args])
	])
])
]) # LN_CONFIG_O2IB

#
# LN_CONFIG_RALND
#
# check whether to use the RapidArray lnd
#
AC_DEFUN([LN_CONFIG_RALND], [
RALND=""
RACPPFLAGS="-I${LINUX}/drivers/xd1/include"
EXTRA_KCFLAGS_save="$EXTRA_KCFLAGS"
EXTRA_KCFLAGS="$EXTRA_KCFLAGS $RACPPFLAGS"
LB_CHECK_COMPILE([if 'RapidArray' kernel headers are present],
RapkGetDeviceByIndex, [
	#include <linux/types.h>
	#include <rapl.h>
],[
	RAP_RETURN rc;
	RAP_PVOID  dev_handle;
	rc = RapkGetDeviceByIndex(0, NULL, &dev_handle);
	return rc == RAP_SUCCESS ? 0 : 1;
],[
	RALND="ralnd"
],[
	RACPPFLAGS=""
])
EXTRA_KCFLAGS="$EXTRA_KCFLAGS_save"
AC_SUBST(RACPPFLAGS)
AC_SUBST(RALND)
]) # LN_CONFIG_RALND

#
# LN_CONFIG_GNILND
#
# check whether to use the Gemini Network Interface lnd
#
AC_DEFUN([LN_CONFIG_GNILND], [
AC_MSG_CHECKING([whether to enable GNI lnd])
AC_ARG_ENABLE([gni],
	AC_HELP_STRING([--enable-gni],
		[enable GNI lnd]),
	[], [enable_gni="no"])
AC_MSG_RESULT([$enable_gni])

AS_IF([test "x$enable_gni" = xyes], [
	# GNICPPFLAGS was set in spec file
	EXTRA_KCFLAGS_save="$EXTRA_KCFLAGS"
	EXTRA_KCFLAGS="$EXTRA_KCFLAGS $GNICPPFLAGS"
	LB_CHECK_COMPILE([if GNI kernel headers are present],
	GNI_header, [
		#include <linux/types.h>
		#include <gni_pub.h>
	],[
		gni_cdm_handle_t kgni_domain;
		gni_return_t	 rc;
		int		 rrc;
		rc = gni_cdm_create(0, 1, 1, 0, &kgni_domain);
		rrc = (rc == GNI_RC_SUCCESS) ? 0 : 1;
		return rrc;
	],[
		GNILND="gnilnd"
	],[
		AC_MSG_ERROR([can't compile gnilnd with given GNICPPFLAGS: $GNICPPFLAGS])
	])
	# at this point, we have gnilnd basic support,
	# now check for extra features
	LB_CHECK_COMPILE([to use RCA in gnilnd],
	RCA_gnilnd, [
		#include <linux/types.h>
		#include <gni_pub.h>
		#include <krca_lib.h>
	],[
		gni_cdm_handle_t kgni_domain;
		gni_return_t	 rc;
		krca_ticket_t	 ticket = KRCA_NULL_TICKET;
		int		 rrc;
		__u32		 nid = 0, nic_addr;
		rc = gni_cdm_create(0, 1, 1, 0, &kgni_domain);
		rrc = (rc == GNI_RC_SUCCESS) ? 0 : 1;
		rrc += krca_nid_to_nicaddrs(nid, 1, &nic_addr);
		rrc += krca_register(&ticket, RCA_MAKE_SERVICE_INDEX(RCA_IO_CLASS, 9), 99, 0);
		return rrc;
	],[
		GNICPPFLAGS="$GNICPPFLAGS -DGNILND_USE_RCA=1"
		GNILNDRCA="gnilndrca"
	])
	EXTRA_KCFLAGS="$EXTRA_KCFLAGS_save"
])
AC_SUBST(GNICPPFLAGS)
AC_SUBST(GNILNDRCA)
AC_SUBST(GNILND)
]) # LN_CONFIG_GNILND

#
# LN_CONFIG_USERSPACE
#
# This is defined but empty because it is called from
# build/autconf/lustre-build.m4 which is shared by all branches.
#
AC_DEFUN([LN_CONFIG_USERSPACE], [
]) # LN_CONFIG_USERSPACE

#
# LN_CONFIG_TCP_SENDPAGE
#
# 2.6.36 tcp_sendpage() first parameter is 'struct sock' instead of 'struct socket'.
#
AC_DEFUN([LN_CONFIG_TCP_SENDPAGE], [
tmp_flags="$EXTRA_KCFLAGS"
EXTRA_KCFLAGS="-Werror"
LB_CHECK_COMPILE([if 'tcp_sendpage' first parameter is socket],
tcp_sendpage_socket, [
	#include <linux/net.h>
	#include <net/tcp.h>
],[
	tcp_sendpage((struct socket*)0, NULL, 0, 0, 0);
],[
	AC_DEFINE(HAVE_TCP_SENDPAGE_USE_SOCKET, 1,
		[tcp_sendpage use socket as first parameter])
])
EXTRA_KCFLAGS="$tmp_flags"
]) # LN_CONFIG_TCP_SENDPAGE

#
# LN_CONFIG_SK_DATA_READY
#
# 2.6.36 tcp_sendpage() first parameter is 'struct sock' instead of 'struct socket'.
#
AC_DEFUN([LN_CONFIG_SK_DATA_READY], [
tmp_flags="$EXTRA_KCFLAGS"
EXTRA_KCFLAGS="-Werror"
LB_CHECK_COMPILE([if 'sk_data_ready' takes only one argument],
sk_data_ready, [
	#include <linux/net.h>
	#include <net/sock.h>
],[
	((struct sock *)0)->sk_data_ready(NULL);
],[
	AC_DEFINE(HAVE_SK_DATA_READY_ONE_ARG, 1,
		[sk_data_ready uses only one argument])
])
EXTRA_KCFLAGS="$tmp_flags"
]) # LN_CONFIG_SK_DATA_READY

#
# LN_PROG_LINUX
#
# LNet linux kernel checks
#
AC_DEFUN([LN_PROG_LINUX], [
AC_MSG_NOTICE([LNet kernel checks
==============================================================================])

LN_FUNC_DEV_GET_BY_NAME_2ARG
LN_CONFIG_AFFINITY
LN_CONFIG_BACKOFF
LN_CONFIG_QUADRICS
LN_CONFIG_O2IB
LN_CONFIG_RALND
LN_CONFIG_GNILND
LN_CONFIG_MX
# 2.6.36
LN_CONFIG_TCP_SENDPAGE
# 3.15
LN_CONFIG_SK_DATA_READY
]) # LN_PROG_LINUX

#
# LN_PATH_DEFAULTS
#
# default paths for installed files
#
AC_DEFUN([LN_PATH_DEFAULTS], [
]) # LN_PATH_DEFAULTS

#
# LN_CONFIGURE
#
# other configure checks
#
AC_DEFUN([LN_CONFIGURE], [
AC_MSG_NOTICE([LNet core checks
==============================================================================])

# lnet/utils/portals.c
AC_CHECK_HEADERS([netdb.h netinet/tcp.h asm/types.h endian.h sys/ioctl.h])
AC_CHECK_FUNCS([gethostbyname socket connect])

# lnet/utils/debug.c
AC_CHECK_HEADERS([linux/version.h])

# lnet/utils/wirecheck.c
AC_CHECK_FUNCS([strnlen])

# --------  Check for required packages  --------------

#
# LC_CONFIG_READLINE
#
# Build with readline
#
AC_MSG_CHECKING([whether to enable readline support])
AC_ARG_ENABLE(readline,
	AC_HELP_STRING([--disable-readline],
		[disable readline support]),
	[], [enable_readline="yes"])
AC_MSG_RESULT([$enable_readline])

# -------- check for readline if enabled ----

LIBREADLINE=""
AS_IF([test "x$enable_readline" = xyes], [
	AC_CHECK_LIB([readline], [readline], [
		LIBREADLINE="-lreadline"
		AC_DEFINE(HAVE_LIBREADLINE, 1,
			[readline library is available])])
])
AC_SUBST(LIBREADLINE)

# -------- enable acceptor libwrap (TCP wrappers) support? -------

AC_MSG_CHECKING([if libwrap support is requested])
AC_ARG_ENABLE([libwrap],
	AC_HELP_STRING([--enable-libwrap], [use TCP wrappers]),
	[case "${enableval}" in
		yes) enable_libwrap="yes" ;;
		no)  enable_libwrap="no" ;;
		*) AC_MSG_ERROR(bad value ${enableval} for --enable-libwrap) ;;
	esac], [enable_libwrap="no"])
AC_MSG_RESULT([$enable_libwrap])
LIBWRAP=""
AS_IF([test "x$enable_libwrap" = xyes], [
	LIBWRAP="-lwrap"
	AC_DEFINE(HAVE_LIBWRAP, 1,
		[libwrap support is requested])
])
AC_SUBST(LIBWRAP)

LN_CONFIG_MAX_PAYLOAD
LN_CONFIG_DLC
]) # LN_CONFIGURE

#
# LN_CONDITIONALS
#
# AM_CONDITOINAL defines for lnet
#
AC_DEFUN([LN_CONDITIONALS], [
AM_CONDITIONAL(BUILD_QSWLND,     test x$QSWLND = "xqswlnd")
AM_CONDITIONAL(BUILD_MXLND,      test x$MXLND = "xmxlnd")
AM_CONDITIONAL(BUILD_O2IBLND,    test x$O2IBLND = "xo2iblnd")
AM_CONDITIONAL(BUILD_RALND,      test x$RALND = "xralnd")
AM_CONDITIONAL(BUILD_GNILND,     test x$GNILND = "xgnilnd")
AM_CONDITIONAL(BUILD_GNILND_RCA, test x$GNILNDRCA = "xgnilndrca")
AM_CONDITIONAL(BUILD_DLC,        test x$USE_DLC = "xyes")
]) # LN_CONDITIONALS

#
# LN_CONFIG_FILES
#
# files that should be generated with AC_OUTPUT
#
AC_DEFUN([LN_CONFIG_FILES], [
AC_CONFIG_FILES([
lnet/Kernelenv
lnet/Makefile
lnet/autoMakefile
lnet/autoconf/Makefile
lnet/doc/Makefile
lnet/include/Makefile
lnet/include/lnet/Makefile
lnet/include/lnet/linux/Makefile
lnet/klnds/Makefile
lnet/klnds/autoMakefile
lnet/klnds/mxlnd/autoMakefile
lnet/klnds/mxlnd/Makefile
lnet/klnds/o2iblnd/Makefile
lnet/klnds/o2iblnd/autoMakefile
lnet/klnds/qswlnd/Makefile
lnet/klnds/qswlnd/autoMakefile
lnet/klnds/ralnd/Makefile
lnet/klnds/ralnd/autoMakefile
lnet/klnds/gnilnd/Makefile
lnet/klnds/gnilnd/autoMakefile
lnet/klnds/socklnd/Makefile
lnet/klnds/socklnd/autoMakefile
lnet/lnet/Makefile
lnet/lnet/autoMakefile
lnet/selftest/Makefile
lnet/selftest/autoMakefile
lnet/utils/Makefile
lnet/utils/lnetconfig/Makefile
])
]) # LN_CONFIG_FILES
