package com.mizaan.app

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.media.RingtoneManager
import android.os.Build
import android.provider.Telephony
import android.util.Log
import androidx.core.app.NotificationCompat
import org.json.JSONArray
import org.json.JSONObject

class SmsReceiver : BroadcastReceiver() {

    companion object {
        const val TAG = "MizaanSmsReceiver"
        const val CHANNEL_ID = "mizaan_transactions"
        const val CHANNEL_NAME = "حركات المحافظ والرسائل"
        const val CHANNEL_DESC = "إشعارات فورية بالعمليات المالية والمشتريات والإيداعات المستلمة"
        const val PREFS_NAME = "FlutterSharedPreferences"
        const val QUEUE_KEY = "flutter.mizaan_pending_raw_sms_v1"

        private val KNOWN_SENDERS = listOf(
            "kuraimi", "kimb", "haseb", "الكريمي", "حاسب",
            "jaib", "jeeb", "جيب", "tadhamon", "tib", "التضامن",
            "jawali", "جوالي",
            "onecash", "ون كاش", "qutaibi", "القطيبي",
            "floosak", "فلوسك",
            "pyes", "بايس",
            "cacbank", "cac", "السريع", "كاك",
            "alamqi", "العمقي",
            "mahfathati", "محفظتي",
            "weepay", "وي باي",
            "shamil", "شامل",
            "busairi", "البصيري",
            "yemenmobile", "sabafon", "you"
        )

        private val FINANCIAL_KEYWORDS = listOf(
            "إيداع", "ايداع", "أودع", "اودع", "أضيف", "اضيف", "إضافة", "اضافة", "استلام", "تغذية",
            "خصم", "شراء", "مشتريات", "سداد", "تحويل", "دفع", "سحب", "حوالة",
            "حاسب", "نقاط البيع", "رصيدك", "رصيد حسابك", "قيد", "دائن", "إشعار دائن", "اشعار دائن",
            "عكس قيد", "لصالحك", "توريد", "لحسابك", "لحسابكم", "محفظتك",
            "رصيد", "مبلغ", "ريال", "yer", "sar", "usd", "$"
        )
    }

    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.action
        Log.d(TAG, "onReceive triggered with action: $action")

        if (action != Telephony.Sms.Intents.SMS_RECEIVED_ACTION && action != "android.provider.Telephony.SMS_RECEIVED") {
            return
        }

        try {
            val messages = Telephony.Sms.Intents.getMessagesFromIntent(intent)
            if (messages.isNullOrEmpty()) {
                Log.d(TAG, "No SMS messages found in intent extras")
                return
            }

            // Extract sender address
            val sender = messages[0].originatingAddress 
                ?: messages[0].displayOriginatingAddress 
                ?: ""

            val fullBody = StringBuilder()
            var timestamp = messages[0].timestampMillis
            if (timestamp <= 0) {
                timestamp = System.currentTimeMillis()
            }

            for (sms in messages) {
                fullBody.append(sms.displayMessageBody ?: "")
            }

            val body = fullBody.toString().trim()
            Log.d(TAG, "Incoming financial SMS received (content redacted)")

            if (sender.isEmpty() || body.isEmpty()) return

            // Check if message is financial / wallet related, or a test message
            if (!isFinancialMessage(sender, body)) {
                Log.d(TAG, "SMS ignored: Not recognized as financial or test SMS")
                return
            }

            val autoImport = isSmsAutoImportEnabled(context)
            val notifEnabled = isSmsNotificationsEnabled(context)
            Log.d(TAG, "Incoming SMS settings: autoImport=$autoImport, notifEnabled=$notifEnabled")

            // 1. Enqueue to shared preferences only if auto-import is enabled
            if (autoImport) {
                savePendingSms(context, sender, body, timestamp)
                Log.d(TAG, "SMS enqueued to FlutterSharedPreferences")
            } else {
                Log.d(TAG, "SMS enqueue skipped because auto-import is disabled by user")
            }

            // 2. Show native notification only if SMS notifications are enabled
            if (notifEnabled) {
                showNotification(context, sender, body)
                Log.d(TAG, "High-priority notification displayed successfully")
            } else {
                Log.d(TAG, "Notification skipped because SMS notifications are disabled by user")
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to process incoming SMS")
        }
    }

    private fun isFinancialMessage(sender: String, body: String): Boolean {
        val cleanSender = sender.lowercase()
        val normalizedSender = cleanSender.replace(Regex("[^a-z0-9]"), "")
        if (normalizedSender == "mfloos") return false
        val cleanBody = body.lowercase()

        val senderForMatching = cleanSender.replace(Regex("[^\\p{L}\\p{N}]"), "")
        val hasKnownSender = KNOWN_SENDERS.any { rawId ->
            val id = rawId.lowercase().replace(Regex("[^\\p{L}\\p{N}]"), "")
            if (id.length <= 3) senderForMatching == id else senderForMatching.contains(id)
        }
        if (!hasKnownSender) return false
        val isTest = cleanBody.contains("test") || cleanBody.contains("تجربة") || cleanBody.contains("اختبار")
        val hasKeyword = FINANCIAL_KEYWORDS.any { cleanBody.contains(it) }
        return isTest || hasKeyword
    }

    private fun resolveWalletName(sender: String, body: String): String {
        val lowerSender = sender.lowercase()
        val lowerBody = body.lowercase()
        return when {
            lowerSender.contains("kuraimi") || lowerSender.contains("kimb") || lowerSender.contains("haseb") || lowerBody.contains("الكريمي") || lowerBody.contains("حاسب") -> "الكريمي"
            lowerSender.contains("jaib") || lowerSender.contains("jeeb") || lowerSender.contains("tadhamon") || lowerSender.contains("tib") || lowerBody.contains("جيب") || lowerBody.contains("التضامن") -> "جيب"
            lowerSender.contains("jawali") || lowerSender.contains("cac") || lowerBody.contains("جوالي") || lowerBody.contains("كاك") -> "جوالي"
            lowerSender.contains("onecash") || lowerSender.contains("qutaibi") || lowerBody.contains("ون كاش") || lowerBody.contains("القطيبي") -> "ون كاش"
            lowerSender.contains("floosak") || lowerBody.contains("فلوسك") || lowerBody.contains("شامل") -> "فلوسك"
            lowerSender.contains("pyes") || lowerBody.contains("بايس") -> "بايس"
            lowerSender.contains("alamqi") || lowerBody.contains("العمقي") -> "العمقي"
            lowerSender.contains("mahfathati") || lowerBody.contains("محفظتي") -> "محفظتي"
            lowerSender.contains("busairi") || lowerBody.contains("البصيري") -> "البصيري"
            lowerSender.contains("kash") || lowerBody.contains("كاش") -> "كاش"
            else -> if (sender.isNotEmpty() && sender.length <= 15) sender else "المحفظة البنكية"
        }
    }

    private fun showNotification(context: Context, sender: String, body: String) {
        val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val defaultSoundUri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)

        // Create channel for Android 8.0+ (Oreo) with maximum heads-up visibility
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val audioAttributes = AudioAttributes.Builder()
                .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                .setUsage(AudioAttributes.USAGE_NOTIFICATION)
                .build()

            val channel = NotificationChannel(
                CHANNEL_ID,
                CHANNEL_NAME,
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = CHANNEL_DESC
                enableVibration(true)
                vibrationPattern = longArrayOf(0, 300, 200, 300)
                enableLights(true)
                setSound(defaultSoundUri, audioAttributes)
                lockscreenVisibility = Notification.VISIBILITY_PRIVATE
            }
            notificationManager.createNotificationChannel(channel)
        }

        val walletName = resolveWalletName(sender, body)
        val isIncome = body.contains("إيداع") || body.contains("ايداع") || body.contains("أودع") || 
                       body.contains("أضيف") || body.contains("اضيف") || body.contains("إضافة") || 
                       body.contains("اضافة") || body.contains("استلام") || body.contains("تغذية") ||
                       body.contains("تحويل وارد") || body.contains("حوالة واردة") || body.contains("تحويل إلى") ||
                       body.contains("تحويل الى") || body.contains("تحويل لك") || body.contains("قيد لحسابك") ||
                       body.contains("دائن") || body.contains("إشعار دائن") || body.contains("اشعار دائن") ||
                       body.contains("عكس قيد") || body.contains("لصالحك") || body.contains("توريد") ||
                       body.contains("إلى محفظتك") || body.contains("الى محفظتك") || body.contains("لحسابك")
        val isPurchase = body.contains("شراء") || body.contains("مشتريات") || body.contains("حاسب")

        val title = when {
            isIncome -> "💰 إيداع جديد - $walletName"
            isPurchase -> "🛍️ عملية شراء جديدة - $walletName"
            body.contains("خصم") || body.contains("سحب") || body.contains("تحويل") -> "💸 عملية خصم جديدة - $walletName"
            body.contains("test") || body.contains("تجربة") -> "🔔 تجربة إشعار ميزان - $walletName"
            else -> "📩 حركة مالية جديدة - $walletName"
        }

        // Tap action: Launch MainActivity
        val launchIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)?.apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val pendingIntent = PendingIntent.getActivity(
            context,
            (System.currentTimeMillis() % 10000).toInt(),
            launchIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val notification = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(R.mipmap.launcher_icon)
            .setContentTitle(title)
            .setContentText("تم استلام حركة مالية جديدة. افتح ميزان لمراجعة التفاصيل.")
            .setStyle(NotificationCompat.BigTextStyle().bigText("تم استلام حركة مالية جديدة. افتح ميزان لمراجعة التفاصيل.").setSummaryText("ميزان"))
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setDefaults(NotificationCompat.DEFAULT_ALL)
            .setSound(defaultSoundUri)
            .setVibrate(longArrayOf(0, 300, 200, 300))
            .setVisibility(NotificationCompat.VISIBILITY_PRIVATE)
            .setCategory(NotificationCompat.CATEGORY_MESSAGE)
            .setAutoCancel(true)
            .setContentIntent(pendingIntent)
            .build()

        val notifId = (System.currentTimeMillis() / 1000).toInt()
        notificationManager.notify(notifId, notification)
    }

    private fun savePendingSms(context: Context, sender: String, body: String, timestamp: Long) {
        try {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val existingJson = prefs.getString(QUEUE_KEY, "[]") ?: "[]"
            val jsonArray = JSONArray(existingJson)

            // Prevent exact duplicates in queue
            for (i in 0 until jsonArray.length()) {
                val item = jsonArray.getJSONObject(i)
                if (item.optString("sender") == sender && item.optString("body") == body && item.optLong("date") == timestamp) {
                    return // Same broadcast already queued
                }
            }

            val newItem = JSONObject().apply {
                put("sender", sender)
                put("body", body)
                put("date", timestamp)
            }
            jsonArray.put(newItem)
            while (jsonArray.length() > 100) jsonArray.remove(0)

            // Commit synchronously before Android can terminate the receiver.
            prefs.edit().putString(QUEUE_KEY, jsonArray.toString()).commit()
        } catch (e: Exception) {
            Log.e(TAG, "Failed to persist pending SMS")
        }
    }

    private fun isSmsAutoImportEnabled(context: Context): Boolean {
        return try {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val activeUserId = prefs.getString("flutter.current_user_id", null)
            if (!activeUserId.isNullOrEmpty()) {
                val userKey = "flutter.${activeUserId}_smsAutoImportEnabled"
                if (prefs.contains(userKey)) {
                    return prefs.getBoolean(userKey, false)
                }
            }
            if (prefs.contains("flutter.smsAutoImportEnabled")) {
                return prefs.getBoolean("flutter.smsAutoImportEnabled", false)
            }
            false
        } catch (e: Exception) {
            false
        }
    }

    private fun isSmsNotificationsEnabled(context: Context): Boolean {
        return try {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val activeUserId = prefs.getString("flutter.current_user_id", null)
            if (!activeUserId.isNullOrEmpty()) {
                val userKey = "flutter.${activeUserId}_smsNotificationsEnabled"
                if (prefs.contains(userKey)) {
                    return prefs.getBoolean(userKey, false)
                }
            }
            if (prefs.contains("flutter.smsNotificationsEnabled")) {
                return prefs.getBoolean("flutter.smsNotificationsEnabled", true)
            }
            for (key in prefs.all.keys) {
                if (key.endsWith("smsNotificationsEnabled")) {
                    val v = prefs.all[key]
                    if (v is Boolean) return v
                }
            }
            true
        } catch (e: Exception) {
            true
        }
    }
}
