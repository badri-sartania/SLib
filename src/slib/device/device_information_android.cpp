#include "../../../inc/slib/core/definition.h"

#if defined(SLIB_PLATFORM_IS_ANDROID)

#include "../../../inc/slib/device/information.h"
#include "../../../inc/slib/core/platform_android.h"
#include "../../../inc/slib/core/variant.h"

SLIB_DEVICE_NAMESPACE_BEGIN

SLIB_JNI_BEGIN_CLASS(_JAndroidPoint, "android/graphics/Point")
	SLIB_JNI_INT_FIELD(x);
	SLIB_JNI_INT_FIELD(y);
SLIB_JNI_END_CLASS

SLIB_JNI_BEGIN_CLASS(_JAndroidDeviceInformation, "slib/platform/android/device/DeviceInformation")
	SLIB_JNI_STATIC_METHOD(getDeviceId, "getDeviceId", "(Landroid/app/Activity;)Ljava/lang/String;");
	SLIB_JNI_STATIC_METHOD(getDeviceOSVersion, "getDeviceOSVersion", "()Ljava/lang/String;");
	SLIB_JNI_STATIC_METHOD(getDeviceName, "getDeviceName", "()Ljava/lang/String;");
	SLIB_JNI_STATIC_METHOD(getScreenSize, "getScreenSize", "(Landroid/app/Activity;)Landroid/graphics/Point;");
	SLIB_JNI_STATIC_METHOD(getDevicePPI, "getDevicePPI", "(Landroid/app/Activity;)I");
SLIB_JNI_END_CLASS

String DeviceInformation::getDeviceId()
{
	jobject jactivity = Android::getCurrentActivity();
	if (jactivity) {
		return _JAndroidDeviceInformation::getDeviceId.callString(sl_null, jactivity);
	}
	return String::null();
}

String DeviceInformation::getDeviceName()
{
	jobject jactivity = Android::getCurrentActivity();
	if (jactivity) {
		return _JAndroidDeviceInformation::getDeviceName.callString(sl_null);
	}
	return String::null();
}

String DeviceInformation::getSystemVersion()
{
	jobject jactivity = Android::getCurrentActivity();
	if (jactivity) {
		return _JAndroidDeviceInformation::getDeviceOSVersion.callString(sl_null);
	}
	return String::null();
}

String DeviceInformation::getSystemName()
{
	String osVersion = getSystemVersion();
	return String::format("Android %s", osVersion);
}

Size DeviceInformation::getScreenSize()
{
	Size ret;
	jobject jactivity = Android::getCurrentActivity();
	if (jactivity) {
		JniLocal<jobject> jpt = _JAndroidDeviceInformation::getScreenSize.callObject(sl_null, jactivity);
		if (jpt.isNotNull()) {
			ret.x = _JAndroidPoint::x.get(jpt);
			ret.y = _JAndroidPoint::y.get(jpt);
		}
	}
	return ret;
}

sl_uint32 DeviceInformation::getDevicePPI()
{
	jobject jactivity = Android::getCurrentActivity();
	if (jactivity) {
		return (sl_uint32)(_JAndroidDeviceInformation::getDevicePPI.callInt(sl_null, jactivity));
	}
	return -1;
}

SLIB_DEVICE_NAMESPACE_END

#endif