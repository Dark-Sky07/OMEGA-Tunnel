# 👑 Omega VPS All In One Optimizer (Bidirectional Turbo Edition)

<p align="center">
  <img src="https://img.shields.io/badge/Release-v4.3.0--Turbo-blue.svg?style=for-the-badge&logo=github" alt="Release v4.3.0" />
  <img src="https://img.shields.io/badge/OS-Ubuntu%20|%20Debian%20|%20CentOS-orange.svg?style=for-the-badge&logo=linux" alt="OS Support" />
  <img src="https://img.shields.io/badge/Panel%20Safety-100%25%20Untouched-success.svg?style=for-the-badge&logo=shield" alt="Panel Safety" />
  <img src="https://img.shields.io/badge/Iran%20Server-Docker%20%2B%20APT%20%2B%20GitHub%20Speedup-orange.svg?style=for-the-badge&logo=docker" alt="Iran Server Booster" />
  <img src="https://img.shields.io/badge/Client%20Guard-Zero%20Drop%20Background-success.svg?style=for-the-badge&logo=android" alt="Client Guard" />
  <img src="https://img.shields.io/badge/Language-100%25%20English%20TUI-informational.svg?style=for-the-badge" alt="English TUI" />
</p>

```text
========================================================================
                  ____  __  __ _____ ____    _   
                 / __ \|  \/  | ____/ ___|  / \  
                | |  | | |\/| |  _|| |  _  / _ \ 
                | |__| | |  | | |__| |_| |/ ___ \
                 \____/|_|  |_|_____\____/_/   \_\\

  __     ______  ____     ___        _   _           _             
  \ \   / /  _ \/ ___|   / _ \ _ __ | |_(_)_ __ ___ (_)_______ _ __
   \ \ / /| |_) \___ \  | | | | '_ \| __| | '_ ` _ \| |_  / _ \ '__|
    \ V / |  __/ ___) | | |_| | |_) | |_| | | | | | | |/ /  __/ |  
     \_/  |_|   |____/   \___/| .__/ \__|_|_| |_| |_|_/___\___|_|  
                              |_|                                  
                   All In One Server Suite
========================================================================
```

**Omega VPS All In One Optimizer** یک سوئیت مهندسی‌شده و مافوق‌حرفه‌ای برای تقویت همه‌جانبه سرورهای لینوکس (VPS) است. این پروژه طراحی شده تا بدون نیاز به سرور واسط ایران (Relay/Bridge)، با دور زدن لایه‌های اختلال و فیلترینگ شدید اپراتورها (ایرانسل، همراه اول، رایتل و سامانتل)، سرعت، پایداری و تاب‌آوری اتصالات کاربران را به بالاترین سطح ممکن برساند.

> 🔒 **تضمین ۱۰۰٪ عدم تداخل با پنل (Zero-Downtime Panel Safety):**  
> این اسکریپت به‌هیچ‌وجه به فایل دیتابیس ۳ایکس‌یوآی (`x-ui.db`)، باینری هسته Xray، یا کانفیگ‌های کاربران دست نمی‌زند، سرویس پنل را ری‌استارت نمی‌کند و ارتباط هیچ کاربر آنلاینی را قطع نمی‌کند!

---

## ⚡ نصب سریع و یک‌خطی (One-Liner Install)

تنها با اجرای یک دستور در ترمینال سرور لینوکسی خود، سوئیت امگا به همراه دستور سراسری `omega` دانلود و نصب می‌شود:

```bash
curl -fsSL https://github.com/Dark-Sky07/OMEGA-Tunnel/archive/refs/heads/arena/01a0d868-omega-tunnel.tar.gz | tar -xz && bash OMEGA-Tunnel-arena-01a0d868-omega-tunnel/install.sh && rm -rf OMEGA-Tunnel-arena-01a0d868-omega-tunnel
```

یا روش جایگزین با اجرای مستقیم استریم:

```bash
curl -fsSL https://codeload.github.com/Dark-Sky07/OMEGA-Tunnel/tar.gz/refs/heads/arena/01a0d868-omega-tunnel | tar -xzO OMEGA-Tunnel-arena-01a0d868-omega-tunnel/install.sh | bash
```

پس از نصب، در هر زمان و از هر کجای ترمینال فقط با تایپ کلمه زیر منوی قدرتمند امگا باز می‌شود:

```bash
omega
```

---

## 🛡️ قرارداد ایمنی پنل و مشتریان (Safety Contract)

| مولفه حساس سرور | سیاست و عملکرد Omega Optimizer |
|---|---|
| **دیتابیس پنل (`/etc/x-ui/x-ui.db`)** | **کاملاً دست‌نخورده.** تمام داده‌های امگا در دایرکتوری مستقل `/opt/omega-boost` ذخیره می‌شوند. |
| **هسته Xray (`/usr/local/x-ui/bin`)** | **بدون تغییر و جایگزینی.** هسته رسمی پنل هرگز آپگرید اجباری یا بازنویسی نمی‌شود. |
| **کاربران آنلاین (Active Clients)** | **بدون قطعی.** هیچ دستوری نیاز به ری‌استارت پنل ندارد. سشن کاربران پایدار می‌ماند. |
| **اتصالات WireGuard و WARP** | **محافظت‌شده.** بر خلاف اسکریپت‌های غیراستاندارد، پورت UDP 443 به صورت عمومی بلاک نمی‌شود تا اینترفیس‌های WARP از کار نیفتند. |
| **فایروال سرور** | **قوانین هدفمند با Rollback تمیز.** تغییرات در جدول `mangle` ثبت شده و با ۱ کلیک قابل بازگشت است. |

---

## 🚀 نقشه کامل امکانات (۲۷ ابزار اختصاصی در یک منو)

```text
  --- [ CORE & ONE-CLICK ] ---
  [1]  Run Read-Only Preflight Server Audit
  [2]  ★ ONE-CLICK FULL SERVER OPTIMIZATION (All In One)

  --- [ NETWORK & ANTI-CENSORSHIP ] ---
  [3]  Network & Kernel Tuning (BBR + FQ + 64MB Buffers + Client Upload Turbo)
  [4]  Operator Compatibility Booster (Fix Samantel / Mobile PMTU Clamping)
  [5]  Optimize Instagram & Video Streaming (Safe for WARP & Google)
  [6]  Client Battery & Persistent Connection Guard (Permanent Background Stay)
  [7]  Iran Peak-Hours Smart Performance Scheduler (Auto-boost 20:00-01:30)
  [8]  Domain & Subdomain Censor Health Checker (Test subscription & CDN domains)
  [9]  Reality SNI & Clean Domain Finder (Test best domains for Reality)
  [10] Cloudflare Clean IP Scanner (Find best low-latency CDN IPs)
  [11] Smart Anti-Pollution DNS Cache (High-speed zero-poisoning Anycast)

  --- [ SYSTEM, HARDWARE & REPUTATION ] ---
  [12] System & Hardware Tuning (RAM, Ulimit 1M, Logs 200M)
  [13] Smart Swap Memory Manager (Dynamic suggestions based on RAM)
  [14] IP Reputation & Google/ChatGPT Unban Healer (Auto-Remediation)
  [15] Iran Server Sanctions & Download Booster (Fix Docker 403, APT, GitHub)
  [16] Security & Anti-Bruteforce Hardening (Fail2ban + Ping Shield)
  [17] Panel & Disaster Recovery Backup (1-Click Backup & Restore)
  [18] Automated Nightly Janitor Cronjob (Memory & Cache Cleaner)
  [19] Update System Packages & Install Essential Tools

  --- [ SELF-HEALING & ALERTS ] ---
  [20] 24/7 Panel & Xray Core Auto-Healing Watchdog (Zero-Downtime)
  [21] Telegram Bot Instant Alerts (Crashes, Unbans, & Backups)

  --- [ MONITORING & DIAGNOSTICS ] ---
  [22] Iran Operators Latency & Packet Loss Probe (19 targets across MCI/Irancell/ADSL)
  [23] Iran-Foreign Tunnel & Bridge Health Doctor (Jitter & Packet Loss)
  [24] VPS Bandwidth & Speedtest (Global & Regional Throughput)
  [25] Live Connections & Traffic Monitor (Real-time MB/s & Clients)
  [26] Port & Firewall Doctor (Scan ports & One-Click Port Opener)
  [27] Recommended VLESS-Reality Setup on Free Port 443

  --- [ MANAGEMENT ] ---
  [r]  Restore / Rollback Settings to Original State
  [u]  Update Omega Suite to Latest Release
  [0]  Exit
```

---

## 🔬 بررسی عمیق شاهکارهای فنی امگا

### ۱. محافظت از باتری و پایداری دائمی اتصال در پس‌زمینه (`omega-client-opt.sh`) 📱🔋
- **مشکل شایع:** اپراتورهای موبایل در ایران (ایرانسل و همراه اول) جدول NAT تهاجمی دارند و بعد از ۶۰ الی ۱۲۰ ثانیه بی‌تحرکی گوشی، اتصال سوکت را می‌بندند که باعث فریز شدن وی‌پی‌ان در پس‌زمینه می‌شود.
- **تضمین امگا:** سرور پالس‌های نامحسوس Keepalive در فواصل ۱۲۰ ثانیه می‌فرستد تا جدول NAT اپراتور هرگز منقضی نشود.  
- **تضمین قطع‌نشدن:** کانکشن کاربر **تا زمانی که خودش دستی قطع نکند، تا ابد باز و زنده می‌ماند** و هم‌زمان با الگوریتم FQ Pacing از روشن ماندن بیهوده آنتن رادیویی گوشی و مصرف باتری جلوگیری می‌کند.

### ۲. زمان‌بند هوشمند ساعات اوج فیلترینگ ایران (`omega-scheduler.sh`) ⏰🌙
- در ساعات اوج فیلترینگ در ایران (۲۰:۰۰ تا ۰۱:۳۰ به وقت تهران)، سرور به صورت خودکار به **حالت پیک بافرهای ۶۴ مگابایتی و ارسال مجدد سریع TCP** ارتقا می‌یابد تا ریزش پکت‌ها جبران شود و در ساعات آرام روز مجدداً به مصرف بهینه برمی‌گردد.

### ۳. شتاب‌دهنده سرور ایران، رفع تحریم داکر و مخازن (`omega-iran-unlocker.sh`) 🇮🇷⚡
- **رفع خطای ۴۰۳ داکر (Docker Hub):** تزریق خودکار میرورهای داخلی و ضدتحریم معتبر (`arvancloud`, `iranserver`, `registry.docker.ir`) در `/etc/docker/daemon.json` بدون نیاز به وی‌پی‌ان یا پراکسی دستی.
- **شتاب‌دهنده مخازن APT با سرعت ۱۰۰ مگابایت بر ثانیه:** تعویض هوشمند سرورهای آپدیت کند اوبونتو/دبیان با پرسرعت‌ترین سرورهای میرور داخلی ایران (کاهش زمان `apt update` و `apt upgrade` به زیر ۱۰ ثانیه).
- **رفع آلودگی دی‌ان‌اس و شتاب‌دهنده گیت‌هاب:** تزریق مستقیم آی‌پی‌های Anycast پاک در `/etc/hosts` برای حل فیلترینگ و پویزن بودن `raw.githubusercontent.com` و است‌های ریلیز گیت‌هاب.
- **دی‌ان‌اس ضدتحریم (شکن و ۴۰۳):** تنظیم خودکار Anycastهای تحریم‌شکن برای دانلود روان پکیج‌های پایتون، نود، داکر و گوگل کلود.

### ۴. سگ نگهبان هوشمند ۲۴/۷ پنل و هسته اشعه (`omega-watchdog.sh`) 🐕
- در صورت بروز کمبود حافظه یا حملات فیلترینگ که منجر به توقف ناگهانی پنل ۳ایکس‌یوآی یا هسته Xray شود، سگ نگهبان در کمتر از ۳ ثانیه سرویس را بدون نیاز به حضور ادمین زنده می‌کند.

### ۵. آنلاکر خودکار گوگل و چت‌جی‌پی‌تی (`omega-unban.sh`) 🤖🔓
- تست استاندارد با اندپوینت‌های رسمی OpenAI (`api.openai.com/v1/models`) و اولویت استاندارد IPv4 در `/etc/gai.conf` برای حل ریشه‌ای ربات‌سنج گوگل.
- امگا با اعمال قانون هوشمند `--clamp-mss-to-pmtu` در جدول `POSTROUTING`، سقف اندازه پکت‌های TCP را دقیقاً مطابق با سقف مجاز مسیر کلاینت تراز می‌کند و مشکل فریز شدن یا لود نشدن کانفیگ‌ها را ۱۰۰٪ روی سرور حل می‌کند.

### ۴. شتاب‌دهنده ویدیو و اینستاگرام سازگار با وارپ (`omega-instagram-fix.sh`) 📸
- برخلاف اسکریپت‌های سنتی که کل پورت UDP 443 را می‌بندند و باعث قطعی WireGuard و Cloudflare WARP می‌شوند، امگا لیست دقیق ساب‌نت‌های رسمی شرکت متا (ASN 32934 / Meta CIDRs) را در یک `ipset` سخت‌افزاری ایزوله می‌کند.
- فقط پروتکل مسدودشده QUIC در مسیر اینستاگرام به TCP پرسرعت هدایت می‌شود، در حالی که سرویس‌های گوگل، هوش مصنوعی، و WARP به حداکثر سرعت نامحدود دسترسی دارند.

### ۵. اسکنر هوشمند آی‌پی تمیز کلودفلر (`omega-cf-scanner.sh`) ☁️
- اسکن لحظه‌ای و اندازه‌گیری تأخیر (TCP Latency) روی رنج‌های طلایی کلودفلر برای اینباندهای WebSocket / CDN بدون نیاز به تغییر سرور.

### ۶. سیستم هشدار و مانیتورینگ زنده تلگرام (`omega-telegram.sh`) 📱
- اتصال مستقیم با توکن ربات تلگرام و Chat ID برای دریافت هشدار در هنگام ری‌استارت هسته، خطاهای امنیتی، و موفقیت بکاپ‌های دوره‌ای.

---

## 🔄 بازگردانی تغییرات به حالت اولیه (Rollback Guarantee)

شما در هر زمان می‌توانید با زدن کلید **`r`** در منوی اصلی، تمام قوانین شبکه، فایروال و تنظیمات کرنل را دقیقاً به حالت خام کارخانه سرور بازگردانید:

```bash
omega -> [r] Restore / Rollback Settings
```

---

## 🤝 لایسنس و حقوق استفاده

این پروژه تحت لایسنس MIT منتشر شده و توسعه آن برای کمک به جامعه ادمین‌های سرور و دسترسی به اینترنت آزاد و پرسرعت انجام گرفته است.  
توسعه‌یافته با ❤️ برای آزادی اطلاعات.
