package es.opentransportmallorca.via

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, TRACKING_CHANNEL)
        TrackingService.onEvent = { event -> channel.invokeMethod(event, null) }
        channel.setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "start" -> {
                        TrackingNotification.current =
                            TrackingNotification.Content.fromMap(call.arguments as Map<*, *>)
                        TrackingService.start(applicationContext)
                        result.success(null)
                    }
                    "update" -> {
                        val content = TrackingNotification.Content.fromMap(call.arguments as Map<*, *>)
                        TrackingNotification.current = content
                        if (TrackingService.isRunning) {
                            TrackingNotification.post(applicationContext, content)
                        }
                        result.success(null)
                    }
                    "stop" -> {
                        TrackingNotification.current = null
                        TrackingService.stop(applicationContext)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            } catch (e: Exception) {
                result.error("tracking_notification", e.message, null)
            }
        }
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        TrackingService.onEvent = null
        TrackingService.stop(applicationContext)
        super.cleanUpFlutterEngine(flutterEngine)
    }

    companion object {
        private const val TRACKING_CHANNEL = "es.opentransportmallorca.via/tracking_notification"
    }
}
