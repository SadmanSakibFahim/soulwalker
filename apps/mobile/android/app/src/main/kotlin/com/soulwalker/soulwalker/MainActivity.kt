package com.soulwalker.soulwalker

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var motion: MotionReader? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val reader = MotionReader(this)
        motion = reader
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "soulwalker/motion")
            .setMethodCallHandler(reader)
    }

    override fun onDestroy() {
        motion?.close()
        super.onDestroy()
    }
}

/**
 * Step counter since boot. Distance is estimated in Dart. The counter keeps
 * running while the app is locked, so a later read can bank the walk.
 */
class MotionReader(private val activity: FlutterActivity) :
    MethodChannel.MethodCallHandler,
    SensorEventListener {
    private val sensorManager =
        activity.getSystemService(Context.SENSOR_SERVICE) as SensorManager
    private val handler = Handler(Looper.getMainLooper())
    private var pending: MethodChannel.Result? = null
    private val timeout =
        Runnable {
            val result = takePending() ?: return@Runnable
            sensorManager.unregisterListener(this)
            result.error("timeout", "No step count arrived.", null)
        }

    private fun takePending(): MethodChannel.Result? {
        synchronized(this) {
            val result = pending
            pending = null
            return result
        }
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "available" ->
                result.success(sensorManager.getDefaultSensor(Sensor.TYPE_STEP_COUNTER) != null)
            "read" -> readSteps(result)
            else -> result.notImplemented()
        }
    }

    fun close() {
        handler.removeCallbacks(timeout)
        takePending()
        sensorManager.unregisterListener(this)
    }

    private fun readSteps(result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q &&
            ContextCompat.checkSelfPermission(
                activity,
                Manifest.permission.ACTIVITY_RECOGNITION,
            ) != PackageManager.PERMISSION_GRANTED
        ) {
            ActivityCompat.requestPermissions(
                activity,
                arrayOf(Manifest.permission.ACTIVITY_RECOGNITION),
                41,
            )
            result.error(
                "permission",
                "Allow physical activity, then start the walk again.",
                null,
            )
            return
        }
        val sensor = sensorManager.getDefaultSensor(Sensor.TYPE_STEP_COUNTER)
        if (sensor == null) {
            result.error("unavailable", "This phone has no step counter.", null)
            return
        }
        if (pending != null) {
            result.error("busy", "A motion read is already running.", null)
            return
        }
        synchronized(this) { pending = result }
        val registered =
            sensorManager.registerListener(this, sensor, SensorManager.SENSOR_DELAY_UI)
        if (!registered) {
            takePending()
            result.error("unavailable", "The step counter did not start.", null)
            return
        }
        handler.postDelayed(timeout, 4000)
    }

    override fun onSensorChanged(event: SensorEvent) {
        val result = takePending() ?: return
        handler.removeCallbacks(timeout)
        sensorManager.unregisterListener(this)
        val steps = event.values[0].toInt()
        activity.runOnUiThread {
            result.success(mapOf("stepCount" to steps))
        }
    }

    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) = Unit
}
